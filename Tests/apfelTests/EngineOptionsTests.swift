// ============================================================================
// EngineOptionsTests.swift - pure per-conversation generation options
// (ApfelCore): defaults, UI-side clamping (the SDK silently accepts e.g.
// temperature 5.0 - the probe measured it - so apfel clamps before the SDK),
// sampling-mode mapping and Codable persistence.
// ============================================================================

import Foundation
import ApfelCore

func runEngineOptionsTests() {

    test("defaults match current engine behavior (nothing opted in)") {
        let o = EngineOptions.defaults
        try assertEqual(o.useCase, .general)
        try assertTrue(!o.permissiveGuardrails)
        try assertEqual(o.samplingMode, .system)
        try assertNil(o.temperature)
        try assertEqual(o.topK, 50)
        try assertEqual(o.topP, 0.9)
        try assertNil(o.seed)
        try assertNil(o.maxResponseTokens)
        try assertTrue(o.allowToolCalls)
        try assertNil(o.reasoningEffort)
        try assertEqual(o.errorRecovery, .preserve)
        try assertEqual(o, EngineOptions())
    }

    test("normalized clamps temperature into 0...2 (SDK accepts 5.0 silently)") {
        var o = EngineOptions()
        o.temperature = 5.0
        try assertEqual(o.normalized().temperature, 2.0)
        o.temperature = -1.0
        try assertEqual(o.normalized().temperature, 0.0)
        o.temperature = 0.7
        try assertEqual(o.normalized().temperature, 0.7)
        o.temperature = nil
        try assertNil(o.normalized().temperature)
    }

    test("normalized clamps topP into (0, 1] and topK/maxResponseTokens to >= 1") {
        var o = EngineOptions()
        o.topP = 0.0
        o.topK = 0
        o.maxResponseTokens = 0
        let n = o.normalized()
        try assertTrue(n.topP > 0.0)
        try assertEqual(n.topK, 1)
        try assertEqual(n.maxResponseTokens, 1)
        o.topP = 1.5
        try assertEqual(o.normalized().topP, 1.0)
        o.maxResponseTokens = nil
        try assertNil(o.normalized().maxResponseTokens)
    }

    test("samplingDecision: system mode defers to the model default") {
        try assertEqual(EngineOptions().samplingDecision(fallbackSeed: 1), .defaultMode)
    }

    test("samplingDecision: greedy maps to greedy") {
        var o = EngineOptions()
        o.samplingMode = .greedy
        try assertEqual(o.samplingDecision(fallbackSeed: 1), .greedy)
    }

    test("samplingDecision: topK uses k and the explicit seed") {
        var o = EngineOptions()
        o.samplingMode = .topK
        o.topK = 40
        o.seed = 42
        try assertEqual(o.samplingDecision(fallbackSeed: 1), .topK(top: 40, seed: 42))
    }

    test("samplingDecision: topK without a seed uses the fallback seed") {
        var o = EngineOptions()
        o.samplingMode = .topK
        o.topK = 50
        try assertEqual(o.samplingDecision(fallbackSeed: 99), .topK(top: 50, seed: 99))
    }

    test("samplingDecision: nucleus uses topP and keeps a nil seed nil") {
        var o = EngineOptions()
        o.samplingMode = .nucleus
        o.topP = 0.8
        try assertEqual(o.samplingDecision(fallbackSeed: 1),
                        .nucleus(probabilityThreshold: 0.8, seed: nil))
        o.seed = 7
        try assertEqual(o.samplingDecision(fallbackSeed: 1),
                        .nucleus(probabilityThreshold: 0.8, seed: 7))
    }

    test("Codable round-trip preserves every field") {
        var o = EngineOptions()
        o.useCase = .contentTagging
        o.permissiveGuardrails = true
        o.samplingMode = .topK
        o.temperature = 1.3
        o.topK = 20
        o.topP = 0.5
        o.seed = 123
        o.maxResponseTokens = 256
        o.allowToolCalls = false
        o.reasoningEffort = .deep
        o.errorRecovery = .revert
        let data = try JSONEncoder().encode(o)
        let back = try JSONDecoder().decode(EngineOptions.self, from: data)
        try assertEqual(back, o)
    }
}
