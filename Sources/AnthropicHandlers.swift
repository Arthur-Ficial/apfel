// ============================================================================
// AnthropicHandlers.swift — HTTP handler for the Anthropic Messages API
// (`POST /v1/messages`). Decodes -> validates -> converts to the OpenAI-style
// ChatCompletionRequest -> reuses ContextManager.makeSession / ToolResolution /
// TokenCounter / Session, then emits an Anthropic-format response or SSE stream.
//
// Mirrors the OpenAI handler in Sources/Handlers.swift. Additive and
// experimental; does not touch the existing /v1/chat/completions path.
// ============================================================================

import FoundationModels
import Foundation
import Hummingbird
import NIOCore
import ApfelCore

// MARK: - /v1/messages

/// POST /v1/messages — Anthropic Messages API endpoint (streaming + non-streaming).
func handleMessages(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    let body = try await request.body.collect(upTo: BodyLimits.maxRequestBodyBytes)
    let requestBodyString = capturedRequestBody(body, debugEnabled: serverState.config.debug)
    events.append("request bytes=\(body.readableBytes)")

    // Decode.
    let anthropicRequest: AnthropicMessagesRequest
    do {
        anthropicRequest = try JSONDecoder().decode(AnthropicMessagesRequest.self, from: body)
    } catch {
        let msg = "Invalid JSON: \(error.localizedDescription)"
        return anthropicFailure(
            status: .badRequest, errorType: "invalid_request_error", message: msg,
            stream: false, requestBody: requestBodyString, events: events,
            event: "decode failed: \(msg)")
    }

    let isStreaming = anthropicRequest.stream == true
    let echoModel = anthropicRequest.model

    // Validate.
    if let failure = AnthropicMessageValidator.validate(anthropicRequest) {
        return anthropicFailure(
            status: .badRequest, errorType: "invalid_request_error", message: failure.message,
            stream: isStreaming, requestBody: requestBodyString, events: events,
            event: "validation failed: \(failure)")
    }

    // Convert to the OpenAI-style request and reuse the whole pipeline.
    let chatRequest = AnthropicConverter.toChatCompletionRequest(anthropicRequest)
    let wantsJSONSchema = chatRequest.response_format?.type == "json_schema"
    events.append("decoded messages=\(chatRequest.messages.count) stream=\(isStreaming) model=\(echoModel)")

    // Structured output: build the native schema up front so a bad schema 400s fast.
    var structuredSchema: GenerationSchema?
    if wantsJSONSchema {
        guard let spec = chatRequest.response_format?.json_schema,
              let schemaJSON = spec.schema?.value else {
            return anthropicFailure(
                status: .badRequest, errorType: "invalid_request_error",
                message: "output_config.format.json_schema requires a 'schema' object",
                stream: isStreaming, requestBody: requestBodyString, events: events,
                event: "json_schema: missing schema")
        }
        do {
            structuredSchema = try SchemaConverter.generationSchema(fromJSON: schemaJSON, name: spec.name)
        } catch {
            return anthropicFailure(
                status: .badRequest, errorType: "invalid_request_error",
                message: "Invalid output_config.format schema: \(error)",
                stream: isStreaming, requestBody: requestBodyString, events: events,
                event: "json_schema: schema conversion failed: \(error)")
        }
    }

    let contextConfig = ContextConfig(
        strategy: .newestFirst,
        maxTurns: nil,
        outputReserve: BodyLimits.defaultOutputReserveTokens
    )
    let sessionOpts = SessionOptions(
        temperature: chatRequest.temperature,
        topP: chatRequest.top_p,
        maxTokens: chatRequest.max_tokens,
        seed: nil,
        permissive: serverState.config.permissive,
        contextConfig: contextConfig,
        retryEnabled: serverState.config.retryEnabled,
        retryCount: serverState.config.retryCount
    )

    // Tool resolution mirrors the OpenAI path (client tools win; MCP injects otherwise).
    let mcpTools = await serverState.mcpManager?.allTools()
    let resolvedTools = ToolResolution.resolve(clientTools: chatRequest.tools, mcpTools: mcpTools)
    let effectiveTools = resolvedTools.tools

    // Build session + final prompt via the shared ContextManager.
    let session: LanguageModelSession
    let finalPrompt: String
    let inputEntries: [Transcript.Entry]
    do {
        (session, finalPrompt, inputEntries) = try await ContextManager.makeSession(
            messages: chatRequest.messages,
            tools: effectiveTools,
            options: sessionOpts,
            jsonMode: false,
            toolChoice: chatRequest.tool_choice
        )
    } catch {
        let classified = ApfelError.classify(error)
        return anthropicFailure(
            status: .init(code: classified.anthropicStatusCode),
            errorType: classified.anthropicErrorType,
            message: classified.anthropicMessage,
            stream: isStreaming, requestBody: requestBodyString, events: events,
            event: "context build failed: \(classified.cliLabel)")
    }
    events.append("context built final_prompt_chars=\(finalPrompt.count)")

    let genOpts = makeGenerationOptions(sessionOpts)
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(builtEntries: inputEntries, finalPrompt: finalPrompt, options: sessionOpts))
    let messageId = "msg_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased())"

    if let schema = structuredSchema {
        return try await anthropicStructuredResponse(
            session: session, prompt: finalPrompt, schema: schema,
            model: echoModel, id: messageId, genOpts: genOpts, promptTokens: promptTokens,
            streaming: isStreaming, requestBody: requestBodyString, events: events)
    }

    if isStreaming {
        return anthropicStreamingResponse(
            session: session, prompt: finalPrompt, model: echoModel, id: messageId,
            genOpts: genOpts, promptTokens: promptTokens,
            requestBody: requestBodyString, events: events)
    } else {
        return try await anthropicNonStreamingResponse(
            session: session, prompt: finalPrompt, model: echoModel, id: messageId,
            genOpts: genOpts, promptTokens: promptTokens,
            requestBody: requestBodyString, events: events)
    }
}

