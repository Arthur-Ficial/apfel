// ============================================================================
// CLIArgumentsTests.swift — Unit tests for CLIArguments.parse()
// ============================================================================

import Foundation
import ApfelCore

func runCLIArgumentsTests() {

    // -- Mode flags --

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
        let args = try CLIArguments.parse(["--stream"])
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

    // -- Prompt parsing --

    test("bare words become the prompt") {
        let args = try CLIArguments.parse(["hello", "world"])
        try assertEqual(args.prompt, "hello world")
    }

    test("prompt after flags") {
        let args = try CLIArguments.parse(["--quiet", "tell", "me", "a", "joke"])
        try assertEqual(args.prompt, "tell me a joke")
        try assertTrue(args.quiet)
    }

    // -- System prompt --

    test("--system sets systemPrompt") {
        let args = try CLIArguments.parse(["--system", "You are helpful", "hi"])
        try assertEqual(args.systemPrompt, "You are helpful")
    }

    test("-s sets systemPrompt") {
        let args = try CLIArguments.parse(["-s", "Be brief", "hi"])
        try assertEqual(args.systemPrompt, "Be brief")
    }

    test("--system without value throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--system"]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    // -- Output --

    test("--output plain") {
        let args = try CLIArguments.parse(["-o", "plain", "hi"])
        try assertEqual(args.outputFormat, "plain")
    }

    test("--output json") {
        let args = try CLIArguments.parse(["--output", "json", "hi"])
        try assertEqual(args.outputFormat, "json")
    }

    test("--output invalid throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--output", "xml"]) }
        catch let e as CLIParseError {
            threw = true
            try assertTrue(e.message.contains("unknown output format"))
        }
        try assertTrue(threw)
    }

    test("--quiet sets quiet") {
        let args = try CLIArguments.parse(["-q", "hi"])
        try assertTrue(args.quiet)
    }

    test("--no-color sets noColor") {
        let args = try CLIArguments.parse(["--no-color", "hi"])
        try assertTrue(args.noColor)
    }

    // -- Server flags --

    test("--port parses valid port") {
        let args = try CLIArguments.parse(["--serve", "--port", "8080"])
        try assertEqual(args.serverPort, 8080)
    }

    test("--port invalid throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--port", "99999"]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    test("--port zero throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--port", "0"]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    test("--host sets serverHost") {
        let args = try CLIArguments.parse(["--serve", "--host", "0.0.0.0"])
        try assertEqual(args.serverHost, "0.0.0.0")
    }

    test("--cors sets serverCORS") {
        let args = try CLIArguments.parse(["--serve", "--cors"])
        try assertTrue(args.serverCORS)
    }

    test("--max-concurrent parses") {
        let args = try CLIArguments.parse(["--serve", "--max-concurrent", "10"])
        try assertEqual(args.serverMaxConcurrent, 10)
    }

    test("--max-concurrent invalid throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--max-concurrent", "0"]) }
        catch { threw = true }
        try assertTrue(threw)
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

    test("--footgun disables origin check and enables CORS") {
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

    test("--allowed-origins empty throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--allowed-origins", ""]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    // -- MCP --

    test("--mcp adds server path") {
        let args = try CLIArguments.parse(["--mcp", "/path/to/server.py", "hi"])
        try assertEqual(args.mcpServerPaths.count, 1)
        try assertEqual(args.mcpServerPaths[0], "/path/to/server.py")
    }

    test("multiple --mcp accumulate") {
        let args = try CLIArguments.parse(["--mcp", "a.py", "--mcp", "b.py", "hi"])
        try assertEqual(args.mcpServerPaths.count, 2)
    }

    test("--mcp-timeout parses") {
        let args = try CLIArguments.parse(["--mcp-timeout", "10", "hi"])
        try assertEqual(args.mcpTimeoutSeconds, 10)
    }

    test("--mcp-timeout caps at 300") {
        let args = try CLIArguments.parse(["--mcp-timeout", "999", "hi"])
        try assertEqual(args.mcpTimeoutSeconds, 300)
    }

    // -- Generation --

    test("--temperature parses") {
        let args = try CLIArguments.parse(["--temperature", "0.7", "hi"])
        try assertEqual(args.temperature, 0.7)
    }

    test("--temperature negative throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--temperature", "-1"]) }
        catch { threw = true }
        try assertTrue(threw)
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
        var threw = false
        do { _ = try CLIArguments.parse(["--max-tokens", "0"]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    test("--permissive sets permissive") {
        let args = try CLIArguments.parse(["--permissive", "hi"])
        try assertTrue(args.permissive)
    }

    // -- Retry --

    test("--retry enables retry") {
        let args = try CLIArguments.parse(["--retry", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 3) // default
    }

    test("--retry with count") {
        let args = try CLIArguments.parse(["--retry", "5", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 5)
    }

    test("--retry without count keeps default") {
        let args = try CLIArguments.parse(["--retry", "--quiet", "hi"])
        try assertTrue(args.retryEnabled)
        try assertEqual(args.retryCount, 3)
    }

    // -- Context --

    test("--context-strategy parses valid strategy") {
        let args = try CLIArguments.parse(["--context-strategy", "sliding-window", "--chat"])
        try assertEqual(args.contextStrategy, .slidingWindow)
    }

    test("--context-strategy invalid throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--context-strategy", "invalid"]) }
        catch { threw = true }
        try assertTrue(threw)
    }

    test("--context-max-turns parses") {
        let args = try CLIArguments.parse(["--context-max-turns", "10", "--chat"])
        try assertEqual(args.contextMaxTurns, 10)
    }

    test("--context-output-reserve parses") {
        let args = try CLIArguments.parse(["--context-output-reserve", "256", "--chat"])
        try assertEqual(args.contextOutputReserve, 256)
    }

    // -- Unknown flags --

    test("unknown flag throws") {
        var threw = false
        do { _ = try CLIArguments.parse(["--nonexistent"]) }
        catch let e as CLIParseError {
            threw = true
            try assertTrue(e.message.contains("unknown option"))
        }
        try assertTrue(threw)
    }

    // -- Environment variable defaults --

    test("APFEL_PORT env sets default port") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_PORT": "9090"])
        try assertEqual(args.serverPort, 9090)
    }

    test("CLI flag overrides env var") {
        let args = try CLIArguments.parse(["--serve", "--port", "8080"], env: ["APFEL_PORT": "9090"])
        try assertEqual(args.serverPort, 8080)
    }

    test("APFEL_SYSTEM_PROMPT env sets systemPrompt") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_SYSTEM_PROMPT": "Be brief"])
        try assertEqual(args.systemPrompt, "Be brief")
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

    test("APFEL_MCP env sets MCP paths") {
        let args = try CLIArguments.parse(["hi"], env: ["APFEL_MCP": "a.py:b.py"])
        try assertEqual(args.mcpServerPaths, ["a.py", "b.py"])
    }

    test("APFEL_HOST env sets serverHost") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_HOST": "0.0.0.0"])
        try assertEqual(args.serverHost, "0.0.0.0")
    }

    test("APFEL_TOKEN env sets serverToken") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_TOKEN": "mytoken"])
        try assertEqual(args.serverToken, "mytoken")
    }

    // -- Combined flags --

    test("full server config parses") {
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

    test("full CLI config parses") {
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
