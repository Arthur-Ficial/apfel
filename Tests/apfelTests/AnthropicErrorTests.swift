// ============================================================================
// AnthropicErrorTests.swift — ApfelError -> Anthropic error type / status / message.
// ============================================================================

import Foundation
import ApfelCore

func runAnthropicErrorTests() {

    test("contextOverflow maps to invalid_request_error 400 with 'context' in message") {
        let e = ApfelError.contextOverflow
        try assertEqual(e.anthropicErrorType, "invalid_request_error")
        try assertEqual(e.anthropicStatusCode, 400)
        try assertTrue(e.anthropicMessage.lowercased().contains("context"))
    }

    test("rateLimited maps to rate_limit_error 429") {
        let e = ApfelError.rateLimited
        try assertEqual(e.anthropicErrorType, "rate_limit_error")
        try assertEqual(e.anthropicStatusCode, 429)
    }

    test("concurrentRequest maps to rate_limit_error 429") {
        let e = ApfelError.concurrentRequest
        try assertEqual(e.anthropicErrorType, "rate_limit_error")
        try assertEqual(e.anthropicStatusCode, 429)
    }

    test("guardrailViolation maps to invalid_request_error 400") {
        let e = ApfelError.guardrailViolation
        try assertEqual(e.anthropicErrorType, "invalid_request_error")
        try assertEqual(e.anthropicStatusCode, 400)
    }

    test("unsupportedLanguage maps to invalid_request_error 400") {
        let e = ApfelError.unsupportedLanguage("xx")
        try assertEqual(e.anthropicErrorType, "invalid_request_error")
        try assertEqual(e.anthropicStatusCode, 400)
    }

    test("refusal stays a 200 (delivered as stop_reason refusal, not an envelope)") {
        let e = ApfelError.refusal("no")
        try assertEqual(e.anthropicStatusCode, 200)
    }

    test("decodingFailure maps to api_error 500") {
        let e = ApfelError.decodingFailure("bad")
        try assertEqual(e.anthropicErrorType, "api_error")
        try assertEqual(e.anthropicStatusCode, 500)
    }

    test("toolExecution maps to api_error 500") {
        let e = ApfelError.toolExecution("boom")
        try assertEqual(e.anthropicErrorType, "api_error")
        try assertEqual(e.anthropicStatusCode, 500)
    }

    test("unknown maps to api_error 500") {
        let e = ApfelError.unknown("?")
        try assertEqual(e.anthropicErrorType, "api_error")
        try assertEqual(e.anthropicStatusCode, 500)
    }

    test("assetsUnavailable maps to overloaded_error 503") {
        let e = ApfelError.assetsUnavailable
        try assertEqual(e.anthropicErrorType, "overloaded_error")
        try assertEqual(e.anthropicStatusCode, 503)
    }
}
