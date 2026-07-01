// ============================================================================
// SSE.swift — Server-Sent Events streaming for OpenAI-compatible responses
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation
import ApfelCore

/// Format a single SSE data line from a ChatCompletionChunk.
/// Returns: "data: {json}\n\n"
func sseDataLine(_ chunk: ChatCompletionChunk) -> String {
    let json = jsonString(chunk, pretty: false)
    return "data: \(json)\n\n"
}

/// The SSE termination marker.
let sseDone = "data: [DONE]\n\n"

/// Create the initial SSE chunk that announces the assistant role.
///
/// `includeUsage` emits explicit `usage: null` on this non-final chunk when the
/// client opted into `stream_options.include_usage` (#238).
func sseRoleChunk(id: String, created: Int, includeUsage: Bool = false) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: "assistant", content: nil, tool_calls: nil),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil,
        includeUsageNull: includeUsage
    )
}

/// Create a content delta SSE chunk.
func sseContentChunk(id: String, created: Int, content: String, includeUsage: Bool = false) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: nil, content: content, tool_calls: nil),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil,
        includeUsageNull: includeUsage
    )
}

/// Create a refusal delta SSE chunk (streams the model's refusal text).
func sseRefusalChunk(id: String, created: Int, refusal: String, includeUsage: Bool = false) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(refusal: refusal),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil,
        includeUsageNull: includeUsage
    )
}

/// Create the final SSE chunk that carries `finish_reason: "content_filter"`.
func sseContentFilterFinishChunk(id: String, created: Int, includeUsage: Bool = false) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(),
            finish_reason: FinishReason.contentFilter.openAIValue,
            logprobs: nil
        )],
        usage: nil,
        includeUsageNull: includeUsage
    )
}

/// Create a usage-only SSE chunk (empty choices, usage stats).
func sseUsageChunk(id: String, created: Int, promptTokens: Int, completionTokens: Int) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [],
        usage: .init(
            prompt_tokens: promptTokens,
            completion_tokens: completionTokens,
            total_tokens: promptTokens + completionTokens
        )
    )
}
