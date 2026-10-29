// ============================================================================
// OnDeviceEngine.swift - the macOS 26 baseline Engine implementation.
// Part of ApfelEngine. 100% on-device; print-free.
//
// One actor instance owns one conversation, driven through an injected
// GenerationBackend (FoundationModelsBackend in production, a fake in unit
// tests). Streaming converts the backend's cumulative snapshots into true
// deltas; each turn's token usage is counted and accumulated per session.
// When the conversation outgrows the runtime input budget the oldest turns
// are dropped (newest-first), keeping the instructions block - the same
// default strategy as `apfel --chat`.
// ============================================================================

import Foundation
import ApfelCore

public actor OnDeviceEngine: Engine {
    private let backend: any GenerationBackend
    private let errorRecovery: ErrorRecovery
    private var sessionUsageTotal = TokenUsage(promptTokens: 0, completionTokens: 0)

    /// `.preserve` is the default: it matches what the macOS 26 runtime does
    /// on its own, so the policy is opt-in rather than a behavior change.
    public init(backend: any GenerationBackend, errorRecovery: ErrorRecovery = .preserve) {
        self.backend = backend
        self.errorRecovery = errorRecovery
    }

    /// Production convenience: a FoundationModels-backed conversation.
    public init(systemPrompt: String? = nil, permissive: Bool = false, errorRecovery: ErrorRecovery = .preserve) {
        self.backend = FoundationModelsBackend(systemPrompt: systemPrompt, permissive: permissive)
        self.errorRecovery = errorRecovery
    }

    public func modelInfo() async -> EngineModelInfo {
        await backend.modelInfo()
    }

    public func prewarm() async {
        await backend.prewarm()
    }

    /// Token usage accumulated across every completed turn of this
    /// conversation (resets with `reset`).
    public func sessionUsage() -> TokenUsage {
        sessionUsageTotal
    }

    public func reset(systemPrompt: String?) async {
        sessionUsageTotal = TokenUsage(promptTokens: 0, completionTokens: 0)
        var entries: [EngineTranscript.Entry] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            entries = [.instructions(systemPrompt)]
        }
        await backend.reset(entries: entries)
    }

    /// Snapshot the conversation for persistence.
    public func transcript() async -> EngineTranscript {
        EngineTranscript(entries: await backend.entries())
    }

    /// Replace the conversation with a persisted transcript. Session usage
    /// restarts at zero - the saved turns were paid for by the session that
    /// generated them.
    public func resume(_ transcript: EngineTranscript) async {
        sessionUsageTotal = TokenUsage(promptTokens: 0, completionTokens: 0)
        await backend.reset(entries: transcript.entries)
    }

    public func contextStatus(outputReserve: Int = 512) async -> EngineContextStatus {
        let used = await backend.count(entries: backend.entries())
        let budget = await backend.inputBudget(outputReserve: outputReserve)
        return EngineContextStatus(
            usedTokens: used, budgetTokens: budget, contextWindow: await backend.contextWindow())
    }

    public func send(_ prompt: String) -> AsyncThrowingStream<EngineEvent, Error> {
        let backend = self.backend
        let errorRecovery = self.errorRecovery
        return AsyncThrowingStream { continuation in
            let task = Task {
                let before = await backend.entries()
                do {
                    var previous = ""
                    for try await content in await backend.stream(prompt: prompt) {
                        // Snapshots are cumulative; emit only the new suffix.
                        if content.hasPrefix(previous) {
                            let delta = String(content.dropFirst(previous.count))
                            if !delta.isEmpty { continuation.yield(.delta(delta)) }
                        } else {
                            // A snapshot that rewrote earlier text (not observed
                            // in practice): resend it whole so the client's
                            // accumulated text stays equal to the model's.
                            continuation.yield(.delta(content))
                        }
                        previous = content
                    }
                    let usage = TokenUsage(
                        promptTokens: await backend.count(entries: before + [.prompt(prompt)]),
                        completionTokens: await backend.count(text: previous))
                    self.accumulate(usage)  // Task inherits this actor's isolation
                    continuation.yield(.usage(usage))
                    continuation.yield(.finished(EngineResponse(text: previous, usage: usage)))
                    await self.rotateContextIfNeeded()
                    continuation.finish()
                } catch {
                    if errorRecovery == .revert {
                        await backend.reset(entries: before)
                    }
                    continuation.finish(throwing: ApfelError.classify(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func accumulate(_ usage: TokenUsage) {
        sessionUsageTotal = sessionUsageTotal.adding(usage)
    }

    /// Newest-first context protection, mirroring `apfel --chat`'s default:
    /// when the conversation exceeds the runtime input budget, drop the oldest
    /// non-instruction entries until it fits (the instructions block stays).
    private func rotateContextIfNeeded(outputReserve: Int = 512) async {
        var entries = await backend.entries()
        let budget = await backend.inputBudget(outputReserve: outputReserve)
        guard await backend.count(entries: entries) > budget else { return }

        var base: [EngineTranscript.Entry] = []
        if case .instructions = entries.first {
            base = [entries.removeFirst()]
        }
        while !entries.isEmpty, await backend.count(entries: base + entries) > budget {
            entries.removeFirst()
        }
        await backend.reset(entries: base + entries)
    }
}
