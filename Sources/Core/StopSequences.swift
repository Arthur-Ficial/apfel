// ============================================================================
// StopSequences.swift - OpenAI `stop` sequences for plain-text generation
// (#483). Part of ApfelCore - pure, no FoundationModels dependency.
//
// Apple's sampling options have no stop field, so apfel applies stop
// sequences on the output side: `StopSequenceMatcher` watches the generated
// text as it grows, releases everything that can no longer become part of a
// delimiter, holds back only the ambiguous suffix, and reports a match the
// moment a delimiter is complete so the caller can stop consuming the model
// stream. The HTTP server (streaming and non-streaming) and the CLI share it.
// ============================================================================

import Foundation

/// Why a `stop` value was rejected.
public enum StopSequenceFailure: Sendable, Equatable, Hashable, Error, CustomStringConvertible {
    /// `stop` was neither a string nor an array of strings.
    case invalidType
    /// An array entry at `index` was not a string.
    case nonStringEntry(index: Int)
    /// A stop sequence was the empty string.
    case emptySequence
    /// More than `StopSequences.maxCount` sequences.
    case tooMany(count: Int)
    /// The sequences together exceed `StopSequences.maxTotalScalars`.
    case tooLong(scalars: Int)
    /// Stop sequences with client tools in scope (not yet supported).
    case withTools
    /// Stop sequences on a server whose MCP tools are in scope.
    case withMCPTools
    /// Stop sequences with a structured `response_format` type.
    case withResponseFormat(String)

    /// Stable user-facing message.
    public var message: String {
        switch self {
        case .invalidType:
            return "'stop' must be a string or an array of strings."
        case .nonStringEntry(let index):
            return "'stop' array entries must be strings; the entry at index \(index) is not."
        case .emptySequence:
            return "'stop' sequences must be non-empty strings."
        case .tooMany(let count):
            return "'stop' accepts at most \(StopSequences.maxCount) sequences, got \(count)."
        case .tooLong(let scalars):
            return "'stop' sequences may total at most \(StopSequences.maxTotalScalars) characters (Unicode scalars), got \(scalars)."
        case .withTools:
            return "'stop' is supported for plain-text generation only and cannot be combined with tool calling yet. Omit 'stop', or send tool_choice 'none'."
        case .withMCPTools:
            return "'stop' cannot be combined with this server's MCP tools (--mcp): tool calling is active for every request. Send tool_choice 'none' to generate plain text with stop sequences."
        case .withResponseFormat(let type):
            return "'stop' cannot be combined with response_format '\(type)' yet: structured output would be cut mid-document. Omit 'stop' or use response_format 'text'."
        }
    }

    public var description: String { message }
}

/// Decoding, limits and combination rules for stop sequences.
public enum StopSequences {
    /// Maximum number of stop sequences per request (OpenAI's limit).
    public static let maxCount = 4
    /// Maximum combined length of all stop sequences, in Unicode scalars.
    /// Bounds the matcher's work per generated scalar and the held-back
    /// output latency.
    public static let maxTotalScalars = 256

    /// Decode the raw OpenAI `stop` value: absent or `null` means none, a
    /// string is one sequence, an array of strings keeps its order (an empty
    /// array means none). The result is also checked against the limits.
    public static func decode(_ raw: RawJSON?) -> Result<[String], StopSequenceFailure> {
        guard let raw else { return .success([]) }
        guard let value = try? JSONSerialization.jsonObject(
            with: Data(raw.value.utf8), options: [.fragmentsAllowed]) else {
            return .failure(.invalidType)
        }
        let stops: [String]
        if value is NSNull {
            return .success([])
        } else if let single = value as? String {
            stops = [single]
        } else if let array = value as? [Any] {
            var collected: [String] = []
            for (index, entry) in array.enumerated() {
                guard let string = entry as? String else {
                    return .failure(.nonStringEntry(index: index))
                }
                collected.append(string)
            }
            stops = collected
        } else {
            return .failure(.invalidType)
        }
        if let failure = validate(stops) { return .failure(failure) }
        return .success(stops)
    }

    /// Check already-decoded stop sequences against the limits.
    public static func validate(_ stops: [String]) -> StopSequenceFailure? {
        if stops.contains(where: \.isEmpty) { return .emptySequence }
        if stops.count > maxCount { return .tooMany(count: stops.count) }
        let total = stops.reduce(0) { $0 + $1.unicodeScalars.count }
        if total > maxTotalScalars { return .tooLong(scalars: total) }
        return nil
    }

