import Foundation

public enum ApfelError: Error, Equatable, Hashable, Sendable {
    case guardrailViolation
    case contextOverflow
    case rateLimited
    case concurrentRequest
    case assetsUnavailable
    case unsupportedGuide
    case decodingFailure(String)
    case unsupportedLanguage(String)
    case toolExecution(String)
    case unknown(String)

    /// Classify any thrown error into a typed ApfelError.
    /// Matches on FoundationModels.GenerationError first, falls back to string matching.
    public static func classify(_ error: Error) -> ApfelError {
        if let already = error as? ApfelError { return already }
        if let mcpError = error as? MCPError {
            return .toolExecution(mcpError.description)
        }

        let typeName = String(describing: type(of: error))
        let mirror = String(reflecting: error)
        if let generationError = classifyGenerationError(
            typeName: typeName,
            mirror: mirror,
            localizedDescription: error.localizedDescription
        ) {
            return generationError
        }

        return classifyLocalizedDescription(error.localizedDescription)
    }

    private static func classifyGenerationError(
        typeName: String,
        mirror: String,
        localizedDescription: String
    ) -> ApfelError? {
        guard typeName.contains("GenerationError") || mirror.contains("GenerationError") else {
            return nil
        }

        guard let generationCase = FoundationModelsGenerationErrorCase.firstMatch(in: mirror) else {
            return nil
        }

        return generationCase.apfelError(localizedDescription: localizedDescription)
    }

    private static func classifyLocalizedDescription(_ description: String) -> ApfelError {
        let desc = description.lowercased()
        if desc.contains(anyOf: ["guardrail", "content policy", "unsafe"]) {
            return .guardrailViolation
        }
        if desc.contains(anyOf: ["context window", "exceeded"]) {
            return .contextOverflow
        }
        if desc.contains(anyOf: ["rate limit", "ratelimited", "rate_limit"]) {
            return .rateLimited
        }
        if desc.contains("concurrent") {
            return .concurrentRequest
        }
        if desc.contains("unsupported language") {
            return .unsupportedLanguage(description)
        }
        return .unknown(description)
    }

    public var cliLabel: String {
        switch self {
        case .guardrailViolation:  return "[guardrail]"
        case .contextOverflow:     return "[context overflow]"
        case .rateLimited:         return "[rate limited]"
        case .concurrentRequest:   return "[busy]"
        case .assetsUnavailable:   return "[model loading]"
        case .unsupportedGuide:    return "[unsupported guide]"
        case .decodingFailure:     return "[decoding failure]"
        case .unsupportedLanguage: return "[unsupported language]"
        case .toolExecution:       return "[tool error]"
        case .unknown:             return "[error]"
        }
    }

    public var openAIType: String {
        switch self {
        case .guardrailViolation:  return "content_policy_violation"
        case .contextOverflow:     return "context_length_exceeded"
        case .rateLimited:         return "rate_limit_error"
        case .concurrentRequest:   return "rate_limit_error"
        case .assetsUnavailable:   return "server_error"
        case .unsupportedGuide:    return "invalid_request_error"
        case .decodingFailure:     return "server_error"
        case .unsupportedLanguage: return "invalid_request_error"
        case .toolExecution:       return "server_error"
        case .unknown:             return "server_error"
        }
    }

    /// HTTP status code for this error type.
    public var httpStatusCode: Int {
        switch self {
        case .guardrailViolation:  return 400
        case .contextOverflow:     return 400
        case .rateLimited:         return 429
        case .concurrentRequest:   return 429
        case .assetsUnavailable:   return 503
        case .unsupportedGuide:    return 400
        case .decodingFailure:     return 500
        case .unsupportedLanguage: return 400
        case .toolExecution:       return 500
        case .unknown:             return 500
        }
    }

    public var openAIMessage: String {
        switch self {
        case .guardrailViolation:
            return "The request was blocked by Apple's safety guardrails. Try rephrasing."
        case .contextOverflow:
            return "Input exceeds the 4096-token context window. Shorten the conversation history."
        case .rateLimited:
            return "Apple Intelligence is rate limited. Retry after a few seconds."
        case .concurrentRequest:
            return "Apple Intelligence is busy with another request. Retry shortly."
        case .assetsUnavailable:
            return "Model assets are loading. Try again in a moment."
        case .unsupportedGuide:
            return "The requested generation guide is not supported by this model."
        case .decodingFailure(let msg):
            return "Model output could not be decoded: \(msg)"
        case .unsupportedLanguage(let msg):
            return "Unsupported language: \(msg)"
        case .toolExecution(let msg):
            return msg
        case .unknown(let msg):
            return msg
        }
    }

    /// Whether this error type is transient and should be retried.
    /// Uses typed matching (locale-independent) — safe on any macOS language.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .concurrentRequest, .assetsUnavailable:
            return true
        default:
            return false
        }
    }
}

private enum FoundationModelsGenerationErrorCase: String, CaseIterable {
    case guardrailViolation
    case refusal
    case exceededContextWindowSize
    case rateLimited
    case concurrentRequests
    case unsupportedLanguageOrLocale
    case assetsUnavailable
    case unsupportedGuide
    case decodingFailure

    static func firstMatch(in mirror: String) -> FoundationModelsGenerationErrorCase? {
        allCases.first { mirror.contains($0.rawValue) }
    }

    func apfelError(localizedDescription: String) -> ApfelError {
        switch self {
        case .guardrailViolation, .refusal:
            return .guardrailViolation
        case .exceededContextWindowSize:
            return .contextOverflow
        case .rateLimited:
            return .rateLimited
        case .concurrentRequests:
            return .concurrentRequest
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage(localizedDescription)
        case .assetsUnavailable:
            return .assetsUnavailable
        case .unsupportedGuide:
            return .unsupportedGuide
        case .decodingFailure:
            return .decodingFailure(localizedDescription)
        }
    }
}

private extension String {
    func contains(anyOf needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

extension ApfelError: LocalizedError, CustomStringConvertible, CustomDebugStringConvertible {
    public var errorDescription: String? { openAIMessage }

    public var description: String { openAIMessage }

    public var debugDescription: String {
        switch self {
        case .guardrailViolation:
            return "ApfelError.guardrailViolation"
        case .contextOverflow:
            return "ApfelError.contextOverflow"
        case .rateLimited:
            return "ApfelError.rateLimited"
        case .concurrentRequest:
            return "ApfelError.concurrentRequest"
        case .assetsUnavailable:
            return "ApfelError.assetsUnavailable"
        case .unsupportedGuide:
            return "ApfelError.unsupportedGuide"
        case .decodingFailure(let message):
            return "ApfelError.decodingFailure(\(String(reflecting: message)))"
        case .unsupportedLanguage(let message):
            return "ApfelError.unsupportedLanguage(\(String(reflecting: message)))"
        case .toolExecution(let message):
            return "ApfelError.toolExecution(\(String(reflecting: message)))"
        case .unknown(let message):
            return "ApfelError.unknown(\(String(reflecting: message)))"
        }
    }
}

/// Check if an error is retryable using ApfelError.classify().
/// Locale-safe: matches on Swift type names, not localizedDescription.
public func isRetryableError(_ error: Error) -> Bool {
    ApfelError.classify(error).isRetryable
}
