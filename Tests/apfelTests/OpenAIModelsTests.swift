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

    test("ToolChoice decodes auto string") {
        let choice = try decode(ToolChoice.self, from: #""auto""#)
        try assertEqual(choice, .auto)
    }

    test("ToolChoice decodes unrecognized string to .invalid (#238)") {
        let choice = try decode(ToolChoice.self, from: #""banana""#)
        try assertEqual(choice, .invalid("banana"))
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

    test("RawJSON decodes scalar JSON string as a quoted JSON literal") {
        let raw = try decode(RawJSON.self, from: #""hello""#)
        try assertEqual(raw.value, #""hello""#)
    }

    test("RawJSON decodes scalar number as a numeric JSON literal") {
        let raw = try decode(RawJSON.self, from: "42")
        try assertEqual(raw.value, "42")
    }

    test("RawJSON decodes scalar boolean as a boolean JSON literal") {
        let raw = try decode(RawJSON.self, from: "true")
        try assertEqual(raw.value, "true")
    }

    test("ChatCompletionRequest decodes top_p") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"top_p":0.9}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.top_p, 0.9)
    }

    test("ChatCompletionRequest top_p defaults to nil when absent") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}]}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertNil(req.top_p)
    }

    test("RawJSON decodes arrays as valid JSON array text") {
        let raw = try decode(RawJSON.self, from: #"[1,"two",false]"#)
        let parsed = try JSONSerialization.jsonObject(with: Data(raw.value.utf8)) as? [Any]
        try assertEqual(parsed?.count, 3)
        try assertEqual(parsed?[0] as? Int, 1)
        try assertEqual(parsed?[1] as? String, "two")
        try assertEqual(parsed?[2] as? Bool, false)
    }

    // MARK: - joinedInstructionContent (#390)

    test("joinedInstructionContent returns nil when no system messages exist") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertNil(messages.joinedInstructionContent)
    }

    test("joinedInstructionContent returns single system message text") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertEqual(messages.joinedInstructionContent, "Be concise.")
    }

    test("joinedInstructionContent joins multiple system messages with double newlines (#390)") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "system", content: .text("Always answer in JSON.")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertEqual(messages.joinedInstructionContent, "Be concise.\n\nAlways answer in JSON.")
    }

    test("joinedInstructionContent skips system messages with empty text") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "system", content: .text("")),
            OpenAIMessage(role: "system", content: .text("Answer in English.")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertEqual(messages.joinedInstructionContent, "Be concise.\n\nAnswer in English.")
    }

    test("joinedInstructionContent folds developer messages in too (#405)") {
        // `developer` is an instruction channel, not a conversation turn. It
        // used to survive the system filter and then be dropped silently by
        // historyEntry, deleting the turn with no error.
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "developer", content: .text("Prefer metric units.")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertEqual(messages.joinedInstructionContent,
                        "Be concise.\n\nPrefer metric units.")
    }

    test("joinedInstructionContent returns nil when all system messages are empty") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertNil(messages.joinedInstructionContent)
    }

    test("joinedInstructionContent returns nil for nil content system message") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: nil),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertNil(messages.joinedInstructionContent)
    }

    test("joinedInstructionContent preserves order of system messages") {
        let messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("First.")),
            OpenAIMessage(role: "user", content: .text("middle")),
            OpenAIMessage(role: "system", content: .text("Second.")),
            OpenAIMessage(role: "user", content: .text("hello")),
        ]
        try assertEqual(messages.joinedInstructionContent, "First.\n\nSecond.")
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

    test("invalidModel failure maps to 404 model_not_found param model (#236)") {
        let failure = ChatRequestValidationFailure.invalidModel("gpt-4o")
        try assertEqual(failure.httpStatusCode, 404)
        try assertEqual(failure.errorCode, "model_not_found")
        try assertEqual(failure.errorParam, "model")
    }

    test("non-model failures map to 400 with nil code and param (#236)") {
        try assertEqual(ChatRequestValidationFailure.emptyMessages.httpStatusCode, 400)
        try assertNil(ChatRequestValidationFailure.emptyMessages.errorCode)
        try assertNil(ChatRequestValidationFailure.emptyMessages.errorParam)
        try assertEqual(ChatRequestValidationFailure.invalidLastRole.httpStatusCode, 400)
        try assertNil(ChatRequestValidationFailure.invalidParameterValue("x").errorCode)
        try assertNil(ChatRequestValidationFailure.invalidParameterValue("x").errorParam)
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

    test("validator rejects empty string content in last user message (#233)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":""}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .emptyLastMessageContent)
    }

    test("validator rejects null content in last user message (#233)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":null}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .emptyLastMessageContent)
    }

    test("validator allows tool last message with empty content (#233)") {
        // Tool-role final messages use a synthetic prompt, so empty content is fine.
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"tool","tool_call_id":"c1","name":"x","content":""}]}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
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

    test("validator rejects temperature > 2 (#235)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"temperature":5.0}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for temperature=5.0")
        }
    }

    test("validator rejects top_p > 1 (#235)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"top_p":2.0}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for top_p=2.0")
        }
    }

    test("validator rejects top_p < 0 (#235)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"top_p":-0.5}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for top_p=-0.5")
        }
    }

    test("validator accepts top_p at boundaries 0 and 1 (#235)") {
        let lo = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"top_p":0.0}"#
        )
        try assertNil(ChatRequestValidator.validate(lo))
        let hi = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"top_p":1.0}"#
        )
        try assertNil(ChatRequestValidator.validate(hi))
    }

    test("validator accepts temperature at upper bound 2 (#235)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"temperature":2.0}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator accepts valid max_tokens and temperature") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"max_tokens":100,"temperature":0.7}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects negative seed") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"seed":-1}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'seed' must be a non-negative integer, got -1")
        )
    }

    test("validator accepts non-negative seed") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"seed":42}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator accepts seed of zero") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"seed":0}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects unknown x_context_strategy listing valid values (#237)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"x_context_strategy":"sliding-window-typo"}"#
        )
        guard case .invalidParameterValue(let detail) = ChatRequestValidator.validate(request) else {
            throw TestFailure("expected .invalidParameterValue for unknown x_context_strategy")
        }
        try assertTrue(detail.contains("newest-first"))
        try assertTrue(detail.contains("sliding-window-typo"))
    }

    test("validator accepts every valid x_context_strategy (#237)") {
        for strategy in ContextStrategy.allCases {
            let request = try decode(
                ChatCompletionRequest.self,
                from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"x_context_strategy":"\#(strategy.rawValue)"}"#
            )
            try assertNil(ChatRequestValidator.validate(request))
        }
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

    test("unsupported parameter detection prefers logprobs over every later unsupported field") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"logprobs":true,"n":2,"stop":"done","presence_penalty":1,"frequency_penalty":1}"#
        )
        try assertEqual(UnsupportedChatParameter.detect(in: request), .logprobs)
    }

    test("unsupported parameter detection prefers n over stop and penalties") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"n":2,"stop":"done","presence_penalty":1,"frequency_penalty":1}"#
        )
        try assertEqual(UnsupportedChatParameter.detect(in: request), .n)
    }

    test("unsupported parameter detection prefers stop over penalties") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"stop":"done","presence_penalty":1,"frequency_penalty":1}"#
        )
        try assertEqual(UnsupportedChatParameter.detect(in: request), .stop)
    }

    test("unsupported parameter detection prefers presence penalty over frequency penalty") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"presence_penalty":1,"frequency_penalty":1}"#
        )
        try assertEqual(UnsupportedChatParameter.detect(in: request), .presencePenalty)
    }

    test("validator rejects invalid tool_choice string (#238)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tool_choice":"banana"}"#
        )
        guard case .invalidParameterValue(let detail) = ChatRequestValidator.validate(request) else {
            throw TestFailure("expected .invalidParameterValue for tool_choice=banana")
        }
        try assertTrue(detail.contains("tool_choice"))
    }

    test("validator rejects undecodable tool_choice object (#238)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tool_choice":{"foo":"bar"}}"#
        )
        if case .invalidParameterValue = ChatRequestValidator.validate(request) { } else {
            throw TestFailure("expected .invalidParameterValue for undecodable tool_choice object")
        }
    }

    test("validator accepts recognized tool_choice values (#238)") {
        for raw in [#""auto""#, #""none""#, #""required""#, #"{"type":"function","function":{"name":"f"}}"#] {
            let request = try decode(
                ChatCompletionRequest.self,
                from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tool_choice":\#(raw)}"#
            )
            try assertNil(ChatRequestValidator.validate(request))
        }
    }

    test("validator prioritizes empty messages before invalid model") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"gpt-4o","messages":[]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .emptyMessages)
    }

    test("validator prioritizes invalid model before unsupported parameters") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"gpt-4o","messages":[{"role":"user","content":"hi"}],"logprobs":true}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .invalidModel("gpt-4o"))
    }

    test("validator prioritizes unsupported parameters before invalid last role") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"assistant","content":"hi"}],"logprobs":true}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .unsupportedParameter(.logprobs))
    }

    test("validator prioritizes invalid last role before image content") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"assistant","content":[{"type":"image_url"}]}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .invalidLastRole)
    }

    test("validator prioritizes image content before numeric parameter validation") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":[{"type":"image_url"}]}],"max_tokens":0,"temperature":-1}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .imageContent)
    }

    test("validator reports max_tokens before later invalid numeric fields") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"max_tokens":0,"temperature":-1,"x_context_max_turns":0,"x_context_output_reserve":0}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'max_tokens' must be a positive integer, got 0")
        )
    }

    test("validator reports temperature before negative seed") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"temperature":-1,"seed":-1}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'temperature' must be non-negative, got -1.0")
        )
    }

    test("validator reports negative seed before invalid context knobs") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"seed":-1,"x_context_max_turns":0,"x_context_output_reserve":0}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'seed' must be a non-negative integer, got -1")
        )
    }

    test("validator reports temperature before invalid context knobs that follow it") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"temperature":-1,"x_context_max_turns":0,"x_context_output_reserve":0}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'temperature' must be non-negative, got -1.0")
        )
    }

    test("validator reports x_context_max_turns before x_context_output_reserve") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"x_context_max_turns":0,"x_context_output_reserve":0}"#
        )
        try assertEqual(
            ChatRequestValidator.validate(request),
            .invalidParameterValue("'x_context_max_turns' must be a positive integer, got 0")
        )
    }

    // --- Unknown role validation (#405) ---

    test("validator rejects unknown role in history (#405)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"bogus","content":"ctx"},{"role":"user","content":"hi"}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .unknownRole("bogus"))
    }

    test("validator rejects case-sensitive role mismatch (#405)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"User","content":"ctx"},{"role":"user","content":"hi"}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .unknownRole("User"))
    }

    test("validator accepts all known roles in history (#405)") {
        for role in ["system", "developer", "assistant"] {
            let request = try decode(
                ChatCompletionRequest.self,
                from: #"{"model":"\#(M)","messages":[{"role":"\#(role)","content":"ctx"},{"role":"user","content":"hi"}]}"#
            )
            try assertNil(ChatRequestValidator.validate(request))
        }
    }

    test("unknownRole failure has correct metadata (#405)") {
        let failure = ChatRequestValidationFailure.unknownRole("bogus")
        try assertEqual(failure.httpStatusCode, 400)
        try assertEqual(failure.errorParam, "messages")
        try assertNil(failure.errorCode)
        try assertTrue(failure.message.contains("bogus"))
        try assertTrue(failure.message.contains("Supported roles"))
        try assertTrue(failure.event.contains("unknown role bogus"))
    }

    test("knownRoles matches historyEntry handled roles plus system and developer (#405)") {
        let expected: Set<String> = ["system", "developer", "user", "assistant", "tool"]
        try assertEqual(ChatRequestValidator.knownRoles, expected)
    }

    test("validator prioritizes invalid last role before unknown role in history (#405)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"bogus","content":"ctx"},{"role":"assistant","content":"hi"}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .invalidLastRole)
    }

    test("validator prioritizes unknown role before image content (#405)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"bogus","content":"ctx"},{"role":"user","content":[{"type":"image_url"}]}]}"#
        )
        try assertEqual(ChatRequestValidator.validate(request), .unknownRole("bogus"))
    }

    // --- parallel_tool_calls decoding (#480) ---

    test("ChatCompletionRequest decodes parallel_tool_calls=true (#480)") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"parallel_tool_calls":true}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.parallel_tool_calls, true)
    }

    test("ChatCompletionRequest decodes parallel_tool_calls=false (#480)") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"parallel_tool_calls":false}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertEqual(req.parallel_tool_calls, false)
    }

    test("ChatCompletionRequest parallel_tool_calls is nil when absent (#480)") {
        let json = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}]}"#
        let req = try decode(ChatCompletionRequest.self, from: json)
        try assertNil(req.parallel_tool_calls)
    }

    // --- Named tool_choice validation against tools array (#480) ---

    test("validator rejects named tool_choice when name not in tools (#480)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tools":[{"type":"function","function":{"name":"bar","description":"d"}}],"tool_choice":{"type":"function","function":{"name":"foo"}}}"#
        )
        guard case .invalidParameterValue(let detail) = ChatRequestValidator.validate(request) else {
            throw TestFailure("expected .invalidParameterValue for tool_choice naming unknown tool")
        }
        try assertTrue(detail.contains("foo"))
        try assertTrue(detail.contains("bar"))
    }

    test("validator accepts named tool_choice when name matches a tool (#480)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tools":[{"type":"function","function":{"name":"lookup","description":"d"}}],"tool_choice":{"type":"function","function":{"name":"lookup"}}}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator skips named tool_choice check when tools array is empty (#480)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tool_choice":{"type":"function","function":{"name":"f"}}}"#
        )
        try assertNil(ChatRequestValidator.validate(request))
    }

    test("validator rejects named tool_choice among multiple tools when none match (#480)") {
        let request = try decode(
            ChatCompletionRequest.self,
            from: #"{"model":"\#(M)","messages":[{"role":"user","content":"hi"}],"tools":[{"type":"function","function":{"name":"a","description":"d"}},{"type":"function","function":{"name":"b","description":"d"}}],"tool_choice":{"type":"function","function":{"name":"c"}}}"#
        )
        guard case .invalidParameterValue(let detail) = ChatRequestValidator.validate(request) else {
            throw TestFailure("expected .invalidParameterValue for tool_choice naming unknown tool among multiple")
        }
        try assertTrue(detail.contains("c"))
        try assertTrue(detail.contains("a"))
        try assertTrue(detail.contains("b"))
    }
}

private func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message) }
    return value
}
