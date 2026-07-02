// ============================================================================
// Session.swift — FoundationModels session management and streaming
// Part of apfel — Apple Intelligence from the command line
// SHARED by both CLI and server modes.
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore

// MARK: - Session Options

/// Options forwarded from CLI flags or OpenAI request parameters.
struct SessionOptions: Sendable {
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?
    let seed: UInt64?
    let permissive: Bool
    let contextConfig: ContextConfig
    let retryEnabled: Bool
    let retryCount: Int

    static let defaults = SessionOptions(
        temperature: nil, topP: nil, maxTokens: nil, seed: nil, permissive: false,
        contextConfig: .defaults, retryEnabled: false, retryCount: 3
    )
}

// MARK: - Generation Options

/// Translate the pure `SamplingDecision` into the SDK's sampling mode.
func makeSamplingMode(_ decision: SamplingDecision) -> GenerationOptions.SamplingMode? {
    switch decision {
    case .greedy:
        return .greedy
    case let .nucleus(probabilityThreshold, seed):
        return .random(probabilityThreshold: probabilityThreshold, seed: seed)
    case let .topK(top, seed):
        return .random(top: top, seed: seed)
    case .defaultMode:
        return nil
    }
}

func makeGenerationOptions(_ opts: SessionOptions) -> GenerationOptions {
    let decision = SamplingDecision.resolve(
        temperature: opts.temperature,
        topP: opts.topP,
        seed: opts.seed
    )
    return GenerationOptions(
        sampling: makeSamplingMode(decision),
        temperature: opts.temperature,
        maximumResponseTokens: opts.maxTokens
    )
}

// MARK: - Model Selection

func makeModel(permissive: Bool) -> SystemLanguageModel {
    SystemLanguageModel(
        guardrails: permissive ? .permissiveContentTransformations : .default
    )
}

// MARK: - Simple Session (CLI use)

/// Create a LanguageModelSession with optional system instructions for CLI use.
/// Uses Transcript.Instructions so streaming and non-streaming read the same source.
func makeSession(systemPrompt: String?, options: SessionOptions = .defaults) -> LanguageModelSession {
    let model = makeModel(permissive: options.permissive)
    guard let systemPrompt, !systemPrompt.isEmpty else {
        return LanguageModelSession(model: model)
    }
    let segment = Transcript.TextSegment(content: systemPrompt)
    let instructions = Transcript.Instructions(segments: [.text(segment)], toolDefinitions: [])
    return makeTranscriptSession(model: model, entries: [.instructions(instructions)])
}

func makePromptEntry(_ prompt: String, options: SessionOptions = .defaults) -> Transcript.Entry {
    let segment = Transcript.TextSegment(content: prompt)
    let prompt = Transcript.Prompt(
        segments: [.text(segment)],
        options: makeGenerationOptions(options)
    )
    return .prompt(prompt)
}

func makeTranscriptSession(model: SystemLanguageModel, entries: [Transcript.Entry]) -> LanguageModelSession {
    guard !entries.isEmpty else {
        return LanguageModelSession(model: model)
    }
    return LanguageModelSession(model: model, transcript: Transcript(entries: entries))
}

func transcriptEntries(_ transcript: Transcript) -> [Transcript.Entry] {
    Array(transcript)
}

/// Assemble the full prompt-token accounting input from the entries
/// ContextManager actually built (which retain native tool definitions) plus
/// the final prompt sent via respond(). Reading the entries back from
/// `session.transcript` instead drops `Instructions.toolDefinitions`, which
/// undercounts prompt tokens for tool-augmented requests (#176).
func sessionInputEntries(
    builtEntries: [Transcript.Entry],
    finalPrompt: String,
    options: SessionOptions = .defaults
) -> [Transcript.Entry] {
    var entries = builtEntries
    entries.append(makePromptEntry(finalPrompt, options: options))
    return entries
}

func assembleTranscriptEntries<BaseEntries: Collection, HistoryEntries: Collection>(
    base: BaseEntries,
    history: HistoryEntries,
    final: Transcript.Entry? = nil
) -> [Transcript.Entry]
where BaseEntries.Element == Transcript.Entry, HistoryEntries.Element == Transcript.Entry {
    var entries: [Transcript.Entry] = []
    entries.reserveCapacity(base.count + history.count + (final == nil ? 0 : 1))
    entries.append(contentsOf: base)
    entries.append(contentsOf: history)
    if let final {
        entries.append(final)
    }
    return entries
}

func fitsTranscriptBudget(
    _ entries: [Transcript.Entry],
    budget: Int
) async -> Bool {
    await TokenCounter.shared.count(entries: entries) <= budget
}

