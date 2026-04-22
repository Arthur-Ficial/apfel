// ============================================================================
// ChatRequestValidator.swift — Shared validation for chat completion requests
// Part of ApfelCore — pure request validation, no HTTP/framework dependency
// ============================================================================

import Foundation

/// Chat-completions request fields that ApfelCore rejects explicitly.
public enum UnsupportedChatParameter: String, Sendable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Requests token log probabilities in the response.
    case logprobs
    /// Requests multiple completions from one prompt.
    case n
    /// Requests stop-sequence handling that Apple's local model does not expose.
    case stop
    /// Requests OpenAI presence-penalty tuning.
    case presencePenalty = "presence_penalty"
    /// Requests OpenAI frequency-penalty tuning.
    case frequencyPenalty = "frequency_penalty"

    /// The JSON field name for the unsupported parameter.
    public var name: String { rawValue }

    /// The stable user-facing explanation for why the parameter is unsupported.
    public var message: String {
        switch self {
        case .logprobs:
            return "Parameter 'logprobs' is not supported by Apple's on-device model."
        case .n:
            return "Parameter 'n' is not supported by Apple's on-device model. Only n=1 is allowed."
        case .stop:
            return "Parameter 'stop' is not supported by Apple's on-device model."
        case .presencePenalty:
            return "Parameter 'presence_penalty' is not supported by Apple's on-device model."
        case .frequencyPenalty:
            return "Parameter 'frequency_penalty' is not supported by Apple's on-device model."
        }
    }

    public var description: String { name }

    public var debugDescription: String { "UnsupportedChatParameter.\(rawValue)" }

    /// Detects the first unsupported parameter present in a request.
    ///
    /// Detection is intentionally ordered so error reporting stays stable.
    ///
    /// - Parameter request: The decoded chat-completions request.
    /// - Returns: The first unsupported parameter found, or `nil`.
    public static func detect(in request: ChatCompletionRequest) -> UnsupportedChatParameter? {
        if request.logprobs == true {
            return .logprobs
        }
        if let count = request.n, count != 1 {
            return .n
        }
        if request.stop != nil {
            return .stop
        }
        if request.presence_penalty != nil {
            return .presencePenalty
        }
        if request.frequency_penalty != nil {
            return .frequencyPenalty
        }
        return nil
    }
}

/// Stable validation failures for OpenAI-compatible chat-completions requests.
public enum ChatRequestValidationFailure: Sendable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The request did not include any messages.
    case emptyMessages
    /// The request used a parameter ApfelCore does not support.
    case unsupportedParameter(UnsupportedChatParameter)
    /// The final message role was not `user` or `tool`.
    case invalidLastRole
    /// The request included image content.
    case imageContent
    /// A numeric or string parameter had an invalid value.
    case invalidParameterValue(String)
    /// The request asked for a model name other than `apple-foundationmodel`.
    case invalidModel(String)

    /// The stable HTTP-facing error message for this validation failure.
    public var message: String {
        switch self {
        case .emptyMessages:
            return "'messages' must contain at least one message"
        case .unsupportedParameter(let parameter):
            return parameter.message
        case .invalidLastRole:
            return "Last message must have role 'user' or 'tool'"
        case .imageContent:
            return "Image content is not supported by the Apple on-device model"
        case .invalidParameterValue(let detail):
            return detail
        case .invalidModel(let model):
            return "The model '\(model)' does not exist. The only available model is 'apple-foundationmodel'."
        }
    }

    /// The stable log/debug event string for this validation failure.
    public var event: String {
        switch self {
        case .emptyMessages:
            return "validation failed: empty messages"
        case .unsupportedParameter(let parameter):
            return "validation failed: unsupported parameter \(parameter.name)"
        case .invalidLastRole:
            return "validation failed: last role != user/tool"
        case .imageContent:
            return "rejected: image content"
        case .invalidParameterValue(let detail):
            return "validation failed: \(detail)"
        case .invalidModel(let model):
            return "validation failed: unknown model \(model)"
        }
    }

    public var description: String { message }

    public var debugDescription: String { event }
}

public enum ChatRequestValidator {
    /// The only model name this server accepts.
    public static let validModel = "apple-foundationmodel"

    /// Validates a decoded chat-completions request.
    ///
    /// - Parameter request: The request to validate.
    /// - Returns: The first validation failure encountered, or `nil`.
    public static func validate(_ request: ChatCompletionRequest) -> ChatRequestValidationFailure? {
        guard !request.messages.isEmpty else {
            return .emptyMessages
        }

        if request.model != validModel {
            return .invalidModel(request.model)
        }

        if let unsupported = UnsupportedChatParameter.detect(in: request) {
            return .unsupportedParameter(unsupported)
        }

        guard let lastRole = request.messages.last?.role, ["user", "tool"].contains(lastRole) else {
            return .invalidLastRole
        }

        if request.messages.contains(where: \.containsImageContent) {
            return .imageContent
        }

        if let maxTokens = request.max_tokens, maxTokens <= 0 {
            return .invalidParameterValue("'max_tokens' must be a positive integer, got \(maxTokens)")
        }
        if let temp = request.temperature, temp < 0 {
            return .invalidParameterValue("'temperature' must be non-negative, got \(temp)")
        }
        if let turns = request.x_context_max_turns, turns <= 0 {
            return .invalidParameterValue("'x_context_max_turns' must be a positive integer, got \(turns)")
        }
        if let reserve = request.x_context_output_reserve, reserve <= 0 {
            return .invalidParameterValue("'x_context_output_reserve' must be a positive integer, got \(reserve)")
        }

        return nil
    }
}
