// ============================================================================
// CodeCropper.swift — extract the first fenced code block from model output
// Part of ApfelCore — pure Swift, no external dependencies
//
// Backs the CLI `--code` flag (#373): Layer 1 is `steeringDirective` (asks the
// model for exactly one fenced block), Layer 2 is `extract` (guarantees the
// output contract no matter what the model does). Fence recognition follows
// the CommonMark subset specified in #373; the policy decisions (first block
// wins, salvage on unclosed fence, no inline-span heuristics) are locked by
// CodeCropperTests.
// ============================================================================

import Foundation

public enum CodeCropper {

    /// The result of a successful extraction.
    public struct Crop: Equatable, Sendable {
        /// Block content with leading/trailing blank lines trimmed, interior
        /// bytes untouched, terminated by exactly one newline. Empty string
        /// for an empty or whitespace-only block ("no code needed" is a valid
        /// model answer).
        public let code: String
        /// First word of the fence info string, lowercased. Model-reported
        /// and advisory only — the validation run saw a curl command labeled
        /// `markdown` — so it is never used to filter or validate.
        public let language: String?

        public init(code: String, language: String?) {
            self.code = code
            self.language = language
        }
    }

    /// System-prompt directive appended in `--code` mode. Wording validated
    /// 20/20 against the live model in the #373 prompt battery; do not edit
    /// without re-running it.
    public static let steeringDirective = """
        Reply with exactly one fenced markdown code block (open it with three \
        backticks followed by the language name, for example ```bash) that \
        contains only the code or command. No text before or after the block.
        """

    /// The full `--code` output policy: fenced block first, bare pass-through
    /// second, nil only for an empty response.
    ///
    /// A model that complies with the steering directive so thoroughly that
    /// it omits the fence entirely still works: with no fence anywhere, the
    /// whole (trimmed) response is taken as the code. One deterministic
    /// nicety on that path: a response that is exactly one backtick-wrapped
    /// inline code span is unwrapped. Prose without a fence passes through
    /// as-is — code mode shapes format, not correctness, and the steering
    /// makes a fence-less prose answer rare.
    ///
    /// Returns nil only when the response is empty or whitespace-only — the
    /// CLI's exit-7 case.
    public static func crop(from response: String) -> Crop? {
        if let fenced = extract(from: response) { return fenced }
        let normalized = response.replacingOccurrences(of: "\r\n", with: "\n")
        let body = trimmed(normalized.components(separatedBy: "\n"))
        guard !body.isEmpty else { return nil }
        return Crop(code: unwrapInlineSpan(body), language: nil)
    }

    /// Unwrap `body` (newline-terminated) when its content is exactly one
    /// inline code span: a single line starting and ending with matching
    /// backtick runs (any length — models wrap one-liners in a triple-backtick
    /// run on a single line, which is a span, not a fence) and no other
    /// backticks inside.
    private static func unwrapInlineSpan(_ body: String) -> String {
        let line = String(body.dropLast())          // strip the trailing \n
        guard !line.contains("\n"), line.hasPrefix("`") else { return body }
        let opening = line.prefix(while: { $0 == "`" })
        guard line.count > opening.count * 2,
              line.hasSuffix(String(opening)) else { return body }
        let inner = line.dropFirst(opening.count).dropLast(opening.count)
        guard !inner.contains("`") else { return body }
        let content = inner.trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? body : content + "\n"
    }

    /// Extract the first fenced code block from `response`.
    ///
    /// - Fences: 3+ backticks or 3+ tildes, indented at most 3 spaces. A
    ///   backtick opener's info string must not contain a backtick
    ///   (CommonMark). The closer is the same character, at least as long,
    ///   with nothing but whitespace after it.
    /// - First block wins; later blocks are discarded.
    /// - An unclosed fence at EOF (a `--max-tokens`-truncated response)
    ///   salvages everything after the opener line.
    /// - Returns nil when no fence opener exists. Inline `code` spans are
    ///   deliberately not considered.
    public static func extract(from response: String) -> Crop? {
        let lines = response.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            guard let opener = fenceOpener(line) else { continue }
            var body: [String] = []
            for bodyLine in lines.dropFirst(index + 1) {
                if isFenceCloser(bodyLine, for: opener) {
                    break
                }
                body.append(bodyLine)
            }
            // Loop either broke on a closer or ran to EOF — both yield the
            // collected body (EOF is the salvage path).
            return Crop(code: trimmed(body), language: opener.language)
        }
        return nil
    }

    // MARK: - Fence recognition

    private struct Opener {
        let character: Character
        let length: Int
        let language: String?
    }

    /// Parse `line` as a fence opener, or nil.
    private static func fenceOpener(_ line: String) -> Opener? {
        guard let (char, runLength, rest) = fenceRun(line) else { return nil }
        let info = rest.trimmingCharacters(in: .whitespaces)
        // CommonMark: an info string on a backtick fence cannot contain `.
        if char == "`" && info.contains("`") { return nil }
        let language = info.isEmpty ? nil : info.split(separator: " ")[0].lowercased()
        return Opener(character: char, length: runLength, language: language)
    }

    /// True when `line` closes a block opened by `opener`: same character,
    /// run at least as long, nothing but whitespace after.
    private static func isFenceCloser(_ line: String, for opener: Opener) -> Bool {
        guard let (char, runLength, rest) = fenceRun(line) else { return false }
        return char == opener.character
            && runLength >= opener.length
            && rest.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Split `line` into (fence character, run length, remainder) when it
    /// starts (after at most 3 spaces) with a run of 3+ backticks or tildes.
    private static func fenceRun(_ line: String) -> (Character, Int, Substring)? {
        var idx = line.startIndex
        var indent = 0
        while idx < line.endIndex, line[idx] == " ", indent < 3 {
            indent += 1
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex, line[idx] == "`" || line[idx] == "~" else { return nil }
        let char = line[idx]
        var length = 0
        while idx < line.endIndex, line[idx] == char {
            length += 1
            idx = line.index(after: idx)
        }
        guard length >= 3 else { return nil }
        return (char, length, line[idx...])
    }

    // MARK: - Whitespace policy (#373 decision 3)

    /// Trim blank lines at both ends, preserve interior bytes, terminate with
    /// exactly one newline. Empty/whitespace-only bodies become "".
    private static func trimmed(_ body: [String]) -> String {
        var lines = body[...]
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines = lines.dropFirst()
        }
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines = lines.dropLast()
        }
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }
}
