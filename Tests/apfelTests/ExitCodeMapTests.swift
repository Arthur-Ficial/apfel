// ============================================================================
// ExitCodeMapTests.swift — Lockdown for ApfelError -> CLI exit-code mapping.
//
// Exit codes are a stable CLI contract (documented in the man page). Every
// `ApfelError` case must map to the correct exit code, and changing that
// mapping must be a deliberate, visible diff.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runExitCodeMapTests() {
    test("ApfelExitCodes: guardrailViolation -> exitGuardrail (3)") {
        try assertEqual(ApfelExitCodes.code(for: .guardrailViolation), 3)
    }
    test("ApfelExitCodes: refusal -> exitGuardrail (3) — same as guardrail for script compat") {
        try assertEqual(ApfelExitCodes.code(for: .refusal("any explanation")), 3)
    }
    test("ApfelExitCodes: refusal exit code is independent of associated text") {
        try assertEqual(ApfelExitCodes.code(for: .refusal("")), 3)
        try assertEqual(ApfelExitCodes.code(for: .refusal("short")), 3)
        try assertEqual(ApfelExitCodes.code(for: .refusal(String(repeating: "x", count: 10_000))), 3)
    }
    test("ApfelExitCodes: contextOverflow -> 4") {
        try assertEqual(ApfelExitCodes.code(for: .contextOverflow), 4)
    }
    test("ApfelExitCodes: rateLimited and concurrentRequest -> 6") {
        try assertEqual(ApfelExitCodes.code(for: .rateLimited), 6)
        try assertEqual(ApfelExitCodes.code(for: .concurrentRequest), 6)
    }
    test("ApfelExitCodes: assetsUnavailable -> runtime error (1), not modelUnavailable") {
        // Rationale: exitModelUnavailable (5) is for the availability *precheck*
        // (Apple Intelligence disabled, device ineligible). assetsUnavailable is a
        // transient loading state that the model itself surfaces during inference.
        try assertEqual(ApfelExitCodes.code(for: .assetsUnavailable), 1)
    }
    test("ApfelExitCodes: all remaining cases -> runtime error (1)") {
        try assertEqual(ApfelExitCodes.code(for: .unsupportedGuide), 1)
        try assertEqual(ApfelExitCodes.code(for: .decodingFailure("x")), 1)
        try assertEqual(ApfelExitCodes.code(for: .unsupportedLanguage("x")), 1)
        try assertEqual(ApfelExitCodes.code(for: .toolExecution("x")), 1)
        try assertEqual(ApfelExitCodes.code(for: .unknown("x")), 1)
    }
    test("ApfelExitCodes: constants match documented values") {
        try assertEqual(ApfelExitCodes.success, 0)
        try assertEqual(ApfelExitCodes.runtimeError, 1)
        try assertEqual(ApfelExitCodes.usageError, 2)
        try assertEqual(ApfelExitCodes.guardrail, 3)
        try assertEqual(ApfelExitCodes.contextOverflow, 4)
        try assertEqual(ApfelExitCodes.modelUnavailable, 5)
        try assertEqual(ApfelExitCodes.rateLimited, 6)
    }
}
