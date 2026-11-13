// ============================================================================
// PrewarmDecision.swift - Pure CLI prewarm policy (#364)
// Part of ApfelCLI - no FoundationModels dependency
//
// The executable fires a fire-and-forget model prewarm before reading stdin
// or conversation JSON, so the model cold-start overlaps input I/O instead
// of following it serially. This type owns the WHICH-modes decision so the
// policy is unit-testable without the SDK.
// ============================================================================

public enum PrewarmDecision {

    /// Whether the executable should fire a model prewarm for this mode
    /// before consuming input.
    ///
    /// - single/stream: the prewarm overlaps the piped-stdin read.
    /// - chat: the prewarm overlaps the user typing the first message.
    /// - batch: the prewarm overlaps reading the first record (#481).
    /// - serve: excluded - `startServer` owns its own prewarm (#169).
    /// - countTokens: excluded - token counting never calls the model.
    /// - benchmark: excluded - benchmarks manage their own sessions and a
    ///   background prewarm would skew cold-start measurements.
    /// - everything else never generates.
    public static func shouldPrewarm(mode: CLIArguments.Mode) -> Bool {
        switch mode {
        case .single, .stream, .chat, .batch:
            return true
        case .serve, .benchmark, .countTokens, .modelInfo, .update,
             .demos, .completions, .help, .version, .release:
            return false
        }
    }
}
