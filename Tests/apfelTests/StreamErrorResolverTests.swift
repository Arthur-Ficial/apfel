// ============================================================================
// StreamErrorResolverTests.swift — Pure decision logic that distinguishes
// output-side context overflow (graceful length-finish) from genuine errors.
//
// Replaces the load-bearing 1024 default cap: with this resolver in place,
// "model ran into the context ceiling after producing some content" stops
// being an error and becomes a normal finish_reason: "length".
// ============================================================================

import Foundation
import ApfelCore

func runStreamErrorResolverTests() {
    // MARK: - Output-side overflow (the only graceful path)

    test("contextOverflow + non-empty prev -> truncated") {
        let outcome = StreamErrorResolver.resolve(prev: "hello world", error: .contextOverflow)
        switch outcome {
        case .truncated(let content): try assertEqual(content, "hello world")
        case .fatal: throw TestFailure("expected .truncated, got .fatal")
        }
    }

    test("contextOverflow + single character prev -> truncated") {
        let outcome = StreamErrorResolver.resolve(prev: "x", error: .contextOverflow)
        if case .fatal = outcome { throw TestFailure("single char prev still counts as content; should be truncated") }
    }

    test("contextOverflow + multi-line prev -> truncated, content preserved verbatim") {
        let multiline = "line one\nline two\nline three"
        let outcome = StreamErrorResolver.resolve(prev: multiline, error: .contextOverflow)
        switch outcome {
        case .truncated(let content): try assertEqual(content, multiline)
        case .fatal: throw TestFailure("expected .truncated")
        }
    }

    test("contextOverflow + empty prev -> fatal(.contextOverflow) — prompt-side overflow") {
        let outcome = StreamErrorResolver.resolve(prev: "", error: .contextOverflow)
        switch outcome {
        case .truncated: throw TestFailure("empty prev means no content was generated; must propagate")
        case .fatal(let err): try assertEqual(err, ApfelError.contextOverflow)
        }
    }

    // MARK: - Refusal (always fatal — partial refusal text is not a usable completion)

    test("refusal + empty prev -> fatal(.refusal)") {
        let outcome = StreamErrorResolver.resolve(prev: "", error: .refusal("blocked"))
        if case .truncated = outcome { throw TestFailure("refusal must never be silently truncated") }
        if case .fatal(let err) = outcome { try assertEqual(err, ApfelError.refusal("blocked")) }
    }

    test("refusal + non-empty prev -> fatal(.refusal) (the partial refusal text is not a trustworthy reply)") {
        let outcome = StreamErrorResolver.resolve(prev: "I cannot", error: .refusal("blocked"))
        if case .truncated = outcome { throw TestFailure("refusal must stay fatal even when prev is non-empty") }
        if case .fatal(let err) = outcome { try assertEqual(err, ApfelError.refusal("blocked")) }
    }

    // MARK: - Every other ApfelError case is fatal regardless of prev

    test("guardrailViolation -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .guardrailViolation) {
            throw TestFailure("guardrail must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .guardrailViolation) {
            throw TestFailure("guardrail must stay fatal")
        }
    }

    test("rateLimited -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .rateLimited) {
            throw TestFailure("rateLimited must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .rateLimited) {
            throw TestFailure("rateLimited must stay fatal")
        }
    }

    test("concurrentRequest -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .concurrentRequest) {
            throw TestFailure("concurrentRequest must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .concurrentRequest) {
            throw TestFailure("concurrentRequest must stay fatal")
        }
    }

    test("assetsUnavailable -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .assetsUnavailable) {
            throw TestFailure("assetsUnavailable must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .assetsUnavailable) {
            throw TestFailure("assetsUnavailable must stay fatal")
        }
    }

    test("unsupportedGuide -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .unsupportedGuide) {
            throw TestFailure("unsupportedGuide must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .unsupportedGuide) {
            throw TestFailure("unsupportedGuide must stay fatal")
        }
    }

    test("decodingFailure -> fatal in both prev states (corrupt output is not a valid completion)") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .decodingFailure("bad")) {
            throw TestFailure("decodingFailure must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .decodingFailure("bad")) {
            throw TestFailure("decodingFailure must stay fatal — the partial bytes are corrupt by definition")
        }
    }

    test("unsupportedLanguage -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .unsupportedLanguage("zz")) {
            throw TestFailure("unsupportedLanguage must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .unsupportedLanguage("zz")) {
            throw TestFailure("unsupportedLanguage must stay fatal")
        }
    }

    test("toolExecution -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .toolExecution("boom")) {
            throw TestFailure("toolExecution must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .toolExecution("boom")) {
            throw TestFailure("toolExecution must stay fatal")
        }
    }

    test("unknown -> fatal in both prev states") {
        if case .truncated = StreamErrorResolver.resolve(prev: "", error: .unknown("boom")) {
            throw TestFailure("unknown must stay fatal")
        }
        if case .truncated = StreamErrorResolver.resolve(prev: "partial", error: .unknown("boom")) {
            throw TestFailure("unknown must stay fatal")
        }
    }

    // MARK: - Fatal payload preserves the classified error verbatim

    test("fatal payload preserves the classified error for all cases") {
        let cases: [ApfelError] = [
            .guardrailViolation, .refusal("r"), .contextOverflow, .rateLimited,
            .concurrentRequest, .assetsUnavailable, .unsupportedGuide,
            .decodingFailure("d"), .unsupportedLanguage("l"),
            .toolExecution("t"), .unknown("u")
        ]
        for err in cases {
            // refusal is always fatal even with non-empty prev, but contextOverflow with empty prev is also fatal
            let prev = (err == .contextOverflow) ? "" : "anything"
            let outcome = StreamErrorResolver.resolve(prev: prev, error: err)
            if case .fatal(let propagated) = outcome {
                try assertEqual(propagated, err, "must propagate the input error verbatim")
            } else {
                throw TestFailure("\(err) must be fatal in this scenario")
            }
        }
    }

    // MARK: - StreamOutcome value semantics

    test("StreamOutcome carries content and finishReason") {
        let stop = StreamOutcome(content: "hi", finishReason: .stop)
        let length = StreamOutcome(content: "hello there", finishReason: .length)
        try assertEqual(stop.content, "hi")
        try assertEqual(stop.finishReason, .stop)
        try assertEqual(length.content, "hello there")
        try assertEqual(length.finishReason, .length)
    }

    test("StreamOutcome is Equatable") {
        let a = StreamOutcome(content: "x", finishReason: .stop)
        let b = StreamOutcome(content: "x", finishReason: .stop)
        let c = StreamOutcome(content: "x", finishReason: .length)
        let d = StreamOutcome(content: "y", finishReason: .stop)
        try assertEqual(a, b)
        try assertTrue(a != c, "different finishReason should differ")
        try assertTrue(a != d, "different content should differ")
    }

    test("StreamOutcome is Hashable (round-trips through Set)") {
        let s: Set<StreamOutcome> = [
            StreamOutcome(content: "x", finishReason: .stop),
            StreamOutcome(content: "x", finishReason: .stop),
            StreamOutcome(content: "x", finishReason: .length)
        ]
        try assertEqual(s.count, 2)
    }

    test("StreamOutcome with empty content is valid (e.g. immediate stop)") {
        let empty = StreamOutcome(content: "", finishReason: .stop)
        try assertEqual(empty.content, "")
        try assertEqual(empty.finishReason, .stop)
    }
}
