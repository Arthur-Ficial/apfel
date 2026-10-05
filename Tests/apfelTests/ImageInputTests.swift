// ============================================================================
// ImageInputTests.swift — data-URL image input parsing + validation (#510)
// Pure ApfelCore: no FoundationModels, no ImageIO. The 27-only decode to
// CGImage lives in the main target and is covered by integration tests.
// ============================================================================

import Foundation
import ApfelCore

private func pngDataURL(_ bytes: Int = 8) -> String {
    "data:image/png;base64," + Data(repeating: 0x41, count: bytes).base64EncodedString()
}

private func imageMessage(role: String = "user", url: String, text: String? = "What is this?") -> OpenAIMessage {
    var parts: [ContentPart] = []
    if let text { parts.append(ContentPart(type: "text", text: text)) }
    parts.append(ContentPart(type: "image_url", text: nil, image_url: ImageURLContent(url: url, detail: nil)))
    return OpenAIMessage(role: role, content: .parts(parts))
}

private func chatRequest(messages: [OpenAIMessage]) -> ChatCompletionRequest {
    let msgJSON = messages.map { m -> String in
        switch m.content {
        case .text(let t):
            return #"{"role":"\#(m.role)","content":"\#(t)"}"#
        case .parts(let parts):
            let encoded = parts.map { p -> String in
                if p.type == "image_url" {
                    return #"{"type":"image_url","image_url":{"url":"\#(p.image_url?.url ?? "")"}}"#
                }
                return #"{"type":"text","text":"\#(p.text ?? "")"}"#
            }.joined(separator: ",")
            return #"{"role":"\#(m.role)","content":[\#(encoded)]}"#
        case .none:
            return #"{"role":"\#(m.role)"}"#
        }
    }.joined(separator: ",")
    let json = #"{"model":"apple-foundationmodel","messages":[\#(msgJSON)]}"#
    return try! JSONDecoder().decode(ChatCompletionRequest.self, from: Data(json.utf8))
}

