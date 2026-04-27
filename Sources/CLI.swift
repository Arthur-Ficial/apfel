// ============================================================================
// CLI.swift — Command-line interface commands
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore
import ApfelCLI
import CReadline

// MARK: - Chat Header

/// Print the chat mode header (app name, version, separator line).
/// Suppressed in --quiet mode. Routed to stderr in JSON mode.
func printHeader() {
    guard !quietMode else { return }
    let header = styled("Apple Intelligence", .cyan, .bold)
        + styled(" · on-device LLM · \(appName) v\(version)", .dim)
    let line = styled(String(repeating: "─", count: 56), .dim)
    if outputFormat == .json {
        printStderr(header)
        printStderr(line)
    } else {
        print(header)
        print(line)
    }
}

// MARK: - Single Prompt

/// Handle a single (non-interactive) prompt.
///
/// Behavior depends on output format:
/// - **plain**: Print response directly. If streaming, print tokens as they arrive.
/// - **json**: Buffer the complete response, then emit a single JSON object.
func singlePrompt(_ prompt: String, systemPrompt: String?, stream: Bool, options: SessionOptions = .defaults, mcpManager: MCPManager? = nil) async throws {
    let mcpTools = await mcpManager?.allTools() ?? []
    let hasMCPTools = !mcpTools.isEmpty

    debugLog("single", "prompt_length=\(prompt.count) stream=\(stream) mcp=\(hasMCPTools)")

    let session: LanguageModelSession
    let finalPrompt: String
    if hasMCPTools {
        var msgs: [OpenAIMessage] = []
        if let sys = systemPrompt { msgs.append(OpenAIMessage(role: "system", content: .text(sys))) }
        msgs.append(OpenAIMessage(role: "user", content: .text(prompt)))
        (session, finalPrompt) = try await ContextManager.makeSession(
            messages: msgs, tools: mcpTools, options: options, jsonMode: false, toolChoice: nil)
    } else {
        session = makeSession(systemPrompt: systemPrompt, options: options)
        finalPrompt = prompt
    }
    let genOpts = makeGenerationOptions(options)

    let result = try await processPrompt(
        prompt: finalPrompt, systemPrompt: systemPrompt, session: session,
        options: options, genOpts: genOpts, stream: stream,
        printDelta: outputFormat == .plain, mcpManager: mcpManager, hasMCPTools: hasMCPTools)
    printToolLog(result.toolLog)

    switch outputFormat {
    case .plain:
        if hasMCPTools || !stream { print(result.content) } else { print() }
    case .json:
        let obj = ApfelResponse(
            model: modelName, content: result.content,
            metadata: .init(onDevice: true, version: version))
        print(jsonString(obj), terminator: "")
    }

    if result.finishReason == .length {
        printStderr("\(styled("apfel:", .yellow)) response truncated at the context window (finish_reason=length). Pass --max-tokens to control the cap explicitly.")
    }
}

// MARK: - Interactive Chat

