// ============================================================================
// OnDeviceEngine.swift - the macOS 26 baseline Engine implementation.
// Part of ApfelEngine. 100% on-device via FoundationModels; print-free.
//
// One actor instance owns one conversation: a LanguageModelSession whose
// transcript grows turn by turn. Streaming converts FoundationModels'
// cumulative snapshots into true deltas. When the transcript outgrows the
// runtime input budget the oldest turns are dropped (newest-first), keeping
// the instructions block - the same default strategy as `apfel --chat`.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

public actor OnDeviceEngine: Engine {
    private var session: LanguageModelSession
    private var systemPrompt: String?
    private let permissive: Bool

    public init(systemPrompt: String? = nil, permissive: Bool = false) {
        self.systemPrompt = systemPrompt
        self.permissive = permissive
        self.session = Self.makeSession(systemPrompt: systemPrompt, permissive: permissive)
    }

    private static func makeModel(permissive: Bool) -> SystemLanguageModel {
        SystemLanguageModel(guardrails: permissive ? .permissiveContentTransformations : .default)
    }

    private static func makeSession(systemPrompt: String?, permissive: Bool) -> LanguageModelSession {
        let model = makeModel(permissive: permissive)
        guard let systemPrompt, !systemPrompt.isEmpty else {
            return LanguageModelSession(model: model)
        }
        let segment = Transcript.TextSegment(content: systemPrompt)
        let instructions = Transcript.Instructions(segments: [.text(segment)], toolDefinitions: [])
        return LanguageModelSession(model: model, transcript: Transcript(entries: [.instructions(instructions)]))
    }

    public func modelInfo() async -> EngineModelInfo {
        let tc = TokenCounter.shared
        return EngineModelInfo(
            availability: await tc.availability,
            contextWindow: await tc.contextWindow,
            capabilities: await tc.capabilitiesReport)
    }

    public func prewarm() async {
        await TokenCounter.shared.prewarm()
    }

    public func reset(systemPrompt: String?) {
        self.systemPrompt = systemPrompt
        self.session = Self.makeSession(systemPrompt: systemPrompt, permissive: permissive)
    }

    public func contextStatus(outputReserve: Int = 512) async -> EngineContextStatus {
        let tc = TokenCounter.shared
        let used = await tc.count(entries: Array(session.transcript))
        let budget = await tc.inputBudget(reservedForOutput: outputReserve)
        return EngineContextStatus(
            usedTokens: used, budgetTokens: budget, contextWindow: await tc.contextWindow)
    }

    public func send(_ prompt: String) -> AsyncThrowingStream<EngineEvent, Error> {
        let session = self.session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = session.streamResponse(to: prompt, options: GenerationOptions())
                    var previous = ""
                    for try await snapshot in stream {
                        let content = snapshot.content
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
                    continuation.yield(.finished(EngineResponse(text: previous)))
                    continuation.finish()
                    await self.rotateContextIfNeeded()
                } catch {
                    continuation.finish(throwing: ApfelError.classify(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Newest-first context protection, mirroring `apfel --chat`'s default:
    /// when the transcript exceeds the runtime input budget, drop the oldest
    /// non-instruction entries until it fits (the instructions block stays).
    private func rotateContextIfNeeded(outputReserve: Int = 512) async {
        let tc = TokenCounter.shared
        var entries = Array(session.transcript)
        let budget = await tc.inputBudget(reservedForOutput: outputReserve)
        guard await tc.count(entries: entries) > budget else { return }

        var base: [Transcript.Entry] = []
        if case .instructions = entries.first {
            base = [entries.removeFirst()]
        }
        while !entries.isEmpty, await tc.count(entries: base + entries) > budget {
            entries.removeFirst()
        }
        session = LanguageModelSession(
            model: Self.makeModel(permissive: permissive),
            transcript: Transcript(entries: base + entries))
    }
}
