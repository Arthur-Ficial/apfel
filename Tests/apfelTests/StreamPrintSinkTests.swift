// ============================================================================
// StreamPrintSinkTests.swift — #182: a retryable error mid-stream must not
// reprint already-streamed output.
//
// StreamPrintSink is the seam that decouples the print side-effect from the
// retried streaming operation. These tests simulate the cumulative-snapshot
// sequence a streaming model emits, including a retry that re-streams an
// already-printed prefix from scratch, and assert every character is emitted
// exactly once, in order.
// ============================================================================

import Foundation
import ApfelCore

func runStreamPrintSinkTests() {

    testAsync("feed: a single growing stream emits each delta exactly once, in order") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })
        for snap in ["He", "Hello", "Hello, wo", "Hello, world"] {
            await sink.feed(cumulative: snap)
        }
        let joined = recorder.joined
        try assertEqual(joined, "Hello, world", "concatenated output reconstructs the final content")
        try assertEqual(recorder.chunks, ["He", "llo", ", wo", "rld"], "each chunk is the suffix delta")
    }

    testAsync("feed: a retry that re-streams the printed prefix does NOT reprint it (#182)") {
        // Attempt 1 streams "Hello, wo" then errors mid-stream. withRetry re-runs
        // the operation: attempt 2 restarts from an empty snapshot and re-streams
        // "Hello, world" cumulatively. Sharing ONE sink across both attempts must
        // suppress re-emitting the "Hello, wo" prefix.
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Attempt 1 (fails after "Hello, wo")
        for snap in ["He", "Hello", "Hello, wo"] {
            await sink.feed(cumulative: snap)
        }
        // Attempt 2 (retry) — re-accumulates from scratch and continues past the
        // failure point.
        for snap in ["He", "Hello", "Hello, wo", "Hello, world!"] {
            await sink.feed(cumulative: snap)
        }

        try assertEqual(recorder.joined, "Hello, world!",
            "output is the final content printed exactly once, no duplicated prefix")
        try assertEqual(recorder.callCount, 4,
            "emits: 'He', 'llo', ', wo' (attempt 1) and 'rld!' (attempt 2 continuation) — re-streamed prefix is suppressed")
    }

    testAsync("feed: a shorter snapshot (start of a retry) emits nothing") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })
        await sink.feed(cumulative: "Hello, world")
        await sink.feed(cumulative: "He")   // retry restarting — shorter
        await sink.feed(cumulative: "Hello") // still under the high-water mark
        try assertEqual(recorder.joined, "Hello, world")
        try assertEqual(recorder.callCount, 1, "only the first, longest snapshot emitted")
    }

    testAsync("feed: an equal-length repeated snapshot emits nothing") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })
        await sink.feed(cumulative: "abc")
        await sink.feed(cumulative: "abc")
        try assertEqual(recorder.callCount, 1, "duplicate snapshot is a no-op")
    }

    testAsync("feed: empty snapshots are no-ops") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })
        await sink.feed(cumulative: "")
        await sink.feed(cumulative: "")
        try assertEqual(recorder.callCount, 0, "no output for empty stream")
    }

    testAsync("feed: a throwing emitter marks the sink broken and stops emission (#389)") {
        struct BrokenPipe: Error {}
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { suffix in
            if recorder.callCount >= 1 { throw BrokenPipe() }
            recorder.append(suffix)
        })
        // First feed succeeds.
        await sink.feed(cumulative: "Hello")
        try assertEqual(recorder.joined, "Hello", "first emit succeeds")
        try assertFalse(await sink.isBroken, "not broken yet")

        // Second feed triggers the throw inside the emitter.
        await sink.feed(cumulative: "Hello, world")
        try assertTrue(await sink.isBroken, "sink is broken after emitter throw")
        try assertEqual(recorder.joined, "Hello", "no new output after break")

        // Subsequent feeds are silent no-ops.
        await sink.feed(cumulative: "Hello, world! More text.")
        try assertEqual(recorder.joined, "Hello", "broken sink stays silent")
        try assertTrue(await sink.isBroken, "still broken")
    }

    // StreamPrintSink must be Sendable so it can be shared across the isolation
    // hops a retried async operation crosses.
    testAsync("StreamPrintSink conforms to Sendable") {
        let _: any Sendable = StreamPrintSink(emit: { _ in })
    }
}

/// Thread-safe recorder for the suffixes the sink emits.
final class SinkRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _chunks: [String] = []

    func append(_ s: String) {
        lock.lock(); defer { lock.unlock() }
        _chunks.append(s)
    }
    var chunks: [String] {
        lock.lock(); defer { lock.unlock() }
        return _chunks
    }
    var joined: String { chunks.joined() }
    var callCount: Int { chunks.count }
}
