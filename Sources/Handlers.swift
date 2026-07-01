// ============================================================================
// Handlers.swift — HTTP request handlers for OpenAI-compatible API
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import FoundationModels
import Foundation
import Hummingbird
import NIOCore
import ApfelCore

struct ChatRequestTrace: Sendable {
    let stream: Bool
    let estimatedTokens: Int?
    let error: String?
    let requestBody: String?
    let responseBody: String?
    let events: [String]
    /// True only when the response body is a live AsyncStream whose
    /// onTermination handler releases the concurrency permit and the
    /// active_requests count itself (streamingResponse /
    /// structuredStreamingResponse). Every other response - including
    /// buffered SSE bodies and early stream failures - must be cleaned up
    /// by the route handler in Server.swift. Keying cleanup on `stream`
    /// instead of this flag leaked one permit per early-failing streaming
    /// request (#213).
    var ownsCleanup: Bool = false
}

func capturedRequestBody(_ body: ByteBuffer, debugEnabled: Bool) -> String? {
    guard debugEnabled else { return nil }
    return body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
}

// MARK: - /v1/chat/completions

/// POST /v1/chat/completions — Main chat endpoint (streaming + non-streaming).
func handleChatCompletion(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    // Decode request body. Collecting over the 1 MiB cap throws; if it
    // propagates out of the handler it bypasses SecurityMiddleware's CORS
    // headers and the request log (the route handler only logs returned
    // responses). Catch it here so a too-large body returns a proper 413
    // with an OpenAI error object, CORS headers, and a log entry (#234).
    let body: ByteBuffer
    do {
        body = try await request.body.collect(upTo: BodyLimits.maxRequestBodyBytes)
    } catch {
        let mib = BodyLimits.maxRequestBodyBytes / (1024 * 1024)
        return chatFailure(
            status: .init(code: 413),
            message: "Request body exceeds the \(mib) MiB limit.",
            type: "invalid_request_error",
            stream: false,
            requestBody: nil,
            events: events,
            event: "request body too large (limit \(BodyLimits.maxRequestBodyBytes) bytes)"
        )
    }
    let requestBodyString = capturedRequestBody(body, debugEnabled: serverState.config.debug)
    events.append("request bytes=\(body.readableBytes)")

    let chatRequest: ChatCompletionRequest
    do {
        chatRequest = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
    } catch {
        let msg = "Invalid JSON: \(error.localizedDescription)"
        return chatFailure(
            status: .badRequest,
            message: msg,
            type: "invalid_request_error",
            stream: false,
            requestBody: requestBodyString,
            events: events,
            event: "decode failed: \(msg)"
        )
    }
    let isStreaming = chatRequest.stream == true
    let includeUsage = chatRequest.stream_options?.include_usage == true
    let jsonMode = chatRequest.response_format?.type == "json_object"
    let wantsJSONSchema = chatRequest.response_format?.type == "json_schema"

    if let failure = ChatRequestValidator.validate(chatRequest) {
        return chatFailure(
            status: .init(code: failure.httpStatusCode),
            message: failure.message,
            type: "invalid_request_error",
            stream: isStreaming,
            requestBody: requestBodyString,
            events: events,
            event: failure.event,
            code: failure.errorCode,
            param: failure.errorParam
        )
    }

    events.append("decoded messages=\(chatRequest.messages.count) stream=\(isStreaming) model=\(chatRequest.model)")

    // response_format: json_schema -> guaranteed structured outputs (#167).
    // Build the native GenerationSchema up front so a malformed/unsupported
    // caller schema fails fast as a 400 before we touch the model.
    var structuredSchema: GenerationSchema?
    if wantsJSONSchema {
        guard let spec = chatRequest.response_format?.json_schema,
              let schemaJSON = spec.schema?.value else {
            return chatFailure(
                status: .badRequest,
                message: "response_format.json_schema requires a 'schema' object",
                type: "invalid_request_error",
                stream: isStreaming,
                requestBody: requestBodyString,
                events: events,
                event: "json_schema: missing schema"
            )
        }
        do {
            structuredSchema = try SchemaConverter.generationSchema(fromJSON: schemaJSON, name: spec.name)
        } catch {
            return chatFailure(
                status: .badRequest,
                message: "Invalid response_format.json_schema: \(error)",
                type: "invalid_request_error",
                stream: isStreaming,
                requestBody: requestBodyString,
                events: events,
                event: "json_schema: schema conversion failed: \(error)"
            )
        }
    }

    // Build context config from request extensions (optional, defaults to newest-first)
    let contextConfig = ContextConfig(
        strategy: chatRequest.x_context_strategy.flatMap { ContextStrategy(rawValue: $0) } ?? .newestFirst,
        maxTurns: chatRequest.x_context_max_turns,
        outputReserve: chatRequest.x_context_output_reserve ?? BodyLimits.defaultOutputReserveTokens
    )

    // Build session options from request (retry config comes from server config)
    let sessionOpts = SessionOptions(
        temperature: chatRequest.temperature,
        topP: chatRequest.top_p,
        maxTokens: chatRequest.max_tokens,
        seed: chatRequest.seed.map { UInt64($0) },
        permissive: serverState.config.permissive,
        contextConfig: contextConfig,
        retryEnabled: serverState.config.retryEnabled,
        retryCount: serverState.config.retryCount
    )

    // Inject MCP tools if client didn't send any; track source for auto-execution
    let mcpTools = await serverState.mcpManager?.allTools()
    let resolvedTools = ToolResolution.resolve(clientTools: chatRequest.tools, mcpTools: mcpTools)
    let effectiveTools = resolvedTools.tools
    let toolsAreMCPInjected = resolvedTools.injected

    // Build session + extract final prompt via ContextManager (Transcript API)
    let session: LanguageModelSession
    let finalPrompt: String
    let inputEntries: [Transcript.Entry]
    do {
        (session, finalPrompt, inputEntries) = try await ContextManager.makeSession(
            messages: chatRequest.messages,
            tools: effectiveTools,
            options: sessionOpts,
            jsonMode: jsonMode,
            toolChoice: chatRequest.tool_choice
        )
    } catch {
        let classified = ApfelError.classify(error)
        let msg = classified.openAIMessage
        return chatFailure(
            status: .init(code: classified.httpStatusCode),
            message: msg,
            type: classified.openAIType,
            stream: isStreaming,
            requestBody: requestBodyString,
            events: events,
            event: "context build failed: \(msg)"
        )
    }
    events.append("context built history=\(max(0, chatRequest.messages.count - 1)) final_prompt_chars=\(finalPrompt.count)")

    let genOpts = makeGenerationOptions(sessionOpts)
    // Count the entries we actually built (native tool definitions intact),
    // not the session's transcript, which drops Instructions.toolDefinitions (#176).
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(builtEntries: inputEntries, finalPrompt: finalPrompt, options: sessionOpts)
    )
    let requestId = "chatcmpl-\(UUID().uuidString.prefix(12).lowercased())"
    let created = Int(Date().timeIntervalSince1970)

    // MCP auto-execute: when tools were server-injected, run model, execute tool calls,
    // re-prompt for final answer, then deliver as JSON or SSE.
    if toolsAreMCPInjected {
        let userPrompt = chatRequest.messages.last(where: { $0.role == "user" })?.textContent ?? finalPrompt
        let result = try await mcpAutoExecuteResponse(
            session: session, prompt: finalPrompt, userPrompt: userPrompt,
            originalMessages: chatRequest.messages, sessionOptions: sessionOpts,
            id: requestId, created: created, genOpts: genOpts,
            promptTokens: promptTokens, streaming: isStreaming,
            includeUsage: includeUsage, jsonMode: jsonMode,
            requestBody: requestBodyString, events: events
        )
        return (result.response, result.trace)
    }

    // json_schema -> schema-guided generation (#167, streaming #171).
    if let schema = structuredSchema {
        if isStreaming {
            let result = structuredStreamingResponse(
                session: session, prompt: finalPrompt, schema: schema,
                id: requestId, created: created, genOpts: genOpts,
                promptTokens: promptTokens, includeUsage: includeUsage,
                requestBody: requestBodyString, events: events)
            return (result.response, result.trace)
        }
        let result = try await structuredNonStreamingResponse(
            session: session, prompt: finalPrompt, schema: schema,
            id: requestId, created: created, genOpts: genOpts,
            promptTokens: promptTokens, requestBody: requestBodyString, events: events)
        return (result.response, result.trace)
    }

    if isStreaming {
        let result = streamingResponse(session: session, prompt: finalPrompt,
                                       id: requestId, created: created,
                                       genOpts: genOpts, promptTokens: promptTokens,
                                       includeUsage: includeUsage,
                                       requestBody: requestBodyString, events: events)
        return (result.response, result.trace)
    } else {
        let result = try await nonStreamingResponse(session: session, prompt: finalPrompt,
                                                     id: requestId, created: created,
                                                     genOpts: genOpts, promptTokens: promptTokens,
                                                     jsonMode: jsonMode,
                                                     requestBody: requestBodyString, events: events)
        return (result.response, result.trace)
    }
}

