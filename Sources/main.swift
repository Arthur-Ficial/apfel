// ============================================================================
// main.swift — Entry point for apfel
// Apple Intelligence from the command line.
// https://github.com/Arthur-Ficial/apfel
// ============================================================================

import Foundation
import ApfelCore
import CReadline

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
    case .assetsUnavailable:   return exitRuntimeError
    case .unsupportedGuide:    return exitRuntimeError
    case .decodingFailure:     return exitRuntimeError
    case .unsupportedLanguage: return exitRuntimeError
    case .toolExecution:       return exitRuntimeError
    case .unknown:             return exitRuntimeError
    }
}

// MARK: - Signal Handling

apfel_install_sigint_exit_handler(isatty(STDOUT_FILENO) != 0 ? 1 : 0)

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
                let classified = ApfelError.classify(error)
                printError("\(classified.cliLabel) \(classified.openAIMessage)")
                exit(exitCode(for: classified))
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
var serverConfig = defaultServerServiceConfig(environment: env)
var serverTokenAuto: Bool = false
var cliTemperature: Double? = Double(env["APFEL_TEMPERATURE"] ?? "")
var cliSeed: UInt64? = nil
var cliMaxTokens: Int? = Int(env["APFEL_MAX_TOKENS"] ?? "").flatMap { $0 > 0 ? $0 : nil }
var cliPermissive: Bool = false
var cliContextStrategy: ContextStrategy? = env["APFEL_CONTEXT_STRATEGY"].flatMap { ContextStrategy(rawValue: $0) }
var cliContextMaxTurns: Int? = env["APFEL_CONTEXT_MAX_TURNS"].flatMap { Int($0) }
var cliContextOutputReserve: Int? = env["APFEL_CONTEXT_OUTPUT_RESERVE"].flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
var fileContents: [String] = []

