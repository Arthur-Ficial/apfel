// ============================================================================
// Models.swift — Data types for CLI, server, and OpenAI API responses
// ============================================================================

import Foundation
import ApfelCore

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
        let logprobs: String?        // always null for Apple's on-device model

        // OpenAI spec requires `logprobs: null` to be explicitly present.
        // Swift's synthesized Encodable omits nil optionals, so we encode manually.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(index, forKey: .index)
            try c.encode(message, forKey: .message)
            try c.encode(finish_reason, forKey: .finish_reason)
            try c.encodeNil(forKey: .logprobs)
        }
        private enum CodingKeys: String, CodingKey {
            case index, message, finish_reason, logprobs
        }
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
    let usage: ChunkUsage?

    struct ChunkChoice: Encodable, Sendable {
        let index: Int
        let delta: Delta
        let finish_reason: String?
        let logprobs: String?        // always null for Apple's on-device model

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(index, forKey: .index)
            try c.encode(delta, forKey: .delta)
            try c.encode(finish_reason, forKey: .finish_reason)
            try c.encodeNil(forKey: .logprobs)
        }
        private enum CodingKeys: String, CodingKey {
            case index, delta, finish_reason, logprobs
        }
    }
    struct Delta: Encodable, Sendable {
        let role: String?
        let content: String?
        let tool_calls: [ToolCallDelta]?
        let refusal: String?
        init(role: String?, content: String?, tool_calls: [ToolCallDelta]?, refusal: String? = nil) {
            self.role = role
            self.content = content
            self.tool_calls = tool_calls
            self.refusal = refusal
        }
    }
    struct ToolCallDelta: Encodable, Sendable {
        let index: Int
        let id: String?
        let type: String?
        let function: ToolCallFunction?
    }
    struct ChunkUsage: Encodable, Sendable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
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
