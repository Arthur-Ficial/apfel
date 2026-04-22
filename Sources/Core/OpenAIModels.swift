// ============================================================================
// OpenAIModels.swift — Pure OpenAI-compatible request and tool calling types
// Part of ApfelCore — shared between the executable and the test runner
// ============================================================================

import Foundation

/// OpenAI-compatible chat-completions request payload.
public struct ChatCompletionRequest: Decodable, Sendable, Equatable, Hashable {
    /// The requested model name. ApfelCore accepts `apple-foundationmodel`.
    public let model: String
    /// The conversation transcript sent to the model.
    public let messages: [OpenAIMessage]
    /// Whether the caller requested streaming chunks.
    public let stream: Bool?
    /// Streaming-specific configuration.
    public let stream_options: StreamOptions?
    /// Sampling temperature override.
    public let temperature: Double?
    /// Maximum completion tokens requested by the client.
    public let max_tokens: Int?
    /// Optional deterministic seed request.
    public let seed: Int?
    /// Client-supplied tool definitions.
    public let tools: [OpenAITool]?
    /// How the client wants tool choice resolved.
    public let tool_choice: ToolChoice?
    /// Requested response-format contract.
    public let response_format: ResponseFormat?
    /// OpenAI logprobs request flag.
    public let logprobs: Bool?
    /// Number of requested completions.
    public let n: Int?
    /// Raw stop-sequence payload.
    public let stop: RawJSON?
    /// OpenAI presence-penalty override.
    public let presence_penalty: Double?
    /// OpenAI frequency-penalty override.
    public let frequency_penalty: Double?
    /// End-user identifier forwarded by the client.
    public let user: String?
    /// Requested context-trimming strategy override.
    public let x_context_strategy: String?
    /// Requested maximum conversation turns after trimming.
    public let x_context_max_turns: Int?
    /// Requested token reserve for the model's output.
    public let x_context_output_reserve: Int?

    /// Creates a chat-completions request value.
    public init(
        model: String,
        messages: [OpenAIMessage],
        stream: Bool? = nil,
        stream_options: StreamOptions? = nil,
        temperature: Double? = nil,
        max_tokens: Int? = nil,
        seed: Int? = nil,
        tools: [OpenAITool]? = nil,
        tool_choice: ToolChoice? = nil,
        response_format: ResponseFormat? = nil,
        logprobs: Bool? = nil,
        n: Int? = nil,
        stop: RawJSON? = nil,
        presence_penalty: Double? = nil,
        frequency_penalty: Double? = nil,
        user: String? = nil,
        x_context_strategy: String? = nil,
        x_context_max_turns: Int? = nil,
        x_context_output_reserve: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.stream_options = stream_options
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.seed = seed
        self.tools = tools
        self.tool_choice = tool_choice
        self.response_format = response_format
        self.logprobs = logprobs
        self.n = n
        self.stop = stop
        self.presence_penalty = presence_penalty
        self.frequency_penalty = frequency_penalty
        self.user = user
        self.x_context_strategy = x_context_strategy
        self.x_context_max_turns = x_context_max_turns
        self.x_context_output_reserve = x_context_output_reserve
    }
}

/// OpenAI `stream_options` payload.
public struct StreamOptions: Decodable, Sendable, Equatable, Hashable {
    /// Whether streaming responses should include a usage block.
    public let include_usage: Bool?

    /// Creates streaming options.
    public init(include_usage: Bool? = nil) {
        self.include_usage = include_usage
    }
}

/// OpenAI-compatible chat message.
public struct OpenAIMessage: Codable, Sendable, Equatable, Hashable {
    /// The OpenAI role string, such as `system`, `user`, `assistant`, or `tool`.
    public let role: String
    /// The message body, either as plain text or structured content parts.
    public let content: MessageContent?
    /// Tool calls requested by an assistant message.
    public let tool_calls: [ToolCall]?
    /// Tool-call identifier for tool-role messages.
    public let tool_call_id: String?
    /// Optional sender name.
    public let name: String?
    /// OpenAI refusal text. Always encoded as `null` for the local model.
    public let refusal: String?

    /// Creates an OpenAI-compatible message value.
    public init(
        role: String,
        content: MessageContent?,
        tool_calls: [ToolCall]? = nil,
        tool_call_id: String? = nil,
        name: String? = nil,
        refusal: String? = nil
    ) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.name = name
        self.refusal = refusal
    }

    // OpenAI spec requires `content` and `refusal` to always be present in
    // assistant-role response messages (as null when absent). Swift's
    // synthesized Encodable omits nil optionals, so we encode manually.
    // Decoding still uses the synthesized init (content/refusal are Optional).
    /// Encodes the message using OpenAI-compatible null-handling rules.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(role, forKey: .role)
        // content: always present (null when nil, string or array when set)
        if let content = content {
            try c.encode(content, forKey: .content)
        } else {
            try c.encodeNil(forKey: .content)
        }
        // These are truly optional per spec — omit when nil
        try c.encodeIfPresent(tool_calls, forKey: .tool_calls)
        try c.encodeIfPresent(tool_call_id, forKey: .tool_call_id)
        try c.encodeIfPresent(name, forKey: .name)
        // refusal: always present in responses (null when absent)
        try c.encodeNil(forKey: .refusal)
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, tool_calls, tool_call_id, name, refusal
    }

    /// Plain text extracted from any content variant. Returns nil if images are present.
    public var textContent: String? {
        switch content {
        case .text(let text):
            return text
        case .parts(let parts):
            var segments: [String] = []
            segments.reserveCapacity(parts.count)
            for part in parts {
                if part.type == "image_url" {
                    return nil
                }
                if let text = part.text {
                    segments.append(text)
                }
            }
            return segments.joined()
        case .none:
            return nil
        }
    }

    /// Whether the message contains image parts.
    public var containsImageContent: Bool {
        guard case .parts(let parts) = content else { return false }
        return parts.contains(where: { $0.type == "image_url" })
    }
}

