// ============================================================================
// main.swift — Entry point for apfel
// Apple Intelligence from the command line.
// https://github.com/Arthur-Ficial/apfel
// ============================================================================

import Foundation
import ApfelCore

// MARK: - Configuration

let version = buildVersion
let appName = "apfel"
let modelName = "apple-foundationmodel"

// MARK: - Exit Codes

let exitSuccess: Int32 = 0
let exitRuntimeError: Int32 = 1
let exitUsageError: Int32 = 2
let exitGuardrail: Int32 = 3
let exitContextOverflow: Int32 = 4
let exitModelUnavailable: Int32 = 5
let exitRateLimited: Int32 = 6

/// Map an ApfelError to the appropriate exit code.
func exitCode(for error: ApfelError) -> Int32 {
    switch error {
    case .guardrailViolation:  return exitGuardrail
    case .contextOverflow:     return exitContextOverflow
    case .rateLimited:         return exitRateLimited
    case .concurrentRequest:   return exitRateLimited
    case .unsupportedLanguage: return exitRuntimeError
    case .unknown:             return exitRuntimeError
    }
}

// MARK: - Signal Handling

signal(SIGINT) { _ in
    if isatty(STDOUT_FILENO) != 0 {
        FileHandle.standardOutput.write(Data("\u{001B}[0m".utf8))
    }
    FileHandle.standardError.write(Data("\n".utf8))
    _exit(130)
}

// MARK: - Argument Parsing

var args = Array(CommandLine.arguments.dropFirst())

// Stdin pipe with no args
if args.isEmpty {
    if isatty(STDIN_FILENO) == 0 {
        var lines: [String] = []
        while let line = readLine(strippingNewline: false) {
            lines.append(line)
        }
        let input = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty {
            do {
                try await singlePrompt(input, systemPrompt: nil, stream: true)
                exit(exitSuccess)
            } catch {
                printError(error.localizedDescription)
                exit(exitRuntimeError)
            }
        }
    }
    printUsage()
    exit(exitUsageError)
}

// Parse flags — env vars provide defaults, CLI flags override
let env = ProcessInfo.processInfo.environment
var systemPrompt: String? = env["APFEL_SYSTEM_PROMPT"]
var mode: String = "single"
var prompt: String = ""
var serverPort: Int = Int(env["APFEL_PORT"] ?? "") ?? 11434
var serverHost: String = env["APFEL_HOST"] ?? "127.0.0.1"
var serverCORS: Bool = false
var serverMaxConcurrent: Int = 5
var serverDebug: Bool = false
var cliTemperature: Double? = Double(env["APFEL_TEMPERATURE"] ?? "")
var cliSeed: UInt64? = nil
var cliMaxTokens: Int? = Int(env["APFEL_MAX_TOKENS"] ?? "").flatMap { $0 > 0 ? $0 : nil }
var cliPermissive: Bool = false
var cliContextStrategy: ContextStrategy? = env["APFEL_CONTEXT_STRATEGY"].flatMap { ContextStrategy(rawValue: $0) }
var cliContextMaxTurns: Int? = env["APFEL_CONTEXT_MAX_TURNS"].flatMap { Int($0) }
var cliContextOutputReserve: Int? = env["APFEL_CONTEXT_OUTPUT_RESERVE"].flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }

