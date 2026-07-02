// ============================================================================
// main.swift — Entry point for apfel
// Apple Intelligence from the command line.
// https://github.com/Arthur-Ficial/apfel
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI
import CReadline

// MARK: - Locale
// Honour the user's LC_CTYPE so libedit handles multibyte characters
// (backspace, arrow keys, Ctrl-W) correctly in --chat (#256).
setlocale(LC_CTYPE, "")

// MARK: - Configuration

let version = buildVersion
let appName = "apfel"
let modelName = "apple-foundationmodel"

// MARK: - Exit Codes
// Declared as `let` here (not the ApfelExitCodes struct) so the
// man-page bidirectional-coverage test (test_bidirectional_exit_code_coverage)
// can still scrape them via its `let\s+exit\w+` regex. Values are delegated
// to ApfelCLI.ApfelExitCodes to keep the mapping unit-testable.

let exitSuccess: Int32 = ApfelExitCodes.success
let exitRuntimeError: Int32 = ApfelExitCodes.runtimeError
let exitUsageError: Int32 = ApfelExitCodes.usageError
let exitGuardrail: Int32 = ApfelExitCodes.guardrail
let exitContextOverflow: Int32 = ApfelExitCodes.contextOverflow
let exitModelUnavailable: Int32 = ApfelExitCodes.modelUnavailable
let exitRateLimited: Int32 = ApfelExitCodes.rateLimited

/// Map an ApfelError to the appropriate exit code.
/// Thin wrapper around ApfelExitCodes.code(for:) (see Sources/CLI/ExitCodes.swift)
/// so the mapping is unit-testable.
func exitCode(for error: ApfelError) -> Int32 {
    ApfelExitCodes.code(for: error)
}

// MARK: - Signal Handling

apfel_install_sigint_exit_handler(isatty(STDOUT_FILENO) != 0 ? 1 : 0)

// Ignore SIGPIPE process-wide. A crashed MCP server (or any closed pipe/socket
// peer) must not kill apfel: writes to a dead pipe would otherwise raise SIGPIPE
// with the default disposition and terminate the process (exit 141), taking down
// the whole --serve HTTP server. With SIG_IGN the write instead fails with EPIPE,
// which the throwing write path in MCPClient maps to a recoverable error (#215).
signal(SIGPIPE, SIG_IGN)

// True when stdin is a FIFO/pipe (`command | apfel`) vs a regular file
// redirect (`apfel < file`). We only suggest `2>&1` for the pipe case;
// regular files don't need that advice.
func stdinIsPipe() -> Bool {
    var st = stat()
    guard fstat(STDIN_FILENO, &st) == 0 else { return false }
    return (st.st_mode & S_IFMT) == S_IFIFO
}

/// Read all of stdin as raw bytes — works for piped text and piped binary files alike.
func readStdinData() -> Data {
    (try? FileHandle.standardInput.readToEnd()) ?? Data()
}