// MARK: - MCP Auto-Execute Response

/// When MCP tools were server-injected, collect the model response, execute any tool calls
/// via MCPManager, re-prompt for a final text answer, then wrap as JSON or SSE.
private func mcpAutoExecuteResponse(
    session: LanguageModelSession,
    prompt: String,
    userPrompt: String,
    originalMessages: [OpenAIMessage],
    sessionOptions: SessionOptions,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    streaming: Bool,
    includeUsage: Bool,
    jsonMode: Bool,
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events = events

    // Collect full model response (never stream intermediate tool-call output to client)
    let srvRetryMax = sessionOptions.retryEnabled ? sessionOptions.retryCount : 0
    let rawContent: String
    do {
        rawContent = try await withRetry(maxRetries: srvRetryMax) {
            let result = try await session.respond(to: prompt, options: genOpts)
            return result.content
        }
    } catch {
        let classified = ApfelError.classify(error)
        if case .refusal(let explanation) = classified {
            if streaming {
                return await refusalStreamingResponse(
                    id: id, created: created, promptTokens: promptTokens,
                    refusal: explanation, includeUsage: includeUsage,
                    requestBody: requestBody,
                    events: events + ["refusal: \(classified.cliLabel)"]
                )
            }
            return await refusalNonStreamingResponse(
                id: id, created: created, promptTokens: promptTokens,
                refusal: explanation, requestBody: requestBody,
                events: events + ["refusal: \(classified.cliLabel)"]
            )
        }
        let msg = classified.openAIMessage
        return chatFailure(
            status: .init(code: classified.httpStatusCode),
            message: msg,
            type: classified.openAIType,
            stream: streaming,
            requestBody: requestBody,
            events: events,
            event: "model error: \(classified.cliLabel)"
        )
    }

    // Auto-execute MCP tool calls and re-prompt for plain text answer
    let content: String
    do {
        if let executed = try await executeMCPToolCallsForServer(
            in: rawContent,
            mcpManager: serverState.mcpManager,
            userPrompt: userPrompt,
            messages: originalMessages,
            sessionOptions: sessionOptions,
            options: genOpts
        ) {
            for log in executed.toolLog {
                events.append("mcp tool: \(log.name)(\(log.args)) = \(log.isError ? "error: " : "")\(log.result)")
            }
            content = executed.content
            events.append("mcp: auto-executed, final response chars=\(content.count)")
        } else {
            content = rawContent
        }
    } catch {
        let classified = ApfelError.classify(error)
        let msg = classified.openAIMessage
        return chatFailure(
            status: .init(code: classified.httpStatusCode),
            message: msg,
            type: classified.openAIType,
            stream: streaming,
            requestBody: requestBody,
            events: events,
            event: "mcp execution failed: \(msg)"
        )
    }

    let deliveredContent = jsonMode ? JSONFenceStripper.strip(content) : content
    let completionTokens = await TokenCounter.shared.count(deliveredContent)
    let finishReason = "stop"

    if streaming {
        // SSE event order: role -> content -> stop [-> usage when opted in] -> [DONE]
        var chunks: [String] = [
            sseDataLine(sseRoleChunk(id: id, created: created, includeUsage: includeUsage)),
            sseDataLine(sseContentChunk(id: id, created: created, content: deliveredContent, includeUsage: includeUsage)),
            sseDataLine(ChatCompletionChunk(
                id: id, object: "chat.completion.chunk", created: created, model: modelName,
                choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: finishReason, logprobs: nil)],
                usage: nil,
                includeUsageNull: includeUsage
            )),
        ]
        if includeUsage {
            chunks.append(sseDataLine(sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)))
        }
        chunks.append(sseDone)
        let body = chunks.joined()
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.init("Connection")!] = "keep-alive"
        let response = Response(status: .ok, headers: headers,
                                 body: .init(byteBuffer: ByteBuffer(string: body)))
        return (
            response,
            ChatRequestTrace(
                stream: true,
                estimatedTokens: promptTokens + completionTokens,
                error: nil,
                requestBody: requestBody,
                responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
                events: events + ["mcp sse finish_reason=\(finishReason)"]
            )
        )
    } else {
        let responseMessage = OpenAIMessage(role: "assistant", content: .text(deliveredContent))
        let payload = ChatCompletionResponse(
            id: id,
            object: "chat.completion",
            created: created,
            model: modelName,
            choices: [.init(index: 0, message: responseMessage, finish_reason: finishReason, logprobs: nil)],
            usage: .init(prompt_tokens: promptTokens, completion_tokens: completionTokens,
                         total_tokens: promptTokens + completionTokens)
        )
        let body = jsonString(payload)
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        let response = Response(status: .ok, headers: headers,
                                 body: .init(byteBuffer: ByteBuffer(string: body)))
        return (
            response,
            ChatRequestTrace(
                stream: false,
                estimatedTokens: promptTokens + completionTokens,
                error: nil,
                requestBody: requestBody,
                responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
                events: events + ["mcp non-stream finish_reason=\(finishReason)"]
            )
        )
    }
}

