// ============================================================================
// CompletionPolicy.swift - What the CLI does with a finished generation's
// finish reason (#484). Pure, so the decision is unit-testable on injected
// outcomes; CLI.swift applies it.
//
// Without --require-complete a length finish keeps today's behavior
// (#128/#130): print the partial text, warn on stderr, exit as usual.
// With --require-complete a length finish (explicit --max-tokens cap or the
// context window running out mid-generation) is a failure: nothing more is
// written to stdout and the process exits ApfelExitCodes.incomplete (8).
//
// This reports how the engine terminated, nothing else. A response that
// stopped naturally can still be wrong or syntactically incomplete.
// ============================================================================

import ApfelCore

public enum CompletionPolicy {
    public enum Decision: Sendable, Equatable {
        /// Generation ended without truncation. Print as usual.
        case complete
        /// Truncated, flag not set: print the partial text and warn (default).
        case truncatedAllowed
        /// Truncated under --require-complete: no stdout, exit 8.
        case truncatedRejected

        /// Whether the response may be written to stdout.
        public var writesStdout: Bool { self != .truncatedRejected }

        /// The exit code this decision forces, or nil to keep the normal one.
        public var exitCode: Int32? {
            self == .truncatedRejected ? ApfelExitCodes.incomplete : nil
        }

        /// Whether the default truncation warning goes to stderr.
        public var warnsTruncation: Bool { self == .truncatedAllowed }
    }

    /// Decide what to do with a response that ended with `finishReason`.
    /// Only `.length` counts as incomplete; other finish reasons keep their
    /// established handling.
    public static func decide(finishReason: FinishReason, requireComplete: Bool) -> Decision {
        guard finishReason == .length else { return .complete }
        return requireComplete ? .truncatedRejected : .truncatedAllowed
    }

    /// stderr error line for `.truncatedRejected`.
    public static let incompleteMessage =
        "incomplete response (finish_reason=length): generation stopped at the token cap or the context window; --require-complete treats that as a failure"
}