// MARK: - Non-streaming

private func anthropicNonStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    model: String,
    id: String,
    genOpts: GenerationOptions,
    promptTokens: Int,
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let nsRetryMax = serverState.config.retryEnabled ? serverState.config.retryCount : 0
    let outcome: StreamOutcome
    do {
        outcome = try await withRetry(maxRetries: nsRetryMax) {
            try await collectStream(session, prompt: prompt, options: genOpts)
        }
    } catch {
        let classified = ApfelError.classify(error)
        if case .refusal(let explanation) = classified {
            return await anthropicRefusalResponse(
                model: model, id: id, promptTokens: promptTokens, refusal: explanation,
                requestBody: requestBody, events: events + ["refusal: \(classified.cliLabel)"])
        }
        return anthropicFailure(
            status: .init(code: classified.anthropicStatusCode),
            errorType: classified.anthropicErrorType, message: classified.anthropicMessage,
            stream: false, requestBody: requestBody, events: events,
            event: "model error: \(classified.cliLabel)")
    }

    let rawContent = outcome.content
    let toolCalls = ToolCallHandler.detectToolCall(in: rawContent)

    let blocks: [AnthropicResponseBlock]
    let stopReason: String
    let deliveredForTokens: String
    if let calls = toolCalls {
        blocks = calls.map { .toolUse(id: $0.id, name: $0.name, input: RawJSON(rawValue: normalizedJSONObject($0.argumentsString))) }
        stopReason = "tool_use"
        deliveredForTokens = rawContent
    } else {
        blocks = [.text(rawContent)]
        stopReason = (outcome.finishReason == .length) ? "max_tokens" : "end_turn"
        deliveredForTokens = rawContent
    }

    let outputTokens = await TokenCounter.shared.count(deliveredForTokens)
    let payload = AnthropicMessagesResponse(
        id: id, model: model, content: blocks, stopReason: stopReason,
        usage: AnthropicUsage(inputTokens: promptTokens, outputTokens: outputTokens))
    let bodyStr = jsonString(payload, pretty: false)

    return (
        anthropicJSONResponse(status: .ok, body: bodyStr),
        ChatRequestTrace(
            stream: false, estimatedTokens: promptTokens + outputTokens, error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(bodyStr, enabled: serverState.config.debug),
            events: events + ["non-stream stop_reason=\(stopReason) output_tokens=\(outputTokens)"])
    )
}

// MARK: - Streaming (SSE)

