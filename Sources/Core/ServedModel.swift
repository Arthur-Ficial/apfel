// ============================================================================
// ServedModel.swift - the models `apfel --serve` answers to (ApfelCore).
//
// Pure and FoundationModels-free: maps each OpenAI-facing model id onto the
// `EngineOptions.UseCase` the engine turns into
// `SystemLanguageModel(useCase:guardrails:)`. `apple-foundationmodel` stays
// the default, so every existing client is unaffected.
//
// The content-tagging adapter (SystemLanguageModel.UseCase.contentTagging,
// macOS 26.0+, unchanged in the macOS 27 SDK) returns labels, not prose, and
// is meant to be driven with guided generation (response_format
// json_schema). A probe on macOS 26.7.3 found it never calls a tool, so
// tools are rejected for it rather than silently ignored.
// ============================================================================

import Foundation

/// A model id the OpenAI-compatible server serves.
public enum ServedModel: String, CaseIterable, Sendable, Equatable {
    /// The general-purpose on-device model.
    case general = "apple-foundationmodel"
    /// The content-tagging tuned variant: tags, topics, emotions, actions.
    case contentTagging = "apple-foundationmodel-content-tagging"

    /// The model used when nothing else is asked for.
    public static let `default`: ServedModel = .general

    /// The served model for an exact, case-sensitive id, or `nil`.
    public static func resolve(_ id: String) -> ServedModel? {
        ServedModel(rawValue: id)
    }

    /// Every served id, quoted and comma-separated, for error messages.
    public static var availableList: String {
        allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }

    /// The `SystemLanguageModel.UseCase` this id runs on.
    public var useCase: EngineOptions.UseCase {
        switch self {
        case .general: return .general
        case .contentTagging: return .contentTagging
        }
    }

    /// Whether requests to this model may carry tools (client or MCP).
    public var supportsTools: Bool {
        self == .general
    }

    /// The message for a request that sends tools to a model without them.
    public var toolsUnsupportedMessage: String {
        "'tools' are not supported by model '\(rawValue)': the content-tagging model returns labels and never calls tools. Use '\(ServedModel.general.rawValue)' for tool calling, or describe the labels you want with response_format json_schema."
    }

    private static let toolParameters: Set<String> = ["tools", "tool_choice", "parallel_tool_calls"]

    /// The request parameters `/v1/models` advertises for this model.
    public var supportedParameters: [String] {
        let all = ["temperature", "max_tokens", "max_completion_tokens", "seed", "stop", "stream",
                   "tools", "tool_choice", "parallel_tool_calls", "response_format",
                   "x_context_strategy", "x_context_max_turns", "x_context_output_reserve"]
        return supportsTools ? all : all.filter { !Self.toolParameters.contains($0) }
    }

    /// The runtime-reported capability names this model can honestly
    /// advertise: a model without tool calling drops `tool_calling`.
    public func capabilities(from reported: [String]) -> [String] {
        supportsTools ? reported : reported.filter { $0 != ModelCapability.toolCalling.rawValue }
    }

    /// The `/v1/models` notes text for this model (languages appended by the server).
    public var notes: String {
        switch self {
        case .general:
            return "Apple on-device model via FoundationModels framework. Unsupported parameters are rejected with 400 when present (except n=1 and logprobs=false)."
        case .contentTagging:
            return "Apple on-device content-tagging model (SystemLanguageModel.UseCase.contentTagging) via FoundationModels framework. Returns labels (tags, topics, emotions, actions), not prose; use response_format json_schema, e.g. {\"tags\": [string]}. Tools are not supported. Unsupported parameters are rejected with 400 when present (except n=1 and logprobs=false)."
        }
    }
}
