// ============================================================================
// ResponsesModels.swift - Pure request layer for POST /v1/responses (#365)
// Part of ApfelCore - no FoundationModels dependency
//
// The OpenAI Responses API is served as a translation layer: decode a
// ResponsesRequest here, validate it (honest 501s for everything the
// on-device model cannot do), map it onto the existing chat internals
// (OpenAIMessage / OpenAITool), and let the executable run the same
// pipeline /v1/chat/completions uses.
// ============================================================================

import Foundation

// MARK: - Request

/// Decoded `POST /v1/responses` request (the subset apfel supports plus the
/// fields it must SEE to reject honestly).
public struct ResponsesRequest: Decodable, Sendable {

    /// `input`: either a plain string or a list of message-ish items.
    public enum Input: Sendable {
        case text(String)
        case items([ResponsesInputItem])
    }

    public let model: String?
    public let input: Input?
    public let instructions: String?
    public let stream: Bool?
    public let temperature: Double?
    public let top_p: Double?
    public let max_output_tokens: Int?
    public let metadata: [String: String]?
    public let text: ResponsesTextConfig?
    public let tools: [ResponsesTool]?
    public let tool_choice: ToolChoice?

    // Seen-to-reject fields (honest 501s).
    public let previous_response_id: String?
    public let background: Bool?
    public let store: Bool?
    public let include: [String]?
    /// True when a `reasoning` object was present in the request.
    public let hasReasoning: Bool

    enum CodingKeys: String, CodingKey {
        case model, input, instructions, stream, temperature, top_p,
             max_output_tokens, metadata, text, tools, tool_choice,
             previous_response_id, background, store, include, reasoning
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        if let s = try? c.decodeIfPresent(String.self, forKey: .input) {
            input = .text(s)
        } else if let items = try c.decodeIfPresent([ResponsesInputItem].self, forKey: .input) {
            input = .items(items)
        } else {
            input = nil
        }
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        stream = try c.decodeIfPresent(Bool.self, forKey: .stream)
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature)
        top_p = try c.decodeIfPresent(Double.self, forKey: .top_p)
        max_output_tokens = try c.decodeIfPresent(Int.self, forKey: .max_output_tokens)
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata)
        text = try c.decodeIfPresent(ResponsesTextConfig.self, forKey: .text)
        tools = try c.decodeIfPresent([ResponsesTool].self, forKey: .tools)
        tool_choice = try c.decodeIfPresent(ToolChoice.self, forKey: .tool_choice)
        previous_response_id = try c.decodeIfPresent(String.self, forKey: .previous_response_id)
        background = try c.decodeIfPresent(Bool.self, forKey: .background)
        store = try c.decodeIfPresent(Bool.self, forKey: .store)
        include = try c.decodeIfPresent([String].self, forKey: .include)
        hasReasoning = c.contains(.reasoning)
    }
}

/// One entry of a list-form `input`. Message items carry role + content;
/// non-message item types (function_call_output, item_reference, ...) are
/// decoded by `type` only so the validator can 501 them by name.
public struct ResponsesInputItem: Decodable, Sendable {
    public let type: String?
    public let role: String?
    /// Flattened text of the content (string form, or `input_text` /
    /// `output_text` parts joined with newlines).
    public let textContent: String?

    enum CodingKeys: String, CodingKey { case type, role, content }

    private struct Part: Decodable {
        let type: String?
        let text: String?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        if let s = try? c.decodeIfPresent(String.self, forKey: .content) {
            textContent = s
        } else if let parts = try? c.decodeIfPresent([Part].self, forKey: .content) {
            textContent = parts.compactMap(\.text).joined(separator: "\n")
        } else {
            textContent = nil
        }
    }
}

/// `text` config: output format selection.
public struct ResponsesTextConfig: Decodable, Sendable {
    public let format: ResponsesTextFormat?
}

/// `text.format`: `text`, `json_object`, or `json_schema` (+ name/schema).
public struct ResponsesTextFormat: Decodable, Sendable {
    public let type: String?
    public let name: String?
    public let schema: RawJSON?
}

/// Responses-style tool definition: FLAT (name/description/parameters live
/// on the tool itself, not nested under `function` as in chat completions).
public struct ResponsesTool: Decodable, Sendable {
    public let type: String
    public let name: String?
    public let description: String?
    public let parameters: RawJSON?
}

// MARK: - Mapper

/// Pure translation from a ResponsesRequest onto the chat-internals types.
public enum ResponsesMapper {

    /// Build chat-style messages: `instructions` becomes a leading system
    /// message; a string input is a single user turn; list inputs map per
    /// item with the Responses `developer` role folded into `system`.
    public static func messages(from request: ResponsesRequest) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        if let instructions = request.instructions, !instructions.isEmpty {
            messages.append(OpenAIMessage(role: "system", content: .text(instructions)))
        }
        switch request.input {
        case .text(let s)?:
            messages.append(OpenAIMessage(role: "user", content: .text(s)))
        case .items(let items)?:
            for item in items {
                guard let role = item.role else { continue }
                let mapped = role == "developer" ? "system" : role
                messages.append(OpenAIMessage(role: mapped, content: .text(item.textContent ?? "")))
            }
        case nil:
            break
        }
        return messages
    }

    /// Convert flat Responses function tools into nested chat-style tools.
    /// Non-function tools never reach here (the validator 501s them).
    public static func tools(from request: ResponsesRequest) -> [OpenAITool]? {
        guard let tools = request.tools, !tools.isEmpty else { return nil }
        return tools.compactMap { tool in
            guard tool.type == "function", let name = tool.name else { return nil }
            return OpenAITool(type: "function", function: OpenAIFunction(
                name: name, description: tool.description, parameters: tool.parameters))
        }
    }
}