private func anthropicStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    model: String,
    id: String,
    genOpts: GenerationOptions,
    promptTokens: Int,
    requestBody: String?,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    let eventBox = TraceBuffer(events: events + ["anthropic stream start"])
    let cleanup = StreamCleanup()
    let taskBox = StreamTaskBox()
    let captureDebugBodies = serverState.config.debug

    let responseStream = AsyncStream<ByteBuffer> { continuation in
        let streamTask = Task {
            let streamStart = Date()
            var responseLines: [String]? = captureDebugBodies ? [] : nil
            responseLines?.reserveCapacity(16)
            var streamError: String?
            var streamCancelled = false
            var outputTokens = 0

            func yield(_ s: String) {
                responseLines?.append(s.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: s))
            }

            defer {
                Task {
                    await cleanup.run {
                        await serverState.semaphore.signal()
                        await serverState.logStore.requestFinished()
                    }
                    continuation.finish()
                }
            }

            // message_start + content_block_start(text).
            yield(anthropicMessageStartLine(id: id, model: model, inputTokens: promptTokens))
            yield(anthropicContentBlockStartLine(index: 0, block: .text))
            await eventBox.append("sent message_start + content_block_start")

            let stream = session.streamResponse(to: prompt, options: genOpts)
            var prev = ""

            do {
                for try await snapshot in stream {
                    let content = snapshot.content
                    if content.count > prev.count {
                        let idx = content.index(content.startIndex, offsetBy: prev.count)
                        let delta = String(content[idx...])
                        yield(anthropicTextDeltaLine(index: 0, text: delta))
                    }
                    prev = content
                }

                let toolCalls = ToolCallHandler.detectToolCall(in: prev)
                outputTokens = await TokenCounter.shared.count(prev)

                if let calls = toolCalls, let first = calls.first {
                    // Replace the empty text block with a tool_use block. Close
                    // text block, open tool_use block, stream its input as one
                    // input_json_delta, then close it.
                    yield(anthropicContentBlockStopLine(index: 0))
                    yield(anthropicContentBlockStartLine(index: 1, block: .toolUse(id: first.id, name: first.name)))
                    yield(anthropicInputJSONDeltaLine(index: 1, partialJSON: normalizedJSONObject(first.argumentsString)))
                    yield(anthropicContentBlockStopLine(index: 1))
                    yield(anthropicMessageDeltaLine(stopReason: "tool_use", outputTokens: outputTokens))
                    yield(anthropicMessageStopLine())
                    await eventBox.append("tool_use stream: \(calls.map(\.name).joined(separator: ", "))")
                } else {
                    let resolved = FinishReasonResolver.resolve(
                        hasToolCalls: false, completionTokens: outputTokens,
                        maxTokens: genOpts.maximumResponseTokens)
                    let stopReason = (resolved == .length) ? "max_tokens" : "end_turn"
                    yield(anthropicContentBlockStopLine(index: 0))
                    yield(anthropicMessageDeltaLine(stopReason: stopReason, outputTokens: outputTokens))
                    yield(anthropicMessageStopLine())
                    await eventBox.append("text stream done stop_reason=\(stopReason) output_tokens=\(outputTokens)")
                }
            } catch is CancellationError {
                streamCancelled = true
                await eventBox.append("anthropic stream cancelled by client")
            } catch {
                let classified = ApfelError.classify(error)
                if case .truncated(let truncatedContent) = StreamErrorResolver.resolve(prev: prev, error: classified) {
                    outputTokens = await TokenCounter.shared.count(truncatedContent)
                    yield(anthropicContentBlockStopLine(index: 0))
                    yield(anthropicMessageDeltaLine(stopReason: "max_tokens", outputTokens: outputTokens))
                    yield(anthropicMessageStopLine())
                    await eventBox.append("anthropic stream truncated stop_reason=max_tokens")
                } else if case .refusal(let explanation) = classified {
                    // Emit the refusal text then close with stop_reason "refusal".
                    yield(anthropicTextDeltaLine(index: 0, text: explanation))
                    outputTokens = await TokenCounter.shared.count(
                        StreamErrorResolver.refusalCompletionText(prev: prev, explanation: explanation))
                    yield(anthropicContentBlockStopLine(index: 0))
                    yield(anthropicMessageDeltaLine(stopReason: "refusal", outputTokens: outputTokens))
                    yield(anthropicMessageStopLine())
                    await eventBox.append("anthropic stream refusal")
                } else {
                    yield(anthropicErrorLine(errorType: classified.anthropicErrorType, message: classified.anthropicMessage))
                    streamError = classified.anthropicMessage
                    await eventBox.append("anthropic stream error: \(classified.cliLabel)")
                }
            }

            let completionLog = RequestLog(
                id: "\(id)-stream",
                timestamp: ISO8601DateFormatter().string(from: streamStart),
                method: "POST", path: "/v1/messages/stream",
                status: streamCancelled ? 499 : (streamError == nil ? 200 : 500),
                duration_ms: Int(Date().timeIntervalSince(streamStart) * 1000),
                stream: true, estimated_tokens: outputTokens, error: streamError,
                request_body: requestBody,
                response_body: responseLines.map { truncateForLog($0.joined(separator: "\n\n")) },
                events: await eventBox.snapshot())
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
            stream: true, estimatedTokens: promptTokens, error: nil,
            requestBody: requestBody,
            responseBody: serverState.config.debug
                ? "Streaming response in progress. See /v1/messages/stream log for final SSE transcript."
                : nil,
            events: events + ["anthropic stream request accepted"])
    )
}

// MARK: - Structured output

