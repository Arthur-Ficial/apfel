// ============================================================================
// Models.swift — Data types for CLI, server, and OpenAI API responses
// ============================================================================

import Foundation

// MARK: - CLI Response Types

struct ApfelResponse: Encodable {
    let model: String
    let content: String
    let metadata: Metadata
    struct Metadata: Encodable {
        let onDevice: Bool
        let version: String
        enum CodingKeys: String, CodingKey { case onDevice = "on_device"; case version }
    }
}

struct ChatMessage: Encodable {
    let role: String
    let content: String
    let model: String?
}

// MARK: - OpenAI Request

struct ChatCompletionRequest: Decodable, Sendable {
    let model: String
    let messages: [OpenAIMessage]
    let stream: Bool?
    let temperature: Double?
    let max_tokens: Int?
    let seed: Int?
    let tools: [OpenAITool]?
    let tool_choice: ToolChoice?
    let response_format: ResponseFormat?
    // Recognized for compatibility / explicit validation:
    let logprobs: Bool?
    let n: Int?
    let stop: RawJSON?
    let presence_penalty: Double?
    let frequency_penalty: Double?
    let user: String?
    // Context management extensions
    let x_context_strategy: String?
    let x_context_max_turns: Int?
    let x_context_output_reserve: Int?
}

// MARK: - OpenAI Message (supports string content, content array, and tool calls)

struct OpenAIMessage: Codable, Sendable {
    let role: String
    let content: MessageContent?     // null when assistant has tool_calls
    let tool_calls: [ToolCall]?
    let tool_call_id: String?        // for role="tool"
    let name: String?

    init(role: String, content: MessageContent?, tool_calls: [ToolCall]? = nil,
         tool_call_id: String? = nil, name: String? = nil) {
        self.role = role; self.content = content; self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id; self.name = name
    }

    /// Plain text extracted from any content variant. Returns nil if images are present.
    var textContent: String? {
        switch content {
        case .text(let s): return s
        case .parts(let parts):
            if parts.contains(where: { $0.type == "image_url" }) { return nil }
            return parts.compactMap(\.text).joined()
        case .none: return nil
        }
    }
}

enum MessageContent: Codable, Sendable {
    case text(String)
    case parts([ContentPart])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .text(s); return }
        self = .parts(try c.decode([ContentPart].self))
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .text(let s): try c.encode(s); case .parts(let p): try c.encode(p) }
    }
}

struct ContentPart: Codable, Sendable {
    let type: String    // "text" or "image_url"
    let text: String?
}

// MARK: - OpenAI Response

struct ChatCompletionResponse: Encodable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage

    struct Choice: Encodable, Sendable {
        let index: Int
        let message: OpenAIMessage
        let finish_reason: String    // "stop" | "tool_calls" | "length" | "content_filter"
    }
    struct Usage: Encodable, Sendable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

// MARK: - OpenAI Streaming Chunk

struct ChatCompletionChunk: Encodable, Sendable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChunkChoice]

    struct ChunkChoice: Encodable, Sendable {
        let index: Int
        let delta: Delta
        let finish_reason: String?
    }
    struct Delta: Encodable, Sendable {
        let role: String?
        let content: String?
        let tool_calls: [ToolCall]?
    }
}

// MARK: - OpenAI Error

struct OpenAIErrorResponse: Encodable, Sendable {
    let error: ErrorDetail
    struct ErrorDetail: Encodable, Sendable {
        let message: String
        let type: String
        let param: String?
        let code: String?
    }
}

// MARK: - Models List

struct ModelsListResponse: Encodable, Sendable {
    let object: String
    let data: [ModelObject]

    struct ModelObject: Encodable, Sendable {
        let id: String
        let object: String
        let created: Int
        let owned_by: String
        let context_window: Int
        let supported_parameters: [String]
        let unsupported_parameters: [String]
        let notes: String
    }
}

// Token counting is handled by TokenCounter.swift (real API: see open-tickets/TICKET-001).
