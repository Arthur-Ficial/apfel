// ============================================================================
// StreamOutcome.swift — Pure decision logic for handling errors thrown
// during a streaming model response.
//
// On Apple's on-device FoundationModels, hitting the context window
// after producing some content surfaces as a thrown error rather
// than as a natural EOS. That throw is morally equivalent to OpenAI's
// finish_reason: "length", not to a server error. This resolver makes the
// distinction:
//
//   - prev empty + contextOverflow  -> the prompt itself is too big.
//                                      Genuine 400, propagate.
//   - prev non-empty + contextOverflow -> the model ran out of room while
//                                          generating. Treat as a graceful
//                                          truncation; emit finish_reason:
//                                          "length" and hand the partial
//                                          content back to the caller.
//   - any other error                -> propagate.
//
// With this resolver in place, the historical 1024 max_tokens default is no
// longer load-bearing: omitted max_tokens flows through as nil, the model
// uses the remaining context window, and any overflow surfaces cleanly.
// ============================================================================

import Foundation

public struct StreamOutcome: Sendable, Equatable, Hashable {
    public let content: String
    public let finishReason: FinishReason

    public init(content: String, finishReason: FinishReason) {
        self.content = content
        self.finishReason = finishReason
    }
}

public enum StreamErrorResolution: Sendable {
    /// The model produced partial content before the throw. Treat as a clean
    /// length-finish; do not propagate the error.
    case truncated(String)
    /// Genuine error. Propagate.
    case fatal(ApfelError)
}

public enum StreamErrorResolver {
    /// Decide how a stream-time error should be handled.
    ///
    /// - parameter prev: the content accumulated by the streaming loop before the throw.
    ///   Empty means no tokens were emitted (the throw is prompt-side).
    /// - parameter error: the classified error.
    /// - returns: `.truncated(prev)` only when the error is a context overflow AND
    ///   `prev` is non-empty. Everything else is fatal.
    public static func resolve(prev: String, error: ApfelError) -> StreamErrorResolution {
        switch error {
        case .contextOverflow where !prev.isEmpty:
            return .truncated(prev)
        default:
            return .fatal(error)
        }
    }

    /// Text whose tokens count toward `completion_tokens` when a refusal is
    /// thrown mid-stream.
    ///
    /// A refusal can arrive AFTER the model has already streamed some content
    /// (accumulated in `prev`). The completion-token total must reflect both the
    /// already-streamed content and the refusal explanation. Returning the
    /// concatenation (rather than summing two independent token counts) lets the
    /// caller make a single `count()` call and avoids double-counting tokens at
    /// the join boundary.
    ///
    /// - parameter prev: content already streamed before the refusal (possibly empty).
    /// - parameter explanation: the refusal explanation text.
    /// - returns: the combined text to be token-counted.
    public static func refusalCompletionText(prev: String, explanation: String) -> String {
        prev + explanation
    }
}
