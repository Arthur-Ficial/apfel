// ============================================================================
// UsageAccounting.swift — where usage numbers come from (#510 item 1, #504)
//
// macOS 27+: the FoundationModels runtime reports token usage with every
// response (`Response.usage`, and `usage` on each stream snapshot), so apfel
// takes prompt/completion numbers straight from the SDK - no tokenCount(for:)
// round trips for usage on the happy path.
// macOS 26: the runtime reports nothing; usage keeps being counted via
// TokenCounter exactly as before, byte-identical on the wire.
//
// The availability decision is made HERE, once. Everything downstream
// branches on data (a reported TokenUsage present or absent), never on
// #available - ApfelCore stays availability-free. Paths that answer without
// a model response (refusals, pre-response errors) have no reported usage on
// either OS and keep counting.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

/// True when the FoundationModels runtime reports token usage on every
/// response (macOS 27+). Decided once per process.
let runtimeReportsUsage: Bool = {
    if #available(macOS 27, *) { return true }
    return false
}()

@available(macOS 27, *)
private func tokenUsage(_ usage: LanguageModelSession.Usage) -> TokenUsage {
    TokenUsage(
        promptTokens: usage.input.totalTokenCount,
        completionTokens: usage.output.totalTokenCount,
        cachedPromptTokens: usage.input.cachedTokenCount)
}

/// The runtime-reported usage of a non-streaming response; nil on macOS 26.
func reportedUsage<Content>(of response: LanguageModelSession.Response<Content>) -> TokenUsage? {
    if #available(macOS 27, *) {
        return tokenUsage(response.usage)
    }
    return nil
}

/// The runtime-reported usage of a streaming snapshot; nil on macOS 26.
///
/// Input tokens are constant across one response's snapshots and output
/// tokens grow with the content, so the LAST seen snapshot's usage prices
/// everything accumulated so far - including a stream cut short by an
/// output-side context overflow.
func reportedUsage<Content>(of snapshot: LanguageModelSession.ResponseStream<Content>.Snapshot) -> TokenUsage? {
    if #available(macOS 27, *) {
        return tokenUsage(snapshot.usage)
    }
    return nil
}

/// Prompt-token accounting input for one request.
///
/// - `.counted` (macOS 26): the number was counted up front via TokenCounter,
///   today's behavior, unchanged on the wire.
/// - `.deferred` (macOS 27): no up-front count - the happy path takes input
///   tokens from the runtime-reported usage, and only paths that answer
///   without any model response (refusals, errors) resolve a count lazily.
enum PromptTokens: Sendable {
    case counted(Int)
    case deferred(entries: [Transcript.Entry])

    /// Build the accounting input: count now on macOS 26, defer on macOS 27.
    static func make(entries: [Transcript.Entry]) async -> PromptTokens {
        if runtimeReportsUsage {
            return .deferred(entries: entries)
        }
        return .counted(await TokenCounter.shared.count(entries: entries))
    }

    /// The prompt-token number for a path with no runtime-reported usage.
    func resolve() async -> Int {
        switch self {
        case .counted(let n):
            return n
        case .deferred(let entries):
            return await TokenCounter.shared.count(entries: entries)
        }
    }

    /// The already-counted value, or nil when counting was deferred. Used for
    /// debug-trace estimates that must not trigger a count of their own.
    var countedValue: Int? {
        if case .counted(let n) = self { return n }
        return nil
    }
}
