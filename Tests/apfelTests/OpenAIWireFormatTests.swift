// ============================================================================
// OpenAIWireFormatTests.swift — JSON wire-format lockdown for the OpenAI-
// compatible types exposed by ApfelCore. Once #105 makes ApfelCore a public
// Swift Package product, any drift in key names, nil-omission rules, or
// enum raw values is a breaking change for every third-party client. This
// file is the contract.
//
// What's covered:
//   - OpenAIMessage.encode (custom encoder): content always present (null when
//     nil), refusal present (null when nil, string when set), optional fields
//     omitted when nil
//   - MessageContent encodes as string for .text and array for .parts
//   - ContentPart default synthesized encoding (nil text omitted)
//   - ToolCall / ToolCallFunction default encoding
//   - ChatCompletionRequest decodes all snake_case fields
//   - ToolChoice string and object forms, plus "none" case
//   - ResponseFormat decoding
//   - ContextStrategy raw values (used as x_context_strategy wire parameter)
//   - FinishReason.openAIValue
// ============================================================================

import Foundation
import ApfelCore

private func sortedEncode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    return String(data: data, encoding: .utf8) ?? ""
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

func runOpenAIWireFormatTests() {

    // MARK: - OpenAIMessage.encode (custom encoder — spec requires content+refusal always present)

    test("OpenAIMessage text content: content present, refusal null, optionals omitted") {
        let msg = OpenAIMessage(role: "user", content: .text("hi"))
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":"hi","refusal":null,"role":"user"}"#
        )
    }

    test("OpenAIMessage nil content still encodes content as explicit null") {
        // OpenAI spec: assistant responses with no text must send content:null,
        // not omit the key. Custom encoder guarantees this.
        let msg = OpenAIMessage(role: "assistant", content: nil)
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":null,"refusal":null,"role":"assistant"}"#
        )
    }

    test("OpenAIMessage refusal is serialized as string when set") {
        let msg = OpenAIMessage(role: "assistant", content: nil, refusal: "I cannot help with that.")
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":null,"refusal":"I cannot help with that.","role":"assistant"}"#
        )
    }

    test("OpenAIMessage refusal is serialized as null when not set") {
        let msg = OpenAIMessage(role: "assistant", content: .text("ok"))
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":"ok","refusal":null,"role":"assistant"}"#
        )
    }

    test("OpenAIMessage with tool_calls field present") {
        let call = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "add", arguments: "{}")
        )
        let msg = OpenAIMessage(role: "assistant", content: nil, tool_calls: [call])
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":null,"refusal":null,"role":"assistant","tool_calls":[{"function":{"arguments":"{}","name":"add"},"id":"call_1","type":"function"}]}"#
        )
    }

    test("OpenAIMessage with tool role includes tool_call_id and name") {
        let msg = OpenAIMessage(
            role: "tool",
            content: .text("42"),
            tool_call_id: "call_abc",
            name: "calculator"
        )
        let json = try sortedEncode(msg)
        try assertEqual(
            json,
            #"{"content":"42","name":"calculator","refusal":null,"role":"tool","tool_call_id":"call_abc"}"#
        )
    }

    // MARK: - MessageContent / ContentPart

    test("MessageContent.text encodes as a bare JSON string") {
        let content = MessageContent.text("hello")
        let json = try sortedEncode(content)
        try assertEqual(json, #""hello""#)
    }

    test("MessageContent.parts encodes as a JSON array") {
        let content = MessageContent.parts([
            ContentPart(type: "text", text: "a"),
            ContentPart(type: "text", text: "b"),
        ])
        let json = try sortedEncode(content)
        try assertEqual(
            json,
            #"[{"text":"a","type":"text"},{"text":"b","type":"text"}]"#
        )
    }

    test("ContentPart with nil text omits the text key") {
        let part = ContentPart(type: "image_url", text: nil)
        let json = try sortedEncode(part)
        try assertEqual(json, #"{"type":"image_url"}"#)
    }

    test("MessageContent.text round-trips through JSONDecoder") {
        let json = #""hi there""#
        let content = try decode(MessageContent.self, from: json)
        guard case .text(let s) = content, s == "hi there" else {
            throw TestFailure("expected .text(\"hi there\"), got \(content)")
        }
    }

    test("MessageContent.parts round-trips through JSONDecoder") {
        let json = #"[{"type":"text","text":"part"}]"#
        let content = try decode(MessageContent.self, from: json)
        guard case .parts(let parts) = content,
              parts.count == 1,
              parts[0].type == "text",
              parts[0].text == "part"
        else {
            throw TestFailure("expected single text part, got \(content)")
        }
    }

    // MARK: - ToolCall / ToolCallFunction

    test("ToolCall encodes id/type/function fields") {
        let call = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "add", arguments: #"{"a":1,"b":2}"#)
        )
        let json = try sortedEncode(call)
        try assertEqual(
            json,
            #"{"function":{"arguments":"{\"a\":1,\"b\":2}","name":"add"},"id":"call_1","type":"function"}"#
        )
    }

    test("ToolCall round-trips via Codable") {
        let original = ToolCall(
            id: "call_xyz",
            type: "function",
            function: ToolCallFunction(name: "lookup", arguments: "{}")
        )
        let data = try JSONEncoder().encode(original)
        let roundTripped = try JSONDecoder().decode(ToolCall.self, from: data)
        try assertEqual(roundTripped, original)
    }

    test("ToolCallFunction.arguments is a JSON-string, not a nested object") {
        // OpenAI spec: function.arguments is always a STRING containing
        // serialized JSON. Changing this type would break every SDK.
        let fn = ToolCallFunction(name: "f", arguments: #"{"k":"v"}"#)
        let json = try sortedEncode(fn)
        try assertEqual(
            json,
            #"{"arguments":"{\"k\":\"v\"}","name":"f"}"#
        )
    }

    // MARK: - ChatCompletionRequest (Decodable) — snake_case field names are the wire contract

    test("ChatCompletionRequest decodes every known field using snake_case keys") {
        let json = #"""
        {
          "model": "apple-foundationmodel",
          "messages": [{"role": "user", "content": "hi"}],
          "stream": true,
          "stream_options": {"include_usage": true},
          "temperature": 0.7,
          "max_tokens": 256,
          "seed": 42,
          "tools": [],
          "tool_choice": "auto",
          "response_format": {"type": "json_object"},
          "logprobs": false,
          "n": 1,
          "presence_penalty": 0.0,
          "frequency_penalty": 0.0,
          "user": "tester",
          "x_context_strategy": "sliding-window",
          "x_context_max_turns": 5,
          "x_context_output_reserve": 256
        }
        """#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.model, "apple-foundationmodel")
        try assertEqual(req.messages.count, 1)
        try assertEqual(req.stream, true)
        try assertEqual(req.stream_options?.include_usage, true)
        try assertEqual(req.temperature, 0.7)
        try assertEqual(req.max_tokens, 256)
        try assertEqual(req.seed, 42)
        try assertNotNil(req.tools)
        try assertEqual(req.tools?.count, 0)
        try assertEqual(req.tool_choice, .auto)
        try assertEqual(req.response_format?.type, "json_object")
        try assertEqual(req.logprobs, false)
        try assertEqual(req.n, 1)
        try assertEqual(req.presence_penalty, 0.0)
        try assertEqual(req.frequency_penalty, 0.0)
        try assertEqual(req.user, "tester")
        try assertEqual(req.x_context_strategy, "sliding-window")
        try assertEqual(req.x_context_max_turns, 5)
        try assertEqual(req.x_context_output_reserve, 256)
    }

    test("ChatCompletionRequest missing optional fields decode as nil") {
        let json = #"""
        {"model": "apple-foundationmodel", "messages": [{"role": "user", "content": "hi"}]}
        """#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertNil(req.stream)
        try assertNil(req.temperature)
        try assertNil(req.max_tokens)
        try assertNil(req.seed)
        try assertNil(req.tools)
        try assertNil(req.tool_choice)
        try assertNil(req.response_format)
        try assertNil(req.logprobs)
        try assertNil(req.n)
        try assertNil(req.presence_penalty)
        try assertNil(req.frequency_penalty)
        try assertNil(req.user)
        try assertNil(req.x_context_strategy)
        try assertNil(req.x_context_max_turns)
        try assertNil(req.x_context_output_reserve)
    }

    // MARK: - ToolChoice — "none" case (not covered elsewhere)

    test("ToolChoice decodes \"none\" string") {
        let choice = try decode(ToolChoice.self, from: #""none""#)
        try assertEqual(choice, ToolChoice.none)
    }

    test("ToolChoice falls back to auto for empty object") {
        let choice = try decode(ToolChoice.self, from: "{}")
        try assertEqual(choice, .auto)
    }

    // MARK: - ResponseFormat

    test("ResponseFormat decodes type=json_object") {
        let fmt = try decode(ResponseFormat.self, from: #"{"type":"json_object"}"#)
        try assertEqual(fmt.type, "json_object")
    }

    test("ResponseFormat decodes type=text") {
        let fmt = try decode(ResponseFormat.self, from: #"{"type":"text"}"#)
        try assertEqual(fmt.type, "text")
    }

    // MARK: - ContextStrategy raw values (wire contract for x_context_strategy)

    test("ContextStrategy raw values match x_context_strategy wire format") {
        try assertEqual(ContextStrategy.newestFirst.rawValue,   "newest-first")
        try assertEqual(ContextStrategy.oldestFirst.rawValue,   "oldest-first")
        try assertEqual(ContextStrategy.slidingWindow.rawValue, "sliding-window")
        try assertEqual(ContextStrategy.summarize.rawValue,     "summarize")
        try assertEqual(ContextStrategy.strict.rawValue,        "strict")
    }

    test("ContextStrategy.allCases covers every public case exactly once") {
        // Locks the set so adding a new strategy forces an explicit test update.
        let all = Set(ContextStrategy.allCases)
        let expected: Set<ContextStrategy> = [
            .newestFirst, .oldestFirst, .slidingWindow, .summarize, .strict,
        ]
        try assertEqual(all, expected)
    }

    // MARK: - FinishReason wire values

    test("FinishReason.openAIValue for every case") {
        try assertEqual(FinishReason.stop.openAIValue,          "stop")
        try assertEqual(FinishReason.length.openAIValue,        "length")
        try assertEqual(FinishReason.toolCalls.openAIValue,     "tool_calls")
        try assertEqual(FinishReason.contentFilter.openAIValue, "content_filter")
    }

    // MARK: - StreamOptions equality (public Equatable conformance)

    test("StreamOptions is Equatable with include_usage") {
        let a = try decode(StreamOptions.self, from: #"{"include_usage":true}"#)
        let b = try decode(StreamOptions.self, from: #"{"include_usage":true}"#)
        try assertEqual(a, b)
    }
}
