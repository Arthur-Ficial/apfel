// ============================================================================
// ContextWindow.swift — measured vs assumed context-window size (#491)
//
// FoundationModels reports contextSize 0 while the model warms up (#192), so
// apfel needs a usable number before the real one arrives. The floor below
// supplies it and must stay: without it inputBudget goes negative, generation
// is rejected, and the model never warms.
//
// What the floor must NOT do is pass itself off as a measurement. On macOS 26
// the assumed 4096 happens to equal the true window, so the two are
// indistinguishable; on macOS 27 the true window is larger and the assumption
// under-reports it. Callers that show the number to a user, or put it on the
// wire in /health, need to know which one they are holding.
// ============================================================================

import Foundation

/// A context-window size together with whether it was actually observed.
public struct ContextWindow: Sendable, Equatable {
    /// Window size in tokens. Always positive.
    public let tokens: Int

    /// `true` when `tokens` came from the model, `false` when it is the
    /// assumed floor standing in for a reading that has not arrived yet.
    public let isMeasured: Bool

    public init(tokens: Int, isMeasured: Bool) {
        self.tokens = tokens
        self.isMeasured = isMeasured
    }

    /// Rendering for user-facing output such as `apfel --model-info`.
    ///
    /// The number stays first so the line still scans; the hedge is appended
    /// only when the value is the assumed floor.
    public var displayText: String {
        isMeasured
            ? "\(tokens) tokens"
            : "\(tokens) tokens (assumed - the model has not reported a size yet)"
    }
}

/// Tracks the largest context size the model has reported so far.
///
/// The model can report a real size and then regress to 0 on a later call
/// (observed on macOS 27 cold start, #192), so the highest value ever seen
/// wins. Until a positive value arrives, `assumedTokens` stands in and the
/// result is flagged `isMeasured == false`.
public struct ContextWindowTracker: Sendable {
    /// Stand-in window used before the model reports a real size.
    ///
    /// 4096 is the smallest window any shipped Apple Intelligence model has
    /// used. It is a lower bound, not a claim about the current machine -
    /// which is precisely why results carrying it report `isMeasured == false`.
    public static let assumedTokens = 4096

    private var highWater = 0

    public init() {}

    /// Fold one raw `SystemLanguageModel.contextSize` reading into the tracker
    /// and return the window to use now.
    public mutating func observe(_ rawReading: Int) -> ContextWindow {
        if rawReading > highWater {
            highWater = rawReading
        }
        guard highWater > 0 else {
            return ContextWindow(tokens: Self.assumedTokens, isMeasured: false)
        }
        return ContextWindow(tokens: highWater, isMeasured: true)
    }
}
