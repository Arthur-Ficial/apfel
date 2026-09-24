// ============================================================================
// ToolExchangeGrouping.swift - Keep an assistant tool call and its tool
// outputs together when client-supplied history is trimmed (#482).
// Part of ApfelCore - pure Swift, no external dependencies.
//
// Entry-count trimming (`history.suffix(k)`) does not know that a
// `tool_calls` message and the `tool` messages answering it belong together,
// so a boundary landing inside the exchange handed the model an orphaned
// call or an unexplained result. This file supplies the pure pieces the
// trimming strategies need: grouping, association validation with precise
// message-path errors, and group-aware newest/oldest/window selection driven
// by an injected "does this candidate fit the budget" predicate.
// ============================================================================

import Foundation

/// The shape of one history entry, which is all grouping needs to know.
public enum HistoryItem: Sendable, Equatable {
    /// A user turn.
    case prompt
    /// An assistant text turn.
    case response
    /// An assistant turn that requests tool calls with these ids.
    case toolCalls(ids: [String])
    /// A tool result answering the call with this id (`nil` when the client
    /// omitted `tool_call_id`).
    case toolOutput(id: String?)
}

public enum ToolExchangeGrouping {

    /// A tool result or tool call the surrounding messages cannot explain.
    /// `index` is the position in the array the caller passed to `validate`.
    public struct AssociationError: Error, Sendable, Equatable, CustomStringConvertible {
        public enum Kind: Sendable, Equatable {
            /// A `tool` message with no `tool_call_id`.
            case missingToolCallId
            /// A `tool` message whose id matches no call in the exchange it follows.
            case orphanToolOutput(id: String)
            /// A second `tool` message for a call that already has a result.
            case duplicateToolOutput(id: String)
            /// One assistant message requesting the same call id twice.
            case duplicateToolCallId(id: String)
            /// An assistant `tool_calls` message not followed by a result for every call.
            case missingToolOutputs(ids: [String])
        }

        public let index: Int
        public let kind: Kind

        public init(index: Int, kind: Kind) {
            self.index = index
            self.kind = kind
        }

        /// OpenAI-style message naming the offending message path.
        public var message: String {
            let path = "messages[\(index)]"
            switch kind {
            case .missingToolCallId:
                return "\(path): a message with role 'tool' must carry the 'tool_call_id' of the assistant tool call it answers"
            case .orphanToolOutput(let id):
                return "\(path): tool result for tool_call_id '\(id)' does not answer a tool call in the preceding assistant message"
            case .duplicateToolOutput(let id):
                return "\(path): tool_call_id '\(id)' already has a tool result in this exchange"
            case .duplicateToolCallId(let id):
                return "\(path): assistant tool_calls repeat the id '\(id)'"
            case .missingToolOutputs(let ids):
                return "\(path): assistant tool_calls must each be followed by a message with role 'tool'; missing results for: \(ids.joined(separator: ", "))"
            }
        }

        public var description: String { message }
    }

    // MARK: - Grouping

    /// Partition `items` into indivisible index ranges: an assistant tool-call
    /// item together with the tool outputs that immediately follow it, and
    /// every other item on its own. Total - broken associations still yield
    /// groups (an orphan output stands alone); `validate` is the gate that
    /// rejects them before any transcript is built.
    public static func groups(_ items: [HistoryItem]) -> [Range<Int>] {
        scan(items).groups
    }

    /// First broken association in an OpenAI message list, or `nil` when every
    /// tool call has exactly its results and every result has its call.
    /// Instruction roles (`system`, `developer`) are not conversation turns
    /// and are skipped without shifting the reported message index.
    public static func validate(_ messages: [OpenAIMessage]) -> AssociationError? {
        var items: [HistoryItem] = []
        var originalIndex: [Int] = []
        for (index, message) in messages.enumerated() {
            guard let item = historyItem(for: message) else { continue }
            items.append(item)
            originalIndex.append(index)
        }
        guard let error = scan(items).firstError else { return nil }
        return AssociationError(index: originalIndex[error.index], kind: error.kind)
    }

    /// `tool_call_id` -> function name for every assistant tool call in the
    /// list, so a tool result's name can be resolved instead of trusting an
    /// optional client-supplied `name`.
    public static func callNames(in messages: [OpenAIMessage]) -> [String: String] {
        var names: [String: String] = [:]
        for message in messages where message.role == "assistant" {
            for call in message.tool_calls ?? [] where names[call.id] == nil {
                names[call.id] = call.function.name
            }
        }
        return names
    }

