// ============================================================================
// AnthropicSSETests.swift — exact SSE byte-frame lockdown for /v1/messages.
// Tests the pure AnthropicSSEFormatter (frame = "event: ...\ndata: ...\n\n").
// ============================================================================

import Foundation
import ApfelCore

func runAnthropicSSETests() {

    test("frame wraps event name and compact JSON with trailing blank line") {
        let frame = AnthropicSSEFormatter.frame(event: "message_stop", json: AnthropicMessageStopEvent())
        try assertEqual(frame, "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n")
    }

    test("ping frame exact bytes") {
        let frame = AnthropicSSEFormatter.frame(event: "ping", json: AnthropicPingEvent())
        try assertEqual(frame, "event: ping\ndata: {\"type\":\"ping\"}\n\n")
    }

    test("message_start frame begins with event line and contains usage") {
        let frame = AnthropicSSEFormatter.frame(
            event: "message_start",
            json: AnthropicMessageStartEvent(id: "msg_1", model: "claude-x", inputTokens: 3))
        try assertTrue(frame.hasPrefix("event: message_start\ndata: {"))
        try assertTrue(frame.hasSuffix("}\n\n"))
        try assertTrue(frame.contains("\"output_tokens\":0"))
        try assertTrue(frame.contains("\"input_tokens\":3"))
    }

    test("content_block_start text frame exact shape") {
        let frame = AnthropicSSEFormatter.frame(
            event: "content_block_start",
            json: AnthropicContentBlockStartEvent(index: 0, contentBlock: .text))
        try assertTrue(frame.hasPrefix("event: content_block_start\ndata: {"))
        try assertTrue(frame.contains("\"index\":0"))
        try assertTrue(frame.contains("\"text\":\"\""))
    }

    test("content_block_delta text frame exact shape") {
        let frame = AnthropicSSEFormatter.frame(
            event: "content_block_delta",
            json: AnthropicContentBlockDeltaEvent.text(index: 0, text: "Hi"))
        try assertTrue(frame.hasPrefix("event: content_block_delta\ndata: {"))
        try assertTrue(frame.contains("\"type\":\"text_delta\""))
        try assertTrue(frame.contains("\"text\":\"Hi\""))
    }

    test("content_block_delta input_json frame uses partial_json") {
        let frame = AnthropicSSEFormatter.frame(
            event: "content_block_delta",
            json: AnthropicContentBlockDeltaEvent.inputJSON(index: 0, partialJSON: #"{"a":2}"#))
        try assertTrue(frame.contains("\"type\":\"input_json_delta\""))
        try assertTrue(frame.contains("\"partial_json\""))
    }

    test("content_block_stop frame exact bytes") {
        let frame = AnthropicSSEFormatter.frame(event: "content_block_stop", json: AnthropicContentBlockStopEvent(index: 0))
        try assertEqual(frame, "event: content_block_stop\ndata: {\"index\":0,\"type\":\"content_block_stop\"}\n\n")
    }

    test("message_delta frame contains stop_reason and output_tokens") {
        let frame = AnthropicSSEFormatter.frame(
            event: "message_delta",
            json: AnthropicMessageDeltaEvent(stopReason: "end_turn", outputTokens: 9))
        try assertTrue(frame.hasPrefix("event: message_delta\ndata: {"))
        try assertTrue(frame.contains("\"stop_reason\":\"end_turn\""))
        try assertTrue(frame.contains("\"output_tokens\":9"))
    }

    test("error frame contains nested error detail") {
        let frame = AnthropicSSEFormatter.frame(
            event: "error",
            json: AnthropicErrorEvent(errorType: "api_error", message: "boom"))
        try assertTrue(frame.hasPrefix("event: error\ndata: {"))
        try assertTrue(frame.contains("\"type\":\"api_error\""))
        try assertTrue(frame.contains("\"message\":\"boom\""))
    }

    test("compactJSON does not escape forward slashes") {
        let json = AnthropicSSEFormatter.compactJSON(AnthropicContentBlockDeltaEvent.text(index: 0, text: "a/b"))
        try assertTrue(json.contains("a/b"))
        try assertTrue(!json.contains("a\\/b"))
    }
}
