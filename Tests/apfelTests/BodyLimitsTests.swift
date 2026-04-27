// ============================================================================
// BodyLimitsTests.swift — Sanity checks for named server constants
//
// `defaultMaxResponseTokens` was deliberately removed: with the streaming-
// overflow root-cause fix, an omitted max_tokens flows through as nil and
// the model uses the remaining context window. No arbitrary cap.
// ============================================================================

import Foundation
import ApfelCore

func runBodyLimitsTests() {
    test("maxRequestBodyBytes is 1 MiB") {
        try assertEqual(BodyLimits.maxRequestBodyBytes, 1024 * 1024)
    }

    test("defaultOutputReserveTokens is 512") {
        try assertEqual(BodyLimits.defaultOutputReserveTokens, 512)
    }

    test("constants are positive") {
        try assertTrue(BodyLimits.maxRequestBodyBytes > 0)
        try assertTrue(BodyLimits.defaultOutputReserveTokens > 0)
    }

    test("no defaultMaxResponseTokens exists (intentionally removed)") {
        let bodyLimitsSrc = (try? String(contentsOfFile: "Sources/Core/Chat/BodyLimits.swift", encoding: .utf8)) ?? ""
        try assertTrue(!bodyLimitsSrc.contains("defaultMaxResponseTokens"),
                       "BodyLimits.swift must not declare defaultMaxResponseTokens — omitted max_tokens is intentionally nil")
    }
}
