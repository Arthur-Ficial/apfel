// ============================================================================
// CLIArgumentsTests.swift - Exhaustive unit tests for CLIArguments.parse()
// Every flag, every validation error, every env default, mode conflicts, and
// typed OutputFormat checks. Error tests verify CLIParseError type + message.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

func runCLIArgumentsTests() {

    // ========================================================================
    // MARK: - Mode flags (happy path)
    // ========================================================================

    test("no args produces single mode with empty prompt") {
        let args = try CLIArguments.parse([])
        try assertEqual(args.mode, .single)
        try assertEqual(args.prompt, "")
    }

    test("--help sets help mode") {
        let args = try CLIArguments.parse(["--help"])
        try assertEqual(args.mode, .help)
    }

    test("-h sets help mode") {
        let args = try CLIArguments.parse(["-h"])
        try assertEqual(args.mode, .help)
    }

    test("--version sets version mode") {
        let args = try CLIArguments.parse(["--version"])
        try assertEqual(args.mode, .version)
    }

    test("-v sets version mode") {
        let args = try CLIArguments.parse(["-v"])
        try assertEqual(args.mode, .version)
    }

    test("--release sets release mode") {
        let args = try CLIArguments.parse(["--release"])
        try assertEqual(args.mode, .release)
    }

    test("--chat sets chat mode") {
        let args = try CLIArguments.parse(["--chat"])
        try assertEqual(args.mode, .chat)
    }

    test("--stream sets stream mode") {
        let args = try CLIArguments.parse(["--stream", "hi"])
        try assertEqual(args.mode, .stream)
    }

    test("--serve sets serve mode") {
        let args = try CLIArguments.parse(["--serve"])
        try assertEqual(args.mode, .serve)
    }

    test("--benchmark sets benchmark mode") {
        let args = try CLIArguments.parse(["--benchmark"])
        try assertEqual(args.mode, .benchmark)
    }

    test("--model-info sets modelInfo mode") {
        let args = try CLIArguments.parse(["--model-info"])
        try assertEqual(args.mode, .modelInfo)
    }

    test("--update sets update mode") {
        let args = try CLIArguments.parse(["--update"])
        try assertEqual(args.mode, .update)
    }

    // ========================================================================
    // MARK: - Prompt parsing
    // ========================================================================

    test("bare words become the prompt") {
        let args = try CLIArguments.parse(["hello", "world"])
        try assertEqual(args.prompt, "hello world")
    }

    test("prompt after flags preserves flag effects") {
        let args = try CLIArguments.parse(["--quiet", "tell", "me", "a", "joke"])
        try assertEqual(args.prompt, "tell me a joke")
        try assertTrue(args.quiet)
    }

    test("single-word prompt parses") {
        let args = try CLIArguments.parse(["hello"])
        try assertEqual(args.prompt, "hello")
    }

    // ========================================================================
    // MARK: - System prompt
    // ========================================================================

    test("--system sets systemPrompt") {
        let args = try CLIArguments.parse(["--system", "You are helpful", "hi"])
        try assertEqual(args.systemPrompt, "You are helpful")
    }

    test("-s sets systemPrompt") {
        let args = try CLIArguments.parse(["-s", "Be brief", "hi"])
        try assertEqual(args.systemPrompt, "Be brief")
    }

    test("--system without value throws CLIParseError") {
        do {
            _ = try CLIArguments.parse(["--system"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--system"))
            try assertTrue(e.message.contains("requires"))
        }
    }

    test("APFEL_SYSTEM_PROMPT env sets systemPrompt") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_SYSTEM_PROMPT": "Be brief"])
        try assertEqual(args.systemPrompt, "Be brief")
    }

    // ========================================================================
    // MARK: - Output flags
    // ========================================================================

    test("-o plain sets outputFormat to .plain") {
        let args = try CLIArguments.parse(["-o", "plain", "hi"])
        try assertEqual(args.outputFormat, .plain)
    }

    test("--output json sets outputFormat to .json") {
        let args = try CLIArguments.parse(["--output", "json", "hi"])
        try assertEqual(args.outputFormat, .json)
    }

    test("outputFormat is nil when not specified") {
        let args = try CLIArguments.parse(["hi"])
        try assertNil(args.outputFormat)
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

    test("--output without value throws CLIParseError") {
        do {
            _ = try CLIArguments.parse(["--output"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--output"))
        }
    }

    test("--quiet sets quiet") {
        let args = try CLIArguments.parse(["-q", "hi"])
        try assertTrue(args.quiet)
    }

    test("--no-color sets noColor") {
        let args = try CLIArguments.parse(["--no-color", "hi"])
        try assertTrue(args.noColor)
    }

    // ========================================================================
    // MARK: - Server flags
    // ========================================================================

    test("--port parses valid port") {
        let args = try CLIArguments.parse(["--serve", "--port", "8080"])
        try assertEqual(args.serverPort, 8080)
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

    test("--port non-numeric throws") {
        do {
            _ = try CLIArguments.parse(["--port", "eighty"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--port"))
        }
    }

    test("--host sets serverHost") {
        let args = try CLIArguments.parse(["--serve", "--host", "0.0.0.0"])
        try assertEqual(args.serverHost, "0.0.0.0")
    }

    test("--host without value throws CLIParseError") {
        do {
            _ = try CLIArguments.parse(["--host"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--host"))
        }
    }

    test("--cors sets serverCORS") {
        let args = try CLIArguments.parse(["--serve", "--cors"])
        try assertTrue(args.serverCORS)
    }

    test("--max-concurrent parses positive") {
        let args = try CLIArguments.parse(["--serve", "--max-concurrent", "10"])
        try assertEqual(args.serverMaxConcurrent, 10)
    }

    test("--max-concurrent zero throws") {
        do {
            _ = try CLIArguments.parse(["--max-concurrent", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--max-concurrent"))
        }
    }

    test("--debug sets debug") {
        let args = try CLIArguments.parse(["--debug", "hi"])
        try assertTrue(args.debug)
    }

    test("--token sets serverToken") {
        let args = try CLIArguments.parse(["--serve", "--token", "secret123"])
        try assertEqual(args.serverToken, "secret123")
    }

    test("--token-auto sets serverTokenAuto") {
        let args = try CLIArguments.parse(["--serve", "--token-auto"])
        try assertTrue(args.serverTokenAuto)
    }

    test("--public-health sets serverPublicHealth") {
        let args = try CLIArguments.parse(["--serve", "--public-health"])
        try assertTrue(args.serverPublicHealth)
    }

    test("--no-origin-check disables origin check") {
        let args = try CLIArguments.parse(["--serve", "--no-origin-check"])
        try assertTrue(!args.serverOriginCheckEnabled)
    }

    test("--footgun disables origin check AND enables CORS") {
        let args = try CLIArguments.parse(["--serve", "--footgun"])
        try assertTrue(!args.serverOriginCheckEnabled)
        try assertTrue(args.serverCORS)
    }

    test("--allowed-origins parses comma-separated list") {
        let args = try CLIArguments.parse(["--serve", "--allowed-origins", "http://a.com,http://b.com"])
        try assertEqual(args.serverAllowedOrigins.count, 2)
        try assertTrue(args.serverAllowedOrigins.contains("http://a.com"))
        try assertTrue(args.serverAllowedOrigins.contains("http://b.com"))
    }

    test("--allowed-origins deduplicates repeated values") {
        let args = try CLIArguments.parse(["--serve", "--allowed-origins", "http://a.com,http://a.com,http://b.com"])
        try assertEqual(args.serverAllowedOrigins.count, 2)
    }

    test("--allowed-origins empty string throws") {
        do {
            _ = try CLIArguments.parse(["--allowed-origins", ""])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--allowed-origins"))
        }
    }

    // ========================================================================
    // MARK: - MCP flags
    // ========================================================================

    test("--mcp adds server path") {
        let args = try CLIArguments.parse(["--mcp", "/path/to/server.py", "hi"])
        try assertEqual(args.mcpServerPaths, ["/path/to/server.py"])
    }

    test("multiple --mcp flags accumulate") {
        let args = try CLIArguments.parse(["--mcp", "a.py", "--mcp", "b.py", "hi"])
        try assertEqual(args.mcpServerPaths, ["a.py", "b.py"])
    }

    test("--mcp-timeout parses") {
        let args = try CLIArguments.parse(["--mcp-timeout", "10", "hi"])
        try assertEqual(args.mcpTimeoutSeconds, 10)
    }

    test("--mcp-timeout clamps at 300") {
        let args = try CLIArguments.parse(["--mcp-timeout", "999", "hi"])
        try assertEqual(args.mcpTimeoutSeconds, 300)
    }

    test("--mcp-timeout zero throws") {
        do {
            _ = try CLIArguments.parse(["--mcp-timeout", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--mcp-timeout"))
        }
    }

    // ========================================================================
    // MARK: - Generation flags
    // ========================================================================

    test("--temperature parses") {
        let args = try CLIArguments.parse(["--temperature", "0.7", "hi"])
        try assertEqual(args.temperature, 0.7)
    }

    test("--temperature zero is valid") {
        let args = try CLIArguments.parse(["--temperature", "0", "hi"])
        try assertEqual(args.temperature, 0.0)
    }

    test("--temperature negative throws") {
        do {
            _ = try CLIArguments.parse(["--temperature", "-1"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--temperature"))
        }
    }

    test("--temperature non-numeric throws") {
        do {
            _ = try CLIArguments.parse(["--temperature", "hot"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--temperature"))
        }
    }

    test("--seed parses") {
        let args = try CLIArguments.parse(["--seed", "42", "hi"])
        try assertEqual(args.seed, 42)
    }

    test("--max-tokens parses") {
        let args = try CLIArguments.parse(["--max-tokens", "100", "hi"])
        try assertEqual(args.maxTokens, 100)
    }

    test("--max-tokens zero throws") {
        do {
            _ = try CLIArguments.parse(["--max-tokens", "0"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--max-tokens"))
        }
    }

    test("--permissive sets permissive") {
        let args = try CLIArguments.parse(["--permissive", "hi"])
        try assertTrue(args.permissive)
    }

    // ========================================================================
    // MARK: - Retry flags
    // ========================================================================

    test("--retry with no number uses default 3") {
        let args = try CLIArguments.parse(["--retry", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 3)
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

    test("--retry 0 rejected (falls back to default 3)") {
        let args = try CLIArguments.parse(["--retry", "0", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 3)
        try assertEqual(args.prompt, "0 hi")
    }

    // ========================================================================
    // MARK: - Context flags
    // ========================================================================

    test("--context-strategy newest-first") {
        let args = try CLIArguments.parse(["--context-strategy", "newest-first", "--chat"])
        try assertEqual(args.contextStrategy, .newestFirst)
    }

    test("--context-strategy sliding-window") {
        let args = try CLIArguments.parse(["--context-strategy", "sliding-window", "--chat"])
        try assertEqual(args.contextStrategy, .slidingWindow)
    }

    test("--context-strategy strict") {
        let args = try CLIArguments.parse(["--context-strategy", "strict", "--chat"])
        try assertEqual(args.contextStrategy, .strict)
    }

    test("--context-strategy invalid throws") {
        do {
            _ = try CLIArguments.parse(["--context-strategy", "invalid"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--context-strategy"))
        }
    }

    test("--context-max-turns parses") {
        let args = try CLIArguments.parse(["--context-max-turns", "10", "--chat"])
        try assertEqual(args.contextMaxTurns, 10)
    }

    test("--context-output-reserve parses") {
        let args = try CLIArguments.parse(["--context-output-reserve", "256", "--chat"])
        try assertEqual(args.contextOutputReserve, 256)
    }

    // ========================================================================
    // MARK: - Unknown flags
    // ========================================================================

    test("unknown flag throws with flag name in message") {
        do {
            _ = try CLIArguments.parse(["--nonexistent"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("unknown option"))
            try assertTrue(e.message.contains("--nonexistent"))
        }
    }

    // ========================================================================
    // MARK: - Environment variable defaults
    // ========================================================================

    test("APFEL_PORT env sets default port") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_PORT": "9090"])
        try assertEqual(args.serverPort, 9090)
    }

    test("CLI --port overrides env APFEL_PORT") {
        let args = try CLIArguments.parse(["--serve", "--port", "8080"], env: ["APFEL_PORT": "9090"])
        try assertEqual(args.serverPort, 8080)
    }

    test("APFEL_HOST env sets serverHost") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_HOST": "0.0.0.0"])
        try assertEqual(args.serverHost, "0.0.0.0")
    }

    test("APFEL_TOKEN env sets serverToken") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_TOKEN": "mytoken"])
        try assertEqual(args.serverToken, "mytoken")
    }

    test("APFEL_TEMPERATURE env sets temperature") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_TEMPERATURE": "0.5"])
        try assertEqual(args.temperature, 0.5)
    }

    test("APFEL_MAX_TOKENS env sets maxTokens") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_MAX_TOKENS": "200"])
        try assertEqual(args.maxTokens, 200)
    }

    test("APFEL_CONTEXT_STRATEGY env sets contextStrategy") {
        let args = try CLIArguments.parse(["--chat"], env: ["APFEL_CONTEXT_STRATEGY": "strict"])
        try assertEqual(args.contextStrategy, .strict)
    }

    test("APFEL_CONTEXT_MAX_TURNS env sets contextMaxTurns") {
        let args = try CLIArguments.parse(["--chat"], env: ["APFEL_CONTEXT_MAX_TURNS": "20"])
        try assertEqual(args.contextMaxTurns, 20)
    }

    test("APFEL_CONTEXT_OUTPUT_RESERVE env sets contextOutputReserve") {
        let args = try CLIArguments.parse(["--chat"], env: ["APFEL_CONTEXT_OUTPUT_RESERVE": "1024"])
        try assertEqual(args.contextOutputReserve, 1024)
    }

    test("APFEL_MCP env splits on colon separator") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_MCP": "a.py:b.py"])
        try assertEqual(args.mcpServerPaths, ["a.py", "b.py"])
    }

    test("APFEL_MCP_TIMEOUT env sets mcpTimeoutSeconds") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_MCP_TIMEOUT": "30"])
        try assertEqual(args.mcpTimeoutSeconds, 30)
    }

    // ========================================================================
    // MARK: - File reader injection
    // ========================================================================

    test("--file uses injected readFile closure") {
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

    test("file read failure throws CLIParseError with path in message") {
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

    test("multiple --file flags accumulate via injected reader") {
        var callCount = 0
        let args = try CLIArguments.parse(
            ["-f", "a.txt", "-f", "b.txt", "compare"],
            readFile: { path in
                callCount += 1
                return "content of \(path)"
            }
        )
        try assertEqual(args.fileContents, ["content of a.txt", "content of b.txt"])
        try assertEqual(callCount, 2)
    }

    // ========================================================================
    // MARK: - Mode conflict detection (NEW behavior)
    // ========================================================================

    test("--chat --serve throws mode conflict error") {
        do {
            _ = try CLIArguments.parse(["--chat", "--serve"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
            try assertTrue(e.message.contains("--chat"))
            try assertTrue(e.message.contains("--serve"))
        }
    }

    test("--serve --chat throws mode conflict (first flag wins ordering)") {
        do {
            _ = try CLIArguments.parse(["--serve", "--chat"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
            try assertTrue(e.message.contains("--serve"))
            try assertTrue(e.message.contains("--chat"))
        }
    }

    test("--chat --benchmark throws mode conflict") {
        do {
            _ = try CLIArguments.parse(["--chat", "--benchmark"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
        }
    }

    test("--stream --chat throws mode conflict") {
        do {
            _ = try CLIArguments.parse(["--stream", "--chat"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
        }
    }

    test("--chat --update throws mode conflict") {
        do {
            _ = try CLIArguments.parse(["--chat", "--update"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
        }
    }

    test("--model-info --serve throws mode conflict") {
        do {
            _ = try CLIArguments.parse(["--model-info", "--serve"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
        }
    }

    test("single mode flag does not trigger conflict") {
        // sanity check that a single --chat still works
        let args = try CLIArguments.parse(["--chat"])
        try assertEqual(args.mode, .chat)
    }

    // ========================================================================
    // MARK: - Combined integration tests
    // ========================================================================

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
        try assertEqual(args.outputFormat, .json)
        try assertEqual(args.prompt, "what is Swift?")
    }
}
