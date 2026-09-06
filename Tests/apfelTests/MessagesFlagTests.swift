// ============================================================================
// MessagesFlagTests.swift - Unit tests for --messages (#363)
// Pure MessagesInput decoding rules (mirrors server validation) plus
// CLIArguments parse behavior and every cross-flag rule.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

private let twoTurn = """
[{"role":"user","content":"What is the capital of Austria?"},
 {"role":"assistant","content":"Vienna."},
 {"role":"user","content":"And its population?"}]
"""

private let wrapped = """
{"messages":[{"role":"system","content":"Be terse."},{"role":"user","content":"hi"}]}
"""

func runMessagesFlagTests() {

    // ========================================================================
    // MARK: - MessagesInput decoding (pure, ApfelCore)
    // ========================================================================

    test("decodes a bare JSON array of messages") {
        let msgs = try MessagesInput.decode(twoTurn)
        try assertEqual(msgs.count, 3)
        try assertEqual(msgs[0].role, "user")
        try assertEqual(msgs[2].textContent, "And its population?")
    }

    test("decodes an object with a messages key") {
        let msgs = try MessagesInput.decode(wrapped)
        try assertEqual(msgs.count, 2)
        try assertEqual(msgs[0].role, "system")
    }

    test("invalid JSON throws invalidJSON") {
        do {
            _ = try MessagesInput.decode("{nope")
            try assertTrue(false, "should have thrown")
        } catch let e as MessagesInput.Error {
            try assertEqual(e, .invalidJSON)
        }
    }

    test("empty array throws emptyMessages") {
        do {
            _ = try MessagesInput.decode("[]")
            try assertTrue(false, "should have thrown")
        } catch let e as MessagesInput.Error {
            try assertEqual(e, .emptyMessages)
        }
    }

    test("unknown role throws unknownRole") {
        do {
            _ = try MessagesInput.decode("[{\"role\":\"wizard\",\"content\":\"x\"}]")
            try assertTrue(false, "should have thrown")
        } catch let e as MessagesInput.Error {
            try assertEqual(e, .unknownRole("wizard"))
        }
    }

    test("trailing assistant message throws invalidLastRole (server parity)") {
        do {
            _ = try MessagesInput.decode("[{\"role\":\"user\",\"content\":\"x\"},{\"role\":\"assistant\",\"content\":\"y\"}]")
            try assertTrue(false, "should have thrown")
        } catch let e as MessagesInput.Error {
            try assertEqual(e, .invalidLastRole("assistant"))
        }
    }

    test("empty last user content throws emptyLastMessage (server parity)") {
        do {
            _ = try MessagesInput.decode("[{\"role\":\"user\",\"content\":\"\"}]")
            try assertTrue(false, "should have thrown")
        } catch let e as MessagesInput.Error {
            try assertEqual(e, .emptyLastMessage)
        }
    }

    test("trailing tool message is accepted (server parity)") {
        let msgs = try MessagesInput.decode("""
        [{"role":"user","content":"add 1+1"},
         {"role":"assistant","content":null,"tool_calls":[{"id":"c1","type":"function","function":{"name":"add","arguments":"{}"}}]},
         {"role":"tool","content":"2","tool_call_id":"c1"}]
        """)
        try assertEqual(msgs.count, 3)
        try assertEqual(msgs[2].role, "tool")
    }

    // ========================================================================
    // MARK: - CLIArguments parse behavior
    // ========================================================================

    test("--messages reads the file and stores raw JSON") {
        let args = try CLIArguments.parse(["--messages", "conv.json"], readFile: { path in
            guard path == "conv.json" else { throw CLIParseError("unexpected path") }
            return twoTurn
        })
        try assertEqual(args.mode, .single)
        try assertEqual(args.messagesJSON, twoTurn)
        try assertTrue(!args.messagesFromStdin)
    }

    test("--messages - defers to stdin (no file read)") {
        let args = try CLIArguments.parse(["--messages", "-"], readFile: { _ in
            throw CLIParseError("must not read a file for -")
        })
        try assertTrue(args.messagesFromStdin)
        try assertEqual(args.messagesJSON, nil)
    }

    test("--messages without a value throws") {
        do {
            _ = try CLIArguments.parse(["--messages"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
        }
    }

    test("--messages with unreadable file throws with the path in the message") {
        do {
            _ = try CLIArguments.parse(["--messages", "missing.json"], readFile: { _ in
                throw NSError(domain: "test", code: 1)
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("missing.json"))
        }
    }

    test("--messages with malformed JSON throws at parse time") {
        do {
            _ = try CLIArguments.parse(["--messages", "bad.json"], readFile: { _ in "{nope" })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
        }
    }

    test("--messages with a trailing assistant message throws at parse time") {
        do {
            _ = try CLIArguments.parse(["--messages", "c.json"], readFile: { _ in
                "[{\"role\":\"user\",\"content\":\"x\"},{\"role\":\"assistant\",\"content\":\"y\"}]"
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("assistant"))
        }
    }

    // ========================================================================
    // MARK: - Cross-flag rules
    // ========================================================================

    test("--messages with a positional prompt throws") {
        do {
            _ = try CLIArguments.parse(["--messages", "c.json", "extra prompt"], readFile: { _ in twoTurn })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
            try assertTrue(e.message.contains("prompt"))
        }
    }

    test("--messages with -f throws") {
        do {
            _ = try CLIArguments.parse(["--messages", "c.json", "-f", "a.txt"],
                                       readFile: { _ in twoTurn },
                                       extractFile: { _ in "file body" })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
            try assertTrue(e.message.contains("--file"))
        }
    }

    test("--messages with --chat throws") {
        do {
            _ = try CLIArguments.parse(["--messages", "c.json", "--chat"], readFile: { _ in twoTurn })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
            try assertTrue(e.message.contains("--chat"))
        }
    }

    test("--messages with --count-tokens throws") {
        do {
            _ = try CLIArguments.parse(["--messages", "c.json", "--count-tokens"], readFile: { _ in twoTurn })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--messages"))
            try assertTrue(e.message.contains("--count-tokens"))
        }
    }

    test("--messages composes with --stream") {
        let args = try CLIArguments.parse(["--messages", "c.json", "--stream"], readFile: { _ in twoTurn })
        try assertEqual(args.mode, .stream)
        try assertEqual(args.messagesJSON, twoTurn)
    }

    test("--messages composes with --schema") {
        let args = try CLIArguments.parse(
            ["--messages", "c.json", "--schema", "s.json"],
            readFile: { path in
                path == "s.json"
                    ? "{\"type\":\"object\",\"properties\":{\"answer\":{\"type\":\"string\"}}}"
                    : twoTurn
            })
        try assertEqual(args.messagesJSON, twoTurn)
        try assertTrue(args.schemaJSON != nil)
    }

    test("knownFlags contains --messages") {
        try assertTrue(CLIArguments.knownFlags.contains("--messages"))
    }

    // ========================================================================
    // MARK: - Repeated --messages: last-flag-wins (#416)
    // ========================================================================

    test("--messages - then --messages file uses the file") {
        let args = try CLIArguments.parse(
            ["--messages", "-", "--messages", "conv.json"],
            readFile: { path in
                guard path == "conv.json" else { throw CLIParseError("unexpected path") }
                return twoTurn
            })
        try assertEqual(args.messagesJSON, twoTurn)
        try assertTrue(!args.messagesFromStdin)
    }

    test("--messages file then --messages - uses stdin") {
        let args = try CLIArguments.parse(
            ["--messages", "conv.json", "--messages", "-"],
            readFile: { path in
                guard path == "conv.json" else { throw CLIParseError("unexpected path") }
                return twoTurn
            })
        try assertTrue(args.messagesFromStdin)
        try assertEqual(args.messagesJSON, nil)
    }

    test("--messages file1 then --messages file2 uses file2") {
        let file1 = "[{\"role\":\"user\",\"content\":\"first\"}]"
        let args = try CLIArguments.parse(
            ["--messages", "a.json", "--messages", "b.json"],
            readFile: { path in
                if path == "a.json" { return file1 }
                if path == "b.json" { return twoTurn }
                throw CLIParseError("unexpected path")
            })
        try assertEqual(args.messagesJSON, twoTurn)
        try assertTrue(!args.messagesFromStdin)
    }
}
