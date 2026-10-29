// ============================================================================
// FoundationModelsBackend.swift - the production GenerationBackend.
// Part of ApfelEngine. 100% on-device via FoundationModels; print-free.
//
// Owns the LanguageModelSession and the conversion between apfel's pure
// `EngineTranscript.Entry` and the SDK's `Transcript.Entry`. Counting and
// model facts go through TokenCounter (runtime context window, never a
// literal). Compiles against the macOS 26 SDK.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

public actor FoundationModelsBackend: GenerationBackend {
    private var session: LanguageModelSession
    private let permissive: Bool

    public init(systemPrompt: String? = nil, permissive: Bool = false) {
        self.permissive = permissive
        var initial: [EngineTranscript.Entry] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            initial = [.instructions(systemPrompt)]
        }
        self.session = Self.makeSession(entries: initial, permissive: permissive)
    }

    private static func makeModel(permissive: Bool) -> SystemLanguageModel {
        SystemLanguageModel(guardrails: permissive ? .permissiveContentTransformations : .default)
    }

    private static func makeSession(entries: [EngineTranscript.Entry], permissive: Bool) -> LanguageModelSession {
        let model = makeModel(permissive: permissive)
        guard !entries.isEmpty else {
            return LanguageModelSession(model: model)
        }
        return LanguageModelSession(
            model: model,
            transcript: Transcript(entries: entries.map(Self.toTranscriptEntry)))
    }

    public func reset(entries: [EngineTranscript.Entry]) {
        session = Self.makeSession(entries: entries, permissive: permissive)
    }

    public func entries() -> [EngineTranscript.Entry] {
        Array(session.transcript).flatMap(Self.fromTranscriptEntry)
    }

    public func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let session = self.session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await snapshot in session.streamResponse(to: prompt, options: GenerationOptions()) {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func count(text: String) async -> Int {
        await TokenCounter.shared.count(text)
    }

    public func count(entries: [EngineTranscript.Entry]) async -> Int {
        await TokenCounter.shared.count(entries: entries.map(Self.toTranscriptEntry))
    }

    public func inputBudget(outputReserve: Int) async -> Int {
        await TokenCounter.shared.inputBudget(reservedForOutput: outputReserve)
    }

    public func contextWindow() async -> ContextWindow {
        await TokenCounter.shared.contextWindow
    }

    public func modelInfo() async -> EngineModelInfo {
        let tc = TokenCounter.shared
        return EngineModelInfo(
            availability: await tc.availability,
            contextWindow: await tc.contextWindow,
            capabilities: await tc.capabilitiesReport,
            variantName: TokenCounter.variantReader())
    }

    public func prewarm() async {
        await TokenCounter.shared.prewarm()
    }

    // MARK: - EngineTranscript <-> Transcript conversion

    private static func textSegments(_ text: String) -> [Transcript.Segment] {
        [.text(Transcript.TextSegment(content: text))]
    }

    private static func joinedText(_ segments: [Transcript.Segment]) -> String {
        segments.compactMap { segment in
            switch segment {
            case .text(let t): return t.content
            case .structure(let s): return s.content.jsonString
            @unknown default: return nil
            }
        }.joined(separator: "\n")
    }

    static func toTranscriptEntry(_ entry: EngineTranscript.Entry) -> Transcript.Entry {
        switch entry {
        case .instructions(let text):
            return .instructions(Transcript.Instructions(segments: textSegments(text), toolDefinitions: []))
        case .prompt(let text):
            return .prompt(Transcript.Prompt(segments: textSegments(text)))
        case .response(let text):
            return .response(Transcript.Response(assetIDs: [], segments: textSegments(text)))
        case .toolCall(let toolName, let argumentsJSON):
            // Persisted arguments should always be valid JSON (they were
            // serialized from GeneratedContent); a hand-edited file falls back
            // to carrying the raw string as the argument content.
            let arguments = (try? GeneratedContent(json: argumentsJSON)) ?? GeneratedContent(argumentsJSON)
            let call = Transcript.ToolCall(id: UUID().uuidString, toolName: toolName, arguments: arguments)
            return .toolCalls(Transcript.ToolCalls([call]))
        case .toolOutput(let toolName, let content):
            return .toolOutput(Transcript.ToolOutput(
                id: UUID().uuidString, toolName: toolName, segments: textSegments(content)))
        }
    }

    static func fromTranscriptEntry(_ entry: Transcript.Entry) -> [EngineTranscript.Entry] {
        switch entry {
        case .instructions(let i):
            return [.instructions(joinedText(i.segments))]
        case .prompt(let p):
            return [.prompt(joinedText(p.segments))]
        case .response(let r):
            return [.response(joinedText(r.segments))]
        case .toolCalls(let calls):
            return calls.map { .toolCall(toolName: $0.toolName, argumentsJSON: $0.arguments.jsonString) }
        case .toolOutput(let o):
            return [.toolOutput(toolName: o.toolName, content: joinedText(o.segments))]
        @unknown default:
            return []
        }
    }
}
