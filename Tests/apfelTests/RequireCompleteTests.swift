// ============================================================================
// RequireCompleteTests.swift - Unit tests for --require-complete (#484)
// Output-policy decisions on injected engine outcomes, exit code 8, the
// flag's parse behavior and every unsupported-combination parse error.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

private let oneTurn = "[{\"role\":\"user\",\"content\":\"hi\"}]"

/// Finish reason the engine reports for a natural end of generation.
private func stopOutcome() -> FinishReason {
    FinishReasonResolver.resolve(hasToolCalls: false, completionTokens: 12, maxTokens: nil)
}

/// Finish reason the engine reports when an explicit --max-tokens cap is hit.
private func capOutcome() -> FinishReason {
    FinishReasonResolver.resolve(hasToolCalls: false, completionTokens: 128, maxTokens: 128)
}

/// Finish reason the engine reports when the context window runs out while
/// generating (partial content already produced): StreamErrorResolver turns
/// the throw into a truncation, which the engine reports as `.length`.
private func contextExhaustedOutcome() throws -> FinishReason {
    switch StreamErrorResolver.resolve(prev: "def read_csv(path):\n    with open(", error: .contextOverflow) {
    case .truncated: return .length
    case .fatal(let e): throw TestFailure("expected truncation, got fatal \(e)")
    }
}

private func expectParseError(_ argv: [String], contains needles: [String], readFile: ((String) throws -> String)? = nil) throws {
    do {
        if let readFile {
            _ = try CLIArguments.parse(argv, readFile: readFile)
        } else {
            _ = try CLIArguments.parse(argv)
        }
        try assertTrue(false, "should have thrown for \(argv)")
    } catch let e as CLIParseError {
        for needle in needles {
            try assertTrue(e.message.contains(needle), "'\(e.message)' should contain '\(needle)'")
        }
    }
}

