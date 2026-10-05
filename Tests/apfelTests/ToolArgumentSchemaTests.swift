// ToolArgumentSchemaTests - validate model-emitted tool arguments against the
// tool's declared inputSchema before execution (#193). On macOS 27 the model
// can invent argument shapes (e.g. multiply({"numbers": [...]}) against a
// schema requiring `a` and `b`); the validator must reject those so the
// existing tool-error feedback loop lets the model retry.

import Foundation
import ApfelCore

func runToolArgumentSchemaTests() {

    let multiplySchema = """
    {"type": "object", "properties": {"a": {"type": "number"}, "b": {"type": "number"}}, "required": ["a", "b"]}
    """

    func expectInvalid(_ name: String, _ arguments: String, _ schema: String?, _ contains: [String]) throws {
        do {
            try MCPProtocol.validateToolArguments(name: name, arguments: arguments, inputSchemaJSON: schema)
            throw TestFailure("expected invalidArguments, nothing thrown")
        } catch let e as MCPError {
            guard case .invalidArguments(let msg) = e else {
                throw TestFailure("expected invalidArguments, got \(e)")
            }
            for needle in contains {
                try assertTrue(msg.contains(needle), "message '\(msg)' should contain '\(needle)'")
            }
        }
    }

    test("valid arguments matching schema pass unchanged") {
        try MCPProtocol.validateToolArguments(
            name: "multiply", arguments: #"{"a": 247, "b": 83}"#, inputSchemaJSON: multiplySchema)
    }

    test("missing required keys throw invalidArguments naming tool, keys and expected params") {
        try expectInvalid(
            "multiply", #"{"a": 247}"#, multiplySchema,
            ["multiply", "b", "a (number)", "b (number)"])
    }

    test("unexpected key outside properties throws and names the key") {
        try expectInvalid(
            "multiply", #"{"numbers": [247, 83]}"#, multiplySchema,
            ["multiply", "numbers", "a", "b"])
    }

    test("additionalProperties true permits extra keys") {
        let schema = """
        {"type": "object", "properties": {"a": {"type": "number"}}, "required": ["a"], "additionalProperties": true}
        """
        try MCPProtocol.validateToolArguments(
            name: "t", arguments: #"{"a": 1, "extra": 2}"#, inputSchemaJSON: schema)
    }

    test("additionalProperties false still rejects extra keys") {
        let schema = """
        {"type": "object", "properties": {"a": {"type": "number"}}, "additionalProperties": false}
        """
        try expectInvalid("t", #"{"a": 1, "extra": 2}"#, schema, ["extra"])
    }

    test("nil schema skips schema validation") {
        try MCPProtocol.validateToolArguments(
            name: "t", arguments: #"{"anything": true}"#, inputSchemaJSON: nil)
    }

    test("unparseable schema skips schema validation") {
        try MCPProtocol.validateToolArguments(
            name: "t", arguments: #"{"anything": true}"#, inputSchemaJSON: "{not json}")
    }

    test("empty properties object accepts any keys (argument-ignoring tools)") {
        // JSON Schema: `properties: {}` does not close the object unless
        // `additionalProperties: false`. Tools that ignore their arguments
        // declare exactly this shape; rejecting invented keys there would
        // trap the model in a retry loop with zero parameter names to use.
        let schema = #"{"type": "object", "properties": {}}"#
        try MCPProtocol.validateToolArguments(
            name: "fetch_document", arguments: #"{"document_id": "document_001"}"#,
            inputSchemaJSON: schema)
    }

    test("schema without properties or required accepts any object") {
        try MCPProtocol.validateToolArguments(
            name: "t", arguments: #"{"x": 1}"#, inputSchemaJSON: #"{"type": "object"}"#)
    }

    test("non-object arguments with required keys throw") {
        try expectInvalid("multiply", "[247, 83]", multiplySchema, ["multiply", "a", "b"])
    }

    test("empty arguments with required keys throw") {
        try expectInvalid("multiply", "", multiplySchema, ["multiply", "a", "b"])
    }

    test("empty arguments with no required keys pass") {
        let schema = #"{"type": "object", "properties": {"a": {"type": "number"}}}"#
        try MCPProtocol.validateToolArguments(name: "t", arguments: "  ", inputSchemaJSON: schema)
    }

    test("malformed arguments JSON still throws invalidArguments (delegates to #241 check)") {
        try expectInvalid("t", "{not json}", multiplySchema, ["not valid JSON"])
    }

    test("required key present but extra key absent passes with additionalProperties omitted") {
        try MCPProtocol.validateToolArguments(
            name: "multiply", arguments: #"{"a": 1, "b": 2}"#, inputSchemaJSON: multiplySchema)
    }

    test("property without type is listed by name only in the error message") {
        let schema = #"{"type": "object", "properties": {"q": {}}, "required": ["q"]}"#
        try expectInvalid("search", "{}", schema, ["search", "q"])
    }

    // MARK: - toolRetryPrompt (#193)
    // The corrective re-prompt after a schema rejection. Wording is
    // reliability-tested on-device: this exact phrasing made the model
    // re-emit a corrected call 5/5 on macOS 27 where descriptive variants
    // peaked at 4/5.

    test("toolRetryPrompt names the tool and the required parameters") {
        let prompt = MCPProtocol.toolRetryPrompt(name: "multiply", inputSchemaJSON: multiplySchema)
        try assertEqual(
            prompt,
            "Your tool call used wrong parameter names and was rejected. "
                + "Call the tool 'multiply' again now with the same values, "
                + "using the parameter names 'a' and 'b'. "
                + "Respond ONLY with the tool call JSON, no other text.")
    }

    test("toolRetryPrompt uses singular wording for a single parameter") {
        let schema = #"{"type": "object", "properties": {"a": {"type": "number"}}, "required": ["a"]}"#
        let prompt = MCPProtocol.toolRetryPrompt(name: "sqrt", inputSchemaJSON: schema)
        try assertTrue(prompt?.contains("using the parameter name 'a'") == true,
                       "got: \(prompt ?? "nil")")
    }

    test("toolRetryPrompt falls back to property names when required is absent") {
        let schema = #"{"type": "object", "properties": {"q": {"type": "string"}}}"#
        let prompt = MCPProtocol.toolRetryPrompt(name: "search", inputSchemaJSON: schema)
        try assertTrue(prompt?.contains("'q'") == true, "got: \(prompt ?? "nil")")
    }

    test("toolRetryPrompt is nil without a schema or without parameter names") {
        try assertNil(MCPProtocol.toolRetryPrompt(name: "t", inputSchemaJSON: nil))
        try assertNil(MCPProtocol.toolRetryPrompt(name: "t", inputSchemaJSON: "{not json}"))
        try assertNil(MCPProtocol.toolRetryPrompt(
            name: "t", inputSchemaJSON: #"{"type": "object", "properties": {}}"#))
    }

    test("toolRetryPrompt joins three parameter names with commas and 'and'") {
        let schema = #"{"type": "object", "required": ["a", "b", "c"]}"#
        let prompt = MCPProtocol.toolRetryPrompt(name: "t", inputSchemaJSON: schema)
        try assertTrue(prompt?.contains("'a', 'b' and 'c'") == true, "got: \(prompt ?? "nil")")
    }
}
