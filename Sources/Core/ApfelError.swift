import Foundation

public enum ApfelError: Error, Equatable, Hashable, Sendable {
    case guardrailViolation
    case refusal(String)
    case contextOverflow
    /// Context overflow with the real numbers: on macOS 27 the runtime's
    /// typed `LanguageModelError.contextSizeExceeded` carries the prompt's
    /// token count and the window size, and apfel's own pre-generation
    /// budget check knows the same two numbers. The wire shape (type,
    /// status, exit code) is identical to `.contextOverflow`; only the
    /// message gains the counts (#510, #197).
    case contextWindowExceeded(tokenCount: Int, contextSize: Int)
    case rateLimited
    /// Rate limited with a known reset: macOS 27's typed
    /// `LanguageModelError.rateLimited` can carry a `resetDate`, which the
    /// server surfaces as a `Retry-After` header on the 429 (#510, #197).
    case rateLimitedUntil(retryAfterSeconds: Int)
    case concurrentRequest
    case assetsUnavailable
    case unsupportedGuide
    case decodingFailure(String)
    case unsupportedLanguage(String)
    case toolExecution(String)
    /// Image input that passed wire validation but could not be used
    /// (undecodable bytes, or image content reaching generation on an OS
    /// without vision support) - always a client-input 400 (#510).
    case invalidImageInput(String)
    case unknown(String)

    /// Classify any thrown error into a typed ApfelError.
    /// Matches on FoundationModels GenerationError / LanguageModelError first,
    /// falls back to string matching.
    public static func classify(_ error: Error) -> ApfelError {
        if let already = error as? ApfelError { return already }
        if let mcpError = error as? MCPError {
            return .toolExecution(mcpError.description)
        }
        // FoundationModels ToolCallError is unreachable - apfel runs tools out-of-band; see #119

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
        let isFoundationModelsError =
            typeName.contains("GenerationError") || mirror.contains("GenerationError")
            || typeName.contains("LanguageModelError") || mirror.contains("LanguageModelError")
        guard isFoundationModelsError else {
            return nil
        }

        guard let generationCase = FoundationModelsGenerationErrorCase.firstMatch(in: mirror) else {
            if mirror.contains("GenerationError") || mirror.contains("LanguageModelError") {
                // A case name is present but unknown to us (#181, #521):
                // return .unknown directly rather than guessing from
                // locale-fragile English keywords.
                return .unknown(localizedDescription)
            }
            // The type is a GenerationError but the mirror carries no case at
            // all. macOS 27 does this to binaries linked against an SDK <= 26.x:
            // mirror "May contain unsafe content", description "Detected content
            // likely to be unsafe" (#193). Only the description is left to go
            // on, so fall through to the keyword classifier.
            return nil
        }

        return generationCase.apfelError(localizedDescription: localizedDescription)
    }

    private static func classifyLocalizedDescription(_ description: String) -> ApfelError {
        let desc = description.lowercased()
        if desc.contains(anyOf: ["refused", "refusal", "declined"]) {
            return .refusal(description)
        }
        if desc.contains(anyOf: ["guardrail", "content policy", "unsafe"]) {
            return .guardrailViolation
        }
        // Rate-limit wording often contains "exceeded" too ("rate limit
        // exceeded"), so it must be checked before the overflow keywords.
        if desc.contains(anyOf: ["rate limit", "ratelimited", "rate_limit"]) {
            return .rateLimited
        }
        if desc.contains(anyOf: ["context window", "exceeded"]) {
            return .contextOverflow
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
        case .refusal:             return "[refusal]"
        case .contextOverflow:     return "[context overflow]"
        case .contextWindowExceeded: return "[context overflow]"
        case .rateLimited:         return "[rate limited]"
        case .rateLimitedUntil:    return "[rate limited]"
        case .concurrentRequest:   return "[busy]"
        case .assetsUnavailable:   return "[model loading]"
        case .unsupportedGuide:    return "[unsupported guide]"
        case .decodingFailure:     return "[decoding failure]"
        case .unsupportedLanguage: return "[unsupported language]"
        case .toolExecution:       return "[tool error]"
        case .invalidImageInput:   return "[image input]"
        case .unknown:             return "[error]"
        }
    }

    public var openAIType: String {
        switch self {
        case .guardrailViolation:  return "content_policy_violation"
        case .refusal:             return "content_policy_violation"
        case .contextOverflow:     return "context_length_exceeded"
        case .contextWindowExceeded: return "context_length_exceeded"
        case .rateLimited:         return "rate_limit_error"
        case .rateLimitedUntil:    return "rate_limit_error"
        case .concurrentRequest:   return "rate_limit_error"
        case .assetsUnavailable:   return "server_error"
        case .unsupportedGuide:    return "invalid_request_error"
        case .decodingFailure:     return "server_error"
        case .unsupportedLanguage: return "invalid_request_error"
        case .toolExecution:       return "server_error"
        case .invalidImageInput:   return "invalid_request_error"
        case .unknown:             return "server_error"
        }
    }

