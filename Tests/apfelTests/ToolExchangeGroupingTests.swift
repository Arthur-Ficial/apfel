// ============================================================================
// ToolExchangeGroupingTests.swift - Unit tests for the pure grouping of
// assistant tool calls with their tool outputs, the association validator,
// and group-aware history selection (#482). Deterministic: token costs are
// injected, no model involved.
// ============================================================================

import Foundation
import ApfelCore

func runToolExchangeGroupingTests() {
    func user(_ text: String = "q") -> OpenAIMessage { OpenAIMessage(role: "user", content: .text(text)) }
    func assistantCalls(_ pairs: [(String, String)]) -> OpenAIMessage {
        OpenAIMessage(role: "assistant", content: nil, tool_calls: pairs.map {
            ToolCall(id: $0.0, type: "function", function: ToolCallFunction(name: $0.1, arguments: "{}"))
        })
    }
    func toolResult(_ id: String?, name: String? = nil) -> OpenAIMessage {
        OpenAIMessage(role: "tool", content: .text("r"), tool_call_id: id, name: name)
    }

    // --- grouping ---

    test("two calls in one assistant message and two separately delivered results form one indivisible group (#482)") {
        let items: [HistoryItem] = [
            .prompt,
            .toolCalls(ids: ["call_a", "call_b"]),
            .toolOutput(id: "call_b"),
            .toolOutput(id: "call_a"),
            .prompt,
        ]
        try assertEqual(ToolExchangeGrouping.groups(items), [0..<1, 1..<4, 4..<5])
    }

    test("plain prompt/response history is one group per entry (#482)") {
        let items: [HistoryItem] = [.prompt, .response, .prompt, .response]
        try assertEqual(ToolExchangeGrouping.groups(items), [0..<1, 1..<2, 2..<3, 3..<4])
    }

    test("chained exchanges are separate groups and grouping is total on broken input (#482)") {
        let chained: [HistoryItem] = [.toolCalls(ids: ["a"]), .toolOutput(id: "a"), .toolCalls(ids: ["b"]), .toolOutput(id: "b")]
        try assertEqual(ToolExchangeGrouping.groups(chained), [0..<2, 2..<4])
        // An orphan output never fails grouping (validation is the gate); it is its own group.
        try assertEqual(ToolExchangeGrouping.groups([.prompt, .toolOutput(id: "x")]), [0..<1, 1..<2])
    }

    // --- validation: precise message-path errors ---

    test("a complete exchange with no redundant name on the results validates (#482)") {
        let messages = [
            user(), assistantCalls([("c1", "get_weather"), ("c2", "get_weather")]),
            toolResult("c2"), toolResult("c1"),
        ]
        try assertNil(ToolExchangeGrouping.validate(messages))
    }

    test("a tool message with no preceding tool call is an orphan at its message index (#482)") {
        let error = ToolExchangeGrouping.validate([user(), toolResult("c9")])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 1, kind: .orphanToolOutput(id: "c9")))
        try assertTrue(error?.message.contains("messages[1]") == true, error?.message ?? "nil")
        try assertTrue(error?.message.contains("c9") == true)
    }

    test("a tool message without tool_call_id is rejected (#482)") {
        let error = ToolExchangeGrouping.validate([user(), assistantCalls([("c1", "add")]), toolResult(nil)])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 2, kind: .missingToolCallId))
        try assertTrue(error?.message.contains("tool_call_id") == true)
    }

    test("a second result for the same call id is a duplicate (#482)") {
        let error = ToolExchangeGrouping.validate([user(), assistantCalls([("c1", "add")]), toolResult("c1"), toolResult("c1")])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 3, kind: .duplicateToolOutput(id: "c1")))
    }

    test("a result naming a call from a different exchange is an orphan (#482)") {
        let error = ToolExchangeGrouping.validate([user(), assistantCalls([("c1", "add")]), toolResult("c1"), toolResult("c7")])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 3, kind: .orphanToolOutput(id: "c7")))
    }

    test("an assistant tool call with a missing result is rejected at the assistant index (#482)") {
        let error = ToolExchangeGrouping.validate([user(), assistantCalls([("c1", "add"), ("c2", "add")]), toolResult("c1"), user()])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 1, kind: .missingToolOutputs(ids: ["c2"])))
        try assertTrue(error?.message.contains("c2") == true)
    }

    test("a repeated tool_call id inside one assistant message is rejected (#482)") {
        let error = ToolExchangeGrouping.validate([user(), assistantCalls([("c1", "add"), ("c1", "add")]), toolResult("c1"), toolResult("c1")])
        try assertEqual(error, ToolExchangeGrouping.AssociationError(index: 1, kind: .duplicateToolCallId(id: "c1")))
    }

    test("instruction roles do not shift the reported message index (#482)") {
        let system = OpenAIMessage(role: "system", content: .text("s"))
        let error = ToolExchangeGrouping.validate([system, user(), toolResult("c1")])
        try assertEqual(error?.index, 2)
    }

    test("callNames resolves an output name through its tool_call_id (#482)") {
        let names = ToolExchangeGrouping.callNames(in: [user(), assistantCalls([("c1", "get_weather"), ("c2", "lookup")]), toolResult("c1"), toolResult("c2")])
        try assertEqual(names["c1"], "get_weather")
        try assertEqual(names["c2"], "lookup")
        try assertNil(names["c3"])
    }

    // --- group-aware selection with an injected token-cost function ---

    // history: prompt(10) | exchange = call(30) + out(30) + out(30) | prompt(10)
    let items: [HistoryItem] = [.prompt, .toolCalls(ids: ["a", "b"]), .toolOutput(id: "a"), .toolOutput(id: "b"), .prompt]
    let costs = [10, 30, 30, 30, 10]
    let groups = ToolExchangeGrouping.groups(items)
    let fits: @Sendable (Int) -> @Sendable ([Range<Int>]) async -> Bool = { budget in
        { ranges in ranges.flatMap { Array($0) }.map { costs[$0] }.reduce(0, +) <= budget }
    }

    testAsync("newest-first keeps the whole exchange or none of it (#482)") {
        // 10 fits, 10 + 90 does not: the exchange is dropped entirely, never split.
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: groups, pinLast: false, fits: fits(75)), [4..<5])
        // 10 + 90 fits, + 10 more does not.
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: groups, pinLast: false, fits: fits(105)), [1..<5])
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: groups, pinLast: false, fits: fits(110)), [0..<5])
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: groups, pinLast: false, fits: fits(5)), [])
    }

    testAsync("oldest-first keeps the whole exchange or none of it (#482)") {
        try assertEqual(await ToolExchangeGrouping.oldestFirst(groups: groups, pinLast: false, fits: fits(75)), [0..<1])
        try assertEqual(await ToolExchangeGrouping.oldestFirst(groups: groups, pinLast: false, fits: fits(100)), [0..<4])
        try assertEqual(await ToolExchangeGrouping.oldestFirst(groups: groups, pinLast: false, fits: fits(0)), [])
    }

    testAsync("a pinned trailing exchange is always kept and older groups fill around it (#482)") {
        let trailing: [HistoryItem] = [.prompt, .prompt, .toolCalls(ids: ["a"]), .toolOutput(id: "a")]
        let trailingCosts = [10, 10, 30, 30]
        let trailingGroups = ToolExchangeGrouping.groups(trailing)
        let fitsTrailing: @Sendable (Int) -> @Sendable ([Range<Int>]) async -> Bool = { budget in
            { ranges in ranges.flatMap { Array($0) }.map { trailingCosts[$0] }.reduce(0, +) <= budget }
        }
        // Budget covers the exchange (60) plus one prompt, not two.
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: trailingGroups, pinLast: true, fits: fitsTrailing(75)), [1..<4])
        // Oldest-first keeps the earliest prompt AND the pinned tail; adjacent ranges merge.
        try assertEqual(await ToolExchangeGrouping.oldestFirst(groups: trailingGroups, pinLast: true, fits: fitsTrailing(75)), [0..<1, 2..<4])
        try assertEqual(await ToolExchangeGrouping.oldestFirst(groups: trailingGroups, pinLast: true, fits: fitsTrailing(80)), [0..<4])
        // Nothing but the pinned tail fits: it is still returned (the caller pre-checked it fits).
        try assertEqual(await ToolExchangeGrouping.newestFirst(groups: trailingGroups, pinLast: true, fits: fitsTrailing(60)), [2..<4])
    }

    test("sliding window counts whole groups and keeps the pinned tail outside the window (#482)") {
        let window = ToolExchangeGrouping.window(groups: groups, pinLast: false, maxGroups: 1)
        try assertEqual(window, [4..<5])
        let windowPinned = ToolExchangeGrouping.window(groups: groups, pinLast: true, maxGroups: 1)
        try assertEqual(windowPinned, [1..<4, 4..<5])
        try assertEqual(ToolExchangeGrouping.window(groups: groups, pinLast: false, maxGroups: nil), groups)
        try assertEqual(ToolExchangeGrouping.window(groups: groups, pinLast: false, maxGroups: 99), groups)
    }

    test("merged coalesces adjacent ranges and preserves order (#482)") {
        try assertEqual(ToolExchangeGrouping.merged([0..<1, 1..<4, 6..<7]), [0..<4, 6..<7])
        try assertEqual(ToolExchangeGrouping.merged([]), [])
    }
}