/// OpenAI-compatible message content.
public enum MessageContent: Codable, Sendable, Equatable, Hashable {
    /// Plain text content.
    case text(String)
    /// Structured content parts.
    case parts([ContentPart])

    /// Decodes either a plain string or an array of structured parts.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        self = .parts(try container.decode([ContentPart].self))
    }

    /// Encodes the content in its wire-compatible representation.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

/// One structured content part within an OpenAI message.
public struct ContentPart: Codable, Sendable, Equatable, Hashable {
    /// The OpenAI part type, such as `text` or `image_url`.
    public let type: String
    /// The text payload for text parts.
    public let text: String?

    /// Creates a content part.
    public init(type: String, text: String?) {
        self.type = type
        self.text = text
    }
}

/// OpenAI-compatible tool definition.
public struct OpenAITool: Decodable, Sendable, Equatable, Hashable {
    /// The tool type. OpenAI-compatible tool-calling uses `function`.
    public let type: String
    /// The function-style tool metadata.
    public let function: OpenAIFunction

    /// Creates a tool definition.
    public init(type: String, function: OpenAIFunction) {
        self.type = type
        self.function = function
    }
}

/// OpenAI-compatible function definition nested under a tool.
public struct OpenAIFunction: Decodable, Sendable, Equatable, Hashable {
    /// The function name.
    public let name: String
    /// Human-readable tool description.
    public let description: String?
    /// Raw JSON Schema parameters for the tool.
    public let parameters: RawJSON?

    /// Creates a function definition.
    public init(name: String, description: String?, parameters: RawJSON?) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Stores arbitrary JSON as a raw string — used for tool parameter schemas.
public struct RawJSON: Decodable, Sendable, Equatable, Hashable {
    /// The raw JSON text.
    public let value: String

    /// Creates a raw JSON wrapper from already-serialized JSON text.
    public init(rawValue: String) {
        self.value = rawValue
    }

    /// Decodes arbitrary JSON and stores its canonical serialized form.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(AnyCodable.self)
        let data = try JSONEncoder().encode(raw)
        value = String(data: data, encoding: .utf8) ?? "{}"
    }
}

/// OpenAI-compatible tool-call payload.
public struct ToolCall: Codable, Sendable, Equatable, Hashable {
    /// Stable tool-call identifier.
    public let id: String
    /// The tool-call type. OpenAI-compatible tool-calling uses `function`.
    public let type: String
    /// Function invocation details.
    public let function: ToolCallFunction

    /// Creates a tool call.
    public init(id: String, type: String, function: ToolCallFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// OpenAI-compatible function invocation payload.
public struct ToolCallFunction: Codable, Sendable, Equatable, Hashable {
    /// The function name to invoke.
    public let name: String
    /// JSON-encoded argument object as a string.
    public let arguments: String

    /// Creates a function invocation payload.
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// OpenAI-compatible tool choice request.
public enum ToolChoice: Decodable, Sendable, Equatable, Hashable {
    /// Let the model decide whether to call tools.
    case auto
    /// Do not allow tool calls.
    case none
    /// Require the model to call a tool.
    case required
    /// Force a specific tool name.
    case specific(name: String)

    /// Decodes the OpenAI string-or-object tool choice format.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none":
                self = .none
            case "required":
                self = .required
            default:
                self = .auto
            }
            return
        }

        struct Specific: Decodable {
            struct Function: Decodable {
                let name: String
            }

            let function: Function
        }

        if let object = try? container.decode(Specific.self) {
            self = .specific(name: object.function.name)
            return
        }

        self = .auto
    }
}

/// OpenAI-compatible response-format request.
public struct ResponseFormat: Decodable, Sendable, Equatable, Hashable {
    /// The requested response format type, such as `text` or `json_object`.
    public let type: String

    /// Creates a response-format request.
    public init(type: String) {
        self.type = type
    }
}

// MARK: - Type-erased Codable for raw JSON schemas

struct AnyCodable: Codable, Sendable {
    let value: (any Sendable)?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil()                                    { value = nil; return }
        if let bool = try? container.decode(Bool.self)              { value = bool; return }
        if let int = try? container.decode(Int.self)                { value = int; return }
        if let double = try? container.decode(Double.self)          { value = double; return }
        if let string = try? container.decode(String.self)          { value = string; return }
        if let object = try? container.decode([String: AnyCodable].self) {
            value = object
            return
        }
        if let array = try? container.decode([AnyCodable].self) {
            value = array
            return
        }
        value = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let value else {
            try container.encodeNil()
            return
        }

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let object as [String: AnyCodable]:
            try container.encode(object)
        case let array as [AnyCodable]:
            try container.encode(array)
        default:
            try container.encodeNil()
        }
    }
}
