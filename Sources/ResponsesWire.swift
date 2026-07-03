// ============================================================================
// ResponsesWire.swift - OpenAI Responses API wire format (#365)
// Response envelope, output items, usage, and the named-SSE event encoders.
// The request side lives in ApfelCore (ResponsesModels.swift); this file is
// executable-side because responses encode next to the HTTP server.
// ============================================================================

import Foundation
import ApfelCore

// MARK: - Raw JSON re-encoding

/// Encodes an already-serialized JSON string as a real JSON fragment (object,
/// array, or scalar) instead of a quoted string. Used to echo tool parameter
/// schemas and json_schema definitions back on the response envelope.
struct RawJSONValue: Encodable {
    let json: String

    private enum Fragment: Encodable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([Fragment])
        case object([String: Fragment])

        init(_ any: Any) {
            switch any {
            case is NSNull: self = .null
            case let n as NSNumber:
                if CFGetTypeID(n) == CFBooleanGetTypeID() { self = .bool(n.boolValue) }
                else if n.doubleValue == n.doubleValue.rounded(), let i = any as? Int { self = .int(i) }
                else { self = .double(n.doubleValue) }
            case let s as String: self = .string(s)
            case let a as [Any]: self = .array(a.map(Fragment.init))
            case let o as [String: Any]: self = .object(o.mapValues(Fragment.init))
            default: self = .null
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .null: try c.encodeNil()
            case .bool(let v): try c.encode(v)
            case .int(let v): try c.encode(v)
            case .double(let v): try c.encode(v)
            case .string(let v): try c.encode(v)
            case .array(let v): try c.encode(v)
            case .object(let v): try c.encode(v)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            try c.encodeNil()
            return
        }
        try c.encode(Fragment(obj))
    }
}

// MARK: - Output items

/// One entry of the response's `output` array.
enum ResponsesOutputItem: Encodable {
    /// An assistant message with one output_text part (or a refusal part).
    case message(id: String, text: String?, refusal: String?, status: String)
    /// A function tool call the client should execute.
    case functionCall(id: String, callId: String, name: String, arguments: String, status: String)

    var itemId: String {
        switch self {
        case .message(let id, _, _, _): return id
        case .functionCall(let id, _, _, _, _): return id
        }
    }

    private enum Keys: String, CodingKey {
        case type, id, status, role, content, call_id, name, arguments
    }
    private enum PartKeys: String, CodingKey {
        case type, text, annotations, refusal
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .message(id, text, refusal, status):
            try c.encode("message", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(status, forKey: .status)
            try c.encode("assistant", forKey: .role)
            var parts = c.nestedUnkeyedContainer(forKey: .content)
            if let refusal {
                var part = parts.nestedContainer(keyedBy: PartKeys.self)
                try part.encode("refusal", forKey: .type)
                try part.encode(refusal, forKey: .refusal)
            } else if let text {
                var part = parts.nestedContainer(keyedBy: PartKeys.self)
                try part.encode("output_text", forKey: .type)
                try part.encode(text, forKey: .text)
                try part.encode([String](), forKey: .annotations)
            }
        case let .functionCall(id, callId, name, arguments, status):
            try c.encode("function_call", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(status, forKey: .status)
            try c.encode(callId, forKey: .call_id)
            try c.encode(name, forKey: .name)
            try c.encode(arguments, forKey: .arguments)
        }
    }
}

// MARK: - Usage

struct ResponsesUsage: Encodable {
    let input_tokens: Int
    let output_tokens: Int

    private enum Keys: String, CodingKey {
        case input_tokens, output_tokens, total_tokens
        case input_tokens_details, output_tokens_details
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(input_tokens, forKey: .input_tokens)
        try c.encode(output_tokens, forKey: .output_tokens)
        try c.encode(input_tokens + output_tokens, forKey: .total_tokens)
        try c.encode(["cached_tokens": 0], forKey: .input_tokens_details)
        try c.encode(["reasoning_tokens": 0], forKey: .output_tokens_details)
    }
}

// MARK: - Response envelope

/// The `response` object: full spec surface with explicit nulls so strict
/// clients (openai SDK pydantic models) validate cleanly.
struct ResponsesEnvelope: Encodable {
    let id: String
    let createdAt: Int
    let status: String                 // "in_progress" | "completed" | "incomplete"
    let instructions: String?
    let maxOutputTokens: Int?
    let metadata: [String: String]?
    let output: [ResponsesOutputItem]
    let temperature: Double?
    let topP: Double?
    let formatType: String             // "text" | "json_object" | "json_schema"
    let formatName: String?
    let formatSchemaJSON: String?
    let toolsEcho: [ResponsesToolEcho]
    let usage: ResponsesUsage?
    let incompleteReason: String?

