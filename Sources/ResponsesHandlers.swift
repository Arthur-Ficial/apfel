// ============================================================================
// ResponsesHandlers.swift - POST /v1/responses (#365)
// A translation layer over the chat pipeline: decode ResponsesRequest
// (ApfelCore), validate (honest 501s), map to chat internals, run the same
// ContextManager/collectStream/streamResponse primitives the chat handler
// uses, and re-encode as a Responses envelope / named-SSE event stream.
//
// v1 scope: string + message-list input, instructions, sampling params,
// text.format text/json_object/json_schema (non-streaming), client function
// tools (non-streaming, one round: the call is returned to the client),
// plain-text streaming with the canonical event sequence. Everything else
// is a 501 from ResponsesRequestValidator - never a silent downgrade.
// MCP tools are NOT auto-injected on this endpoint (chat completions only).
// ============================================================================

import Foundation
import FoundationModels
import Hummingbird
import HTTPTypes
import ApfelCore

// MARK: - Echoed request fields

/// Request fields echoed verbatim on every envelope for this request.
struct ResponsesEcho {
    let instructions: String?
    let maxOutputTokens: Int?
    let metadata: [String: String]?
    let temperature: Double?
    let topP: Double?
    let formatType: String
    let formatName: String?
    let formatSchemaJSON: String?
    let toolsEcho: [ResponsesToolEcho]

    init(_ r: ResponsesRequest, formatType: String) {
        instructions = r.instructions
        maxOutputTokens = r.max_output_tokens
        metadata = r.metadata
        temperature = r.temperature
        topP = r.top_p
        self.formatType = formatType
        formatName = r.text?.format?.name
        formatSchemaJSON = r.text?.format?.schema?.value
        toolsEcho = (r.tools ?? []).compactMap { tool in
            guard tool.type == "function", let name = tool.name else { return nil }
            return ResponsesToolEcho(name: name, description: tool.description,
                                     parametersJSON: tool.parameters?.value)
        }
    }

    func envelope(id: String, created: Int, status: String,
                  output: [ResponsesOutputItem], usage: ResponsesUsage?,
                  incompleteReason: String? = nil) -> ResponsesEnvelope {
        ResponsesEnvelope(
            id: id, createdAt: created, status: status,
            instructions: instructions, maxOutputTokens: maxOutputTokens,
            metadata: metadata, output: output,
            temperature: temperature, topP: topP,
            formatType: formatType, formatName: formatName,
            formatSchemaJSON: formatSchemaJSON, toolsEcho: toolsEcho,
            usage: usage, incompleteReason: incompleteReason)
    }
}

// MARK: - Failure helper (same shape as the chat handler's chatFailure)

private func responsesFailure(
    status: HTTPResponse.Status,
    message: String,
    type: String,
    stream: Bool,
    requestBody: String?,
    events: [String],
    event: String,
    code: String? = nil,
    param: String? = nil
) -> (response: Response, trace: ChatRequestTrace) {
    (
        openAIError(status: status, message: message, type: type, code: code, param: param),
        ChatRequestTrace(
            stream: stream,
            estimatedTokens: nil,
            error: message,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(message, enabled: serverState.config.debug),
            events: events + [event]
        )
    )
}

// MARK: - Handler