// MARK: - Non-Streaming Response

private func nonStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    jsonMode: Bool,
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let nsRetryMax = serverState.config.retryEnabled ? serverState.config.retryCount : 0
    let outcome: StreamOutcome
    do {
        // Route non-streaming through collectStream so output-side context
        // overflow surfaces as a graceful length-finish on this path too.
        outcome = try await withRetry(maxRetries: nsRetryMax) {
            try await collectStream(session, prompt: prompt, options: genOpts)
        }
    } catch {
        let classified = ApfelError.classify(error)
        if case .refusal(let explanation) = classified {
            return await refusalNonStreamingResponse(
                id: id, created: created, promptTokens: promptTokens,
                refusal: explanation, requestBody: requestBody,
                events: events + ["refusal: \(classified.cliLabel)"]
            )
        }
        let msg = classified.openAIMessage
        return chatFailure(
            status: .init(code: classified.httpStatusCode),
            message: msg,
            type: classified.openAIType,
            stream: false,
            requestBody: requestBody,
            events: events,
            event: "model error: \(classified.cliLabel)"
        )
    }
    let rawContent = outcome.content

    // Detect tool calls in response
    let toolCalls = ToolCallHandler.detectToolCall(in: rawContent)
    let responseMessage: OpenAIMessage
    let deliveredContent: String
    if let calls = toolCalls {
        let openAIToolCalls = calls.map { ToolCall(id: $0.id, type: "function",
                                                    function: ToolCallFunction(name: $0.name, arguments: $0.argumentsString)) }
        responseMessage = OpenAIMessage(role: "assistant", content: nil, tool_calls: openAIToolCalls)
        deliveredContent = rawContent
    } else {
        deliveredContent = jsonMode ? JSONFenceStripper.strip(rawContent) : rawContent
        responseMessage = OpenAIMessage(role: "assistant", content: .text(deliveredContent))
    }

    let completionTokens = await TokenCounter.shared.count(deliveredContent)
    // collectStream already resolved .stop vs .length (cap-hit and output-side
    // overflow); only override here when tool calls are detected.
    let finishReason = (toolCalls != nil ? FinishReason.toolCalls : outcome.finishReason).openAIValue

    let payload = ChatCompletionResponse(
        id: id,
        object: "chat.completion",
        created: created,
        model: modelName,
        choices: [.init(index: 0, message: responseMessage, finish_reason: finishReason, logprobs: nil)],
        usage: .init(prompt_tokens: promptTokens, completion_tokens: completionTokens,
                     total_tokens: promptTokens + completionTokens)
    )

    let body = jsonString(payload)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    let response = Response(status: .ok, headers: headers,
                             body: .init(byteBuffer: ByteBuffer(string: body)))
    return (
        response,
        ChatRequestTrace(
            stream: false,
            estimatedTokens: promptTokens + completionTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
            events: events + ["non-stream response chars=\(deliveredContent.count)", "finish_reason=\(finishReason)"]
        )
    )
}

