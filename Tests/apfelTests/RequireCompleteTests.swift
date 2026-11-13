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
        let msg = CompletionPolicy.incompleteMessage(cause: .contextWindow)
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

    // ========================================================================
    // MARK: - Preflight: no exact finish signal + explicit cap (PR #551 review)
    //
    // Below macOS 26.4 completion tokens are the chars/4 estimate, so an
    // explicit --max-tokens cap cannot be detected; the flag must refuse
    // before generating instead of guessing. Capability injected via the
    // existing #315 TokenCountFallback.
    // ========================================================================

    let oldOS = TokenCountFallback.osTooOld(currentOS: "26.1.0")

    test("preflight: approximate count + --max-tokens + --require-complete -> refusal") {
        let refusal = CompletionPolicy.preflightRefusal(
            requireComplete: true, maxTokens: 4, tokenCountFallback: oldOS)
        guard let refusal else { throw TestFailure("expected a refusal") }
        try assertTrue(refusal.contains("--require-complete"), refusal)
        try assertTrue(refusal.contains("--max-tokens"), refusal)
        try assertTrue(refusal.contains("macOS 26.4"), refusal)
        try assertTrue(refusal.contains("26.1.0"), refusal)
        try assertTrue(refusal.contains("update macOS"), refusal)
    }

    test("preflight: refusal exit code is the usage error (2), not incomplete (8)") {
        try assertEqual(CompletionPolicy.preflightExitCode, ApfelExitCodes.usageError)
        try assertTrue(CompletionPolicy.preflightExitCode != ApfelExitCodes.incomplete)
    }

    test("preflight: exact count (tokenizer API usable) -> no refusal") {
        try assertNil(CompletionPolicy.preflightRefusal(
            requireComplete: true, maxTokens: 4, tokenCountFallback: nil))
    }

    test("preflight: approximate count without --max-tokens -> no refusal (context truncation is exact)") {
        try assertNil(CompletionPolicy.preflightRefusal(
            requireComplete: true, maxTokens: nil, tokenCountFallback: oldOS))
    }

    test("preflight: approximate count + --max-tokens without the flag -> no refusal (default unchanged)") {
        try assertNil(CompletionPolicy.preflightRefusal(
            requireComplete: false, maxTokens: 4, tokenCountFallback: oldOS))
    }

    test("preflight: model unavailable is not this refusal's business (availability gate owns it)") {
        try assertNil(CompletionPolicy.preflightRefusal(
            requireComplete: true, maxTokens: 4, tokenCountFallback: .modelUnavailable))
    }

    // ========================================================================
    // MARK: - Default mode: finish reason is unknown, not "stop" (macOS 26 run)
    //
    // Without --require-complete an approximate Mac with an explicit cap
    // still generates, but its stop/length decision is an estimate in both
    // directions. apfel must not report it as fact.
    // ========================================================================

    test("finish note: approximate count + explicit cap -> note naming the cap and macOS 26.4") {
        guard let note = CompletionPolicy.unknownFinishNote(maxTokens: 4, tokenCountFallback: oldOS) else {
            throw TestFailure("expected a note")
        }
        try assertTrue(note.contains("--max-tokens 4"), note)
        try assertTrue(note.contains("macOS 26.4"), note)
        try assertTrue(note.contains("26.1.0"), note)
        try assertTrue(!note.contains("JSON"), "plain output has no envelope to mention (#564): \(note)")
    }

    test("finish note: -o json also says finish_reason is left out of the envelope (#564)") {
        guard let note = CompletionPolicy.unknownFinishNote(maxTokens: 4, tokenCountFallback: oldOS, jsonEnvelope: true) else {
            throw TestFailure("expected a note")
        }
        try assertTrue(note.contains("--max-tokens 4"), note)
        try assertTrue(note.contains("finish_reason is left out of the JSON envelope"), note)
    }

    test("finish note: exact count, or no explicit cap -> no note") {
        try assertNil(CompletionPolicy.unknownFinishNote(maxTokens: 4, tokenCountFallback: nil))
        try assertNil(CompletionPolicy.unknownFinishNote(maxTokens: nil, tokenCountFallback: oldOS))
        try assertNil(CompletionPolicy.unknownFinishNote(maxTokens: 4, tokenCountFallback: .modelUnavailable))
    }

    test("reported finish: exact signal reports the engine's reason") {
        try assertEqual(CompletionPolicy.reportedFinishReason(.stop, truncation: nil, finishSignalExact: true), .stop)
        try assertEqual(CompletionPolicy.reportedFinishReason(.length, truncation: .tokenCap(4), finishSignalExact: true), .length)
    }

    test("reported finish: approximate signal makes an estimated stop or cap length unknown (nil)") {
        try assertNil(CompletionPolicy.reportedFinishReason(.stop, truncation: nil, finishSignalExact: false))
        try assertNil(CompletionPolicy.reportedFinishReason(.length, truncation: .tokenCap(4), finishSignalExact: false))
    }

    test("reported finish: a context-window cut-off is exact on every OS") {
        try assertEqual(CompletionPolicy.reportedFinishReason(.length, truncation: .contextWindow, finishSignalExact: false), .length)
    }

    test("reported finish: tool calls and content filter are never estimates") {
        try assertEqual(CompletionPolicy.reportedFinishReason(.toolCalls, truncation: nil, finishSignalExact: false), .toolCalls)
        try assertEqual(CompletionPolicy.reportedFinishReason(.contentFilter, truncation: nil, finishSignalExact: false), .contentFilter)
    }

    // ========================================================================
    // MARK: - Truncation warning names the real cause (PR #551 review)
    // ========================================================================

    test("length warning: explicit cap names --max-tokens and not the context window") {
        let msg = CompletionPolicy.lengthWarning(cause: .tokenCap(4))
        try assertTrue(msg.contains("--max-tokens 4"), msg)
        try assertTrue(msg.contains("finish_reason=length"), msg)
        try assertTrue(!msg.contains("context window"), msg)
    }

    test("length warning: context window names the context window") {
        let msg = CompletionPolicy.lengthWarning(cause: .contextWindow)
        try assertTrue(msg.contains("context window"), msg)
        try assertTrue(msg.contains("finish_reason=length"), msg)
    }

    test("incomplete message: names the actual cause") {
        let cap = CompletionPolicy.incompleteMessage(cause: .tokenCap(4))
        try assertTrue(cap.contains("--max-tokens 4"), cap)
        try assertTrue(!cap.contains("context window"), cap)
        try assertTrue(cap.contains("finish_reason=length") && cap.contains("--require-complete"), cap)
        let ctx = CompletionPolicy.incompleteMessage(cause: .contextWindow)
        try assertTrue(ctx.contains("context window"), ctx)
    }

    test("truncation cause: the cap path reports tokenCap with the limit") {
        try assertEqual(TruncationCause.resolve(finishReason: capOutcome(), maxTokens: 128), .tokenCap(128))
    }

    test("truncation cause: a non-length finish has no cause") {
        try assertNil(TruncationCause.resolve(finishReason: stopOutcome(), maxTokens: 128))
    }

    // ========================================================================
    // MARK: - --code: empty extracted code is never a silent success
    // ========================================================================

    test("code output: unterminated fence with no body (capped run) -> noCode, exit 7") {
        let r = CodeOutputPolicy.resolve(response: "```python\n")
        guard case .noCode(let msg) = r else { throw TestFailure("expected noCode, got \(r)") }
        try assertTrue(msg.contains("empty"), msg)
        try assertEqual(CodeOutputPolicy.Resolution.noCode(msg).exitCode, ApfelExitCodes.noCode)
    }

    test("code output: closed but empty block -> noCode") {
        guard case .noCode = CodeOutputPolicy.resolve(response: "```bash\n\n```\n") else {
            throw TestFailure("expected noCode")
        }
    }

    test("code output: empty response -> noCode") {
        guard case .noCode = CodeOutputPolicy.resolve(response: "  \n") else {
            throw TestFailure("expected noCode")
        }
    }

    test("code output: a real block -> code, exit 0") {
        let r = CodeOutputPolicy.resolve(response: "```python\nprint(1)\n```")
        guard case .code(let crop) = r else { throw TestFailure("expected code, got \(r)") }
        try assertEqual(crop.code, "print(1)\n")
        try assertEqual(crop.language, "python")
        try assertEqual(r.exitCode, ApfelExitCodes.success)
    }

    test("code output: unterminated fence with partial code salvages it") {
        guard case .code(let crop) = CodeOutputPolicy.resolve(response: "```python\nimport csv") else {
            throw TestFailure("expected code")
        }
        try assertEqual(crop.code, "import csv\n")
    }
}
