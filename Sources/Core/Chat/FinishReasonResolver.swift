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

    /// The OpenAI-compatible wire value for this finish reason.
    public var openAIValue: String {
        switch self {
        case .stop: return "stop"
        case .length: return "length"
        case .toolCalls: return "tool_calls"
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