private func anthropicStructuredResponse(
    session: LanguageModelSession,
    prompt: String,
    schema: GenerationSchema,
    model: String,
    id: String,
    genOpts: GenerationOptions,
    promptTokens: Int,
    streaming: Bool,
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let nsRetryMax = serverState.config.retryEnabled ? serverState.config.retryCount : 0
    let content: String
    do {
        content = try await withRetry(maxRetries: nsRetryMax) {
            let result = try await session.respond(to: prompt, schema: schema, options: genOpts)
            return result.content.jsonString
        }
    } catch {
        let classified = ApfelError.classify(error)
        if case .refusal(let explanation) = classified {
            return await anthropicRefusalResponse(
                model: model, id: id, promptTokens: promptTokens, refusal: explanation,
                requestBody: requestBody, events: events + ["refusal: \(classified.cliLabel)"])
        }
        return anthropicFailure(
            status: .init(code: classified.anthropicStatusCode),
            errorType: classified.anthropicErrorType, message: classified.anthropicMessage,
            stream: streaming, requestBody: requestBody, events: events,
            event: "structured model error: \(classified.cliLabel)")
    }

    let outputTokens = await TokenCounter.shared.count(content)

    if streaming {
        // Emit the structured JSON as a single text delta (mirrors the OpenAI
        // structured-streaming buffering: a partial object's JSON is not a
        // growing prefix, so we emit the final document as one delta).
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.init("Connection")!] = "keep-alive"
        var frames = anthropicMessageStartLine(id: id, model: model, inputTokens: promptTokens)
        frames += anthropicContentBlockStartLine(index: 0, block: .text)
        frames += anthropicTextDeltaLine(index: 0, text: content)
        frames += anthropicContentBlockStopLine(index: 0)
        frames += anthropicMessageDeltaLine(stopReason: "end_turn", outputTokens: outputTokens)
        frames += anthropicMessageStopLine()
        let response = Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(string: frames)))
        return (
            response,
            ChatRequestTrace(
                stream: true, estimatedTokens: promptTokens + outputTokens, error: nil,
                requestBody: requestBody,
                responseBody: captureTruncatedLogBody(frames, enabled: serverState.config.debug),
                events: events + ["structured anthropic stream chars=\(content.count)"])
        )
    }

    let payload = AnthropicMessagesResponse(
        id: id, model: model, content: [.text(content)], stopReason: "end_turn",
        usage: AnthropicUsage(inputTokens: promptTokens, outputTokens: outputTokens))
    let bodyStr = jsonString(payload, pretty: false)
    return (
        anthropicJSONResponse(status: .ok, body: bodyStr),
        ChatRequestTrace(
            stream: false, estimatedTokens: promptTokens + outputTokens, error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(bodyStr, enabled: serverState.config.debug),
            events: events + ["structured anthropic non-stream chars=\(content.count)"])
    )
}

// MARK: - Refusal (200 + stop_reason:"refusal")

private func anthropicRefusalResponse(
    model: String,
    id: String,
    promptTokens: Int,
    refusal: String,
    requestBody: String?,
    events: [String]
) async -> (response: Response, trace: ChatRequestTrace) {
    let outputTokens = await TokenCounter.shared.count(refusal)
    let payload = AnthropicMessagesResponse(
        id: id, model: model, content: [.text(refusal)], stopReason: "refusal",
        usage: AnthropicUsage(inputTokens: promptTokens, outputTokens: outputTokens))
    let bodyStr = jsonString(payload, pretty: false)
    return (
        anthropicJSONResponse(status: .ok, body: bodyStr),
        ChatRequestTrace(
            stream: false, estimatedTokens: promptTokens + outputTokens, error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(bodyStr, enabled: serverState.config.debug),
            events: events + ["anthropic refusal stop_reason=refusal"])
    )
}

// MARK: - Helpers

private func anthropicFailure(
    status: HTTPResponse.Status,
    errorType: String,
    message: String,
    stream: Bool,
    requestBody: String?,
    events: [String],
    event: String
) -> (response: Response, trace: ChatRequestTrace) {
    (
        anthropicError(status: status, errorType: errorType, message: message),
        ChatRequestTrace(
            stream: stream, estimatedTokens: nil, error: message,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(message, enabled: serverState.config.debug),
            events: events + [event])
    )
}

/// Create an Anthropic-formatted error response envelope.
func anthropicError(status: HTTPResponse.Status, errorType: String, message: String) -> Response {
    let requestId = "req_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased())"
    let envelope = AnthropicErrorEnvelope(errorType: errorType, message: message, requestId: requestId)
    let body = jsonString(envelope, pretty: false)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body)))
}

private func anthropicJSONResponse(status: HTTPResponse.Status, body: String) -> Response {
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body)))
}

/// Ensure a tool-call argument string is a JSON object literal; default to `{}`.
private func normalizedJSONObject(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "{}" }
    if let data = trimmed.data(using: .utf8),
       (try? JSONSerialization.jsonObject(with: data)) != nil {
        return trimmed
    }
    return "{}"
}
