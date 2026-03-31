// ============================================================================
// ContextStrategyTests.swift — Unit tests for ContextStrategy and ContextConfig
// ============================================================================

import ApfelCore

func runContextStrategyTests() {
    test("ContextStrategy raw values") {
        try assertEqual(ContextStrategy.newestFirst.rawValue, "newest-first")
        try assertEqual(ContextStrategy.oldestFirst.rawValue, "oldest-first")
        try assertEqual(ContextStrategy.slidingWindow.rawValue, "sliding-window")
        try assertEqual(ContextStrategy.summarize.rawValue, "summarize")
        try assertEqual(ContextStrategy.strict.rawValue, "strict")
    }

    test("ContextStrategy allCases has 5 entries") {
        try assertEqual(ContextStrategy.allCases.count, 5)
    }

    test("ContextStrategy init from valid raw value") {
        try assertNotNil(ContextStrategy(rawValue: "newest-first"))
        try assertNotNil(ContextStrategy(rawValue: "strict"))
    }

    test("ContextStrategy init from invalid raw value returns nil") {
        try assertNil(ContextStrategy(rawValue: "invalid"))
        try assertNil(ContextStrategy(rawValue: ""))
    }

    test("ContextConfig defaults") {
        let cfg = ContextConfig.defaults
        try assertEqual(cfg.strategy, .newestFirst)
        try assertNil(cfg.maxTurns)
        try assertEqual(cfg.outputReserve, 512)
    }

    test("ContextConfig custom values") {
        let cfg = ContextConfig(strategy: .slidingWindow, maxTurns: 6, outputReserve: 256)
        try assertEqual(cfg.strategy, .slidingWindow)
        try assertEqual(cfg.maxTurns, 6)
        try assertEqual(cfg.outputReserve, 256)
    }

    test("ContextConfig equality") {
        let a = ContextConfig(strategy: .strict, outputReserve: 300)
        let b = ContextConfig(strategy: .strict, outputReserve: 300)
        let c = ContextConfig(strategy: .newestFirst, outputReserve: 300)
        try assertTrue(a == b)
        try assertTrue(a != c)
    }

    test("ContextConfig zero-arg init matches defaults") {
        try assertTrue(ContextConfig() == ContextConfig.defaults)
    }
}