// MARK: - Streaming Response (SSE)

private func streamingResponse(
    session: LanguageModelSession,
    prompt: String,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    includeUsage: Bool,
    requestBody: String?,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    let eventBox = TraceBuffer(events: events + ["stream start"])
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
            var completionTokens = 0

            defer {
                Task {
                    await cleanup.run {
                        await serverState.semaphore.signal()
                        await serverState.logStore.requestFinished()
                    }
                    continuation.finish()
                }
            }

            // Role announcement chunk
            let roleLine = sseDataLine(sseRoleChunk(id: id, created: created, includeUsage: includeUsage))
            responseLines?.append(roleLine.trimmingCharacters(in: .whitespacesAndNewlines))
            continuation.yield(ByteBuffer(string: roleLine))
            await eventBox.append("sent role chunk")

            let stream = session.streamResponse(to: prompt, options: genOpts)
            var prev = ""
            var chunkCount = 0

            do {
                for try await snapshot in stream {
                    let content = snapshot.content
                    if content.count > prev.count {
                        let idx = content.index(content.startIndex, offsetBy: prev.count)
                        let delta = String(content[idx...])
                        let chunkLine = sseDataLine(sseContentChunk(id: id, created: created, content: delta, includeUsage: includeUsage))
                        responseLines?.append(chunkLine.trimmingCharacters(in: .whitespacesAndNewlines))
                        continuation.yield(ByteBuffer(string: chunkLine))
                        chunkCount += 1
                        await eventBox.append("chunk #\(chunkCount) delta=\(delta.count) total=\(content.count)")
                    }
                    prev = content
                }

                // Check accumulated response for tool calls before emitting final chunk
                let toolCalls = ToolCallHandler.detectToolCall(in: prev)
                completionTokens = await TokenCounter.shared.count(prev)
                let resolved = FinishReasonResolver.resolve(
                    hasToolCalls: toolCalls != nil,
                    completionTokens: completionTokens,
                    maxTokens: genOpts.maximumResponseTokens
                )
                let finishReason = resolved.openAIValue
                if let calls = toolCalls {
                    let openAIToolCalls = calls.map {
                        ToolCall(id: $0.id, type: "function",
                                 function: ToolCallFunction(name: $0.name, arguments: $0.argumentsString))
                    }
                    let chunkToolCalls = openAIToolCalls.enumerated().map { index, call in
                        ChatCompletionChunk.ToolCallDelta(
                            index: index,
                            id: call.id,
                            type: call.type,
                            function: call.function
                        )
                    }
                    let toolChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(
                            index: 0,
                            delta: .init(role: nil, content: nil, tool_calls: chunkToolCalls),
                            finish_reason: finishReason,
                            logprobs: nil
                        )],
                        usage: nil,
                        includeUsageNull: includeUsage
                    )
                    let toolLine = sseDataLine(toolChunk)
                    responseLines?.append(toolLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: toolLine))
                    await eventBox.append("tool_calls detected: \(calls.map(\.name).joined(separator: ", "))")
                } else {
                    let stopChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: finishReason, logprobs: nil)],
                        usage: nil,
                        includeUsageNull: includeUsage
                    )
                    let stopLine = sseDataLine(stopChunk)
                    responseLines?.append(stopLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: stopLine))
                }

                // Per OpenAI spec, emit the usage chunk only when the client
                // opted in via stream_options.include_usage=true. Without
                // opt-in, the empty-choices usage chunk is a spec violation.
                if includeUsage {
                    let usageChunk = sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)
                    let usageLine = sseDataLine(usageChunk)
                    responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: usageLine))
                }

                continuation.yield(ByteBuffer(string: sseDone))
                responseLines?.append("data: [DONE]")
                await eventBox.append("sent [DONE] total_chars=\(prev.count) finish_reason=\(finishReason)")
            } catch is CancellationError {
                streamCancelled = true
                await eventBox.append("stream cancelled by client")
            } catch {
                let classified = ApfelError.classify(error)
                // Output-side context overflow with content already streamed is
                // a graceful length-finish, not an error. See StreamErrorResolver.
                if case .truncated(let truncatedContent) = StreamErrorResolver.resolve(prev: prev, error: classified) {
                    completionTokens = await TokenCounter.shared.count(truncatedContent)
                    let lengthChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(
                            index: 0,
                            delta: .init(role: nil, content: nil, tool_calls: nil),
                            finish_reason: FinishReason.length.openAIValue,
                            logprobs: nil
                        )],
                        usage: nil,
                        includeUsageNull: includeUsage
                    )
                    let lengthLine = sseDataLine(lengthChunk)
                    responseLines?.append(lengthLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: lengthLine))

                    if includeUsage {
                        let usageChunk = sseUsageChunk(
                            id: id, created: created,
                            promptTokens: promptTokens, completionTokens: completionTokens
                        )
                        let usageLine = sseDataLine(usageChunk)
                        responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                        continuation.yield(ByteBuffer(string: usageLine))
                    }

                    continuation.yield(ByteBuffer(string: sseDone))
                    responseLines?.append("data: [DONE]")
                    await eventBox.append("stream truncated by context, finish_reason=length total_chars=\(truncatedContent.count)")
                } else if case .refusal(let explanation) = classified {
                    // OpenAI wire format: stream a refusal delta, then a final
                    // chunk with finish_reason=content_filter, then [DONE].
                    let refusalLine = sseDataLine(sseRefusalChunk(id: id, created: created, refusal: explanation, includeUsage: includeUsage))
                    responseLines?.append(refusalLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: refusalLine))

                    let finishLine = sseDataLine(sseContentFilterFinishChunk(id: id, created: created, includeUsage: includeUsage))
                    responseLines?.append(finishLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: finishLine))

                    // Completion tokens must account for BOTH the content already
                    // streamed before the refusal (accumulated in `prev`) and the
                    // refusal explanation itself. Counting only `explanation` drops
                    // the pre-refusal streamed content. The pure helper returns the
                    // concatenation so we make a single `count()` call (avoiding
                    // double-counting tokens at the join boundary).
                    completionTokens = await TokenCounter.shared.count(
                        StreamErrorResolver.refusalCompletionText(prev: prev, explanation: explanation))
                    if includeUsage {
                        let usageChunk = sseUsageChunk(
                            id: id, created: created,
                            promptTokens: promptTokens, completionTokens: completionTokens
                        )
                        let usageLine = sseDataLine(usageChunk)
                        responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                        continuation.yield(ByteBuffer(string: usageLine))
                    }

                    continuation.yield(ByteBuffer(string: sseDone))
                    responseLines?.append("data: [DONE]")
                    await eventBox.append("sent refusal stream finish_reason=content_filter")
                } else {
                    let errPayload = OpenAIErrorResponse(error: .init(
                        message: classified.openAIMessage, type: classified.openAIType, param: nil, code: nil))
                    let errJSON = jsonString(errPayload, pretty: false)
                    let errMsg = "data: \(errJSON)\n\n"
                    responseLines?.append(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: errMsg))
                    continuation.yield(ByteBuffer(string: sseDone))
                    streamError = classified.openAIMessage
                    await eventBox.append("stream error: \(classified.cliLabel) \(classified.openAIMessage)")
                }
            }

            let completionLog = RequestLog(
                id: "\(id)-stream",
                timestamp: ISO8601DateFormatter().string(from: streamStart),
                method: "POST",
                path: "/v1/chat/completions/stream",
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
                ? "Streaming response in progress. See /v1/chat/completions/stream log for final SSE transcript."
                : nil,
            events: events + ["stream request accepted", "final stream completion logged separately"],
            ownsCleanup: true
        )
    )
}

