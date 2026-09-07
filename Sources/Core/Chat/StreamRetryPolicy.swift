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

/// Exit status a UNIX filter reports when stdout's consumer closed the pipe:
/// 128 + SIGPIPE (13). apfel ignores SIGPIPE process-wide (#215), so it has to
/// reproduce that status itself rather than inherit it from the signal.
public let brokenPipeExitStatus: Int32 = 141

/// Write `text` to `handle`, tolerating a consumer that has gone away.
///
/// The legacy non-throwing `FileHandle.write(_:)` converts EPIPE into an
/// Objective-C `NSFileHandleOperationException`. Swift cannot catch an ObjC
/// exception, so that call aborts the process -- which is how the #215 SIGPIPE
/// hardening turned a clean pipe death into a SIGABRT and a stack trace on the
/// user's terminal (#389). The throwing `write(contentsOf:)` overload surfaces
/// the same condition as an ordinary Swift error.
///
/// - Returns: `false` when the write failed, so each caller can choose: stdout
///   is apfel's product and a vanished reader means the work is done, while a
///   lost diagnostic on stderr must never change the exit status.
@discardableResult
public func writeTolerantly(_ text: String, to handle: FileHandle) -> Bool {
    do {
        try handle.write(contentsOf: Data(text.utf8))
        return true
    } catch {
        return false
    }
}

public actor StreamPrintSink {
    /// Number of characters already emitted (the high-water mark across retries).
    private var emittedCount = 0
    /// The text already printed, so a divergent retry can be detected rather
    /// than silently spliced onto the previous attempt's prefix (#402).
    private var emittedText = ""
    private let emit: @Sendable (String) -> Void

    /// - parameter emit: receives each newly-printable suffix. Defaults to
    ///   writing to stdout and flushing, so deltas appear live.
    public init(emit: @escaping @Sendable (String) -> Void = StreamPrintSink.printAndFlush) {
        self.emit = emit
    }

    /// Feed a cumulative snapshot. Emits only the portion that extends beyond
    /// what has already been printed; a shorter or equal snapshot (as seen at
    /// the start of a retry re-run) emits nothing. When a retry diverges from
    /// what was already printed, the discontinuity is signalled and the new
    /// text is emitted in full (#402).
    public func feed(cumulative content: String) {
        if emittedCount > 0 {
            let convergent = content.count <= emittedCount
                ? emittedText.hasPrefix(content)
                : content.hasPrefix(emittedText)
            if !convergent {
                emit("\n[retry: new response]\n")
                emit(content)
                emittedText = content
                emittedCount = content.count
                return
            }
        }
        guard content.count > emittedCount else { return }
        let start = content.index(content.startIndex, offsetBy: emittedCount)
        let delta = String(content[start...])
        emit(delta)
        emittedText = content
        emittedCount = content.count
    }

    /// Default emit: write to stdout and flush so streaming output is live.
    ///
    /// When the consumer closes the pipe (`apfel --stream ... | head -1`) there
    /// is nothing left to stream to, so exit the way SIGPIPE would have --
    /// quietly, with status 141. That is what a UNIX filter does, and apfel's
    /// golden goal leads with being one (#389).
    public static let printAndFlush: @Sendable (String) -> Void = { suffix in
        if !writeTolerantly(suffix, to: FileHandle.standardOutput) {
            exit(brokenPipeExitStatus)
        }
    }
}
