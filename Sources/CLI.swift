// ============================================================================
// CLI.swift — Command-line interface commands
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore

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
func singlePrompt(_ prompt: String, systemPrompt: String?, stream: Bool, options: SessionOptions = .defaults) async throws {
    let session = makeSession(systemPrompt: systemPrompt, options: options)
    let genOpts = makeGenerationOptions(options)

    switch outputFormat {
    case .plain:
        if stream {
            let _ = try await collectStream(session, prompt: prompt, printDelta: true, options: genOpts)
            print()
        } else {
            let response = try await session.respond(to: prompt, options: genOpts)
            print(response.content)
        }

    case .json:
        let content: String
        if stream {
            content = try await collectStream(session, prompt: prompt, printDelta: false, options: genOpts)
        } else {
            let response = try await session.respond(to: prompt, options: genOpts)
            content = response.content
        }
        let obj = ApfelResponse(
            model: modelName,
            content: content,
            metadata: .init(onDevice: true, version: version)
        )
        print(jsonString(obj))
    }
}

// MARK: - Interactive Chat

/// Run an interactive multi-turn chat session with context window protection.
func chat(systemPrompt: String?, options: SessionOptions = .defaults) async throws {
    guard isatty(STDIN_FILENO) != 0 else {
        printError("--chat requires an interactive terminal (stdin must be a TTY)")
        exit(exitUsageError)
    }

    let model = makeModel(permissive: options.permissive)
    var session = makeSession(systemPrompt: systemPrompt, options: options)
    let genOpts = makeGenerationOptions(options)
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
        if !quietMode {
            let prompt = styled("you› ", .green, .bold)
            if outputFormat == .json {
                stderr.write(Data(prompt.utf8))
            } else {
                print(prompt, terminator: "")
            }
        }
        fflush(stdout)

        guard let input = readLine() else { break }
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
            switch outputFormat {
            case .plain:
                let _ = try await collectStream(session, prompt: trimmed, printDelta: true, options: genOpts)
                print("\n")

            case .json:
                let content = try await collectStream(session, prompt: trimmed, printDelta: false, options: genOpts)
                print(jsonString(
                    ChatMessage(role: "assistant", content: content, model: modelName),
                    pretty: false
                ))
                fflush(stdout)
            }

            // Context window protection: check transcript size after each turn
            let transcript = session.transcript
            let tokenCount = await TokenCounter.shared.count(entries: Array(Array(transcript)))
            let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
            if tokenCount > budget {
                do {
                    let truncated = try await truncateTranscript(transcript, budget: budget, config: options.contextConfig)
                    session = LanguageModelSession(model: model, transcript: truncated)
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
    let entries = Array(Array(transcript))
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
    let available = await tc.isAvailable
    let contextSize = await tc.contextSize
    let languages = await tc.supportedLanguages

    print("""
    \(styled("apfel", .cyan, .bold)) v\(version) — model info
    \(styled("├", .dim)) model:      \(modelName)
    \(styled("├", .dim)) on-device:  true (always)
    \(styled("├", .dim)) available:  \(available ? styled("yes", .green) : styled("no", .red))
    \(styled("├", .dim)) context:    \(contextSize) tokens
    \(styled("├", .dim)) languages:  \(languages.joined(separator: ", "))
    \(styled("└", .dim)) framework:  FoundationModels (macOS 26+)
    """)
}

// MARK: - Usage

/// Print the help text. Styled with ANSI colors when on a TTY.
func printUsage() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — Apple Intelligence from the command line

    \(styled("USAGE:", .yellow, .bold))
      \(appName) [OPTIONS] <prompt>       Send a single prompt
      \(appName) --chat                   Interactive conversation
      \(appName) --stream <prompt>        Stream a single response
      \(appName) --serve                  Start OpenAI-compatible HTTP server

    \(styled("OPTIONS:", .yellow, .bold))
      -s, --system <text>       Set a system prompt
          --system-file <path>  Read system prompt from file
      -o, --output <format>     Output format: plain, json [default: plain]
      -q, --quiet               Suppress non-essential output
          --no-color             Disable colored output
          --temperature <n>      Sampling temperature (e.g., 0.7)
          --seed <n>             Random seed for reproducible output
          --max-tokens <n>       Maximum response tokens
          --permissive           Use permissive content guardrails
          --model-info           Print model capabilities and exit
      -h, --help                Show this help
      -v, --version             Print version

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
          --max-concurrent <n>   Max concurrent model requests [default: 5]
          --debug                Verbose logging

    \(styled("ENVIRONMENT:", .yellow, .bold))
      APFEL_SYSTEM_PROMPT       Default system prompt
      APFEL_HOST                Server bind address [default: 127.0.0.1]
      APFEL_PORT                Server port [default: 11434]
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
      \(appName) -o json "Translate to German: hello" | jq .content
      APFEL_SYSTEM_PROMPT="Be brief" \(appName) "Explain TCP"
      \(appName) --serve --port 3000 --host 0.0.0.0 --cors
    """)
}
