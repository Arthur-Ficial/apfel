// ============================================================================
// ApfelCorePublicAPIUsageTests.swift — Compile-time lockdown of the ApfelCore
// public surface at the moment #105 is scoped.
//
// This file exercises every public type, property, method, and enum case that
// a third-party consumer would see once Package.swift starts shipping
// `.library(name: "ApfelCore", ...)`. Purpose:
//
//   - Removing a public symbol ⇒ this file fails to compile.
//   - Renaming a public symbol ⇒ this file fails to compile.
//   - Changing a signature (new required parameter, changed return type) ⇒
//     this file fails to compile.
//   - Removing `Sendable` from a public type ⇒ the `let _: any Sendable = x`
//     line fails to compile.
//
// It is complementary to `swift package diagnose-api-breaking-changes` — that
// tool runs on CI and against the last tag; this file runs on every `swift
// run apfel-tests` and against HEAD, so it catches breakage within a single
// commit before it reaches CI.
//
// Runtime assertions here are minimal and exist only so the test harness has
// something to call. The real work is the compile step.
// ============================================================================

import Foundation
import ApfelCore

private func requireSendable<T: Sendable>(_ value: T) -> T { value }

func runApfelCorePublicAPIUsageTests() {

    // MARK: - ApfelError + isRetryableError(_:)

    test("ApfelError cases, accessors, and classify(_:) are public") {
        let cases: [ApfelError] = [
            .guardrailViolation,
            .contextOverflow,
            .rateLimited,
            .concurrentRequest,
            .assetsUnavailable,
            .unsupportedGuide,
            .decodingFailure("d"),
            .unsupportedLanguage("tlh"),
            .toolExecution("t"),
            .unknown("u"),
        ]
        for e in cases {
            let _: String = e.cliLabel
            let _: String = e.openAIType
            let _: String = e.openAIMessage
            let _: Int    = e.httpStatusCode
            let _: Bool   = e.isRetryable
            let _: String = e.description
            let _: String = e.debugDescription
            let _: String? = e.errorDescription
            let _ = requireSendable(e)
        }
        // Equatable is public.
        try assertEqual(ApfelError.rateLimited, ApfelError.rateLimited)
        let _: Set<ApfelError> = [.rateLimited, .contextOverflow]
        // classify(_:) is public static.
        let classified = ApfelError.classify(MCPError.timedOut("x"))
        if case .toolExecution = classified { } else {
            throw TestFailure("classify(MCPError) should map to .toolExecution")
        }
        // Global function.
        try assertTrue(isRetryableError(ApfelError.rateLimited))
    }

    // MARK: - MCPError (+ LocalizedError, CustomStringConvertible)

    test("MCPError cases and descriptions are public") {
        let cases: [MCPError] = [
            .invalidResponse("x"), .serverError("x"),
            .toolNotFound("x"),    .processError("x"),
            .timedOut("x"),
        ]
        for e in cases {
            let _: String  = e.description
            let _: String? = e.errorDescription
            let _ = requireSendable(e)
        }
        try assertEqual(MCPError.timedOut("a"), MCPError.timedOut("a"))
    }

    // MARK: - MCPProtocol

    test("MCPProtocol public surface compiles") {
        let _: String = MCPProtocol.protocolVersion
        let _: String = MCPProtocol.initializeRequest(id: 1)
        let _: String = MCPProtocol.initializedNotification()
        let _: String = MCPProtocol.toolsListRequest(id: 2)
        let _: String = MCPProtocol.toolsCallRequest(id: 3, name: "f", arguments: "{}")

        let info = try MCPProtocol.parseInitializeResponse(
            #"{"result":{"serverInfo":{"name":"s","version":"1"}}}"#
        )
        let _: String = info.name
        let _: String = info.version
        let _ = requireSendable(info)

        let tools: [OpenAITool] = try MCPProtocol.parseToolsListResponse(
            #"{"result":{"tools":[]}}"#
        )
        try assertEqual(tools.count, 0)

        let call = try MCPProtocol.parseToolCallResponse(
            #"{"result":{"content":[{"text":"ok"}]}}"#
        )
        let _: String = call.text
        let _: Bool   = call.isError
        let _ = requireSendable(call)
    }

    // MARK: - OpenAI types

    test("OpenAI types are constructible and Sendable where declared") {
        let msg = OpenAIMessage(
            role: "user",
            content: .text("hi"),
            tool_calls: nil,
            tool_call_id: nil,
            name: nil,
            refusal: nil
        )
        let _: String            = msg.role
        let _: MessageContent?   = msg.content
        let _: [ToolCall]?       = msg.tool_calls
        let _: String?           = msg.tool_call_id
        let _: String?           = msg.name
        let _: String?           = msg.refusal
        let _: String?           = msg.textContent
        let _: Bool              = msg.containsImageContent
        try assertEqual(msg, msg)
        let _ = requireSendable(msg)

        // MessageContent cases
        let _: MessageContent = .text("x")
        let _: MessageContent = .parts([ContentPart(type: "text", text: "a")])
        let _: Set<MessageContent> = [.text("x")]

        // ContentPart
        let part = ContentPart(type: "text", text: "x")
        let _: String  = part.type
        let _: String? = part.text
        let _ = requireSendable(part)

        // ToolCall / ToolCallFunction
        let fn = ToolCallFunction(name: "add", arguments: "{}")
        let tc = ToolCall(id: "c1", type: "function", function: fn)
        let _: String = tc.id
        let _: String = tc.type
        let _: ToolCallFunction = tc.function
        let _: String = fn.name
        let _: String = fn.arguments
        let _ = requireSendable(tc)

        // OpenAITool / OpenAIFunction
        let tool = OpenAITool(
            type: "function",
            function: OpenAIFunction(name: "n", description: "d", parameters: nil)
        )
        let _: String           = tool.type
        let _: OpenAIFunction   = tool.function
        let _: String           = tool.function.name
        let _: String?          = tool.function.description
        let _: RawJSON?         = tool.function.parameters
        let _ = requireSendable(tool)
        let _: Set<OpenAITool> = [tool]

        // RawJSON
        let raw = RawJSON(rawValue: "{}")
        let _: String = raw.value
        try assertEqual(raw, RawJSON(rawValue: "{}"))

        // ToolChoice
        let _: ToolChoice = .auto
        let _: ToolChoice = .none
        let _: ToolChoice = .required
        let _: ToolChoice = .specific(name: "x")
        let _: Set<ToolChoice> = [.auto, .required]

        // ResponseFormat
        let fmt = ResponseFormat(type: "text")
        let _: String = fmt.type
        let _ = requireSendable(fmt)
        let _: Set<ResponseFormat> = [fmt]
        try assertEqual(
            try JSONDecoder().decode(ResponseFormat.self, from: Data(#"{"type":"text"}"#.utf8)),
            fmt
        )

        // StreamOptions
        let opts = StreamOptions(include_usage: true)
        let _: Bool? = opts.include_usage
        let _ = requireSendable(opts)
        try assertEqual(
            try JSONDecoder().decode(StreamOptions.self, from: Data(#"{"include_usage":true}"#.utf8)),
            opts
        )

        // ChatCompletionRequest
        let req = ChatCompletionRequest(
            model: "apple-foundationmodel",
            messages: [OpenAIMessage(role: "user", content: .text("hi"))]
        )
        let _: String              = req.model
        let _: [OpenAIMessage]     = req.messages
        let _: Bool?               = req.stream
        let _: StreamOptions?      = req.stream_options
        let _: Double?             = req.temperature
        let _: Int?                = req.max_tokens
        let _: Int?                = req.seed
        let _: [OpenAITool]?       = req.tools
        let _: ToolChoice?         = req.tool_choice
        let _: ResponseFormat?     = req.response_format
        let _: Bool?               = req.logprobs
        let _: Int?                = req.n
        let _: RawJSON?            = req.stop
        let _: Double?             = req.presence_penalty
        let _: Double?             = req.frequency_penalty
        let _: String?             = req.user
        let _: String?             = req.x_context_strategy
        let _: Int?                = req.x_context_max_turns
        let _: Int?                = req.x_context_output_reserve
        let _ = requireSendable(req)
        let _: Set<ChatCompletionRequest> = [req]
        try assertEqual(
            try JSONDecoder().decode(
                ChatCompletionRequest.self,
                from: Data(#"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}]}"#.utf8)
            ),
            req
        )
    }

    // MARK: - ChatRequestValidator surface

    test("ChatRequestValidator public surface compiles") {
        try assertEqual(ChatRequestValidator.validModel, "apple-foundationmodel")

        // UnsupportedChatParameter cases
        let params: [UnsupportedChatParameter] = [
            .logprobs, .n, .stop, .presencePenalty, .frequencyPenalty,
        ]
        for p in params {
            let _: String = p.name
            let _: String = p.message
            let _: String = p.rawValue  // RawValue: String is public
            let _: String = p.description
            let _: String = p.debugDescription
            let _ = requireSendable(p)
        }
        let _: Set<UnsupportedChatParameter> = [.logprobs, .stop]

        // ChatRequestValidationFailure cases
        let failures: [ChatRequestValidationFailure] = [
            .emptyMessages,
            .unsupportedParameter(.logprobs),
            .invalidLastRole,
            .imageContent,
            .invalidParameterValue("why"),
            .invalidModel("gpt-5"),
        ]
        for f in failures {
            let _: String = f.message
            let _: String = f.event
            let _: String = f.description
            let _: String = f.debugDescription
            let _ = requireSendable(f)
        }
        let _: Set<ChatRequestValidationFailure> = [.emptyMessages, .invalidLastRole]

        // validate(_:) and detect(in:) are public
        let req = try JSONDecoder().decode(
            ChatCompletionRequest.self,
            from: Data(#"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}]}"#.utf8)
        )
        let _: ChatRequestValidationFailure? = ChatRequestValidator.validate(req)
        let _: UnsupportedChatParameter?     = UnsupportedChatParameter.detect(in: req)
    }

    // MARK: - FinishReason / FinishReasonResolver

    test("FinishReason and FinishReasonResolver public surface compiles") {
        let cases: [FinishReason] = [.stop, .length, .toolCalls]
        for c in cases {
            let _: String = c.openAIValue
            let _: String = c.description
            let _: String = c.debugDescription
            let _ = requireSendable(c)
        }
        let _: Set<FinishReason> = [.stop, .toolCalls]
        let r = FinishReasonResolver.resolve(hasToolCalls: false, completionTokens: 0, maxTokens: nil)
        try assertEqual(r, .stop)
    }

    // MARK: - StreamOutcome / StreamErrorResolver

    test("StreamOutcome and StreamErrorResolver public surface compiles") {
        let outcome = StreamOutcome(content: "hi", finishReason: .stop)
        let _: String        = outcome.content
        let _: FinishReason  = outcome.finishReason
        let _ = requireSendable(outcome)

        let truncated = StreamErrorResolver.resolve(prev: "x", error: .contextOverflow)
        if case .truncated(let s) = truncated { let _: String = s }
        let fatal = StreamErrorResolver.resolve(prev: "", error: .contextOverflow)
        if case .fatal(let e) = fatal { let _: ApfelError = e }
    }

    // MARK: - ToolResolution / ResolvedTools

    test("ToolResolution.resolve and ResolvedTools public surface compile") {
        let resolved = ToolResolution.resolve(clientTools: nil, mcpTools: nil)
        let _: [OpenAITool]? = resolved.tools
        let _: Bool          = resolved.injected
        let _ = requireSendable(resolved)
    }

    // MARK: - StreamCleanup

    testAsync("StreamCleanup public surface compiles") {
        let c = StreamCleanup()
        await c.run { }
        let _ = requireSendable(c)
    }

    // MARK: - ContextStrategy / ContextConfig

    test("ContextStrategy cases and ContextConfig public surface compile") {
        let _: ContextStrategy = .newestFirst
        let _: ContextStrategy = .oldestFirst
        let _: ContextStrategy = .slidingWindow
        let _: ContextStrategy = .summarize
        let _: ContextStrategy = .strict
        let _: [ContextStrategy] = ContextStrategy.allCases
        let _: Set<ContextStrategy> = [.strict, .summarize]

        let cfg = ContextConfig(
            strategy: .slidingWindow,
            maxTurns: 10,
            outputReserve: 128,
            permissive: true
        )
        let _: ContextStrategy = cfg.strategy
        let _: Int?            = cfg.maxTurns
        let _: Int             = cfg.outputReserve
        let _: Bool            = cfg.permissive
        let _ = requireSendable(cfg)
        let _: ContextConfig   = ContextConfig.defaults
        try assertEqual(ContextConfig.defaults.strategy, .newestFirst)
        let _: Set<ContextConfig> = [cfg, .defaults]
    }

    // MARK: - JSONFenceStripper

    test("JSONFenceStripper.strip(_:) public surface compiles") {
        let _: String = JSONFenceStripper.strip("```json\n{}\n```")
    }

    // MARK: - BufferedLineReader (surface only — behavior covered elsewhere)

    test("BufferedLineReader init signature compiles") {
        // Construct with default buffer size and an fd we won't read from.
        // -1 is an invalid fd; we never call readLine here, so no I/O happens.
        let _ = BufferedLineReader(fileDescriptor: -1)
        let _ = BufferedLineReader(fileDescriptor: -1, bufferSize: 16)
    }

    // MARK: - ModelAvailability

    test("ModelAvailability public surface compiles") {
        let cases: [ModelAvailability] = [
            .available,
            .appleIntelligenceNotEnabled,
            .deviceNotEligible,
            .modelNotReady,
            .unknownUnavailable,
        ]
        for m in cases {
            let _: Bool   = m.isAvailable
            let _: String = m.shortLabel
            let _: String = m.remediation
            let _: String = m.description
            let _: String = m.debugDescription
            let _ = requireSendable(m)
        }
        let _: Set<ModelAvailability> = [.available, .deviceNotEligible]
        try assertTrue(ModelAvailability.available.isAvailable)
    }

    // MARK: - OriginValidator

    test("OriginValidator public surface compiles") {
        let _: [String] = OriginValidator.defaultAllowedOrigins
        let _: Bool = OriginValidator.isAllowed(origin: nil, allowedOrigins: [])
        let _: Bool = OriginValidator.isValidToken(provided: nil, expected: nil)
    }

    // MARK: - withRetry(_:)

    testAsync("withRetry signature compiles and runs a non-throwing closure") {
        let result: Int = try await withRetry(maxRetries: 0) {
            42
        }
        guard result == 42 else { throw TestFailure("expected 42") }
    }

    // MARK: - SchemaIR / SchemaParser

    test("SchemaIR / SchemaParser public surface compiles") {
        let prop = SchemaIR.Property(
            name: "x",
            description: "a field",
            schema: .string(name: "x", description: nil, enumValues: nil),
            isOptional: true
        )
        let _: String       = prop.name
        let _: String?      = prop.description
        let _: SchemaIR     = prop.schema
        let _: Bool         = prop.isOptional
        let _ = requireSendable(prop)

        let ir: SchemaIR = .object(name: "root", description: nil, properties: [prop])
        try assertEqual(ir, ir)
        let _ = requireSendable(ir)

        // Cases exist
        let _: SchemaIR = .string(name: "s", description: nil, enumValues: ["a"])
        let _: SchemaIR = .number(name: "n", description: nil)
        let _: SchemaIR = .bool(name: "b", description: nil)
        let _: SchemaIR = .array(itemName: "arr", items: .string(name: "item", description: nil, enumValues: nil))

        // SchemaParser.parse signature
        let parsed = try SchemaParser.parse(
            json: #"{"type":"object","properties":{"name":{"type":"string"}}}"#,
            name: "root"
        )
        if case .object = parsed { } else {
            throw TestFailure("expected object IR at root")
        }
        let _: Set<SchemaIR> = [parsed]

        // SchemaParser.Error cases
        let errs: [SchemaParser.Error] = [
            .invalidJSON, .unsupportedType("x"), .missingArrayItems,
        ]
        try assertEqual(errs.count, 3)
    }

    // MARK: - ToolCallHandler

    test("ToolCallHandler public surface compiles") {
        let def = ToolDef(name: "f", description: "d", parametersJSON: "{}")
        let _: String  = def.name
        let _: String? = def.description
        let _: String? = def.parametersJSON
        let _ = requireSendable(def)

        let instructions = ToolCallHandler.buildOutputFormatInstructions(toolNames: ["f"])
        try assertTrue(instructions.contains("Tool Calling Format"))

        let fallback = ToolCallHandler.buildFallbackPrompt(tools: [def])
        try assertTrue(fallback.contains("function schemas"))

        try assertEqual(ToolCallHandler.ensureJSONArguments(""), "{}")

        let maybeCalls: [ParsedToolCall]? = ToolCallHandler.detectToolCall(
            in: #"{"tool_calls":[{"id":"c","type":"function","function":{"name":"f","arguments":"{}"}}]}"#
        )
        let calls = maybeCalls ?? []
        guard let first = calls.first else { throw TestFailure("expected at least one tool call") }
        let _: String = first.id
        let _: String = first.name
        let _: String = first.argumentsString
        let _ = requireSendable(first)
    }
}
