// ============================================================================
// FinishReasonResolver.swift — Pure decision logic for OpenAI's finish_reason
// ============================================================================

import Foundation

public enum FinishReason: Sendable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The response completed normally.
    case stop
    /// The response stopped because it reached the requested token cap.
    case length
    /// The response ended in a tool-call payload instead of plain text.
    case toolCalls
    /// The model refused to produce a completion; the refusal text is on the
    /// assistant message. OpenAI wire value: "content_filter".
    case contentFilter

    /// The OpenAI-compatible wire value for this finish reason.
    public var openAIValue: String {
        switch self {
        case .stop: return "stop"
        case .length: return "length"
        case .toolCalls: return "tool_calls"
        case .contentFilter: return "content_filter"
        }
    }

    public var description: String { openAIValue }

    public var debugDescription: String { "FinishReason.\(openAIValue)" }
}

public enum FinishReasonResolver {
    /// Selects the OpenAI finish_reason for a completed response.
    /// Tool calls take precedence over length truncation.
    public static func resolve(
        hasToolCalls: Bool,
        completionTokens: Int,
        maxTokens: Int?
    ) -> FinishReason {
        if hasToolCalls { return .toolCalls }
        if let max = maxTokens, completionTokens >= max, completionTokens > 0 {
            return .length
        }
        return .stop
    }
}

/// Why a response ended with `.length` (PR #551 review): the explicit output
/// cap or the context window. Lets the CLI name the real cause instead of
/// always blaming the context window. Package-internal: the OpenAI wire value
/// stays `length` either way.
package enum TruncationCause: Sendable, Equatable {
    /// The explicit `maximumResponseTokens` cap (`--max-tokens N`) was reached.
    case tokenCap(Int)
    /// The context window ran out while generating.
    case contextWindow

    /// Cause for a stream that ended without an error: only the explicit cap
    /// can produce `.length` there (context exhaustion arrives as a thrown
    /// error and is reported as `.contextWindow` by the caller).
    package static func resolve(finishReason: FinishReason, maxTokens: Int?) -> TruncationCause? {
        guard finishReason == .length, let maxTokens else { return nil }
        return .tokenCap(maxTokens)
    }
}
