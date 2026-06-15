// ============================================================================
// AnthropicModels.swift — Pure Anthropic Messages API request/response types
// Part of ApfelCore — shared between the executable and the test runner.
//
// These types model the wire contract emitted by the
// `anthropics/ClaudeForFoundationModels` Swift library (POST /v1/messages),
// so apfel can serve on-device FoundationModels answers to that client.
//
// Pure: no FoundationModels, no Hummingbird. Reuses `RawJSON` from
// OpenAIModels.swift for arbitrary JSON-Schema payloads.
// ============================================================================

import Foundation

// MARK: - Request

/// Anthropic Messages API request body (`POST /v1/messages`).
///
/// camelCase in Swift, snake_case on the wire. `messages[].content` decodes
/// either a bare string (shorthand) or an array of content blocks.
public struct AnthropicMessagesRequest: Decodable, Sendable, Equatable {
    /// Requested model name. apfel accepts ANY string and echoes it back.
    public let model: String
    /// Maximum tokens to generate. REQUIRED on the wire.
    public let maxTokens: Int?
    /// Optional system prompt (a plain string, not blocks).
    public let system: String?
    /// Conversation messages.
    public let messages: [AnthropicMessage]
    /// Optional client-supplied tool definitions.
    public let tools: [AnthropicTool]?
    /// Optional tool-choice directive.
    public let toolChoice: AnthropicToolChoice?
    /// Optional structured-output configuration.
    public let outputConfig: AnthropicOutputConfig?
    /// Optional adaptive-thinking directive. Accepted and IGNORED.
    public let thinking: AnthropicThinking?
    /// Optional cache-control directive. Accepted and IGNORED.
    public let cacheControl: AnthropicCacheControl?
    /// Sampling temperature override.
    public let temperature: Double?
    /// Nucleus (top-p) sampling threshold override.
    public let topP: Double?
    /// Top-k sampling override. Accepted; best-effort or ignored.
    public let topK: Int?
    /// Whether the caller requested streaming SSE frames.
    public let stream: Bool?

    public init(
        model: String,
        maxTokens: Int? = nil,
        system: String? = nil,
        messages: [AnthropicMessage],
        tools: [AnthropicTool]? = nil,
        toolChoice: AnthropicToolChoice? = nil,
        outputConfig: AnthropicOutputConfig? = nil,
        thinking: AnthropicThinking? = nil,
        cacheControl: AnthropicCacheControl? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.outputConfig = outputConfig
        self.thinking = thinking
        self.cacheControl = cacheControl
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stream = stream
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case tools
        case toolChoice = "tool_choice"
        case outputConfig = "output_config"
        case thinking
        case cacheControl = "cache_control"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
    }
}

/// One Anthropic message: a role plus string-or-block content.
public struct AnthropicMessage: Decodable, Sendable, Equatable {
    /// `"user"` or `"assistant"`.
    public let role: String
    /// Message content: either a bare string or an array of content blocks.
    public let content: AnthropicMessageContent

    public init(role: String, content: AnthropicMessageContent) {
        self.role = role
        self.content = content
    }
}

/// Anthropic message content — a bare string (shorthand) or a block array.
public enum AnthropicMessageContent: Decodable, Sendable, Equatable {
    /// Shorthand: `content: "some text"`.
    case text(String)
    /// Structured: `content: [ {type:"text", ...}, ... ]`.
    case blocks([AnthropicContentBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
            return
        }
        self = .blocks(try container.decode([AnthropicContentBlock].self))
    }

    /// The content as a normalized array of blocks (string shorthand becomes a single text block).
    public var asBlocks: [AnthropicContentBlock] {
        switch self {
        case .text(let s): return [.text(s)]
        case .blocks(let b): return b
        }
    }
}

/// An Anthropic content block in `messages[].content`.
public enum AnthropicContentBlock: Decodable, Sendable, Equatable {
    /// `{type:"text", text:String}`.
    case text(String)
    /// `{type:"image", source:{...}}` — apfel is text-only; parsed but not rendered.
    case image(mediaType: String, data: String)
    /// `{type:"tool_use", id, name, input}` — an assistant turn replayed from history.
    case toolUse(id: String, name: String, input: RawJSON)
    /// `{type:"tool_result", tool_use_id, content, is_error?}` — a user turn replayed from history.
    case toolResult(toolUseID: String, content: String, isError: Bool)

