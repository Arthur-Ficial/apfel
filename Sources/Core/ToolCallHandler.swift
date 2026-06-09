import Foundation

/// A tool definition for system-prompt injection (no FoundationModels dependency).
public struct ToolDef: Sendable {
    public let name: String
    public let description: String?
    public let parametersJSON: String?

    public init(name: String, description: String?, parametersJSON: String?) {
        self.name = name
        self.description = description
        self.parametersJSON = parametersJSON
    }
}

/// Result of executing a prompt through the unified processPrompt() pipeline.
package struct ProcessPromptResult: Sendable {
    public let content: String
    public let toolLog: [ToolLogEntry]
    public let finishReason: FinishReason

    public init(content: String, toolLog: [ToolLogEntry], finishReason: FinishReason) {
        self.content = content; self.toolLog = toolLog; self.finishReason = finishReason
    }

    /// Pre-1.3.3 initialiser preserved for source compatibility. Delegates to
    /// the three-argument init with `finishReason: .stop`.
    public init(content: String, toolLog: [ToolLogEntry]) {
        self.init(content: content, toolLog: toolLog, finishReason: .stop)
    }
}

/// A log entry from executing a tool call.
package struct ToolLogEntry: Sendable, Equatable {
    public let name: String
    public let args: String
    public let result: String
    public let isError: Bool

    public init(name: String, args: String, result: String, isError: Bool) {
        self.name = name; self.args = args; self.result = result; self.isError = isError
    }
}

/// A parsed tool call extracted from model output.
public struct ParsedToolCall: Sendable {
    public let id: String
    public let name: String
    public let argumentsString: String
}

public enum ToolCallHandler {

    // MARK: - System Prompt Building

    /// Build output format instructions only (no tool schemas).
    /// Always needed — tells the model HOW to respond with tool calls.
    public static func buildOutputFormatInstructions(toolNames: [String]) -> String {
        return """
        ## Tool Calling Format
        \(toolCallResponseFormat(functionHint: " (\(toolNames.joined(separator: ", ")))"))
        """
    }

    /// Build text-based schema injection for tools that failed native conversion.
    public static func buildFallbackPrompt(tools: [ToolDef]) -> String {
        guard !tools.isEmpty else { return "" }
        return """
        Additional function schemas (text fallback):
        \(serializedToolSchemas(tools))
        """
    }

    // MARK: - Tool Call Detection

    /// Detect and parse tool calls from model output.
    /// Handles: clean JSON, JSON in markdown code blocks, JSON after preamble text.
    /// Returns nil if the response is a normal text reply.
    public static func detectToolCall(in response: String) -> [ParsedToolCall]? {
        for candidate in extractCandidates(from: response) {
            if let calls = parseToolCallJSON(candidate), !calls.isEmpty {
                return calls
            }
            if let repaired = repairUnclosedBrackets(candidate),
               let calls = parseToolCallJSON(repaired), !calls.isEmpty {
                return calls
            }
        }
        return nil
    }

    // MARK: - Private Helpers

