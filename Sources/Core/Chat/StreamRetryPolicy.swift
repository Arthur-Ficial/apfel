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
    private let emit: @Sendable (String) throws -> Void
    private var broken = false

    /// - parameter emit: receives each newly-printable suffix. Defaults to
    ///   writing to stdout and flushing, so deltas appear live. A throwing
    ///   emitter that fails marks the sink broken; subsequent feeds are no-ops.
    public init(emit: @escaping @Sendable (String) throws -> Void = StreamPrintSink.printAndFlush) {
        self.emit = emit
    }

    /// Feed a cumulative snapshot. Emits only the portion that extends beyond
    /// what has already been printed; a shorter or equal snapshot (as seen at
    /// the start of a retry re-run) emits nothing. Once the emitter has
    /// failed (broken pipe), all subsequent feeds are silent no-ops.
    public func feed(cumulative content: String) {
        guard !broken else { return }
        guard content.count > emittedCount else { return }
        let start = content.index(content.startIndex, offsetBy: emittedCount)
        do {
            try emit(String(content[start...]))
        } catch {
            broken = true
            return
        }
        emittedCount = content.count
    }

    /// True once the emitter has failed (e.g. EPIPE on a closed stdout pipe).
    public var isBroken: Bool { broken }

    /// Default emit: write to stdout and flush so streaming output is live.
    ///
    /// Uses the throwing `write(contentsOf:)` variant. The legacy non-throwing
    /// `write(_:)` raises an Objective-C `NSFileHandleOperationException` on
    /// EPIPE (when SIGPIPE is SIG_IGN'd), which Swift cannot catch (#389).
    /// On a broken pipe, exit 141 (128 + SIGPIPE) - the standard UNIX
    /// convention for a consumer that closed the pipe.
    public static let printAndFlush: @Sendable (String) -> Void = { suffix in
        do {
            try FileHandle.standardOutput.write(contentsOf: Data(suffix.utf8))
        } catch {
            exit(141)
        }
    }
}
