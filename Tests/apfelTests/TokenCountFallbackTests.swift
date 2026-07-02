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

    test("transientError message names the runtime error and the fallback (#327)") {
        let msg = TokenCountFallback.transientError.message
        try assertTrue(msg.contains("error during counting"))
        try assertTrue(msg.contains("chars/4"))
        try assertTrue(!msg.contains("Apple Intelligence unavailable"))
        try assertTrue(!msg.contains("macOS 26.4"))
    }

    test("reason returns nil even when transientError exists as a case (#327)") {
        let reason = TokenCountFallback.reason(
            modelAvailable: true, osSupportsTokenCounting: true, currentOS: "26.5.0")
        try assertTrue(reason == nil)
    }
}
