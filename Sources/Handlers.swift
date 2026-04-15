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
}

func capturedRequestBody(_ body: ByteBuffer, debugEnabled: Bool) -> String? {
    guard debugEnabled else { return nil }
    return body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
}

// MARK: - /v1/chat/completions

/// POST /v1/chat/completions — Main chat endpoint (streaming + non-streaming).
func handleChatCompletion(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    // Decode request body
    let body = try await request.body.collect(upTo: BodyLimits.maxRequestBodyBytes)
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

    if let failure = ChatRequestValidator.validate(chatRequest) {
        return chatFailure(
            status: .badRequest,
            message: failure.message,
            type: "invalid_request_error",
            stream: isStreaming,
            requestBody: requestBodyString,
            events: events,
            event: failure.event
        )
    }

    events.append("decoded messages=\(chatRequest.messages.count) stream=\(isStreaming) model=\(chatRequest.model)")

    // Build context config from request extensions (optional, defaults to newest-first)
    let contextConfig = ContextConfig(
        strategy: chatRequest.x_context_strategy.flatMap { ContextStrategy(rawValue: $0) } ?? .newestFirst,
        maxTurns: chatRequest.x_context_max_turns,
        outputReserve: chatRequest.x_context_output_reserve ?? BodyLimits.defaultOutputReserveTokens
    )

    // Build session options from request (retry config comes from server config)
    let sessionOpts = SessionOptions(
        temperature: chatRequest.temperature,
        maxTokens: chatRequest.max_tokens,
        seed: chatRequest.seed.map { UInt64($0) },
        permissive: false,
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
    do {
        let jsonMode = chatRequest.response_format?.type == "json_object"
        (session, finalPrompt) = try await ContextManager.makeSession(
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
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(session, finalPrompt: finalPrompt, options: sessionOpts)
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
            requestBody: requestBodyString, events: events
        )
        return (result.response, result.trace)
    }

    if isStreaming {
        let result = streamingResponse(session: session, prompt: finalPrompt,
                                       id: requestId, created: created,
                                       genOpts: genOpts, promptTokens: promptTokens,
                                       requestBody: requestBodyString, events: events)
        return (result.response, result.trace)
    } else {
        let result = try await nonStreamingResponse(session: session, prompt: finalPrompt,
                                                     id: requestId, created: created,
                                                     genOpts: genOpts, promptTokens: promptTokens,
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

    let completionTokens = await TokenCounter.shared.count(content)
    let finishReason = "stop"

    if streaming {
        // Wrap final content as SSE events: role -> content -> stop -> usage -> [DONE]
        let chunks: [String] = [
            sseDataLine(sseRoleChunk(id: id, created: created)),
            sseDataLine(sseContentChunk(id: id, created: created, content: content)),
            sseDataLine(ChatCompletionChunk(
                id: id, object: "chat.completion.chunk", created: created, model: modelName,
                choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: finishReason, logprobs: nil)],
                usage: nil
            )),
            sseDataLine(sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)),
            sseDone,
        ]
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
    requestBody: String?,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let nsRetryMax = serverState.config.retryEnabled ? serverState.config.retryCount : 0
    let content: String
    do {
        content = try await withRetry(maxRetries: nsRetryMax) {
            let result = try await session.respond(to: prompt, options: genOpts)
            return result.content
        }
    } catch {
        let classified = ApfelError.classify(error)
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

    // Detect tool calls in response
    let toolCalls = ToolCallHandler.detectToolCall(in: content)
    let responseMessage: OpenAIMessage
    if let calls = toolCalls {
        let openAIToolCalls = calls.map { ToolCall(id: $0.id, type: "function",
                                                    function: ToolCallFunction(name: $0.name, arguments: $0.argumentsString)) }
        responseMessage = OpenAIMessage(role: "assistant", content: nil, tool_calls: openAIToolCalls)
    } else {
        responseMessage = OpenAIMessage(role: "assistant", content: .text(content))
    }

    let completionTokens = await TokenCounter.shared.count(content)
    let finishReason = FinishReasonResolver.resolve(
        hasToolCalls: toolCalls != nil,
        completionTokens: completionTokens,
        maxTokens: genOpts.maximumResponseTokens
    ).openAIValue

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
            events: events + ["non-stream response chars=\(content.count)", "finish_reason=\(finishReason)"]
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
            let roleLine = sseDataLine(sseRoleChunk(id: id, created: created))
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
                        let chunkLine = sseDataLine(sseContentChunk(id: id, created: created, content: delta))
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
                        usage: nil
                    )
                    let toolLine = sseDataLine(toolChunk)
                    responseLines?.append(toolLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: toolLine))
                    await eventBox.append("tool_calls detected: \(calls.map(\.name).joined(separator: ", "))")
                } else {
                    let stopChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: finishReason, logprobs: nil)],
                        usage: nil
                    )
                    let stopLine = sseDataLine(stopChunk)
                    responseLines?.append(stopLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: stopLine))
                }

                // Emit usage stats as a proper chunk before [DONE]
                let usageChunk = sseUsageChunk(id: id, created: created, promptTokens: promptTokens, completionTokens: completionTokens)
                let usageLine = sseDataLine(usageChunk)
                responseLines?.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: usageLine))

                continuation.yield(ByteBuffer(string: sseDone))
                responseLines?.append("data: [DONE]")
                await eventBox.append("sent [DONE] total_chars=\(prev.count) finish_reason=\(finishReason)")
            } catch is CancellationError {
                streamCancelled = true
                await eventBox.append("stream cancelled by client")
            } catch {
                let classified = ApfelError.classify(error)
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
            events: events + ["stream request accepted", "final stream completion logged separately"]
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
    event: String
) -> (response: Response, trace: ChatRequestTrace) {
    (
        openAIError(status: status, message: message, type: type),
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

// MARK: - Error Helper

/// Create an OpenAI-formatted error response (with CORS headers when enabled).
func openAIError(status: HTTPResponse.Status, message: String, type: String, code: String? = nil) -> Response {
    let error = OpenAIErrorResponse(error: .init(message: message, type: type, param: nil, code: code))
    let body = jsonString(error)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body)))
}