func runImageInputTests() {

    // MARK: parseDataURL — accepted media types

    test("parseDataURL accepts png, jpeg, webp, heic, gif") {
        for mime in ["image/png", "image/jpeg", "image/webp", "image/heic", "image/gif"] {
            let url = "data:\(mime);base64," + Data("x".utf8).base64EncodedString()
            guard case .success(let parsed) = ImageInput.parseDataURL(url) else {
                throw TestFailure("expected success for \(mime)")
            }
            try assertEqual(parsed.mediaType, mime)
            try assertEqual(parsed.data, Data("x".utf8))
        }
    }

    test("parseDataURL normalizes image/jpg to image/jpeg and is case-insensitive") {
        let url = "DATA:IMAGE/JPG;BASE64," + Data("y".utf8).base64EncodedString()
        guard case .success(let parsed) = ImageInput.parseDataURL(url) else {
            throw TestFailure("expected success")
        }
        try assertEqual(parsed.mediaType, "image/jpeg")
    }

    // MARK: parseDataURL — rejections

    test("parseDataURL rejects http and https URLs (on-device: no fetching)") {
        for url in ["http://example.com/a.png", "https://example.com/a.png", "HTTPS://example.com/a.png"] {
            guard case .failure(let f) = ImageInput.parseDataURL(url) else {
                throw TestFailure("expected failure for \(url)")
            }
            try assertEqual(f, .remoteURL)
            try assertTrue(f.message.contains("apfel does not fetch remote images - send a data URL"), f.message)
        }
    }

    test("parseDataURL rejects file URLs and local paths") {
        for url in ["file:///etc/passwd", "/etc/passwd", "~/photo.png", "./photo.png"] {
            guard case .failure(let f) = ImageInput.parseDataURL(url) else {
                throw TestFailure("expected failure for \(url)")
            }
            try assertEqual(f, .localFile)
            try assertTrue(f.message.contains("data URL"), f.message)
        }
    }

    test("parseDataURL rejects non-data schemes") {
        guard case .failure(let f) = ImageInput.parseDataURL("ftp://example.com/a.png") else {
            throw TestFailure("expected failure")
        }
        try assertEqual(f, .notADataURL)
    }

    test("parseDataURL rejects unsupported media types by name") {
        guard case .failure(let f) = ImageInput.parseDataURL("data:image/tiff;base64,QUJD") else {
            throw TestFailure("expected failure")
        }
        try assertEqual(f, .unsupportedMediaType("image/tiff"))
        try assertTrue(f.message.contains("image/tiff"), f.message)
        try assertTrue(f.message.contains("image/png"), f.message)
    }

    test("parseDataURL rejects data URLs without base64 marker") {
        guard case .failure(let f) = ImageInput.parseDataURL("data:image/png,plaintext") else {
            throw TestFailure("expected failure")
        }
        try assertEqual(f, .notBase64)
    }

    test("parseDataURL rejects invalid and empty base64 payloads") {
        guard case .failure(let bad) = ImageInput.parseDataURL("data:image/png;base64,@@@not-base64@@@") else {
            throw TestFailure("expected failure for invalid base64")
        }
        try assertEqual(bad, .invalidBase64)
        guard case .failure(let empty) = ImageInput.parseDataURL("data:image/png;base64,") else {
            throw TestFailure("expected failure for empty payload")
        }
        try assertEqual(empty, .invalidBase64)
    }

    test("parseDataURL enforces the base64 size cap") {
        let url = "data:image/png;base64," + String(repeating: "A", count: 32)
        guard case .failure(let f) = ImageInput.parseDataURL(url, maxBase64Bytes: 16) else {
            throw TestFailure("expected failure")
        }
        try assertEqual(f, .tooLarge(limitBytes: 16))
        try assertTrue(f.message.contains("exceeds"), f.message)
    }

    test("default base64 cap is 20 MB") {
        try assertEqual(ImageInput.maxBase64Bytes, 20 * 1024 * 1024)
    }

    // MARK: ContentPart image_url decode/encode

    test("ContentPart decodes image_url with url and optional detail") {
        let json = #"[{"type":"text","text":"hi"},{"type":"image_url","image_url":{"url":"data:image/png;base64,QQ==","detail":"low"}}]"#
        let parts = try JSONDecoder().decode([ContentPart].self, from: Data(json.utf8))
        try assertEqual(parts.count, 2)
        try assertEqual(parts[1].image_url?.url, "data:image/png;base64,QQ==")
        try assertEqual(parts[1].image_url?.detail, "low")
        try assertNil(parts[0].image_url)
    }

    test("ContentPart image_url roundtrips through encode") {
        let part = ContentPart(type: "image_url", text: nil, image_url: ImageURLContent(url: "data:image/png;base64,QQ==", detail: nil))
        let data = try JSONEncoder().encode(part)
        let decoded = try JSONDecoder().decode(ContentPart.self, from: data)
        try assertEqual(decoded, part)
    }

    test("ContentPart existing two-argument initializer still works") {
        let part = ContentPart(type: "text", text: "hello")
        try assertEqual(part.text, "hello")
        try assertNil(part.image_url)
    }

    // MARK: OpenAIMessage helpers

    test("textIgnoringImages joins text parts and skips image parts") {
        let msg = imageMessage(url: pngDataURL(), text: "describe this")
        try assertEqual(msg.textIgnoringImages, "describe this")
        try assertNil(msg.textContent, "textContent stays nil when images are present")
    }

    test("textIgnoringImages is nil for an image-only message") {
        let msg = imageMessage(url: pngDataURL(), text: nil)
        try assertNil(msg.textIgnoringImages)
    }

    test("imageParts returns the image_url payloads in order") {
        let msg = OpenAIMessage(role: "user", content: .parts([
            ContentPart(type: "image_url", text: nil, image_url: ImageURLContent(url: "data:a", detail: nil)),
            ContentPart(type: "text", text: "and"),
            ContentPart(type: "image_url", text: nil, image_url: ImageURLContent(url: "data:b", detail: "high")),
        ]))
        try assertEqual(msg.imageParts.map(\.url), ["data:a", "data:b"])
        try assertEqual(OpenAIMessage(role: "user", content: .text("plain")).imageParts.count, 0)
    }

    // MARK: ChatRequestValidator image policy

    test("validator: unsupported policy rejects images with the macOS 27 hint") {
        let req = chatRequest(messages: [imageMessage(url: pngDataURL())])
        let failure = ChatRequestValidator.validate(req, imagePolicy: .unsupported)
        try assertEqual(failure, .imageContent)
        let msg = failure!.message
        try assertTrue(msg.contains("Image content is not supported by the Apple on-device model"), msg)
        try assertTrue(msg.contains("image input requires macOS 27"), msg)
    }

    test("validator: single-argument validate keeps the unsupported-policy behavior") {
        let req = chatRequest(messages: [imageMessage(url: pngDataURL())])
        try assertEqual(ChatRequestValidator.validate(req), .imageContent)
    }

    test("validator: dataURL policy accepts a valid data-URL image with text") {
        let req = chatRequest(messages: [imageMessage(url: pngDataURL())])
        try assertNil(ChatRequestValidator.validate(req, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)))
    }

    test("validator: dataURL policy accepts an image-only last user message") {
        let req = chatRequest(messages: [imageMessage(url: pngDataURL(), text: nil)])
        try assertNil(ChatRequestValidator.validate(req, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)))
    }

    test("validator: dataURL policy rejects remote URLs with the on-device message") {
        let req = chatRequest(messages: [imageMessage(url: "https://example.com/a.png")])
        let failure = ChatRequestValidator.validate(req, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes))
        try assertEqual(failure, .imageInput(.remoteURL))
        try assertTrue(failure!.message.contains("apfel does not fetch remote images"), failure!.message)
    }

    test("validator: dataURL policy rejects file URLs and oversized payloads") {
        let fileReq = chatRequest(messages: [imageMessage(url: "file:///etc/passwd")])
        try assertEqual(
            ChatRequestValidator.validate(fileReq, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)),
            .imageInput(.localFile))
        let bigReq = chatRequest(messages: [imageMessage(url: pngDataURL(64))])
        try assertEqual(
            ChatRequestValidator.validate(bigReq, imagePolicy: .dataURL(maxBase64Bytes: 8)),
            .imageInput(.tooLarge(limitBytes: 8)))
    }

    test("validator: dataURL policy rejects image parts outside user messages") {
        let req = chatRequest(messages: [
            imageMessage(role: "assistant", url: pngDataURL()),
            OpenAIMessage(role: "user", content: .text("hi")),
        ])
        let failure = ChatRequestValidator.validate(req, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes))
        try assertEqual(failure, .imagePartInRole("assistant"))
        try assertTrue(failure!.message.contains("user"), failure!.message)
    }

    test("validator: dataURL policy rejects an image_url part with no url") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":[{"type":"image_url"}]}]}"#
        let req = try JSONDecoder().decode(ChatCompletionRequest.self, from: Data(json.utf8))
        try assertEqual(
            ChatRequestValidator.validate(req, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)),
            .imageInput(.missingURL))
    }

    test("validator: image failures are 400s with stable events") {
        let failure = ChatRequestValidationFailure.imageInput(.remoteURL)
        try assertEqual(failure.httpStatusCode, 400)
        try assertTrue(failure.event.contains("image"), failure.event)
        try assertEqual(ChatRequestValidationFailure.imagePartInRole("tool").httpStatusCode, 400)
    }

    // MARK: ApfelError.invalidImageInput

    test("ApfelError.invalidImageInput maps to a 400 invalid_request_error") {
        let err = ApfelError.invalidImageInput("could not decode image data")
        try assertEqual(err.httpStatusCode, 400)
        try assertEqual(err.openAIType, "invalid_request_error")
        try assertTrue(err.openAIMessage.contains("could not decode image data"), err.openAIMessage)
    }

    // MARK: BodyLimits

    test("vision request body limit is 24 MiB and the default stays 1 MiB") {
        try assertEqual(BodyLimits.visionMaxRequestBodyBytes, 24 * 1024 * 1024)
        try assertEqual(BodyLimits.maxRequestBodyBytes, 1024 * 1024)
    }

    // MARK: Responses API

    test("ResponsesInputItem captures input_image parts (string and object image_url)") {
        let json = #"{"role":"user","content":[{"type":"input_text","text":"color?"},{"type":"input_image","image_url":"data:image/png;base64,QQ==","detail":"auto"},{"type":"input_image","image_url":{"url":"data:image/jpeg;base64,QQ=="}}]}"#
        let item = try JSONDecoder().decode(ResponsesInputItem.self, from: Data(json.utf8))
        try assertEqual(item.imageParts.map(\.url), ["data:image/png;base64,QQ==", "data:image/jpeg;base64,QQ=="])
        try assertEqual(item.imageParts[0].detail, "auto")
        try assertTrue(item.hasNonTextParts, "input_image is still a non-text part")
        try assertEqual(item.unsupportedPartTypes, [])
    }

    test("ResponsesInputItem flags part types that are neither text nor image") {
        let json = #"{"role":"user","content":[{"type":"input_file","file_id":"f1"}]}"#
        let item = try JSONDecoder().decode(ResponsesInputItem.self, from: Data(json.utf8))
        try assertEqual(item.unsupportedPartTypes, ["input_file"])
    }

    test("ResponsesMapper maps input_image parts onto chat-style image_url parts") {
        let json = #"{"model":"apple-foundationmodel","input":[{"role":"user","content":[{"type":"input_text","text":"color?"},{"type":"input_image","image_url":"data:image/png;base64,QQ=="}]}]}"#
        let request = try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
        let messages = ResponsesMapper.messages(from: request)
        try assertEqual(messages.count, 1)
        guard case .parts(let parts) = messages[0].content else {
            throw TestFailure("expected parts content, got \(String(describing: messages[0].content))")
        }
        try assertEqual(parts.first?.text, "color?")
        try assertEqual(messages[0].imageParts.map(\.url), ["data:image/png;base64,QQ=="])
    }

    test("Responses validator: unsupported policy keeps rejecting input_image with the hint") {
        let json = #"{"model":"apple-foundationmodel","input":[{"role":"user","content":[{"type":"input_image","image_url":"data:image/png;base64,QQ=="}]}]}"#
        let request = try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
        let failure = ResponsesRequestValidator.validate(request, imagePolicy: .unsupported)
        try assertEqual(failure, .imageContent)
        try assertTrue(failure!.message.contains("image input requires macOS 27"), failure!.message)
        try assertEqual(ResponsesRequestValidator.validate(request), .imageContent, "old signature keeps old policy")
    }

    test("Responses validator: dataURL policy accepts a valid input_image and rejects remote URLs") {
        let good = #"{"model":"apple-foundationmodel","input":[{"role":"user","content":[{"type":"input_image","image_url":"data:image/png;base64,QQ=="}]}]}"#
        let goodReq = try JSONDecoder().decode(ResponsesRequest.self, from: Data(good.utf8))
        try assertNil(ResponsesRequestValidator.validate(goodReq, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)))

        let remote = #"{"model":"apple-foundationmodel","input":[{"role":"user","content":[{"type":"input_image","image_url":"https://example.com/x.png"}]}]}"#
        let remoteReq = try JSONDecoder().decode(ResponsesRequest.self, from: Data(remote.utf8))
        try assertEqual(
            ResponsesRequestValidator.validate(remoteReq, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes)),
            .imageInput(.remoteURL))
    }

    test("Responses validator: dataURL policy rejects non-image non-text parts by name") {
        let json = #"{"model":"apple-foundationmodel","input":[{"role":"user","content":[{"type":"input_file","file_id":"f1"},{"type":"input_text","text":"x"}]}]}"#
        let request = try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
        let failure = ResponsesRequestValidator.validate(request, imagePolicy: .dataURL(maxBase64Bytes: ImageInput.maxBase64Bytes))
        try assertEqual(failure, .unsupportedContentPart("input_file"))
        try assertTrue(failure!.message.contains("input_file"), failure!.message)
    }
}
