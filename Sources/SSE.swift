// ============================================================================
// SSE.swift — Server-Sent Events streaming for OpenAI-compatible responses
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation

/// Format a single SSE data line from a ChatCompletionChunk.
/// Returns: "data: {json}\n\n"
func sseDataLine(_ chunk: ChatCompletionChunk) -> String {
    let json = jsonString(chunk, pretty: false)
    return "data: \(json)\n\n"
}

/// The SSE termination marker.
let sseDone = "data: [DONE]\n\n"

/// Create the initial SSE chunk that announces the assistant role.
func sseRoleChunk(id: String, created: Int) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: "assistant", content: nil, refusal: nil, tool_calls: nil),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil
    )
}

/// Create a content delta SSE chunk.
func sseContentChunk(id: String, created: Int, content: String) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: nil, content: content, refusal: nil, tool_calls: nil),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil
    )
}

/// Create a refusal delta SSE chunk.
func sseRefusalChunk(id: String, created: Int, refusal: String) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: nil, content: nil, refusal: refusal, tool_calls: nil),
            finish_reason: nil,
            logprobs: nil
        )],
        usage: nil
    )
}

/// Create a finish chunk with a specific finish reason and no delta content.
func sseFinishChunk(id: String, created: Int, finishReason: String) -> ChatCompletionChunk {
    ChatCompletionChunk(
        id: id,
        object: "chat.completion.chunk",
        created: created,
        model: modelName,
        choices: [.init(
            index: 0,
            delta: .init(role: nil, content: nil, refusal: nil, tool_calls: nil),
            finish_reason: finishReason,
            logprobs: nil
        )],
        usage: nil
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
