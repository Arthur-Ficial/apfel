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

    testAsync("feed: a divergent retry does not splice two generations (#402)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Attempt 1 streams "Hello" then hits a retryable error.
        await sink.feed(cumulative: "Hello")

        // Attempt 2 produces completely different text.
        await sink.feed(cumulative: "Goodbye.")

        let output = recorder.joined
        try assertTrue(output.contains("Goodbye."),
            "the full second-attempt text must appear in output, got: \(output)")
        try assertTrue(!output.contains("Helloye"),
            "spliced garbage must never appear, got: \(output)")
    }

    testAsync("feed: a shorter divergent retry emits the full new text (#402)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Attempt 1 streams a longer response.
        await sink.feed(cumulative: "Hello world")

        // Attempt 2 returns shorter, completely different text.
        await sink.feed(cumulative: "Bye")

        let output = recorder.joined
        try assertTrue(output.contains("Bye"),
            "the full shorter retry text must appear, got: \(output)")
        try assertTrue(!output.contains("Hello worldBye"),
            "must not simply append divergent text, got: \(output)")
    }

    testAsync("feed: a divergent retry followed by growth emits correctly (#402)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Attempt 1 partial.
        await sink.feed(cumulative: "Hello")

        // Attempt 2 diverges, then grows.
        await sink.feed(cumulative: "Good")
        await sink.feed(cumulative: "Goodbye.")

        let output = recorder.joined
        try assertTrue(output.contains("Goodbye."),
            "full divergent text including growth must appear, got: \(output)")
    }

    // #543: delta math must use Unicode scalars, not Characters. A snapshot
    // boundary inside a grapheme cluster must not lose the trailing scalar(s).

    testAsync("feed: CRLF split across snapshots emits the LF (#543)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Snapshot 1 delivers CR; snapshot 2 merges it with LF into one
        // Character (\r\n). Under Character counting the count would not grow
        // (6 -> 6) and the LF would be silently dropped.
        await sink.feed(cumulative: "hello\r")
        await sink.feed(cumulative: "hello\r\n")

        try assertEqual(recorder.joined, "hello\r\n",
            "the LF after a mid-cluster CRLF split must not be lost")
        try assertEqual(recorder.chunks, ["hello\r", "\n"],
            "second chunk must be the bare LF scalar")
    }

    testAsync("feed: combining accent split across snapshots emits the accent (#543)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // "e" then "e\u{0301}" (e + combining acute accent = e). Under
        // Character counting "cafe" is 4 Characters and so is "cafe\u{0301}"
        // (the combining accent merges with the preceding e), so the guard
        // would suppress the accent entirely.
        await sink.feed(cumulative: "cafe")
        await sink.feed(cumulative: "cafe\u{0301}")

        try assertEqual(recorder.joined, "cafe\u{0301}",
            "combining accent must not be lost when it merges with the prior scalar")
        try assertEqual(recorder.chunks, ["cafe", "\u{0301}"],
            "second chunk must be the bare combining acute accent")
    }

    testAsync("feed: emoji skin-tone modifier split across snapshots emits the modifier (#543)") {
        let recorder = SinkRecorder()
        let sink = StreamPrintSink(emit: { recorder.append($0) })

        // Waving hand U+1F44B, then skin-tone modifier U+1F3FD. Together they
        // form one Character; split across snapshots, the modifier must arrive.
        await sink.feed(cumulative: "hi \u{1F44B}")
        await sink.feed(cumulative: "hi \u{1F44B}\u{1F3FD}")

        try assertEqual(recorder.joined, "hi \u{1F44B}\u{1F3FD}",
            "skin-tone modifier must not be lost")
        try assertEqual(recorder.callCount, 2, "two chunks: base text, then modifier")
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
