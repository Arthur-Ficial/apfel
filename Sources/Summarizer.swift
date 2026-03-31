// ============================================================================
// Summarizer.swift — Context strategy: compress old history into a summary
// Part of apfel — Apple Intelligence from the command line
//
// Uses the on-device model itself to generate a summary of older turns,
// keeping recent turns verbatim. Falls back to newest-first on failure.
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore

/// Summarize old history entries, keeping recent ones verbatim.
/// Falls back to newest-first if summarization fails or budget is too tight.
func trimWithSummary(
    base: [Transcript.Entry], history: [Transcript.Entry],
    final: Transcript.Entry?, budget: Int
) async -> [Transcript.Entry] {
    guard history.count > 2 else {
        return await trimNewestFirst(
            base: base, history: history, final: final, budget: budget)
    }

    // Split: keep recent 50% of budget, summarize the rest
    let halfBudget = budget / 2
    var recentEntries: [Transcript.Entry] = []
    for entry in history.reversed() {
        var candidate = base + [entry] + recentEntries
        if let final { candidate.append(final) }
        if await TokenCounter.shared.count(entries: candidate) > halfBudget { break }
        recentEntries.insert(entry, at: 0)
    }

    let oldEntries = Array(history.dropLast(recentEntries.count))
    guard !oldEntries.isEmpty else {
        return base + recentEntries
    }

    // Render old entries to text for summarization
    let oldText = renderEntries(oldEntries)
    guard !oldText.isEmpty else {
        return await trimNewestFirst(
            base: base, history: history, final: final, budget: budget)
    }

    // Summarize using the on-device model
    let summaryText = await generateSummary(oldText)
    guard let summaryText else {
        return await trimNewestFirst(
            base: base, history: history, final: final, budget: budget)
    }

    let segment = Transcript.TextSegment(content: "[Summary of prior conversation]: \(summaryText)")
    let summaryEntry = Transcript.Entry.response(
        Transcript.Response(assetIDs: [], segments: [.text(segment)]))

    return base + [summaryEntry] + recentEntries
}

// MARK: - Helpers

private func renderEntries(_ entries: [Transcript.Entry]) -> String {
    entries.compactMap { entry -> String? in
        switch entry {
        case .prompt(let p):
            return p.segments.compactMap { seg in
                if case .text(let t) = seg { return "User: \(t.content)" }; return nil
            }.joined()
        case .response(let r):
            return r.segments.compactMap { seg in
                if case .text(let t) = seg { return "Assistant: \(t.content)" }; return nil
            }.joined()
        default: return nil
        }
    }.joined(separator: "\n")
}

private func generateSummary(_ text: String) async -> String? {
    let model = SystemLanguageModel.default
    let session = LanguageModelSession(
        model: model,
        instructions: "Summarize the following conversation in 2-3 sentences. Be concise."
    )
    do {
        let response = try await session.respond(to: text)
        let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? nil : summary
    } catch {
        return nil
    }
}
