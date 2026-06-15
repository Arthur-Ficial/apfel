// ============================================================================
// AnthropicSSE.swift — Server-Sent Events builders for the Anthropic Messages
// API (`/v1/messages`). Thin wrappers over the pure AnthropicSSEFormatter in
// ApfelCore, mirroring Sources/SSE.swift for the OpenAI path.
// ============================================================================

import Foundation
import ApfelCore

/// `event: message_start\ndata: {...}\n\n`.
func anthropicMessageStartLine(id: String, model: String, inputTokens: Int) -> String {
    AnthropicSSEFormatter.frame(event: "message_start",
        json: AnthropicMessageStartEvent(id: id, model: model, inputTokens: inputTokens))
}

/// `event: content_block_start\ndata: {...}\n\n`.
func anthropicContentBlockStartLine(index: Int, block: AnthropicStreamBlock) -> String {
    AnthropicSSEFormatter.frame(event: "content_block_start",
        json: AnthropicContentBlockStartEvent(index: index, contentBlock: block))
}

/// `event: content_block_delta\ndata: {text_delta}\n\n`.
func anthropicTextDeltaLine(index: Int, text: String) -> String {
    AnthropicSSEFormatter.frame(event: "content_block_delta",
        json: AnthropicContentBlockDeltaEvent.text(index: index, text: text))
}

/// `event: content_block_delta\ndata: {input_json_delta}\n\n`.
func anthropicInputJSONDeltaLine(index: Int, partialJSON: String) -> String {
    AnthropicSSEFormatter.frame(event: "content_block_delta",
        json: AnthropicContentBlockDeltaEvent.inputJSON(index: index, partialJSON: partialJSON))
}

/// `event: content_block_stop\ndata: {...}\n\n`.
func anthropicContentBlockStopLine(index: Int) -> String {
    AnthropicSSEFormatter.frame(event: "content_block_stop",
        json: AnthropicContentBlockStopEvent(index: index))
}

/// `event: message_delta\ndata: {...}\n\n`.
func anthropicMessageDeltaLine(stopReason: String?, outputTokens: Int) -> String {
    AnthropicSSEFormatter.frame(event: "message_delta",
        json: AnthropicMessageDeltaEvent(stopReason: stopReason, outputTokens: outputTokens))
}

/// `event: message_stop\ndata: {...}\n\n`.
func anthropicMessageStopLine() -> String {
    AnthropicSSEFormatter.frame(event: "message_stop", json: AnthropicMessageStopEvent())
}

/// `event: ping\ndata: {...}\n\n`.
func anthropicPingLine() -> String {
    AnthropicSSEFormatter.frame(event: "ping", json: AnthropicPingEvent())
}

/// `event: error\ndata: {...}\n\n` — a mid-stream fatal error frame.
func anthropicErrorLine(errorType: String, message: String) -> String {
    AnthropicSSEFormatter.frame(event: "error",
        json: AnthropicErrorEvent(errorType: errorType, message: message))
}
