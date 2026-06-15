// ============================================================================
// AnthropicValidatorTests.swift — Pure validator for /v1/messages requests.
// ============================================================================

import Foundation
import ApfelCore

private func decodeReqV(_ json: String) throws -> AnthropicMessagesRequest {
    try JSONDecoder().decode(AnthropicMessagesRequest.self, from: Data(json.utf8))
}

func runAnthropicValidatorTests() {

    test("validator accepts a valid basic request") {
        let req = try decodeReqV(#"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}"#)
        try assertNil(AnthropicMessageValidator.validate(req))
    }

    test("validator rejects empty model") {
        let req = AnthropicMessagesRequest(model: "", maxTokens: 10, messages: [
            AnthropicMessage(role: "user", content: .text("hi"))
        ])
        try assertEqual(AnthropicMessageValidator.validate(req), .missingModel)
    }

    test("validator rejects missing max_tokens") {
        let req = try decodeReqV(#"{"model":"m","messages":[{"role":"user","content":"hi"}]}"#)
        try assertEqual(AnthropicMessageValidator.validate(req), .invalidMaxTokens)
    }

    test("validator rejects max_tokens <= 0") {
        let req = try decodeReqV(#"{"model":"m","max_tokens":0,"messages":[{"role":"user","content":"hi"}]}"#)
        try assertEqual(AnthropicMessageValidator.validate(req), .invalidMaxTokens)
    }

    test("validator rejects empty messages") {
        let req = try decodeReqV(#"{"model":"m","max_tokens":10,"messages":[]}"#)
        try assertEqual(AnthropicMessageValidator.validate(req), .emptyMessages)
    }

    test("validator rejects bad role") {
        let req = try decodeReqV(#"{"model":"m","max_tokens":10,"messages":[{"role":"system","content":"hi"}]}"#)
        if case .invalidRole(let r)? = AnthropicMessageValidator.validate(req) {
            try assertEqual(r, "system")
        } else {
            throw TestFailure("expected .invalidRole")
        }
    }

    test("validator rejects malformed tool_use missing id") {
        let req = try decodeReqV(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"assistant","content":[{"type":"tool_use","id":"","name":"calc","input":{}}]}]}
        """#)
        if case .malformedToolBlock(let msg)? = AnthropicMessageValidator.validate(req) {
            try assertTrue(msg.contains("tool_use"))
        } else {
            throw TestFailure("expected .malformedToolBlock for empty id")
        }
    }

    test("validator rejects malformed tool_result missing tool_use_id") {
        let req = try decodeReqV(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"","content":"4"}]}]}
        """#)
        if case .malformedToolBlock(let msg)? = AnthropicMessageValidator.validate(req) {
            try assertTrue(msg.contains("tool_use_id"))
        } else {
            throw TestFailure("expected .malformedToolBlock for empty tool_use_id")
        }
    }

    test("validator accepts well-formed tool_use and tool_result history") {
        let req = try decodeReqV(#"""
        {"model":"m","max_tokens":10,"messages":[
        {"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"calc","input":{"a":2}}]},
        {"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"4"}]}]}
        """#)
        try assertNil(AnthropicMessageValidator.validate(req))
    }

    test("validator surfaces stable failure messages") {
        try assertEqual(AnthropicValidationFailure.missingModel.message, "'model' is required and must be a non-empty string")
        try assertEqual(AnthropicValidationFailure.invalidMaxTokens.message, "'max_tokens' is required and must be a positive integer")
        try assertEqual(AnthropicValidationFailure.emptyMessages.message, "'messages' must contain at least one message")
    }

    test("validator checks model before max_tokens before messages") {
        let req = AnthropicMessagesRequest(model: "", maxTokens: nil, messages: [])
        try assertEqual(AnthropicMessageValidator.validate(req), .missingModel)
        let req2 = AnthropicMessagesRequest(model: "m", maxTokens: nil, messages: [])
        try assertEqual(AnthropicMessageValidator.validate(req2), .invalidMaxTokens)
        let req3 = AnthropicMessagesRequest(model: "m", maxTokens: 10, messages: [])
        try assertEqual(AnthropicMessageValidator.validate(req3), .emptyMessages)
    }
}
