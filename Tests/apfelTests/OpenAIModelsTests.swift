import Foundation
import ApfelCore

private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

func runOpenAIModelsTests() {
    test("OpenAIMessage textContent returns plain string") {
        let message = OpenAIMessage(role: "user", content: .text("hello"))
        try assertEqual(message.textContent, "hello")
    }

    test("OpenAIMessage textContent joins text parts") {
        let message = OpenAIMessage(
            role: "user",
            content: .parts([
                ContentPart(type: "text", text: "hello"),
                ContentPart(type: "text", text: " world"),
            ])
        )
        try assertEqual(message.textContent, "hello world")
    }

    test("OpenAIMessage textContent returns nil when image parts are present") {
        let message = OpenAIMessage(
            role: "user",
            content: .parts([
                ContentPart(type: "text", text: "look"),
                ContentPart(type: "image_url", text: nil),
            ])
        )
        try assertTrue(message.containsImageContent)
        try assertNil(message.textContent)
    }

    test("ToolChoice decodes required string") {
        let choice = try decode(ToolChoice.self, from: #""required""#)
        try assertEqual(choice, .required)
    }

    test("ToolChoice decodes specific function object") {
        let choice = try decode(ToolChoice.self, from: #"{"function":{"name":"lookup"}}"#)
        try assertEqual(choice, .specific(name: "lookup"))
    }

    test("ToolChoice falls back to auto for unknown string") {
        let choice = try decode(ToolChoice.self, from: #""auto""#)
        try assertEqual(choice, .auto)
    }

    test("ChatCompletionRequest decodes stream_options.include_usage=true") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stream":true,"stream_options":{"include_usage":true}}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.stream_options?.include_usage, true)
    }

    test("ChatCompletionRequest decodes stream_options.include_usage=false") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stream":true,"stream_options":{"include_usage":false}}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.stream_options?.include_usage, false)
    }

    test("ChatCompletionRequest stream_options is nil when absent") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stream":true}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertNil(req.stream_options)
    }

    test("ChatCompletionRequest stream_options.include_usage is nil when object empty") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stream":true,"stream_options":{}}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertNotNil(req.stream_options)
        try assertNil(req.stream_options?.include_usage)
    }

    test("RawJSON preserves nested tool parameter schemas as valid JSON") {
        let tool = try decode(OpenAITool.self, from:
            #"{"type":"function","function":{"name":"weather","description":"lookup","parameters":{"type":"object","properties":{"city":{"type":"string"}}}}}"#
        )
        let raw = try unwrap(tool.function.parameters, "expected parameters JSON")
        let parsed = try JSONSerialization.jsonObject(with: Data(raw.value.utf8)) as? [String: Any]
        try assertEqual(parsed?["type"] as? String, "object")
        try assertNotNil((parsed?["properties"] as? [String: Any])?["city"])
    }
}

func runChatRequestValidatorTests() {
    let M = ChatRequestValidator.validModel  // "apple-foundationmodel"

    test("validator rejects empty messages") {
        let request = try decode(ChatCompletionRequest.self, from: #"{"model":"\#(M)","messages":[]}"#)
        try assertEqual(ChatRequestValidator.validate(request), .emptyMessages)
    }

    test("validator rejects invalid model name") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"gpt-4o","messages":[{"role":"user","content":"hi"}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .invalidModel("gpt-4o"))
    }

    test("validator accepts valid model name") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}]}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects unsupported parameters") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"presence_penalty":1}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .unsupportedParameter(.presencePenalty)
        )
    }

    test("validator allows compatibility no-ops for n=1 and logprobs=false") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"n":1,"logprobs":false}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects assistant as last message") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"assistant","content":"hi"}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .invalidLastRole)
    }

    test("validator allows tool as last message") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"tool","tool_call_id":"call_1","name":"lookup","content":"result"}]}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects image content") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":[{"type":"text","text":"look"},{"type":"image_url"}]}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .imageContent)
    }

    test("validator exposes stable failure metadata") {
        try assertEqual(ChatRequestValidationFailure.invalidLastRole.message, "Last message must have role 'user' or 'tool'")
        try assertEqual(ChatRequestValidationFailure.invalidLastRole.event, "validation failed: last role != user/tool")
        try assertEqual(
            ChatRequestValidationFailure.unsupportedParameter(.frequencyPenalty).message,
            "Parameter 'frequency_penalty' is not supported by Apple's on-device model."
        )
    }

    test("validator rejects max_tokens <= 0") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"max_tokens":0}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for max_tokens=0")
        }
    }

    test("validator rejects negative temperature") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"temperature":-1.0}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for temperature=-1")
        }
    }

    test("validator accepts valid max_tokens and temperature") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"max_tokens":100,"temperature":0.7}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects x_context_max_turns <= 0") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"x_context_max_turns":0}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for x_context_max_turns=0")
        }
    }

    test("validator rejects x_context_output_reserve <= 0") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"x_context_output_reserve":-1}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for x_context_output_reserve=-1")
        }
    }
}

private func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message) }
    return value
}