func runRequireCompleteTests() {

    // ========================================================================
    // MARK: - Exit code catalogue
    // ========================================================================

    test("ApfelExitCodes.incomplete is 8") {
        try assertEqual(ApfelExitCodes.incomplete, 8)
    }

    test("exit 8 does not collide with any established exit code") {
        let established: [Int32] = [
            ApfelExitCodes.success, ApfelExitCodes.runtimeError, ApfelExitCodes.usageError,
            ApfelExitCodes.guardrail, ApfelExitCodes.contextOverflow, ApfelExitCodes.modelUnavailable,
            ApfelExitCodes.rateLimited, ApfelExitCodes.noCode,
        ]
        try assertTrue(!established.contains(ApfelExitCodes.incomplete))
    }

    // ========================================================================
    // MARK: - Output policy on injected outcomes
    // ========================================================================

    test("policy: .stop with --require-complete -> complete, prints, exit unchanged") {
        let d = CompletionPolicy.decide(finishReason: stopOutcome(), requireComplete: true)
        try assertEqual(d, .complete)
        try assertTrue(d.writesStdout)
        try assertNil(d.exitCode)
    }

    test("policy: .stop without --require-complete -> complete") {
        try assertEqual(CompletionPolicy.decide(finishReason: stopOutcome(), requireComplete: false), .complete)
    }

    test("policy: explicit cap exhaustion with --require-complete -> rejected, no stdout, exit 8") {
        let reason = capOutcome()
        try assertEqual(reason, .length)
        let d = CompletionPolicy.decide(finishReason: reason, requireComplete: true)
        try assertEqual(d, .truncatedRejected)
        try assertTrue(!d.writesStdout)
        try assertEqual(d.exitCode, 8)
    }

    test("policy: output-side context exhaustion with --require-complete -> rejected, exit 8") {
        let d = CompletionPolicy.decide(finishReason: try contextExhaustedOutcome(), requireComplete: true)
        try assertEqual(d, .truncatedRejected)
        try assertTrue(!d.writesStdout)
        try assertEqual(d.exitCode, 8)
    }

    test("policy default (no flag): cap exhaustion keeps partial output, exit unchanged (#128/#130)") {
        let d = CompletionPolicy.decide(finishReason: capOutcome(), requireComplete: false)
        try assertEqual(d, .truncatedAllowed)
        try assertTrue(d.writesStdout)
        try assertNil(d.exitCode)
    }

    test("policy default (no flag): context exhaustion keeps partial output") {
        let d = CompletionPolicy.decide(finishReason: try contextExhaustedOutcome(), requireComplete: false)
        try assertEqual(d, .truncatedAllowed)
        try assertTrue(d.writesStdout)
    }

    test("policy: non-length finishes are not reclassified (tool calls, content filter)") {
        for reason in [FinishReason.toolCalls, .contentFilter] {
            try assertEqual(CompletionPolicy.decide(finishReason: reason, requireComplete: true), .complete)
        }
    }

    test("policy: only truncatedAllowed warns; rejected reports an error instead") {
        try assertTrue(CompletionPolicy.Decision.truncatedAllowed.warnsTruncation)
        try assertTrue(!CompletionPolicy.Decision.truncatedRejected.warnsTruncation)
        try assertTrue(!CompletionPolicy.Decision.complete.warnsTruncation)
    }

    test("policy: rejection message names finish_reason=length and exit 8 context") {
        let msg = CompletionPolicy.incompleteMessage
        try assertTrue(msg.contains("finish_reason=length"), msg)
        try assertTrue(msg.contains("--require-complete"), msg)
    }

    // ========================================================================
    // MARK: - Parse
    // ========================================================================

    test("--require-complete parses with a positional prompt") {
        let args = try CLIArguments.parse(["--require-complete", "hello"])
        try assertTrue(args.requireComplete)
        try assertEqual(args.mode, .single)
    }

    test("requireComplete defaults to false") {
        try assertTrue(!(try CLIArguments.parse(["hello"])).requireComplete)
    }

    test("--require-complete is a known flag") {
        try assertTrue(CLIArguments.isKnownFlag("--require-complete"))
    }

    test("--require-complete composes with --stream") {
        let args = try CLIArguments.parse(["--require-complete", "--stream", "hi"])
        try assertTrue(args.requireComplete)
        try assertEqual(args.mode, .stream)
    }

    test("--require-complete composes with --code and --max-tokens") {
        let args = try CLIArguments.parse(["--require-complete", "--code", "--max-tokens", "128", "csv reader"])
        try assertTrue(args.requireComplete)
        try assertTrue(args.codeOnly)
        try assertEqual(args.maxTokens, 128)
    }

    test("--require-complete composes with --messages") {
        let args = try CLIArguments.parse(["--require-complete", "--messages", "c.json"], readFile: { _ in oneTurn })
        try assertTrue(args.requireComplete)
        try assertNotNil(args.messagesJSON)
    }

    test("--require-complete composes with -o json and --quiet") {
        let args = try CLIArguments.parse(["--require-complete", "-o", "json", "-q", "hi"])
        try assertTrue(args.requireComplete)
        try assertEqual(args.outputFormat, .json)
        try assertTrue(args.quiet)
    }

    // ========================================================================
    // MARK: - Unsupported combinations (specific parse errors)
    // ========================================================================

    test("--require-complete --chat throws a specific error") {
        try expectParseError(["--require-complete", "--chat"], contains: ["--require-complete", "chat"])
    }

    test("--require-complete --serve throws a specific error") {
        try expectParseError(["--require-complete", "--serve"], contains: ["--require-complete", "serve"])
    }

    test("--require-complete --count-tokens throws a specific error") {
        try expectParseError(["--require-complete", "--count-tokens", "hi"], contains: ["--require-complete", "count-tokens"])
    }

    test("--require-complete --schema throws a specific error") {
        let schema = "{\"type\":\"object\",\"properties\":{\"a\":{\"type\":\"string\"}}}"
        try expectParseError(["--require-complete", "--schema", "s.json", "hi"],
                             contains: ["--require-complete", "--schema"], readFile: { _ in schema })
    }

    test("--require-complete --mcp throws a specific error") {
        try expectParseError(["--require-complete", "--mcp", "server.py", "hi"],
                             contains: ["--require-complete", "MCP"])
    }
}
