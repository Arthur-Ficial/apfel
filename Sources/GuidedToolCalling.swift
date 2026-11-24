// ============================================================================
// GuidedToolCalling.swift - runs the guided tool step (#533) for
// /v1/chat/completions requests with client tools.
//
// The decision is generated under a JSON schema (GuidedToolStep in
// ApfelCore): {"action": <tool name or "answer">, "arguments": {<tool>: {...}}}.
// A tool call goes back to the client as an ordinary OpenAI `tool_calls`
// response; when the step left the chosen tool's arguments out or they break
// its schema, one more guided request in the same session writes them under
// the tool's own schema. An "answer" is written by the normal text path in a
// fresh session without tool instructions, so the reply streams as usual.
// Out-of-band execution is unchanged (#119): apfel never runs client tools.
// ============================================================================

import Foundation
import FoundationModels
import Hummingbird
import ApfelCore
import ApfelEngine

/// What the guided step decided, with the tokens it used.
enum GuidedToolOutcome: Sendable {
    case call(ParsedToolCall, usage: TokenUsage)
    case answer(usage: TokenUsage)
}

/// A model error during the guided step: the failed round's counted input
/// and the usage of any round that completed before it, so a refusal is
/// reported with honest token counts.
struct GuidedToolStepFailure: Error {
    let underlying: any Error
    let promptTokens: Int
    let completedUsage: TokenUsage?
}

/// Build the guided step and its generation schema for the tools in scope.
/// Shared by every path that runs the step (#590): chat completions with
/// client tools, server `--mcp` auto-execution, `/v1/responses` function
/// tools, and the CLI `--mcp` path.
/// - Throws: `GuidedToolStep.Unavailable` or a schema-conversion error when
///   guided generation cannot express a tool; callers fall back to the
///   free-text format.
func prepareGuidedToolStep(
    tools: [OpenAITool], mode: ToolPolicy.Mode
) throws -> (step: GuidedToolStep, schema: GenerationSchema) {
    let step = try GuidedToolStep(
        tools: tools.map {
            ToolDef(name: $0.function.name, description: $0.function.description,
                    parametersJSON: $0.function.parameters?.value)
        },
        mode: mode)
    return (step, try SchemaConverter.generationSchema(fromJSON: step.schemaJSON, name: "tool_step"))
}

/// True when a failed guided step should fall back to the free-text format
/// (#590 item 2): the step schema and its tool list cost tokens the free-text
/// format does not, so an input-side overflow of the step is not final.
func guidedStepFallsBackToFreeText(_ classified: ApfelError) -> Bool {
    switch classified {
    case .contextOverflow, .contextWindowExceeded: return true
    default: return false
    }
}

/// Generate the guided step for one request and resolve it to a call or an
/// answer. Model errors propagate to the caller unchanged.
func runGuidedToolStep(
    _ step: GuidedToolStep,
    stepSchema: GenerationSchema,
    messages: [OpenAIMessage],
    tools: [OpenAITool],
    toolChoice: ToolChoice?,
    options: SessionOptions,
    events: inout [String]
) async throws -> GuidedToolOutcome {
    let (session, finalPrompt, entries, pieces) = try await ContextManager.makeSession(
        messages: messages, tools: tools, options: options, jsonMode: false,
        toolChoice: toolChoice, responseSchema: stepSchema, toolInstructions: step.instructions)
    // The step is an internal decision of a few tokens plus the arguments:
    // the client's max_tokens caps the visible answer, not the step.
    let stepOptions = SessionOptions(
        temperature: options.temperature, topP: options.topP, maxTokens: nil, seed: options.seed,
        permissive: options.permissive, contextConfig: options.contextConfig,
        retryEnabled: options.retryEnabled, retryCount: options.retryCount)
    let genOpts = makeGenerationOptions(stepOptions)
    let retryMax = options.retryEnabled ? options.retryCount : 0
    let prompt = makeUserPrompt(text: finalPrompt, pieces: pieces)
    let renderer = StructuredJSONRenderer(schemaJSON: step.schemaJSON, name: "tool_step")
    // macOS 26 counts what the runtime sees: the built entries plus the final
    // prompt carrying the step schema as its response format (#485).
    @Sendable func stepInputTokens() async -> Int {
        let finalEntry = hasImagePiece(pieces)
            ? makePromptEntry(pieces: pieces, options: options, responseSchema: stepSchema)
            : makePromptEntry(finalPrompt, options: options, responseSchema: stepSchema)
        return await TokenCounter.shared.countInput(entries: entries + [finalEntry])
    }

    let first: (json: String, usage: TokenUsage?)
    do {
        first = try await withModelRetry(maxRetries: retryMax) { () -> (json: String, usage: TokenUsage?) in
            let result = try await session.respond(to: prompt, schema: stepSchema, options: genOpts)
            return (renderer.finalJSON(result.content), reportedUsage(of: result))
        }
    } catch {
        // A refusal (or any failure) is reported with the step's real input
        // size, so the client's usage stays honest.
        throw GuidedToolStepFailure(
            underlying: error, promptTokens: await stepInputTokens(), completedUsage: nil)
    }
    var usage: TokenUsage
    if let reported = first.usage {
        usage = reported
    } else {
        usage = TokenUsage(
            promptTokens: await stepInputTokens(),
            completionTokens: await TokenCounter.shared.count(first.json))
    }
    events.append("guided tool step: \(first.json.prefix(300))")

    guard let decision = step.parse(first.json) else {
        throw ApfelError.unknown("The guided tool step returned an unreadable decision: \(first.json.prefix(200))")
    }
    guard case .call(let name, let stepArguments) = decision else {
        return .answer(usage: usage)
    }

    let schema = tools.first { $0.function.name == name }?.function.parameters?.value
    var arguments = stepArguments
    if let current = arguments, !argumentsMatch(name: name, arguments: current, schema: schema) {
        arguments = nil
    }
    if arguments == nil, let request = step.argumentsRequest(for: name) {
        // The step chose the tool but left its arguments out or broke them:
        // write them under the tool's own schema in the same session.
        let argumentSchema = try SchemaConverter.generationSchema(fromJSON: request.schemaJSON, name: name)
        let argumentRenderer = StructuredJSONRenderer(schemaJSON: request.schemaJSON, name: name)
        // Same convention as the repair round: the step's output and the
        // follow-up prompt (with its schema) are the second round's added input.
        let followUpInput = await TokenCounter.shared.count(first.json)
            + TokenCounter.shared.countInput(entries: [
                makePromptEntry(request.prompt, options: options, responseSchema: argumentSchema)])
        let second: (json: String, usage: TokenUsage?)
        do {
            second = try await withModelRetry(maxRetries: retryMax) { () -> (json: String, usage: TokenUsage?) in
                let result = try await session.respond(to: request.prompt, schema: argumentSchema, options: genOpts)
                return (argumentRenderer.finalJSON(result.content), reportedUsage(of: result))
            }
        } catch {
            throw GuidedToolStepFailure(underlying: error, promptTokens: followUpInput, completedUsage: usage)
        }
        if let reported = second.usage {
            usage = usage.adding(reported)
        } else {
            usage = usage.adding(TokenUsage(
                promptTokens: followUpInput,
                completionTokens: await TokenCounter.shared.count(second.json)))
        }
        events.append("guided arguments request: \(name)")
        arguments = second.json
    }
    let call = ParsedToolCall(
        id: "call_\(UUID().uuidString.prefix(8).lowercased())", name: name,
        argumentsString: arguments ?? "{}")
    return .call(call, usage: usage)
}

