import Foundation
import ApfelCore

// Test helper: simulate FoundationModels GenerationError by name
private struct GenErrSim: Error, LocalizedError, CustomStringConvertible {
    let caseName: String
    let localizedMsg: String
    var errorDescription: String? { localizedMsg }
    var description: String { "GenerationError.\(caseName)(Context(debugDescription: \"\(localizedMsg)\"))" }
}

// Test helper: simulate FoundationModels ToolCallError
private struct ToolCallErrSim: Error, LocalizedError, CustomStringConvertible {
    let localizedMsg: String
    var errorDescription: String? { localizedMsg }
    var description: String { "ToolCallError(tool: test_tool, underlyingError: \(localizedMsg))" }
}

func runApfelErrorTests() {
    test("guardrail keyword → .guardrailViolation") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "guardrail violation occurred"])
        try assertEqual(ApfelError.classify(err), .guardrailViolation)
    }
    test("content policy keyword → .guardrailViolation") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "content policy blocked this request"])
        try assertEqual(ApfelError.classify(err), .guardrailViolation)
    }
    test("context window keyword → .contextOverflow") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "exceeded context window size"])
        try assertEqual(ApfelError.classify(err), .contextOverflow)
    }
    test("rate limit keyword → .rateLimited") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "rate limited, try later"])
        try assertEqual(ApfelError.classify(err), .rateLimited)
    }
    test("concurrent keyword → .concurrentRequest") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "concurrent requests not allowed"])
        try assertEqual(ApfelError.classify(err), .concurrentRequest)
    }
    test("unknown error → .unknown") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "something went wrong"])
        if case .unknown = ApfelError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }
    test("MCP server errors map to toolExecution") {
        let err = MCPError.serverError("Tool 'divide' failed: division by zero")
        try assertEqual(
            ApfelError.classify(err),
            .toolExecution("Tool 'divide' failed: division by zero")
        )
    }
    test("MCP timeouts map to toolExecution") {
        let err = MCPError.timedOut("Tool 'multiply' timed out after 5s")
        try assertEqual(
            ApfelError.classify(err),
            .toolExecution("Tool 'multiply' timed out after 5s")
        )
    }
    test("CLI labels") {
        try assertEqual(ApfelError.guardrailViolation.cliLabel, "[guardrail]")
        try assertEqual(ApfelError.contextOverflow.cliLabel, "[context overflow]")
        try assertEqual(ApfelError.rateLimited.cliLabel, "[rate limited]")
        try assertEqual(ApfelError.concurrentRequest.cliLabel, "[busy]")
        try assertEqual(ApfelError.toolExecution("x").cliLabel, "[tool error]")
        try assertEqual(ApfelError.unknown("x").cliLabel, "[error]")
    }
    test("OpenAI error types") {
        try assertEqual(ApfelError.guardrailViolation.openAIType, "content_policy_violation")
        try assertEqual(ApfelError.contextOverflow.openAIType, "context_length_exceeded")
        try assertEqual(ApfelError.rateLimited.openAIType, "rate_limit_error")
        try assertEqual(ApfelError.concurrentRequest.openAIType, "rate_limit_error")
        try assertEqual(ApfelError.toolExecution("x").openAIType, "server_error")
    }
    test("HTTP status codes") {
        try assertEqual(ApfelError.guardrailViolation.httpStatusCode, 400)
        try assertEqual(ApfelError.contextOverflow.httpStatusCode, 400)
        try assertEqual(ApfelError.rateLimited.httpStatusCode, 429)
        try assertEqual(ApfelError.concurrentRequest.httpStatusCode, 429)
        try assertEqual(ApfelError.toolExecution("x").httpStatusCode, 500)
        try assertEqual(ApfelError.unknown("x").httpStatusCode, 500)
    }
    test("classify passes through existing ApfelError unchanged") {
        try assertEqual(ApfelError.classify(ApfelError.contextOverflow), .contextOverflow)
        try assertEqual(ApfelError.classify(ApfelError.guardrailViolation), .guardrailViolation)
        try assertEqual(ApfelError.classify(ApfelError.rateLimited), .rateLimited)
        try assertEqual(ApfelError.classify(ApfelError.concurrentRequest), .concurrentRequest)
        try assertEqual(ApfelError.classify(ApfelError.toolExecution("x")), .toolExecution("x"))
    }
    test("openAIMessage is non-empty for all cases") {
        let cases: [ApfelError] = [.guardrailViolation, .refusal("reason"), .contextOverflow,
                                    .rateLimited, .concurrentRequest, .toolExecution("tool failed"),
                                    .unknown("oops"), .unsupportedGuide, .decodingFailure("decode failed")]
        for c in cases {
            try assertTrue(!c.openAIMessage.isEmpty, "\(c)")
        }
    }
    test("all MCPError variants map to toolExecution") {
        let variants: [MCPError] = [
            .invalidResponse("bad json"),
            .serverError("tool failed"),
            .toolNotFound("no such tool"),
            .processError("server died"),
            .timedOut("timed out after 5s"),
        ]
        for err in variants {
            let classified = ApfelError.classify(err)
            if case .toolExecution(let msg) = classified {
                try assertTrue(!msg.isEmpty, "toolExecution message should not be empty for \(err)")
            } else {
                throw TestFailure("expected .toolExecution for \(err), got \(classified)")
            }
        }
    }
    test("MCPError descriptions match classification messages") {
        let err = MCPError.serverError("divide failed")
        try assertEqual(err.description, "divide failed")
        try assertEqual(ApfelError.classify(err), .toolExecution("divide failed"))
    }
    test("MCPError Equatable works correctly") {
        try assertEqual(MCPError.timedOut("a"), MCPError.timedOut("a"))
        try assertTrue(MCPError.timedOut("a") != MCPError.timedOut("b"))
        try assertTrue(MCPError.timedOut("a") != MCPError.serverError("a"))
        try assertEqual(MCPError.toolNotFound("x"), MCPError.toolNotFound("x"))
    }
    test("toolExecution preserves original error message") {
        let msg = "Tool 'divide' failed: Error: division by zero"
        let err = ApfelError.toolExecution(msg)
        try assertEqual(err.openAIMessage, msg)
        try assertEqual(err.httpStatusCode, 500)
        try assertEqual(err.openAIType, "server_error")
        try assertEqual(err.cliLabel, "[tool error]")
    }
    test("unsupportedLanguage error properties") {
        let err = ApfelError.unsupportedLanguage("Klingon")
        try assertEqual(err.httpStatusCode, 400)
        try assertEqual(err.openAIType, "invalid_request_error")
        try assertEqual(err.cliLabel, "[unsupported language]")
        try assertTrue(err.openAIMessage.contains("Klingon"))
    }

    // --- refusal (#115) ---

    test("classify detects GenerationError.refusal separately from guardrailViolation") {
        let refusal = GenErrSim(caseName: "refusal", localizedMsg: "Content not appropriate")
        let guardrail = GenErrSim(caseName: "guardrailViolation", localizedMsg: "Safety check failed")
        if case .refusal(let msg) = ApfelError.classify(refusal) {
            try assertTrue(msg == "Content not appropriate")
        } else {
            throw TestFailure("expected .refusal for GenerationError.refusal")
        }
        try assertEqual(ApfelError.classify(guardrail), .guardrailViolation)
    }
    test("refusal error properties") {
        let err = ApfelError.refusal("Not allowed")
        try assertEqual(err.cliLabel, "[refusal]")
        try assertEqual(err.openAIType, "content_policy_violation")
        try assertEqual(err.httpStatusCode, 400)
        try assertTrue(err.openAIMessage.contains("Not allowed"))
        try assertTrue(!err.isRetryable)
    }
    test("classify passthrough for refusal") {
        let original = ApfelError.refusal("reason")
        try assertEqual(ApfelError.classify(original), .refusal("reason"))
    }
    test("refusal string fallback matches 'refused'") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "The model refused to answer"])
        if case .refusal = ApfelError.classify(err) { } else {
            throw TestFailure("expected .refusal for 'refused' keyword")
        }
    }
    test("refusal string fallback matches 'refusal'") {
        let err = NSError(domain: "FM", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Content refusal triggered"])
        if case .refusal = ApfelError.classify(err) { } else {
            throw TestFailure("expected .refusal for 'refusal' keyword")
        }
    }

    // --- ToolCallError (#115) ---

    test("classify detects FoundationModels ToolCallError as toolExecution") {
        let err = ToolCallErrSim(localizedMsg: "Tool 'search' failed: no results")
        if case .toolExecution(let msg) = ApfelError.classify(err) {
            try assertTrue(msg == "Tool 'search' failed: no results")
        } else {
            throw TestFailure("expected .toolExecution for ToolCallError")
        }
    }
    test("ToolCallError classification is locale-independent") {
        let err = ToolCallErrSim(localizedMsg: "Werkzeugfehler: Division durch Null")
        if case .toolExecution(let msg) = ApfelError.classify(err) {
            try assertTrue(msg.contains("Werkzeugfehler"))
        } else {
            throw TestFailure("expected .toolExecution regardless of locale")
        }
    }

    // --- unsupportedGuide (#41) ---

    test("unsupportedGuide error properties") {
        let err = ApfelError.unsupportedGuide
        try assertEqual(err.cliLabel, "[unsupported guide]")
        try assertEqual(err.openAIType, "invalid_request_error")
        try assertEqual(err.httpStatusCode, 400)
        try assertTrue(!err.openAIMessage.isEmpty)
        try assertTrue(!err.isRetryable)
    }
    test("classify detects GenerationError.unsupportedGuide") {
        let err = GenErrSim(caseName: "unsupportedGuide", localizedMsg: "Nicht unterstuetzte Anleitung")
        try assertEqual(ApfelError.classify(err), .unsupportedGuide)
    }
    test("classify passthrough for unsupportedGuide") {
        try assertEqual(ApfelError.classify(ApfelError.unsupportedGuide), .unsupportedGuide)
    }

    // --- decodingFailure (#41) ---

    test("decodingFailure error properties") {
        let err = ApfelError.decodingFailure("bad output")
        try assertEqual(err.cliLabel, "[decoding failure]")
        try assertEqual(err.openAIType, "server_error")
        try assertEqual(err.httpStatusCode, 500)
        try assertTrue(err.openAIMessage.contains("bad output"))
        try assertTrue(!err.isRetryable)
    }
    test("classify detects GenerationError.decodingFailure") {
        let err = GenErrSim(caseName: "decodingFailure", localizedMsg: "Dekodierungsfehler")
        if case .decodingFailure = ApfelError.classify(err) { } else {
            throw TestFailure("expected .decodingFailure")
        }
    }
    test("classify passthrough for decodingFailure") {
        if case .decodingFailure = ApfelError.classify(ApfelError.decodingFailure("x")) { } else {
            throw TestFailure("expected .decodingFailure passthrough")
        }
    }
}
