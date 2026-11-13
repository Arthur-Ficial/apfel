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

import Foundation
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

    /// Plain-language name of the truncation cause. Nil (unknown) keeps the
    /// neutral wording that names both possibilities.
    static func causePhrase(_ cause: TruncationCause?) -> String {
        switch cause {
        case .tokenCap(let n): return "the --max-tokens \(n) cap was reached"
        case .contextWindow: return "the context window ran out"
        case nil: return "generation stopped at the token cap or the context window"
        }
    }

    /// stderr error line for `.truncatedRejected`, naming the real cause.
    package static func incompleteMessage(cause: TruncationCause?) -> String {
        "incomplete response (finish_reason=length): \(causePhrase(cause)); --require-complete treats that as a failure"
    }

    /// Default stderr warning for a length finish without `--require-complete`
    /// (output was still printed). Mentions the context window only when it
    /// really was the cause; an explicit cap is reported as the cap.
    package static func lengthWarning(cause: TruncationCause?) -> String {
        switch cause {
        case .tokenCap(let n):
            return "response truncated: the --max-tokens \(n) cap was reached (finish_reason=length)."
        case .contextWindow, nil:
            return "response truncated at the context window (finish_reason=length). Pass --max-tokens to control the cap explicitly."
        }
    }

    // MARK: - Exactness of the finish signal (PR #551 review)

    /// Note for stderr when this Mac cannot tell an explicit cap from a
    /// natural stop: the explicit-cap finish reason compares completion tokens
    /// to the cap, and below macOS 26.4 (no on-device tokenizer API, no runtime
    /// usage report) those tokens are the chars/4 estimate, wrong in both
    /// directions. Nil when the signal is exact or no explicit cap is set.
    /// `.modelUnavailable` is left to the availability gate.
    /// `jsonEnvelope`: the run prints the `-o json` envelope, so the note also
    /// says why `finish_reason` is missing there; plain output has no
    /// envelope to mention (#564).
    package static func unknownFinishNote(
        maxTokens: Int?, tokenCountFallback: TokenCountFallback?, jsonEnvelope: Bool = false
    ) -> String? {
        guard let maxTokens, case .osTooOld(let currentOS) = tokenCountFallback else { return nil }
        let note = "cannot tell whether the --max-tokens \(maxTokens) cap cut this response: "
            + "exact finish detection needs the on-device tokenizer API (macOS 26.4+), "
            + "this Mac runs macOS \(currentOS)"
        return note + (jsonEnvelope ? "; finish_reason is left out of the JSON envelope." : ".")
    }

    /// The finish reason apfel may report as fact, or nil when it is unknown.
    /// With an approximate signal an estimated `stop`, or a `length` from the
    /// estimated cap comparison, is unknown; a context-window cut-off (a
    /// thrown error) and non-length outcomes are exact on every OS. So is a
    /// matched `--stop` sequence (#483): the delimiter was observed, no token
    /// count is involved, so its `stop` is reported as fact.
    package static func reportedFinishReason(
        _ reason: FinishReason, truncation: TruncationCause?, finishSignalExact: Bool,
        stopMatched: Bool = false
    ) -> FinishReason? {
        if finishSignalExact { return reason }
        if stopMatched && reason == .stop { return reason }
        switch reason {
        case .toolCalls, .contentFilter: return reason
        case .length where truncation == .contextWindow: return reason
        case .stop, .length: return nil
        }
    }

    // MARK: - Preflight (PR #551 review)

    /// Exit code for `preflightRefusal`: the usage error (2). The flag
    /// combination cannot be honored on this Mac and nothing was generated,
    /// so it is not `incomplete` (8, "generated and was truncated").
    public static let preflightExitCode: Int32 = ApfelExitCodes.usageError

    /// Refuse `--require-complete` with an explicit output cap when this Mac
    /// cannot detect that cap. The explicit-cap finish reason compares
    /// completion tokens to the cap; without the on-device tokenizer API
    /// (macOS < 26.4, which also has no runtime usage report) those tokens are
    /// the chars/4 estimate, so a cut-off answer can read as `stop`. The flag
    /// must not guess. Context-window truncation is a thrown error, an exact
    /// signal on every OS, so without an explicit cap nothing is refused.
    ///
    /// Capability comes from the #315 `TokenCountFallback` plumbing, never an
    /// OS check here. `.modelUnavailable` is left to the availability gate.
    /// Returns the stderr message, or nil when the run may proceed.
    public static func preflightRefusal(
        requireComplete: Bool,
        maxTokens: Int?,
        tokenCountFallback: TokenCountFallback?
    ) -> String? {
        guard requireComplete, maxTokens != nil,
              case .osTooOld(let currentOS) = tokenCountFallback else { return nil }
        return "--require-complete cannot detect a --max-tokens cap on this Mac: "
            + "an exact finish signal needs the on-device tokenizer API (macOS 26.4+), "
            + "this Mac runs macOS \(currentOS) and only estimates token counts. "
            + "Drop --max-tokens (and APFEL_MAX_TOKENS) to keep --require-complete, "
            + "or update macOS to 26.4 or later."
    }
}

extension CompletionPolicy {
    /// `--batch` promises that a truncated record is never reported as ok
    /// (#481). With an explicit output cap that needs the exact finish
    /// signal of the on-device tokenizer API (macOS 26.4+); below it the
    /// cap comparison is a chars/4 estimate and a cut-off answer could read
    /// as `ok`, so the run is refused before any record is read, like
    /// `preflightRefusal` for `--require-complete`. A context-window
    /// cut-off is exact on every OS, so without a cap nothing is refused.
    /// Exit code: `preflightExitCode` (2). Nil when the run may proceed.
    public static func batchPreflightRefusal(
        maxTokens: Int?,
        tokenCountFallback: TokenCountFallback?
    ) -> String? {
        guard maxTokens != nil, case .osTooOld(let currentOS) = tokenCountFallback else { return nil }
        return "--batch cannot detect a --max-tokens cap on this Mac: "
            + "an exact finish signal needs the on-device tokenizer API (macOS 26.4+), "
            + "this Mac runs macOS \(currentOS) and only estimates token counts, so a cut-off record would read as ok. "
            + "Drop --max-tokens (and APFEL_MAX_TOKENS), or update macOS to 26.4 or later."
    }
}

/// The `--code` output decision (#373, PR #551 review): what goes to stdout
/// and with which exit code. Empty extracted code is never a silent success:
/// an empty response, an empty block, and a capped run that produced only
/// the opening fence all exit `noCode` (7).
public enum CodeOutputPolicy {
    public enum Resolution: Sendable, Equatable {
        case code(CodeCropper.Crop)
        /// No code to print; the associated value is the stderr message.
        case noCode(String)

        public var exitCode: Int32 {
            switch self {
            case .code: return ApfelExitCodes.success
            case .noCode: return ApfelExitCodes.noCode
            }
        }
    }

    public static func resolve(response: String) -> Resolution {
        guard let crop = CodeCropper.crop(from: response) else {
            return .noCode("empty model response, no code to print")
        }
        guard !crop.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .noCode("the response's code block is empty, no code to print")
        }
        return .code(crop)
    }
}
