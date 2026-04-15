// ============================================================================
// FinishReasonResolver.swift — Pure decision logic for OpenAI's finish_reason
// ============================================================================

import Foundation

public enum FinishReason: Sendable, Equatable {
    case stop
    case length
    case toolCalls

    public var openAIValue: String {
        switch self {
        case .stop: return "stop"
        case .length: return "length"
        case .toolCalls: return "tool_calls"
        }
    }
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
