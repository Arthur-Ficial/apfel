// ============================================================================
// StreamCleanupTests.swift — Baseline coverage for the only previously-untested
// public ApfelCore type. Locks idempotency, ordering, and actor-isolated
// Sendable semantics ahead of the library product exposure in #105.
// ============================================================================

import Foundation
import ApfelCore

func runStreamCleanupTests() {
    testAsync("run executes the operation exactly once") {
        let cleanup = StreamCleanup()
        let counter = CleanupCounter()
        await cleanup.run { await counter.bump() }
        let count = await counter.value
        guard count == 1 else { throw TestFailure("expected 1 call, got \(count)") }
    }

    testAsync("subsequent run calls are no-ops (idempotent)") {
        let cleanup = StreamCleanup()
        let counter = CleanupCounter()
        await cleanup.run { await counter.bump() }
        await cleanup.run { await counter.bump() }
        await cleanup.run { await counter.bump() }
        let count = await counter.value
        guard count == 1 else { throw TestFailure("expected 1 call after 3 attempts, got \(count)") }
    }

    testAsync("only the first operation runs when multiple distinct closures race") {
        // Two independent closures submitted back-to-back — only the first wins.
        let cleanup = StreamCleanup()
        let witness = CleanupWitness()
        await cleanup.run { await witness.record("first") }
        await cleanup.run { await witness.record("second") }
        let log = await witness.log
        guard log == ["first"] else { throw TestFailure("expected [first] only, got \(log)") }
    }

    testAsync("concurrent run calls on the same instance still execute at most once") {
        let cleanup = StreamCleanup()
        let counter = CleanupCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { await cleanup.run { await counter.bump() } }
            }
        }
        let count = await counter.value
        guard count == 1 else {
            throw TestFailure("expected 1 call under 50-way concurrency, got \(count)")
        }
    }

    testAsync("separate StreamCleanup instances are independent") {
        let a = StreamCleanup()
        let b = StreamCleanup()
        let counter = CleanupCounter()
        await a.run { await counter.bump() }
        await b.run { await counter.bump() }
        let count = await counter.value
        guard count == 2 else { throw TestFailure("expected 2 calls across 2 instances, got \(count)") }
    }

    testAsync("a StreamCleanup that was never invoked performs no work") {
        _ = StreamCleanup()  // constructed and dropped; passes by not crashing
    }

    // Compile-time: StreamCleanup must remain Sendable so it can cross
    // isolation domains (request → onTermination handler). If this line stops
    // compiling, the library surface changed in a breaking way.
    testAsync("StreamCleanup conforms to Sendable") {
        let _: any Sendable = StreamCleanup()
    }
}

actor CleanupCounter {
    private(set) var value = 0
    func bump() { value += 1 }
}

actor CleanupWitness {
    private(set) var log: [String] = []
    func record(_ entry: String) { log.append(entry) }
}