/// True when `arguments` satisfy the tool's declared schema (required keys
/// present, no undeclared keys under `additionalProperties: false`).
private func argumentsMatch(name: String, arguments: String, schema: String?) -> Bool {
    do {
        try MCPProtocol.validateToolArguments(name: name, arguments: arguments, inputSchemaJSON: schema)
        return true
    } catch {
        return false
    }
}

/// The OpenAI response for a call made by the guided step: the same wire
/// shape as a detected free-text call (non-streaming message, or role chunk,
/// tool_calls chunk, separate finish chunk, optional usage chunk, [DONE]).
func guidedToolCallResponse(
    _ call: ParsedToolCall,
    usage: TokenUsage,
    stream: Bool,
    includeUsage: Bool,
    id: String,
    created: Int,
    model: String,
    requestBody: String?,
    events: [String]
) -> (response: Response, trace: ChatRequestTrace) {
    let finishReason = FinishReason.toolCalls.openAIValue
    let toolCall = ToolCall(id: call.id, type: "function",
                            function: ToolCallFunction(name: call.name, arguments: call.argumentsString))
    let traceEvents = events + ["tool_calls: \(call.name)", "finish_reason=\(finishReason)"]
    if stream {
        var chunks: [String] = [
            sseDataLine(sseRoleChunk(id: id, created: created, model: model, includeUsage: includeUsage)),
            sseDataLine(ChatCompletionChunk(
                id: id, object: "chat.completion.chunk", created: created, model: model,
                choices: [.init(
                    index: 0,
                    delta: .init(role: nil, content: nil, tool_calls: [
                        ChatCompletionChunk.ToolCallDelta(index: 0, id: toolCall.id, type: toolCall.type, function: toolCall.function),
                    ]),
                    finish_reason: nil, logprobs: nil)],
                usage: nil, includeUsageNull: includeUsage)),
            sseDataLine(ChatCompletionChunk(
                id: id, object: "chat.completion.chunk", created: created, model: model,
                choices: [.init(index: 0, delta: .init(role: nil, content: nil, tool_calls: nil),
                                finish_reason: finishReason, logprobs: nil)],
                usage: nil, includeUsageNull: includeUsage)),
        ]
        if includeUsage {
            chunks.append(sseDataLine(sseUsageChunk(
                id: id, created: created, model: model, promptTokens: usage.promptTokens, completionTokens: usage.completionTokens)))
        }
        chunks.append(sseDone)
        let body = chunks.joined()
        let response = Response(status: .ok, headers: eventStreamHeaders(),
                                body: .init(byteBuffer: ByteBuffer(string: body)))
        return (response, ChatRequestTrace(
            stream: true, estimatedTokens: usage.totalTokens, error: nil, requestBody: requestBody,
            responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug), events: traceEvents))
    }
    let payload = ChatCompletionResponse(
        id: id, object: "chat.completion", created: created, model: model,
        choices: [.init(index: 0, message: OpenAIMessage(role: "assistant", content: nil, tool_calls: [toolCall]),
                        finish_reason: finishReason, logprobs: nil)],
        usage: .init(prompt_tokens: usage.promptTokens, completion_tokens: usage.completionTokens,
                     total_tokens: usage.totalTokens))
    let body = jsonString(payload)
    return (jsonResponse(body), ChatRequestTrace(
        stream: false, estimatedTokens: usage.totalTokens, error: nil, requestBody: requestBody,
        responseBody: captureTruncatedLogBody(body, enabled: serverState.config.debug), events: traceEvents))
}
