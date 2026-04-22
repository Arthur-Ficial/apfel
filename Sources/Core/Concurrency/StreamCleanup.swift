// ============================================================================
// StreamCleanup.swift — Idempotent one-shot async cleanup
// Used by the SSE streaming path to ensure semaphore release + log flush
// happen exactly once even when both stream completion and client disconnect fire.
// ============================================================================

import Foundation

/// Ensures asynchronous cleanup work executes at most once.
///
/// The streaming server path can trigger cleanup from multiple places, such as
/// normal completion and client disconnect handling. `StreamCleanup` provides
/// a tiny actor that turns those competing signals into one idempotent cleanup
/// execution.
public actor StreamCleanup {
    private var didRun = false

    /// Creates a cleanup coordinator in the "not yet run" state.
    public init() {}

    /// Runs the cleanup operation exactly once.
    ///
    /// Subsequent callers return immediately without invoking `operation`.
    ///
    /// - Parameter operation: The asynchronous cleanup work to perform.
    public func run(_ operation: @Sendable () async -> Void) async {
        if didRun { return }
        didRun = true
        await operation()
    }
}