    private enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input
        case toolUseID = "tool_use_id"
        case content
        case isError = "is_error"
    }

    private struct ImageSource: Decodable {
        let media_type: String?
        let data: String?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try c.decodeIfPresent(String.self, forKey: .text) ?? "")
        case "image":
            let src = try c.decodeIfPresent(ImageSource.self, forKey: .source)
            self = .image(mediaType: src?.media_type ?? "", data: src?.data ?? "")
        case "tool_use":
            let id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
            let name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            let input = try c.decodeIfPresent(RawJSON.self, forKey: .input) ?? RawJSON(rawValue: "{}")
            self = .toolUse(id: id, name: name, input: input)
        case "tool_result":
            let toolUseID = try c.decodeIfPresent(String.self, forKey: .toolUseID) ?? ""
            let isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            self = .toolResult(toolUseID: toolUseID, content: AnthropicContentBlock.decodeResultContent(c), isError: isError)
        default:
            // Unknown block type — degrade to empty text rather than crash.
            self = .text("")
        }
    }

    /// `tool_result.content` may be a bare string OR an array of text blocks. Flatten to a string.
    private static func decodeResultContent(_ c: KeyedDecodingContainer<CodingKeys>) -> String {
        if let s = try? c.decode(String.self, forKey: .content) {
            return s
        }
        if let blocks = try? c.decode([AnthropicContentBlock].self, forKey: .content) {
            return blocks.map {
                if case .text(let t) = $0 { return t }
                return ""
            }.joined()
        }
        return ""
    }
}

/// An Anthropic tool definition (`tools[]`).
public struct AnthropicTool: Decodable, Sendable, Equatable {
    public let name: String
    public let description: String?
    /// The tool's JSON Schema (`input_schema`).
    public let inputSchema: RawJSON?

    public init(name: String, description: String?, inputSchema: RawJSON?) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

/// Anthropic tool-choice directive (`tool_choice`).
public enum AnthropicToolChoice: Decodable, Sendable, Equatable {
    /// `{type:"auto"}` — model decides.
    case auto
    /// `{type:"any"}` — model must call some tool.
    case any
    /// `{type:"none"}` — no tool calls.
    case none
    /// `{type:"tool", name:"x"}` — force a specific tool.
    case tool(name: String)

    private enum CodingKeys: String, CodingKey { case type, name }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? "auto"
        switch type {
        case "any": self = .any
        case "none": self = .none
        case "tool": self = .tool(name: (try? c.decode(String.self, forKey: .name)) ?? "")
        default: self = .auto
        }
    }
}

/// Anthropic structured-output configuration (`output_config`).
public struct AnthropicOutputConfig: Decodable, Sendable, Equatable {
    /// Optional effort hint. Accepted and IGNORED.
    public let effort: String?
    /// Optional output-format directive.
    public let format: Format?

    public init(effort: String? = nil, format: Format? = nil) {
        self.effort = effort
        self.format = format
    }

    /// `output_config.format = {type:"json_schema", schema:<JSON Schema>}`.
    public struct Format: Decodable, Sendable, Equatable {
        public let type: String
        public let schema: RawJSON?

        public init(type: String, schema: RawJSON?) {
            self.type = type
            self.schema = schema
        }
    }
}

/// Adaptive-thinking directive (`thinking`). Accepted and IGNORED.
public struct AnthropicThinking: Decodable, Sendable, Equatable {
    public let type: String?
    public init(type: String? = nil) { self.type = type }
}

/// Cache-control directive (`cache_control`). Accepted and IGNORED.
public struct AnthropicCacheControl: Decodable, Sendable, Equatable {
    public let type: String?
    public init(type: String? = nil) { self.type = type }
}

// MARK: - Response (non-streaming)

