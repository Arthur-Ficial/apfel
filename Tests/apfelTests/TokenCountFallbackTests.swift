// ============================================================================
// TokenCountFallbackTests.swift — Why token counting fell back to chars/4 (ApfelCore)
// ============================================================================

import Foundation
import ApfelCore

func runTokenCountFallbackTests() {

    test("no fallback when OS supports token counting and model is available") {
        let reason = TokenCountFallback.reason(
            modelAvailable: true, osSupportsTokenCounting: true, currentOS: "26.4.0")
        try assertTrue(reason == nil)
    }

    test("OS too old wins even when the model is available (#315)") {
        let reason = TokenCountFallback.reason(
            modelAvailable: true, osSupportsTokenCounting: false, currentOS: "26.3.1")
        try assertEqual(reason, .osTooOld(currentOS: "26.3.1"))
    }

    test("OS too old wins when both the OS is old and the model is unavailable") {
        let reason = TokenCountFallback.reason(
            modelAvailable: false, osSupportsTokenCounting: false, currentOS: "26.1.0")
        try assertEqual(reason, .osTooOld(currentOS: "26.1.0"))
    }

    test("model unavailable when OS is new enough but the model is off") {
        let reason = TokenCountFallback.reason(
            modelAvailable: false, osSupportsTokenCounting: true, currentOS: "26.4.0")
        try assertEqual(reason, .modelUnavailable)
    }

    test("osTooOld message names the required version, the actual OS, and the fallback") {
        let msg = TokenCountFallback.osTooOld(currentOS: "26.3.1").message
        try assertTrue(msg.contains("macOS 26.4"))
        try assertTrue(msg.contains("26.3.1"))
        try assertTrue(msg.contains("chars/4"))
        try assertTrue(!msg.contains("Apple Intelligence unavailable"))
    }

    test("modelUnavailable message names Apple Intelligence and the fallback") {
        let msg = TokenCountFallback.modelUnavailable.message
        try assertTrue(msg.contains("Apple Intelligence unavailable"))
        try assertTrue(msg.contains("chars/4"))
    }

    // #326: osTooOld must not skip session construction (model is available,
    // only the tokenizer API is missing). Skipping drops MCP tool schemas
    // from the count, making --strict false-pass.

    test("osTooOld does not skip session construction (#326)") {
        let fallback = TokenCountFallback.osTooOld(currentOS: "26.3.1")
        try assertFalse(fallback.skipSessionConstruction,
            "osTooOld must not skip session construction - model is available")
    }

    test("modelUnavailable skips session construction") {
        let fallback = TokenCountFallback.modelUnavailable
        try assertTrue(fallback.skipSessionConstruction,
            "modelUnavailable must skip session construction")
    }

    test("nil fallback means no skip (real API usable)") {
        let fallback = TokenCountFallback.reason(
            modelAvailable: true, osSupportsTokenCounting: true, currentOS: "26.4.0")
        try assertTrue(fallback == nil)
    }
}
