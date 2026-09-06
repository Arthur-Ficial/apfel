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

// Exit status a UNIX filter uses when stdout's consumer closes the pipe.
// 128 + SIGPIPE (13) = 141.
public let brokenPipeExitStatus: Int32 = 141

public actor StreamPrintSink {
    /// Number of characters already emitted (the high-water mark across retries).
    private var emittedCount = 0
    private let emit: @Sendable (String) -> Void

    /// - parameter emit: receives each newly-printable suffix. Defaults to
    ///   writing to stdout and flushing, so deltas appear live.
    public init(emit: @escaping @Sendable (String) -> Void = StreamPrintSink.printAndFlush) {
        self.emit = emit
    }

    /// Feed a cumulative snapshot. Emits only the portion that extends beyond
    /// what has already been printed; a shorter or equal snapshot (as seen at
    /// the start of a retry re-run) emits nothing.
    public func feed(cumulative content: String) {
        guard content.count > emittedCount else { return }
        let start = content.index(content.startIndex, offsetBy: emittedCount)
        emit(String(content[start...]))
        emittedCount = content.count
    }

    /// Default emit: write to stdout and flush so streaming output is live.
    ///
    /// Uses the throwing `write(contentsOf:)` overload. The legacy non-throwing
    /// `write(_:)` raises an ObjC `NSFileHandleOperationException` on EPIPE
    /// that Swift cannot catch, so `apfel --stream ... | head -1` aborted with
    /// a stack trace (#389). With SIGPIPE ignored process-wide (main.swift:57),
    /// a closed reader surfaces as EPIPE here. A consumer that stopped reading
    /// is normal for a UNIX filter - exit the way SIGPIPE would have, quietly.
    public static let printAndFlush: @Sendable (String) -> Void = { suffix in
        do {
            try FileHandle.standardOutput.write(contentsOf: Data(suffix.utf8))
        } catch {
            exit(brokenPipeExitStatus)
        }
    }
}
