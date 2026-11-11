// ============================================================================
// SamplingDecision.swift — Pure mapping from request sampling params to a mode
// Part of ApfelCore — shared with the executable, unit-testable without
// FoundationModels (whose GenerationOptions.SamplingMode lives in the SDK).
// ============================================================================

import Foundation

/// A FoundationModels-free description of which sampling mode a request maps to.
///
/// The executable's `makeGenerationOptions` translates this into the SDK's
/// `GenerationOptions.SamplingMode`. Keeping the decision pure lets the unit
/// runner (which cannot import FoundationModels) exercise the policy directly.
public enum SamplingDecision: Sendable, Equatable {
    /// Deterministic greedy decoding (always pick the most likely token).
    case greedy
    /// Nucleus (top-p) sampling with the given probability threshold and seed.
    case nucleus(probabilityThreshold: Double, seed: UInt64?)
    /// Top-k random sampling with a fixed k and the given seed.
    case topK(top: Int, seed: UInt64)
    /// No explicit sampling mode — defer to the model default.
    case defaultMode

    /// Temperatures below this are treated as "deterministic": greedy
    /// decoding, and the value is not forwarded to the SDK. Forwarding one
    /// to any sampling mode makes the on-device model degenerate (measured on
    /// macOS 27.0.1: 0.0005 answers normally, 0.0003 emits "model\nmodel...",
    /// 0.0002 and below produce no decodable output until the context window
    /// fills - minutes of a stalled model for every client).
    public static let minimumSamplingTemperature: Double = 0.001

    /// The temperature to hand to the SDK: nil for a below-floor value (the
    /// request then runs greedy, see `resolve`), the value itself otherwise.
    public static func forwardedTemperature(_ temperature: Double?) -> Double? {
        guard let temperature, temperature >= minimumSamplingTemperature else { return nil }
        return temperature
    }

    /// Maps OpenAI-style sampling parameters to a sampling decision.
    ///
    /// Policy:
    /// - `temperature` below `minimumSamplingTemperature` (0 included) ->
    ///   greedy, even with `top_p` or `seed`: the client asked for
    ///   deterministic output, and near-zero sampling degenerates.
    /// - else `top_p` present -> nucleus(top_p, seed) (honors #168).
    /// - else a `seed` -> topK(top: 50, seed) (existing reproducible behavior).
    /// - else -> defaultMode.
    public static func resolve(
        temperature: Double?,
        topP: Double?,
        seed: UInt64?
    ) -> SamplingDecision {
        if let temperature, temperature < minimumSamplingTemperature {
            return .greedy
        }
        if let topP {
            return .nucleus(probabilityThreshold: topP, seed: seed)
        }
        if let seed {
            return .topK(top: 50, seed: seed)
        }
        return .defaultMode
    }
}
