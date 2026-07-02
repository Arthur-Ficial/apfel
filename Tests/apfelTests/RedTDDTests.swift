// ============================================================================
// RedTDDTests.swift - TDD RED tests for the open bug tickets (#177/#178/#180/
// #181/#183). These are DELIBERATELY FAILING. They assert the CORRECT
// behaviour described in each GitHub issue; the fix that makes them pass is a
// separate follow-up task. Do not "fix" the code to make these green here.
//
// Branch: tdd/red-tests-167-183
// Bugs in the executable target (#175/#176/#179/#182) and the feature tickets
// (#167-#171) are red-tested at the wire/CLI boundary in
// Tests/integration/test_tdd_red.py - they cannot be reached from this
// pure-library test target (see Package.swift: apfel-tests depends only on
// ApfelCore + ApfelCLI).
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runRedTDDTests() {

    // ---- #177: env vars / --retry must validate like their flags --------------

    test("#177 APFEL_PORT out-of-range falls back to default (like --port)") {
        // --port rejects values outside 1..65535; the env var must too.
        let args = try CLIArguments.parse([], env: ["APFEL_PORT": "99999"])
        try assertEqual(args.serverPort, 11434,
            "out-of-range APFEL_PORT must fall back to 11434, not bind an invalid port")
    }

    test("#177 APFEL_TEMPERATURE negative is rejected (like --temperature)") {
        // --temperature requires >= 0; the env var currently accepts -5.
        let args = try CLIArguments.parse([], env: ["APFEL_TEMPERATURE": "-5"])
        try assertNil(args.temperature,
            "negative APFEL_TEMPERATURE must be rejected like the --temperature flag")
    }

    test("#177 APFEL_CONTEXT_MAX_TURNS zero is rejected (like the flag)") {
        // --context-max-turns requires > 0; the env var currently accepts 0.
        let args = try CLIArguments.parse([], env: ["APFEL_CONTEXT_MAX_TURNS": "0"])
        try assertNil(args.contextMaxTurns,
            "non-positive APFEL_CONTEXT_MAX_TURNS must be rejected like the flag")
    }

    test("#177 --retry=0 throws like other numeric flags") {
        do {
            _ = try CLIArguments.parse(["--retry=0", "hi"])
            throw TestFailure("expected CLIParseError for --retry=0, none thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--retry"),
                "error should name the --retry flag, got: \(e.message)")
        }
    }

    // ---- #178: balanced-JSON extraction must ignore braces inside strings -----

    test("#178 tool call with '}' inside a string value is still detected") {
        // Leading/trailing prose forces the balanced-extraction path (#3 in
        // extractCandidates). The '}' inside the id string "call_a}b" makes the
        // brace-depth counter hit zero early and truncates the JSON candidate.
        let resp = "Let me help. {\"tool_calls\":[{\"id\":\"call_a}b\","
            + "\"type\":\"function\",\"function\":{\"name\":\"calc\","
            + "\"arguments\":\"{}\"}}]} There you go."
        let calls = ToolCallHandler.detectToolCall(in: resp)
        try assertNotNil(calls,
            "a tool call whose string value contains '}' must still be detected")
        try assertEqual(calls?.count, 1, "exactly one tool call expected")
        try assertEqual(calls?.first?.name, "calc", "tool name should parse as 'calc'")
    }

    // ---- #180: non-dictionary property schemas must not be silently dropped ---

    test("#180 non-dict property schema is surfaced, not silently dropped") {
        // "bad" is a string, not an object schema. Today parseObject hits
        // `else { continue }` and drops it, returning an object with one prop.
        let json = "{\"type\":\"object\",\"properties\":"
            + "{\"good\":{\"type\":\"string\"},\"bad\":\"notadict\"},"
            + "\"required\":[\"good\"]}"
        do {
            let ir = try SchemaParser.parse(json: json, name: "root")
            guard case .object(_, _, let props) = ir else {
                throw TestFailure("expected an object schema, got \(ir)")
            }
            // Acceptable fix A: represent the property. (Fix B: throw - handled below.)
            try assertEqual(props.count, 2,
                "malformed property 'bad' must not be silently dropped")
        } catch let e as SchemaParser.Error {
            // Acceptable fix B: surface a parse error instead of silent loss.
            _ = e
        }
    }

    // ---- #181: unknown GenerationError case must NOT guess from locale text ---

    test("#181 unknown GenerationError case classifies to .unknown, not a keyword guess") {
        // caseName is not in FoundationModelsGenerationErrorCase, so firstMatch
        // returns nil. Today classify() then falls through to English-keyword
        // matching and sees "refused" -> .refusal. That locale-fragile guess is
        // the bug: an unrecognised GenerationError must classify to .unknown.
        let stub = FoundationModelsGenerationErrorStub(
            caseName: "quotaExhausted",
            localizedMsg: "the request was refused for policy reasons"
        )
        try assertEqual(
            ApfelError.classify(stub),
            .unknown("the request was refused for policy reasons"),
            "unknown GenerationError case must not be re-classified via locale keywords")
    }

    // ---- #183: strip() must trim when there is no fence (per its docstring) ---

    test("#183 strip() trims surrounding whitespace when no fence present") {
        // Docstring: "Returns the input trimmed of surrounding whitespace
        // otherwise." Today the no-fence branch returns the original content.
        try assertEqual(JSONFenceStripper.strip("  {\"a\":1}  "), "{\"a\":1}",
            "no-fence input must be trimmed, matching the fenced path and the docstring")
    }
}
