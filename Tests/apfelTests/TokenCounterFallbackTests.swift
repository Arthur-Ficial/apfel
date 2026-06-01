// ============================================================================
// TokenCounterFallbackTests.swift - Asserts fallbackCount accounts for tool
// arguments and tool definitions (not just text segments and flat call counts).
// Source-level checks: TokenCounter lives in the apfel target (FoundationModels),
// so we verify the code structure rather than calling fallbackCount directly.
// ============================================================================

import Foundation

func runTokenCounterFallbackTests() {
    let src = (try? String(contentsOfFile: "Sources/TokenCounter.swift", encoding: .utf8)) ?? ""

    test("fallbackCount: tool calls iterate individual calls, not flat count") {
        try assertTrue(src.contains("for call in tc"),
                       "fallbackCount must iterate tool calls individually, not use tc.count * N")
        try assertTrue(!src.contains("tc.count * 20"),
                       "fallbackCount must not use flat tc.count * 20 (ignores arguments)")
    }

    test("fallbackCount: tool call arguments are counted") {
        try assertTrue(src.contains("call.arguments"),
                       "fallbackCount must access call.arguments to count argument tokens")
    }

    test("fallbackCount: tool call name is counted") {
        try assertTrue(src.contains("call.toolName.count"),
                       "fallbackCount must count tool call name tokens")
    }

    test("fallbackCount: instructions count tool definitions") {
        try assertTrue(src.contains("i.toolDefinitions"),
                       "fallbackCount must iterate toolDefinitions in instructions")
    }

    test("fallbackCount: tool definition name is counted") {
        try assertTrue(src.contains("def.name.count"),
                       "fallbackCount must count tool definition name tokens")
    }

    test("fallbackCount: tool definition description is counted") {
        try assertTrue(src.contains("def.description.count"),
                       "fallbackCount must count tool definition description tokens")
    }
}
