// ============================================================================
// ToolPolicyTests.swift - Unit tests for the pure request-scoped tool policy
// that enforces tool_choice and parallel_tool_calls at the response boundary
// (#480). No model, no network: every case is deterministic.
// ============================================================================

import Foundation
import ApfelCore

func runToolPolicyTests() {
    let names = ["get_weather", "lookup_ticket"]
    func call(_ name: String, id: String = "call_1") -> ParsedToolCall {
        ParsedToolCall(id: id, name: name, argumentsString: "{}")
    }
    func resolve(_ choice: ToolChoice?, tools: [String] = names, parallel: Bool? = nil) throws -> ToolPolicy {
        switch ToolPolicy.resolve(toolChoice: choice, toolNames: tools, parallelToolCalls: parallel) {
        case .success(let policy): return policy
        case .failure(let error): throw TestFailure("unexpected scope error: \(error)")
        }
    }
    func scopeError(_ choice: ToolChoice?, tools: [String] = names) throws -> ToolPolicy.ScopeError {
        switch ToolPolicy.resolve(toolChoice: choice, toolNames: tools, parallelToolCalls: nil) {
        case .success(let policy): throw TestFailure("expected scope error, got \(policy)")
        case .failure(let error): return error
        }
    }

    // --- resolve: request scope ---

    test("no tools and no tool_choice resolves to disabled (#480)") {
        let policy = try resolve(nil, tools: [])
        try assertEqual(policy.mode, .disabled)
        try assertEqual(policy.toolsInScope, false)
    }

    test("tool_choice none disables tools even when tools are supplied (#480)") {
        let policy = try resolve(ToolChoice.none)
        try assertEqual(policy.mode, .disabled)
        try assertEqual(policy.allowedNames, [])
    }

    test("omitted tool_choice with tools resolves to auto over all names (#480)") {
        let policy = try resolve(nil)
        try assertEqual(policy.mode, .auto)
        try assertEqual(policy.allowedNames, names)
        try assertEqual(policy.forcesToolCall, false)
    }

    test("tool_choice required with tools resolves to required (#480)") {
        let policy = try resolve(.required)
        try assertEqual(policy.mode, .required)
        try assertEqual(policy.forcesToolCall, true)
    }

    test("tool_choice required without tools is a scope error naming tool_choice (#480)") {
        let error = try scopeError(.required, tools: [])
        try assertEqual(error, .requiredWithoutTools)
        try assertEqual(error.param, "tool_choice")
        try assertTrue(error.message.contains("required"))
    }

    test("named tool_choice matching a tool resolves to specific (#480)") {
        let policy = try resolve(.specific(name: "lookup_ticket"))
        try assertEqual(policy.mode, .specific("lookup_ticket"))
        try assertEqual(policy.forcesToolCall, true)
    }

    test("named tool_choice absent from the resolved scope is a scope error listing available names (#480)") {
        let error = try scopeError(.specific(name: "nonexistent"))
        try assertEqual(error, .unknownFunction(name: "nonexistent", available: names))
        try assertTrue(error.message.contains("nonexistent"))
        try assertTrue(error.message.contains("get_weather"))
    }

    test("named tool_choice with no tools at all is a scope error (MCP gap, #480)") {
        let error = try scopeError(.specific(name: "add"), tools: [])
        try assertEqual(error, .unknownFunction(name: "add", available: []))
    }

    test("invalid tool_choice is a scope error (validator normally catches it first) (#480)") {
        let error = try scopeError(.invalid("banana"))
        try assertEqual(error, .invalidChoice("banana"))
    }

    test("parallel_tool_calls false caps calls at one; true or absent leaves no cap (#480)") {
        try assertEqual(try resolve(nil, parallel: false).maxCalls, 1)
        try assertNil(try resolve(nil, parallel: true).maxCalls)
        try assertNil(try resolve(nil, parallel: nil).maxCalls)
    }

    // --- scopedTools: what the model gets to see ---

    test("scopedTools returns nil when disabled and only the named tool for specific (#480)") {
        let tools = names.map { OpenAITool(type: "function", function: OpenAIFunction(name: $0, description: nil, parameters: nil)) }
        try assertNil(try resolve(ToolChoice.none).scopedTools(from: tools))
        try assertEqual(try resolve(nil).scopedTools(from: tools)?.count, 2)
        let specific = try resolve(.specific(name: "get_weather")).scopedTools(from: tools)
        try assertEqual(specific?.map(\.function.name), ["get_weather"])
    }

    // --- evaluate: the response boundary ---

    test("disabled: tool-call-shaped output is ordinary content (#480)") {
        let policy = try resolve(ToolChoice.none)
        try assertEqual(policy.evaluate([call("get_weather")]), .content)
        try assertEqual(policy.evaluate(nil), .content)
    }

    test("auto: plain text is content, allowed calls pass through (#480)") {
        let policy = try resolve(nil)
        try assertEqual(policy.evaluate(nil), .content)
        let calls = [call("get_weather"), call("lookup_ticket", id: "call_2")]
        try assertEqual(policy.evaluate(calls), .toolCalls(calls))
    }

    test("auto: a call to a function outside the scope is a tool_call_not_allowed violation (#480)") {
        let policy = try resolve(nil)
        guard case .violation(let v) = policy.evaluate([call("get_weather"), call("rm_rf", id: "call_2")]) else {
            throw TestFailure("expected violation for unknown function")
        }
        try assertEqual(v.code, "tool_call_not_allowed")
        try assertTrue(v.message.contains("rm_rf"))
        try assertTrue(v.message.contains("get_weather"))
    }

    test("required: plain text is a tool_choice_not_satisfied violation (#480)") {
        let policy = try resolve(.required)
        guard case .violation(let v) = policy.evaluate(nil) else {
            throw TestFailure("expected violation for plain text under required")
        }
        try assertEqual(v.code, "tool_choice_not_satisfied")
    }

    test("required: an allowed call satisfies the policy (#480)") {
        let policy = try resolve(.required)
        try assertEqual(policy.evaluate([call("lookup_ticket")]), .toolCalls([call("lookup_ticket")]))
    }

    test("specific: plain text and a different function are tool_choice_not_satisfied violations (#480)") {
        let policy = try resolve(.specific(name: "lookup_ticket"))
        guard case .violation(let text) = policy.evaluate(nil) else {
            throw TestFailure("expected violation for plain text under specific")
        }
        try assertEqual(text.code, "tool_choice_not_satisfied")
        try assertTrue(text.message.contains("lookup_ticket"))
        guard case .violation(let wrong) = policy.evaluate([call("get_weather")]) else {
            throw TestFailure("expected violation for wrong function under specific")
        }
        try assertEqual(wrong.code, "tool_choice_not_satisfied")
        try assertTrue(wrong.message.contains("get_weather"))
        try assertTrue(wrong.message.contains("lookup_ticket"))
    }

    test("specific: the forced call passes, and a second unrelated call is a violation (#480)") {
        let policy = try resolve(.specific(name: "lookup_ticket"))
        try assertEqual(policy.evaluate([call("lookup_ticket")]), .toolCalls([call("lookup_ticket")]))
        guard case .violation = policy.evaluate([call("lookup_ticket"), call("get_weather", id: "call_2")]) else {
            throw TestFailure("expected violation when a non-forced call rides along")
        }
    }

    test("parallel_tool_calls false with two generated calls keeps only the first (#480)") {
        let policy = try resolve(nil, parallel: false)
        let calls = [call("get_weather"), call("lookup_ticket", id: "call_2")]
        try assertEqual(policy.evaluate(calls), .toolCalls([call("get_weather")]))
    }

    test("parallel_tool_calls false under specific caps a repeated forced call at one (#480)") {
        let policy = try resolve(.specific(name: "get_weather"), parallel: false)
        let calls = [call("get_weather"), call("get_weather", id: "call_2")]
        try assertEqual(policy.evaluate(calls), .toolCalls([call("get_weather")]))
    }

    test("enforceNames false defers unknown names to the executor but still applies mode and cap (#480)") {
        let policy = try resolve(nil, parallel: false)
        let calls = [call("mystery"), call("get_weather", id: "call_2")]
        try assertEqual(policy.evaluate(calls, enforceNames: false), .toolCalls([call("mystery")]))
        let forced = try resolve(.specific(name: "get_weather"))
        guard case .violation = forced.evaluate([call("mystery")], enforceNames: false) else {
            throw TestFailure("mode enforcement must not depend on enforceNames")
        }
    }

    test("repairPrompt restates the violation and the contract for one bounded repair round (#480)") {
        let violation = ToolPolicy.Violation(code: ToolPolicy.Violation.notAllowedCode, message: "the model called 'say_hi'")
        let auto = try resolve(nil).repairPrompt(for: violation)
        try assertTrue(auto.contains("say_hi"), auto)
        try assertTrue(auto.contains("get_weather") && auto.contains("plain text"), auto)
        let forced = try resolve(.specific(name: "lookup_ticket")).repairPrompt(for: violation)
        try assertTrue(forced.contains("lookup_ticket") && !forced.contains("plain text"), forced)
        let required = try resolve(.required).repairPrompt(for: violation)
        try assertTrue(required.contains("get_weather, lookup_ticket") && !required.contains("plain text"), required)
    }

    test("evaluate treats an empty detected array like no detection (#480)") {
        try assertEqual(try resolve(nil).evaluate([]), .content)
        guard case .violation = try resolve(.required).evaluate([]) else {
            throw TestFailure("empty detection under required must be a violation")
        }
    }

    // --- evaluate(output:): arguments held to the client tool schemas (#580) ---

    let timeSchemas = [
        "convert_time": #"{"type":"object","properties":{"time":{"type":"string"},"target_timezone":{"type":"string"}},"required":["time"]}"#,
        "web_search": #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"],"additionalProperties":false}"#,
    ]
    func checked(_ choice: ToolChoice? = nil) throws -> ToolPolicy {
        try resolve(choice, tools: ["convert_time", "web_search"]).withArgumentSchemas(timeSchemas)
    }
    func envelope(_ name: String, _ arguments: String) -> String {
        let escaped = arguments.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"tool_calls": [{"id": "call_1", "type": "function", "function": {"name": ""# + name
            + #"", "arguments": ""# + escaped + #""}}]}"#
    }
    func violationCode(_ outcome: ToolPolicy.Outcome) throws -> String {
        guard case .violation(let violation) = outcome else {
            throw TestFailure("expected a violation, got \(outcome)")
        }
        return violation.code
    }

    test("evaluate(output:) passes a call whose arguments match the schema (#580)") {
        let outcome = try checked().evaluate(output: envelope("convert_time", #"{"time": "14:30"}"#))
        guard case .toolCalls(let calls) = outcome else { throw TestFailure("expected tool calls, got \(outcome)") }
        try assertEqual(calls.map(\.name), ["convert_time"])
        try assertEqual(calls.first?.argumentsString, #"{"time": "14:30"}"#)
    }

    test("evaluate(output:) rejects a call missing a required argument instead of sending {} (#580)") {
        let policy = try checked()
        let outcome = policy.evaluate(output: envelope("convert_time", "{}"))
        try assertEqual(try violationCode(outcome), ToolPolicy.Violation.invalidArgumentsCode)
        guard case .violation(let violation) = outcome else { return }
        try assertTrue(violation.message.contains("convert_time"))
        try assertTrue(violation.message.contains("time"))
        try assertTrue(policy.repairPrompt(for: violation).contains("missing required parameter(s): time"))
    }

    test("evaluate(output:) rejects a bare string wrapped as {\"value\": ...} for a schema without value (#580)") {
        let output = #"{"tool_calls": [{"id": "call_1", "type": "function", "function": "convert_time", "arguments": "14:30"}]}"#
        try assertEqual(try violationCode(try checked().evaluate(output: output)), ToolPolicy.Violation.invalidArgumentsCode)
    }

    test("evaluate(output:) rejects undeclared arguments when additionalProperties is false (#581)") {
        let outcome = try checked().evaluate(output: envelope("web_search", #"{"query": "x", "minLength": 1}"#))
        try assertEqual(try violationCode(outcome), ToolPolicy.Violation.invalidArgumentsCode)
    }

    test("evaluate(output:) rejects arguments that are not valid JSON (#580)") {
        let outcome = try checked().evaluate(output: envelope("web_search", #"{"query": "x", "n": 5"}"#))
        try assertEqual(try violationCode(outcome), ToolPolicy.Violation.invalidArgumentsCode)
    }

    test("evaluate(output:) never delivers unparseable tool-call text as content under auto (#580)") {
        let output = #"{"tool_calls": [{"id": "call_1", "arguments": {"query": "who won", "category:sports"}}]}"#
        try assertEqual(try violationCode(try checked().evaluate(output: output)), ToolPolicy.Violation.invalidCallCode)
    }

    test("evaluate(output:) keeps plain text as content under auto") {
        try assertEqual(try checked().evaluate(output: "It is 14:30 in Tokyo."), .content)
    }

    test("evaluate(output:) keeps tool-call-shaped text as content when tools are disabled") {
        let policy = try resolve(ToolChoice.none).withArgumentSchemas(timeSchemas)
        try assertEqual(policy.evaluate(output: envelope("convert_time", "{}")), .content)
    }

    test("parameterSchemas(of:) maps each tool name to its parameters JSON (#580)") {
        let tools = [
            OpenAITool(type: "function", function: OpenAIFunction(
                name: "convert_time", description: nil, parameters: RawJSON(rawValue: #"{"type":"object"}"#))),
            OpenAITool(type: "function", function: OpenAIFunction(name: "ping", description: nil, parameters: nil)),
        ]
        try assertEqual(ToolPolicy.parameterSchemas(of: tools), ["convert_time": #"{"type":"object"}"#])
        try assertEqual(ToolPolicy.parameterSchemas(of: nil), [:])
    }

    test("evaluate(output:) without schemas only checks names, as evaluate(_:) does") {
        let policy = try resolve(nil, tools: ["convert_time"])
        guard case .toolCalls = policy.evaluate(output: envelope("convert_time", "{}")) else {
            throw TestFailure("a schema-less policy must not judge arguments")
        }
    }
}
