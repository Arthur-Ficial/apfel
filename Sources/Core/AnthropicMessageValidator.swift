// ============================================================================
// AnthropicMessageValidator.swift — Pure validation for Anthropic Messages
// API requests. No HTTP/framework dependency. Mirrors ChatRequestValidator.
// ============================================================================

import Foundation

/// Stable validation failures for Anthropic Messages API requests.
public enum AnthropicValidationFailure: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The request did not include a model name.
    case missingModel
    /// `max_tokens` was absent or not a positive integer.
    case invalidMaxTokens
    /// The request did not include any messages.
    case emptyMessages
    /// A message used a role other than `user` or `assistant`.
    case invalidRole(String)
    /// A `tool_result` / `tool_use` block was malformed.
    case malformedToolBlock(String)

    /// The HTTP-facing error message for this validation failure.
    public var message: String {
        switch self {
        case .missingModel:
            return "'model' is required and must be a non-empty string"
        case .invalidMaxTokens:
            return "'max_tokens' is required and must be a positive integer"
        case .emptyMessages:
            return "'messages' must contain at least one message"
        case .invalidRole(let role):
            return "Message role must be 'user' or 'assistant', got '\(role)'"
        case .malformedToolBlock(let detail):
            return detail
        }
    }

    public var description: String { message }
}

public enum AnthropicMessageValidator {
    /// Validate a decoded Anthropic Messages API request.
    ///
    /// - Returns: The first validation failure, or `nil` when the request is valid.
    public static func validate(_ request: AnthropicMessagesRequest) -> AnthropicValidationFailure? {
        guard !request.model.isEmpty else {
            return .missingModel
        }
        guard let maxTokens = request.maxTokens, maxTokens > 0 else {
            return .invalidMaxTokens
        }
        guard !request.messages.isEmpty else {
            return .emptyMessages
        }

        for message in request.messages {
            guard message.role == "user" || message.role == "assistant" else {
                return .invalidRole(message.role)
            }
            for block in message.content.asBlocks {
                switch block {
                case .toolUse(let id, let name, _):
                    if id.isEmpty || name.isEmpty {
                        return .malformedToolBlock("tool_use block requires non-empty 'id' and 'name'")
                    }
                case .toolResult(let toolUseID, _, _):
                    if toolUseID.isEmpty {
                        return .malformedToolBlock("tool_result block requires a non-empty 'tool_use_id'")
                    }
                case .text, .image:
                    break
                }
            }
        }

        return nil
    }
}
