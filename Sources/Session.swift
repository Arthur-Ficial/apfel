// ============================================================================
// Session.swift — prompt processing and MCP tool execution (host side).
// Part of apfel — Apple Intelligence from the command line.
// SHARED by both CLI and server modes. Session construction, context
// trimming and stream collection moved to ApfelEngine
// (Sources/Engine/Session.swift).
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore
import ApfelEngine

// MARK: - Unified Prompt Processing (shared by singlePrompt and chat)

/// Unified prompt execution: retry + streaming/non-streaming + MCP tool execution.
/// Used by BOTH singlePrompt() and chat() - ONE code path, no duplication.
func processPrompt(
    prompt: String,
    pieces: [PromptPiece]? = nil,
    systemPrompt: String?,
    session: LanguageModelSession,
    options: SessionOptions,
    genOpts: GenerationOptions,
    stream: Bool,
    printDelta: Bool,
    mcpManager: MCPManager?,
    hasMCPTools: Bool,
    stopSequences: [String] = []
) async throws -> ProcessPromptResult {
    let retryMax = options.retryEnabled ? options.retryCount : 0
    // Image-bearing turns attach natively (macOS 27, #510); text-only turns
    // build the exact same prompt as before.
    let promptValue = makeUserPrompt(text: prompt, pieces: pieces ?? [.text(prompt)])

    debugLog("prompt", "stream=\(stream) retry=\(retryMax) mcp=\(hasMCPTools) images=\(pieces.map { p in p.reduce(0) { if case .image = $1 { return $0 + 1 } else { return $0 } } } ?? 0)")

    var content: String
    var finishReason: FinishReason = .stop
    // Print deltas only on the live streaming path with no MCP tools (tool calls
    // re-prompt and stream the final answer separately). Share ONE print sink
    // across all retry attempts: a retryable mid-stream error re-runs the stream
    // from an empty snapshot, and the sink suppresses re-emitting the already-
    // printed prefix so output appears exactly once, live, in order (#182).
    let shouldPrint = stream && printDelta && !hasMCPTools
    let printSink = shouldPrint ? StreamPrintSink() : nil
    let outcome = try await withModelRetry(maxRetries: retryMax) {
        try await collectStream(session, prompt: promptValue, sink: printSink, options: genOpts, stopSequences: stopSequences)
    }
    content = outcome.content
    finishReason = outcome.finishReason
    var truncation = outcome.truncation
    var matchedStop = outcome.matchedStop

    debugLog("response", "length=\(content.count) finish=\(finishReason)\(outcome.matchedStop.map { " stop_matched=\($0.debugDescription)" } ?? "")")

    var toolLog: [ToolLogEntry] = []
    if let result = try await executeMCPToolCallsForCLI(
        in: content, mcpManager: mcpManager, userPrompt: prompt,
        systemPrompt: systemPrompt, options: genOpts
    ) {
        content = result.content
        toolLog = result.toolLog.map { ToolLogEntry(name: $0.name, args: $0.args, result: $0.result, isError: $0.isError) }
        debugLog("mcp", "executed \(toolLog.count) tool calls")
        // After tool re-prompt the model produced a fresh natural reply.
        finishReason = .stop
        truncation = nil
        matchedStop = nil
    }

    return ProcessPromptResult(
        content: content, toolLog: toolLog, finishReason: finishReason,
        truncation: truncation, matchedStop: matchedStop)
}

/// Print tool execution log entries to stderr.
func printToolLog(_ toolLog: [ToolLogEntry]) {
    guard !quietMode else { return }
    for log in toolLog {
        if log.isError {
            printStderr("\(styledErr("tool:", .red)) \(log.name) failed: \(log.result)")
        } else {
            printStderr("\(styledErr("tool:", .cyan)) \(log.name)(\(log.args)) = \(log.result)")
        }
    }
}

// MARK: - MCP Tool Execution

/// Result of detecting and executing MCP tool calls (before re-prompting).
struct MCPExecutionResult {
    let toolCalls: [ParsedToolCall]
    let resultParts: [String]
    let toolLog: [(name: String, args: String, result: String, isError: Bool)]
    /// Corrective re-prompts (`MCPProtocol.toolRetryPrompt`) for calls
    /// rejected by schema validation (#193). Non-empty means those calls were
    /// not executed and the model should be re-prompted to retry; both paths
    /// surface these as the follow-up's final instruction, because an error
    /// inside a tool-result transcript entry alone does not make the
    /// on-device model re-emit a tool call.
    let retryInstructions: [String]
}

