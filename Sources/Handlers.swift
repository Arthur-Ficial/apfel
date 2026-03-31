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

// MARK: - /v1/chat/completions

/// POST /v1/chat/completions — Main chat endpoint (streaming + non-streaming).
func handleChatCompletion(_ request: Request, context: some RequestContext) async throws -> (response: Response, trace: ChatRequestTrace) {
    var events: [String] = []

    // Decode request body
    let body = try await request.body.collect(upTo: 1024 * 1024)
    let requestBodyString = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
    events.append("request bytes=\(body.readableBytes)")

    let chatRequest: ChatCompletionRequest
    do {
        chatRequest = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
    } catch {
        let msg = "Invalid JSON: \(error.localizedDescription)"
        return (openAIError(status: .badRequest, message: msg, type: "invalid_request_error"),
                ChatRequestTrace(stream: false, estimatedTokens: nil, error: msg,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: msg, events: events + ["decode failed: \(msg)"]))
    }

    // Validate: must have at least one message
    guard !chatRequest.messages.isEmpty else {
        let msg = "'messages' must contain at least one message"
        return (openAIError(status: .badRequest, message: msg, type: "invalid_request_error"),
                ChatRequestTrace(stream: chatRequest.stream == true, estimatedTokens: nil, error: msg,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: msg, events: events + ["validation failed: empty messages"]))
    }

    if let unsupported = unsupportedParameter(in: chatRequest) {
        return (openAIError(status: .badRequest, message: unsupported.message, type: "invalid_request_error"),
                ChatRequestTrace(stream: chatRequest.stream == true, estimatedTokens: nil, error: unsupported.message,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: unsupported.message,
                                 events: events + ["validation failed: unsupported parameter \(unsupported.name)"]))
    }

    // Validate: last message must be user or tool (tool = standard tool-calling flow)
    guard ["user", "tool"].contains(chatRequest.messages.last?.role) else {
        let msg = "Last message must have role 'user' or 'tool'"
        return (openAIError(status: .badRequest, message: msg, type: "invalid_request_error"),
                ChatRequestTrace(stream: chatRequest.stream == true, estimatedTokens: nil, error: msg,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: msg, events: events + ["validation failed: last role != user/tool"]))
    }

    // Reject image content (not supported by Apple's on-device model)
    let hasImages = chatRequest.messages.contains { msg in
        if case .parts(let parts) = msg.content {
            return parts.contains { $0.type == "image_url" }
        }
        return false
    }
    if hasImages {
        let msg = "Image content is not supported by the Apple on-device model"
        return (openAIError(status: .badRequest, message: msg, type: "invalid_request_error"),
                ChatRequestTrace(stream: chatRequest.stream == true, estimatedTokens: nil, error: msg,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: msg, events: events + ["rejected: image content"]))
    }

    events.append("decoded messages=\(chatRequest.messages.count) stream=\(chatRequest.stream == true) model=\(chatRequest.model)")

    // Build context config from request extensions (optional, defaults to newest-first)
    let contextConfig = ContextConfig(
        strategy: chatRequest.x_context_strategy.flatMap { ContextStrategy(rawValue: $0) } ?? .newestFirst,
        maxTurns: chatRequest.x_context_max_turns,
        outputReserve: chatRequest.x_context_output_reserve ?? 512
    )

    // Build session options from request
    let sessionOpts = SessionOptions(
        temperature: chatRequest.temperature,
        maxTokens: chatRequest.max_tokens,
        seed: chatRequest.seed.map { UInt64($0) },
        permissive: false,
        contextConfig: contextConfig
    )

    // Build session + extract final prompt via ContextManager (Transcript API)
    let session: LanguageModelSession
    let finalPrompt: String
    do {
        let jsonMode = chatRequest.response_format?.type == "json_object"
        (session, finalPrompt) = try await ContextManager.makeSession(
            messages: chatRequest.messages,
            tools: chatRequest.tools,
            options: sessionOpts,
            jsonMode: jsonMode,
            toolChoice: chatRequest.tool_choice
        )
    } catch {
        let classified = ApfelError.classify(error)
        let msg = classified.openAIMessage
        return (openAIError(status: .init(code: classified.httpStatusCode), message: msg, type: classified.openAIType),
                ChatRequestTrace(stream: chatRequest.stream == true, estimatedTokens: nil, error: msg,
                                 requestBody: truncateForLog(requestBodyString),
                                 responseBody: msg, events: events + ["context build failed: \(msg)"]))
    }
    events.append("context built history=\(max(0, chatRequest.messages.count - 1)) final_prompt_chars=\(finalPrompt.count)")

    let genOpts = makeGenerationOptions(sessionOpts)
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(session, finalPrompt: finalPrompt, options: sessionOpts)
    )
    let requestId = "chatcmpl-\(UUID().uuidString.prefix(12).lowercased())"
    let created = Int(Date().timeIntervalSince1970)

    if chatRequest.stream == true {
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

// MARK: - Non-Streaming Response

private func nonStreamingResponse(
    session: LanguageModelSession,
    prompt: String,
    id: String,
    created: Int,
    genOpts: GenerationOptions,
    promptTokens: Int,
    requestBody: String,
    events: [String]
) async throws -> (response: Response, trace: ChatRequestTrace) {
    let content: String
    do {
        let result = try await session.respond(to: prompt, options: genOpts)
        content = result.content
    } catch {
        let classified = ApfelError.classify(error)
        let msg = classified.openAIMessage
        return (
            openAIError(status: .init(code: classified.httpStatusCode), message: msg, type: classified.openAIType),
            ChatRequestTrace(stream: false, estimatedTokens: nil, error: msg,
                             requestBody: truncateForLog(requestBody),
                             responseBody: msg, events: events + ["model error: \(classified.cliLabel)"])
        )
    }

    // Detect tool calls in response
    let toolCalls = ToolCallHandler.detectToolCall(in: content)
    var finishReason: String
    let responseMessage: OpenAIMessage
    if let calls = toolCalls {
        finishReason = "tool_calls"
        let openAIToolCalls = calls.map { ToolCall(id: $0.id, type: "function",
                                                    function: ToolCallFunction(name: $0.name, arguments: $0.argumentsString)) }
        responseMessage = OpenAIMessage(role: "assistant", content: nil, tool_calls: openAIToolCalls)
    } else {
        responseMessage = OpenAIMessage(role: "assistant", content: .text(content))
        finishReason = "stop"  // may be overridden below
    }

    let completionTokens = await TokenCounter.shared.count(content)

    // Detect truncation: if max_tokens was set and response hit the limit
    if finishReason == "stop",
       let maxTok = genOpts.maximumResponseTokens,
       completionTokens >= maxTok {
        finishReason = "length"
    }

    let payload = ChatCompletionResponse(
        id: id,
        object: "chat.completion",
        created: created,
        model: modelName,
        choices: [.init(index: 0, message: responseMessage, finish_reason: finishReason)],
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
            requestBody: truncateForLog(requestBody),
            responseBody: truncateForLog(body),
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
    requestBody: String,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    var headers = HTTPFields()
    headers[.contentType] = "text/event-stream"
    headers[.cacheControl] = "no-cache"
    headers[.init("Connection")!] = "keep-alive"
    if serverState?.config.cors == true {
        headers[.init("Access-Control-Allow-Origin")!] = "*"
    }
    let eventBox = TraceBuffer(events: events + ["stream start"])

    let responseStream = AsyncStream<ByteBuffer> { continuation in
        Task {
            let streamStart = Date()
            var responseLines: [String] = []
            var streamError: String?

            // Role announcement chunk
            let roleLine = sseDataLine(sseRoleChunk(id: id, created: created))
            responseLines.append(roleLine.trimmingCharacters(in: .whitespacesAndNewlines))
            continuation.yield(ByteBuffer(string: roleLine))
            eventBox.append("sent role chunk")

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
                        responseLines.append(chunkLine.trimmingCharacters(in: .whitespacesAndNewlines))
                        continuation.yield(ByteBuffer(string: chunkLine))
                        chunkCount += 1
                        eventBox.append("chunk #\(chunkCount) delta=\(delta.count) total=\(content.count)")
                    }
                    prev = content
                }

                // Check accumulated response for tool calls before emitting final chunk
                let toolCalls = ToolCallHandler.detectToolCall(in: prev)
                if let calls = toolCalls {
                    let openAIToolCalls = calls.map {
                        ToolCall(id: $0.id, type: "function",
                                 function: ToolCallFunction(name: $0.name, arguments: $0.argumentsString))
                    }
                    let toolChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(
                            index: 0,
                            delta: .init(role: nil, content: nil, tool_calls: openAIToolCalls),
                            finish_reason: "tool_calls"
                        )]
                    )
                    let toolLine = sseDataLine(toolChunk)
                    responseLines.append(toolLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: toolLine))
                    eventBox.append("tool_calls detected: \(calls.map(\.name).joined(separator: ", "))")
                } else {
                    // Detect truncation
                    let completionTokens = await TokenCounter.shared.count(prev)
                    var streamFinish = "stop"
                    if let maxTok = genOpts.maximumResponseTokens, completionTokens >= maxTok {
                        streamFinish = "length"
                    }
                    let stopChunk = ChatCompletionChunk(
                        id: id, object: "chat.completion.chunk", created: created, model: modelName,
                        choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil), finish_reason: streamFinish)]
                    )
                    let stopLine = sseDataLine(stopChunk)
                    responseLines.append(stopLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.yield(ByteBuffer(string: stopLine))
                }

                // Emit usage stats before [DONE] (OpenAI stream_options pattern)
                let completionTokens = await TokenCounter.shared.count(prev)
                let usageLine = "data: {\"usage\":{\"prompt_tokens\":\(promptTokens),\"completion_tokens\":\(completionTokens),\"total_tokens\":\(promptTokens + completionTokens)}}\n\n"
                responseLines.append(usageLine.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: usageLine))

                continuation.yield(ByteBuffer(string: sseDone))
                responseLines.append("data: [DONE]")
                let finishReason = toolCalls != nil ? "tool_calls" : "stop"
                eventBox.append("sent [DONE] total_chars=\(prev.count) finish_reason=\(finishReason)")
            } catch {
                let classified = ApfelError.classify(error)
                let errPayload = OpenAIErrorResponse(error: .init(
                    message: classified.openAIMessage, type: classified.openAIType, param: nil, code: nil))
                let errJSON = jsonString(errPayload, pretty: false)
                let errMsg = "data: \(errJSON)\n\n"
                responseLines.append(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
                continuation.yield(ByteBuffer(string: errMsg))
                continuation.yield(ByteBuffer(string: sseDone))
                streamError = classified.openAIMessage
                eventBox.append("stream error: \(classified.cliLabel) \(classified.openAIMessage)")
            }

            let completionLog = RequestLog(
                id: "\(id)-stream",
                timestamp: ISO8601DateFormatter().string(from: streamStart),
                method: "POST",
                path: "/v1/chat/completions/stream",
                status: streamError == nil ? 200 : 500,
                duration_ms: Int(Date().timeIntervalSince(streamStart) * 1000),
                stream: true,
                estimated_tokens: await TokenCounter.shared.count(prev),
                error: streamError,
                request_body: truncateForLog(requestBody),
                response_body: truncateForLog(responseLines.joined(separator: "\n\n")),
                events: eventBox.snapshot()
            )
            await serverState.logStore.append(completionLog)
            continuation.finish()
        }
    }

    return (
        Response(status: .ok, headers: headers, body: .init(asyncSequence: responseStream)),
        ChatRequestTrace(
            stream: true,
            estimatedTokens: promptTokens,
            error: nil,
            requestBody: truncateForLog(requestBody),
            responseBody: "Streaming response in progress. See /v1/chat/completions/stream log for final SSE transcript.",
            events: events + ["stream request accepted", "final stream completion logged separately"]
        )
    )
}

