// ============================================================================
// Session.swift — FoundationModels session construction, context trimming
// and stream collection. Part of ApfelEngine — SHARED by the CLI, the HTTP
// server and the SwiftUI chat app. The host-specific half (prompt processing
// with MCP tool execution and stderr printing) stays in the main target
// (Sources/Session.swift).
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore

// MARK: - Session Options

/// Options forwarded from CLI flags or OpenAI request parameters.
public struct SessionOptions: Sendable {
    public let temperature: Double?
    public let topP: Double?
    public let maxTokens: Int?
    public let seed: UInt64?
    public let permissive: Bool
    public let contextConfig: ContextConfig
    public let retryEnabled: Bool
    public let retryCount: Int

    public init(
        temperature: Double?, topP: Double?, maxTokens: Int?, seed: UInt64?,
        permissive: Bool, contextConfig: ContextConfig,
        retryEnabled: Bool, retryCount: Int
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.seed = seed
        self.permissive = permissive
        self.contextConfig = contextConfig
        self.retryEnabled = retryEnabled
        self.retryCount = retryCount
    }

    public static let defaults = SessionOptions(
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

/// Build the SDK generation options for one request.
///
/// `init(samplingMode:)` replaced the deprecated `init(sampling:)` in the
/// macOS 27 SDK and is back-deployed to macOS 26 (`@backDeployed(before:
/// macOS 27)`, forwarding to `init(sampling:)`), so one unconditional call
/// maps the sampling decision identically on both OSes - no #available
/// split, no deprecation warning (#510 item 5).
///
/// `toolCalling` is macOS 27's runtime-side tool_choice (#510 item 3): the
/// resolved directive is applied under #available(macOS 27, *) and ignored
/// on macOS 26 (see ToolCallingSupport.swift). Tool-free requests pass nil
/// and get byte-identical options to before.
public func makeGenerationOptions(
    _ opts: SessionOptions,
    toolCalling directive: ToolCallingDirective? = nil
) -> GenerationOptions {
    let decision = SamplingDecision.resolve(
        temperature: opts.temperature,
        topP: opts.topP,
        seed: opts.seed
    )
    var options = GenerationOptions(
        samplingMode: makeSamplingMode(decision),
        temperature: opts.temperature,
        maximumResponseTokens: opts.maxTokens
    )
    applyToolCallingDirective(directive, to: &options)
    return options
}

// MARK: - Model Selection

public func makeModel(permissive: Bool) -> SystemLanguageModel {
    SystemLanguageModel(
        guardrails: permissive ? .permissiveContentTransformations : .default
    )
}

// MARK: - Simple Session (CLI use)

/// Create a LanguageModelSession with optional system instructions for CLI use.
/// Uses Transcript.Instructions so streaming and non-streaming read the same source.
public func makeSession(systemPrompt: String?, options: SessionOptions = .defaults) -> LanguageModelSession {
    let model = makeModel(permissive: options.permissive)
    guard let systemPrompt, !systemPrompt.isEmpty else {
        return LanguageModelSession(model: model)
    }
    let segment = Transcript.TextSegment(content: systemPrompt)
    let instructions = Transcript.Instructions(segments: [.text(segment)], toolDefinitions: [])
    return makeTranscriptSession(model: model, entries: [.instructions(instructions)])
}

public func makePromptEntry(_ prompt: String, options: SessionOptions = .defaults) -> Transcript.Entry {
    let segment = Transcript.TextSegment(content: prompt)
    let prompt = Transcript.Prompt(
        segments: [.text(segment)],
        options: makeGenerationOptions(options)
    )
    return .prompt(prompt)
}

/// Prompt entry for a user turn with ordered text/image pieces (#510).
/// Text-only pieces produce the same entry as `makePromptEntry(_:options:)`;
/// images become native attachment segments (macOS 27, see VisionSupport).
public func makePromptEntry(pieces: [PromptPiece], options: SessionOptions = .defaults) -> Transcript.Entry {
    .prompt(Transcript.Prompt(
        segments: promptSegments(pieces: pieces),
        options: makeGenerationOptions(options)
    ))
}

public func makeTranscriptSession(model: SystemLanguageModel, entries: [Transcript.Entry]) -> LanguageModelSession {
    guard !entries.isEmpty else {
        return LanguageModelSession(model: model)
    }
    return LanguageModelSession(model: model, transcript: Transcript(entries: entries))
}

public func transcriptEntries(_ transcript: Transcript) -> [Transcript.Entry] {
    Array(transcript)
}

/// Assemble the full prompt-token accounting input from the entries
/// ContextManager actually built (which retain native tool definitions) plus
/// the final prompt sent via respond(). Reading the entries back from
/// `session.transcript` instead drops `Instructions.toolDefinitions`, which
/// undercounts prompt tokens for tool-augmented requests (#176).
public func sessionInputEntries(
    builtEntries: [Transcript.Entry],
    finalPrompt: String,
    options: SessionOptions = .defaults,
    finalPieces: [PromptPiece]? = nil
) -> [Transcript.Entry] {
    var entries = builtEntries
    // An image-bearing final turn is accounted as the entry actually sent
    // (text + attachment segments, #510); the text-only path is unchanged.
    if let finalPieces, hasImagePiece(finalPieces) {
        entries.append(makePromptEntry(pieces: finalPieces, options: options))
    } else {
        entries.append(makePromptEntry(finalPrompt, options: options))
    }
    return entries
}

public func assembleTranscriptEntries<BaseEntries: Collection, HistoryEntries: Collection>(
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

public func fitsTranscriptBudget(
    _ entries: [Transcript.Entry],
    budget: Int
) async -> Bool {
    await TokenCounter.shared.count(entries: entries) <= budget
}

public func fitsTranscriptBudget(
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

public func fitsTranscriptBudget<BaseEntries: Collection, HistoryEntries: Collection>(
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

// MARK: - Tool exchange groups (#482)

/// Indivisible index ranges into `history`: an assistant tool-call entry stays
/// with the tool outputs that answer it, so no trimming boundary can hand the
/// model an orphaned call or an unexplained result (#482). Everything else is
/// one group per entry, so tool-free history trims exactly as before.
func historyGroups(_ history: [Transcript.Entry]) -> [Range<Int>] {
    ToolExchangeGrouping.groups(history.map(historyItem))
}

private func historyItem(_ entry: Transcript.Entry) -> HistoryItem {
    switch entry {
    case .prompt:
        return .prompt
    case .toolCalls(let calls):
        return .toolCalls(ids: calls.map(\.id))
    case .toolOutput(let output):
        return .toolOutput(id: output.id)
    default:
        return .response
    }
}

/// The entries of `history` covered by `ranges`, in order.
func selectEntries(_ history: [Transcript.Entry], in ranges: [Range<Int>]) -> [Transcript.Entry] {
    ranges.flatMap { history[$0] }
}

/// The budget predicate group-aware selection drives: does base + the
/// selected history + the final prompt fit?
func budgetPredicate(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int
) -> ([Range<Int>]) async -> Bool {
    { ranges in
        await fitsTranscriptBudget(
            base: base, history: selectEntries(history, in: ranges), final: final, budget: budget)
    }
}

public func trimHistoryEntriesToBudget(
    baseEntries: [Transcript.Entry],
    historyEntries: [Transcript.Entry],
    finalEntry: Transcript.Entry? = nil,
    budget: Int,
    config: ContextConfig = .defaults,
    pinLast: Bool = false
) async -> [Transcript.Entry]? {
    // A trailing tool result is only answerable together with the call that
    // produced it: pin that last exchange and price it as required, so a
    // group too large for the window fails as context overflow instead of
    // being silently dropped (#482).
    let groups = historyGroups(historyEntries)
    let pin = pinLast && !groups.isEmpty
    let pinnedEntries = pin ? Array(historyEntries[groups[groups.count - 1]]) : []
    let requiredEntries = assembleTranscriptEntries(base: baseEntries, history: pinnedEntries, final: finalEntry)
    guard await fitsTranscriptBudget(requiredEntries, budget: budget) else {
        return nil
    }

    switch config.strategy {
    case .newestFirst:
        return await trimNewestFirst(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget, pinLast: pin)
    case .oldestFirst:
        return await trimOldestFirst(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget, pinLast: pin)
    case .slidingWindow:
        return await trimSlidingWindow(
            base: baseEntries, history: historyEntries, final: finalEntry,
            budget: budget, maxTurns: config.maxTurns, pinLast: pin)
    case .summarize:
        return await trimWithSummary(
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget,
            permissive: config.permissive, pinLast: pin)
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

public func trimNewestFirst(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int, pinLast: Bool = false
) async -> [Transcript.Entry] {
    let kept = await ToolExchangeGrouping.newestFirst(
        groups: historyGroups(history), pinLast: pinLast,
        fits: budgetPredicate(base: base, history: history, final: final, budget: budget))
    return assembleTranscriptEntries(base: base, history: selectEntries(history, in: kept))
}

// MARK: - Strategy: Oldest First

public func trimOldestFirst(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int, pinLast: Bool = false
) async -> [Transcript.Entry] {
    let kept = await ToolExchangeGrouping.oldestFirst(
        groups: historyGroups(history), pinLast: pinLast,
        fits: budgetPredicate(base: base, history: history, final: final, budget: budget))
    return assembleTranscriptEntries(base: base, history: selectEntries(history, in: kept))
}

// MARK: - Strategy: Sliding Window

/// `maxTurns` counts whole groups: a tool exchange (call plus its results) is
/// one turn, the same as a user or assistant message (#482).
func trimSlidingWindow(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int, maxTurns: Int?, pinLast: Bool = false
) async -> [Transcript.Entry] {
    let windowed = ToolExchangeGrouping.window(
        groups: historyGroups(history), pinLast: pinLast, maxGroups: maxTurns)
    // Apply token-budget safety net (drop from front if over budget)
    let kept = await ToolExchangeGrouping.newestFirst(
        groups: windowed, pinLast: pinLast,
        fits: budgetPredicate(base: base, history: history, final: final, budget: budget))
    return assembleTranscriptEntries(base: base, history: selectEntries(history, in: kept))
}

// MARK: - Streaming Helper

/// Stream a response, optionally printing deltas to stdout.
/// FoundationModels returns cumulative snapshots; we compute deltas by tracking prev length.
///
/// Resolves `finishReason` two ways:
///   - Natural stream completion: `.length` if `completionTokens >= maxTokens`,
///     else `.stop`. Tool-call detection happens at higher layers.
///   - Output-side context overflow (model ran into the dynamic context
///     ceiling after producing content): graceful `.length`. Prompt-side
///     overflow (no content produced before the throw) still throws.
///
/// - Returns: A `GenerationOutcome` carrying the accumulated content, the
///   resolved finish reason, and the runtime-reported usage when the SDK
///   provides it (macOS 27+; nil on macOS 26).
public func collectStream(
    _ session: LanguageModelSession,
    prompt: String,
    sink: StreamPrintSink? = nil,
    options: GenerationOptions = GenerationOptions()
) async throws -> GenerationOutcome {
    try await collectStream(session, prompt: Prompt(prompt), sink: sink, options: options)
}

/// Prompt-typed variant so an image-bearing user turn (macOS 27, #510)
/// streams through the same path as text.
public func collectStream(
    _ session: LanguageModelSession,
    prompt: Prompt,
    sink: StreamPrintSink? = nil,
    options: GenerationOptions = GenerationOptions()
) async throws -> GenerationOutcome {
    let stream = session.streamResponse(to: prompt, options: options)
    var prev = ""
    var reported: TokenUsage? = nil
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
            reported = reportedUsage(of: snapshot) ?? reported
        }
        // Completion tokens for the finish-reason decision: the runtime's own
        // number when reported (macOS 27+), else one tokenizer count (macOS 26).
        let completionTokens: Int
        if let reported {
            completionTokens = reported.completionTokens
        } else {
            completionTokens = await TokenCounter.shared.count(prev)
        }
        let reason = FinishReasonResolver.resolve(
            hasToolCalls: false,
            completionTokens: completionTokens,
            maxTokens: options.maximumResponseTokens
        )
        return GenerationOutcome(content: prev, finishReason: reason, usage: reported)
    } catch {
        let classified = classifyModelError(error)
        switch StreamErrorResolver.resolve(prev: prev, error: classified) {
        case .truncated(let content):
            // The last snapshot's reported usage prices the truncated content.
            return GenerationOutcome(content: content, finishReason: .length, usage: reported)
        case .fatal(let err):
            throw err
        }
    }
}

/// Outcome of one streamed model call: content, finish reason, and the
/// runtime-reported usage when the SDK provides it (macOS 27+; nil on 26).
public struct GenerationOutcome: Sendable {
    public let content: String
    public let finishReason: FinishReason
    public let usage: TokenUsage?

    public init(content: String, finishReason: FinishReason, usage: TokenUsage?) {
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
    }
}
