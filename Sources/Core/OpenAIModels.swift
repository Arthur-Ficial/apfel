// ============================================================================
// OpenAIModels.swift — Pure OpenAI-compatible request and tool calling types
// Part of ApfelCore — shared between the executable and the test runner
// ============================================================================

import Foundation

public struct ChatCompletionRequest: Decodable, Sendable {
    public let model: String
    public let messages: [OpenAIMessage]
    public let stream: Bool?
    public let stream_options: StreamOptions?
    public let temperature: Double?
    public let max_tokens: Int?
    public let seed: Int?
    public let tools: [OpenAITool]?
    public let tool_choice: ToolChoice?
    public let response_format: ResponseFormat?
    public let logprobs: Bool?
    public let n: Int?
    public let stop: RawJSON?
    public let presence_penalty: Double?
    public let frequency_penalty: Double?
    public let user: String?
    public let x_context_strategy: String?
    public let x_context_max_turns: Int?
    public let x_context_output_reserve: Int?
}

public struct StreamOptions: Decodable, Sendable, Equatable {
    public let include_usage: Bool?
}

public struct OpenAIMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: MessageContent?
    public let tool_calls: [ToolCall]?
    public let tool_call_id: String?
    public let name: String?
    public let refusal: String?      // required by OpenAI spec, always null for our model

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

    public var containsImageContent: Bool {
        guard case .parts(let parts) = content else { return false }
        return parts.contains(where: { $0.type == "image_url" })
    }
}

public enum MessageContent: Codable, Sendable, Equatable {
    case text(String)
    case parts([ContentPart])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        self = .parts(try container.decode([ContentPart].self))
    }

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

public struct ContentPart: Codable, Sendable, Equatable {
    public let type: String
    public let text: String?

    public init(type: String, text: String?) {
        self.type = type
        self.text = text
    }
}

public struct OpenAITool: Decodable, Sendable {
    public let type: String
    public let function: OpenAIFunction

    public init(type: String, function: OpenAIFunction) {
        self.type = type
        self.function = function
    }
}

public struct OpenAIFunction: Decodable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: RawJSON?

    public init(name: String, description: String?, parameters: RawJSON?) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Stores arbitrary JSON as a raw string — used for tool parameter schemas.
public struct RawJSON: Decodable, Sendable, Equatable {
    public let value: String

    public init(rawValue: String) {
        self.value = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(AnyCodable.self)
        let data = try JSONEncoder().encode(raw)
        value = String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: ToolCallFunction

    public init(id: String, type: String, function: ToolCallFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ToolCallFunction: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

public enum ToolChoice: Decodable, Sendable, Equatable {
    case auto
    case none
    case required
    case specific(name: String)

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

public struct ResponseFormat: Decodable, Sendable, Equatable {
    public let type: String
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