/// Detect and execute MCP tool calls found in model output.
/// Returns nil if no tool calls were detected or mcpManager is nil.
/// Does NOT re-prompt — callers choose their own re-prompt strategy.
func detectAndExecuteMCPTools(
    in content: String,
    mcpManager: MCPManager?
) async throws -> MCPExecutionResult? {
    guard let mcpManager,
          let toolCalls = ToolCallHandler.detectToolCall(in: content) else {
        return nil
    }
    return try await executeMCPTools(toolCalls, mcpManager: mcpManager)
}

/// Execute already-detected tool calls against the MCP manager. The server
/// path validates the calls against the request's `ToolPolicy` first (#480);
/// the CLI path feeds detection straight in.
func executeMCPTools(
    _ toolCalls: [ParsedToolCall],
    mcpManager: MCPManager
) async throws -> MCPExecutionResult {
    var resultParts: [String] = []
    var toolLog: [(name: String, args: String, result: String, isError: Bool)] = []
    var retryInstructions: [String] = []
    for call in toolCalls {
        do {
            let result = try await mcpManager.execute(name: call.name, arguments: call.argumentsString)
            if result.isError {
                // An MCP-spec `isError: true` result is a tool-execution error
                // (e.g. divide(1,0)). Feed it back to the model so it can see
                // the error and recover, instead of aborting with HTTP 500 (#220).
                resultParts.append("\(call.name): error - \(result.text)")
                toolLog.append((name: call.name, args: call.argumentsString, result: result.text, isError: true))
            } else {
                resultParts.append("\(call.name): \(result.text)")
                toolLog.append((name: call.name, args: call.argumentsString, result: result.text, isError: false))
            }
        } catch {
            switch error as? MCPError {
            // Non-fatal per-call failures: feed them back as an error result so
            // the model can retry (unknown tool, or malformed model-emitted
            // arguments (#241)) instead of aborting the whole request.
            case .toolNotFound, .invalidArguments:
                let msg = "\(error)"
                resultParts.append("\(call.name): error - \(msg)")
                toolLog.append((name: call.name, args: call.argumentsString, result: msg, isError: true))
                if case .invalidArguments = error as? MCPError,
                   let retryPrompt = await mcpManager.retryPrompt(for: call.name) {
                    retryInstructions.append(retryPrompt)
                }
            default:
                throw error
            }
        }
    }

    return MCPExecutionResult(
        toolCalls: toolCalls, resultParts: resultParts, toolLog: toolLog,
        retryInstructions: retryInstructions)
}

/// The fixed CLI follow-up prompt template with an empty tool result, used to
/// price the prompt overhead so the tool result gets the remaining token budget.
private func cliFollowUpOverhead(userPrompt: String, systemPrompt: String?) -> String {
    (systemPrompt ?? "")
        + "The user asked: \(userPrompt)\n\nThe tool returned: \n\nAnswer the user's question using this result."
}

/// Truncate a tool-result string to a token budget derived from the model's
/// context window minus the fixed prompt overhead and an output reserve, so a
/// large tool result cannot overflow the context (CLI) or be dropped whole by
/// the context trimmer while the prompt still references it (server) (#221).
func truncateToolResultToBudget(
    _ result: String,
    overhead: String,
    outputReserve: Int = 512
) async -> String {
    let inputBudget = await TokenCounter.shared.inputBudget(reservedForOutput: outputReserve)
    let overheadTokens = await TokenCounter.shared.count(overhead)
    let budget = max(0, inputBudget - overheadTokens)
    let tokens = await TokenCounter.shared.count(result)
    return ToolOutputTruncator.truncate(result, tokenCount: tokens, budgetTokens: budget).text
}