    /// The history shape of one message; `nil` for instruction roles.
    public static func historyItem(for message: OpenAIMessage) -> HistoryItem? {
        switch message.role {
        case "user":
            return .prompt
        case "assistant":
            if let calls = message.tool_calls, !calls.isEmpty {
                return .toolCalls(ids: calls.map(\.id))
            }
            return .response
        case "tool":
            return .toolOutput(id: message.tool_call_id)
        default:
            return nil
        }
    }

    private static func scan(_ items: [HistoryItem]) -> (groups: [Range<Int>], firstError: AssociationError?) {
        var groups: [Range<Int>] = []
        var firstError: AssociationError?
        func note(_ index: Int, _ kind: AssociationError.Kind) {
            if firstError == nil { firstError = AssociationError(index: index, kind: kind) }
        }

        var index = 0
        while index < items.count {
            switch items[index] {
            case .toolCalls(let ids):
                var seen = Set<String>()
                for id in ids where !seen.insert(id).inserted {
                    note(index, .duplicateToolCallId(id: id))
                }
                var pending = Set(ids)
                var next = index + 1
                while next < items.count, case .toolOutput(let id) = items[next] {
                    if let id {
                        if !seen.contains(id) {
                            note(next, .orphanToolOutput(id: id))
                        } else if pending.remove(id) == nil {
                            note(next, .duplicateToolOutput(id: id))
                        }
                    } else {
                        note(next, .missingToolCallId)
                    }
                    next += 1
                }
                if !pending.isEmpty {
                    note(index, .missingToolOutputs(ids: ids.filter(pending.contains)))
                }
                groups.append(index..<next)
                index = next
            case .toolOutput(let id):
                if let id {
                    note(index, .orphanToolOutput(id: id))
                } else {
                    note(index, .missingToolCallId)
                }
                groups.append(index..<(index + 1))
                index += 1
            case .prompt, .response:
                groups.append(index..<(index + 1))
                index += 1
            }
        }
        return (groups, firstError)
    }

    // MARK: - Group-aware selection

    /// The largest suffix of whole groups that fits, as merged entry ranges.
    /// With `pinLast`, the final group is always part of the candidate (the
    /// caller has verified it fits on its own) and older groups fill in
    /// front of it newest-first.
    public static func newestFirst(
        groups: [Range<Int>],
        pinLast: Bool,
        fits: ([Range<Int>]) async -> Bool
    ) async -> [Range<Int>] {
        let pinnedCount = pinLast && !groups.isEmpty ? 1 : 0
        let droppableCount = groups.count - pinnedCount
        func candidate(_ keep: Int) -> [Range<Int>] {
            merged(Array(groups.suffix(keep + pinnedCount)))
        }
        let keep = await largestCount(upTo: droppableCount) { await fits(candidate($0)) }
        return candidate(keep)
    }

    /// The largest prefix of whole groups that fits, plus the pinned final
    /// group when requested, as merged entry ranges.
    public static func oldestFirst(
        groups: [Range<Int>],
        pinLast: Bool,
        fits: ([Range<Int>]) async -> Bool
    ) async -> [Range<Int>] {
        let pinnedCount = pinLast && !groups.isEmpty ? 1 : 0
        let droppable = Array(groups.dropLast(pinnedCount))
        let pinned = Array(groups.suffix(pinnedCount))
        func candidate(_ keep: Int) -> [Range<Int>] {
            merged(Array(droppable.prefix(keep)) + pinned)
        }
        let keep = await largestCount(upTo: droppable.count) { await fits(candidate($0)) }
        return candidate(keep)
    }

    /// The last `maxGroups` droppable groups plus the pinned final group.
    /// `nil` means no window. A tool exchange counts as one turn.
    public static func window(groups: [Range<Int>], pinLast: Bool, maxGroups: Int?) -> [Range<Int>] {
        guard let maxGroups else { return groups }
        let pinnedCount = pinLast && !groups.isEmpty ? 1 : 0
        let droppable = groups.dropLast(pinnedCount)
        return Array(droppable.suffix(max(0, maxGroups))) + Array(groups.suffix(pinnedCount))
    }

    /// Coalesce adjacent or overlapping ranges, preserving order.
    public static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for range in ranges {
            if let last = result.last, last.upperBound >= range.lowerBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }

    /// Binary search for the largest `k` in `0...total` with `fits(k)`, given
    /// that fitting is monotone (if `k` fits, every smaller count fits).
    private static func largestCount(upTo total: Int, fits: (Int) async -> Bool) async -> Int {
        var low = 0
        var high = total
        while low < high {
            let mid = (low + high + 1) / 2
            if await fits(mid) {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }
}