    /// Stop sequences apply to plain-text generation only: a cut tool call
    /// or a cut JSON document would be structurally invalid. `nil` when the
    /// combination is allowed (always when `stops` is empty).
    public static func combinationFailure(stops: [String], toolsInScope: Bool, responseFormat: String?) -> StopSequenceFailure? {
        guard !stops.isEmpty else { return nil }
        if toolsInScope { return .withTools }
        if let type = responseFormat, type != "text" { return .withResponseFormat(type) }
        return nil
    }
}

/// Incremental stop-sequence matcher over cumulative text snapshots.
///
/// Semantics (identical for any chunking of the same text):
/// - Matching is on exact Unicode scalars, no normalization.
/// - The first delimiter to be *completely* generated wins (smallest end
///   offset); at the same end offset the longest delimiter wins.
/// - Delivered text is everything before the winning delimiter; the
///   delimiter and everything after it are never released.
/// - Only the longest suffix that could still grow into a delimiter is held
///   back; everything before it is released at once.
/// - At end of stream without a match, `finish()` releases the held suffix.
public struct StopSequenceMatcher: Sendable {
    /// The stop sequences, as given.
    public let stops: [String]
    private let stopScalars: [[Unicode.Scalar]]
    private let longest: Int

    /// All text released so far.
    public private(set) var delivered: String = ""
    /// The delimiter that ended generation, if any.
    public private(set) var matchedStop: String? = nil
    /// Scalars of the cumulative input consumed so far.
    private var consumed = 0
    /// Consumed but not yet released scalars.
    private var held: [Unicode.Scalar] = []
    private var finished = false

    /// True once a delimiter has been matched.
    public var isMatched: Bool { matchedStop != nil }

    /// Text currently held back because it could still become a delimiter.
    public var heldBack: String { Self.string(held[...]) }

    /// - Parameter stops: Stop sequences; empty strings are ignored (the
    ///   request validators reject them before this point).
    public init(stops: [String]) {
        self.stops = stops
        self.stopScalars = stops.map { Array($0.unicodeScalars) }.filter { !$0.isEmpty }
        self.longest = stopScalars.map(\.count).max() ?? 0
    }

    /// Feed the full text generated so far. Returns the newly releasable
    /// text (possibly empty). Snapshots that do not grow release nothing;
    /// after a match or `finish()` nothing more is released.
    @discardableResult
    public mutating func feed(cumulative: String) -> String {
        guard !isMatched, !finished else { return "" }
        let scalars = cumulative.unicodeScalars
        guard scalars.count > consumed else { return "" }
        var released = String.UnicodeScalarView()
        for scalar in scalars.dropFirst(consumed) {
            consumed += 1
            held.append(scalar)
            if let winner = completedStop() {
                released.append(contentsOf: held[0..<(held.count - stopScalars[winner].count)])
                held.removeAll()
                matchedStop = String(String.UnicodeScalarView(stopScalars[winner]))
                break
            }
        }
        if !isMatched {
            let keep = ambiguousSuffixLength()
            released.append(contentsOf: held[0..<(held.count - keep)])
            held.removeFirst(held.count - keep)
        }
        let delta = String(released)
        delivered += delta
        return delta
    }

    /// End of stream: release the held suffix when no delimiter matched.
    @discardableResult
    public mutating func finish() -> String {
        guard !finished else { return "" }
        finished = true
        guard !isMatched else { return "" }
        let rest = Self.string(held[...])
        held.removeAll()
        delivered += rest
        return rest
    }

    /// One-shot convenience: the delivered text for a complete `text`.
    public static func apply(_ stops: [String], to text: String) -> (text: String, matchedStop: String?) {
        var matcher = StopSequenceMatcher(stops: stops)
        matcher.feed(cumulative: text)
        matcher.finish()
        return (matcher.delivered, matcher.matchedStop)
    }

    /// Index of the longest delimiter that `held` ends with, if any.
    private func completedStop() -> Int? {
        var best: Int? = nil
        for (index, stop) in stopScalars.enumerated() where stop.count <= held.count {
            if held[(held.count - stop.count)...].elementsEqual(stop),
               best == nil || stop.count > stopScalars[best!].count {
                best = index
            }
        }
        return best
    }

    /// Length of the longest suffix of `held` that is a proper prefix of
    /// some delimiter (so it could still complete one).
    private func ambiguousSuffixLength() -> Int {
        var length = min(held.count, max(longest - 1, 0))
        while length > 0 {
            let suffix = held[(held.count - length)...]
            if stopScalars.contains(where: { $0.count > length && $0[0..<length].elementsEqual(suffix) }) {
                return length
            }
            length -= 1
        }
        return 0
    }

    private static func string(_ scalars: ArraySlice<Unicode.Scalar>) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }
}
