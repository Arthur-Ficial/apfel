// ============================================================================
// ToolOutputTruncator.swift - Head+tail truncation of tool output to a token
// budget before the follow-up prompt (#221). Pure logic, part of ApfelCore.
// ============================================================================

import Foundation

/// Truncates a tool result so it fits a token budget before it is fed back to
/// the model, whose context window is small and read at runtime.
///
/// A large tool result (file reader, web fetch, DB query) fed back verbatim
/// either overflows the context window after the tool already ran (CLI) or is
/// dropped whole by the context trimmer while the prompt still references it
/// (server) - a confident hallucination. This keeps the head and the tail
/// (the two most useful ends) and drops the middle, leaving an explicit marker.
///
/// The split is character-proportional to the measured tokens-per-character
/// ratio: token counting itself needs the model (root target), so the caller
/// passes in the already-measured `tokenCount` and the derived `budgetTokens`.
public enum ToolOutputTruncator {

    /// Token headroom reserved for the truncation marker itself.
    static let markerReserveTokens = 24

    /// The outcome of a truncation attempt.
    public struct Result: Equatable, Sendable {
        /// The (possibly truncated) text to feed to the model.
        public let text: String
        /// Whether the text was actually truncated.
        public let wasTruncated: Bool

        public init(text: String, wasTruncated: Bool) {
            self.text = text
            self.wasTruncated = wasTruncated
        }
    }

    /// Truncate `text` (which measures `tokenCount` tokens) to fit within
    /// `budgetTokens`, keeping the head and tail and inserting a marker.
    ///
    /// Returns the text unchanged when it already fits (`tokenCount <=
    /// budgetTokens`) or when it is empty.
    ///
    /// - Parameters:
    ///   - text: the full tool result.
    ///   - tokenCount: the measured token count of `text`.
    ///   - budgetTokens: the maximum tokens the result may occupy.
    public static func truncate(_ text: String, tokenCount: Int, budgetTokens: Int) -> Result {
        let charCount = text.count
        guard charCount > 0, tokenCount > budgetTokens else {
            return Result(text: text, wasTruncated: false)
        }

        let tokensPerChar = Double(tokenCount) / Double(charCount)
        // Reserve headroom for the marker text so the marked result still fits.
        let contentTokenBudget = max(0, budgetTokens - markerReserveTokens)
        // Characters that fit in the content budget at the measured ratio.
        var allowedChars = tokensPerChar > 0 ? Int(Double(contentTokenBudget) / tokensPerChar) : 0
        allowedChars = min(max(allowedChars, 0), charCount)

        let headChars = allowedChars / 2
        let tailChars = allowedChars - headChars
        let shownTokens = Int((Double(allowedChars) * tokensPerChar).rounded())

        let head = String(text.prefix(headChars))
        let tail = String(text.suffix(tailChars))
        let marker = "\n\n[tool output truncated: \(shownTokens) of \(tokenCount) tokens shown]\n\n"

        return Result(text: head + marker + tail, wasTruncated: true)
    }
}