func fitsTranscriptBudget(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry? = nil,
    budget: Int
) async -> Bool {
    await fitsTranscriptBudget(
        assembleTranscriptEntries(base: base, history: history, final: final),
        budget: budget
    )
}

func fitsTranscriptBudget<BaseEntries: Collection, HistoryEntries: Collection>(
    base: BaseEntries,
    history: HistoryEntries,
    final: Transcript.Entry? = nil,
    budget: Int
) async -> Bool
where BaseEntries.Element == Transcript.Entry, HistoryEntries.Element == Transcript.Entry {
    await fitsTranscriptBudget(
        assembleTranscriptEntries(base: base, history: history, final: final),
        budget: budget
    )
}

func trimHistoryEntriesToBudget(
    baseEntries: [Transcript.Entry],
    historyEntries: [Transcript.Entry],
    finalEntry: Transcript.Entry? = nil,
    budget: Int,
    config: ContextConfig = .defaults
) async -> [Transcript.Entry]? {
    let requiredEntries = assembleTranscriptEntries(base: baseEntries, history: [], final: finalEntry)
    guard await fitsTranscriptBudget(requiredEntries, budget: budget) else {
        return nil
    }

    switch config.strategy {
    case .newestFirst:
        return await trimNewestFirst(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget)
    case .oldestFirst:
        return await trimOldestFirst(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget)
    case .slidingWindow:
        return await trimSlidingWindow(
            base: baseEntries, history: historyEntries, final: finalEntry,
            budget: budget, maxTurns: config.maxTurns)
    case .summarize:
        return await trimWithSummary(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget,
            permissive: config.permissive)
    case .strict:
        // No trimming — return all history or nil if it exceeds budget.
        // The final entry is included for the budget CHECK only; like every
        // other strategy the returned entries must NOT contain it, because
        // callers send the final prompt separately via respond(). Including
        // it here made the model see the prompt twice and double-counted it
        // in prompt_tokens.
        let all = assembleTranscriptEntries(base: baseEntries, history: historyEntries, final: finalEntry)
        return await fitsTranscriptBudget(all, budget: budget)
            ? assembleTranscriptEntries(base: baseEntries, history: historyEntries)
            : nil
    }
}

// MARK: - Strategy: Newest First (default)

func trimNewestFirst(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int
) async -> [Transcript.Entry] {
    let keepCount = await maxNewestHistoryCountThatFits(
        base: base,
        history: history,
        final: final,
        budget: budget
    )
    return assembleTranscriptEntries(base: base, history: history.suffix(keepCount))
}

// MARK: - Strategy: Oldest First

func trimOldestFirst(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int
) async -> [Transcript.Entry] {
    let keepCount = await maxOldestHistoryCountThatFits(
        base: base,
        history: history,
        final: final,
        budget: budget
    )
    return assembleTranscriptEntries(base: base, history: history.prefix(keepCount))
}

// MARK: - Strategy: Sliding Window

func trimSlidingWindow(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int, maxTurns: Int?
) async -> [Transcript.Entry] {
    let windowSize = min(maxTurns ?? Int.max, history.count)
    let windowed = Array(history.suffix(windowSize))
    // Apply token-budget safety net (drop from front if over budget)
    return await trimNewestFirst(
        base: base, history: windowed, final: final, budget: budget)
}

// MARK: - Unified Prompt Processing (shared by singlePrompt and chat)