func parseAllowedOrigins(_ value: String) -> [String] {
    value.split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

var serviceSubcommand: ServiceSubcommand?
if args.first == "service" {
    guard args.count >= 2, let subcommand = ServiceSubcommand(rawValue: args[1]) else {
        printError("service requires one of: install|start|stop|restart|status|uninstall|run")
        exit(exitUsageError)
    }
    serviceSubcommand = subcommand
    mode = "service"
    args = Array(args.dropFirst(2))

    switch subcommand {
    case .install:
        break
    case .run:
        guard args.isEmpty else {
            printError("apfel service run does not accept extra arguments")
            exit(exitUsageError)
        }
    default:
        guard args.isEmpty else {
            printError("apfel service \(subcommand.rawValue) does not accept extra arguments")
            exit(exitUsageError)
        }
    }
}

func rejectServiceInstallOption(_ option: String) -> Never {
    printError("\(option) is not supported with apfel service install")
    exit(exitUsageError)
}

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
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count else {
            printError("--system requires a value")
            exit(exitUsageError)
        }
        systemPrompt = args[i]

    case "-o", "--output":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
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
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        quietMode = true

    case "--no-color":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        noColorFlag = true

    case "--chat":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "chat"

    case "--stream":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "stream"

    case "--serve":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "serve"

    case "--benchmark":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "benchmark"

    case "--port":
        i += 1
        guard i < args.count, let p = Int(args[i]), p > 0, p < 65536 else {
            printError("--port requires a valid port number (1-65535)")
            exit(exitUsageError)
        }
        serverConfig.port = p

    case "--host":
        i += 1
        guard i < args.count else {
            printError("--host requires an address")
            exit(exitUsageError)
        }
        serverConfig.host = args[i]

    case "--cors":
        serverConfig.cors = true

    case "--max-concurrent":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--max-concurrent requires a positive number")
            exit(exitUsageError)
        }
        serverConfig.maxConcurrent = n

    case "--debug":
        serverConfig.debug = true
        apfelDebugEnabled = true

    case "--allowed-origins":
        i += 1
        guard i < args.count else {
            printError("--allowed-origins requires a comma-separated list of origins")
            exit(exitUsageError)
        }
        let customOrigins = parseAllowedOrigins(args[i])
        guard !customOrigins.isEmpty else {
            printError("--allowed-origins requires at least one non-empty origin")
            exit(exitUsageError)
        }
        for origin in customOrigins where !serverConfig.allowedOrigins.contains(origin) {
            serverConfig.allowedOrigins.append(origin)
        }

    case "--no-origin-check":
        serverConfig.originCheckEnabled = false

    case "--token":
        i += 1
        guard i < args.count else {
            printError("--token requires a secret value")
            exit(exitUsageError)
        }
        serverConfig.token = args[i]

    case "--token-auto":
        serverTokenAuto = true

    case "--public-health":
        serverConfig.publicHealth = true

    case "--footgun":
        serverConfig.originCheckEnabled = false
        serverConfig.cors = true

    case "--mcp":
        i += 1
        guard i < args.count else {
            printError("--mcp requires a path to an MCP server script")
            exit(exitUsageError)
        }
        serverConfig.mcpServerPaths.append(args[i])

    case "--temperature":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let t = Double(args[i]), t >= 0 else {
            printError("--temperature requires a non-negative number (e.g., 0.7)")
            exit(exitUsageError)
        }
        cliTemperature = t

    case "--seed":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let s = UInt64(args[i]) else {
            printError("--seed requires a positive integer")
            exit(exitUsageError)
        }
        cliSeed = s

    case "--max-tokens":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--max-tokens requires a positive number")
            exit(exitUsageError)
        }
        cliMaxTokens = n

    case "--permissive":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        cliPermissive = true

    case "--retry":
        serverConfig.retryEnabled = true
        // Optional argument: --retry or --retry N
        if i + 1 < args.count, let n = Int(args[i + 1]), n > 0 {
            serverConfig.retryCount = n
            i += 1
        }

    case "--context-strategy":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let s = ContextStrategy(rawValue: args[i]) else {
            printError("--context-strategy requires: newest-first|oldest-first|sliding-window|summarize|strict")
            exit(exitUsageError)
        }
        cliContextStrategy = s

    case "--context-max-turns":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--context-max-turns requires a positive number")
            exit(exitUsageError)
        }
        cliContextMaxTurns = n

    case "--context-output-reserve":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--context-output-reserve requires a positive number")
            exit(exitUsageError)
        }
        cliContextOutputReserve = n

    case "--system-file":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
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
            printError(fileErrorMessage(path: path))
            exit(exitUsageError)
        }

    case "--model-info":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "model-info"

    case "--update":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        mode = "update"

    case "-f", "--file":
        if serviceSubcommand == .install { rejectServiceInstallOption(args[i]) }
        i += 1
        guard i < args.count else {
            printError("--file requires a file path")
            exit(exitUsageError)
        }
        let path = args[i]
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            fileContents.append(content)
        } catch {
            printError(fileErrorMessage(path: path))
            exit(exitUsageError)
        }

    default:
        if args[i].hasPrefix("-") {
            printError("unknown option: \(args[i])")
            exit(exitUsageError)
        }
        if serviceSubcommand == .install {
            printError("unexpected argument for apfel service install: \(args[i])")
            exit(exitUsageError)
        }
        prompt = args[i...].joined(separator: " ")
        i = args.count
        continue
    }
    i += 1
}

// Read stdin when piped -- as the prompt (no args) or prepended to the prompt
if mode == "single" && isatty(STDIN_FILENO) == 0 {
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    let stdinContent = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    if !stdinContent.isEmpty {
        if prompt.isEmpty && fileContents.isEmpty {
            prompt = stdinContent
        } else {
            fileContents.append(stdinContent)
        }
    }
}

// Prepend file/stdin content to the prompt
if !fileContents.isEmpty {
    let combined = fileContents.joined(separator: "\n\n")
    if prompt.isEmpty {
        prompt = combined
    } else {
        prompt = combined + "\n\n" + prompt
    }
}