func handleResponses(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    // Body collect with a proper 413 (#234).
    let body: ByteBuffer
    do {
        body = try await request.body.collect(upTo: BodyLimits.maxRequestBodyBytes)
    } catch {
        let mib = BodyLimits.maxRequestBodyBytes / (1024 * 1024)
        return responsesFailure(
            status: .init(code: 413),
            message: "Request body exceeds the \(mib) MiB limit.",
            type: "invalid_request_error",
            stream: false, requestBody: nil, events: events,
            event: "request body too large")
    }
    let requestBodyString = capturedRequestBody(body, debugEnabled: serverState.config.debug)
    events.append("request bytes=\(body.readableBytes)")

    let responsesRequest: ResponsesRequest
    do {
        responsesRequest = try JSONDecoder().decode(ResponsesRequest.self, from: body)
    } catch {
        let msg = "Invalid JSON: \(error.localizedDescription)"
        return responsesFailure(
            status: .badRequest, message: msg, type: "invalid_request_error",
            stream: false, requestBody: requestBodyString, events: events,
            event: "decode failed: \(msg)")
    }
    let isStreaming = responsesRequest.stream == true

    if let failure = ResponsesRequestValidator.validate(responsesRequest) {
        return responsesFailure(
            status: .init(code: failure.httpStatusCode),
            message: failure.message,
            type: "invalid_request_error",
            stream: isStreaming, requestBody: requestBodyString, events: events,
            event: failure.event,
            code: failure.errorCode, param: failure.errorParam)
    }

    let formatType = responsesRequest.text?.format?.type ?? "text"
    let jsonMode = formatType == "json_object"

    // json_schema -> native GenerationSchema, failing fast as a 400.
    var structuredSchema: GenerationSchema?
    if formatType == "json_schema",
       let format = responsesRequest.text?.format,
       let schemaJSON = format.schema?.value {
        do {
            structuredSchema = try SchemaConverter.generationSchema(
                fromJSON: schemaJSON, name: format.name ?? "schema")
        } catch {
            return responsesFailure(
                status: .badRequest,
                message: "Invalid text.format json_schema: \(error)",
                type: "invalid_request_error",
                stream: isStreaming, requestBody: requestBodyString, events: events,
                event: "json_schema conversion failed: \(error)")
        }
    }

    let messages = ResponsesMapper.messages(from: responsesRequest)
    let tools = ResponsesMapper.tools(from: responsesRequest)
    events.append("decoded input messages=\(messages.count) stream=\(isStreaming) format=\(formatType) tools=\(tools?.count ?? 0)")

    let sessionOpts = SessionOptions(
        temperature: responsesRequest.temperature,
        topP: responsesRequest.top_p,
        maxTokens: responsesRequest.max_output_tokens,
        seed: nil,
        permissive: serverState.config.permissive,
        contextConfig: ContextConfig(
            strategy: .newestFirst, maxTurns: nil,
            outputReserve: BodyLimits.defaultOutputReserveTokens),
        retryEnabled: serverState.config.retryEnabled,
        retryCount: serverState.config.retryCount
    )

    let session: LanguageModelSession
    let finalPrompt: String
    let inputEntries: [Transcript.Entry]
    do {
        (session, finalPrompt, inputEntries) = try await ContextManager.makeSession(
            messages: messages, tools: tools, options: sessionOpts,
            jsonMode: jsonMode, toolChoice: responsesRequest.tool_choice)
    } catch {
        let classified = ApfelError.classify(error)
        return responsesFailure(
            status: .init(code: classified.httpStatusCode),
            message: classified.openAIMessage,
            type: classified.openAIType,
            stream: isStreaming, requestBody: requestBodyString, events: events,
            event: "context build failed: \(classified.openAIMessage)")
    }

    let genOpts = makeGenerationOptions(sessionOpts)
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(builtEntries: inputEntries, finalPrompt: finalPrompt, options: sessionOpts))
    let requestId = "resp_\(UUID().uuidString.prefix(12).lowercased())"
    let created = Int(Date().timeIntervalSince1970)
    let echo = ResponsesEcho(responsesRequest, formatType: formatType)

    if isStreaming {
        // Validator guarantees: no tools, no json_schema on this path.
        let result = responsesStreamingResponse(
            session: session, prompt: finalPrompt, jsonMode: jsonMode,
            id: requestId, created: created, genOpts: genOpts,
            promptTokens: promptTokens, echo: echo,
            requestBody: requestBodyString, events: events)
        return (result.response, result.trace)
    }

    let result = try await responsesNonStreamingResponse(
        session: session, prompt: finalPrompt, schema: structuredSchema,
        jsonMode: jsonMode, id: requestId, created: created, genOpts: genOpts,
        promptTokens: promptTokens, echo: echo,
        requestBody: requestBodyString, events: events)
    return (result.response, result.trace)
}

// MARK: - Non-streaming

