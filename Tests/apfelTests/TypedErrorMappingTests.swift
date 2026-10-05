// ============================================================================
// TypedErrorMappingTests.swift - pure payload -> message mapping for the two
// ApfelError cases added for macOS 27's typed LanguageModelError (#510 item 4,
// #197). The #available glue (TypedErrorSupport.swift, main target) only
// moves the SDK payload numbers into these cases; everything user-visible is
// locked down here with plain values.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runTypedErrorMappingTests() {
    // MARK: - contextWindowExceeded(tokenCount:contextSize:)

    test("contextWindowExceeded message carries the real counts") {
        try assertEqual(
            ApfelError.contextWindowExceeded(tokenCount: 4310, contextSize: 4096).openAIMessage,
            "Input exceeds the model's context window: the input is 4310 tokens, the window is 4096 tokens. Shorten the conversation history."
        )
    }
    test("contextWindowExceeded wire fields match .contextOverflow") {
        let e = ApfelError.contextWindowExceeded(tokenCount: 9000, contextSize: 8192)
        try assertEqual(e.cliLabel, "[context overflow]")
        try assertEqual(e.openAIType, "context_length_exceeded")
        try assertEqual(e.httpStatusCode, 400)
        try assertEqual(e.isRetryable, false)
        try assertNil(e.retryAfterSeconds)
    }
    test("contextWindowExceeded exits 4 like contextOverflow") {
        try assertEqual(ApfelExitCodes.code(for: .contextWindowExceeded(tokenCount: 4310, contextSize: 4096)), 4)
    }
    test("contextWindowExceeded debugDescription names both numbers") {
        try assertEqual(
            ApfelError.contextWindowExceeded(tokenCount: 4310, contextSize: 4096).debugDescription,
            "ApfelError.contextWindowExceeded(tokenCount: 4310, contextSize: 4096)"
        )
    }

    // MARK: - rateLimitedUntil(retryAfterSeconds:)

    test("rateLimitedUntil message names the wait in seconds") {
        try assertEqual(
            ApfelError.rateLimitedUntil(retryAfterSeconds: 42).openAIMessage,
            "Apple Intelligence is rate limited. Retry after 42 seconds."
        )
    }
    test("rateLimitedUntil message is singular for one second") {
        try assertEqual(
            ApfelError.rateLimitedUntil(retryAfterSeconds: 1).openAIMessage,
            "Apple Intelligence is rate limited. Retry after 1 second."
        )
    }
    test("rateLimitedUntil wire fields match .rateLimited") {
        let e = ApfelError.rateLimitedUntil(retryAfterSeconds: 42)
        try assertEqual(e.cliLabel, "[rate limited]")
        try assertEqual(e.openAIType, "rate_limit_error")
        try assertEqual(e.httpStatusCode, 429)
        try assertEqual(e.isRetryable, true)
        try assertEqual(e.retryAfterSeconds, 42)
    }
    test("rateLimitedUntil exits 6 like rateLimited") {
        try assertEqual(ApfelExitCodes.code(for: .rateLimitedUntil(retryAfterSeconds: 3)), 6)
    }
    test("isRetryableError treats rateLimitedUntil as transient") {
        try assertEqual(isRetryableError(ApfelError.rateLimitedUntil(retryAfterSeconds: 3)), true)
    }

    // MARK: - resetDate -> Retry-After seconds (pure date math)

    test("retryAfterSeconds rounds a fractional wait up") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(4.2)
        try assertEqual(ApfelError.retryAfterSeconds(until: reset, now: now), 5)
    }
    test("retryAfterSeconds keeps an exact wait") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        try assertEqual(ApfelError.retryAfterSeconds(until: now.addingTimeInterval(30), now: now), 30)
    }
    test("retryAfterSeconds clamps past and zero waits to 1") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        try assertEqual(ApfelError.retryAfterSeconds(until: now, now: now), 1)
        try assertEqual(ApfelError.retryAfterSeconds(until: now.addingTimeInterval(-60), now: now), 1)
    }

    // MARK: - retryAfterSeconds is nil for every other case

    test("retryAfterSeconds is nil for the non-rate-limit cases") {
        try assertNil(ApfelError.rateLimited.retryAfterSeconds)
        try assertNil(ApfelError.contextOverflow.retryAfterSeconds)
        try assertNil(ApfelError.guardrailViolation.retryAfterSeconds)
        try assertNil(ApfelError.unknown("x").retryAfterSeconds)
    }
}