/// CLI path: execute MCP tool calls and re-prompt with a plain follow-up session.
/// No conversation history is threaded — the follow-up gets only the user prompt + tool results.
func executeMCPToolCallsForCLI(
    in content: String,
    mcpManager: MCPManager?,
    userPrompt: String,
    systemPrompt: String?,
    options: GenerationOptions
) async throws -> (content: String, toolLog: [(name: String, args: String, result: String, isError: Bool)])? {
    guard let executed = try await detectAndExecuteMCPTools(in: content, mcpManager: mcpManager) else {
        return nil
    }

    var aggregatedLog = executed.toolLog
    let plainSession = makeSession(systemPrompt: systemPrompt)
    let overhead = cliFollowUpOverhead(userPrompt: userPrompt, systemPrompt: systemPrompt)
    // Schema-rejected calls (#193): close the follow-up with the corrective
    // instead of "Answer the user's question..." - the CLI follow-up session
    // keeps the original system prompt (tool schemas + calling format), so
    // the model can re-emit the corrected call and the loop below runs it.
    func followUpInstruction(_ result: MCPExecutionResult) -> String {
        result.retryInstructions.isEmpty
            ? "Answer the user's question using this result."
            : result.retryInstructions.joined(separator: "\n")
    }
    var toolResult = await truncateToolResultToBudget(
        executed.resultParts.joined(separator: "\n"), overhead: overhead)
    var finalContent = try await plainSession.respond(
        to: "The user asked: \(userPrompt)\n\nThe tool returned: \(toolResult)\n\n\(followUpInstruction(executed))",
        options: options
    ).content

    // The re-prompt answer may itself contain another tool_calls request. If we
    // returned it verbatim that JSON would leak to the user as raw text. Run a
    // bounded re-detection loop: execute any further tool calls and re-prompt
    // again, with a hard cap so a model that keeps emitting tool_calls cannot
    // spin forever.
    var reprompts = 0
    while reprompts < ToolCallHandler.mcpRepromptCap,
          let followUp = try await detectAndExecuteMCPTools(in: finalContent, mcpManager: mcpManager) {
        reprompts += 1
        aggregatedLog.append(contentsOf: followUp.toolLog)
        toolResult = await truncateToolResultToBudget(
            followUp.resultParts.joined(separator: "\n"), overhead: overhead)
        finalContent = try await plainSession.respond(
            to: "The user asked: \(userPrompt)\n\nThe tool returned: \(toolResult)\n\n\(followUpInstruction(followUp))",
            options: options
        ).content
    }

    // Cap exhausted but the model is still emitting a tool call: fail loudly
    // instead of stripping the JSON and returning a fragment as success (#435).
    try ToolCallHandler.ensureToolLoopCompleted(in: finalContent)

    return (content: finalContent, toolLog: aggregatedLog)
}

/// Token-budget each executed tool result for a server follow-up, given the
/// prior conversation, so no single `role: "tool"` message exceeds the context
/// budget and gets dropped whole by the trimmer (#221). The returned toolLog is
/// left full elsewhere; only the prompt-bound copy is truncated.
private func truncatedServerToolResults(
    toolCalls: [ParsedToolCall],
    toolLog: [(name: String, args: String, result: String, isError: Bool)],
    priorMessages: [OpenAIMessage],
    sessionOptions: SessionOptions
) async throws -> [(name: String, result: String)] {
    // Price the follow-up exactly as ContextManager will build it (#221, #482):
    // the instructions, the originating user prompt, the tool-call entry, an
    // empty result per call and the synthetic final prompt all have to fit
    // alongside the results, because the trailing exchange is pinned. Older
    // history is trimmable and is not charged here. Joining message text used
    // to miss the tool-call entry, the final prompt and transcript framing, so
    // a result truncated to that budget still overflowed the pinned exchange.
    let instructions = priorMessages.filter { [OpenAIMessage].instructionRoles.contains($0.role) }
    let originating = priorMessages.last(where: { $0.role == "user" }).map { [$0] } ?? []
    let template = appendExecutedToolResults(
        to: instructions + originating,
        toolCalls: toolCalls,
        toolResults: toolLog.map { (name: $0.name, result: "") })
    let prepared = try await ContextManager.prepareEntries(
        messages: template, tools: nil, options: sessionOptions)
    // Same pricing the budget check applies (countInput: incl. the runtime's
    // default instructions when there is no system message, #485).
    let overheadTokens = await TokenCounter.shared.countInput(
        entries: prepared.base + prepared.history + [prepared.final])
    let inputBudget = await TokenCounter.shared.inputBudget(
        reservedForOutput: sessionOptions.contextConfig.outputReserve)
    let perResultBudget = max(0, inputBudget - overheadTokens) / max(1, toolLog.count)
    var out: [(name: String, result: String)] = []
    for entry in toolLog {
        let tokens = await TokenCounter.shared.count(entry.result)
        let text = ToolOutputTruncator.truncate(
            entry.result, tokenCount: tokens, budgetTokens: perResultBudget).text
        out.append((name: entry.name, result: text))
    }
    return out
}

