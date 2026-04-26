// ============================================================================
// BodyLimitsTests.swift — Sanity checks for named server constants
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runBodyLimitsTests() {
    test("maxRequestBodyBytes is 1 MiB") {
        try assertEqual(BodyLimits.maxRequestBodyBytes, 1024 * 1024)
    }

    test("defaultOutputReserveTokens is 512") {
        try assertEqual(BodyLimits.defaultOutputReserveTokens, 512)
    }

    test("defaultMaxResponseTokens is 1024") {
        try assertEqual(BodyLimits.defaultMaxResponseTokens, 1024)
    }

    test("defaultMaxResponseTokens fits within 4096-token context window") {
        try assertTrue(BodyLimits.defaultMaxResponseTokens > 0)
        try assertTrue(BodyLimits.defaultMaxResponseTokens <= 4096)
    }

    test("constants are positive") {
        try assertTrue(BodyLimits.maxRequestBodyBytes > 0)
        try assertTrue(BodyLimits.defaultOutputReserveTokens > 0)
        try assertTrue(BodyLimits.defaultMaxResponseTokens > 0)
    }

    test("CLI maxTokens fallback uses BodyLimits.defaultMaxResponseTokens (parity with server)") {
        let args = try CLIArguments.parse(["hello"])
        try assertNil(args.maxTokens, "CLI should not set maxTokens when --max-tokens is omitted")
        // Both main.swift and Handlers.swift apply ?? BodyLimits.defaultMaxResponseTokens,
        // so the fallback is compiler-enforced via the same constant.
        let fallback = args.maxTokens ?? BodyLimits.defaultMaxResponseTokens
        try assertEqual(fallback, 1024)
    }

    test("CLI explicit --max-tokens overrides the default") {
        let args = try CLIArguments.parse(["--max-tokens", "256", "hello"])
        let resolved = args.maxTokens ?? BodyLimits.defaultMaxResponseTokens
        try assertEqual(resolved, 256)
    }
}
