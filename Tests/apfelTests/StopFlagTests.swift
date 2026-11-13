// ============================================================================
// StopFlagTests.swift - Unit tests for the repeatable --stop flag (#483).
// Happy paths, every value error, and every rejected combination. Error
// tests verify CLIParseError + message.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

private func expectParseError(_ args: [String], env: [String: String] = [:], contains needle: String) throws {
    do {
        _ = try CLIArguments.parse(args, env: env, readFile: { _ in #"{"type":"object","properties":{"a":{"type":"string"}}}"# })
        throw TestFailure("expected CLIParseError containing '\(needle)' for \(args)")
    } catch let e as CLIParseError {
        try assertTrue(e.message.contains(needle), "message was: \(e.message)")
    }
}

func runStopFlagTests() {

    // MARK: - Happy path

    test("--stop is a known flag") {
        try assertTrue(CLIArguments.knownFlags.contains("--stop"))
    }

    test("no --stop means no stop sequences") {
        let args = try CLIArguments.parse(["hello"])
        try assertEqual(args.stopSequences, [])
    }

    test("--stop stores the sequence verbatim") {
        let args = try CLIArguments.parse(["--stop", "\nObservation", "write"])
        try assertEqual(args.stopSequences, ["\nObservation"])
        try assertEqual(args.prompt, "write")
        try assertEqual(args.mode, .single)
    }

    test("--stop is repeatable and keeps order") {
        let args = try CLIArguments.parse(["--stop", "END", "--stop", "---", "x"])
        try assertEqual(args.stopSequences, ["END", "---"])
    }

    test("--stop value may start with a dash") {
        let args = try CLIArguments.parse(["--stop", "-- end", "x"])
        try assertEqual(args.stopSequences, ["-- end"])
    }

    test("--stop works with --stream") {
        let args = try CLIArguments.parse(["--stream", "--stop", "END", "x"])
        try assertEqual(args.mode, .stream)
        try assertEqual(args.stopSequences, ["END"])
    }

    test("--stop works with --messages") {
        let args = try CLIArguments.parse(["--messages", "conv.json", "--stop", "END"], readFile: { _ in
            #"[{"role":"user","content":"hi"}]"#
        })
        try assertEqual(args.stopSequences, ["END"])
    }

    test("--stop works with -o json and --code") {
        let args = try CLIArguments.parse(["-o", "json", "--code", "--stop", "END", "x"])
        try assertEqual(args.stopSequences, ["END"])
        try assertTrue(args.codeOnly)
    }

    test("--stop accepts exactly the 4-sequence limit") {
        let args = try CLIArguments.parse(["--stop", "a", "--stop", "b", "--stop", "c", "--stop", "d", "x"])
        try assertEqual(args.stopSequences.count, 4)
    }

    // MARK: - Value errors

    test("--stop without a value is an error") {
        try expectParseError(["--stop"], contains: "--stop requires a non-empty stop sequence")
    }

    test("--stop with an empty value is an error") {
        try expectParseError(["--stop", "", "x"], contains: "--stop requires a non-empty stop sequence")
    }

    test("more than 4 --stop values is an error") {
        try expectParseError(["--stop", "a", "--stop", "b", "--stop", "c", "--stop", "d", "--stop", "e", "x"],
                             contains: "at most 4")
    }

    test("--stop values over the total size cap are an error") {
        let long = String(repeating: "x", count: StopSequences.maxTotalScalars + 1)
        try expectParseError(["--stop", long, "x"], contains: "\(StopSequences.maxTotalScalars)")
    }

    // MARK: - Rejected combinations

    test("--stop cannot combine with --chat") {
        try expectParseError(["--chat", "--stop", "END"], contains: "--stop requires a one-shot prompt; cannot combine with --chat")
    }

    test("--stop cannot combine with --serve") {
        try expectParseError(["--serve", "--stop", "END"], contains: "cannot combine with --serve")
    }

    test("--stop cannot combine with --benchmark") {
        try expectParseError(["--benchmark", "--stop", "END"], contains: "cannot combine with --benchmark")
    }

    test("--stop cannot combine with --count-tokens") {
        try expectParseError(["--count-tokens", "--stop", "END", "x"], contains: "cannot combine with --count-tokens")
    }

    test("--stop cannot combine with --model-info") {
        try expectParseError(["--model-info", "--stop", "END"], contains: "cannot combine with --model-info")
    }

    test("--stop cannot combine with --update") {
        try expectParseError(["--update", "--stop", "END"], contains: "cannot combine with --update")
    }

    test("--stop cannot combine with --schema") {
        try expectParseError(["--schema", "s.json", "--stop", "END", "x"], contains: "--stop cannot be combined with --schema")
    }

    test("--stop cannot combine with --mcp") {
        try expectParseError(["--mcp", "calc.py", "--stop", "END", "x"], contains: "--stop cannot be combined with MCP tool calling")
    }

    test("--stop cannot combine with APFEL_MCP from the environment") {
        try expectParseError(["--stop", "END", "x"], env: ["APFEL_MCP": "calc.py"], contains: "APFEL_MCP")
    }
}
