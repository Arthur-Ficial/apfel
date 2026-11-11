// ============================================================================
// TokenEstimateTests.swift - the chars/4 fallback prices transcript framing
// (#544: trimming on macOS 26.0-26.3 kept ~1000 tokens too many)
// ============================================================================

import Foundation
import ApfelCore

func runTokenEstimateTests() {
    test("transcript fallback adds per-entry and fixed framing") {
        // Measured on macOS 27.0.1: +4.5 tokens per message, +66 per transcript.
        try assertEqual(TokenEstimate.transcriptFallback(textTokens: 1000, entries: 0), 1000)
        try assertEqual(TokenEstimate.transcriptFallback(textTokens: 1000, entries: 1),
                        1000 + TokenEstimate.fixedFramingTokens + TokenEstimate.perEntryFramingTokens)
        try assertEqual(TokenEstimate.transcriptFallback(textTokens: 981, entries: 41), 981 + 64 + 41 * 5)
    }

    test("the estimate covers the measured real count for a 41-message transcript") {
        // Real prompt_tokens 1218 for 20 note pairs + 1 prompt (3927 chars).
        let estimate = TokenEstimate.transcriptFallback(textTokens: 3927 / 4, entries: 41)
        try assertTrue(estimate >= 1218, "estimate \(estimate) must not undercount the real 1218")
        try assertTrue(estimate <= 1218 * 11 / 10, "estimate \(estimate) should stay within 10% above")
    }
}
