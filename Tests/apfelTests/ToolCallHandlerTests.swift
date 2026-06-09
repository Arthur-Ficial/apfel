import Foundation
import ApfelCore

private func extractToolSchemaJSON(from prompt: String) -> String? {
    guard let startRange = prompt.range(of: "\n[", options: .backwards),
          let endIndex = prompt.lastIndex(of: "]") else {
        return nil
    }
    let startIndex = prompt.index(before: startRange.upperBound)
    return String(prompt[startIndex...endIndex])
}

func runToolCallHandlerTests() {

    // MARK: - Detection

    test("detects clean JSON tool call") {
        let response = #"{"tool_calls": [{"id": "call_abc", "type": "function", "function": {"name": "get_weather", "arguments": "{\"location\":\"Vienna\"}"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "get_weather")
        try assertEqual(result!.first?.id, "call_abc")
    }
    test("detects tool call inside markdown code block") {
        let response = "```json\n{\"tool_calls\": [{\"id\": \"c1\", \"type\": \"function\", \"function\": {\"name\": \"search\", \"arguments\": \"{}\"}}]}\n```"
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "search")
    }
    test("detects tool call after preamble text") {
        let response = "Let me look that up.\n{\"tool_calls\": [{\"id\": \"c2\", \"type\": \"function\", \"function\": {\"name\": \"calc\", \"arguments\": \"{}\"}}]}"
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "calc")
    }
    test("returns nil for plain text response") {
        let response = "Vienna is the capital of Austria."
        try assertNil(ToolCallHandler.detectToolCall(in: response))
    }
    test("returns nil for partial/malformed JSON") {
        try assertNil(ToolCallHandler.detectToolCall(in: "{tool_calls: broken}"))
        try assertNil(ToolCallHandler.detectToolCall(in: "{}"))
        try assertNil(ToolCallHandler.detectToolCall(in: "{\"tool_calls\": []}"))
    }
    test("parses arguments JSON string correctly") {
        let response = #"{"tool_calls": [{"id": "c3", "type": "function", "function": {"name": "fn", "arguments": "{\"key\":\"val\"}"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.argumentsString, "{\"key\":\"val\"}")
    }
    test("parses function name string shape with sibling arguments") {
        let response = #"{"tool_calls": [{"id": "call_unique1", "type": "function", "function": "get_current_conditions", "arguments": "{\"latitude\": 37.7749, \"longitude\": -122.4194}"}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "get_current_conditions")
        try assertEqual(result!.first?.argumentsString, "{\"latitude\": 37.7749, \"longitude\": -122.4194}")
    }
    test("detects multiple tool calls") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn1", "arguments": "{}"}}, {"id": "c2", "type": "function", "function": {"name": "fn2", "arguments": "{}"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.count, 2)
    }

    // MARK: - System prompt building (production paths)

    test("buildOutputFormatInstructions contains function names and format") {
        let instr = ToolCallHandler.buildOutputFormatInstructions(toolNames: ["get_weather", "search_web"])
        try assertTrue(instr.contains("get_weather"), "missing get_weather")
        try assertTrue(instr.contains("search_web"), "missing search_web")
        try assertTrue(instr.contains("tool_calls"), "missing tool_calls keyword")
        try assertTrue(instr.contains("JSON"), "missing JSON instruction")
    }
    test("buildFallbackPrompt with description") {
        let tools = [ToolDef(name: "fn", description: "Does a thing", parametersJSON: nil)]
        let prompt = ToolCallHandler.buildFallbackPrompt(tools: tools)
        try assertTrue(prompt.contains("Does a thing"))
    }
    test("buildFallbackPrompt without description still works") {
        let tools = [ToolDef(name: "fn", description: nil, parametersJSON: nil)]
        let prompt = ToolCallHandler.buildFallbackPrompt(tools: tools)
        try assertTrue(prompt.contains("fn"))
    }

    // MARK: - Edge cases (bug fixes)

    test("detects tool call with missing closing bracket (#187)") {
        let response = #"{"tool_calls": [{"id": "call_123", "type": "function", "function": {"name": "HassTurnOff", "arguments": {"entity_id": "office_light"}}}}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "HassTurnOff")
        try assertEqual(result!.first?.id, "call_123")
        try assertTrue(result!.first!.argumentsString.contains("office_light"))
    }

    test("detects tool call with missing bracket and string arguments (#187)") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "get_weather", "arguments": "{\"city\":\"Vienna\"}"}}}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "get_weather")
        try assertEqual(result!.first?.argumentsString, #"{"city":"Vienna"}"#)
    }

    test("detects tool call with missing bracket after preamble (#187)") {
        let response = "Sure, I'll turn that off.\n" + #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "toggle", "arguments": "{}"}}}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "toggle")
    }

    test("detects multiple tool calls with missing bracket (#187)") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn1", "arguments": "{}"}}, {"id": "c2", "type": "function", "function": {"name": "fn2", "arguments": "{}"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.count, 2)
    }

    test("repairs missing bracket with multiple tool calls (#187)") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn1", "arguments": "{}"}}, {"id": "c2", "type": "function", "function": {"name": "fn2", "arguments": "{}"}}}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.count, 2)
        try assertEqual(result!.first?.name, "fn1")
        try assertEqual(result!.last?.name, "fn2")
    }

    test("handles trailing backticks without crash") {
        try assertNil(ToolCallHandler.detectToolCall(in: "```"))
    }
    test("handles empty code block without crash") {
        try assertNil(ToolCallHandler.detectToolCall(in: "``````"))
    }

    test("detects tool call in broken code block with trailing text") {
        // Model sometimes outputs tool call JSON inside an unclosed code block with extra text
        let response = "```json\n{\"tool_calls\": [{\"id\": \"call_1\", \"type\": \"function\", \"function\": {\"name\": \"multiply\", \"arguments\": \"{\\\"a\\\": 247, \\\"b\\\": 83}\"}}]}\n20621"
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "multiply")
    }

    test("detects tool call with trailing text after JSON") {
        let response = "Sure, let me calculate that.\n{\"tool_calls\": [{\"id\": \"c1\", \"type\": \"function\", \"function\": {\"name\": \"add\", \"arguments\": \"{\\\"a\\\": 1, \\\"b\\\": 2}\"}}]}\nHere is the result."
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "add")
    }

    // MARK: - JSON escaping in buildFallbackPrompt

    test("buildFallbackPrompt escapes special characters in descriptions") {
        let tools = [ToolDef(name: "fn", description: #"Get the "current" weather\today"#, parametersJSON: nil)]
        let prompt = ToolCallHandler.buildFallbackPrompt(tools: tools)
        try assertTrue(prompt.contains("current"), "missing description content")
        // Find the JSON array in the output and validate it parses
        if let startRange = prompt.range(of: "\n["),
           let _ = prompt.range(of: "\n]", range: startRange.upperBound..<prompt.endIndex) {
            let jsonSlice = String(prompt[startRange.upperBound...]) // includes [ to end
            let arrayEnd = jsonSlice.range(of: "\n]")!
            let jsonStr = "[" + String(jsonSlice[..<arrayEnd.upperBound])
            let data = jsonStr.data(using: .utf8)!
            let parsed = try? JSONSerialization.jsonObject(with: data)
            if parsed == nil {
                throw TestFailure("Generated JSON is not valid — special characters broke escaping")
            }
        }
    }

    // MARK: - Plain string arguments (TICKET-013)

    test("handles arguments as plain string (not JSON) — wraps as JSON object") {
        // Model sometimes returns: "arguments": "desktop" instead of "arguments": "{\"path\":\"desktop\"}"
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "list_dir", "arguments": "desktop"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "list_dir")
        // Plain string must be wrapped as valid JSON per OpenAI spec
        try assertEqual(result!.first?.argumentsString, #"{"value":"desktop"}"#)
    }

    test("handles arguments as JSON object (not string)") {
        // Model sometimes returns: "arguments": {"city": "Vienna"} instead of string
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn", "arguments": {"city": "Vienna"}}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.name, "fn")
        // Should be serialized to a JSON string
        try assertTrue(result!.first!.argumentsString.contains("Vienna"))
    }

    test("handles empty arguments string — becomes empty JSON object") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn", "arguments": ""}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.argumentsString, "{}")
    }

    test("handles missing arguments field") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "fn"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        try assertEqual(result!.first?.argumentsString, "{}")
    }

    // MARK: - ensureJSONArguments (TICKET-013 fix)

    test("ensureJSONArguments passes through valid JSON object") {
        let result = ToolCallHandler.ensureJSONArguments(#"{"path":"desktop"}"#)
        try assertEqual(result, #"{"path":"desktop"}"#)
    }

    test("ensureJSONArguments passes through JSON array") {
        let result = ToolCallHandler.ensureJSONArguments(#"["a","b"]"#)
        try assertEqual(result, #"["a","b"]"#)
    }

    test("ensureJSONArguments wraps plain string") {
        let result = ToolCallHandler.ensureJSONArguments("desktop")
        try assertEqual(result, #"{"value":"desktop"}"#)
    }

    test("ensureJSONArguments wraps string with spaces") {
        let result = ToolCallHandler.ensureJSONArguments("ls -la /tmp")
        try assertEqual(result, #"{"value":"ls -la /tmp"}"#)
    }

    test("ensureJSONArguments escapes quotes in plain string") {
        let result = ToolCallHandler.ensureJSONArguments(#"say "hello""#)
        try assertEqual(result, #"{"value":"say \"hello\""}"#)
    }

    test("ensureJSONArguments preserves backslashes and newlines as valid JSON") {
        let result = ToolCallHandler.ensureJSONArguments("line1\nC:\\tmp")
        let parsed = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        try assertEqual(parsed?["value"] as? String, "line1\nC:\\tmp")
    }

    test("ensureJSONArguments converts empty string to empty object") {
        try assertEqual(ToolCallHandler.ensureJSONArguments(""), "{}")
        try assertEqual(ToolCallHandler.ensureJSONArguments("  "), "{}")
    }

    test("ensureJSONArguments handles whitespace-padded JSON") {
        let result = ToolCallHandler.ensureJSONArguments("  {\"key\": \"val\"}  ")
        // Should pass through since trimmed starts with {
        try assertTrue(result.contains("key"))
    }

    test("plain string arguments produce parseable JSON in full pipeline") {
        let response = #"{"tool_calls": [{"id": "c1", "type": "function", "function": {"name": "run_cmd", "arguments": "ls -l"}}]}"#
        let result = ToolCallHandler.detectToolCall(in: response)
        try assertNotNil(result)
        let argsStr = result!.first!.argumentsString
        // Must be parseable JSON
        let data = argsStr.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        try assertNotNil(parsed)
        try assertEqual(parsed!["value"] as? String, "ls -l")
    }

    // MARK: - Split prompt methods

    test("buildOutputFormatInstructions contains tool names") {
        let result = ToolCallHandler.buildOutputFormatInstructions(toolNames: ["get_weather", "search"])
        try assertTrue(result.contains("get_weather"), "missing tool name")
        try assertTrue(result.contains("search"), "missing tool name")
        try assertTrue(result.contains("tool_calls"), "missing format instruction")
    }

    test("buildFallbackPrompt returns empty for no tools") {
        let result = ToolCallHandler.buildFallbackPrompt(tools: [])
        try assertEqual(result, "")
    }

    test("buildFallbackPrompt includes schemas for given tools") {
        let tools = [ToolDef(name: "fn", description: "Does stuff", parametersJSON: nil)]
        let result = ToolCallHandler.buildFallbackPrompt(tools: tools)
        try assertTrue(result.contains("fn"), "missing tool name")
        try assertTrue(result.contains("Does stuff"), "missing description")
    }

    test("buildFallbackPrompt omits invalid parameters JSON but stays valid") {
        let tools = [ToolDef(name: "fn", description: "Does stuff", parametersJSON: "{not json}")]
        let prompt = ToolCallHandler.buildFallbackPrompt(tools: tools)
        guard let json = extractToolSchemaJSON(from: prompt),
              let data = json.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = parsed.first else {
            throw TestFailure("Failed to parse fallback schema JSON")
        }
        try assertEqual(first["name"] as? String, "fn")
        try assertEqual(first["description"] as? String, "Does stuff")
        try assertNil(first["parameters"])
    }

    test("buildFallbackPrompt preserves parsed parameters JSON") {
        let tools = [ToolDef(
            name: "get_weather",
            description: "Weather lookup",
            parametersJSON: #"{"type":"object","properties":{"city":{"type":"string"}}}"#
        )]
        let prompt = ToolCallHandler.buildFallbackPrompt(tools: tools)
        guard let json = extractToolSchemaJSON(from: prompt),
              let data = json.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let parameters = parsed.first?["parameters"] as? [String: Any] else {
            throw TestFailure("Failed to parse fallback prompt schema JSON")
        }
        try assertEqual(parameters["type"] as? String, "object")
        try assertNotNil(parameters["properties"])
    }

    test("buildOutputFormatInstructions references tool_calls JSON format") {
        let instr = ToolCallHandler.buildOutputFormatInstructions(toolNames: ["calc", "search"])
        try assertTrue(instr.contains("tool_calls"), "must describe tool_calls JSON format")
        try assertTrue(instr.contains("calc"), "must list tool names")
        try assertTrue(instr.contains("search"), "must list tool names")
    }

    // MARK: - ToolLogEntry

    test("ToolLogEntry stores tool execution result") {
        let entry = ToolLogEntry(name: "calc", args: "{\"a\":1}", result: "42", isError: false)
        try assertEqual(entry.name, "calc")
        try assertEqual(entry.args, "{\"a\":1}")
        try assertEqual(entry.result, "42")
        try assertEqual(entry.isError, false)
    }
    test("ToolLogEntry stores error result") {
        let entry = ToolLogEntry(name: "fail", args: "{}", result: "timeout", isError: true)
        try assertTrue(entry.isError)
        try assertEqual(entry.name, "fail")
    }
    test("ToolLogEntry is Equatable") {
        let a = ToolLogEntry(name: "add", args: "{}", result: "3", isError: false)
        let b = ToolLogEntry(name: "add", args: "{}", result: "3", isError: false)
        try assertEqual(a, b)
    }

    // MARK: - ProcessPromptResult

    test("ProcessPromptResult with empty toolLog") {
        let result = ProcessPromptResult(content: "hello", toolLog: [])
        try assertEqual(result.content, "hello")
        try assertTrue(result.toolLog.isEmpty)
    }
    test("ProcessPromptResult with populated toolLog") {
        let log = ToolLogEntry(name: "add", args: "{\"a\":1,\"b\":2}", result: "3", isError: false)
        let result = ProcessPromptResult(content: "The sum is 3", toolLog: [log])
        try assertEqual(result.toolLog.count, 1)
        try assertEqual(result.toolLog[0].name, "add")
    }
    test("ProcessPromptResult content can be empty") {
        let result = ProcessPromptResult(content: "", toolLog: [])
        try assertTrue(result.content.isEmpty)
    }
}