// MARK: - Dispatch

let contextConfig = ContextConfig(
    strategy: cliContextStrategy ?? .newestFirst,
    maxTurns: cliContextMaxTurns,
    outputReserve: cliContextOutputReserve ?? 512,
    permissive: cliPermissive
)

let sessionOpts = SessionOptions(
    temperature: cliTemperature,
    maxTokens: cliMaxTokens,
    seed: cliSeed,
    permissive: cliPermissive,
    contextConfig: contextConfig,
    retryEnabled: serverConfig.retryEnabled,
    retryCount: serverConfig.retryCount
)

// Check model availability for modes that need it
let requiresModelAvailabilityCheck: Bool = {
    switch serviceSubcommand {
    case .run:
        return true
    case .install, .start, .stop, .restart, .status, .uninstall:
        return false
    case .none:
        return mode != "model-info" && mode != "serve" && mode != "update"
    }
}()
if requiresModelAvailabilityCheck {
    let available = await TokenCounter.shared.isAvailable
    if !available {
        printError("Apple Intelligence is not enabled or model is not ready. Run: apfel --model-info")
        exit(exitModelUnavailable)
    }
}

// Initialize MCP servers if any
var mcpManager: MCPManager?
if serviceSubcommand == nil && !serverConfig.mcpServerPaths.isEmpty {
    do {
        mcpManager = try await MCPManager(paths: serverConfig.mcpServerPaths)
    } catch {
        printError("MCP server failed to start: \(error)")
        exit(exitRuntimeError)
    }
}
defer { Task { await mcpManager?.shutdown() } }

do {
    switch mode {
    case "service":
        guard let serviceSubcommand else {
            printError("missing service subcommand")
            exit(exitUsageError)
        }

        switch serviceSubcommand {
        case .run:
            let manager = ServiceManager()
            let persistedConfig = try manager.loadConfig()
            var serviceMCPManager: MCPManager?
            if !persistedConfig.mcpServerPaths.isEmpty {
                do {
                    serviceMCPManager = try await MCPManager(paths: persistedConfig.mcpServerPaths)
                } catch {
                    printError("MCP server failed to start: \(error)")
                    exit(exitRuntimeError)
                }
            }
            defer { Task { await serviceMCPManager?.shutdown() } }
            try await startServer(
                config: makeRuntimeServerConfig(from: persistedConfig),
                mcpManager: serviceMCPManager
            )

        default:
            try await performServiceCommand(
                subcommand: serviceSubcommand,
                config: serverConfig,
                tokenAuto: serverTokenAuto
            )
        }

    case "serve":
        let tokenWasAutoGenerated = serverTokenAuto
        if serverTokenAuto {
            serverConfig.token = UUID().uuidString
        }
        try await startServer(
            config: makeRuntimeServerConfig(from: serverConfig, tokenWasAutoGenerated: tokenWasAutoGenerated),
            mcpManager: mcpManager
        )

    case "update":
        performUpdate()

    case "model-info":
        await printModelInfo()

    case "benchmark":
        try await runBenchmarks()

    case "chat":
        try await chat(systemPrompt: systemPrompt, options: sessionOpts, mcpManager: mcpManager)

    case "stream":
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: true, options: sessionOpts, mcpManager: mcpManager)

    default:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: systemPrompt, stream: false, options: sessionOpts, mcpManager: mcpManager)
    }
} catch {
    let classified = ApfelError.classify(error)
    printError("\(classified.cliLabel) \(classified.openAIMessage)")
    exit(exitCode(for: classified))
}

func fileErrorMessage(path: String) -> String {
    let fm = FileManager.default
    if !fm.fileExists(atPath: path) {
        return "no such file: \(path)"
    }
    if !fm.isReadableFile(atPath: path) {
        return "permission denied: \(path)"
    }
    return "cannot read file: \(path)"
}
