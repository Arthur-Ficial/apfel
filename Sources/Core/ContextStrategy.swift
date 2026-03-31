// ============================================================================
// ContextStrategy.swift — Configurable context window management
// Part of ApfelCore — pure data types, no FoundationModels dependency
// ============================================================================

/// Strategy for trimming conversation history when approaching the context limit.
public enum ContextStrategy: String, Codable, Sendable, CaseIterable {
    case newestFirst = "newest-first"
    case oldestFirst = "oldest-first"
    case slidingWindow = "sliding-window"
    case summarize = "summarize"
    case strict = "strict"
}

/// Configuration for context window management.
public struct ContextConfig: Sendable, Equatable {
    public let strategy: ContextStrategy
    public let maxTurns: Int?
    public let outputReserve: Int

    public init(
        strategy: ContextStrategy = .newestFirst,
        maxTurns: Int? = nil,
        outputReserve: Int = 512
    ) {
        self.strategy = strategy
        self.maxTurns = maxTurns
        self.outputReserve = outputReserve
    }

    public static let defaults = ContextConfig()
}