    private enum Keys: String, CodingKey {
        case id, object, created_at, status, background, error,
             incomplete_details, instructions, max_output_tokens, metadata,
             model, output, parallel_tool_calls, previous_response_id,
             reasoning, store, temperature, text, tool_choice, tools, top_p,
             truncation, usage, user
    }
    private enum FormatKeys: String, CodingKey { case format }
    private enum FormatInnerKeys: String, CodingKey { case type, name, schema }
    private enum IncompleteKeys: String, CodingKey { case reason }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode("response", forKey: .object)
        try c.encode(createdAt, forKey: .created_at)
        try c.encode(status, forKey: .status)
        try c.encode(false, forKey: .background)
        try c.encodeNil(forKey: .error)
        if let incompleteReason {
            var inc = c.nestedContainer(keyedBy: IncompleteKeys.self, forKey: .incomplete_details)
            try inc.encode(incompleteReason, forKey: .reason)
        } else {
            try c.encodeNil(forKey: .incomplete_details)
        }
        try c.encode(instructions, forKey: .instructions)
        try c.encode(maxOutputTokens, forKey: .max_output_tokens)
        try c.encode(metadata ?? [:], forKey: .metadata)
        try c.encode(modelName, forKey: .model)
        try c.encode(output, forKey: .output)
        try c.encode(false, forKey: .parallel_tool_calls)
        try c.encodeNil(forKey: .previous_response_id)
        try c.encodeNil(forKey: .reasoning)
        try c.encode(false, forKey: .store)
        try c.encode(temperature, forKey: .temperature)
        var text = c.nestedContainer(keyedBy: FormatKeys.self, forKey: .text)
        var format = text.nestedContainer(keyedBy: FormatInnerKeys.self, forKey: .format)
        try format.encode(formatType, forKey: .type)
        if formatType == "json_schema" {
            try format.encode(formatName ?? "schema", forKey: .name)
            if let schemaJSON = formatSchemaJSON {
                try format.encode(RawJSONValue(json: schemaJSON), forKey: .schema)
            }
        }
        try c.encode("auto", forKey: .tool_choice)
        try c.encode(toolsEcho, forKey: .tools)
        try c.encode(topP, forKey: .top_p)
        try c.encode("disabled", forKey: .truncation)
        if let usage { try c.encode(usage, forKey: .usage) } else { try c.encodeNil(forKey: .usage) }
        try c.encodeNil(forKey: .user)
    }
}

/// Echo of a flat Responses function tool on the envelope.
struct ResponsesToolEcho: Encodable {
    let name: String
    let description: String?
    let parametersJSON: String?

    private enum Keys: String, CodingKey { case type, name, description, parameters, strict }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode("function", forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        if let parametersJSON {
            try c.encode(RawJSONValue(json: parametersJSON), forKey: .parameters)
        } else {
            try c.encodeNil(forKey: .parameters)
        }
        try c.encode(false, forKey: .strict)
    }
}

// MARK: - SSE events

/// Encode one named Responses SSE event: `event: <type>` + `data: <json>`.
func responsesEventLine(type: String, payload: some Encodable) -> String {
    "event: \(type)\ndata: \(jsonString(payload, pretty: false))\n\n"
}

struct ResponsesLifecycleEvent: Encodable {
    let type: String
    let sequence_number: Int
    let response: ResponsesEnvelope
}

struct ResponsesOutputItemEvent: Encodable {
    let type: String
    let sequence_number: Int
    let output_index: Int
    let item: ResponsesOutputItem
}

struct ResponsesContentPartEvent: Encodable {
    let type: String
    let sequence_number: Int
    let item_id: String
    let output_index: Int
    let content_index: Int
    let text: String

    private enum Keys: String, CodingKey {
        case type, sequence_number, item_id, output_index, content_index, part
    }
    private enum PartKeys: String, CodingKey { case type, text, annotations }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(type, forKey: .type)
        try c.encode(sequence_number, forKey: .sequence_number)
        try c.encode(item_id, forKey: .item_id)
        try c.encode(output_index, forKey: .output_index)
        try c.encode(content_index, forKey: .content_index)
        var part = c.nestedContainer(keyedBy: PartKeys.self, forKey: .part)
        try part.encode("output_text", forKey: .type)
        try part.encode(text, forKey: .text)
        try part.encode([String](), forKey: .annotations)
    }
}

struct ResponsesTextDeltaEvent: Encodable {
    let type = "response.output_text.delta"
    let sequence_number: Int
    let item_id: String
    let output_index: Int
    let content_index: Int
    let delta: String
    let logprobs: [String] = []

    private enum Keys: String, CodingKey {
        case type, sequence_number, item_id, output_index, content_index, delta, logprobs
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(type, forKey: .type)
        try c.encode(sequence_number, forKey: .sequence_number)
        try c.encode(item_id, forKey: .item_id)
        try c.encode(output_index, forKey: .output_index)
        try c.encode(content_index, forKey: .content_index)
        try c.encode(delta, forKey: .delta)
        try c.encode(logprobs, forKey: .logprobs)
    }
}

struct ResponsesTextDoneEvent: Encodable {
    let type = "response.output_text.done"
    let sequence_number: Int
    let item_id: String
    let output_index: Int
    let content_index: Int
    let text: String
    let logprobs: [String] = []

    private enum Keys: String, CodingKey {
        case type, sequence_number, item_id, output_index, content_index, text, logprobs
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(type, forKey: .type)
        try c.encode(sequence_number, forKey: .sequence_number)
        try c.encode(item_id, forKey: .item_id)
        try c.encode(output_index, forKey: .output_index)
        try c.encode(content_index, forKey: .content_index)
        try c.encode(text, forKey: .text)
        try c.encode(logprobs, forKey: .logprobs)
    }
}

struct ResponsesErrorEvent: Encodable {
    let type = "error"
    let sequence_number: Int
    let message: String

    private enum Keys: String, CodingKey { case type, sequence_number, message, code, param }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(type, forKey: .type)
        try c.encode(sequence_number, forKey: .sequence_number)
        try c.encode(message, forKey: .message)
        try c.encodeNil(forKey: .code)
        try c.encodeNil(forKey: .param)
    }
}
