// ============================================================================
// StreamTaskBox.swift — Synchronous Sendable box for the streaming Task.
// Holds the task so the response continuation's onTermination handler can
// cancel it on client disconnect.
//
// Implementation note: uses OSAllocatedUnfairLock (Sendable in Swift 6) rather
// than an actor so set/cancel stay synchronous. An actor would race with
// onTermination, since "schedule a Task to set" can be reordered against
// "schedule a Task to cancel" and leave the streaming task running after
// disconnect.
// ============================================================================

import Foundation
import os

public final class StreamTaskBox: Sendable {
    private let storage = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    public init() {}

    public func set(_ task: Task<Void, Never>) {
        storage.withLock { $0 = task }
    }

    public func cancel() {
        let task = storage.withLock { $0 }
        task?.cancel()
    }

    /// Test-only: returns 0 if empty, 1 if a task is held.
    public var taskCount: Int { storage.withLock { $0 == nil ? 0 : 1 } }
}
