// ============================================================================
// TraceBufferTests.swift — Concurrency safety + behavior of TraceBuffer actor
// ============================================================================

import Foundation
import ApfelCore

func runTraceBufferTests() {
    testAsync("starts with seeded events") {
        let buf = TraceBuffer(events: ["a", "b"])
        let snap = await buf.snapshot()
        guard snap == ["a", "b"] else { throw TestFailure("seed lost: \(snap)") }
    }

    testAsync("append preserves order") {
        let buf = TraceBuffer(events: [])
        await buf.append("first")
        await buf.append("second")
        await buf.append("third")
        let snap = await buf.snapshot()
        guard snap == ["first", "second", "third"] else { throw TestFailure("order: \(snap)") }
    }

    testAsync("snapshot is a copy, not a live view") {
        let buf = TraceBuffer(events: ["x"])
        let s1 = await buf.snapshot()
        await buf.append("y")
        let s2 = await buf.snapshot()
        guard s1 == ["x"] else { throw TestFailure("snapshot mutated: \(s1)") }
        guard s2 == ["x", "y"] else { throw TestFailure("second: \(s2)") }
    }

    testAsync("concurrent appends preserve every entry") {
        let buf = TraceBuffer(events: [])
        let count = 200
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask { await buf.append("e\(i)") }
            }
        }
        let snap = await buf.snapshot()
        guard snap.count == count else {
            throw TestFailure("lost events under concurrency: got \(snap.count) of \(count)")
        }
        let unique = Set(snap)
        guard unique.count == count else {
            throw TestFailure("duplicates under concurrency: \(unique.count) unique")
        }
    }
}

func runStreamTaskBoxTests() {
    testAsync("set + cancel cancels the held task") {
        let box = StreamTaskBox()
        let observed = ObservedFlag()
        let t: Task<Void, Never> = Task {
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch {
                await observed.markCancelled()
            }
        }
        box.set(t)
        box.cancel()
        _ = await t.value
        let cancelled = await observed.wasCancelled
        guard cancelled else { throw TestFailure("task was not cancelled") }
    }

    test("cancel before set is a no-op (no crash)") {
        let box = StreamTaskBox()
        box.cancel()
        try assertEqual(box.taskCount, 0)
    }

    test("set replaces previous task") {
        let box = StreamTaskBox()
        let t1: Task<Void, Never> = Task { _ = try? await Task.sleep(nanoseconds: 1_000_000) }
        let t2: Task<Void, Never> = Task { _ = try? await Task.sleep(nanoseconds: 1_000_000) }
        box.set(t1)
        box.set(t2)
        try assertEqual(box.taskCount, 1)
    }
}

actor ObservedFlag {
    private(set) var wasCancelled = false
    func markCancelled() { wasCancelled = true }
}