/// Run an interactive multi-turn chat session with context window protection.
func chat(systemPrompt: String?, options: SessionOptions = .defaults, mcpManager: MCPManager? = nil) async throws {
    guard isatty(STDIN_FILENO) != 0 else {
        printError("--chat requires an interactive terminal (stdin must be a TTY)")
        exit(exitUsageError)
    }

    // Keep SIGINT blocked while chat bootstraps so background threads spawned
    // during model/session setup do not inherit an unblocked Ctrl-C.
    apfel_block_sigint()

    let mcpTools = await mcpManager?.allTools() ?? []
    let hasMCPTools = !mcpTools.isEmpty

    let model = makeModel(permissive: options.permissive)
    var session: LanguageModelSession
    if hasMCPTools {
        // Build session directly with tool definitions in Instructions.
        // Can't use ContextManager.makeSession() here because it requires a user message,
        // and chat has no user message at init time (user hasn't typed anything yet).
        let converted = await SchemaConverter.convert(tools: mcpTools)
        var instrParts: [String] = []
        if let sys = systemPrompt { instrParts.append(sys) }
        let toolNames = mcpTools.map { $0.function.name }
        instrParts.append(ToolCallHandler.buildOutputFormatInstructions(toolNames: toolNames))
        instrParts.append("IMPORTANT: You may ONLY call the functions listed above (\(toolNames.joined(separator: ", "))). Do NOT invent function names. If the user's request cannot be handled by these specific functions, respond with plain text.")
        if !converted.fallback.isEmpty {
            instrParts.append(ToolCallHandler.buildFallbackPrompt(tools: converted.fallback))
        }
        let instrText = instrParts.joined(separator: "\n\n")
        let segments: [Transcript.Segment] = [.text(Transcript.TextSegment(content: instrText))]
        let instr = Transcript.Instructions(segments: segments, toolDefinitions: converted.native)
        session = makeTranscriptSession(model: model, entries: [.instructions(instr)])
        debugLog("chat", "session created with \(converted.native.count) native + \(converted.fallback.count) fallback tools")
    } else {
        session = makeSession(systemPrompt: systemPrompt, options: options)
    }
    let genOpts = makeGenerationOptions(options)
    let lineEditor = ChatLineEditor(outputFormat: outputFormat)
    var turn = 0

    printHeader()
    if !quietMode {
        if let sys = systemPrompt {
            let sysLine = styled("system: ", .magenta, .bold) + styled(sys, .dim)
            if outputFormat == .json {
                printStderr(sysLine)
            } else {
                print(sysLine)
            }
        }
        let hint = styled("Type 'quit' to exit.\n", .dim)
        if outputFormat == .json {
            printStderr(hint)
        } else {
            print(hint)
        }
    }

    while true {
        let prompt = quietMode ? "" : "you› "
        guard let input = lineEditor.readLine(prompt: prompt) else { break }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed.lowercased() == "quit" || trimmed.lowercased() == "exit" { break }

        turn += 1

        if outputFormat == .json {
            print(jsonString(
                ChatMessage(role: "user", content: trimmed, model: nil),
                pretty: false
            ))
            fflush(stdout)
        }

        if !quietMode && outputFormat == .plain {
            print(styled(" ai› ", .cyan, .bold), terminator: "")
            fflush(stdout)
        }

        do {
            let result = try await processPrompt(
                prompt: trimmed, systemPrompt: systemPrompt, session: session,
                options: options, genOpts: genOpts, stream: true,
                printDelta: outputFormat == .plain, mcpManager: mcpManager, hasMCPTools: hasMCPTools)
            if !hasMCPTools && outputFormat == .plain { print("\n") }
            printToolLog(result.toolLog)
            let content = result.content

            switch outputFormat {
            case .plain:
                if hasMCPTools { print(content + "\n") }
            case .json:
                print(jsonString(
                    ChatMessage(role: "assistant", content: content, model: modelName),
                    pretty: false
                ))
                fflush(stdout)
            }

            // Context window protection: check transcript size after each turn
            let transcript = session.transcript
            let tokenCount = await TokenCounter.shared.count(entries: transcriptEntries(transcript))
            let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
            if tokenCount > budget {
                do {
                    let truncated = try await truncateTranscript(transcript, budget: budget, config: options.contextConfig)
                    if hasMCPTools {
                        // Re-inject MCP tool definitions into the truncated transcript.
                        // Without this, tools silently stop working after context rotation.
                        let truncEntries = transcriptEntries(truncated)
                        var rebuilt: [Transcript.Entry] = []
                        let converted = await SchemaConverter.convert(tools: mcpTools)
                        if let first = truncEntries.first, case .instructions(let instr) = first {
                            let updated = Transcript.Instructions(
                                segments: instr.segments, toolDefinitions: converted.native)
                            rebuilt.append(.instructions(updated))
                            rebuilt.append(contentsOf: truncEntries.dropFirst())
                        } else {
                            let toolInstr = Transcript.Instructions(
                                segments: [], toolDefinitions: converted.native)
                            rebuilt.append(.instructions(toolInstr))
                            rebuilt.append(contentsOf: truncEntries)
                        }
                        session = makeTranscriptSession(model: model, entries: rebuilt)
                        debugLog("context", "rotated with MCP tools re-injected (\(converted.native.count) native)")
                    } else {
                        session = LanguageModelSession(model: model, transcript: truncated)
                        debugLog("context", "rotated (no MCP tools)")
                    }
                    if !quietMode && outputFormat == .plain {
                        print(styled("  [context rotated — \(options.contextConfig.strategy.rawValue)]", .dim))
                    }
                } catch {
                    let classified = ApfelError.classify(error)
                    printError("\(classified.cliLabel) \(classified.openAIMessage)")
                    break
                }
            }
        } catch {
            let classified = ApfelError.classify(error)
            printError("\(classified.cliLabel) \(classified.openAIMessage)")
        }
    }

    if !quietMode {
        let bye = styled("\nGoodbye.", .dim)
        if outputFormat == .json {
            printStderr(bye)
        } else {
            print(bye)
        }
    }
}