// MARK: - Structured Output (response_format: json_schema, #167)

/// Non-streaming schema-guided generation. The model generates against the
/// native `GenerationSchema`, guaranteeing the output conforms to the caller's
/// JSON Schema. The `GeneratedContent` is serialized to JSON and returned as
/// the message content.
private func structuredNonStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    schema: GenerationSchema,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
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
            return await refusalNonStreamingResponse(
                id: id, created: created, promptTokens: promptTokens,
                refusal: explanation, requestBody: requestBody,
                events: events + ["refusal: \(classified.cliLabel)"]
            )
        }
        let msg = classified.openAIMessage
        return chatFailure(
            status: .init(code: classified.httpStatusCode),
            message: msg,
            type: classified.openAIType,
            stream: false,
            requestBody: requestBody,
            events: events,
            event: "structured model error: \(classified.cliLabel)"
        )
    }

    let completionTokens = await TokenCounter.shared.count(content)
    let finishReason = "stop"
    let responseMessage = OpenAIMessage(role: "assistant", content: .text(content))
    let payload = ChatCompletionResponse(
        id: id,
        object: "chat.completion",
        created: created,
        model: modelName,
        choices: [.init(index: 0, message: responseMessage, finish_reason: finishReason, logprobs: nil)],
        usage: .init(prompt_tokens: promptTokens, completion_tokens: completionTokens,
                     total_tokens: promptTokens + completionTokens)
    )
    let body = jsonString(payload)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    let response = Response(status: .ok, headers: headers,
                             body: .init(byteBuffer: ByteBuffer(string: body)))
    return (
        response,
        ChatRequestTrace(
            stream: false,
            estimatedTokens: promptTokens + completionTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
            events: events + ["structured non-stream chars=\(content.count)", "finish_reason=\(finishReason)"]
        )
    )
}