    private static func extractCandidates(from text: String) -> [String] {
        var candidates: [String] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Whole response as-is
        candidates.append(trimmed)

        // 2. Strip markdown code blocks ```json ... ``` or ``` ... ```
        var remaining = text
        while let start = remaining.range(of: "```"),
              let nextIdx = remaining.index(start.upperBound, offsetBy: 1, limitedBy: remaining.endIndex),
              let end = remaining.range(of: "```", range: nextIdx..<remaining.endIndex) {
            let block = String(remaining[start.upperBound..<end.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip optional "json" language tag
            let stripped = block.hasPrefix("json\n") ? String(block.dropFirst(5)) : block
            candidates.append(stripped)
            remaining = String(remaining[end.upperBound...])
        }

        // 3. Extract balanced JSON object starting at {"tool_calls" (handles trailing text).
        //    The brace counter is string-aware: braces inside quoted JSON strings
        //    (e.g. the '}' in an id like "call_a}b") must not affect depth.
        if let range = text.range(of: "{\"tool_calls\"") {
            var depth = 0
            var inString = false
            var escaped = false
            var idx = range.lowerBound
            while idx < text.endIndex {
                let ch = text[idx]
                if inString {
                    if escaped {
                        escaped = false
                    } else if ch == "\\" {
                        escaped = true
                    } else if ch == "\"" {
                        inString = false
                    }
                } else if ch == "\"" {
                    inString = true
                } else if ch == "{" {
                    depth += 1
                } else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        candidates.append(String(text[range.lowerBound...idx]))
                        break
                    }
                }
                idx = text.index(after: idx)
            }
            // Fallback: take everything from {"tool_calls" to end
            if depth != 0 {
                candidates.append(String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return candidates
    }

    private static func serializedToolSchemas(_ tools: [ToolDef]) -> String {
        let schemaObjects = tools.map { toolSchemaObject(for: $0) }
        guard let data = try? JSONSerialization.data(
            withJSONObject: schemaObjects,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func toolSchemaObject(for tool: ToolDef) -> [String: Any] {
        var object: [String: Any] = ["name": tool.name]
        if let description = tool.description {
            object["description"] = description
        }
        if let parametersJSON = tool.parametersJSON,
           let data = parametersJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) {
            object["parameters"] = parsed
        }
        return object
    }

    /// Ensure an arguments string is valid JSON per OpenAI spec.
    /// If the string is already a JSON object/array, return as-is.
    /// If it's empty, return "{}". If it's a plain string (e.g. "desktop"),
    /// wrap it as {"value": "desktop"} so consumers can always JSON-parse it.
    public static func ensureJSONArguments(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty string → empty object
        if trimmed.isEmpty { return "{}" }
        // Already a JSON object or array
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return s }
        // Plain string — wrap as {"value": "..."} using the JSON encoder for escaping.
        return jsonObjectString(["value": trimmed]) ?? "{}"
    }

    /// The model sometimes omits the closing `]` for the tool_calls array,
    /// producing invalid JSON. This repair inserts missing brackets (string-aware)
    /// before the outermost closing `}` so the candidate can be re-parsed.
    private static func repairUnclosedBrackets(_ json: String) -> String? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return nil }

        var bracketDepth = 0
        var inString = false
        var escaped = false

        for ch in trimmed {
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else if ch == "\"" {
                inString = true
            } else if ch == "[" {
                bracketDepth += 1
            } else if ch == "]" {
                bracketDepth -= 1
            }
        }

        guard bracketDepth > 0 else { return nil }

        let insertPos = trimmed.index(before: trimmed.endIndex)
        var repaired = trimmed
        repaired.insert(contentsOf: String(repeating: "]", count: bracketDepth), at: insertPos)
        return repaired
    }

    private static func parseToolCallJSON(_ json: String) -> [ParsedToolCall]? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCalls = obj["tool_calls"] as? [[String: Any]],
              !rawCalls.isEmpty else { return nil }

        var result: [ParsedToolCall] = []
        for call in rawCalls {
            guard let id = call["id"] as? String else { continue }

            let name: String
            let rawArguments: Any?
            if let fn = call["function"] as? [String: Any],
               let fnName = fn["name"] as? String {
                name = fnName
                rawArguments = fn["arguments"]
            } else if let fnName = call["function"] as? String {
                name = fnName
                rawArguments = call["arguments"]
            } else {
                continue
            }

            let args: String
            if let s = rawArguments as? String {
                args = ensureJSONArguments(s)
            } else if let obj = rawArguments,
                      let data = try? JSONSerialization.data(withJSONObject: obj),
                      let s = String(data: data, encoding: .utf8) {
                args = s
            } else {
                args = "{}"
            }
            result.append(ParsedToolCall(id: id, name: name, argumentsString: args))
        }
        return result.isEmpty ? nil : result
    }

    private static func toolCallResponseFormat(functionHint: String = "") -> String {
        """
        When you need to call a function\(functionHint), respond ONLY with this exact JSON (no other text before or after):
        {"tool_calls": [{"id": "call_<unique>", "type": "function", "function": {"name": "<name>", "arguments": "<escaped_json_string>"}}]}

        Replace <unique> with a short unique string, <name> with the function name, and <escaped_json_string> with the arguments as a JSON-encoded string.
        """
    }

    private static func jsonObjectString(_ object: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string.replacingOccurrences(of: "\\/", with: "/")
    }
}
