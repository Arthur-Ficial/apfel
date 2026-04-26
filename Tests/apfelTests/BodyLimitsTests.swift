// ============================================================================
// BodyLimitsTests.swift — Sanity checks for named server constants
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

    test("defaultMaxResponseTokens is 512") {
        try assertEqual(BodyLimits.defaultMaxResponseTokens, 512)
    }

    test("defaultMaxResponseTokens matches defaultOutputReserveTokens") {
        try assertEqual(BodyLimits.defaultMaxResponseTokens, BodyLimits.defaultOutputReserveTokens)
    }

    test("constants are positive") {
        try assertTrue(BodyLimits.maxRequestBodyBytes > 0)
        try assertTrue(BodyLimits.defaultOutputReserveTokens > 0)
        try assertTrue(BodyLimits.defaultMaxResponseTokens > 0)
    }

    test("defaultMaxResponseTokens fits within 4096-token context window") {
        try assertTrue(BodyLimits.defaultMaxResponseTokens <= 4096)
        try assertTrue(BodyLimits.defaultMaxResponseTokens >= 128)
    }
}