/// Anthropic Messages API non-streaming response body.
public struct AnthropicMessagesResponse: Encodable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let role: String
    public let model: String
    public let content: [AnthropicResponseBlock]
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: AnthropicUsage

    public init(
        id: String,
        model: String,
        content: [AnthropicResponseBlock],
        stopReason: String?,
        usage: AnthropicUsage,
        type: String = "message",
        role: String = "assistant",
        stopSequence: String? = nil
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.model = model
        self.content = content
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, role, model, content, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }

    // stop_reason / stop_sequence must always be present (null when nil).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(role, forKey: .role)
        try c.encode(model, forKey: .model)
        try c.encode(content, forKey: .content)
        if let stopReason { try c.encode(stopReason, forKey: .stopReason) }
        else { try c.encodeNil(forKey: .stopReason) }
        if let stopSequence { try c.encode(stopSequence, forKey: .stopSequence) }
        else { try c.encodeNil(forKey: .stopSequence) }
        try c.encode(usage, forKey: .usage)
    }
}

/// A response content block — text or a tool_use call.
public enum AnthropicResponseBlock: Encodable, Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: RawJSON)

    private enum CodingKeys: String, CodingKey { case type, text, id, name, input }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(AnthropicRawJSONValue(input), forKey: .input)
        }
    }
}

/// Anthropic token-usage block. Both fields always present.
public struct AnthropicUsage: Encodable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// Encodes a `RawJSON` value as live JSON (object/array/scalar) rather than a string.
struct AnthropicRawJSONValue: Encodable {
    let raw: RawJSON
    init(_ raw: RawJSON) { self.raw = raw }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: Data(raw.value.utf8))
        try container.encode(decoded)
    }
}

// MARK: - Error envelope

/// Anthropic error response body.
public struct AnthropicErrorEnvelope: Encodable, Sendable, Equatable {
    public let type: String
    public let error: Detail
    public let requestId: String

    public init(errorType: String, message: String, requestId: String) {
        self.type = "error"
        self.error = Detail(type: errorType, message: message)
        self.requestId = requestId
    }

    public struct Detail: Encodable, Sendable, Equatable {
        public let type: String
        public let message: String
    }

    private enum CodingKeys: String, CodingKey {
        case type, error
        case requestId = "request_id"
    }
}

// MARK: - Streaming events (Encodable wire shapes)

/// `message_start` event payload.
public struct AnthropicMessageStartEvent: Encodable, Sendable, Equatable {
    public let type = "message_start"
    public let message: StartMessage

    public init(id: String, model: String, inputTokens: Int) {
        self.message = StartMessage(id: id, model: model, inputTokens: inputTokens)
    }

    public struct StartMessage: Encodable, Sendable, Equatable {
        public let id: String
        public let type = "message"
        public let role = "assistant"
        public let model: String
        public let content: [AnthropicResponseBlock] = []
        public let stopReason: String? = nil
        public let stopSequence: String? = nil
        public let usage: AnthropicUsage

        init(id: String, model: String, inputTokens: Int) {
            self.id = id
            self.model = model
            self.usage = AnthropicUsage(inputTokens: inputTokens, outputTokens: 0)
        }

        private enum CodingKeys: String, CodingKey {
            case id, type, role, model, content, usage
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(type, forKey: .type)
            try c.encode(role, forKey: .role)
            try c.encode(model, forKey: .model)
            try c.encode(content, forKey: .content)
            try c.encodeNil(forKey: .stopReason)
            try c.encodeNil(forKey: .stopSequence)
            try c.encode(usage, forKey: .usage)
        }
    }
}

/// `content_block_start` event payload.
public struct AnthropicContentBlockStartEvent: Encodable, Sendable, Equatable {
    public let type = "content_block_start"
    public let index: Int
    public let contentBlock: AnthropicStreamBlock

    public init(index: Int, contentBlock: AnthropicStreamBlock) {
        self.index = index
        self.contentBlock = contentBlock
    }

    private enum CodingKeys: String, CodingKey {
        case type, index
        case contentBlock = "content_block"
    }
}

/// The block descriptor inside `content_block_start`.
public enum AnthropicStreamBlock: Encodable, Sendable, Equatable {
    /// Opening text block: `{type:"text", text:""}`.
    case text
    /// Opening tool_use block: `{type:"tool_use", id, name, input:{}}`.
    case toolUse(id: String, name: String)

