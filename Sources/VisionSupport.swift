// ============================================================================
// VisionSupport.swift — macOS 27 image input + capability reporting (#510)
//
// macOS 27's FoundationModels accepts image attachments on prompts and
// reports the model's capabilities; macOS 26 does neither. The availability
// decision for every one of those 27-only APIs is made HERE, once.
// Everything downstream branches on data (`runtimeSupportsVision`, decoded
// `PromptPiece` values, a `CapabilitiesReport`), never on #available -
// ApfelCore stays availability-free (same pattern as UsageAccounting.swift).
//
// 100% on-device: images arrive as base64 data URLs (server) or local files
// the CLI user named (-f / pipe). Nothing is ever fetched over the network,
// and the server never reads a filesystem path named by an HTTP client -
// ImageInput (ApfelCore) enforces both by construction.
// ============================================================================

import Foundation
import FoundationModels
import CoreGraphics
import ImageIO
import ApfelCore

/// True when the FoundationModels runtime accepts image attachments and
/// reports capabilities (macOS 27+). Decided once per process.
let runtimeSupportsVision: Bool = {
    if #available(macOS 27, *) { return true }
    return false
}()

/// The server's image-input policy: base64 data URLs up to 20 MB on
/// macOS 27, the unchanged honest 400 on macOS 26.
let serverImagePolicy: ImageInputPolicy = runtimeSupportsVision
    ? .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)
    : .unsupported

/// The server's request-body cap: room for one full-size data-URL image
/// where images can be used at all (macOS 27); the unchanged 1 MiB cap on
/// macOS 26.
let serverMaxRequestBodyBytes: Int = runtimeSupportsVision
    ? BodyLimits.visionMaxRequestBodyBytes
    : BodyLimits.maxRequestBodyBytes

/// Longest-side pixel cap applied while decoding. Larger images are
/// downscaled (preserving aspect ratio and EXIF orientation) - the
/// on-device model works on far smaller representations, so quality for
/// generation is unaffected while a decompression-bomb PNG cannot balloon
/// into gigabytes of bitmap.
let imageMaxPixelSize = 4096

// MARK: - Decoded images

/// A decoded, downscaled image ready to attach to a prompt.
/// CGImage is immutable and Sendable in the SDK.
struct PromptImage: Sendable {
    let image: CGImage
}

/// One ordered piece of a user turn: text or an image. Mirrors the order of
/// the OpenAI content parts so the model sees text and images as the client
/// arranged them.
enum PromptPiece: Sendable {
    case text(String)
    case image(PromptImage)
}

/// True when any piece is an image.
func hasImagePiece(_ pieces: [PromptPiece]) -> Bool {
    pieces.contains { if case .image = $0 { return true } else { return false } }
}

/// Decode image bytes into a prompt-ready CGImage via ImageIO, capped at
/// `imageMaxPixelSize` on the longest side. Animated GIFs use the first
/// frame (index 0).
func decodePromptImage(data: Data, label: String) throws -> PromptImage {
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: imageMaxPixelSize,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) >= 1,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw ApfelError.invalidImageInput("the image data could not be decoded (\(label))")
    }
    return PromptImage(image: image)
}

/// The ordered text/image pieces of one OpenAI message. Image parts are
/// parsed (data URL) and decoded (ImageIO); any failure is a client-input
/// error. On an OS without vision support a message that still carries
/// images (the server validator normally rejects them first; the CLI
/// `--messages` path arrives here directly) gets the same honest message.
func promptPieces(of message: OpenAIMessage) throws -> [PromptPiece] {
    switch message.content {
    case .text(let text):
        return [.text(text)]
    case .none:
        return []
    case .parts(let parts):
        guard message.containsImageContent else {
            let text = parts.compactMap(\.text).joined()
            return text.isEmpty ? [] : [.text(text)]
        }
        guard runtimeSupportsVision else {
            throw ApfelError.invalidImageInput(ChatRequestValidationFailure.imageContent.message)
        }
        var pieces: [PromptPiece] = []
        for part in parts {
            if part.type == "image_url" {
                guard let payload = part.image_url, !payload.url.isEmpty else {
                    throw ApfelError.invalidImageInput(ImageInput.Failure.missingURL.message)
                }
                switch ImageInput.parseDataURL(payload.url) {
                case .failure(let failure):
                    throw ApfelError.invalidImageInput(failure.message)
                case .success(let parsed):
                    pieces.append(.image(try decodePromptImage(data: parsed.data, label: parsed.mediaType)))
                }
            } else if let text = part.text, !text.isEmpty {
                pieces.append(.text(text))
            }
        }
        return pieces
    }
}

// MARK: - Prompt / transcript construction (the only 27-gated builders)

/// Build the `respond()` prompt for a user turn: plain text when there are
/// no images (today's exact behavior on both OSes), text + native image
/// attachments in piece order on macOS 27.
func makeUserPrompt(text: String, pieces: [PromptPiece]) -> Prompt {
    guard hasImagePiece(pieces) else { return Prompt(text) }
    if #available(macOS 27, *) {
        let components: [Prompt] = pieces.map { piece in
            switch piece {
            case .text(let part):
                return Prompt(part)
            case .image(let image):
                return Prompt(Attachment<ImageAttachmentContent>(image.image))
            }
        }
        return Prompt(components)
    }
    // Unreachable: images never decode on macOS 26 (promptPieces throws).
    return Prompt(text)
}

/// Transcript segments for a user turn's pieces - text segments plus, on
/// macOS 27, native image attachment segments in piece order.
func promptSegments(pieces: [PromptPiece]) -> [Transcript.Segment] {
    pieces.compactMap { piece in
        switch piece {
        case .text(let text):
            return .text(Transcript.TextSegment(content: text))
        case .image(let image):
            if #available(macOS 27, *) {
                return .attachment(Transcript.AttachmentSegment(
                    content: .image(Transcript.ImageAttachment(image.image))))
            }
            // Unreachable: images never decode on macOS 26.
            return nil
        }
    }
}

// MARK: - Capabilities (#510 item 6, capabilities half)

/// Read the model's reported capabilities. macOS 27 reports them via
/// `SystemLanguageModel.capabilities`; macOS 26 has no such API, so the
/// report says so (`reported == false`) instead of guessing.
func readModelCapabilities() -> CapabilitiesReport {
    if #available(macOS 27, *) {
        let capabilities = SystemLanguageModel.default.capabilities
        var present: [ModelCapability] = []
        if capabilities.contains(.vision) { present.append(.vision) }
        if capabilities.contains(.toolCalling) { present.append(.toolCalling) }
        if capabilities.contains(.guidedGeneration) { present.append(.guidedGeneration) }
        if capabilities.contains(.reasoning) { present.append(.reasoning) }
        return CapabilitiesReport(capabilities: present)
    }
    return .notReported
}