private func responsesNonStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    schema: GenerationSchema?,
    jsonMode: Bool,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    echo: ResponsesEcho,
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let retryMax = serverState.config.retryEnabled ? serverState.config.retryCount : 0

    var output: [ResponsesOutputItem] = []
    var deliveredText = ""
    var status = "completed"
    var incompleteReason: String?
    do {
        if let schema {
            let content = try await withRetry(maxRetries: retryMax) {
                try await session.respond(to: prompt, schema: schema, options: genOpts).content.jsonString
            }
            deliveredText = content
            output = [.message(id: "msg_\(UUID().uuidString.prefix(12).lowercased())",
                               text: content, refusal: nil, status: "completed")]
        } else {
            let outcome = try await withRetry(maxRetries: retryMax) {
                try await collectStream(session, prompt: prompt, options: genOpts)
            }
            if let calls = ToolCallHandler.detectToolCall(in: outcome.content) {
                output = calls.map { call in
                    .functionCall(id: "fc_\(UUID().uuidString.prefix(12).lowercased())",
                                  callId: call.id, name: call.name,
                                  arguments: call.argumentsString, status: "completed")
                }
                deliveredText = outcome.content
            } else {
                deliveredText = jsonMode ? JSONFenceStripper.strip(outcome.content) : outcome.content
                if outcome.finishReason == .length {
                    status = "incomplete"
                    incompleteReason = "max_output_tokens"
                }
                output = [.message(id: "msg_\(UUID().uuidString.prefix(12).lowercased())",
                                   text: deliveredText, refusal: nil, status: "completed")]
            }
        }
    } catch {
        let classified = ApfelError.classify(error)
        if case .refusal(let explanation) = classified {
            // Wire parity with chat: a refusal is a 200 with a refusal part.
            let completionTokens = await TokenCounter.shared.count(explanation)
            let envelope = echo.envelope(
                id: id, created: created, status: "completed",
                output: [.message(id: "msg_\(UUID().uuidString.prefix(12).lowercased())",
                                  text: nil, refusal: explanation, status: "completed")],
                usage: ResponsesUsage(input_tokens: promptTokens, output_tokens: completionTokens))
            return encodeEnvelope(envelope, requestBody: requestBody,
                                  events: events + ["refusal delivered"],
                                  estimatedTokens: promptTokens + completionTokens)
        }
        return responsesFailure(
            status: .init(code: classified.httpStatusCode),
            message: classified.openAIMessage,
            type: classified.openAIType,
            stream: false, requestBody: requestBody, events: events,
            event: "model error: \(classified.cliLabel)")
    }

    let completionTokens = await TokenCounter.shared.count(deliveredText)
    let envelope = echo.envelope(
        id: id, created: created, status: status, output: output,
        usage: ResponsesUsage(input_tokens: promptTokens, output_tokens: completionTokens),
        incompleteReason: incompleteReason)
    return encodeEnvelope(
        envelope, requestBody: requestBody,
        events: events + ["responses non-stream chars=\(deliveredText.count) status=\(status) items=\(output.count)"],
        estimatedTokens: promptTokens + completionTokens)
}

private func encodeEnvelope(
    _ envelope: ResponsesEnvelope,
    requestBody: String?,
    events: [String],
    estimatedTokens: Int
) -> (response: Response, trace: ChatRequestTrace) {
    let body = jsonString(envelope)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return (
        Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body))),
        ChatRequestTrace(
            stream: false,
            estimatedTokens: estimatedTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
            events: events
        )
    )
}

// MARK: - Streaming (canonical Responses event sequence)