    private enum CodingKeys: String, CodingKey { case type, text, id, name, input }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try c.encode("text", forKey: .type)
            try c.encode("", forKey: .text)
        case .toolUse(let id, let name):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(EmptyObject(), forKey: .input)
        }
    }

    private struct EmptyObject: Encodable {
        func encode(to encoder: Encoder) throws {
            _ = encoder.container(keyedBy: DummyKey.self)
        }
        private enum DummyKey: CodingKey {}
    }
}

/// `content_block_delta` event payload (text_delta or input_json_delta).
public struct AnthropicContentBlockDeltaEvent: Encodable, Sendable, Equatable {
    public let type = "content_block_delta"
    public let index: Int
    public let delta: Delta

    public static func text(index: Int, text: String) -> AnthropicContentBlockDeltaEvent {
        AnthropicContentBlockDeltaEvent(index: index, delta: .text(text))
    }

    public static func inputJSON(index: Int, partialJSON: String) -> AnthropicContentBlockDeltaEvent {
        AnthropicContentBlockDeltaEvent(index: index, delta: .inputJSON(partialJSON))
    }

    init(index: Int, delta: Delta) {
        self.index = index
        self.delta = delta
    }

    public enum Delta: Encodable, Sendable, Equatable {
        case text(String)
        case inputJSON(String)

        private enum CodingKeys: String, CodingKey {
            case type, text
            case partialJSON = "partial_json"
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let t):
                try c.encode("text_delta", forKey: .type)
                try c.encode(t, forKey: .text)
            case .inputJSON(let j):
                try c.encode("input_json_delta", forKey: .type)
                try c.encode(j, forKey: .partialJSON)
            }
        }
    }
}

/// `content_block_stop` event payload.
public struct AnthropicContentBlockStopEvent: Encodable, Sendable, Equatable {
    public let type = "content_block_stop"
    public let index: Int
    public init(index: Int) { self.index = index }
}

/// `message_delta` event payload — carries final stop_reason and output token usage.
public struct AnthropicMessageDeltaEvent: Encodable, Sendable, Equatable {
    public let type = "message_delta"
    public let delta: Delta
    public let usage: DeltaUsage

    public init(stopReason: String?, outputTokens: Int) {
        self.delta = Delta(stopReason: stopReason)
        self.usage = DeltaUsage(outputTokens: outputTokens)
    }

    public struct Delta: Encodable, Sendable, Equatable {
        public let stopReason: String?
        public let stopSequence: String? = nil

        private enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if let stopReason { try c.encode(stopReason, forKey: .stopReason) }
            else { try c.encodeNil(forKey: .stopReason) }
            try c.encodeNil(forKey: .stopSequence)
        }
    }

    public struct DeltaUsage: Encodable, Sendable, Equatable {
        public let outputTokens: Int
        private enum CodingKeys: String, CodingKey { case outputTokens = "output_tokens" }
    }
}

/// `message_stop` event payload.
public struct AnthropicMessageStopEvent: Encodable, Sendable, Equatable {
    public let type = "message_stop"
    public init() {}
}

/// `ping` event payload.
public struct AnthropicPingEvent: Encodable, Sendable, Equatable {
    public let type = "ping"
    public init() {}
}

/// SSE `error` event payload.
public struct AnthropicErrorEvent: Encodable, Sendable, Equatable {
    public let type = "error"
    public let error: AnthropicErrorEnvelope.Detail

    public init(errorType: String, message: String) {
        self.error = AnthropicErrorEnvelope.Detail(type: errorType, message: message)
    }
}

// MARK: - Pure SSE frame formatter

/// Pure helpers for building Anthropic SSE byte strings.
///
/// Kept in ApfelCore so the exact wire frames are unit-testable without
/// FoundationModels. The `apfel`-target `AnthropicSSE.swift` wraps these.
public enum AnthropicSSEFormatter {
    /// Compact, sorted-key JSON encoding for SSE payloads.
    public static func compactJSON(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    /// Build one full SSE frame: `event: <event>\ndata: <json>\n\n`.
    public static func frame(event: String, json: some Encodable) -> String {
        "event: \(event)\ndata: \(compactJSON(json))\n\n"
    }
}