/// Server path: execute MCP tool calls and re-prompt with full conversation context.
/// Appends tool call/result messages to the conversation and rebuilds a session via ContextManager.
///
/// Runs the same bounded re-detection loop as the CLI path (#240): if the model
/// answers the tool-result follow-up with another `{"tool_calls": ...}` (common
/// in tool chains), that round is executed and re-prompted, up to `maxReprompts`.
/// On cap exhaustion any trailing tool-call JSON is stripped so it never leaks to
/// the HTTP client as `message.content` with `finish_reason: "stop"`.
func executeMCPToolCallsForServer(
    firstRound: [ParsedToolCall],
    mcpManager: MCPManager?,
    userPrompt: String,
    messages: [OpenAIMessage],
    sessionOptions: SessionOptions,
    jsonMode: Bool = false
) async throws -> (content: String, toolLog: [(name: String, args: String, result: String, isError: Bool)], usage: [TokenUsage])? {
    // `firstRound` is the policy-validated call set for the model's first
    // response (#480); empty means the model answered in plain text.
    guard let mcpManager, !firstRound.isEmpty else {
        return nil
    }
    // Runtime-reported usage per follow-up model call (macOS 27+; empty on 26).
    var usageRounds: [TokenUsage] = []
    let executed = try await executeMCPTools(firstRound, mcpManager: mcpManager)

    var aggregatedLog = executed.toolLog
    var currentMessages = messages
    var currentExecuted = executed
    var finalContent = ""

    // Mirror the CLI path's bounded loop: initial re-prompt plus up to
    // mcpRepromptCap further rounds when the model keeps emitting tool calls.
    var reprompts = 0
    while true {
        let truncated = try await truncatedServerToolResults(
            toolCalls: currentExecuted.toolCalls, toolLog: currentExecuted.toolLog,
            priorMessages: currentMessages, sessionOptions: sessionOptions)
        var followUpMessages = appendExecutedToolResults(
            to: currentMessages,
            toolCalls: currentExecuted.toolCalls,
            toolResults: truncated
        )
        // Schema-rejected calls (#193): the corrective must arrive as the
        // final user prompt. Left only in the tool-result entry, the
        // synthetic "Respond to the user based on the tool result above."
        // prompt wins and the model apologizes instead of re-emitting a
        // corrected tool call.
        if !currentExecuted.retryInstructions.isEmpty {
            followUpMessages.append(OpenAIMessage(
                role: "user",
                content: .text(currentExecuted.retryInstructions.joined(separator: "\n"))
            ))
        }
        // A retry round needs the tool schemas and the tool-calling format in
        // scope again, exactly like the first round - without them the model
        // answers the arithmetic by hand (wrongly) instead of re-emitting the
        // corrected call (#193). Ordinary tool-result follow-ups keep
        // tools: nil, unchanged.
        let followUpTools: [OpenAITool]? = currentExecuted.retryInstructions.isEmpty
            ? nil : await mcpManager.allTools()
        let (followUpSession, followUpPrompt, _, followUpPieces) = try await ContextManager.makeSession(
            messages: followUpMessages,
            tools: followUpTools,
            options: sessionOptions,
            // A json_object request keeps its contract through the tool
            // round (Fable review F3: the answer came back as prose). A
            // schema-retry round still needs the tool-calling format instead.
            jsonMode: jsonMode && currentExecuted.retryInstructions.isEmpty,
            toolChoice: nil
        )
        // Follow-up options are rebuilt directive-free: the tool-result round
        // answers in plain text (or legitimately chains another call), so a
        // request-scoped tool-calling directive must not leak into it. On
        // macOS 26 this is the exact same value as the caller's options.
        let followUpResponse = try await followUpSession.respond(
            to: makeUserPrompt(text: followUpPrompt, pieces: followUpPieces),
            options: makeGenerationOptions(sessionOptions))
        finalContent = followUpResponse.content
        if let roundUsage = reportedUsage(of: followUpResponse) {
            usageRounds.append(roundUsage)
        }

        // The re-prompt answer may itself request another tool call. Execute and
        // re-prompt again with a hard cap so a model that keeps emitting
        // tool_calls cannot spin forever.
        guard reprompts < ToolCallHandler.mcpRepromptCap,
              let next = try await detectAndExecuteMCPTools(in: finalContent, mcpManager: mcpManager) else {
            break
        }
        reprompts += 1
        aggregatedLog.append(contentsOf: next.toolLog)
        currentMessages = followUpMessages
        currentExecuted = next
    }

    // Cap exhausted but the model is still emitting a tool call: fail loudly
    // instead of stripping the JSON and returning a fragment as success (#435).
    try ToolCallHandler.ensureToolLoopCompleted(in: finalContent)

    return (content: finalContent, toolLog: aggregatedLog, usage: usageRounds)
}

private func appendExecutedToolResults(
    to messages: [OpenAIMessage],
    toolCalls: [ParsedToolCall],
    toolResults: [(name: String, result: String)]
) -> [OpenAIMessage] {
    let assistantToolCalls = toolCalls.map { call in
        ToolCall(
            id: call.id,
            type: "function",
            function: ToolCallFunction(name: call.name, arguments: call.argumentsString)
        )
    }

    var followUpMessages = messages
    followUpMessages.append(OpenAIMessage(role: "assistant", content: nil, tool_calls: assistantToolCalls))
    for (call, result) in zip(toolCalls, toolResults) {
        followUpMessages.append(
            OpenAIMessage(
                role: "tool",
                content: .text(result.result),
                tool_call_id: call.id,
                name: result.name
            )
        )
    }
    return followUpMessages
}
