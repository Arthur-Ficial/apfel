import Foundation
import ApfelCore

func runSamplingDecisionTests() {
    // #168: temperature == 0 with no explicit top_p -> deterministic greedy.
    test("resolve maps temperature:0 (no top_p) to greedy") {
        let decision = SamplingDecision.resolve(temperature: 0, topP: nil, seed: nil)
        try assertEqual(decision, .greedy)
    }

    test("resolve maps temperature:0 with a seed (no top_p) to greedy") {
        let decision = SamplingDecision.resolve(temperature: 0, topP: nil, seed: 42)
        try assertEqual(decision, .greedy)
    }

    // #168: top_p present -> nucleus(probabilityThreshold:, seed:).
    test("resolve maps top_p to nucleus carrying the seed") {
        let decision = SamplingDecision.resolve(temperature: nil, topP: 0.9, seed: 7)
        try assertEqual(decision, .nucleus(probabilityThreshold: 0.9, seed: 7))
    }

    test("resolve maps top_p to nucleus with nil seed when no seed given") {
        let decision = SamplingDecision.resolve(temperature: 0.7, topP: 0.5, seed: nil)
        try assertEqual(decision, .nucleus(probabilityThreshold: 0.5, seed: nil))
    }

    // temperature 0 (or any temperature below the floor) means "deterministic"
    // even with top_p: forwarding a near-zero temperature to a sampling mode
    // makes the on-device model emit garbage until the window fills (F1).
    test("resolve maps temperature:0 with top_p to greedy") {
        let decision = SamplingDecision.resolve(temperature: 0, topP: 0.8, seed: nil)
        try assertEqual(decision, .greedy)
    }

    test("resolve maps a near-zero temperature to greedy (F1: 0.0003 degenerates)") {
        for t in [0.0001, 0.0003, 1e-10, 0.0009] {
            try assertEqual(SamplingDecision.resolve(temperature: t, topP: nil, seed: nil), .greedy, "t=\(t)")
            try assertEqual(SamplingDecision.resolve(temperature: t, topP: 0.9, seed: 7), .greedy, "t=\(t) + top_p")
            try assertEqual(SamplingDecision.resolve(temperature: t, topP: nil, seed: 7), .greedy, "t=\(t) + seed")
        }
    }

    test("resolve keeps sampling at and above the floor") {
        try assertEqual(SamplingDecision.resolve(temperature: SamplingDecision.minimumSamplingTemperature, topP: nil, seed: nil), .defaultMode)
        try assertEqual(SamplingDecision.resolve(temperature: 0.2, topP: 0.9, seed: nil), .nucleus(probabilityThreshold: 0.9, seed: nil))
    }

    test("forwardedTemperature drops a below-floor temperature, keeps a real one") {
        try assertNil(SamplingDecision.forwardedTemperature(0))
        try assertNil(SamplingDecision.forwardedTemperature(0.0001))
        try assertNil(SamplingDecision.forwardedTemperature(nil))
        try assertEqual(SamplingDecision.forwardedTemperature(0.7), 0.7)
    }

    // Existing seed-only behavior is preserved: topK(top: 50, seed:).
    test("resolve preserves seed-only top-k(50) behavior") {
        let decision = SamplingDecision.resolve(temperature: nil, topP: nil, seed: 99)
        try assertEqual(decision, .topK(top: 50, seed: 99))
    }

    test("resolve preserves seed-only top-k(50) with a non-zero temperature") {
        let decision = SamplingDecision.resolve(temperature: 0.7, topP: nil, seed: 99)
        try assertEqual(decision, .topK(top: 50, seed: 99))
    }

    // Nothing specified -> model default.
    test("resolve returns defaultMode when nothing is specified") {
        let decision = SamplingDecision.resolve(temperature: nil, topP: nil, seed: nil)
        try assertEqual(decision, .defaultMode)
    }

    test("resolve returns defaultMode for a non-zero temperature with no seed/top_p") {
        let decision = SamplingDecision.resolve(temperature: 0.7, topP: nil, seed: nil)
        try assertEqual(decision, .defaultMode)
    }
}
