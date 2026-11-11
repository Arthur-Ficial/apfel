// ============================================================================
// EngineOptions.swift — per-conversation generation options (ApfelCore).
//
// Pure, Codable, FoundationModels-free: the GUI persists these per
// conversation and the engine (ApfelEngine) maps them onto the SDK's
// GenerationOptions / SystemLanguageModel init. Every knob here was
// verified working on real hardware (probe, 2026-11-02); clamping lives
// here because the SDK validates nothing (it silently accepts e.g.
// temperature 5.0).
// ============================================================================

import Foundation

/// Persistence support for the existing pure policy enum (String raw value).
extension ErrorRecovery: Codable {}

/// Everything a conversation can customize about on-device generation.
/// `EngineOptions()` (== `.defaults`) reproduces the engine's historical
/// behavior exactly: nothing is opted in.
public struct EngineOptions: Sendable, Equatable, Codable {

    /// Which tuned variant of the system model to use (`SystemLanguageModel.UseCase`).
    public enum UseCase: String, Sendable, Equatable, Codable, CaseIterable {
        /// The general-purpose assistant model.
        case general
        /// The content-tagging tuned variant (outputs tags, not prose).
        case contentTagging
    }

    /// Which sampling mode the UI selected. The temperature applies on top
    /// of any mode, mirroring `GenerationOptions`.
    public enum SamplingModeChoice: String, Sendable, Equatable, Codable, CaseIterable {
        /// Defer to the model's default sampling.
        case system
        /// Deterministic greedy decoding.
        case greedy
        /// Top-k random sampling (`topK`, optional `seed`).
        case topK
        /// Nucleus (top-p) sampling (`topP`, optional `seed`).
        case nucleus
    }

    /// Reasoning effort (`ContextOptions.ReasoningLevel`, macOS 27 +
    /// reasoning-capable model only — `core3` rejects every level).
    public enum ReasoningEffort: String, Sendable, Equatable, Codable, CaseIterable {
        case light, moderate, deep
    }

    public var useCase: UseCase = .general
    /// `SystemLanguageModel.Guardrails.permissiveContentTransformations`
    /// (intended for transforming user-provided text; guardrails can never
    /// be disabled outright).
    public var permissiveGuardrails: Bool = false
    public var samplingMode: SamplingModeChoice = .system
    /// nil = model default. UI range 0...2; `normalized()` clamps.
    public var temperature: Double? = nil
    public var topK: Int = 50
    public var topP: Double = 0.9
    /// Fixed seed for reproducible top-k / nucleus sampling; nil = random.
    public var seed: UInt64? = nil
    /// Approximate output cap (the runtime counts framing tokens on top);
    /// nil = no limit beyond the context window.
    public var maxResponseTokens: Int? = nil
    /// false maps to macOS 27's `toolCallingMode = .disallowed`
    /// (`.required` is deliberately never exposed: it reproducibly
    /// overflows the context window). No-op on macOS 26.
    public var allowToolCalls: Bool = true
    /// nil = no reasoning request (the only working value on `core3`).
    public var reasoningEffort: ReasoningEffort? = nil
    /// What happens to the conversation when a turn fails.
    public var errorRecovery: ErrorRecovery = .preserve

    public init() {}

    public static let defaults = EngineOptions()

    /// Clamp every value into the range the model meaningfully accepts.
    /// The SDK does not validate (temperature 5.0 is silently accepted),
    /// so apfel enforces honesty here: temperature 0...2, topP (0, 1],
    /// topK >= 1, maxResponseTokens >= 1.
    public func normalized() -> EngineOptions {
        var o = self
        if let t = o.temperature { o.temperature = min(max(t, 0.0), 2.0) }
        o.topP = min(max(o.topP, 0.01), 1.0)
        o.topK = max(o.topK, 1)
        if let m = o.maxResponseTokens { o.maxResponseTokens = max(m, 1) }
        return o
    }

    /// The pure sampling decision for one turn. `fallbackSeed` is used only
    /// for top-k without an explicit seed (the decision type requires one);
    /// callers pass a random value, tests pass a fixed one.
    public func samplingDecision(fallbackSeed: UInt64) -> SamplingDecision {
        switch samplingMode {
        case .system:
            return .defaultMode
        case .greedy:
            return .greedy
        case .topK:
            return .topK(top: topK, seed: seed ?? fallbackSeed)
        case .nucleus:
            return .nucleus(probabilityThreshold: topP, seed: seed)
        }
    }
}