/// Unified prompt execution: retry + streaming/non-streaming + MCP tool execution.
/// Used by BOTH singlePrompt() and chat() - ONE code path, no duplication.
func processPrompt(
    prompt: String,
    systemPrompt: String?,
    session: LanguageModelSession,
    options: SessionOptions,
    genOpts: GenerationOptions,
    stream: Bool,
    printDelta: Bool,
    mcpManager: MCPManager?,
    hasMCPTools: Bool
) async throws -> ProcessPromptResult {
    let retryMax = options.retryEnabled ? options.retryCount : 0

    debugLog("prompt", "stream=\(stream) retry=\(retryMax) mcp=\(hasMCPTools)")

    var content: String
    var finishReason: FinishReason = .stop
    // Print deltas only on the live streaming path with no MCP tools (tool calls
    // re-prompt and stream the final answer separately). Share ONE print sink
    // across all retry attempts: a retryable mid-stream error re-runs the stream
    // from an empty snapshot, and the sink suppresses re-emitting the already-
    // printed prefix so output appears exactly once, live, in order (#182).
    let shouldPrint = stream && printDelta && !hasMCPTools
    let printSink = shouldPrint ? StreamPrintSink() : nil
    let outcome = try await withRetry(maxRetries: retryMax) {
        try await collectStream(session, prompt: prompt, sink: printSink, options: genOpts)
    }
    content = outcome.content
    finishReason = outcome.finishReason

    debugLog("response", "length=\(content.count) finish=\(finishReason)")

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
    }

    return ProcessPromptResult(content: content, toolLog: toolLog, finishReason: finishReason)
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

    var resultParts: [String] = []
    var toolLog: [(name: String, args: String, result: String, isError: Bool)] = []
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
            default:
                throw error
            }
        }
    }

    return MCPExecutionResult(toolCalls: toolCalls, resultParts: resultParts, toolLog: toolLog)
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
    var toolResult = await truncateToolResultToBudget(
        executed.resultParts.joined(separator: "\n"), overhead: overhead)
    var finalContent = try await plainSession.respond(
        to: "The user asked: \(userPrompt)\n\nThe tool returned: \(toolResult)\n\nAnswer the user's question using this result.",
        options: options
    ).content

    // The re-prompt answer may itself contain another tool_calls request. If we
    // returned it verbatim that JSON would leak to the user as raw text. Run a
    // bounded re-detection loop: execute any further tool calls and re-prompt
    // again, with a hard cap so a model that keeps emitting tool_calls cannot
    // spin forever. On cap exhaustion we strip the trailing tool-call JSON so no
    // raw protocol text leaks.
    let maxReprompts = 3
    var reprompts = 0
    while reprompts < maxReprompts,
          let followUp = try await detectAndExecuteMCPTools(in: finalContent, mcpManager: mcpManager) {
        reprompts += 1
        aggregatedLog.append(contentsOf: followUp.toolLog)
        toolResult = await truncateToolResultToBudget(
            followUp.resultParts.joined(separator: "\n"), overhead: overhead)
        finalContent = try await plainSession.respond(
            to: "The user asked: \(userPrompt)\n\nThe tool returned: \(toolResult)\n\nAnswer the user's question using this result.",
            options: options
        ).content
    }

    // Cap exhausted but the model is still emitting a tool call: strip the raw
    // JSON so it never reaches the user as text.
    if ToolCallHandler.detectToolCall(in: finalContent) != nil {
        finalContent = stripToolCallJSON(from: finalContent)
    }

    return (content: finalContent, toolLog: aggregatedLog)
}

