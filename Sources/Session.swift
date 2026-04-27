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
    let maxTokens: Int?
    let seed: UInt64?
    let permissive: Bool
    let contextConfig: ContextConfig
    let retryEnabled: Bool
    let retryCount: Int

    static let defaults = SessionOptions(
        temperature: nil, maxTokens: nil, seed: nil, permissive: false,
        contextConfig: .defaults, retryEnabled: false, retryCount: 3
    )
}

// MARK: - Generation Options

func makeGenerationOptions(_ opts: SessionOptions) -> GenerationOptions {
    let sampling: GenerationOptions.SamplingMode? = opts.seed.map {
        .random(top: 50, seed: $0)
    }
    return GenerationOptions(
        sampling: sampling,
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

func sessionInputEntries(
    _ session: LanguageModelSession,
    finalPrompt: String,
    options: SessionOptions = .defaults
) -> [Transcript.Entry] {
    var entries = transcriptEntries(session.transcript)
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
        // No trimming — return all history or nil if it exceeds budget
        let all = assembleTranscriptEntries(base: baseEntries, history: historyEntries, final: finalEntry)
        return await fitsTranscriptBudget(all, budget: budget)
            ? all
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
    if stream {
        let outcome = try await withRetry(maxRetries: retryMax) {
            try await collectStream(session, prompt: prompt, printDelta: printDelta && !hasMCPTools, options: genOpts)
        }
        content = outcome.content
        finishReason = outcome.finishReason
    } else {
        // Route non-streaming through the streaming path too: same overflow
        // semantics on both paths, no second code path to maintain.
        let outcome = try await withRetry(maxRetries: retryMax) {
            try await collectStream(session, prompt: prompt, printDelta: false, options: genOpts)
        }
        content = outcome.content
        finishReason = outcome.finishReason
    }

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
            printStderr("\(styled("tool:", .red)) \(log.name) failed: \(log.result)")
        } else {
            printStderr("\(styled("tool:", .cyan)) \(log.name)(\(log.args)) = \(log.result)")
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
            resultParts.append("\(call.name): \(result)")
            toolLog.append((name: call.name, args: call.argumentsString, result: result, isError: false))
        } catch {
            if case .toolNotFound = error as? MCPError {
                let msg = "\(error)"
                resultParts.append("\(call.name): error - \(msg)")
                toolLog.append((name: call.name, args: call.argumentsString, result: msg, isError: true))
            } else {
                throw error
            }
        }
    }

    return MCPExecutionResult(toolCalls: toolCalls, resultParts: resultParts, toolLog: toolLog)
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

    let plainSession = makeSession(systemPrompt: systemPrompt)
    let toolResult = executed.resultParts.joined(separator: "\n")
    let finalContent = try await plainSession.respond(
        to: "The user asked: \(userPrompt)\n\nThe tool returned: \(toolResult)\n\nAnswer the user's question using this result.",
        options: options
    ).content
    return (content: finalContent, toolLog: executed.toolLog)
}

/// Server path: execute MCP tool calls and re-prompt with full conversation context.
/// Appends tool call/result messages to the conversation and rebuilds a session via ContextManager.
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

    let followUpMessages = appendExecutedToolResults(
        to: messages,
        toolCalls: executed.toolCalls,
        toolResults: executed.toolLog.map { ($0.name, $0.result) }
    )
    let (followUpSession, followUpPrompt) = try await ContextManager.makeSession(
        messages: followUpMessages,
        tools: nil,
        options: sessionOptions,
        jsonMode: false,
        toolChoice: nil
    )
    let finalContent = try await followUpSession.respond(to: followUpPrompt, options: options).content
    return (content: finalContent, toolLog: executed.toolLog)
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
    printDelta: Bool,
    options: GenerationOptions = GenerationOptions()
) async throws -> StreamOutcome {
    let stream = session.streamResponse(to: prompt, options: options)
    var prev = ""
    do {
        for try await snapshot in stream {
            let content = snapshot.content
            if content.count > prev.count {
                let idx = content.index(content.startIndex, offsetBy: prev.count)
                let delta = String(content[idx...])
                if printDelta {
                    print(delta, terminator: "")
                    fflush(stdout)
                }
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
