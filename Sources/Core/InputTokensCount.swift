// ============================================================================
// InputTokensCount.swift - POST /v1/responses/input_tokens (#485)
// Part of ApfelCore - pure data types, no FoundationModels dependency.
//
// The token preflight contract: which Responses parameters a count request
// may carry, the wire report (OpenAI's `response.input_tokens` object plus
// the additive `x_apfel` budget report), and the honest errors - an input
// that does not fit, and a tokenizer that is unavailable or failed. There is
// no approximate path: an error never carries a guessed number.
// ============================================================================

import Foundation

// MARK: - Truncation (shared with /v1/responses generation)

/// The Responses API `truncation` parameter, mapped to the context strategy
/// generation uses, so a count and a generation trim identically.
public enum ResponsesTruncation: String, Sendable, Equatable {
    /// Drop the oldest conversation turns until the input fits (newest-first).
    case auto
    /// Never drop anything: an input over budget is an error.
    case disabled

    /// `nil` (absent) means `auto`, the Responses API default. Unknown values
    /// are rejected earlier by the request validator.
    public init(requestValue: String?) {
        self = requestValue == "disabled" ? .disabled : .auto
    }

    /// The context strategy generation applies for this mode.
    public var contextStrategy: ContextStrategy {
        switch self {
        case .auto: return .newestFirst
        case .disabled: return .strict
        }
    }
}

// MARK: - Request contract

/// Validation for POST /v1/responses/input_tokens. The body is a Responses
/// request restricted to the parameters that shape the model input; anything
/// that only affects sampling or storage is rejected by name instead of being
/// silently ignored, because it would not change the count.
public enum ResponsesInputTokensValidator {

    /// Parameters of OpenAI's input-token count request.
    public static let countParameters: Set<String> = [
        "model", "input", "instructions", "tools", "tool_choice", "text",
        "truncation", "parallel_tool_calls", "previous_response_id",
        "conversation", "reasoning",
    ]

    public enum Failure: Equatable, Sendable {
        /// A failure shared with /v1/responses (model, input, roles, tools,
        /// text.format, truncation, stateless 501s).
        case request(ResponsesRequestValidator.Failure)
        /// A parameter that is not part of the count request.
        case unsupportedParameter(String)
        /// `conversation`: apfel is stateless and stores nothing.
        case conversation
        /// Image input: apfel does not claim an exact count for attachments.
        case imageInput

        public var httpStatusCode: Int {
            switch self {
            case .request(let failure): return failure.httpStatusCode
            case .unsupportedParameter: return 400
            case .conversation, .imageInput: return 501
            }
        }

        public var message: String {
            switch self {
            case .request(let failure):
                return failure.message
            case .unsupportedParameter(let name):
                return "'\(name)' is not a parameter of /v1/responses/input_tokens (it does not change the input tokens). Supported: \(ResponsesInputTokensValidator.countParameters.sorted().joined(separator: ", "))."
            case .conversation:
                return "'conversation' is not supported: apfel is stateless and never stores conversations. Send the full conversation in 'input'."
            case .imageInput:
                return "Counting image input is not supported by /v1/responses/input_tokens. Count the text parts separately."
            }
        }

        public var errorCode: String? {
            if case .request(let failure) = self { return failure.errorCode }
            return nil
        }

        public var errorParam: String? {
            switch self {
            case .request(let failure): return failure.errorParam
            case .unsupportedParameter(let name): return name
            case .conversation: return "conversation"
            case .imageInput: return "input"
            }
        }

        public var event: String {
            "input_tokens validation failed: \(message)"
        }
    }

    /// The top-level keys of a JSON object body; empty for anything else.
    public static func topLevelKeys(of body: Data) -> Set<String> {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return []
        }
        return Set(object.keys)
    }

    /// One ordered pass. `presentKeys` are the body's top-level keys, so
    /// parameters the Responses decoder does not model are still caught.
    public static func validate(_ r: ResponsesRequest, presentKeys: Set<String>) -> Failure? {
        guard let model = r.model, !model.isEmpty else { return .request(.missingModel) }
        guard model == ResponsesRequestValidator.validModel else { return .request(.invalidModel(model)) }
        if let unknown = presentKeys.subtracting(countParameters).sorted().first {
            return .unsupportedParameter(unknown)
        }
        if presentKeys.contains("conversation") { return .conversation }
        if case .items(let items)? = r.input {
            // Files and other part types: named, never dropped from the count.
            if let bad = items.lazy.compactMap(\.unsupportedPartTypes.first).first {
                return .request(.unsupportedContentPart(bad))
            }
            if items.contains(where: { !$0.imageParts.isEmpty }) {
                return .imageInput
            }
        }
        // Images were rejected above, so the image policy never applies.
        return ResponsesRequestValidator.validate(r, imagePolicy: .unsupported).map(Failure.request)
    }
}

// MARK: - Removed-item mapping

extension ResponsesMapper {
    /// The `input` item index of each conversation turn, in the order the
    /// turns reach the transcript. Instruction roles (system, developer) are
    /// folded into the instructions block and have no turn of their own; a
    /// string input is the single item 0.
    public static func conversationInputIndices(from request: ResponsesRequest) -> [Int] {
        switch request.input {
        case .text?:
            return [0]
        case .items(let items)?:
            return items.indices.filter { index in
                guard let role = items[index].role else { return false }
                let mapped = role == "developer" ? "system" : role
                return ![OpenAIMessage].instructionRoles.contains(mapped)
            }
        case nil:
            return []
        }
    }
}