/// Turn piped stdin into prompt text: a piped PDF or image is extracted via lesbar
/// (OCR + "what the image is about", same as `-f`); anything else is decoded as UTF-8
/// text — apfel's existing pipe behaviour. Empty stdin returns "".
/// Throws `CLIParseError` when the bytes are a PDF/image but extraction fails.
func stdinPromptText(_ data: Data) throws -> String {
    if data.isEmpty { return "" }
    if let extracted = try LesbarFileReader.extractPipedIfBinary(data) {
        return extracted
    }
    return (String(data: data, encoding: .utf8) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Argument Parsing

let rawArgs = Array(CommandLine.arguments.dropFirst())

// No args AND stdin is a TTY: nothing to read, nothing to do -> usage + exit 2.
// This is the only no-args special case. The bare-pipe case (`echo hi | apfel`)
// used to be a fast path that ran BEFORE parse() and therefore dropped every
// APFEL_* env var and skipped the model-availability gate (#222). It now flows
// through the normal parse()/dispatch path below.
if rawArgs.isEmpty && isatty(STDIN_FILENO) != 0 {
    printUsage()
    exit(exitUsageError)
}

// True for the bare-pipe invocation (`echo hi | apfel` with no flags). It
// streams by default to preserve the historical output behavior of that path.
let noArgsPipe = rawArgs.isEmpty

// Pure, testable parsing. Errors land here as CLIParseError.
let parsed: CLIArguments
do {
    parsed = try CLIArguments.parse(
        rawArgs,
        env: ProcessInfo.processInfo.environment,
        extractFile: { try LesbarFileReader.extractForPrompt(path: $0) }
    )
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
case .demos:
    exit(runDemosInstall(target: parsed.demosTarget))
default:
    break
}

// Apply parsed values to global state used throughout the main target.
if let fmt = parsed.outputFormat { outputFormat = fmt }
if parsed.quiet { quietMode = true }
if parsed.noColor { noColorFlag = true }
if parsed.debug { ApfelDebugConfiguration.isEnabled = true }

// Surface non-fatal parse warnings (invalid APFEL_* env values ignored in
// favor of defaults) on stderr unless --quiet. Collected by parse() so it
// stays pure; printed here (#254).
if !quietMode {
    for warning in parsed.warnings {
        printStderr("\(styled("apfel:", .yellow)) \(warning)")
    }
}

// Build the prompt: positional args + piped stdin + attached files.
var prompt = parsed.prompt
var fileContents = parsed.fileContents
var pipedContent: String? = nil

// Read stdin when piped (single/stream/count-tokens) -- as the prompt (no args) or prepended to the prompt.
if parsed.mode.acceptsStdinInput && isatty(STDIN_FILENO) == 0 {
    let stdinContent: String
    do {
        stdinContent = try stdinPromptText(readStdinData())
    } catch let error as CLIParseError {
        printError(error.message)
        exit(exitUsageError)
    }
    if !stdinContent.isEmpty {
        pipedContent = stdinContent
        if prompt.isEmpty && fileContents.isEmpty {
            prompt = stdinContent
        } else {
            fileContents.append(stdinContent)
        }
    } else if !quietMode && stdinIsPipe() {
        // Empty pipe: hint about stderr redirection. Fires whether or not a
        // prompt was given, so the bare-pipe case (`somecmd | apfel`, no args)
        // still gets the hint now that it flows through this path (#152, #222).
        printStderr("\(styled("apfel:", .yellow)) piped input was empty - if the command prints to stderr, try: command 2>&1 | apfel")
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

// Debuggable: with --debug, show exactly what each file extracted to and the full
// prompt that goes to the model, so you can see what apfel actually puts to the API.
if ApfelDebugConfiguration.isEnabled {
    for attachment in parsed.fileAttachments {
        debugLog("extract", "\(attachment.path) -> \(attachment.content.count) chars:\n\(attachment.content)")
    }
    debugLog("prompt", "final prompt to model (\(prompt.count) chars):\n\(prompt)")
}

// MARK: - Dispatch

let contextConfig = ContextConfig(
    strategy: parsed.contextStrategy ?? .newestFirst,
    maxTurns: parsed.contextMaxTurns,
    outputReserve: parsed.contextOutputReserve ?? BodyLimits.defaultOutputReserveTokens,
    permissive: parsed.permissive
)

let sessionOpts = SessionOptions(
    temperature: parsed.temperature,
    topP: parsed.topP,
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

// Reject empty-prompt single/stream invocations BEFORE the model-availability
// gate, so "nothing to do" is a usage error (exit 2) regardless of whether the
// model is available. This preserves the old bare-pipe behavior: an empty pipe
// with no args prints the hint above and exits 2 without touching the model.
if (parsed.mode == .single || parsed.mode == .stream) && prompt.isEmpty {
    printError("no prompt provided")
    exit(exitUsageError)
}

// Check model availability for modes that need it. If unavailable, surface
// the specific reason (appleIntelligenceNotEnabled / deviceNotEligible /
// modelNotReady) so users know exactly what to fix. See #59.
switch parsed.mode {
case .modelInfo, .serve, .update, .countTokens:
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

// Shut MCP servers down before the process exits. This must be an awaited call
// on every exit path, NOT a `defer { Task { ... } }`: async main returns and the
// process exits before an unstructured Task is ever scheduled, so children would
// only die on stdin EOF (a server ignoring EOF is orphaned) and the remote DELETE
// would never fire. terminate() + bounded waitUntilExit() reaps locals; the
// remote branch awaits its DELETE (#246).
func shutdownMCP() async {
    await mcpManager?.shutdown()
}

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
            retryCount: parsed.retryCount,
            permissive: parsed.permissive
        )
        try await startServer(config: config, mcpManager: mcpManager)

    case .update:
        performUpdate()

    case .modelInfo:
        await printModelInfo()

    case .benchmark:
        try await runBenchmarks()

    case .chat:
        try await chat(systemPrompt: parsed.systemPrompt, options: sessionOpts, mcpManager: mcpManager, contextStatus: parsed.contextStatus)

    case .stream:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            await shutdownMCP()
            exit(exitUsageError)
        }
        try await singlePrompt(prompt, systemPrompt: parsed.systemPrompt, stream: true, options: sessionOpts, mcpManager: mcpManager)

    case .single:
        guard !prompt.isEmpty else {
            printError("no prompt provided")
            await shutdownMCP()
            exit(exitUsageError)
        }
        // The bare-pipe case (`echo hi | apfel`) streams to preserve its
        // historical output behavior; an explicit prompt does not (#222).
        try await singlePrompt(prompt, systemPrompt: parsed.systemPrompt, stream: noArgsPipe, options: sessionOpts, mcpManager: mcpManager)

    case .countTokens:
        guard !prompt.isEmpty || parsed.systemPrompt != nil else {
            printError("no prompt or file content provided")
            await shutdownMCP()
            exit(exitUsageError)
        }
        let report = try await countTokens(
            mergedPrompt: prompt,
            positionalPrompt: parsed.prompt,
            pipedContent: pipedContent,
            fileAttachments: parsed.fileAttachments,
            systemPrompt: parsed.systemPrompt,
            options: sessionOpts,
            mcpManager: mcpManager
        )
        if parsed.strictCount && !report.fits {
            await shutdownMCP()
            exit(exitContextOverflow)
        }

    case .help, .version, .release, .demos:
        break   // Already handled above; exhaustive switch.
    }
} catch {
    let classified = ApfelError.classify(error)
    printError("\(classified.cliLabel) \(classified.openAIMessage)")
    await shutdownMCP()
    exit(exitCode(for: classified))
}

// Normal completion: await MCP shutdown before the process exits (#246).
await shutdownMCP()