// MARK: - TraceBuffer

final class TraceBuffer: @unchecked Sendable {
    private var events: [String]
    private let lock = NSLock()

    init(events: [String]) { self.events = events }

    func append(_ event: String) {
        lock.lock(); events.append(event); lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }; return events
    }
}

private struct UnsupportedParameter {
    let name: String
    let message: String
}

private func unsupportedParameter(in request: ChatCompletionRequest) -> UnsupportedParameter? {
    if request.logprobs == true {
        return UnsupportedParameter(
            name: "logprobs",
            message: "Parameter 'logprobs' is not supported by Apple's on-device model."
        )
    }

    if let n = request.n, n != 1 {
        return UnsupportedParameter(
            name: "n",
            message: "Parameter 'n' is not supported by Apple's on-device model. Only n=1 is allowed."
        )
    }

    if request.stop != nil {
        return UnsupportedParameter(
            name: "stop",
            message: "Parameter 'stop' is not supported by Apple's on-device model."
        )
    }

    if request.presence_penalty != nil {
        return UnsupportedParameter(
            name: "presence_penalty",
            message: "Parameter 'presence_penalty' is not supported by Apple's on-device model."
        )
    }

    if request.frequency_penalty != nil {
        return UnsupportedParameter(
            name: "frequency_penalty",
            message: "Parameter 'frequency_penalty' is not supported by Apple's on-device model."
        )
    }

    return nil
}

// MARK: - Error Helper

/// Create an OpenAI-formatted error response (with CORS headers when enabled).
func openAIError(status: HTTPResponse.Status, message: String, type: String, code: String? = nil) -> Response {
    let error = OpenAIErrorResponse(error: .init(message: message, type: type, param: nil, code: code))
    let body = jsonString(error)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    if serverState?.config.cors == true {
        headers[.init("Access-Control-Allow-Origin")!] = "*"
    }
    return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(string: body)))
}
