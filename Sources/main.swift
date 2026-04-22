// ============================================================================
// main.swift — Entry point for apfel
// Apple Intelligence from the command line.
// https://github.com/Arthur-Ficial/apfel
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI
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

let rawArgs = Array(CommandLine.arguments.dropFirst())

// No-args + stdin-pipe fast path: `echo "prompt" | apfel` with no flags.
// Must stay above the parse() call because it needs isatty + await singlePrompt
// before any parsing happens.
if rawArgs.isEmpty {
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

// Pure, testable parsing. Errors land here as CLIParseError.
let parsed: CLIArguments
do {
    parsed = try CLIArguments.parse(rawArgs, env: ProcessInfo.processInfo.environment)
} catch let error as CLIParseError {
    printError(error.message)
    exit(exitUsageError)
}

// Handle immediate-exit modes.
switch parsed.mode {
case .help:
    printUsage()
    exit(exitSuccess)
case .version:
    print("\(appName) v\(version)")
    exit(exitSuccess)
case .release:
    printRelease()
    exit(exitSuccess)
default:
    break
}

// Apply parsed values to global state used throughout the main target.
if let fmt = parsed.outputFormat { outputFormat = fmt }
if parsed.quiet { quietMode = true }
if parsed.noColor { noColorFlag = true }
if parsed.debug { ApfelDebugConfiguration.isEnabled = true }

// Build the prompt: positional args + piped stdin + attached files.
var prompt = parsed.prompt
var fileContents = parsed.fileContents

// Read stdin when piped (single/stream) -- as the prompt (no args) or prepended to the prompt.
if parsed.mode.acceptsStdinInput && isatty(STDIN_FILENO) == 0 {
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

// Prepend file/stdin content to the prompt.
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
    strategy: parsed.contextStrategy ?? .newestFirst,
    maxTurns: parsed.contextMaxTurns,
    outputReserve: parsed.contextOutputReserve ?? 512,
    permissive: parsed.permissive
)

let sessionOpts = SessionOptions(
    temperature: parsed.temperature,
    maxTokens: parsed.maxTokens,
    seed: parsed.seed,
    permissive: parsed.permissive,
    contextConfig: contextConfig,
    retryEnabled: parsed.retryEnabled,
    retryCount: parsed.retryCount
)

// Resolve the final allowed-origins list: defaults + any CLI-specified values.
let serverAllowedOrigins: [String] = {
    var origins = OriginValidator.defaultAllowedOrigins
    for origin in parsed.serverAllowedOrigins where !origins.contains(origin) {
        origins.append(origin)
    }
    return origins
}()

// Check model availability for modes that need it. If unavailable, surface
// the specific reason (appleIntelligenceNotEnabled / deviceNotEligible /
// modelNotReady) so users know exactly what to fix. See #59.
switch parsed.mode {
case .modelInfo, .serve, .update:
    break
default:
    let availability = await TokenCounter.shared.availability
    if !availability.isAvailable {
        printError("Model unavailable: \(availability.shortLabel)")
        printStderr("")
        printStderr(availability.remediation)
        printStderr("")
        printStderr("For full diagnostic info run: apfel --model-info")
        exit(exitModelUnavailable)
    }
}

// Initialize MCP servers if any.
var mcpManager: MCPManager?
if !parsed.mcpServerPaths.isEmpty {
    do {
        mcpManager = try await MCPManager(paths: parsed.mcpServerPaths, bearerToken: parsed.mcpBearerToken, timeoutSeconds: parsed.mcpTimeoutSeconds)
    } catch {
        printError("MCP server failed to start: \(error)")
        exit(exitRuntimeError)
    }
}
defer { Task { await mcpManager?.shutdown() } }

do {
    switch parsed.mode {
    case .serve:
        var serverToken = parsed.serverToken
        let tokenWasAutoGenerated = parsed.serverTokenAuto && serverToken == nil
        if parsed.serverTokenAuto && serverToken == nil {
            serverToken = UUID().uuidString
        }
        let config = ServerConfig(
            host: parsed.serverHost,
            port: parsed.serverPort,
            cors: parsed.serverCORS,
            maxConcurrent: parsed.serverMaxConcurrent,
            debug: parsed.debug,
            allowedOrigins: parsed.serverOriginCheckEnabled ? serverAllowedOrigins : ["*"],
            originCheckEnabled: parsed.serverOriginCheckEnabled,
            token: serverToken,
            tokenWasAutoGenerated: tokenWasAutoGenerated,
            publicHealth: parsed.serverPublicHealth,
            retryEnabled: parsed.retryEnabled,
            retryCount: parsed.retryCount
        )
        try await startServer(config: config, mcpManager: mcpManager)

    case .update:
        performUpdate()

    case .modelInfo:
        await printModelInfo()

    case .benchmark:
        try await runBenchmarks()

    case .chat:
        try await chat(systemPrompt: parsed.systemPrompt, options: sessionOpts, mcpManager: mcpManager)

    case .stream:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: parsed.systemPrompt, stream: true, options: sessionOpts, mcpManager: mcpManager)

    case .single:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: parsed.systemPrompt, stream: false, options: sessionOpts, mcpManager: mcpManager)

    case .help, .version, .release:
        break   // Already handled above; exhaustive switch.
    }
} catch {
    let classified = ApfelError.classify(error)
    printError("\(classified.cliLabel) \(classified.openAIMessage)")
    exit(exitCode(for: classified))
}
