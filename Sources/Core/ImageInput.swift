// ============================================================================
// ImageInput.swift — pure data-URL image input parsing + policy (#510)
//
// apfel is 100% on-device: image input arrives as a base64 data URL in the
// request body, never as something the server would fetch (http/https) or
// read from the local filesystem on a client's behalf (file://, paths).
// This file is the pure part: scheme rules, media-type whitelist, base64
// decode, size cap. Decoding the bytes into a CGImage (and the macOS-27
// availability decision) lives in the main target.
// ============================================================================

import Foundation

/// Whether, and under which limits, image content parts are accepted.
///
/// The decision is made once in the main target (image input needs the
/// macOS 27 FoundationModels attachment API); ApfelCore only enforces it.
public enum ImageInputPolicy: Sendable, Equatable, Hashable {
    /// Image parts are rejected (macOS 26: the on-device model cannot see them).
    case unsupported
    /// Image parts are accepted as base64 data URLs up to the given base64
    /// payload size (macOS 27+).
    case dataURL(maxBase64Bytes: Int)

    /// True when image parts can be accepted at all.
    public var allowsImages: Bool {
        if case .dataURL = self { return true }
        return false
    }
}

/// Pure parsing of OpenAI-style `image_url` values into image bytes.
public enum ImageInput {

    /// Maximum accepted base64 payload length per image: 20 MB of base64
    /// text (about 15 MB of decoded image data).
    public static let maxBase64Bytes = 20 * 1024 * 1024

    /// Media types the decoder accepts. GIF uses the first frame only.
    public static let allowedMediaTypes: [String] = [
        "image/png", "image/jpeg", "image/webp", "image/heic", "image/gif",
    ]

    /// Why an `image_url` value was rejected. Every case carries a stable,
    /// user-facing message.
    public enum Failure: Error, Sendable, Equatable, Hashable {
        /// An `http://` or `https://` URL: apfel never fetches image content.
        case remoteURL
        /// A `file://` URL or a local filesystem path: an HTTP client must
        /// not make the server read arbitrary local files.
        case localFile
        /// Not a `data:` URL at all.
        case notADataURL
        /// A `data:` URL without the `;base64` marker.
        case notBase64
        /// A media type outside `allowedMediaTypes`.
        case unsupportedMediaType(String)
        /// The base64 payload did not decode (or was empty).
        case invalidBase64
        /// The base64 payload exceeded the size cap.
        case tooLarge(limitBytes: Int)
        /// An `image_url` part without a `url` value.
        case missingURL

        /// The stable user-facing error message.
        public var message: String {
            switch self {
            case .remoteURL:
                return "apfel does not fetch remote images - send a data URL (data:image/png;base64,...). apfel is 100% on-device."
            case .localFile:
                return "apfel does not read local file paths from 'image_url' - send a data URL (data:image/png;base64,...)."
            case .notADataURL:
                return "'image_url' must be a data URL (data:image/png;base64,...)."
            case .notBase64:
                return "image data URLs must be base64-encoded (data:image/png;base64,...)."
            case .unsupportedMediaType(let type):
                return "unsupported image media type '\(type)'. Supported: \(ImageInput.allowedMediaTypes.joined(separator: ", "))."
            case .invalidBase64:
                return "the image data URL payload is not valid base64."
            case .tooLarge(let limit):
                return "the image data URL exceeds the \(limit / (1024 * 1024)) MB base64 limit."
            case .missingURL:
                return "'image_url' part is missing its 'image_url.url' value."
            }
        }
    }

    /// One parsed image: its normalized media type and decoded bytes.
    public struct ParsedImage: Sendable, Equatable {
        public let mediaType: String
        public let data: Data

        public init(mediaType: String, data: Data) {
            self.mediaType = mediaType
            self.data = data
        }
    }

    /// Parses an `image_url` value. Only base64 `data:` URLs with a
    /// whitelisted image media type under the size cap succeed; remote URLs,
    /// file URLs, and local paths are rejected by category so the error can
    /// say exactly why.
    public static func parseDataURL(
        _ url: String,
        maxBase64Bytes: Int = ImageInput.maxBase64Bytes
    ) -> Result<ParsedImage, Failure> {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            return .failure(.remoteURL)
        }
        if lowered.hasPrefix("file://") || trimmed.hasPrefix("/")
            || trimmed.hasPrefix("~") || trimmed.hasPrefix("./") || trimmed.hasPrefix("../") {
            return .failure(.localFile)
        }
        guard lowered.hasPrefix("data:") else {
            return .failure(.notADataURL)
        }
        guard let comma = trimmed.firstIndex(of: ",") else {
            return .failure(.notBase64)
        }
        let header = lowered[lowered.index(lowered.startIndex, offsetBy: "data:".count)..<comma]
        let headerFields = header.split(separator: ";").map(String.init)
        guard headerFields.contains("base64") else {
            return .failure(.notBase64)
        }
        var mediaType = headerFields.first ?? ""
        if mediaType == "image/jpg" { mediaType = "image/jpeg" }
        guard allowedMediaTypes.contains(mediaType) else {
            return .failure(.unsupportedMediaType(headerFields.first ?? ""))
        }
        let payload = String(trimmed[trimmed.index(after: comma)...])
        guard payload.utf8.count <= maxBase64Bytes else {
            return .failure(.tooLarge(limitBytes: maxBase64Bytes))
        }
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
              !data.isEmpty else {
            return .failure(.invalidBase64)
        }
        return .success(ParsedImage(mediaType: mediaType, data: data))
    }
}
