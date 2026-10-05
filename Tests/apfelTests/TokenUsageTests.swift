// ============================================================================
// TokenUsageTests.swift — Unit tests for the pure per-model-call token-usage
// type that carries runtime-reported numbers (macOS 27: Response.usage) or
// counted fallbacks (macOS 26: TokenCounter) to the wire (#510 item 1, #504).
// ============================================================================

import Foundation
import ApfelCore

func runTokenUsageTests() {
    test("init maps prompt/completion/cached fields") {
        let u = TokenUsage(promptTokens: 60, completionTokens: 3, cachedPromptTokens: 12)
        try assertEqual(u.promptTokens, 60)
        try assertEqual(u.completionTokens, 3)
        try assertEqual(u.cachedPromptTokens, 12)
    }

    test("cachedPromptTokens defaults to 0 (macOS 26 counted path has no cache data)") {
        let u = TokenUsage(promptTokens: 14, completionTokens: 2)
        try assertEqual(u.cachedPromptTokens, 0)
    }

    test("totalTokens is prompt + completion") {
        let u = TokenUsage(promptTokens: 60, completionTokens: 3)
        try assertEqual(u.totalTokens, 63)
    }

    test("adding sums every field (one tool-call round onto another)") {
        let round1 = TokenUsage(promptTokens: 60, completionTokens: 25, cachedPromptTokens: 10)
        let round2 = TokenUsage(promptTokens: 110, completionTokens: 18, cachedPromptTokens: 60)
        let sum = round1.adding(round2)
        try assertEqual(sum, TokenUsage(promptTokens: 170, completionTokens: 43, cachedPromptTokens: 70))
    }

    test("sum of no rounds is nil (macOS 26: nothing reported, caller falls back to counting)") {
        try assertNil(TokenUsage.sum([]))
    }

    test("sum of a single round is that round") {
        let only = TokenUsage(promptTokens: 60, completionTokens: 3)
        try assertEqual(TokenUsage.sum([only]), only)
    }

    test("sum across tool-call rounds sums every field") {
        let rounds = [
            TokenUsage(promptTokens: 60, completionTokens: 25, cachedPromptTokens: 0),
            TokenUsage(promptTokens: 110, completionTokens: 18, cachedPromptTokens: 60),
            TokenUsage(promptTokens: 150, completionTokens: 9, cachedPromptTokens: 120),
        ]
        try assertEqual(
            TokenUsage.sum(rounds),
            TokenUsage(promptTokens: 320, completionTokens: 52, cachedPromptTokens: 180))
    }

    test("sum is order-independent") {
        let a = TokenUsage(promptTokens: 1, completionTokens: 2, cachedPromptTokens: 3)
        let b = TokenUsage(promptTokens: 10, completionTokens: 20, cachedPromptTokens: 30)
        try assertEqual(TokenUsage.sum([a, b]), TokenUsage.sum([b, a]))
    }

    // #516: repair-round usage must fold into refusal responses on macOS 27
    test("sum of one repair round provides prompt and completion for refusal folding") {
        let repairRound = TokenUsage(promptTokens: 200, completionTokens: 50, cachedPromptTokens: 0)
        let roundsUsage = TokenUsage.sum([repairRound])
        try assertNotNil(roundsUsage)
        try assertEqual(roundsUsage!.promptTokens, 200)
        try assertEqual(roundsUsage!.completionTokens, 50)
        let refusalPrompt = 100
        let refusalCompletion = 20
        try assertEqual(refusalPrompt + (roundsUsage?.promptTokens ?? 0), 300)
        try assertEqual(refusalCompletion + (roundsUsage?.completionTokens ?? 0), 70)
    }

    test("sum of empty rounds returns nil so macOS 26 counted path is unchanged") {
        let roundsUsage = TokenUsage.sum([])
        try assertNil(roundsUsage)
        let refusalPrompt = 100
        try assertEqual(refusalPrompt + (roundsUsage?.promptTokens ?? 0), 100)
    }

    // #516 item 2: tool-definition token estimate guards #176 regression
    test("estimateToolDefinitionTokens returns chars/4 of name + description") {
        let tokens = TokenUsage.estimateToolDefinitionTokens(
            name: "calculator", description: "Performs arithmetic operations")
        let expected = max(1, ("calculator".count + "Performs arithmetic operations".count) / 4)
        try assertEqual(tokens, expected)
    }

    test("estimateToolDefinitionTokens floors at 1 for empty name and description") {
        try assertEqual(TokenUsage.estimateToolDefinitionTokens(name: "", description: ""), 1)
    }

    test("estimateToolDefinitionTokens grows with description length") {
        let short = TokenUsage.estimateToolDefinitionTokens(name: "add", description: "Add two numbers")
        let long = TokenUsage.estimateToolDefinitionTokens(name: "add", description: "Add two numbers together and return the sum of the operands as an integer")
        try assertTrue(long > short)
    }
}