/// Streaming schema-guided generation (#171). FoundationModels emits cumulative
/// `GeneratedContent` snapshots; we serialize each to JSON and stream the new
/// suffix as content deltas, so the concatenated stream is valid, conforming JSON.
private func structuredStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    schema: GenerationSchema,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    includeUsage: Bool,
    requestBody: String?,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    let eventBox = TraceBuffer(events: events + ["structured stream start"])
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
            var completionTokens = 0

            defer {
                Task {
                    await cleanup.run {
                        await serverState.semaphore.signal()
                        await serverState.logStore.requestFinished()
                    }
                    continuation.finish()
                }
            }

            let roleLine = sseDataLine(sseRoleChunk(id: id, created: created, includeUsage: includeUsage))
            responseLines?.append(roleLine.trimmingCharacters(in: .whitespacesAndNewlines))
            continuation.yield(ByteBuffer(string: roleLine))
            await eventBox.append("sent role chunk")

            let stream = session.streamResponse(to: prompt, schema: schema, options: genOpts)
            var prev = ""

            do {
                // Partial GeneratedContent snapshots do not serialize to a
                // growing prefix of the final JSON (a partial object's jsonString
                // is its own well-formed fragment, not a substring of the final).
                // Streaming suffix-diffs would therefore concatenate into invalid
                // JSON. To keep the concatenated stream a single valid, conforming
                // document, we buffer to the final snapshot and emit it as one
                // content delta (#167/#171).
                for try await snapshot in stream {
                    prev = snapshot.content.jsonString
                }

                let contentLine = sseDataLine(sseContentChunk(id: id, created: created, content: prev, includeUsage: includeUsage))
                responseLines?.append(contentLine.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: contentLine))
                await eventBox.append("structured content delta chars=\(prev.count)")

                completionTokens = await TokenCounter.shared.count(prev)
                let finishReason = FinishReason.stop.openAIValue
                let stopChunk = ChatCompletionChunk(
                    id: id, object: "chat.completion.chunk", created: created, model: modelName,
                    choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: finishReason, logprobs: nil)],
                    usage: nil,
                    includeUsageNull: includeUsage
                )
                let stopLine = sseDataLine(stopChunk)
                responseLines?.append(stopLine.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: stopLine))

                if includeUsage {
                    let usageChunk = sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)
                    let usageLine = sseDataLine(usageChunk)
                    responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: usageLine))
                }

                continuation.yield(ByteBuffer(string: sseDone))
                responseLines?.append("data: [DONE]")
                await eventBox.append("sent [DONE] total_chars=\(prev.count) finish_reason=\(finishReason)")
            } catch is CancellationError {
                streamCancelled = true
                await eventBox.append("structured stream cancelled by client")
            } catch {
                let classified = ApfelError.classify(error)
                if case .refusal(let explanation) = classified {
                    let refusalLine = sseDataLine(sseRefusalChunk(id: id, created: created, refusal: explanation, includeUsage: includeUsage))
                    responseLines?.append(refusalLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: refusalLine))

                    let finishLine = sseDataLine(sseContentFilterFinishChunk(id: id, created: created, includeUsage: includeUsage))
                    responseLines?.append(finishLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: finishLine))

                    completionTokens = await TokenCounter.shared.count(
                        StreamErrorResolver.refusalCompletionText(prev: prev, explanation: explanation))
                    if includeUsage {
                        let usageChunk = sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)
                        let usageLine = sseDataLine(usageChunk)
                        responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                        continuation.yield(ByteBuffer(string: usageLine))
                    }

                    continuation.yield(ByteBuffer(string: sseDone))
                    responseLines?.append("data: [DONE]")
                    await eventBox.append("sent refusal stream finish_reason=content_filter")
                } else {
                    let errPayload = OpenAIErrorResponse(error: .init(
                        message: classified.openAIMessage, type: classified.openAIType, param: nil, code: nil))
                    let errJSON = jsonString(errPayload, pretty: false)
                    let errMsg = "data: \(errJSON)\n\n"
                    responseLines?.append(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: errMsg))
                    continuation.yield(ByteBuffer(string: sseDone))
                    streamError = classified.openAIMessage
                    await eventBox.append("structured stream error: \(classified.cliLabel) \(classified.openAIMessage)")
                }
            }

            let completionLog = RequestLog(
                id: "\(id)-stream",
                timestamp: ISO8601DateFormatter().string(from: streamStart),
                method: "POST",
                path: "/v1/chat/completions/stream",
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
                ? "Streaming response in progress. See /v1/chat/completions/stream log for final SSE transcript."
                : nil,
            events: events + ["structured stream request accepted", "final stream completion logged separately"],
            ownsCleanup: true
        )
    )
}

