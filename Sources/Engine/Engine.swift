// ============================================================================
// Engine.swift - the reusable generation engine surface (ApfelEngine).
//
// Shape per the 2026-10-29 FoundationModels API study: the engine exposes
// DATA (ApfelCore types, strings, events) - never FoundationModels types - so
// a GUI, the CLI or a test consumes the same surface. Errors are always
// classified `ApfelError`. The single `#available(macOS 27, *)` decision for
// a future 27-specialized engine (runtime-reported usage, tool-calling mode)
// lives in `EngineFactory.make` and nowhere else.
//
// This library is print-free by construction: no stdout/stderr, no globals
// from the apfel executable (outputFormat/quietMode stay in the main target).
// ============================================================================

import Foundation
import ApfelCore

// MARK: - Data surface

/// One streamed generation event.
public enum EngineEvent: Sendable {
    /// The next chunk of assistant text (a true delta, not a cumulative snapshot).
    case delta(String)
    /// The completed turn's token usage: runtime-reported where the OS
    /// provides it (macOS 27+), counted via TokenCounter on macOS 26.
    case usage(TokenUsage)
    /// The turn completed; carries the full text.
    case finished(EngineResponse)
}

/// The completed result of one generation turn.
public struct EngineResponse: Sendable {
    public let text: String
    /// The turn's token usage: runtime-reported where the OS provides it
    /// (macOS 27+), counted via TokenCounter on macOS 26; nil only when no
    /// number could be produced at all.
    public let usage: TokenUsage?

    public init(text: String, usage: TokenUsage? = nil) {
        self.text = text
        self.usage = usage
    }
}

/// Model facts a client shows the user. All values are read from the runtime
/// (never hardcoded - the context window is dynamic, #192/#330).
public struct EngineModelInfo: Sendable {
    public let availability: ModelAvailability
    public let contextWindow: ContextWindow
    public let capabilities: CapabilitiesReport
    /// Model variant display name (e.g. "AFM 3 Core"), read from the injected
    /// `TokenCounter.variantReader`; nil where the OS does not report one
    /// (macOS 26).
    public let variantName: String?

    public init(availability: ModelAvailability, contextWindow: ContextWindow, capabilities: CapabilitiesReport, variantName: String? = nil) {
        self.availability = availability
        self.contextWindow = contextWindow
        self.capabilities = capabilities
        self.variantName = variantName
    }
}

/// Live context accounting for one conversation.
public struct EngineContextStatus: Sendable {
    /// Tokens the current transcript occupies.
    public let usedTokens: Int
    /// Input budget (context window minus the output reserve).
    public let budgetTokens: Int
    /// The full runtime context window.
    public let contextWindow: ContextWindow

    public init(usedTokens: Int, budgetTokens: Int, contextWindow: ContextWindow) {
        self.usedTokens = usedTokens
        self.budgetTokens = budgetTokens
        self.contextWindow = contextWindow
    }
}

// MARK: - Engine protocol

/// A stateful, on-device chat engine: one instance is one conversation.
public protocol Engine: Sendable {
    /// Model facts for onboarding / status UI.
    func modelInfo() async -> EngineModelInfo
    /// Warm the model up (no-op when unavailable).
    func prewarm() async
    /// Send one user turn, optionally with image attachments (macOS 27,
    /// capability-gated by the caller - see `EngineModelInfo.capabilities`);
    /// events stream back (deltas, then `.finished`). Thrown errors are
    /// always `ApfelError`. Cancelling the consuming task stops generation.
    func send(_ prompt: String, images: [PromptImage]) async -> AsyncThrowingStream<EngineEvent, Error>
    /// Apply per-conversation generation options (clamped via
    /// `EngineOptions.normalized()` before they reach the SDK). Takes effect
    /// from the next turn; `.defaults` reproduces historical behavior.
    func setOptions(_ options: EngineOptions) async
    /// Current context accounting (reads the runtime window, never a literal).
    func contextStatus(outputReserve: Int) async -> EngineContextStatus
    /// Token usage accumulated across this conversation's completed turns.
    func sessionUsage() async -> TokenUsage
    /// Snapshot the conversation for persistence (`EngineTranscript.encode()`).
    func transcript() async -> EngineTranscript
    /// Replace the conversation with a persisted transcript (fresh session
    /// usage), e.g. after `EngineTranscript.decode(from:)`.
    func resume(_ transcript: EngineTranscript) async
    /// Drop conversation history (keeps the system prompt), e.g. after the
    /// user clears the chat or changes the system prompt.
    func reset(systemPrompt: String?) async
}

extension Engine {
    /// Text-only turn - the overwhelmingly common case.
    public func send(_ prompt: String) async -> AsyncThrowingStream<EngineEvent, Error> {
        await send(prompt, images: [])
    }
}

// MARK: - Factory

public enum EngineFactory {
    /// The ONE place a macOS-27-specialized engine would be selected.
    /// Today both branches return the shared on-device engine: the
    /// 27-specialized variant (runtime-reported usage events, tool-calling
    /// mode) requires building against the macOS 27 SDK and is deferred -
    /// the surface above is already shaped for it (`EngineEvent.usage`).
    public static func make(systemPrompt: String? = nil, permissive: Bool = false, errorRecovery: ErrorRecovery = .preserve) -> any Engine {
        if #available(macOS 27, *) {
            return OnDeviceEngine(systemPrompt: systemPrompt, permissive: permissive, errorRecovery: errorRecovery)
        }
        return OnDeviceEngine(systemPrompt: systemPrompt, permissive: permissive, errorRecovery: errorRecovery)
    }
}
