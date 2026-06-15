// ============================================================================
// AnthropicModelsTests.swift — Decode/encode wire-format lockdown for the
// Anthropic Messages API types in ApfelCore.
// ============================================================================

import Foundation
import ApfelCore

private func decodeAnthropic<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

private func encodeSorted<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(data: try encoder.encode(value), encoding: .utf8) ?? ""
}

func runAnthropicModelsTests() {

    // MARK: - Request decoding

    test("AnthropicMessagesRequest decodes basic plain request") {
        let json = #"{"model":"claude-sonnet-4-6","max_tokens":1024,"messages":[{"role":"user","content":"Say hi"}]}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.model, "claude-sonnet-4-6")
        try assertEqual(req.maxTokens, 1024)
        try assertEqual(req.messages.count, 1)
        try assertEqual(req.messages[0].role, "user")
        try assertEqual(req.messages[0].content.asBlocks.count, 1)
        if case .text(let t) = req.messages[0].content.asBlocks[0] {
            try assertEqual(t, "Say hi")
        } else {
            throw TestFailure("expected text block")
        }
    }

    test("AnthropicMessagesRequest decodes string-shorthand content") {
        let json = #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"bare string"}]}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        if case .text(let t) = req.messages[0].content {
            try assertEqual(t, "bare string")
        } else {
            throw TestFailure("expected .text shorthand")
        }
    }

    test("AnthropicMessagesRequest decodes block-array content") {
        let json = #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":[{"type":"text","text":"hello"}]}]}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        if case .blocks(let b) = req.messages[0].content {
            try assertEqual(b.count, 1)
        } else {
            throw TestFailure("expected .blocks")
        }
    }

    test("AnthropicMessagesRequest decodes system string") {
        let json = #"{"model":"m","max_tokens":10,"system":"You are terse.","messages":[{"role":"user","content":"hi"}]}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.system, "You are terse.")
    }

    test("AnthropicMessagesRequest decodes streaming flag") {
        let json = #"{"model":"m","max_tokens":10,"stream":true,"messages":[{"role":"user","content":"hi"}]}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.stream, true)
    }

    test("AnthropicMessagesRequest decodes tools with input_schema") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],
        "tools":[{"name":"calc","description":"adds","input_schema":{"type":"object","properties":{"a":{"type":"number"}}}}]}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.tools?.count, 1)
        try assertEqual(req.tools?[0].name, "calc")
        try assertEqual(req.tools?[0].description, "adds")
        let schema = try unwrapModels(req.tools?[0].inputSchema, "expected input_schema")
        let parsed = try JSONSerialization.jsonObject(with: Data(schema.value.utf8)) as? [String: Any]
        try assertEqual(parsed?["type"] as? String, "object")
    }

    test("AnthropicMessagesRequest decodes tool_choice variants") {
        let any = try decodeAnthropic(AnthropicMessagesRequest.self,
            from: #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"any"}}"#)
        try assertEqual(any.toolChoice, .any)
        let none = try decodeAnthropic(AnthropicMessagesRequest.self,
            from: #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"none"}}"#)
        try assertEqual(none.toolChoice, AnthropicToolChoice.none)
        let tool = try decodeAnthropic(AnthropicMessagesRequest.self,
            from: #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"tool","name":"calc"}}"#)
        try assertEqual(tool.toolChoice, .tool(name: "calc"))
    }

    test("AnthropicMessagesRequest decodes tool_use history block") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"calc","input":{"a":2}}]}]}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        guard case .toolUse(let id, let name, let input) = req.messages[0].content.asBlocks[0] else {
            throw TestFailure("expected tool_use block")
        }
        try assertEqual(id, "toolu_1")
        try assertEqual(name, "calc")
        try assertTrue(input.value.contains("\"a\""))
    }

    test("AnthropicMessagesRequest decodes tool_result with string content") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"4"}]}]}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        guard case .toolResult(let tid, let content, let isError) = req.messages[0].content.asBlocks[0] else {
            throw TestFailure("expected tool_result block")
        }
        try assertEqual(tid, "toolu_1")
        try assertEqual(content, "4")
        try assertEqual(isError, false)
    }

    test("AnthropicMessagesRequest decodes tool_result with block content and is_error") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"t","is_error":true,"content":[{"type":"text","text":"boom"}]}]}]}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        guard case .toolResult(_, let content, let isError) = req.messages[0].content.asBlocks[0] else {
            throw TestFailure("expected tool_result block")
        }
        try assertEqual(content, "boom")
        try assertEqual(isError, true)
    }

    test("AnthropicMessagesRequest decodes image block without crashing") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"AAAA"}}]}]}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        guard case .image(let media, let data) = req.messages[0].content.asBlocks[0] else {
            throw TestFailure("expected image block")
        }
        try assertEqual(media, "image/png")
        try assertEqual(data, "AAAA")
    }

    test("AnthropicMessagesRequest decodes structured output config") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],
        "output_config":{"effort":"high","format":{"type":"json_schema","schema":{"type":"object"}}}}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.outputConfig?.effort, "high")
        try assertEqual(req.outputConfig?.format?.type, "json_schema")
        try assertNotNil(req.outputConfig?.format?.schema)
    }

    test("AnthropicMessagesRequest accepts and ignores thinking and cache_control") {
        let json = #"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],
        "thinking":{"type":"adaptive"},"cache_control":{"type":"ephemeral"}}
        """#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.thinking?.type, "adaptive")
        try assertEqual(req.cacheControl?.type, "ephemeral")
    }

    test("AnthropicMessagesRequest decodes temperature, top_p, top_k") {
        let json = #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"temperature":0.5,"top_p":0.9,"top_k":40}"#
        let req = try decodeAnthropic(AnthropicMessagesRequest.self, from: json)
        try assertEqual(req.temperature, 0.5)
        try assertEqual(req.topP, 0.9)
        try assertEqual(req.topK, 40)
    }

    // MARK: - Response encoding

    test("AnthropicMessagesResponse encodes required fields with usage") {
        let resp = AnthropicMessagesResponse(
            id: "msg_1", model: "claude-sonnet-4-6",
            content: [.text("hi there")],
            stopReason: "end_turn",
            usage: AnthropicUsage(inputTokens: 5, outputTokens: 3)
        )
        let json = try encodeSorted(resp)
        try assertTrue(json.contains("\"id\":\"msg_1\""))
        try assertTrue(json.contains("\"type\":\"message\""))
        try assertTrue(json.contains("\"role\":\"assistant\""))
        try assertTrue(json.contains("\"model\":\"claude-sonnet-4-6\""))
        try assertTrue(json.contains("\"stop_reason\":\"end_turn\""))
        try assertTrue(json.contains("\"stop_sequence\":null"))
        try assertTrue(json.contains("\"input_tokens\":5"))
        try assertTrue(json.contains("\"output_tokens\":3"))
        try assertTrue(json.contains("\"type\":\"text\""))
        try assertTrue(json.contains("\"text\":\"hi there\""))
    }

    test("AnthropicResponseBlock tool_use encodes input as live JSON object") {
        let block = AnthropicResponseBlock.toolUse(id: "toolu_9", name: "calc", input: RawJSON(rawValue: #"{"a":2,"b":3}"#))
        let json = try encodeSorted(block)
        try assertTrue(json.contains("\"type\":\"tool_use\""))
        try assertTrue(json.contains("\"id\":\"toolu_9\""))
        try assertTrue(json.contains("\"name\":\"calc\""))
        // input must be a real object, not a stringified blob
        try assertTrue(json.contains("\"input\":{"))
        try assertTrue(json.contains("\"a\":2"))
    }

    test("AnthropicErrorEnvelope encodes type/error/request_id") {
        let env = AnthropicErrorEnvelope(errorType: "invalid_request_error", message: "context too big", requestId: "req_abc")
        let json = try encodeSorted(env)
        try assertTrue(json.contains("\"type\":\"error\""))
        try assertTrue(json.contains("\"request_id\":\"req_abc\""))
        try assertTrue(json.contains("\"message\":\"context too big\""))
        try assertTrue(json.contains("\"type\":\"invalid_request_error\""))
    }

    // MARK: - SSE event encoding

    test("message_start event carries usage with output_tokens 0") {
        let e = AnthropicMessageStartEvent(id: "msg_1", model: "claude-x", inputTokens: 7)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"message_start\""))
        try assertTrue(json.contains("\"input_tokens\":7"))
        try assertTrue(json.contains("\"output_tokens\":0"))
        try assertTrue(json.contains("\"model\":\"claude-x\""))
        try assertTrue(json.contains("\"content\":[]"))
        try assertTrue(json.contains("\"stop_reason\":null"))
    }

    test("content_block_start text event") {
        let e = AnthropicContentBlockStartEvent(index: 0, contentBlock: .text)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"content_block_start\""))
        try assertTrue(json.contains("\"index\":0"))
        try assertTrue(json.contains("\"content_block\":{"))
        try assertTrue(json.contains("\"text\":\"\""))
    }

    test("content_block_start tool_use event has empty input object") {
        let e = AnthropicContentBlockStartEvent(index: 1, contentBlock: .toolUse(id: "toolu_2", name: "calc"))
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"tool_use\""))
        try assertTrue(json.contains("\"id\":\"toolu_2\""))
        try assertTrue(json.contains("\"input\":{}"))
    }

    test("content_block_delta text_delta event") {
        let e = AnthropicContentBlockDeltaEvent.text(index: 0, text: "Hello")
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"content_block_delta\""))
        try assertTrue(json.contains("\"type\":\"text_delta\""))
        try assertTrue(json.contains("\"text\":\"Hello\""))
    }

    test("content_block_delta input_json_delta event") {
        let e = AnthropicContentBlockDeltaEvent.inputJSON(index: 0, partialJSON: #"{"a":"#)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"input_json_delta\""))
        try assertTrue(json.contains("\"partial_json\""))
    }

    test("content_block_stop event") {
        let e = AnthropicContentBlockStopEvent(index: 0)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"content_block_stop\""))
        try assertTrue(json.contains("\"index\":0"))
    }

    test("message_delta event has required output_tokens usage") {
        let e = AnthropicMessageDeltaEvent(stopReason: "end_turn", outputTokens: 12)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"message_delta\""))
        try assertTrue(json.contains("\"stop_reason\":\"end_turn\""))
        try assertTrue(json.contains("\"output_tokens\":12"))
    }

    test("message_delta tool_use stop reason") {
        let e = AnthropicMessageDeltaEvent(stopReason: "tool_use", outputTokens: 4)
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"stop_reason\":\"tool_use\""))
    }

    test("message_stop and ping events") {
        try assertTrue(try encodeSorted(AnthropicMessageStopEvent()).contains("\"type\":\"message_stop\""))
        try assertTrue(try encodeSorted(AnthropicPingEvent()).contains("\"type\":\"ping\""))
    }

    test("error SSE event encodes nested error detail") {
        let e = AnthropicErrorEvent(errorType: "api_error", message: "boom")
        let json = try encodeSorted(e)
        try assertTrue(json.contains("\"type\":\"error\""))
        try assertTrue(json.contains("\"type\":\"api_error\""))
        try assertTrue(json.contains("\"message\":\"boom\""))
    }
}

private func unwrapModels<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message) }
    return value
}