// MARK: - Validator

/// Request validation policy for /v1/responses. Mirrors the chat validator's
/// shape: one ordered pass, each failure knows its HTTP status and message.
public enum ResponsesRequestValidator {

    static let validModel = "apple-foundationmodel"
    static let allowedRoles: Set<String> = ["system", "developer", "user", "assistant"]
    static let allowedFormats: Set<String> = ["text", "json_object", "json_schema"]

    public enum Failure: Equatable, Sendable {
        case missingModel
        case invalidModel(String)
        case missingInput
        case emptyInput
        case unknownRole(String)
        case invalidLastRole(String)
        case invalidTextFormat(String)
        case missingSchema
        case invalidRange(String)
        /// A feature the on-device model / this stateless server does not
        /// support. Always a 501 with a plain-spoken message.
        case unsupported(String)

        public var httpStatusCode: Int {
            switch self {
            case .invalidModel: return 404
            case .unsupported: return 501
            default: return 400
            }
        }

        public var message: String {
            switch self {
            case .missingModel:
                return "'model' is required."
            case .invalidModel(let m):
                return "Model '\(m)' not found. This server serves only '\(validModel)'."
            case .missingInput:
                return "'input' is required (a string or a list of message items)."
            case .emptyInput:
                return "'input' must not be empty."
            case .unknownRole(let r):
                return "Unknown input role '\(r)' (allowed: system, developer, user, assistant)."
            case .invalidLastRole(let r):
                return "The last input item must be a user turn, got role '\(r)'."
            case .invalidTextFormat(let t):
                return "Unsupported text.format.type '\(t)' (supported: text, json_object, json_schema)."
            case .missingSchema:
                return "text.format json_schema requires a 'schema' object."
            case .invalidRange(let what):
                return what
            case .unsupported(let feature):
                switch feature {
                case "previous_response_id":
                    return "'previous_response_id' is not supported: apfel is stateless and never stores responses. Resend the full conversation in 'input'."
                case "store":
                    return "'store: true' is not supported: apfel is stateless and never stores responses."
                case "background":
                    return "'background' is not supported by this on-device server."
                case "reasoning":
                    return "'reasoning' is not supported by Apple's on-device model."
                case "include":
                    return "'include' is not supported by this server."
                case "tools with stream":
                    return "Function tools with 'stream: true' are not yet supported on /v1/responses. Use stream: false."
                case "json_schema with stream":
                    return "text.format json_schema with 'stream: true' is not yet supported on /v1/responses. Use stream: false."
                default:
                    return "'\(feature)' is not supported by this server."
                }
            }
        }

        public var errorCode: String? {
            if case .invalidModel = self { return "model_not_found" }
            return nil
        }

        public var errorParam: String? {
            if case .invalidModel = self { return "model" }
            return nil
        }

        public var event: String {
            "responses validation failed: \(message)"
        }
    }

    public static func validate(_ r: ResponsesRequest) -> Failure? {
        // Model first (matches the chat handler's 404 behavior).
        guard let model = r.model, !model.isEmpty else { return .missingModel }
        guard model == validModel else { return .invalidModel(model) }

        // Honest 501s before anything else: say what we will not do.
        if r.previous_response_id != nil { return .unsupported("previous_response_id") }
        if r.background == true { return .unsupported("background") }
        if r.hasReasoning { return .unsupported("reasoning") }
        if r.store == true { return .unsupported("store") }
        if let include = r.include, !include.isEmpty { return .unsupported("include") }
        if let tools = r.tools {
            for tool in tools where tool.type != "function" {
                return .unsupported("tools[].type=\(tool.type)")
            }
            if !tools.isEmpty && r.stream == true { return .unsupported("tools with stream") }
        }
        if r.text?.format?.type == "json_schema" && r.stream == true {
            return .unsupported("json_schema with stream")
        }

        // Input shape.
        switch r.input {
        case nil:
            return .missingInput
        case .text(let s)?:
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyInput }
        case .items(let items)?:
            guard let last = items.last else { return .emptyInput }
            for item in items {
                if let type = item.type, type != "message" {
                    return .unsupported("input[].type=\(type)")
                }
                if let role = item.role, !allowedRoles.contains(role) {
                    return .unknownRole(role)
                }
            }
            if last.role != "user" { return .invalidLastRole(last.role ?? "none") }
        }

        // Output format.
        if let format = r.text?.format {
            let type = format.type ?? "text"
            guard allowedFormats.contains(type) else { return .invalidTextFormat(type) }
            if type == "json_schema" && format.schema?.value == nil { return .missingSchema }
        }

        // Numeric ranges (same policy as chat completions, #235).
        if let t = r.temperature, !(0...2).contains(t) {
            return .invalidRange("'temperature' must be between 0 and 2, got \(t).")
        }
        if let p = r.top_p, !(0...1).contains(p) {
            return .invalidRange("'top_p' must be between 0 and 1, got \(p).")
        }
        if let m = r.max_output_tokens, m <= 0 {
            return .invalidRange("'max_output_tokens' must be positive, got \(m).")
        }
        return nil
    }
}
