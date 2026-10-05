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

    // MARK: - refusalBase (#516)

    test("refusalBase with no rounds falls back to counted prompt tokens") {
        let base = TokenUsage.refusalBase(rounds: [], countedPromptTokens: 42)
        try assertEqual(base.promptTokens, 42)
        try assertEqual(base.priorCompletionTokens, 0)
    }

    test("refusalBase with one round uses reported prompt and completion tokens") {
        let round = TokenUsage(promptTokens: 60, completionTokens: 25)
        let base = TokenUsage.refusalBase(rounds: [round], countedPromptTokens: 999)
        try assertEqual(base.promptTokens, 60)
        try assertEqual(base.priorCompletionTokens, 25)
    }

    test("refusalBase with repair round sums both rounds") {
        let initial = TokenUsage(promptTokens: 60, completionTokens: 25)
        let repair = TokenUsage(promptTokens: 110, completionTokens: 18)
        let base = TokenUsage.refusalBase(rounds: [initial, repair], countedPromptTokens: 999)
        try assertEqual(base.promptTokens, 170)
        try assertEqual(base.priorCompletionTokens, 43)
    }

    test("refusalBase ignores countedPromptTokens when rounds are present") {
        let round = TokenUsage(promptTokens: 7, completionTokens: 3)
        let base = TokenUsage.refusalBase(rounds: [round], countedPromptTokens: 1_000_000)
        try assertEqual(base.promptTokens, 7)
    }
}
