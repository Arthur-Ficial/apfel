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

    static let defaults = SessionOptions(
        temperature: nil, maxTokens: nil, seed: nil, permissive: false,
        contextConfig: .defaults
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
func makeSession(systemPrompt: String?, options: SessionOptions = .defaults) -> LanguageModelSession {
    let model = makeModel(permissive: options.permissive)
    guard let systemPrompt, !systemPrompt.isEmpty else {
        return LanguageModelSession(model: model)
    }

    // Build CLI sessions from transcript instructions so streaming and
    // non-streaming generation read the same system prompt source.
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

func sessionInputEntries(
    _ session: LanguageModelSession,
    finalPrompt: String,
    options: SessionOptions = .defaults
) -> [Transcript.Entry] {
    Array(Array(session.transcript)) + [makePromptEntry(finalPrompt, options: options)]
}

func assembleTranscriptEntries(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry? = nil
) -> [Transcript.Entry] {
    var entries = base
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
            base: baseEntries, history: historyEntries, final: finalEntry, budget: budget)
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
    var kept: [Transcript.Entry] = []
    for entry in history.reversed() {
        if !(await fitsTranscriptBudget(base: base, history: [entry] + kept, final: final, budget: budget)) {
            break
        }
        kept.insert(entry, at: 0)
    }
    return assembleTranscriptEntries(base: base, history: kept)
}

// MARK: - Strategy: Oldest First

func trimOldestFirst(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int
) async -> [Transcript.Entry] {
    var kept: [Transcript.Entry] = []
    for entry in history {
        if !(await fitsTranscriptBudget(base: base, history: kept + [entry], final: final, budget: budget)) {
            break
        }
        kept.append(entry)
    }
    return assembleTranscriptEntries(base: base, history: kept)
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

// MARK: - Streaming Helper

/// Stream a response, optionally printing deltas to stdout.
/// FoundationModels returns cumulative snapshots; we compute deltas by tracking prev length.
/// - Returns: The complete response text after all chunks have been received.
func collectStream(
    _ session: LanguageModelSession,
    prompt: String,
    printDelta: Bool,
    options: GenerationOptions = GenerationOptions()
) async throws -> String {
    let stream = session.streamResponse(to: prompt, options: options)
    var prev = ""
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
    return prev
}
