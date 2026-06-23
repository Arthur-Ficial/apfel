// ============================================================================
// TokenBudgetReport.swift — Pure token budget preflight types (ApfelCore)
// ============================================================================

import Foundation

/// Per-file token count for JSON breakdown.
public struct FileTokenCount: Sendable, Equatable {
    public let path: String
    public let tokens: Int

    public init(path: String, tokens: Int) {
        self.path = path
        self.tokens = tokens
    }
}

/// Result of a `--count-tokens` preflight. All counts are supplied by the caller
/// (typically TokenCounter in the main target); this type only aggregates and
/// computes budget / fits.
public struct TokenBudgetReport: Sendable, Equatable {
    public let promptTokens: Int
    public let systemTokens: Int
    public let fileTokens: [FileTokenCount]
    public let mcpToolTokens: Int
    public let total: Int
    public let budget: Int
    public let outputReserve: Int
    public let contextSize: Int
    public let approximate: Bool

    public var fits: Bool {
        Self.fits(total: total, budget: budget)
    }

    public init(
        promptTokens: Int,
        systemTokens: Int,
        fileTokens: [FileTokenCount],
        mcpToolTokens: Int,
        total: Int,
        budget: Int,
        outputReserve: Int,
        contextSize: Int,
        approximate: Bool
    ) {
        self.promptTokens = promptTokens
        self.systemTokens = systemTokens
        self.fileTokens = fileTokens
        self.mcpToolTokens = mcpToolTokens
        self.total = total
        self.budget = budget
        self.outputReserve = outputReserve
        self.contextSize = contextSize
        self.approximate = approximate
    }

    public static func fits(total: Int, budget: Int) -> Bool {
        total <= budget
    }

    public static func inputBudget(contextSize: Int, outputReserve: Int) -> Int {
        contextSize - outputReserve
    }

    public static func make(
        promptTokens: Int,
        systemTokens: Int,
        fileTokens: [FileTokenCount],
        mcpToolTokens: Int,
        total: Int,
        contextSize: Int,
        outputReserve: Int,
        approximate: Bool
    ) -> TokenBudgetReport {
        let budget = inputBudget(contextSize: contextSize, outputReserve: outputReserve)
        return TokenBudgetReport(
            promptTokens: promptTokens,
            systemTokens: systemTokens,
            fileTokens: fileTokens,
            mcpToolTokens: mcpToolTokens,
            total: total,
            budget: budget,
            outputReserve: outputReserve,
            contextSize: contextSize,
            approximate: approximate
        )
    }
}