/// Remove a trailing `{"tool_calls": ...}` JSON block from model output so it
/// never leaks to the user as raw protocol text. Mirrors the string-aware
/// balanced-brace scan in `ToolCallHandler.extractCandidates`. If no balanced
/// block is found, the original text (trimmed) is returned unchanged.
func stripToolCallJSON(from text: String) -> String {
    guard let range = text.range(of: "{\"tool_calls\"") else {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var depth = 0
    var inString = false
    var escaped = false
    var idx = range.lowerBound
    while idx < text.endIndex {
        let ch = text[idx]
        if inString {
            if escaped { escaped = false }
            else if ch == "\\" { escaped = true }
            else if ch == "\"" { inString = false }
        } else if ch == "\"" {
            inString = true
        } else if ch == "{" {
            depth += 1
        } else if ch == "}" {
            depth -= 1
            if depth == 0 {
                let before = String(text[text.startIndex..<range.lowerBound])
                let after = String(text[text.index(after: idx)...])
                return (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        idx = text.index(after: idx)
    }
    // No balanced close — drop everything from the marker onward.
    return String(text[text.startIndex..<range.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Token-budget each executed tool result for a server follow-up, given the
/// prior conversation, so no single `role: "tool"` message exceeds the context
/// budget and gets dropped whole by the trimmer (#221). The returned toolLog is
/// left full elsewhere; only the prompt-bound copy is truncated.
private func truncatedServerToolResults(
    toolLog: [(name: String, args: String, result: String, isError: Bool)],
    priorMessages: [OpenAIMessage]
) async -> [(name: String, result: String)] {
    let inputBudget = await TokenCounter.shared.inputBudget(reservedForOutput: 512)
    let conversationText = priorMessages.compactMap { $0.textContent }.joined(separator: "\n")
    let overheadTokens = await TokenCounter.shared.count(conversationText)
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
    in content: String,
    mcpManager: MCPManager?,
    userPrompt: String,
    messages: [OpenAIMessage],
    sessionOptions: SessionOptions,
    options: GenerationOptions
) async throws -> (content: String, toolLog: [(name: String, args: String, result: String, isError: Bool)])? {
    guard let executed = try await detectAndExecuteMCPTools(in: content, mcpManager: mcpManager) else {
        return nil
    }

    var aggregatedLog = executed.toolLog
    var currentMessages = messages
    var currentExecuted = executed
    var finalContent = ""

    // Mirror the CLI path's bounded loop: initial re-prompt plus up to
    // maxReprompts further rounds when the model keeps emitting tool calls.
    let maxReprompts = 3
    var reprompts = 0
    while true {
        let truncated = await truncatedServerToolResults(
            toolLog: currentExecuted.toolLog, priorMessages: currentMessages)
        let followUpMessages = appendExecutedToolResults(
            to: currentMessages,
            toolCalls: currentExecuted.toolCalls,
            toolResults: truncated
        )
        let (followUpSession, followUpPrompt, _) = try await ContextManager.makeSession(
            messages: followUpMessages,
            tools: nil,
            options: sessionOptions,
            jsonMode: false,
            toolChoice: nil
        )
        finalContent = try await followUpSession.respond(to: followUpPrompt, options: options).content

        // The re-prompt answer may itself request another tool call. Execute and
        // re-prompt again with a hard cap so a model that keeps emitting
        // tool_calls cannot spin forever.
        guard reprompts < maxReprompts,
              let next = try await detectAndExecuteMCPTools(in: finalContent, mcpManager: mcpManager) else {
            break
        }
        reprompts += 1
        aggregatedLog.append(contentsOf: next.toolLog)
        currentMessages = followUpMessages
        currentExecuted = next
    }

    // Cap exhausted but the model is still emitting a tool call: strip the raw
    // JSON so it never reaches the client as content with finish_reason stop.
    if ToolCallHandler.detectToolCall(in: finalContent) != nil {
        finalContent = stripToolCallJSON(from: finalContent)
    }

    return (content: finalContent, toolLog: aggregatedLog)
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

// MARK: - Streaming Helper

/// Stream a response, optionally printing deltas to stdout.
/// FoundationModels returns cumulative snapshots; we compute deltas by tracking prev length.
///
/// Resolves `finishReason` two ways:
///   - Natural stream completion: `.length` if `completionTokens >= maxTokens`,
///     else `.stop`. Tool-call detection happens at higher layers.
///   - Output-side context overflow (model ran into the 4096-token ceiling
///     after producing content): graceful `.length`. Prompt-side overflow
///     (no content produced before the throw) still throws.
///
/// - Returns: A `StreamOutcome` carrying the accumulated content and the
///   resolved finish reason.
func collectStream(
    _ session: LanguageModelSession,
    prompt: String,
    sink: StreamPrintSink? = nil,
    options: GenerationOptions = GenerationOptions()
) async throws -> StreamOutcome {
    let stream = session.streamResponse(to: prompt, options: options)
    var prev = ""
    do {
        for try await snapshot in stream {
            let content = snapshot.content
            // Feed the cumulative snapshot to the (optional) print sink. The sink
            // tracks a high-water mark across retries and emits only the suffix
            // beyond what it has already printed, so a retried re-run never
            // reprints the already-streamed prefix (#182).
            if let sink {
                await sink.feed(cumulative: content)
            }
            prev = content
        }
        let completionTokens = await TokenCounter.shared.count(prev)
        let reason = FinishReasonResolver.resolve(
            hasToolCalls: false,
            completionTokens: completionTokens,
            maxTokens: options.maximumResponseTokens
        )
        return StreamOutcome(content: prev, finishReason: reason)
    } catch {
        let classified = ApfelError.classify(error)
        switch StreamErrorResolver.resolve(prev: prev, error: classified) {
        case .truncated(let content):
            return StreamOutcome(content: content, finishReason: .length)
        case .fatal(let err):
            throw err
        }
    }
}

func maxNewestHistoryCountThatFits(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry?,
    budget: Int
) async -> Int {
    guard !history.isEmpty else { return 0 }

    var low = 0
    var high = history.count
    while low < high {
        let mid = (low + high + 1) / 2
        let candidate = history.suffix(mid)
        if await fitsTranscriptBudget(base: base, history: candidate, final: final, budget: budget) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    return low
}

private func maxOldestHistoryCountThatFits(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry?,
    budget: Int
) async -> Int {
    guard !history.isEmpty else { return 0 }

    var low = 0
    var high = history.count
    while low < high {
        let mid = (low + high + 1) / 2
        let candidate = history.prefix(mid)
        if await fitsTranscriptBudget(base: base, history: candidate, final: final, budget: budget) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    return low
}
