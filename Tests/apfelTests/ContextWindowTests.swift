// ============================================================================
// ContextWindowTests.swift — measured vs assumed context window (#491)
//
// The SDK reports contextSize 0 while the model is warming (#192), so apfel
// falls back to an assumed floor. The floor itself is correct and must stay -
// it prevents the #192 deadlock. What must NOT happen is reporting that
// fallback as if it were a real reading: on macOS 27 the assumed 4096 is half
// the true 8192 window, and /health serves it to OpenAI clients.
// ============================================================================

import Foundation
import ApfelCore

func runContextWindowTests() {
    test("a positive SDK reading is reported as measured") {
        var tracker = ContextWindowTracker()
        let w = tracker.observe(8192)
        try assertEqual(w.tokens, 8192)
        try assertTrue(w.isMeasured, "a real SDK reading must be flagged as measured")
    }

    // The heart of #491: 4096 measured and 4096 assumed are the same number
    // but not the same claim. Only the flag can tell them apart.
    test("a real 4096 reading is measured, an assumed 4096 is not") {
        var measured = ContextWindowTracker()
        let real = measured.observe(4096)
        var assumed = ContextWindowTracker()
        let guess = assumed.observe(0)

        try assertEqual(real.tokens, guess.tokens, "same number ...")
        try assertTrue(real.isMeasured, "... but a real 4096 reading is measured")
        try assertTrue(!guess.isMeasured, "... and an assumed 4096 is not")
    }

    test("a zero reading falls back to the assumed floor, flagged as not measured") {
        var tracker = ContextWindowTracker()
        let w = tracker.observe(0)
        try assertEqual(w.tokens, ContextWindowTracker.assumedTokens)
        try assertTrue(!w.isMeasured, "the floor is a guess and must never claim to be measured")
    }

    test("the assumed floor is 4096") {
        try assertEqual(ContextWindowTracker.assumedTokens, 4096)
    }

    test("the high-water mark survives an SDK regression to zero") {
        var tracker = ContextWindowTracker()
        _ = tracker.observe(8192)
        let after = tracker.observe(0)
        try assertEqual(after.tokens, 8192, "must not drop back to the floor once the real size is known")
        try assertTrue(after.isMeasured, "a remembered real reading is still a measurement")
    }

    test("the high-water mark only ever rises") {
        var tracker = ContextWindowTracker()
        _ = tracker.observe(8192)
        let lower = tracker.observe(4096)
        try assertEqual(lower.tokens, 8192)
    }

    test("a negative reading is treated as no reading") {
        var tracker = ContextWindowTracker()
        let w = tracker.observe(-1)
        try assertEqual(w.tokens, ContextWindowTracker.assumedTokens)
        try assertTrue(!w.isMeasured)
    }

    test("the assumed window is never zero or negative (#192 deadlock guard)") {
        var tracker = ContextWindowTracker()
        try assertTrue(tracker.observe(0).tokens > 0)
    }

    // The rendering is what a user actually sees, so the hedge is tested as
    // behaviour, not left to the call site to remember.
    test("a measured window renders as a plain token count") {
        let w = ContextWindow(tokens: 8192, isMeasured: true)
        try assertEqual(w.displayText, "8192 tokens")
    }

    test("an assumed window says so in the rendering") {
        let w = ContextWindow(tokens: 4096, isMeasured: false)
        try assertTrue(w.displayText.hasPrefix("4096 tokens "),
                       "the number stays first so the line still scans")
        try assertTrue(w.displayText.contains("assumed"),
                       "an assumed window must not read as a measurement")
    }
}