    /// HTTP status code for this error type.
    ///
    /// `.refusal` returns 200 because an output-side refusal is a successful
    /// completion per the OpenAI wire format: HTTP 200 with
    /// `finish_reason: "content_filter"` and the refusal text on the assistant
    /// message. The CLI exit-code mapping stays separate (`ApfelExitCodes`).
    public var httpStatusCode: Int {
        switch self {
        case .guardrailViolation:  return 400
        case .refusal:             return 200
        case .contextOverflow:     return 400
        case .contextWindowExceeded: return 400
        case .rateLimited:         return 429
        case .rateLimitedUntil:    return 429
        case .concurrentRequest:   return 429
        case .assetsUnavailable:   return 503
        case .unsupportedGuide:    return 400
        case .decodingFailure:     return 500
        case .unsupportedLanguage: return 400
        case .toolExecution:       return 500
        case .invalidImageInput:   return 400
        case .unknown:             return 500
        }
    }

    public var openAIMessage: String {
        switch self {
        case .guardrailViolation:
            return "The request was blocked by Apple's safety guardrails. Try rephrasing."
        case .refusal(let explanation):
            return "The on-device model refused the request: \(explanation)"
        case .contextOverflow:
            // No hardcoded size: the window is dynamic (TokenCounter.contextSize)
            // and this string must stay true if the OS changes it (#330, #192).
            return "Input exceeds the model's context window. Shorten the conversation history."
        case .contextWindowExceeded(let tokenCount, let contextSize):
            // The numbers are runtime-reported (or runtime-counted), never
            // hardcoded - the window stays dynamic (#330, #192).
            return "Input exceeds the model's context window: the input is \(tokenCount) tokens, the window is \(contextSize) tokens. Shorten the conversation history."
        case .rateLimited:
            return "Apple Intelligence is rate limited. Retry after a few seconds."
        case .rateLimitedUntil(let seconds):
            return "Apple Intelligence is rate limited. Retry after \(seconds) second\(seconds == 1 ? "" : "s")."
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
        case .invalidImageInput(let msg):
            return msg
        case .unknown(let msg):
            return msg
        }
    }

    /// Whether this error type is transient and should be retried.
    /// Uses typed matching (locale-independent) — safe on any macOS language.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .rateLimitedUntil, .concurrentRequest, .assetsUnavailable:
            return true
        default:
            return false
        }
    }

    /// The `Retry-After` value for the server's 429, when the runtime
    /// reported a reset date (macOS 27, #510). Nil for every other case.
    public var retryAfterSeconds: Int? {
        if case .rateLimitedUntil(let seconds) = self { return seconds }
        return nil
    }

    /// Seconds until `resetDate`, rounded up and clamped to at least 1 -
    /// a `Retry-After: 0` (or a negative value) would tell clients to hammer.
    public static func retryAfterSeconds(until resetDate: Date, now: Date = Date()) -> Int {
        max(1, Int(resetDate.timeIntervalSince(now).rounded(.up)))
    }
}

private enum FoundationModelsGenerationErrorCase: String, CaseIterable {
    // GenerationError case names (macOS 26)
    case guardrailViolation
    case refusal
    case exceededContextWindowSize
    case rateLimited
    case concurrentRequests
    case unsupportedLanguageOrLocale
    case assetsUnavailable
    case unsupportedGuide
    case decodingFailure
    // LanguageModelError case names that differ from GenerationError (macOS 27, #521)
    case contextSizeExceeded
    case unsupportedGenerationGuide

    static func firstMatch(in mirror: String) -> FoundationModelsGenerationErrorCase? {
        allCases.first { mirror.contains($0.rawValue) }
    }

    func apfelError(localizedDescription: String) -> ApfelError {
        switch self {
        case .guardrailViolation:
            return .guardrailViolation
        case .refusal:
            return .refusal(localizedDescription)
        case .exceededContextWindowSize, .contextSizeExceeded:
            return .contextOverflow
        case .rateLimited:
            return .rateLimited
        case .concurrentRequests:
            return .concurrentRequest
        case .unsupportedLanguageOrLocale:
            return .unsupportedLanguage(localizedDescription)
        case .assetsUnavailable:
            return .assetsUnavailable
        case .unsupportedGuide, .unsupportedGenerationGuide:
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
        case .refusal(let message):
            return "ApfelError.refusal(\(String(reflecting: message)))"
        case .contextOverflow:
            return "ApfelError.contextOverflow"
        case .contextWindowExceeded(let tokenCount, let contextSize):
            return "ApfelError.contextWindowExceeded(tokenCount: \(tokenCount), contextSize: \(contextSize))"
        case .rateLimited:
            return "ApfelError.rateLimited"
        case .rateLimitedUntil(let seconds):
            return "ApfelError.rateLimitedUntil(retryAfterSeconds: \(seconds))"
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
        case .invalidImageInput(let message):
            return "ApfelError.invalidImageInput(\(String(reflecting: message)))"
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
