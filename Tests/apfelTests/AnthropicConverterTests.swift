// ============================================================================
// AnthropicConverterTests.swift — AnthropicMessagesRequest -> ChatCompletionRequest
// ============================================================================

import Foundation
import ApfelCore

private func decodeReq(_ json: String) throws -> AnthropicMessagesRequest {
    try JSONDecoder().decode(AnthropicMessagesRequest.self, from: Data(json.utf8))
}

func runAnthropicConverterTests() {

    test("converter maps system string to leading system message") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"system":"Be terse.","messages":[{"role":"user","content":"hi"}]}"#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.messages.first?.role, "system")
        try assertEqual(chat.messages.first?.textContent, "Be terse.")
        try assertEqual(chat.messages.last?.role, "user")
        try assertEqual(chat.messages.last?.textContent, "hi")
    }

    test("converter omits system message when absent") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}"#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.messages.count, 1)
        try assertEqual(chat.messages[0].role, "user")
    }

    test("converter echoes model string through") {
        let req = try decodeReq(#"{"model":"claude-sonnet-4-6","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}"#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.model, "claude-sonnet-4-6")
    }

    test("converter joins text blocks into one user message") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}]}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.messages.last?.textContent, "ab")
    }

    test("converter maps assistant tool_use to tool_calls") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"calc","input":{"a":2}}]},
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"4"}]}]}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        let assistant = chat.messages.first { $0.role == "assistant" }
        try assertNotNil(assistant?.tool_calls)
        try assertEqual(assistant?.tool_calls?.first?.id, "toolu_1")
        try assertEqual(assistant?.tool_calls?.first?.function.name, "calc")
        try assertTrue(assistant?.tool_calls?.first?.function.arguments.contains("\"a\"") == true)
    }

    test("converter maps tool_result to a tool-role message") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"4"}]}]}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        let toolMsg = chat.messages.first { $0.role == "tool" }
        try assertNotNil(toolMsg)
        try assertEqual(toolMsg?.tool_call_id, "toolu_1")
        try assertEqual(toolMsg?.textContent, "4")
    }

    test("converter renders image block as text placeholder, never crashes") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"AAAA"}}]}]}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.messages.last?.role, "user")
        try assertTrue(chat.messages.last?.textContent?.contains("image") == true)
    }

    test("converter maps tools to OpenAITool function definitions") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],
        "tools":[{"name":"calc","description":"adds","input_schema":{"type":"object"}}]}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.tools?.count, 1)
        try assertEqual(chat.tools?[0].type, "function")
        try assertEqual(chat.tools?[0].function.name, "calc")
        try assertEqual(chat.tools?[0].function.description, "adds")
        try assertNotNil(chat.tools?[0].function.parameters)
    }

    test("converter maps tool_choice any to required") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"any"}}"#)
        try assertEqual(AnthropicConverter.toChatCompletionRequest(req).tool_choice, .required)
    }

    test("converter maps tool_choice none to none") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"none"}}"#)
        try assertEqual(AnthropicConverter.toChatCompletionRequest(req).tool_choice, ToolChoice.none)
    }

    test("converter maps tool_choice tool to specific") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"tool","name":"calc"}}"#)
        try assertEqual(AnthropicConverter.toChatCompletionRequest(req).tool_choice, .specific(name: "calc"))
    }

    test("converter maps tool_choice auto and absent to nil") {
        let autoReq = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"auto"}}"#)
        try assertNil(AnthropicConverter.toChatCompletionRequest(autoReq).tool_choice)
        let absentReq = try decodeReq(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}"#)
        try assertNil(AnthropicConverter.toChatCompletionRequest(absentReq).tool_choice)
    }

    test("converter maps output_config json_schema to response_format") {
        let req = try decodeReq(#"""
        {"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}],
        "output_config":{"format":{"type":"json_schema","schema":{"type":"object"}}}}
        """#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.response_format?.type, "json_schema")
        try assertNotNil(chat.response_format?.json_schema?.schema)
    }

    test("converter passes through temperature, top_p, max_tokens, stream") {
        let req = try decodeReq(#"{"model":"m","max_tokens":256,"stream":true,"messages":[{"role":"user","content":"hi"}],"temperature":0.3,"top_p":0.8}"#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.temperature, 0.3)
        try assertEqual(chat.top_p, 0.8)
        try assertEqual(chat.max_tokens, 256)
        try assertEqual(chat.stream, true)
    }

    test("converter produces a user-last message for plain chat (makeSession compatible)") {
        let req = try decodeReq(#"{"model":"m","max_tokens":10,"system":"sys","messages":[{"role":"user","content":"q1"},{"role":"assistant","content":"a1"},{"role":"user","content":"q2"}]}"#)
        let chat = AnthropicConverter.toChatCompletionRequest(req)
        try assertEqual(chat.messages.last?.role, "user")
        try assertEqual(chat.messages.last?.textContent, "q2")
    }
}
