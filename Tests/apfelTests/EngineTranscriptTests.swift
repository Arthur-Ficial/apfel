// Tests for EngineTranscript — versioned, Codable conversation persistence.
// Round-trips always compare the RE-READ value against the original.

import Foundation
import ApfelCore

func runEngineTranscriptTests() {
    test("empty transcript round-trips") {
        let original = EngineTranscript(entries: [])
        let reread = try EngineTranscript.decode(from: original.encode())
        try assertEqual(reread, original)
    }

    test("text-only transcript round-trips") {
        let original = EngineTranscript(entries: [
            .instructions("You are terse."),
            .prompt("What is 2+2?"),
            .response("4"),
        ])
        let reread = try EngineTranscript.decode(from: original.encode())
        try assertEqual(reread, original)
    }

    test("tool call and output round-trip") {
        let original = EngineTranscript(entries: [
            .prompt("multiply 6 by 7"),
            .toolCall(toolName: "multiply", argumentsJSON: "{\"a\":6,\"b\":7}"),
            .toolOutput(toolName: "multiply", content: "42"),
            .response("The answer is 42."),
        ])
        let reread = try EngineTranscript.decode(from: original.encode())
        try assertEqual(reread, original)
    }

    test("unicode and newline content round-trips") {
        let original = EngineTranscript(entries: [
            .instructions("Rispondi in italiano.\nSempre."),
            .prompt("ciao 👋 — καλημέρα\n\t改行 \"quoted\" \\backslash"),
            .response("línea 1\nlínea 2 🌍"),
        ])
        let reread = try EngineTranscript.decode(from: original.encode())
        try assertEqual(reread, original)
    }

    test("current version is stamped into the encoded JSON") {
        let data = try EngineTranscript(entries: [.prompt("hi")]).encode()
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        try assertEqual(obj?["version"] as? Int, EngineTranscript.currentVersion)
    }

    test("future version fails with a clear error, not a crash") {
        let future = EngineTranscript.currentVersion + 1
        let data = Data("{\"version\":\(future),\"entries\":[]}".utf8)
        do {
            _ = try EngineTranscript.decode(from: data)
            throw TestFailure("expected unsupportedVersion")
        } catch let e as EngineTranscriptError {
            try assertEqual(e, .unsupportedVersion(found: future, supported: EngineTranscript.currentVersion))
            try assertTrue(e.description.contains("\(future)"), "error names the found version")
        }
    }

    test("version below 1 is rejected") {
        let data = Data("{\"version\":0,\"entries\":[]}".utf8)
        do {
            _ = try EngineTranscript.decode(from: data)
            throw TestFailure("expected unsupportedVersion")
        } catch let e as EngineTranscriptError {
            try assertEqual(e, .unsupportedVersion(found: 0, supported: EngineTranscript.currentVersion))
        }
    }

    test("unknown entry kind fails with a clear error") {
        let data = Data("{\"version\":1,\"entries\":[{\"kind\":\"hologram\",\"content\":\"x\"}]}".utf8)
        do {
            _ = try EngineTranscript.decode(from: data)
            throw TestFailure("expected unrecognizedEntryKind")
        } catch let e as EngineTranscriptError {
            try assertEqual(e, .unrecognizedEntryKind("hologram"))
        }
    }

    test("garbage data throws, never crashes") {
        do {
            _ = try EngineTranscript.decode(from: Data("not json".utf8))
            throw TestFailure("expected a decoding error")
        } catch is TestFailure {
            throw TestFailure("expected a decoding error")
        } catch {
            // any thrown error is the contract; crashing is the bug
        }
    }

    test("missing version field throws") {
        do {
            _ = try EngineTranscript.decode(from: Data("{\"entries\":[]}".utf8))
            throw TestFailure("expected a decoding error")
        } catch is TestFailure {
            throw TestFailure("expected a decoding error")
        } catch {
            // DecodingError.keyNotFound is fine — just not a crash
        }
    }
}
