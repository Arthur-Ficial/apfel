// ============================================================================
// ApfelErrorMessageTests.swift — Exact-string lockdown for every public error
// message in ApfelCore. This is the baseline for adding LocalizedError in #105:
// when we add `errorDescription`, it must produce these same strings (or the
// change must be deliberate and visible in this test's diff).
//
// Covers:
//   - ApfelError.openAIMessage (all 10 cases)
//   - ApfelError.cliLabel, .openAIType, .httpStatusCode (stable enumerations)
//   - MCPError.description / errorDescription (all 5 cases)
//   - ChatRequestValidationFailure.message and .event (all 6 cases)
//   - UnsupportedChatParameter.name and .message (all 5 cases)
// ============================================================================

import Foundation
import ApfelCore

func runApfelErrorMessageTests() {
    // MARK: - ApfelError.openAIMessage (the user-visible HTTP error body)

    test("ApfelError.guardrailViolation.openAIMessage") {
        try assertEqual(
            ApfelError.guardrailViolation.openAIMessage,
            "The request was blocked by Apple's safety guardrails. Try rephrasing."
        )
    }
    test("ApfelError.contextOverflow.openAIMessage") {
        try assertEqual(
            ApfelError.contextOverflow.openAIMessage,
            "Input exceeds the 4096-token context window. Shorten the conversation history."
        )
    }
    test("ApfelError.rateLimited.openAIMessage") {
        try assertEqual(
            ApfelError.rateLimited.openAIMessage,
            "Apple Intelligence is rate limited. Retry after a few seconds."
        )
    }
    test("ApfelError.concurrentRequest.openAIMessage") {
        try assertEqual(
            ApfelError.concurrentRequest.openAIMessage,
            "Apple Intelligence is busy with another request. Retry shortly."
        )
    }
    test("ApfelError.assetsUnavailable.openAIMessage") {
        try assertEqual(
            ApfelError.assetsUnavailable.openAIMessage,
            "Model assets are loading. Try again in a moment."
        )
    }
    test("ApfelError.unsupportedGuide.openAIMessage") {
        try assertEqual(
            ApfelError.unsupportedGuide.openAIMessage,
            "The requested generation guide is not supported by this model."
        )
    }
    test("ApfelError.decodingFailure.openAIMessage embeds the detail") {
        try assertEqual(
            ApfelError.decodingFailure("bad JSON").openAIMessage,
            "Model output could not be decoded: bad JSON"
        )
    }
    test("ApfelError.unsupportedLanguage.openAIMessage embeds the detail") {
        try assertEqual(
            ApfelError.unsupportedLanguage("tlh").openAIMessage,
            "Unsupported language: tlh"
        )
    }
    test("ApfelError.toolExecution.openAIMessage passes the detail through verbatim") {
        try assertEqual(
            ApfelError.toolExecution("calculator exploded").openAIMessage,
            "calculator exploded"
        )
    }
    test("ApfelError.unknown.openAIMessage passes the detail through verbatim") {
        try assertEqual(
            ApfelError.unknown("mystery").openAIMessage,
            "mystery"
        )
    }

    // MARK: - ApfelError.cliLabel (terminal prefix users see)

    test("ApfelError cliLabel lockdown for every case") {
        try assertEqual(ApfelError.guardrailViolation.cliLabel,  "[guardrail]")
        try assertEqual(ApfelError.contextOverflow.cliLabel,     "[context overflow]")
        try assertEqual(ApfelError.rateLimited.cliLabel,         "[rate limited]")
        try assertEqual(ApfelError.concurrentRequest.cliLabel,   "[busy]")
        try assertEqual(ApfelError.assetsUnavailable.cliLabel,   "[model loading]")
        try assertEqual(ApfelError.unsupportedGuide.cliLabel,    "[unsupported guide]")
        try assertEqual(ApfelError.decodingFailure("x").cliLabel,"[decoding failure]")
        try assertEqual(ApfelError.unsupportedLanguage("x").cliLabel, "[unsupported language]")
        try assertEqual(ApfelError.toolExecution("x").cliLabel,  "[tool error]")
        try assertEqual(ApfelError.unknown("x").cliLabel,        "[error]")
    }

    // MARK: - ApfelError.openAIType (JSON error payload "type" field — wire contract)

    test("ApfelError openAIType lockdown for every case") {
        try assertEqual(ApfelError.guardrailViolation.openAIType,  "content_policy_violation")
        try assertEqual(ApfelError.contextOverflow.openAIType,     "context_length_exceeded")
        try assertEqual(ApfelError.rateLimited.openAIType,         "rate_limit_error")
        try assertEqual(ApfelError.concurrentRequest.openAIType,   "rate_limit_error")
        try assertEqual(ApfelError.assetsUnavailable.openAIType,   "server_error")
        try assertEqual(ApfelError.unsupportedGuide.openAIType,    "invalid_request_error")
        try assertEqual(ApfelError.decodingFailure("x").openAIType,"server_error")
        try assertEqual(ApfelError.unsupportedLanguage("x").openAIType, "invalid_request_error")
        try assertEqual(ApfelError.toolExecution("x").openAIType,  "server_error")
        try assertEqual(ApfelError.unknown("x").openAIType,        "server_error")
    }

    // MARK: - ApfelError.httpStatusCode (wire contract)

    test("ApfelError httpStatusCode lockdown for every case") {
        try assertEqual(ApfelError.guardrailViolation.httpStatusCode,  400)
        try assertEqual(ApfelError.contextOverflow.httpStatusCode,     400)
        try assertEqual(ApfelError.rateLimited.httpStatusCode,         429)
        try assertEqual(ApfelError.concurrentRequest.httpStatusCode,   429)
        try assertEqual(ApfelError.assetsUnavailable.httpStatusCode,   503)
        try assertEqual(ApfelError.unsupportedGuide.httpStatusCode,    400)
        try assertEqual(ApfelError.decodingFailure("x").httpStatusCode,500)
        try assertEqual(ApfelError.unsupportedLanguage("x").httpStatusCode, 400)
        try assertEqual(ApfelError.toolExecution("x").httpStatusCode,  500)
        try assertEqual(ApfelError.unknown("x").httpStatusCode,        500)
    }

    // MARK: - MCPError (already LocalizedError today — lock both surfaces)

    test("MCPError.description passes the detail through for every case") {
        try assertEqual(MCPError.invalidResponse("no json").description,  "no json")
        try assertEqual(MCPError.serverError("500 inside").description,   "500 inside")
        try assertEqual(MCPError.toolNotFound("add").description,         "add")
        try assertEqual(MCPError.processError("pipe broken").description, "pipe broken")
        try assertEqual(MCPError.timedOut("after 30s").description,       "after 30s")
    }

    test("MCPError.errorDescription equals .description for every case") {
        try assertEqual(MCPError.invalidResponse("x").errorDescription,  "x")
        try assertEqual(MCPError.serverError("x").errorDescription,      "x")
        try assertEqual(MCPError.toolNotFound("x").errorDescription,     "x")
        try assertEqual(MCPError.processError("x").errorDescription,     "x")
        try assertEqual(MCPError.timedOut("x").errorDescription,         "x")
    }

    test("ApfelError.localizedDescription equals openAIMessage for every case") {
        let cases: [ApfelError] = [
            .guardrailViolation,
            .contextOverflow,
            .rateLimited,
            .concurrentRequest,
            .assetsUnavailable,
            .unsupportedGuide,
            .decodingFailure("bad JSON"),
            .unsupportedLanguage("tlh"),
            .toolExecution("calculator exploded"),
            .unknown("mystery"),
        ]
        for error in cases {
            try assertEqual((error as Error).localizedDescription, error.openAIMessage)
        }
    }

    // MARK: - ChatRequestValidationFailure.message (HTTP 400 body for bad requests)

    test("ChatRequestValidationFailure.message for every case") {
        try assertEqual(
            ChatRequestValidationFailure.emptyMessages.message,
            "'messages' must contain at least one message"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidLastRole.message,
            "Last message must have role 'user' or 'tool'"
        )
        try assertEqual(
            ChatRequestValidationFailure.imageContent.message,
            "Image content is not supported by the Apple on-device model"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidParameterValue("nope").message,
            "nope"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidModel("gpt-5").message,
            "The model 'gpt-5' does not exist. The only available model is 'apple-foundationmodel'."
        )
        // unsupportedParameter delegates to the parameter's own message —
        // sampled here, fully covered below.
        try assertEqual(
            ChatRequestValidationFailure.unsupportedParameter(.logprobs).message,
            "Parameter 'logprobs' is not supported by Apple's on-device model."
        )
    }

    // MARK: - ChatRequestValidationFailure.event (debug/log line)

    test("ChatRequestValidationFailure.event for every case") {
        try assertEqual(
            ChatRequestValidationFailure.emptyMessages.event,
            "validation failed: empty messages"
        )
        try assertEqual(
            ChatRequestValidationFailure.unsupportedParameter(.stop).event,
            "validation failed: unsupported parameter stop"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidLastRole.event,
            "validation failed: last role != user/tool"
        )
        try assertEqual(
            ChatRequestValidationFailure.imageContent.event,
            "rejected: image content"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidParameterValue("temperature<0").event,
            "validation failed: temperature<0"
        )
        try assertEqual(
            ChatRequestValidationFailure.invalidModel("gpt-5").event,
            "validation failed: unknown model gpt-5"
        )
    }

    // MARK: - UnsupportedChatParameter (name + message)

    test("UnsupportedChatParameter.name matches the JSON field name") {
        try assertEqual(UnsupportedChatParameter.logprobs.name,          "logprobs")
        try assertEqual(UnsupportedChatParameter.n.name,                 "n")
        try assertEqual(UnsupportedChatParameter.stop.name,              "stop")
        try assertEqual(UnsupportedChatParameter.presencePenalty.name,   "presence_penalty")
        try assertEqual(UnsupportedChatParameter.frequencyPenalty.name,  "frequency_penalty")
    }

    test("UnsupportedChatParameter.message for every case") {
        try assertEqual(
            UnsupportedChatParameter.logprobs.message,
            "Parameter 'logprobs' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.n.message,
            "Parameter 'n' is not supported by Apple's on-device model. Only n=1 is allowed."
        )
        try assertEqual(
            UnsupportedChatParameter.stop.message,
            "Parameter 'stop' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.presencePenalty.message,
            "Parameter 'presence_penalty' is not supported by Apple's on-device model."
        )
        try assertEqual(
            UnsupportedChatParameter.frequencyPenalty.message,
            "Parameter 'frequency_penalty' is not supported by Apple's on-device model."
        )
    }

    // MARK: - Retryability (wire-relevant, affects client retry logic)

    test("ApfelError.isRetryable lockdown for every case") {
        try assertEqual(ApfelError.guardrailViolation.isRetryable,  false)
        try assertEqual(ApfelError.contextOverflow.isRetryable,     false)
        try assertEqual(ApfelError.rateLimited.isRetryable,         true)
        try assertEqual(ApfelError.concurrentRequest.isRetryable,   true)
        try assertEqual(ApfelError.assetsUnavailable.isRetryable,   true)
        try assertEqual(ApfelError.unsupportedGuide.isRetryable,    false)
        try assertEqual(ApfelError.decodingFailure("x").isRetryable,false)
        try assertEqual(ApfelError.unsupportedLanguage("x").isRetryable, false)
        try assertEqual(ApfelError.toolExecution("x").isRetryable,  false)
        try assertEqual(ApfelError.unknown("x").isRetryable,        false)
    }

    test("isRetryableError(_:) mirrors ApfelError.isRetryable for classified errors") {
        try assertEqual(isRetryableError(ApfelError.rateLimited),        true)
        try assertEqual(isRetryableError(ApfelError.concurrentRequest),  true)
        try assertEqual(isRetryableError(ApfelError.assetsUnavailable),  true)
        try assertEqual(isRetryableError(ApfelError.contextOverflow),    false)
        try assertEqual(isRetryableError(ApfelError.guardrailViolation), false)
    }
}
