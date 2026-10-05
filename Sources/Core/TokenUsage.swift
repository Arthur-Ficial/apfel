// ============================================================================
// TokenUsage.swift — Pure per-model-call token usage (#510 item 1, #504)
//
// One model call's prompt/completion token numbers on their way to the wire
// (OpenAI `usage`, Responses `usage`). Where the numbers come from is the
// executable's decision: on macOS 27+ the FoundationModels runtime reports
// them with every response; on macOS 26 apfel counts them via the tokenizer.
// ApfelCore only carries and combines the numbers - it never touches the SDK.
// ============================================================================

import Foundation

/// Token usage for one model call.
///
/// A single request can make several model calls (tool-call rounds, a tool
/// policy repair round); `sum(_:)` combines their per-call usage into the one
/// `usage` object the request reports, following the OpenAI convention that
/// usage totals every token the request processed.
public struct TokenUsage: Sendable, Equatable {
    /// Tokens in the model input, including any framing the runtime adds.
    public let promptTokens: Int
    /// Tokens the model generated.
    public let completionTokens: Int
    /// Prompt tokens served from the runtime's prefix cache (a subset of
    /// `promptTokens`). 0 when the source has no cache data (counted path).
    public let cachedPromptTokens: Int

    public init(promptTokens: Int, completionTokens: Int, cachedPromptTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cachedPromptTokens = cachedPromptTokens
    }

    /// Prompt plus completion tokens - the wire `total_tokens` value.
    public var totalTokens: Int {
        promptTokens + completionTokens
    }

    /// Field-wise sum of this call's usage and another call's.
    public func adding(_ other: TokenUsage) -> TokenUsage {
        TokenUsage(
            promptTokens: promptTokens + other.promptTokens,
            completionTokens: completionTokens + other.completionTokens,
            cachedPromptTokens: cachedPromptTokens + other.cachedPromptTokens)
    }

    /// Combine per-call usage across the model calls of one request.
    ///
    /// Returns nil when no call reported usage - the caller's signal to fall
    /// back to counted numbers (the macOS 26 path).
    public static func sum(_ rounds: [TokenUsage]) -> TokenUsage? {
        guard var total = rounds.first else { return nil }
        for round in rounds.dropFirst() {
            total = total.adding(round)
        }
        return total
    }

    /// Compute prompt and prior-completion tokens for a refusal that follows
    /// zero or more completed model rounds. On macOS 27 the runtime reports
    /// per-round usage and the sum is the source of truth; on macOS 26 no
    /// runtime usage exists and the caller falls back to a counted prompt
    /// figure (the discarded output is folded in as a prompt adjustment).
    public static func refusalBase(
        rounds: [TokenUsage],
        countedPromptTokens: Int
    ) -> (promptTokens: Int, priorCompletionTokens: Int) {
        if let reported = sum(rounds) {
            return (reported.promptTokens, reported.completionTokens)
        }
        return (countedPromptTokens, 0)
    }
}