// MARK: - Context Truncation

/// Truncate a transcript to fit within the token budget using the configured strategy.
func truncateTranscript(_ transcript: Transcript, budget: Int, config: ContextConfig = .defaults) async throws -> Transcript {
    let entries = transcriptEntries(transcript)
    guard !entries.isEmpty else { return transcript }

    let baseEntries: [Transcript.Entry]
    let historyEntries: [Transcript.Entry]
    if case .instructions = entries.first {
        baseEntries = [entries.first!]
        historyEntries = Array(entries.dropFirst())
    } else {
        baseEntries = []
        historyEntries = entries
    }

    guard let trimmed = await trimHistoryEntriesToBudget(
        baseEntries: baseEntries,
        historyEntries: historyEntries,
        budget: budget,
        config: config
    ) else {
        throw ApfelError.contextOverflow
    }

    return Transcript(entries: trimmed)
}

// MARK: - Model Info

/// Print model information and exit.
func printModelInfo() async {
    let tc = TokenCounter.shared
    let availability = await tc.availability
    let contextSize = await tc.contextSize
    let languages = await tc.supportedLanguages

    let availabilityLine = availability.isAvailable
        ? styled(availability.shortLabel, .green)
        : styled(availability.shortLabel, .red)

    print("""
    \(styled("apfel", .cyan, .bold)) v\(version) — model info
    \(styled("├", .dim)) model:      \(modelName)
    \(styled("├", .dim)) on-device:  true (always)
    \(styled("├", .dim)) available:  \(availabilityLine)
    \(styled("├", .dim)) context:    \(contextSize) tokens
    \(styled("├", .dim)) languages:  \(languages.joined(separator: ", "))
    \(styled("└", .dim)) framework:  FoundationModels (macOS 26+)
    """)

    if !availability.isAvailable {
        print("")
        print(styled("How to fix:", .yellow, .bold))
        print(availability.remediation)
    }
}

// MARK: - Release Info

