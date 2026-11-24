// ============================================================================
// InputTokensHandler.swift - POST /v1/responses/input_tokens (#485)
// The OpenAI token-count call (`client.responses.input_tokens.count(...)`)
// for the stateless text + function-tool subset of the Responses API.
//
// Same decode, mapping, tool scoping, structured-output schema and context
// assembly as POST /v1/responses (ContextManager.prepareEntries), then the
// Engine preflight with Apple's exact tokenizer. Never generates, never runs
// a tool, never returns an estimate.
// ============================================================================

import Foundation
import FoundationModels
import Hummingbird
import HTTPTypes
import ApfelCore
import ApfelEngine

func handleInputTokens(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    let body: ByteBuffer
    do {
        body = try await request.body.collect(upTo: serverMaxRequestBodyBytes)
    } catch {
        let mib = serverMaxRequestBodyBytes / (1024 * 1024)
        return openAIFailure(
            status: .init(code: 413),
            message: "Request body exceeds the \(mib) MiB limit.",
            type: "invalid_request_error",
            stream: false, requestBody: nil, events: events,
            event: "request body too large")
    }
    let requestBodyString = capturedRequestBody(body, debugEnabled: serverState.config.debug)
    events.append("request bytes=\(body.readableBytes)")
    let data = Data(buffer: body)

    let countRequest: ResponsesRequest
    do {
        countRequest = try JSONDecoder().decode(ResponsesRequest.self, from: data)
    } catch {
        let msg = "Invalid JSON: \(error.localizedDescription)"
        return openAIFailure(
            status: .badRequest, message: msg, type: "invalid_request_error",
            stream: false, requestBody: requestBodyString, events: events,
            event: "decode failed: \(msg)")
    }

    if let failure = ResponsesInputTokensValidator.validate(
        countRequest, presentKeys: ResponsesInputTokensValidator.topLevelKeys(of: data)) {
        return openAIFailure(
            status: .init(code: failure.httpStatusCode),
            message: failure.message,
            type: "invalid_request_error",
            stream: false, requestBody: requestBodyString, events: events,
            event: failure.event,
            code: failure.errorCode, param: failure.errorParam)
    }

    // Structured output: the schema rides on the final prompt entry so its
    // overhead is counted exactly as respond(schema:) prices it.
    let formatType = countRequest.text?.format?.type ?? "text"
    var responseSchema: GenerationSchema?
    if formatType == "json_schema",
       let format = countRequest.text?.format,
       // The same schema text /v1/responses generates with (#560).
       let schemaJSON = SchemaParser.rawJSONValue(
           in: Data(buffer: body), at: ["text", "format", "schema"]) ?? format.schema?.value {
        do {
            responseSchema = try SchemaConverter.generationSchema(
                fromJSON: schemaJSON, name: format.name ?? "schema")
        } catch {
            return openAIFailure(
                status: .badRequest,
                message: "Invalid text.format json_schema: \(error)",
                type: "invalid_request_error",
                stream: false, requestBody: requestBodyString, events: events,
                event: "json_schema conversion failed: \(error)")
        }
    }

    let messages = ResponsesMapper.messages(from: countRequest)
    let tools = ResponsesMapper.tools(from: countRequest)
    let toolPolicy: ToolPolicy
    switch ToolPolicy.resolve(
        toolChoice: countRequest.tool_choice,
        toolNames: (tools ?? []).map(\.function.name),
        parallelToolCalls: nil
    ) {
    case .success(let policy):
        toolPolicy = policy
    case .failure(let scopeError):
        return openAIFailure(
            status: .badRequest, message: scopeError.message,
            type: "invalid_request_error",
            stream: false, requestBody: requestBodyString, events: events,
            event: "tool_choice scope rejected: \(scopeError.message)",
            param: scopeError.param)
    }

    let truncation = ResponsesTruncation(requestValue: countRequest.truncation)
    let outputReserve = BodyLimits.defaultOutputReserveTokens
    let options = responsesSessionOptions(countRequest, truncation: truncation)
    events.append("count input messages=\(messages.count) format=\(formatType) tools=\(tools?.count ?? 0) truncation=\(truncation.rawValue)")

    // Free-text entries: what generation sends without the guided step.
    func freeTextEntries() async throws -> ContextManager.PreparedEntries {
        try await ContextManager.prepareEntries(
            messages: messages, tools: toolPolicy.scopedTools(from: tools), options: options,
            jsonMode: formatType == "json_object", toolChoice: countRequest.tool_choice,
            responseSchema: responseSchema)
    }
    // With function tools in scope /v1/responses decides under the guided
    // tool step (#590 item 1): its first request carries the step's
    // instructions and schema, so that is what the preflight counts, built
    // exactly like runGuidedToolStep builds it. A step guided generation
    // cannot express, or one that does not fit, falls back to free text in
    // generation, and so it does here.
    var guided: (step: GuidedToolStep, schema: GenerationSchema)?
    if serverState.config.toolCalling == .guided, toolPolicy.toolsInScope, responseSchema == nil,
       let scoped = toolPolicy.scopedTools(from: tools), !scoped.isEmpty {
        guided = try? prepareGuidedToolStep(tools: scoped, mode: toolPolicy.mode)
    }

    let prepared: ContextManager.PreparedEntries
    do {
        if let guided {
            prepared = try await ContextManager.prepareEntries(
                messages: messages, tools: toolPolicy.scopedTools(from: tools), options: options,
                jsonMode: false, toolChoice: countRequest.tool_choice,
                responseSchema: guided.schema, toolInstructions: guided.step.instructions)
            events.append("counting the guided tool step")
        } else {
            prepared = try await freeTextEntries()
        }
    } catch {
        let classified = classifyModelError(error)
        return openAIFailure(
            status: .init(code: classified.httpStatusCode),
            message: classified.openAIMessage,
            type: classified.openAIType,
            stream: false, requestBody: requestBodyString, events: events,
            event: "input preparation failed: \(classified.openAIMessage)")
    }

    // The budget is read at runtime, the same way generation reads it.
    let window = await TokenCounter.shared.contextWindow
    let budget = window.tokens - outputReserve
    func preflight(_ entries: ContextManager.PreparedEntries) async throws -> InputTokenPreflightOutcome {
        try await InputTokenPreflight.run(
            prepared: entries, budget: budget,
            strategy: truncation.contextStrategy, counter: TokenCounter.shared)
    }
    var outcome: InputTokenPreflightOutcome
    do {
        outcome = try await preflight(prepared)
        if guided != nil, case .overflow = outcome {
            events.append("guided tool step does not fit the context window, counting the free-text format")
            outcome = try await preflight(try await freeTextEntries())
        }
    } catch let error as TokenCountingError {
        return openAIFailure(
            status: .init(code: error.httpStatusCode),
            message: error.message,
            type: error.openAIType,
            stream: false, requestBody: requestBodyString, events: events,
            event: "token counting unavailable: \(error.code)",
            code: error.code)
    } catch {
        let classified = classifyModelError(error)
        return openAIFailure(
            status: .init(code: classified.httpStatusCode),
            message: classified.openAIMessage,
            type: classified.openAIType,
            stream: false, requestBody: requestBodyString, events: events,
            event: "input preparation failed: \(classified.openAIMessage)")
    }

    switch outcome {
    case .overflow(let untrimmed):
        let overflow = InputTokensOverflow(
            untrimmedInputTokens: untrimmed, contextSize: window.tokens,
            outputReserve: outputReserve, truncation: truncation)
        return openAIFailure(
            status: .init(code: overflow.httpStatusCode),
            message: overflow.message,
            type: overflow.openAIType,
            stream: false, requestBody: requestBodyString, events: events,
            event: "input over budget: \(untrimmed) > \(budget)",
            code: overflow.code, param: overflow.param)
    case .counted(let result):
        let itemIndices = ResponsesMapper.conversationInputIndices(from: countRequest)
        let removedItems = result.removedHistoryPositions.compactMap { position in
            itemIndices.indices.contains(position) ? itemIndices[position] : nil
        }
        let report = InputTokensReport(
            inputTokens: result.inputTokens,
            untrimmedInputTokens: result.untrimmedInputTokens,
            contextSize: window.tokens,
            contextSizeMeasured: window.isMeasured,
            outputReserve: outputReserve,
            truncation: truncation,
            removedInputItems: removedItems)
        let json = report.jsonString
        return (
            jsonResponse(json),
            ChatRequestTrace(
                stream: false,
                estimatedTokens: result.inputTokens,
                error: nil,
                requestBody: requestBodyString,
                responseBody: captureTruncatedLogBody(json, enabled: serverState.config.debug),
                events: events + ["counted input_tokens=\(result.inputTokens) untrimmed=\(result.untrimmedInputTokens) removed=\(removedItems.count)"]
            )
        )
    }
}

/// Session options /v1/responses builds for a request. Shared by generation
/// and the token preflight so both prepare identical prompt entries.
func responsesSessionOptions(_ r: ResponsesRequest, truncation: ResponsesTruncation) -> SessionOptions {
    SessionOptions(
        temperature: r.temperature,
        topP: r.top_p,
        maxTokens: r.max_output_tokens,
        seed: nil,
        permissive: serverState.config.permissive,
        contextConfig: ContextConfig(
            strategy: truncation.contextStrategy, maxTurns: nil,
            outputReserve: BodyLimits.defaultOutputReserveTokens),
        retryEnabled: serverState.config.retryEnabled,
        retryCount: serverState.config.retryCount,
        useCase: (r.model.flatMap(ServedModel.resolve) ?? .default).useCase
    )
}
