// ============================================================================
// TokenBudgetTests.swift — Pure token budget report logic (ApfelCore)
// ============================================================================

import Foundation
import ApfelCore

func runTokenBudgetTests() {

    test("fits returns true when total equals budget") {
        try assertTrue(TokenBudgetReport.fits(total: 3584, budget: 3584))
    }

    test("fits returns true when total is under budget") {
        try assertTrue(TokenBudgetReport.fits(total: 100, budget: 3584))
    }

    test("fits returns false when total exceeds budget") {
        try assertTrue(!TokenBudgetReport.fits(total: 3585, budget: 3584))
    }

    test("inputBudget subtracts output reserve from context size") {
        try assertEqual(TokenBudgetReport.inputBudget(contextSize: 4096, outputReserve: 512), 3584)
    }

    test("inputBudget respects custom output reserve") {
        try assertEqual(TokenBudgetReport.inputBudget(contextSize: 4096, outputReserve: 256), 3840)
    }

    test("make computes budget and fits from totals") {
        let report = TokenBudgetReport.make(
            promptTokens: 42,
            systemTokens: 128,
            fileTokens: [FileTokenCount(path: "README.md", tokens: 890)],
            mcpToolTokens: 340,
            total: 1400,
            contextSize: 4096,
            outputReserve: 512,
            approximate: false
        )
        try assertEqual(report.budget, 3584)
        try assertTrue(report.fits)
        try assertEqual(report.promptTokens, 42)
        try assertEqual(report.systemTokens, 128)
        try assertEqual(report.fileTokens.count, 1)
        try assertEqual(report.fileTokens[0].path, "README.md")
        try assertEqual(report.mcpToolTokens, 340)
        try assertEqual(report.total, 1400)
        try assertEqual(report.outputReserve, 512)
        try assertEqual(report.contextSize, 4096)
        try assertFalse(report.approximate)
    }

    test("make marks over-budget when total exceeds budget") {
        let report = TokenBudgetReport.make(
            promptTokens: 4000,
            systemTokens: 0,
            fileTokens: [],
            mcpToolTokens: 0,
            total: 4000,
            contextSize: 4096,
            outputReserve: 512,
            approximate: false
        )
        try assertTrue(!report.fits)
    }
}

func assertFalse(_ v: Bool, _ msg: String = "") throws {
    try assertTrue(!v, msg.isEmpty ? "Expected false" : msg)
}
