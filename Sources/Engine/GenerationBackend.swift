// ============================================================================
// GenerationBackend.swift - the generation dependency OnDeviceEngine drives.
//
// The production backend (FoundationModelsBackend) wraps a FoundationModels
// session plus TokenCounter; tests inject a fake, so every piece of
// conversation logic in OnDeviceEngine (deltas, usage accounting, rotation,
// error recovery, resume) is unit-testable without the model.
// ============================================================================

import Foundation
import ApfelCore

/// Everything `OnDeviceEngine` needs from the model runtime, expressed in
/// pure ApfelCore data (`EngineTranscript.Entry`, never FoundationModels types).
public protocol GenerationBackend: Sendable {
    /// Replace the conversation with these entries.
    func reset(entries: [EngineTranscript.Entry]) async
    /// The conversation as pure entries (grows as turns complete).
    func entries() async -> [EngineTranscript.Entry]
    /// Stream CUMULATIVE text snapshots for one user turn. The backend owns
    /// appending the prompt (and whatever response the runtime leaves,
    /// partial on failure) to its conversation.
    func stream(prompt: String) async -> AsyncThrowingStream<String, Error>
    /// Token count for plain text.
    func count(text: String) async -> Int
    /// Token count for conversation entries.
    func count(entries: [EngineTranscript.Entry]) async -> Int
    /// Tokens available for input given a reserved output budget
    /// (from the runtime context window, never a literal).
    func inputBudget(outputReserve: Int) async -> Int
    /// The runtime context window.
    func contextWindow() async -> ContextWindow
    /// Model facts for onboarding / status UI.
    func modelInfo() async -> EngineModelInfo
    /// Warm the model up (no-op when unavailable).
    func prewarm() async
}
