// ============================================================================
// GuidedToolStepTests.swift - the pure half of the guided tool step (#533):
// the step schema, the lenient tool schemas, the decision instruction and the
// step parser. No model: the server half is covered by integration tests.
// ============================================================================

import Foundation
import ApfelCore

func runGuidedToolStepTests() {
    func object(_ json: String) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw TestFailure("not a JSON object: \(json)")
        }
        return value
    }
    let search = ToolDef(
        name: "web_search", description: "Search the web.",
        parametersJSON: #"{"type":"object","properties":{"query":{"type":"string","minLength":1,"maxLength":4096},"n":{"type":"number","multipleOf":1}},"required":["query"],"additionalProperties":false}"#)
    let location = ToolDef(name: "get_location", description: "Where the user is.", parametersJSON: #"{"type":"object","properties":{}}"#)
    let noParams = ToolDef(name: "ping", description: nil, parametersJSON: nil)

    // --- lenient schemas ---

    test("lenientSchema drops string-shape and step keywords guided generation rejects (#533)") {
        let lenient = try object(GuidedToolStep.lenientSchemaJSON(search.parametersJSON!)!)
        let props = lenient["properties"] as? [String: [String: Any]]
        try assertNil(props?["query"]?["minLength"])
        try assertNil(props?["query"]?["maxLength"])
        try assertNil(props?["n"]?["multipleOf"])
        try assertEqual(props?["query"]?["type"] as? String, "string")
        try assertEqual(lenient["required"] as? [String], ["query"])
    }

    test("lenientSchema drops non-string enums") {
        let raw = #"{"type":"object","properties":{"mode":{"type":"integer","enum":[1,2]}}}"#
        let lenient = try object(GuidedToolStep.lenientSchemaJSON(raw)!)
        try assertNil((lenient["properties"] as? [String: [String: Any]])?["mode"]?["enum"])
    }

    test("lenientSchema keeps map schemas, so such a tool falls back to free text instead of losing its entries") {
        let raw = #"{"type":"object","properties":{"env":{"type":"object","additionalProperties":{"type":"string"}},"tags":{"type":"object","patternProperties":{"^x_":{"type":"string"}}}}}"#
        let lenient = try object(GuidedToolStep.lenientSchemaJSON(raw)!)
        let props = lenient["properties"] as? [String: [String: Any]]
        try assertNotNil(props?["env"]?["additionalProperties"] as? [String: Any])
        try assertNotNil(props?["tags"]?["patternProperties"])
    }

    test("a tool whose parameters are a root $ref or union is not mistaken for a parameterless tool") {
        for raw in [##"{"$ref":"#/$defs/P","$defs":{"P":{"type":"object","properties":{"q":{"type":"string"}},"required":["q"]}}}"##,
                    #"{"anyOf":[{"type":"object","properties":{"q":{"type":"string"}}}]}"#] {
            do {
                _ = try GuidedToolStep(tools: [ToolDef(name: "find", description: nil, parametersJSON: raw)], mode: .auto)
                throw TestFailure("expected unavailable for \(raw)")
            } catch let error as GuidedToolStep.Unavailable {
                try assertTrue(error.reason.contains("find"))
            }
        }
    }

    test("lenientSchema recurses into array items and $defs") {
        let raw = #"{"type":"object","properties":{"urls":{"type":"array","items":{"type":"string","pattern":"^https"},"uniqueItems":true}},"$defs":{"x":{"type":"string","format":"uri","minLength":2}}}"#
        let lenient = try object(GuidedToolStep.lenientSchemaJSON(raw)!)
        let urls = (lenient["properties"] as? [String: [String: Any]])?["urls"]
        try assertNil((urls?["items"] as? [String: Any])?["pattern"])
        try assertNil(urls?["uniqueItems"])
        try assertNil(((lenient["$defs"] as? [String: Any])?["x"] as? [String: Any])?["minLength"])
    }

    test("lenientSchema returns nil for text that is not a JSON object") {
        try assertNil(GuidedToolStep.lenientSchemaJSON("not json"))
        try assertNil(GuidedToolStep.lenientSchemaJSON("[1]"))
    }

    // --- step schema ---

    test("step schema under auto offers every tool plus the answer action (#533)") {
        let step = try GuidedToolStep(tools: [search, location, noParams], mode: .auto)
        let schema = try object(step.schemaJSON)
        try assertEqual(schema["required"] as? [String], ["action"])
        let action = (schema["properties"] as? [String: Any])?["action"] as? [String: Any]
        try assertEqual(action?["enum"] as? [String], ["web_search", "get_location", "ping", "answer"])
        let arguments = (schema["properties"] as? [String: Any])?["arguments"] as? [String: Any]
        let argProps = arguments?["properties"] as? [String: Any]
        try assertEqual(argProps?.keys.sorted(), ["web_search"], "only tools that declare properties get an arguments slot")
        try assertEqual(arguments?["required"] as? [String], [])
    }

    test("step schema under required leaves out the answer action") {
        let step = try GuidedToolStep(tools: [search, location], mode: .required)
        let action = ((try object(step.schemaJSON))["properties"] as? [String: Any])?["action"] as? [String: Any]
        try assertEqual(action?["enum"] as? [String], ["web_search", "get_location"])
    }

    test("step schema for a named tool_choice offers only that tool") {
        let step = try GuidedToolStep(tools: [search, location], mode: .specific("get_location"))
        let action = ((try object(step.schemaJSON))["properties"] as? [String: Any])?["action"] as? [String: Any]
        try assertEqual(action?["enum"] as? [String], ["get_location"])
    }

    test("the answer action is renamed when a tool is called answer") {
        let answerTool = ToolDef(name: "answer", description: nil, parametersJSON: nil)
        let step = try GuidedToolStep(tools: [answerTool], mode: .auto)
        try assertTrue(step.answerAction != "answer")
        let action = ((try object(step.schemaJSON))["properties"] as? [String: Any])?["action"] as? [String: Any]
        try assertEqual(action?["enum"] as? [String], ["answer", step.answerAction])
    }

    test("the answer action never collides with a tool name") {
        let tools = ["answer", "reply_to_user", "respond_to_user"].map { ToolDef(name: $0, description: nil, parametersJSON: nil) }
        let step = try GuidedToolStep(tools: tools, mode: .auto)
        try assertFalse(tools.map(\.name).contains(step.answerAction))
        try assertEqual(step.parse("{\"action\":\"\(step.answerAction)\"}"), .answer)
    }

    test("a disabled policy has no guided step") {
        do {
            _ = try GuidedToolStep(tools: [search], mode: .disabled)
            throw TestFailure("expected unavailable")
        } catch let error as GuidedToolStep.Unavailable {
            try assertTrue(error.reason.contains("no tools"))
        }
    }

    test("a tool whose parameters are not a JSON object makes the guided step unavailable") {
        let broken = ToolDef(name: "broken", description: nil, parametersJSON: "{not json")
        do {
            _ = try GuidedToolStep(tools: [broken], mode: .auto)
            throw TestFailure("expected unavailable")
        } catch let error as GuidedToolStep.Unavailable {
            try assertTrue(error.reason.contains("broken"))
        }
    }

    // --- instruction ---

    test("auto instruction lists the tools and tells the model when to answer") {
        let step = try GuidedToolStep(tools: [search], mode: .auto)
        try assertTrue(step.instructions.contains("- web_search: Search the web."))
        try assertTrue(step.instructions.contains("set action to \"answer\""))
        try assertTrue(step.instructions.contains("arguments.<its name>"))
        try assertFalse(step.instructions.contains("tool_calls"), "no free-text envelope in the guided prompt")
    }

    test("required and named instructions demand a call") {
        try assertTrue(try GuidedToolStep(tools: [search], mode: .required).instructions.contains("Call one of the tools now"))
        try assertTrue(try GuidedToolStep(tools: [search], mode: .specific("web_search")).instructions.contains("Call the tool web_search now"))
    }

    // --- parsing ---

    test("parse reads an answer decision") {
        let step = try GuidedToolStep(tools: [search], mode: .auto)
        try assertEqual(step.parse(#"{"action":"answer","arguments":{"web_search":{"query":"x"}}}"#), .answer)
    }

    test("parse reads a call with its arguments as compact JSON") {
        let step = try GuidedToolStep(tools: [search], mode: .auto)
        guard case .call(let name, let arguments)? = step.parse(#"{"action":"web_search","arguments":{"web_search":{"query":"who won"}}}"#) else {
            throw TestFailure("expected a call")
        }
        try assertEqual(name, "web_search")
        let parsed = try object(arguments ?? "")
        try assertEqual(parsed.count, 1)
        try assertEqual(parsed["query"] as? String, "who won")
    }

    test("parse reports a call without its arguments slot as arguments nil") {
        let step = try GuidedToolStep(tools: [search, location], mode: .auto)
        try assertEqual(step.parse(#"{"action":"web_search"}"#), .call(name: "web_search", arguments: nil))
        try assertEqual(step.parse(#"{"action":"get_location","arguments":{}}"#), .call(name: "get_location", arguments: "{}"))
    }

    test("parse rejects an unknown action and non-JSON") {
        let step = try GuidedToolStep(tools: [search], mode: .auto)
        try assertNil(step.parse(#"{"action":"delete_everything"}"#))
        try assertNil(step.parse("hello"))
    }

    test("argumentsRequest names the tool and carries its lenient schema") {
        let step = try GuidedToolStep(tools: [search, location], mode: .auto)
        let request = step.argumentsRequest(for: "web_search")
        try assertTrue(request?.prompt.contains("web_search") == true)
        let schema = try object(request?.schemaJSON ?? "")
        try assertNil(((schema["properties"] as? [String: [String: Any]])?["query"])?["minLength"])
        try assertNil(step.argumentsRequest(for: "nope"))
    }
}