var i = 0
while i < args.count {
    switch args[i] {
    case "-h", "--help":
        printUsage()
        exit(exitSuccess)

    case "-v", "--version":
        print("\(appName) v\(version)")
        exit(exitSuccess)

    case "--release":
        printRelease()
        exit(exitSuccess)

    case "-s", "--system":
        i += 1
        guard i < args.count else {
            printError("--system requires a value")
            exit(exitUsageError)
        }
        systemPrompt = args[i]

    case "-o", "--output":
        i += 1
        guard i < args.count else {
            printError("--output requires a value (plain or json)")
            exit(exitUsageError)
        }
        guard let fmt = OutputFormat(rawValue: args[i]) else {
            printError("unknown output format: \(args[i]) (use plain or json)")
            exit(exitUsageError)
        }
        outputFormat = fmt

    case "-q", "--quiet":
        quietMode = true

    case "--no-color":
        noColorFlag = true

    case "--chat":
        mode = "chat"

    case "--stream":
        mode = "stream"

    case "--serve":
        mode = "serve"

    case "--gui":
        mode = "gui"

    case "--port":
        i += 1
        guard i < args.count, let p = Int(args[i]), p > 0, p < 65536 else {
            printError("--port requires a valid port number (1-65535)")
            exit(exitUsageError)
        }
        serverPort = p

    case "--host":
        i += 1
        guard i < args.count else {
            printError("--host requires an address")
            exit(exitUsageError)
        }
        serverHost = args[i]

    case "--cors":
        serverCORS = true

    case "--max-concurrent":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--max-concurrent requires a positive number")
            exit(exitUsageError)
        }
        serverMaxConcurrent = n

    case "--debug":
        serverDebug = true

    case "--temperature":
        i += 1
        guard i < args.count, let t = Double(args[i]) else {
            printError("--temperature requires a number (e.g., 0.7)")
            exit(exitUsageError)
        }
        cliTemperature = t

    case "--seed":
        i += 1
        guard i < args.count, let s = UInt64(args[i]) else {
            printError("--seed requires a positive integer")
            exit(exitUsageError)
        }
        cliSeed = s

    case "--max-tokens":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--max-tokens requires a positive number")
            exit(exitUsageError)
        }
        cliMaxTokens = n

    case "--permissive":
        cliPermissive = true

    case "--context-strategy":
        i += 1
        guard i < args.count, let s = ContextStrategy(rawValue: args[i]) else {
            printError("--context-strategy requires: newest-first|oldest-first|sliding-window|summarize|strict")
            exit(exitUsageError)
        }
        cliContextStrategy = s

    case "--context-max-turns":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--context-max-turns requires a positive number")
            exit(exitUsageError)
        }
        cliContextMaxTurns = n

    case "--context-output-reserve":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--context-output-reserve requires a positive number")
            exit(exitUsageError)
        }
        cliContextOutputReserve = n

    case "--system-file":
        i += 1
        guard i < args.count else {
            printError("--system-file requires a file path")
            exit(exitUsageError)
        }
        let path = args[i]
        do {
            systemPrompt = try String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            printError("Cannot read file: \(path)")
            exit(exitUsageError)
        }

    case "--model-info":
        mode = "model-info"

    default:
        if args[i].hasPrefix("-") {
            printError("unknown option: \(args[i])")
            exit(exitUsageError)
        }
        prompt = args[i...].joined(separator: " ")
        i = args.count
        continue
    }
    i += 1
}

// If no prompt was given but stdin is piped, read stdin as the prompt
if prompt.isEmpty && mode == "single" && isatty(STDIN_FILENO) == 0 {
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    prompt = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Dispatch

let contextConfig = ContextConfig(
    strategy: cliContextStrategy ?? .newestFirst,
    maxTurns: cliContextMaxTurns,
    outputReserve: cliContextOutputReserve ?? 512
)

let sessionOpts = SessionOptions(
    temperature: cliTemperature,
    maxTokens: cliMaxTokens,
    seed: cliSeed,
    permissive: cliPermissive,
    contextConfig: contextConfig
)

// Check model availability for modes that need it
if mode != "model-info" && mode != "gui" && mode != "serve" {
    let available = await TokenCounter.shared.isAvailable
    if !available {
        printError("Apple Intelligence is not enabled or model is not ready. Run: apfel --model-info")
        exit(exitModelUnavailable)
    }
}

do {
    switch mode {
    case "gui":
        startGUI()

    case "serve":
        let config = ServerConfig(
            host: serverHost,
            port: serverPort,
            cors: serverCORS,
            maxConcurrent: serverMaxConcurrent,
            debug: serverDebug
        )
        try await startServer(config: config)

    case "model-info":
        await printModelInfo()

    case "chat":
        try await chat(systemPrompt: systemPrompt, options: sessionOpts)

    case "stream":
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: true, options: sessionOpts)

    default:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: false, options: sessionOpts)
    }
} catch {
    let classified = ApfelError.classify(error)
    printError("\(classified.cliLabel) \(classified.openAIMessage)")
    exit(exitCode(for: classified))
}