// MARK: - Wire report

/// A successful count: OpenAI's `response.input_tokens` object plus the
/// additive `x_apfel` report of the runtime budget it was measured against.
public struct InputTokensReport: Sendable, Equatable {
    /// Tokens of the input generation would send (after any truncation).
    public let inputTokens: Int
    /// Tokens of the full input before truncation.
    public let untrimmedInputTokens: Int
    /// The model's context window, read at runtime.
    public let contextSize: Int
    /// False when the window is the assumed floor, not a runtime reading.
    public let contextSizeMeasured: Bool
    /// Tokens reserved for the response.
    public let outputReserve: Int
    public let truncation: ResponsesTruncation
    /// `input` item indices truncation removed, oldest first.
    public let removedInputItems: [Int]

    public init(inputTokens: Int, untrimmedInputTokens: Int, contextSize: Int,
                contextSizeMeasured: Bool, outputReserve: Int,
                truncation: ResponsesTruncation, removedInputItems: [Int]) {
        self.inputTokens = inputTokens
        self.untrimmedInputTokens = untrimmedInputTokens
        self.contextSize = contextSize
        self.contextSizeMeasured = contextSizeMeasured
        self.outputReserve = outputReserve
        self.truncation = truncation
        self.removedInputItems = removedInputItems
    }

    /// Tokens available for input: the window minus the output reserve.
    public var inputBudget: Int { contextSize - outputReserve }
    public var fits: Bool { inputTokens <= inputBudget }
    public var trimmed: Bool { inputTokens != untrimmedInputTokens || !removedInputItems.isEmpty }

    private struct Wire: Encodable {
        let object = "response.input_tokens"
        let input_tokens: Int
        let x_apfel: Extension
    }

    private struct Extension: Encodable {
        let context_size: Int
        let context_size_measured: Bool
        let output_reserve: Int
        let input_budget: Int
        let untrimmed_input_tokens: Int
        let input_tokens: Int
        let truncation: String
        let fits: Bool
        let trimmed: Bool
        let removed_input_items: [Int]
        let tokenizer = "apple-foundationmodels"
    }

    /// The JSON body of the 200 response.
    public var jsonString: String {
        let wire = Wire(input_tokens: inputTokens, x_apfel: Extension(
            context_size: contextSize, context_size_measured: contextSizeMeasured,
            output_reserve: outputReserve, input_budget: inputBudget,
            untrimmed_input_tokens: untrimmedInputTokens, input_tokens: inputTokens,
            truncation: truncation.rawValue, fits: fits, trimmed: trimmed,
            removed_input_items: removedInputItems))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(wire), let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Errors

/// The input does not fit the runtime budget: with `truncation: disabled` at
/// all, with `auto` not even after dropping every removable turn.
public struct InputTokensOverflow: Error, Sendable, Equatable {
    public let untrimmedInputTokens: Int
    public let contextSize: Int
    public let outputReserve: Int
    public let truncation: ResponsesTruncation

    public init(untrimmedInputTokens: Int, contextSize: Int, outputReserve: Int, truncation: ResponsesTruncation) {
        self.untrimmedInputTokens = untrimmedInputTokens
        self.contextSize = contextSize
        self.outputReserve = outputReserve
        self.truncation = truncation
    }

    public var inputBudget: Int { contextSize - outputReserve }
    public var httpStatusCode: Int { 400 }
    /// Same type generation uses for an input over the window.
    public var openAIType: String { "context_length_exceeded" }
    public var code: String { "context_length_exceeded" }
    public var param: String { "input" }

    public var message: String {
        let numbers = "The input is \(untrimmedInputTokens) tokens; the input budget is \(inputBudget) tokens (context window \(contextSize) minus \(outputReserve) reserved for output)."
        switch truncation {
        case .disabled:
            return "\(numbers) truncation is 'disabled', so nothing was removed. Shorten the input or use truncation 'auto'."
        case .auto:
            return "\(numbers) It does not fit even after truncation removed every older turn. Shorten the instructions, tools or the last user message."
        }
    }
}

/// Exact token counting is not possible. Never carries an estimate.
public enum TokenCountingError: Error, Sendable, Equatable {
    /// The tokenizer API does not exist on this OS, or the model is down.
    case unavailable(TokenCountFallback)
    /// Apple's tokenizer threw at runtime.
    case failed(String)

    public var httpStatusCode: Int {
        switch self {
        case .unavailable(.osTooOld): return 501
        case .unavailable(.modelUnavailable): return 503
        case .failed: return 503
        }
    }

    public var openAIType: String {
        switch self {
        case .unavailable(.osTooOld): return "invalid_request_error"
        case .unavailable(.modelUnavailable), .failed: return "server_error"
        }
    }

    public var code: String {
        switch self {
        case .unavailable: return "token_counting_unavailable"
        case .failed: return "token_counting_failed"
        }
    }

    public var message: String {
        switch self {
        case .unavailable(.osTooOld(let currentOS)):
            return "Exact token counting is unavailable: Apple's on-device tokenizer API requires macOS 26.4 or later, and this Mac runs macOS \(currentOS). apfel returns no estimate from this endpoint."
        case .unavailable(.modelUnavailable):
            return "Exact token counting is unavailable: Apple Intelligence is not available on this Mac right now. apfel returns no estimate from this endpoint."
        case .failed(let detail):
            return "Apple's tokenizer failed to count this input (\(detail)); no estimate was substituted."
        }
    }
}
