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

/// JSON output for `apfel --count-tokens -o json`.
struct TokenBudgetJSONResponse: Encodable {
    let prompt_tokens: Int
    let system_tokens: Int
    let file_tokens: [FileEntry]
    let mcp_tool_tokens: Int
    let total: Int
    let budget: Int
    let output_reserve: Int
    let fits: Bool
    let approximate: Bool
    let context_size: Int

    struct FileEntry: Encodable {
        let path: String
        let tokens: Int
    }

    init(report: TokenBudgetReport) {
        prompt_tokens = report.promptTokens
        system_tokens = report.systemTokens
        file_tokens = report.fileTokens.map { FileEntry(path: $0.path, tokens: $0.tokens) }
        mcp_tool_tokens = report.mcpToolTokens
        total = report.total
        budget = report.budget
        output_reserve = report.outputReserve
        fits = report.fits
        approximate = report.approximate
        context_size = report.contextSize
    }
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
    /// Control flag (not a wire field). When true and `usage` is nil, the chunk
    /// encodes `"usage": null` explicitly. OpenAI sends `usage: null` on every
    /// non-final chunk when `stream_options.include_usage` is set; without the
    /// opt-in a nil usage is omitted entirely (#238).
    var includeUsageNull: Bool = false

    // Custom encoder so `usage` is emitted as explicit null only when opted in,
    // and omitted otherwise. Swift's synthesized Encodable would always drop a
    // nil optional, losing the include_usage null-usage contract.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(object, forKey: .object)
        try c.encode(created, forKey: .created)
        try c.encode(model, forKey: .model)
        try c.encode(choices, forKey: .choices)
        if let usage = usage {
            try c.encode(usage, forKey: .usage)
        } else if includeUsageNull {
            try c.encodeNil(forKey: .usage)
        }
    }
    private enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage
    }

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

        init(role: String? = nil, content: String? = nil, tool_calls: [ToolCallDelta]? = nil, refusal: String? = nil) {
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

        // OpenAI always emits `param` and `code` on the error object (as null
        // when absent). Swift's synthesized Encodable omits nil optionals, so
        // router/proxy front-ends that branch on error.code miss the key.
        // Encode both explicitly, using null when nil (#236).
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(message, forKey: .message)
            try c.encode(type, forKey: .type)
            if let param = param { try c.encode(param, forKey: .param) }
            else { try c.encodeNil(forKey: .param) }
            if let code = code { try c.encode(code, forKey: .code) }
            else { try c.encodeNil(forKey: .code) }
        }
        private enum CodingKeys: String, CodingKey {
            case message, type, param, code
        }
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