private func chatFailure(
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

// MARK: - Refusal Response (OpenAI wire-format parity: 200 + content_filter)

/// Build a non-streaming 200 OK response for an on-device model refusal.
///
/// OpenAI wire format: `choices[0].message.refusal` populated,
/// `choices[0].message.content: null`, `choices[0].finish_reason: "content_filter"`.
private func refusalNonStreamingResponse(
    id: String,
    created: Int,
    promptTokens: Int,
    refusal: String,
    requestBody: String?,
    events: [String]
) async -> (response: Response, trace: ChatRequestTrace) {
    let responseMessage = OpenAIMessage(role: "assistant", content: nil, refusal: refusal)
    let completionTokens = await TokenCounter.shared.count(refusal)
    let finishReason = FinishReason.contentFilter.openAIValue
    let payload = ChatCompletionResponse(
        id: id,
        object: "chat.completion",
        created: created,
        model: modelName,
        choices: [.init(index: 0, message: responseMessage, finish_reason: finishReason, logprobs: nil)],
        usage: .init(
            prompt_tokens: promptTokens,
            completion_tokens: completionTokens,
            total_tokens: promptTokens + completionTokens
        )
    )
    let body = jsonString(payload)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    let response = Response(status: .ok, headers: headers,
                             body: .init(byteBuffer: ByteBuffer(string: body)))
    return (
        response,
        ChatRequestTrace(
            stream: false,
            estimatedTokens: promptTokens + completionTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
            events: events + ["refusal non-stream finish_reason=\(finishReason)"]
        )
    )
}

/// Build a streaming 200 OK response for an on-device model refusal.
///
/// SSE order: role chunk -> refusal delta -> content_filter finish chunk
/// -> [optional usage chunk when include_usage=true] -> [DONE].
private func refusalStreamingResponse(
    id: String,
    created: Int,
    promptTokens: Int,
    refusal: String,
    includeUsage: Bool,
    requestBody: String?,
    events: [String]
) async -> (response: Response, trace: ChatRequestTrace) {
    let completionTokens = await TokenCounter.shared.count(refusal)
    let finishReason = FinishReason.contentFilter.openAIValue
    var chunks: [String] = [
        sseDataLine(sseRoleChunk(id: id, created: created, includeUsage: includeUsage)),
        sseDataLine(sseRefusalChunk(id: id, created: created, refusal: refusal, includeUsage: includeUsage)),
        sseDataLine(sseContentFilterFinishChunk(id: id, created: created, includeUsage: includeUsage)),
    ]
    if includeUsage {
        chunks.append(sseDataLine(sseUsageChunk(
            id: id, created: created,
            promptTokens: promptTokens, completionTokens: completionTokens
        )))
    }
    chunks.append(sseDone)
    let body = chunks.joined()
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    let response = Response(status: .ok, headers: headers,
                             body: .init(byteBuffer: ByteBuffer(string: body)))
    return (
        response,
        ChatRequestTrace(
            stream: true,
            estimatedTokens: promptTokens + completionTokens,
            error: nil,
            requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug),
            events: events + ["refusal sse finish_reason=\(finishReason)"]
        )
    )
}

// MARK: - Error Helper

/// Create an OpenAI-formatted error response (with CORS headers when enabled).
func openAIError(status: HTTPResponse.Status, message: String, type: String, code: String? = nil, param: String? = nil) -> Response {
    let error = OpenAIErrorResponse(error: .init(message: message, type: type, param: param, code: code))
    let body = jsonString(error)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body)))
}
