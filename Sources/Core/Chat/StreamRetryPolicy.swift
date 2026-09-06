// ============================================================================
// StreamRetryPolicy.swift — A print sink that survives stream retries without
// reprinting already-emitted output.
//
// The streaming model response is wrapped in `withRetry`. A retryable error
// thrown mid-stream (rateLimited, concurrentRequest, assetsUnavailable) causes
// `withRetry` to re-run the whole streaming operation from scratch. The model
// emits cumulative snapshots, so a re-run starts from an empty snapshot and
// re-accumulates the same prefix. If each attempt printed its own deltas
// independently, the already-streamed prefix would be reprinted on every retry
// — the user sees duplicated output (#182).
//
// `StreamPrintSink` is the seam. The streaming loop feeds it each cumulative
// snapshot; the sink tracks a high-water mark of how many characters it has
// already emitted and prints only the suffix beyond that mark. Sharing ONE sink
// instance across all retry attempts means a re-run that re-streams an
// already-printed prefix emits nothing until the stream surpasses where the
// previous attempt failed — output is printed exactly once, live, in order.
//
// The sink is an actor so it is Sendable and safe to share across the
// isolation hops a retried async operation crosses. It is pure (no
// FoundationModels dependency) and deterministically unit-testable: feed it a
// scripted sequence of cumulative snapshots simulating a failed-then-retried
// stream and assert each character is emitted exactly once, in order.
// ============================================================================

import Foundation

public actor StreamPrintSink {
    /// Number of characters already emitted (the high-water mark across retries).
    private var emittedCount = 0
    /// The text that has been emitted so far, used to detect divergent retries.
    private var emittedText = ""
    private let emit: @Sendable (String) -> Void

    /// - parameter emit: receives each newly-printable suffix. Defaults to
    ///   writing to stdout and flushing, so deltas appear live.
    public init(emit: @escaping @Sendable (String) -> Void = StreamPrintSink.printAndFlush) {
        self.emit = emit
    }

    /// Feed a cumulative snapshot. Emits only the portion that extends beyond
    /// what has already been printed. When a retry diverges from the already-
    /// printed prefix, the sink marks the discontinuity on stderr and re-emits
    /// the full new content rather than silently splicing two generations (#402).
    public func feed(cumulative content: String) {
        if content.hasPrefix(emittedText) {
            guard content.count > emittedCount else { return }
            let start = content.index(content.startIndex, offsetBy: emittedCount)
            emit(String(content[start...]))
            emittedText = content
            emittedCount = content.count
        } else if emittedText.hasPrefix(content) {
            // Retry re-streaming a prefix we already printed - wait for it
            // to catch up past the high-water mark.
            return
        } else {
            FileHandle.standardError.write(
                Data("\n[apfel: retry diverged from previous output; restarting]\n".utf8)
            )
            emit("\n")
            emit(content)
            emittedText = content
            emittedCount = content.count
        }
    }

    /// Default emit: write to stdout and flush so streaming output is live.
    public static let printAndFlush: @Sendable (String) -> Void = { suffix in
        FileHandle.standardOutput.write(Data(suffix.utf8))
    }
}
