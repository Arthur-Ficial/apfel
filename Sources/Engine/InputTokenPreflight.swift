// ============================================================================
// InputTokenPreflight.swift - exact input-token preflight (#485)
// Part of ApfelEngine.
//
// Counts the prepared input generation would send, after the SAME trimming
// generation applies, using only an exact counter. The preflight has no
// session, no generation and no tool executor in reach: its single
// dependency is `ExactTranscriptCounter`. A counter failure anywhere - the
// untrimmed count or any count inside trimming - is thrown, request-scoped,
// never replaced by an estimate.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

/// Exact tokenizer access. Production: `TokenCounter` (Apple's tokenizer);
/// tests inject a scripted counter.
package protocol ExactTranscriptCounter: Sendable {
    func exactCount(entries: [Transcript.Entry]) async throws -> Int
}

extension TokenCounter: ExactTranscriptCounter {}

package struct InputTokenPreflightResult: Sendable, Equatable {
    /// Tokens of the input generation sends (after trimming).
    public let inputTokens: Int
    /// Tokens of the full prepared input.
    public let untrimmedInputTokens: Int
    /// Positions in `PreparedEntries.history` that trimming removed.
    public let removedHistoryPositions: [Int]
}

package enum InputTokenPreflightOutcome: Sendable, Equatable {
    case counted(InputTokenPreflightResult)
    /// The input cannot fit the budget under this strategy.
    case overflow(untrimmedInputTokens: Int)
}

/// Records the first counter failure inside trimming, which can only signal
/// "does not fit" through its Bool predicate. One instance per request.
private actor CountFailureRecorder {
    private(set) var failure: TokenCountingError?

    func record(_ error: Error) {
        guard failure == nil else { return }
        failure = (error as? TokenCountingError) ?? .failed(String(describing: error))
    }
}

package enum InputTokenPreflight {

    package static func run(
        prepared: ContextManager.PreparedEntries,
        budget: Int,
        strategy: ContextStrategy,
        counter: some ExactTranscriptCounter
    ) async throws -> InputTokenPreflightOutcome {
        let all = assembleTranscriptEntries(
            base: prepared.base, history: prepared.history, final: prepared.final)
        let untrimmed = try await counter.exactCount(entries: all)

        let recorder = CountFailureRecorder()
        let kept = await trimHistoryEntriesToBudget(
            baseEntries: prepared.base,
            historyEntries: prepared.history,
            finalEntry: prepared.final,
            budget: budget,
            config: ContextConfig(strategy: strategy),
            pinLast: prepared.pinsTrailingExchange,
            count: { entries in
                do {
                    return try await counter.exactCount(entries: entries)
                } catch {
                    await recorder.record(error)
                    return Int.max
                }
            })
        if let failure = await recorder.failure {
            throw failure
        }
        guard let kept else {
            return .overflow(untrimmedInputTokens: untrimmed)
        }

        let keptIDs = Set(kept.map(\.id))
        let removed = prepared.history.indices.filter { !keptIDs.contains(prepared.history[$0].id) }
        let inputTokens = removed.isEmpty
            ? untrimmed
            : try await counter.exactCount(entries: kept + [prepared.final])
        return .counted(InputTokenPreflightResult(
            inputTokens: inputTokens,
            untrimmedInputTokens: untrimmed,
            removedHistoryPositions: removed))
    }
}
