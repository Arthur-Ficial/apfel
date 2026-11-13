// ============================================================================
// BatchTests.swift - Unit tests for `apfel --batch` (#481).
// The pure pieces of the JSONL record processor: the incremental line framer
// (bounded read-ahead, UTF-8 boundaries, unterminated final line, oversized
// records), the record parser (independent records, malformed lines,
// missing / conflicting fields, escaped newlines), the result-line contract,
// the aggregate exit status, and every --batch flag rule.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

private func bytes(_ s: String) -> [UInt8] { Array(s.utf8) }

private func lines(_ frames: [BatchFrame]) -> [String] {
    frames.compactMap {
        if case .line(_, let b) = $0 { return String(decoding: b, as: UTF8.self) }
        return nil
    }
}

private func expectBatchParseError(_ args: [String], contains needle: String) throws {
    do {
        _ = try CLIArguments.parse(args, readFile: { _ in #"{"type":"object","properties":{"a":{"type":"string"}}}"# }, extractFile: { _ in "file text" })
        throw TestFailure("expected CLIParseError containing '\(needle)' for \(args)")
    } catch let e as CLIParseError {
        try assertTrue(e.message.contains(needle), "message was: \(e.message)")
    }
}

private func record(_ outcome: BatchParseOutcome) throws -> BatchRecord {
    guard case .record(let r) = outcome else { throw TestFailure("expected a record, got \(outcome)") }
    return r
}

private func invalid(_ outcome: BatchParseOutcome) throws -> (customID: String?, message: String) {
    guard case .invalid(let id, let message) = outcome else { throw TestFailure("expected invalid, got \(outcome)") }
    return (id, message)
}

private func decodeLine(_ line: String) throws -> [String: Any] {
    guard let obj = try JSONSerialization.jsonObject(with: Data(line.utf8), options: [.fragmentsAllowed]) as? [String: Any] else {
        throw TestFailure("not a JSON object: \(line)")
    }
    return obj
}

func runBatchTests() {

    // MARK: - Framer

    test("framer emits each complete line with its 1-based line number") {
        var f = BatchLineFramer()
        let frames = f.feed(bytes("{\"a\":1}\n{\"b\":2}\n"))
        try assertEqual(frames, [.line(number: 1, bytes: bytes("{\"a\":1}")), .line(number: 2, bytes: bytes("{\"b\":2}"))])
        try assertEqual(f.finish(), [])
    }

    test("framer emits a line before EOF (incremental, no read-to-end)") {
        var f = BatchLineFramer()
        try assertEqual(lines(f.feed(bytes("{\"x\":1}\n{\"y\""))), ["{\"x\":1}"])
        try assertEqual(f.bufferedByteCount, 4)
    }

    test("framer joins a line split across chunks") {
        var f = BatchLineFramer()
        try assertEqual(f.feed(bytes("{\"cus")), [])
        try assertEqual(lines(f.feed(bytes("tom_id\":\"a\"}\n"))), ["{\"custom_id\":\"a\"}"])
    }

    test("framer keeps a multi-byte UTF-8 character split across chunks intact") {
        var f = BatchLineFramer()
        let all = bytes("{\"prompt\":\"Grüße 🍎\"}\n")
        // Split inside the 4-byte apple emoji and inside the 2-byte ü.
        let ue = all.firstIndex(of: 0xC3)! + 1
        let apple = all.firstIndex(of: 0xF0)! + 2
        var out: [BatchFrame] = []
        out += f.feed(Array(all[..<ue]))
        out += f.feed(Array(all[ue..<apple]))
        out += f.feed(Array(all[apple...]))
        try assertEqual(lines(out), ["{\"prompt\":\"Grüße 🍎\"}"])
    }

    test("framer emits an unterminated final line at EOF") {
        var f = BatchLineFramer()
        try assertEqual(f.feed(bytes("{\"a\":1}\n{\"b\":2}")).count, 1)
        try assertEqual(f.finish(), [.line(number: 2, bytes: bytes("{\"b\":2}"))])
    }

    test("framer strips a CRLF line ending") {
        var f = BatchLineFramer()
        try assertEqual(lines(f.feed(bytes("{\"a\":1}\r\n"))), ["{\"a\":1}"])
    }

    test("framer strips a UTF-8 BOM on the first line only") {
        var f = BatchLineFramer()
        let frames = f.feed([0xEF, 0xBB, 0xBF] + bytes("{\"a\":1}\n") + [0xEF, 0xBB, 0xBF] + bytes("x\n"))
        try assertEqual(frames.first, .line(number: 1, bytes: bytes("{\"a\":1}")))
        try assertEqual(frames.last, .line(number: 2, bytes: [0xEF, 0xBB, 0xBF] + bytes("x")))
    }

    test("framer counts blank lines so line numbers match the input file") {
        var f = BatchLineFramer()
        let frames = f.feed(bytes("a\n\nb\n"))
        try assertEqual(frames, [.line(number: 1, bytes: bytes("a")), .line(number: 2, bytes: []), .line(number: 3, bytes: bytes("b"))])
    }

    test("framer reports an oversized record and never buffers past the limit") {
        var f = BatchLineFramer(maxRecordBytes: 8)
        var frames: [BatchFrame] = []
        for _ in 0..<1000 {
            frames += f.feed(bytes("0123456789"))
            try assertTrue(f.bufferedByteCount <= 8, "buffered \(f.bufferedByteCount)")
        }
        frames += f.feed(bytes("tail\nok\n"))
        try assertEqual(frames, [.oversized(number: 1), .line(number: 2, bytes: bytes("ok"))])
    }

    test("framer: a record exactly at the limit is accepted") {
        var f = BatchLineFramer(maxRecordBytes: 8)
        try assertEqual(f.feed(bytes("12345678\n")), [.line(number: 1, bytes: bytes("12345678"))])
    }

    test("framer reports an oversized unterminated final record at EOF") {
        var f = BatchLineFramer(maxRecordBytes: 4)
        try assertEqual(f.feed(bytes("ok\n0123456789")), [.line(number: 1, bytes: bytes("ok"))])
        try assertEqual(f.finish(), [.oversized(number: 2)])
    }

    test("framer: bounded limits are sane") {
        try assertEqual(BatchLimits.maxRecordBytes, 1_048_576)
        try assertTrue(BatchLimits.readChunkBytes <= BatchLimits.maxRecordBytes)
    }

    // MARK: - Record parser

    test("parser: prompt record") {
        let r = try record(BatchRecordParser.parse(bytes(#"{"custom_id":"t-1","prompt":"Classify: refund please"}"#), line: 3))
        try assertEqual(r, BatchRecord(line: 3, customID: "t-1", input: .prompt("Classify: refund please")))
    }

    test("parser: escaped newlines inside a prompt survive") {
        let r = try record(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"line one\nline two"}"#), line: 1))
        try assertEqual(r.input, .prompt("line one\nline two"))
    }

    test("parser: messages record keeps a validated conversation") {
        let r = try record(BatchRecordParser.parse(bytes(#"{"custom_id":"m","messages":[{"role":"system","content":"Be brief"},{"role":"user","content":"hi"}]}"#), line: 1))
        guard case .messages(let json) = r.input else { throw TestFailure("expected messages") }
        let decoded = try MessagesInput.decode(json)
        try assertEqual(decoded.count, 2)
        try assertEqual(decoded.last?.textContent, "hi")
    }

    test("parser: a whitespace-only line is blank, not an error") {
        try assertEqual(BatchRecordParser.parse(bytes("   \t"), line: 1), .blank)
        try assertEqual(BatchRecordParser.parse([], line: 1), .blank)
    }

    test("parser: malformed JSON is an invalid record") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"x""#), line: 1))
        try assertNil(e.customID)
        try assertTrue(e.message.contains("not valid JSON"), e.message)
    }

    test("parser: invalid UTF-8 is an invalid record") {
        let e = try invalid(BatchRecordParser.parse([0x7B, 0xFF, 0xFE, 0x7D], line: 1))
        try assertTrue(e.message.contains("UTF-8"), e.message)
    }

    test("parser: a JSON array is not a record object") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"["a"]"#), line: 1))
        try assertTrue(e.message.contains("JSON object"), e.message)
    }

    test("parser: missing custom_id") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"prompt":"x"}"#), line: 1))
        try assertTrue(e.message.contains("custom_id"), e.message)
    }

    test("parser: custom_id must be a string") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":7,"prompt":"x"}"#), line: 1))
        try assertTrue(e.message.contains("custom_id must be a string"), e.message)
    }

    test("parser: empty custom_id is rejected") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"","prompt":"x"}"#), line: 1))
        try assertTrue(e.message.contains("custom_id"), e.message)
    }

    test("parser: missing prompt and messages") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a"}"#), line: 1))
        try assertEqual(e.customID, "a")
        try assertTrue(e.message.contains("exactly one of prompt or messages"), e.message)
    }

    test("parser: prompt and messages together conflict") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"x","messages":[{"role":"user","content":"y"}]}"#), line: 1))
        try assertEqual(e.customID, "a")
        try assertTrue(e.message.contains("exactly one of prompt or messages"), e.message)
    }

    test("parser: prompt must be a non-empty string") {
        let e1 = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":42}"#), line: 1))
        try assertTrue(e1.message.contains("prompt must be a string"), e1.message)
        let e2 = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"  "}"#), line: 1))
        try assertTrue(e2.message.contains("prompt is empty"), e2.message)
    }

    test("parser: invalid messages reuse the --messages rules") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","messages":[{"role":"assistant","content":"hi"}]}"#), line: 1))
        try assertTrue(e.message.contains("last message must have role user or tool"), e.message)
        let e2 = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","messages":"hi"}"#), line: 1))
        try assertTrue(e2.message.contains("messages"), e2.message)
    }

    test("parser: unknown fields are rejected, not silently ignored") {
        let e = try invalid(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"x","system":"pirate"}"#), line: 1))
        try assertEqual(e.customID, "a")
        try assertTrue(e.message.contains("unknown field \"system\""), e.message)
    }

    test("parser: records are independent - parsing has no carried state") {
        let a = try record(BatchRecordParser.parse(bytes(#"{"custom_id":"a","prompt":"secret ZEBRA-7731"}"#), line: 1))
        let b = try record(BatchRecordParser.parse(bytes(#"{"custom_id":"b","prompt":"what was the secret?"}"#), line: 2))
        try assertEqual(b.input, .prompt("what was the secret?"))
        try assertTrue(a != b)
    }

    // MARK: - Result lines

    test("result: ok line is compact single-line JSON in the documented field order") {
        let r = BatchResult.generated(line: 1, customID: "t-1", content: "billing\nok", finishReason: .stop, truncation: nil)
        try assertEqual(r.status, .ok)
        try assertFalse(r.jsonLine.contains("\n"))
        try assertEqual(r.jsonLine, #"{"line":1,"custom_id":"t-1","status":"ok","content":"billing\nok","finish_reason":"stop","partial_content":null,"error":null}"#)
    }

    test("result: unknown finish reason is null, still ok") {
        let r = BatchResult.generated(line: 2, customID: "x", content: "hi", finishReason: nil, truncation: nil)
        try assertEqual(r.status, .ok)
        try assertEqual(try decodeLine(r.jsonLine)["finish_reason"] is NSNull, true)
    }

    test("result: a length finish is incomplete, partial text explicitly identified, counts as failure") {
        let r = BatchResult.generated(line: 4, customID: "x", content: "half an ans", finishReason: .length, truncation: .tokenCap(16))
        try assertEqual(r.status, .incomplete)
        try assertTrue(r.isFailure)
        let obj = try decodeLine(r.jsonLine)
        try assertTrue(obj["content"] is NSNull)
        try assertEqual(obj["partial_content"] as? String, "half an ans")
        try assertEqual(obj["finish_reason"] as? String, "length")
        let err = obj["error"] as? [String: Any]
        try assertEqual(err?["type"] as? String, "incomplete")
        try assertEqual(err?["exit_code"] as? Int, 8)
        try assertTrue((err?["message"] as? String ?? "").contains("--max-tokens 16"))
    }

    test("result: model error carries type, message and the one-shot exit code") {
        let r = BatchResult.failure(line: 5, customID: "g", error: .guardrailViolation)
        try assertEqual(r.status, .error)
        let obj = try decodeLine(r.jsonLine)
        try assertTrue(obj["content"] is NSNull)
        let err = obj["error"] as? [String: Any]
        try assertEqual(err?["type"] as? String, "content_policy_violation")
        try assertEqual(err?["exit_code"] as? Int, 3)
    }

    test("result: invalid record keeps line, echoes custom_id when known") {
        let r = BatchResult.invalidRecord(line: 9, customID: nil, message: "record is not valid JSON")
        let obj = try decodeLine(r.jsonLine)
        try assertEqual(obj["line"] as? Int, 9)
        try assertTrue(obj["custom_id"] is NSNull)
        try assertEqual(obj["status"] as? String, "error")
        let err = obj["error"] as? [String: Any]
        try assertEqual(err?["type"] as? String, "invalid_record")
        try assertEqual(err?["exit_code"] as? Int, 2)
    }

    test("result: oversized record names the byte limit") {
        let r = BatchResult.oversized(line: 3)
        let err = try decodeLine(r.jsonLine)["error"] as? [String: Any]
        try assertTrue((err?["message"] as? String ?? "").contains("\(BatchLimits.maxRecordBytes)"))
    }

    test("result: repeated custom_ids are echoed and disambiguated by line") {
        let a = try decodeLine(BatchResult.generated(line: 1, customID: "dup", content: "a", finishReason: .stop, truncation: nil).jsonLine)
        let b = try decodeLine(BatchResult.generated(line: 2, customID: "dup", content: "b", finishReason: .stop, truncation: nil).jsonLine)
        try assertEqual(a["custom_id"] as? String, b["custom_id"] as? String)
        try assertTrue((a["line"] as? Int) != (b["line"] as? Int))
    }

    test("result: content with quotes, slashes and non-ASCII round-trips") {
        let text = "a \"quoted\" path/to/file \u{1F34E} \u{0007}"
        let r = BatchResult.generated(line: 1, customID: "id/\"x\"", content: text, finishReason: .stop, truncation: nil)
        let obj = try decodeLine(r.jsonLine)
        try assertEqual(obj["content"] as? String, text)
        try assertEqual(obj["custom_id"] as? String, "id/\"x\"")
    }

    // MARK: - Aggregate exit status

    test("tally: all ok exits 0") {
        var t = BatchTally()
        t.add(.generated(line: 1, customID: "a", content: "x", finishReason: .stop, truncation: nil))
        try assertEqual(t.exitCode, ApfelExitCodes.success)
        try assertEqual(t.summary, "batch: 1 record, 1 ok, 0 failed")
    }

    test("tally: any failure exits 1; empty input exits 0") {
        var t = BatchTally()
        try assertEqual(t.exitCode, 0)
        t.add(.generated(line: 1, customID: "a", content: "x", finishReason: .stop, truncation: nil))
        t.add(.invalidRecord(line: 2, customID: nil, message: "bad"))
        t.add(.generated(line: 3, customID: "c", content: "x", finishReason: .length, truncation: nil))
        try assertEqual(t.exitCode, ApfelExitCodes.runtimeError)
        try assertEqual(t.summary, "batch: 3 records, 1 ok, 2 failed")
    }

    // MARK: - Flag rules

    test("--batch is a known flag and a mode") {
        try assertTrue(CLIArguments.knownFlags.contains("--batch"))
        let args = try CLIArguments.parse(["--batch"])
        try assertEqual(args.mode, .batch)
        try assertFalse(args.mode.acceptsStdinInput, "the batch runner owns stdin")
    }

    test("--batch prewarms the model") {
        try assertTrue(PrewarmDecision.shouldPrewarm(mode: .batch))
    }

    test("--batch accepts generation flags, -s and --schema") {
        let args = try CLIArguments.parse(["--batch", "-s", "Be brief", "--temperature", "0", "--max-tokens", "64", "--seed", "1", "--permissive", "--retry", "--schema", "label.json"], readFile: { _ in #"{"type":"object","properties":{"a":{"type":"string"}}}"# })
        try assertEqual(args.mode, .batch)
        try assertEqual(args.systemPrompt, "Be brief")
        try assertEqual(args.schemaName, "label")
        try assertEqual(args.maxTokens, 64)
    }

    test("--batch accepts --stop") {
        let args = try CLIArguments.parse(["--batch", "--stop", "END"])
        try assertEqual(args.stopSequences, ["END"])
    }

    test("--batch rejects a positional prompt") {
        try expectBatchParseError(["--batch", "hello"], contains: "--batch reads records from stdin")
    }

    test("--batch rejects -f") {
        try expectBatchParseError(["--batch", "-f", "a.txt"], contains: "--batch cannot be combined with -f/--file")
    }

    test("--batch rejects --messages") {
        try expectBatchParseError(["--batch", "--messages", "-"], contains: "--messages cannot be combined with --batch")
    }

    test("--batch rejects other modes") {
        try expectBatchParseError(["--batch", "--stream"], contains: "--batch")
        try expectBatchParseError(["--chat", "--batch"], contains: "--batch")
        try expectBatchParseError(["--batch", "--serve"], contains: "--batch")
    }

    test("--batch rejects -o (output is always JSONL)") {
        try expectBatchParseError(["--batch", "-o", "json"], contains: "--batch always writes JSONL")
    }

    test("--batch rejects --code") {
        try expectBatchParseError(["--batch", "--code"], contains: "--code requires a single one-shot prompt")
    }

    test("--batch rejects --require-complete (truncation already fails a record)") {
        try expectBatchParseError(["--batch", "--require-complete"], contains: "--batch already treats a truncated record as a failure")
    }

    test("--batch rejects MCP tools") {
        try expectBatchParseError(["--batch", "--mcp", "server.py"], contains: "--batch cannot be combined with MCP tool calling")
    }

    test("--batch rejects --stop with --schema") {
        try expectBatchParseError(["--batch", "--schema", "s.json", "--stop", "x"], contains: "--stop cannot be combined with --schema")
    }

    test("--batch rejects --context-status and --strict") {
        try expectBatchParseError(["--batch", "--context-status"], contains: "--context-status only applies to --chat")
        try expectBatchParseError(["--batch", "--strict"], contains: "--strict requires --count-tokens")
    }

    test("--batch completion entry exists") {
        try assertTrue(ShellCompletions.allFlagNames.contains("--batch"))
    }

    test("--help documents --batch") {
        try assertTrue(UsageText.render(appName: "apfel", version: "0", style: { $0 }).contains("--batch"))
    }
}