private func responsesStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    jsonMode: Bool,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    echo: ResponsesEcho,
    requestBody: String?,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    let eventBox = TraceBuffer(events: events + ["responses stream start"])
    let cleanup = StreamCleanup()
    let taskBox = StreamTaskBox()
    let captureDebugBodies = serverState.config.debug

    let responseStream = AsyncStream<ByteBuffer> { continuation in
        let streamTask = Task {
            let streamStart = Date()
            var responseLines: [String]? = captureDebugBodies ? [] : nil
            var streamError: String?
            var streamCancelled = false
            var completionTokens = 0
            var seq = 0
            let itemId = "msg_\(UUID().uuidString.prefix(12).lowercased())"

            func emit(_ type: String, _ payload: some Encodable) {
                let line = responsesEventLine(type: type, payload: payload)
                responseLines?.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: line))
            }
            func nextSeq() -> Int { seq += 1; return seq }

            defer {
                Task {
                    await cleanup.run {
                        await serverState.semaphore.signal()
                        await serverState.logStore.requestFinished()
                    }
                    continuation.finish()
                }
            }

            // Lifecycle preamble.
            let inProgress = echo.envelope(id: id, created: created, status: "in_progress", output: [], usage: nil)
            emit("response.created", ResponsesLifecycleEvent(type: "response.created", sequence_number: nextSeq(), response: inProgress))
            emit("response.in_progress", ResponsesLifecycleEvent(type: "response.in_progress", sequence_number: nextSeq(), response: inProgress))
            emit("response.output_item.added", ResponsesOutputItemEvent(
                type: "response.output_item.added", sequence_number: nextSeq(), output_index: 0,
                item: .message(id: itemId, text: nil, refusal: nil, status: "in_progress")))
            emit("response.content_part.added", ResponsesContentPartEvent(
                type: "response.content_part.added", sequence_number: nextSeq(),
                item_id: itemId, output_index: 0, content_index: 0, text: ""))
            await eventBox.append("sent responses preamble")

            let stream = session.streamResponse(to: prompt, options: genOpts)
            var prev = ""
            var emitted = 0
            do {
                for try await snapshot in stream {
                    let content = snapshot.content
                    guard content.count > prev.count else { prev = content; continue }
                    prev = content
                    // json_object mode buffers the whole response so the final
                    // concatenation is fence-stripped valid JSON (#223 parity).
                    if jsonMode { continue }
                    let idx = content.index(content.startIndex, offsetBy: emitted)
                    let delta = String(content[idx...])
                    emit("response.output_text.delta", ResponsesTextDeltaEvent(
                        sequence_number: nextSeq(), item_id: itemId,
                        output_index: 0, content_index: 0, delta: delta))
                    emitted = content.count
                }

                let finalText = jsonMode ? JSONFenceStripper.strip(prev) : prev
                if jsonMode && !finalText.isEmpty {
                    emit("response.output_text.delta", ResponsesTextDeltaEvent(
                        sequence_number: nextSeq(), item_id: itemId,
                        output_index: 0, content_index: 0, delta: finalText))
                }
                completionTokens = await TokenCounter.shared.count(finalText)
                let resolved = FinishReasonResolver.resolve(
                    hasToolCalls: false, completionTokens: completionTokens,
                    maxTokens: genOpts.maximumResponseTokens)
                let status = resolved == .length ? "incomplete" : "completed"

                emit("response.output_text.done", ResponsesTextDoneEvent(
                    sequence_number: nextSeq(), item_id: itemId,
                    output_index: 0, content_index: 0, text: finalText))
                emit("response.content_part.done", ResponsesContentPartEvent(
                    type: "response.content_part.done", sequence_number: nextSeq(),
                    item_id: itemId, output_index: 0, content_index: 0, text: finalText))
                let doneItem = ResponsesOutputItem.message(id: itemId, text: finalText, refusal: nil, status: "completed")
                emit("response.output_item.done", ResponsesOutputItemEvent(
                    type: "response.output_item.done", sequence_number: nextSeq(), output_index: 0, item: doneItem))
                let final = echo.envelope(
                    id: id, created: created, status: status, output: [doneItem],
                    usage: ResponsesUsage(input_tokens: promptTokens, output_tokens: completionTokens),
                    incompleteReason: status == "incomplete" ? "max_output_tokens" : nil)
                emit("response.completed", ResponsesLifecycleEvent(
                    type: "response.completed", sequence_number: nextSeq(), response: final))
                await eventBox.append("responses stream complete chars=\(finalText.count) status=\(status)")
            } catch is CancellationError {
                streamCancelled = true
                await eventBox.append("responses stream cancelled by client")
            } catch {
                let classified = ApfelError.classify(error)
                if case .truncated(let truncatedContent) = StreamErrorResolver.resolve(prev: prev, error: classified) {
                    // Output-side overflow with content already streamed is a
                    // graceful incomplete, mirroring the chat path.
                    completionTokens = await TokenCounter.shared.count(truncatedContent)
                    emit("response.output_text.done", ResponsesTextDoneEvent(
                        sequence_number: nextSeq(), item_id: itemId,
                        output_index: 0, content_index: 0, text: truncatedContent))
                    let doneItem = ResponsesOutputItem.message(id: itemId, text: truncatedContent, refusal: nil, status: "completed")
                    emit("response.output_item.done", ResponsesOutputItemEvent(
                        type: "response.output_item.done", sequence_number: nextSeq(), output_index: 0, item: doneItem))
                    let final = echo.envelope(
                        id: id, created: created, status: "incomplete", output: [doneItem],
                        usage: ResponsesUsage(input_tokens: promptTokens, output_tokens: completionTokens),
                        incompleteReason: "max_output_tokens")
                    emit("response.completed", ResponsesLifecycleEvent(
                        type: "response.completed", sequence_number: nextSeq(), response: final))
                    await eventBox.append("responses stream truncated -> incomplete")
                } else {
                    emit("error", ResponsesErrorEvent(sequence_number: nextSeq(), message: classified.openAIMessage))
                    streamError = classified.openAIMessage
                    await eventBox.append("responses stream error: \(classified.cliLabel)")
                }
            }

            let completionLog = RequestLog(
                id: "\(id)-stream",
                timestamp: ISO8601DateFormatter().string(from: streamStart),
                method: "POST",
                path: "/v1/responses/stream",
                status: streamCancelled ? 499 : (streamError == nil ? 200 : 500),
                duration_ms: Int(Date().timeIntervalSince(streamStart) * 1000),
                stream: true,
                estimated_tokens: completionTokens,
                error: streamError,
                request_body: requestBody,
                response_body: responseLines.map { truncateForLog($0.joined(separator: "\n\n")) },
                events: await eventBox.snapshot()
            )
            await serverState.logStore.append(completionLog)
        }
        taskBox.set(streamTask)

        continuation.onTermination = { _ in
            taskBox.cancel()
            Task {
                await cleanup.run {
                    await serverState.semaphore.signal()
                    await serverState.logStore.requestFinished()
                }
            }
        }
    }

    return (
        Response(status: .ok, headers: headers, body: .init(asyncSequence: responseStream)),
        ChatRequestTrace(
            stream: true,
            estimatedTokens: promptTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: serverState.config.debug
                ? "Streaming response in progress. See /v1/responses/stream log for final SSE transcript."
                : nil,
            events: events + ["responses stream request accepted"],
            ownsCleanup: true
        )
    )
}
