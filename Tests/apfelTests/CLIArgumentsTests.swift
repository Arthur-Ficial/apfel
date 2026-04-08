// ============================================================================
// CLIArgumentsTests.swift — Unit tests for CLIArguments.parse()
// Focused on edge cases, validation errors, and non-obvious behavior.
// Happy-path flag→field mapping is covered by the combined integration tests.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runCLIArgumentsTests() {

    // -- Baseline & parsing --

    test("no args produces single mode with empty prompt") {
        let args = try CLIArguments.parse([])
        try assertEqual(args.mode, .single)
        try assertEqual(args.prompt, "")
    }

    test("bare words become the prompt") {
        let args = try CLIArguments.parse(["hello", "world"])
        try assertEqual(args.prompt, "hello world")
    }

    test("prompt after flags preserves flag effects") {
        let args = try CLIArguments.parse(["--quiet", "tell", "me", "a", "joke"])
        try assertEqual(args.prompt, "tell me a joke")
        try assertTrue(args.quiet)
    }

    // -- Validation errors (tightened: verify CLIParseError type + message content) --

    test("--system without value throws CLIParseError") {
        do {
            _ = try CLIArguments.parse(["--system"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--system requires"))
        }
    }

    test("--output invalid format throws with format name") {
        do {
            _ = try CLIArguments.parse(["--output", "xml"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("unknown output format"))
            try assertTrue(e.message.contains("xml"))
        }
    }

    test("--port out of range throws") {
        do {
            _ = try CLIArguments.parse(["--port", "99999"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--port"))
        }
    }

    test("--port zero throws") {
        do {
            _ = try CLIArguments.parse(["--port", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--port"))
        }
    }

    test("--max-concurrent zero throws") {
        do {
            _ = try CLIArguments.parse(["--max-concurrent", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--max-concurrent"))
        }
    }

    test("--allowed-origins empty string throws") {
        do {
            _ = try CLIArguments.parse(["--allowed-origins", ""])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--allowed-origins"))
        }
    }

    test("--temperature negative throws") {
        do {
            _ = try CLIArguments.parse(["--temperature", "-1"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--temperature"))
        }
    }

    test("--max-tokens zero throws") {
        do {
            _ = try CLIArguments.parse(["--max-tokens", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--max-tokens"))
        }
    }

    test("--context-strategy invalid value throws") {
        do {
            _ = try CLIArguments.parse(["--context-strategy", "invalid"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--context-strategy"))
        }
    }

    test("unknown flag throws with flag name in message") {
        do {
            _ = try CLIArguments.parse(["--nonexistent"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("unknown option"))
            try assertTrue(e.message.contains("--nonexistent"))
        }
    }

    // -- Non-obvious behavior --

    test("--footgun sets CORS and disables origin check together") {
        let args = try CLIArguments.parse(["--serve", "--footgun"])
        try assertTrue(!args.serverOriginCheckEnabled)
        try assertTrue(args.serverCORS)
    }

    test("--allowed-origins parses comma-separated and deduplicates") {
        let args = try CLIArguments.parse(["--serve", "--allowed-origins", "http://a.com,http://b.com"])
        try assertEqual(args.serverAllowedOrigins.count, 2)
        try assertTrue(args.serverAllowedOrigins.contains("http://a.com"))
        try assertTrue(args.serverAllowedOrigins.contains("http://b.com"))
    }

    test("multiple --mcp flags accumulate") {
        let args = try CLIArguments.parse(["--mcp", "a.py", "--mcp", "b.py", "hi"])
        try assertEqual(args.mcpServerPaths, ["a.py", "b.py"])
    }

    test("--mcp-timeout clamps at 300") {
        let args = try CLIArguments.parse(["--mcp-timeout", "999", "hi"])
        try assertEqual(args.mcpTimeoutSeconds, 300)
    }

    test("--retry with explicit count parses optional argument") {
        let args = try CLIArguments.parse(["--retry", "5", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 5)
    }

    test("--retry followed by flag keeps default count") {
        let args = try CLIArguments.parse(["--retry", "--quiet", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 3)
        try assertTrue(args.quiet)
    }

    // -- Environment variable precedence --

    test("CLI flag overrides env var") {
        let args = try CLIArguments.parse(["--serve", "--port", "8080"], env: ["APFEL_PORT": "9090"])
        try assertEqual(args.serverPort, 8080)
    }

    test("APFEL_MCP env splits on colon separator") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_MCP": "a.py:b.py"])
        try assertEqual(args.mcpServerPaths, ["a.py", "b.py"])
    }

    // -- File reader injection --

    test("--file uses injected readFile") {
        let args = try CLIArguments.parse(
            ["--file", "test.txt", "summarize"],
            readFile: { path in
                try assertEqual(path, "test.txt")
                return "file content here"
            }
        )
        try assertEqual(args.fileContents, ["file content here"])
        try assertEqual(args.prompt, "summarize")
    }

    test("--system-file uses injected readFile and trims whitespace") {
        let args = try CLIArguments.parse(
            ["--system-file", "system.txt", "hi"],
            readFile: { _ in "\n  Be concise  \n" }
        )
        try assertEqual(args.systemPrompt, "Be concise")
    }

    test("file read failure throws CLIParseError") {
        struct FakeError: Error {}
        do {
            _ = try CLIArguments.parse(
                ["--file", "missing.txt", "hi"],
                readFile: { _ in throw FakeError() }
            )
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("missing.txt"))
        }
    }

    // -- Combined integration tests (cover happy-path flag mapping) --

    test("full server config parses all flags") {
        let args = try CLIArguments.parse([
            "--serve", "--port", "8080", "--host", "0.0.0.0",
            "--cors", "--max-concurrent", "10", "--token", "secret",
            "--public-health", "--retry", "5", "--debug",
            "--mcp", "calc.py"
        ])
        try assertEqual(args.mode, .serve)
        try assertEqual(args.serverPort, 8080)
        try assertEqual(args.serverHost, "0.0.0.0")
        try assertTrue(args.serverCORS)
        try assertEqual(args.serverMaxConcurrent, 10)
        try assertEqual(args.serverToken, "secret")
        try assertTrue(args.serverPublicHealth)
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 5)
        try assertTrue(args.debug)
        try assertEqual(args.mcpServerPaths, ["calc.py"])
    }

    test("full CLI config parses all flags") {
        let args = try CLIArguments.parse([
            "--system", "Be brief", "--temperature", "0.8",
            "--seed", "42", "--max-tokens", "100",
            "--permissive", "--retry", "--quiet", "--no-color",
            "--output", "json",
            "what is Swift?"
        ])
        try assertEqual(args.mode, .single)
        try assertEqual(args.systemPrompt, "Be brief")
        try assertEqual(args.temperature, 0.8)
        try assertEqual(args.seed, 42)
        try assertEqual(args.maxTokens, 100)
        try assertTrue(args.permissive)
        try assertTrue(args.retryEnabled)
        try assertTrue(args.quiet)
        try assertTrue(args.noColor)
        try assertEqual(args.outputFormat, "json")
        try assertEqual(args.prompt, "what is Swift?")
    }
}
