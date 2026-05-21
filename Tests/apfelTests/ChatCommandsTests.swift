// ============================================================================
// ChatCommandsTests.swift - Unit tests for ChatCommand recognition in --chat mode.
// Tests the pure ChatCommand.parse() function that classifies slash commands.
// ============================================================================

import Foundation
import ApfelCLI

func runChatCommandsTests() {

    // ========================================================================
    // MARK: - /clear
    // ========================================================================

    test("/clear is recognised") {
        try assertEqual(ChatCommand.parse("/clear"), .clear)
    }

    test("/clear with trailing whitespace is recognised") {
        try assertEqual(ChatCommand.parse("/clear   "), .clear)
    }

    test("/clear with leading whitespace is recognised") {
        try assertEqual(ChatCommand.parse("  /clear"), .clear)
    }

    test("/clear is case-insensitive") {
        try assertEqual(ChatCommand.parse("/CLEAR"), .clear)
        try assertEqual(ChatCommand.parse("/Clear"), .clear)
    }

    test("/clear with args returns nil (no false positives)") {
        try assertNil(ChatCommand.parse("/clear all"))
        try assertNil(ChatCommand.parse("/clear screen"))
    }

    // ========================================================================
    // MARK: - /new
    // ========================================================================

    test("/new is recognised") {
        try assertEqual(ChatCommand.parse("/new"), .new)
    }

    test("/new with trailing whitespace is recognised") {
        try assertEqual(ChatCommand.parse("/new   "), .new)
    }

    test("/new with leading whitespace is recognised") {
        try assertEqual(ChatCommand.parse("  /new"), .new)
    }

    test("/new is case-insensitive") {
        try assertEqual(ChatCommand.parse("/NEW"), .new)
        try assertEqual(ChatCommand.parse("/New"), .new)
    }

    test("/new with args returns nil (no false positives)") {
        try assertNil(ChatCommand.parse("/new topic here"))
        try assertNil(ChatCommand.parse("/new conversation"))
    }

    // ========================================================================
    // MARK: - /context
    // ========================================================================

    test("/context is recognised") {
        try assertEqual(ChatCommand.parse("/context"), .context)
    }

    test("/context with trailing whitespace is recognised") {
        try assertEqual(ChatCommand.parse("/context   "), .context)
    }

    test("/context with leading whitespace is recognised") {
        try assertEqual(ChatCommand.parse("  /context"), .context)
    }

    test("/context is case-insensitive") {
        try assertEqual(ChatCommand.parse("/CONTEXT"), .context)
        try assertEqual(ChatCommand.parse("/Context"), .context)
    }

    test("/context with args returns nil (no false positives)") {
        try assertNil(ChatCommand.parse("/context now"))
        try assertNil(ChatCommand.parse("/context status"))
    }

    // ========================================================================
    // MARK: - Developer tool slash commands
    // ========================================================================

    test("/cmd with no args returns tool with empty args") {
        try assertEqual(ChatCommand.parse("/cmd"), .tool(name: "cmd", args: []))
    }

    test("/cmd with args returns tool with joined query string") {
        try assertEqual(
            ChatCommand.parse("/cmd list open ports"),
            .tool(name: "cmd", args: ["list open ports"])
        )
    }

    test("/oneliner with args returns tool") {
        try assertEqual(
            ChatCommand.parse("/oneliner count unique lines"),
            .tool(name: "oneliner", args: ["count unique lines"])
        )
    }

    test("/naming with args returns tool") {
        try assertEqual(
            ChatCommand.parse("/naming function that retries"),
            .tool(name: "naming", args: ["function that retries"])
        )
    }

    test("/explain with args returns joined query string") {
        // Non-flag tokens (including hyphens embedded in words) are joined into
        // a single query string — they are NOT treated as bash flags.
        try assertEqual(
            ChatCommand.parse("/explain awk -F: '{print $1}'"),
            .tool(name: "explain", args: ["awk -F: '{print $1}'"])
        )
    }

    test("/explain with quoted hyphenated command does not misroute -l as a flag (regression)") {
        // Reported bug: /explain "$ ls | wc -l" → "Unknown option: -l"
        // The -l" token (with trailing quote) must never reach the bash script as a flag.
        try assertEqual(
            ChatCommand.parse("/explain \"$ ls | wc -l\""),
            .tool(name: "explain", args: ["$ ls | wc -l"])
        )
    }

    test("/cmd strips double quotes used only for grouping") {
        try assertEqual(
            ChatCommand.parse("/cmd \"find large files\""),
            .tool(name: "cmd", args: ["find large files"])
        )
    }

    test("/docs-apple strips quoted query after leading flags") {
        try assertEqual(
            ChatCommand.parse("/docs-apple --1000 --no-sosumi \"explain NetworkExtension in a few sentences, no code samples\""),
            .tool(name: "docs-apple", args: ["--1000", "--no-sosumi", "explain NetworkExtension in a few sentences, no code samples"])
        )
    }

    test("/port strips quoted port number") {
        try assertEqual(
            ChatCommand.parse("/port \"3000\""),
            .tool(name: "port", args: ["3000"])
        )
    }

    test("/explain preserves single quotes inside shell snippets") {
        try assertEqual(
            ChatCommand.parse("/explain awk -F: '{print $1}' /etc/passwd"),
            .tool(name: "explain", args: ["awk -F: '{print $1}' /etc/passwd"])
        )
    }

    test("/wtd with no args returns tool with empty args") {
        try assertEqual(ChatCommand.parse("/wtd"), .tool(name: "wtd", args: []))
    }

    test("/wtd with directory path returns tool with path arg") {
        try assertEqual(
            ChatCommand.parse("/wtd ~/projects/my-app"),
            .tool(name: "wtd", args: ["~/projects/my-app"])
        )
    }

    test("/port with port number returns tool") {
        try assertEqual(ChatCommand.parse("/port 3000"), .tool(name: "port", args: ["3000"]))
        try assertEqual(ChatCommand.parse("/port 8080"), .tool(name: "port", args: ["8080"]))
    }

    test("/process with pid returns tool") {
        try assertEqual(ChatCommand.parse("/process 1234"), .tool(name: "process", args: ["1234"]))
    }

    test("/daemon with daemon name returns tool") {
        try assertEqual(
            ChatCommand.parse("/daemon mDNSResponder"),
            .tool(name: "daemon", args: ["mDNSResponder"])
        )
    }

    test("/docs-apple with args returns tool") {
        try assertEqual(
            ChatCommand.parse("/docs-apple SwiftUI Button"),
            .tool(name: "docs-apple", args: ["SwiftUI Button"])
        )
    }

    test("/docs_apple normalises to docs-apple") {
        try assertEqual(
            ChatCommand.parse("/docs_apple Task"),
            .tool(name: "docs-apple", args: ["Task"])
        )
    }

    test("/mdn with query returns tool") {
        try assertEqual(
            ChatCommand.parse("/mdn CSS flexbox"),
            .tool(name: "mdn", args: ["CSS flexbox"])
        )
    }

    test("/mdn with @keyword extracts explicit tag") {
        try assertEqual(
            ChatCommand.parse("/mdn @flexbox"),
            .tool(name: "mdn", args: ["@flexbox"])
        )
    }

    test("all toolNames are individually recognised") {
        for name in ChatCommand.toolNames {
            let result = ChatCommand.parse("/\(name)")
            try assertEqual(result, .tool(name: name, args: []))
        }
    }

    test("toolNames has exactly 10 entries") {
        try assertEqual(ChatCommand.toolNames.count, 10)
    }

    test("toolNames contains expected canonical names") {
        try assertTrue(ChatCommand.toolNames.contains("cmd"))
        try assertTrue(ChatCommand.toolNames.contains("explain"))
        try assertTrue(ChatCommand.toolNames.contains("docs-apple"))
        try assertTrue(ChatCommand.toolNames.contains("wtd"))
        try assertTrue(ChatCommand.toolNames.contains("port"))
    }

    test("tool keyword matching is case-insensitive") {
        try assertEqual(ChatCommand.parse("/CMD"), .tool(name: "cmd", args: []))
        try assertEqual(ChatCommand.parse("/Explain"), .tool(name: "explain", args: []))
        try assertEqual(ChatCommand.parse("/PORT 3000"), .tool(name: "port", args: ["3000"]))
    }

    test("/cmd with leading explicit flag keeps flag separate from query") {
        // A token starting with - BEFORE the first non-flag word stays as a separate flag arg.
        // This preserves e.g. /cmd -x show disk usage → ["-x", "show disk usage"]
        try assertEqual(
            ChatCommand.parse("/cmd -x show disk usage"),
            .tool(name: "cmd", args: ["-x", "show disk usage"])
        )
    }

    // ========================================================================
    // MARK: - Non-commands pass through as nil
    // ========================================================================

    test("regular input without slash returns nil") {
        try assertNil(ChatCommand.parse("hello world"))
    }

    test("empty string returns nil") {
        try assertNil(ChatCommand.parse(""))
    }

    test("quit is not a slash command (handled separately)") {
        try assertNil(ChatCommand.parse("quit"))
    }

    test("exit is not a slash command (handled separately)") {
        try assertNil(ChatCommand.parse("exit"))
    }

    test("/unknown returns nil") {
        try assertNil(ChatCommand.parse("/unknown"))
    }

    test("/clearthat does not match /clear") {
        try assertNil(ChatCommand.parse("/clearthat"))
    }

    test("/newer does not match /new") {
        try assertNil(ChatCommand.parse("/newer"))
    }

    test("bare tool name without slash returns nil") {
        // In chat, bare words go to the LLM — only /toolname routes to the tool
        try assertNil(ChatCommand.parse("port"))
        try assertNil(ChatCommand.parse("cmd"))
        try assertNil(ChatCommand.parse("explain"))
        try assertNil(ChatCommand.parse("wtd"))
    }

    test("natural language starting with tool name returns nil (goes to LLM)") {
        // "explain how recursion works" must NOT trigger the explain tool
        try assertNil(ChatCommand.parse("explain how recursion works"))
        // "port is an important concept" must NOT trigger the port tool
        try assertNil(ChatCommand.parse("port is an important concept"))
    }

    test("slash with only whitespace returns nil") {
        try assertNil(ChatCommand.parse("/"))
        try assertNil(ChatCommand.parse("/   "))
    }
}