func printRelease() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — release info

    \(styled("BUILD:", .yellow, .bold))
    \(styled("├", .dim)) version:    \(version)
    \(styled("├", .dim)) commit:     \(buildCommit)
    \(styled("├", .dim)) branch:     \(buildBranch)
    \(styled("├", .dim)) built:      \(buildDate)
    \(styled("├", .dim)) swift:      \(buildSwiftVersion)
    \(styled("└", .dim)) os:         \(buildOS)

    \(styled("CAPABILITIES:", .yellow, .bold))
    \(styled("├", .dim)) on-device:  100% local inference (no cloud, no API keys)
    \(styled("├", .dim)) model:      \(modelName) (FoundationModels framework)
    \(styled("├", .dim)) modes:      single, stream, chat, serve
    \(styled("├", .dim)) server:     OpenAI-compatible (/v1/chat/completions)
    \(styled("├", .dim)) tools:      function calling + MCP tool servers (--mcp)
    \(styled("├", .dim)) formats:    plain, json, streaming SSE
    \(styled("└", .dim)) strategies: newest-first, oldest-first, sliding-window, summarize, strict

    \(styled("LINKS:", .yellow, .bold))
    \(styled("├", .dim)) repo:       https://github.com/Arthur-Ficial/apfel
    \(styled("├", .dim)) gui:        https://github.com/Arthur-Ficial/apfel-gui
    \(styled("└", .dim)) requires:   macOS 26+, Apple Silicon, Apple Intelligence enabled
    """)
}

// MARK: - Self-Update

/// Check for updates and optionally run `brew upgrade apfel`.
/// Detects install method from the binary path, prompts y/N on TTY.
func performUpdate() {
    let current = version
    let execPath = ProcessInfo.processInfo.arguments[0]
    let resolved = (execPath as NSString).resolvingSymlinksInPath

    let isBrew = resolved.contains("/homebrew/Cellar/apfel/") || resolved.contains("/homebrew/opt/apfel/")

    if isBrew {
        print("\(appName) v\(current) (installed via Homebrew)")
    } else {
        print("\(appName) v\(current) (installed from source)")
        print("To update: git pull && make install")
        print("Or visit: https://github.com/Arthur-Ficial/apfel/releases")
        return
    }

    // Check for updates via brew
    let outdatedJSON = shellOutput("/opt/homebrew/bin/brew", args: ["info", "--json=v2", "apfel"])
    guard let data = outdatedJSON.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let formulae = json["formulae"] as? [[String: Any]],
          let formula = formulae.first,
          let installed = formula["installed"] as? [[String: Any]],
          let installedVersion = installed.first?["version"] as? String,
          let stable = (formula["versions"] as? [String: Any])?["stable"] as? String else {
        print("Could not check for updates. Try: brew upgrade apfel")
        return
    }

    if installedVersion == stable {
        print(styled("Already up to date.", .green))
        return
    }

    print("Update available: \(styled("v\(stable)", .green))")
    print("")

    // Non-interactive: report only
    guard isatty(STDIN_FILENO) != 0 else {
        print("Run `apfel --update` in a terminal to update.")
        return
    }

    print("Update now? [y/N] ", terminator: "")
    fflush(stdout)
    guard let answer = readLine(), answer.lowercased() == "y" else {
        print("Cancelled.")
        return
    }

    print(styled("Running: brew upgrade apfel", .dim))
    let result = shellPassthrough("/opt/homebrew/bin/brew", args: ["upgrade", "apfel"])
    if result == 0 {
        let newVersion = shellOutput("/opt/homebrew/bin/apfel", args: ["--version"]).trimmingCharacters(in: .whitespacesAndNewlines)
        print(styled("Updated to \(newVersion)", .green))
    } else {
        printError("brew upgrade failed (exit \(result)). Try manually: brew upgrade apfel")
    }
}

/// Run a command and capture stdout.
private func shellOutput(_ executable: String, args: [String]) -> String {
    let proc = Process()
    let pipe = Pipe()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        return ""
    }
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

/// Run a command with stdout/stderr passed through to the terminal.
@discardableResult
private func shellPassthrough(_ executable: String, args: [String]) -> Int32 {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        return 1
    }
    return proc.terminationStatus
}

// MARK: - Usage

/// Print the help text. Styled with ANSI colors when on a TTY.
func printUsage() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — Apple Intelligence from the command line

    \(styled("USAGE:", .yellow, .bold))
      \(appName) [OPTIONS] <prompt>       Send a single prompt
      \(appName) -f <file> <prompt>       Attach file content to prompt
      \(appName) --chat                   Interactive conversation
      \(appName) --stream <prompt>        Stream a single response
      \(appName) --serve                  Start OpenAI-compatible HTTP server
      \(appName) --benchmark              Run internal performance benchmarks

    \(styled("OPTIONS:", .yellow, .bold))
      -f, --file <path>         Attach file content to prompt (repeatable)
      -s, --system <text>       Set a system prompt
          --system-file <path>  Read system prompt from file
      -o, --output <format>     Output format: plain, json [default: plain]
      -q, --quiet               Suppress non-essential output
          --no-color             Disable colored output
          --temperature <n>      Sampling temperature (e.g., 0.7)
          --seed <n>             Random seed for reproducible output
          --max-tokens <n>       Maximum response tokens
          --mcp <path|url>       Attach local or remote MCP tool server (repeatable)
          --mcp-token <token>    Bearer token for remote MCP servers (prefer APFEL_MCP_TOKEN env)
          --mcp-timeout <n>      MCP server timeout in seconds [default: 5]
          --permissive           Use permissive content guardrails
          --retry [n]            Enable retry with exponential backoff [default: 3 retries]
          --model-info           Print model capabilities and exit
          --benchmark            Run internal performance benchmarks
          --update               Check for updates and upgrade via Homebrew
          --debug                Enable debug logging to stderr (all modes)
      -h, --help                Show this help
      -v, --version             Print version
          --release             Show detailed release and build info

    \(styled("CONTEXT OPTIONS:", .yellow, .bold))
          --context-strategy <s>  Context management strategy [default: newest-first]
                                  newest-first, oldest-first, sliding-window,
                                  summarize, strict (error on overflow)
          --context-max-turns <n> Max history turns (sliding-window only)
          --context-output-reserve <n>
                                  Tokens reserved for output [default: 512]

    \(styled("SERVER OPTIONS:", .yellow, .bold))
          --serve                Start OpenAI-compatible HTTP server
          --port <number>        Server port [default: 11434]
          --host <address>       Bind address [default: 127.0.0.1]
          --cors                 Enable CORS headers for browser clients
          --allowed-origins <origins>
                                 Add comma-separated origins to localhost defaults
          --no-origin-check      Disable origin checking (allow all origins)
          --token <secret>       Require Bearer token authentication
          --token-auto           Generate and print a random Bearer token
          --public-health        Keep /health unauthenticated on non-loopback binds
          --footgun              Disable all protections (--no-origin-check + --cors)
          --max-concurrent <n>   Max concurrent model requests [default: 5]


    \(styled("ENVIRONMENT:", .yellow, .bold))
      APFEL_SYSTEM_PROMPT       Default system prompt
      APFEL_MCP                 MCP server paths (colon-separated)
      APFEL_MCP_TIMEOUT         MCP timeout in seconds [default: 5]
      APFEL_HOST                Server bind address [default: 127.0.0.1]
      APFEL_PORT                Server port [default: 11434]
      APFEL_TOKEN               Bearer token for server authentication
      APFEL_TEMPERATURE         Default temperature
      APFEL_MAX_TOKENS          Default max tokens
      APFEL_CONTEXT_STRATEGY    Default context strategy
      APFEL_CONTEXT_MAX_TURNS   Max turns for sliding-window
      APFEL_CONTEXT_OUTPUT_RESERVE
                                Tokens reserved for output
      NO_COLOR                  Disable colored output (https://no-color.org)

    \(styled("EXIT CODES:", .yellow, .bold))
      0  Success
      1  Runtime error
      2  Usage error (bad flags)
      3  Guardrail blocked (content policy)
      4  Context overflow (input too long)
      5  Model unavailable (Apple Intelligence not enabled)
      6  Rate limited / busy

    \(styled("EXAMPLES:", .yellow, .bold))
      \(appName) "What is the capital of Austria?"
      \(appName) --stream "Write a haiku about code"
      \(appName) -s "You are a pirate" --chat
      \(appName) --system-file prompt.txt "Analyze this"
      echo "Summarize this" | \(appName)
      \(appName) -f code.swift "Explain this code"
      \(appName) -f a.txt -f b.txt "Compare these files"
      cat README.md | \(appName) "Summarize this"
      \(appName) -o json "Translate to German: hello" | jq .content
      APFEL_SYSTEM_PROMPT="Be brief" \(appName) "Explain TCP"
      \(appName) --serve --port 3000 --host 0.0.0.0 --cors
    """)
}
