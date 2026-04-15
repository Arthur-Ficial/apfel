// ============================================================================
// StreamCleanup.swift — Idempotent one-shot async cleanup
// Used by the SSE streaming path to ensure semaphore release + log flush
// happen exactly once even when both stream completion and client disconnect fire.
// ============================================================================

import Foundation

public actor StreamCleanup {
    private var didRun = false

    public init() {}

    public func run(_ operation: @Sendable () async -> Void) async {
        if didRun { return }
        didRun = true
        await operation()
    }
}
