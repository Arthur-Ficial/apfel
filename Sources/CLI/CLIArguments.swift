// ============================================================================
// CLIArguments.swift - Parsed CLI arguments as a testable value type
// Part of ApfelCLI - CLI-specific parsing, separate from ApfelCore domain logic
//
// parse() is a pure function: no side effects, no exit() calls, no direct file
// I/O. File reading is injectable via the `readFile` closure for testability.
// ============================================================================

import Foundation
import ApfelCore

/// Represents the result of parsing CLI arguments into a typed struct.
public struct CLIArguments: Sendable, Equatable {

    // MARK: - Mode

    public enum Mode: String, Sendable, Equatable {
        case single
        case stream
        case chat
        case serve
        case benchmark
        case modelInfo = "model-info"
        case update
        case help
        case version
        case release
    }

    public var mode: Mode = .single

    // MARK: - Prompt & Content

    public var prompt: String = ""
    public var systemPrompt: String? = nil
    public var fileContents: [String] = []

    // MARK: - Output

    public var outputFormat: OutputFormat? = nil
    public var quiet: Bool = false
    public var noColor: Bool = false

    // MARK: - Server

    public var serverPort: Int = 11434
    public var serverHost: String = "127.0.0.1"
    public var serverCORS: Bool = false
    public var serverMaxConcurrent: Int = 5
    public var debug: Bool = false
    public var serverAllowedOrigins: [String] = []
    public var serverOriginCheckEnabled: Bool = true
    public var serverToken: String? = nil
    public var serverTokenAuto: Bool = false
    public var serverPublicHealth: Bool = false

    // MARK: - MCP

    public var mcpServerPaths: [String] = []
    public var mcpTimeoutSeconds: Int = 5

    // MARK: - Generation

    public var temperature: Double? = nil
    public var seed: UInt64? = nil
    public var maxTokens: Int? = nil
    public var permissive: Bool = false

    // MARK: - Retry

    public var retryEnabled: Bool = false
    public var retryCount: Int = 3

    // MARK: - Context

    public var contextStrategy: ContextStrategy? = nil
    public var contextMaxTurns: Int? = nil
    public var contextOutputReserve: Int? = nil

    public init() {}
}

/// Errors thrown during argument parsing. Contains a user-facing message.
public struct CLIParseError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

// MARK: - Parsing

extension CLIArguments {

    /// Parse command-line arguments into a CLIArguments struct.
    ///
    /// Pure function: does not call exit(), does not read files directly, does
    /// not print. Returns the parsed result or throws `CLIParseError`.
    ///
    /// - Parameters:
    ///   - args: Command-line arguments (without the executable name).
    ///   - env: Environment variables. Env defaults are applied first, CLI
    ///     flags override them.
    ///   - readFile: Closure to read file contents by path. Defaults to
    ///     `String(contentsOfFile:)`. Injectable for testing.
    public static func parse(
        _ args: [String],
        env: [String: String] = [:],
        readFile: (_ path: String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) }
    ) throws -> CLIArguments {
        var result = CLIArguments()

        // Environment variable defaults (CLI flags override these).
        result.systemPrompt = env["APFEL_SYSTEM_PROMPT"]
        result.serverPort = Int(env["APFEL_PORT"] ?? "") ?? 11434
        result.serverHost = env["APFEL_HOST"] ?? "127.0.0.1"
        result.serverToken = env["APFEL_TOKEN"]
        result.mcpServerPaths = env["APFEL_MCP"]?
            .split(separator: ":").map(String.init).filter { !$0.isEmpty } ?? []
        result.mcpTimeoutSeconds = Int(env["APFEL_MCP_TIMEOUT"] ?? "")
            .flatMap { $0 > 0 ? min($0, 300) : nil } ?? 5
        result.temperature = Double(env["APFEL_TEMPERATURE"] ?? "")
        result.maxTokens = Int(env["APFEL_MAX_TOKENS"] ?? "").flatMap { $0 > 0 ? $0 : nil }
        result.contextStrategy = env["APFEL_CONTEXT_STRATEGY"].flatMap { ContextStrategy(rawValue: $0) }
        result.contextMaxTurns = env["APFEL_CONTEXT_MAX_TURNS"].flatMap { Int($0) }
        result.contextOutputReserve = env["APFEL_CONTEXT_OUTPUT_RESERVE"]
            .flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }

        // Track the first mode-setting flag seen so we can detect conflicts.
        // --help/-h/--version/-v/--release short-circuit out of parse and do
        // not participate in conflict detection (they are "give me info and
        // exit" requests).
        var firstModeFlag: String? = nil

        func setMode(_ mode: Mode, flagName: String) throws {
            if let first = firstModeFlag {
                throw CLIParseError("cannot combine \(first) and \(flagName)")
            }
            firstModeFlag = flagName
            result.mode = mode
        }

        var i = 0
        while i < args.count {
            switch args[i] {

            // -- Immediate-exit modes (no conflict detection) --

            case "-h", "--help":
                result.mode = .help
                return result

            case "-v", "--version":
                result.mode = .version
                return result

            case "--release":
                result.mode = .release
                return result

            // -- System prompt --

            case "-s", "--system":
                i += 1
                guard i < args.count else { throw CLIParseError("--system requires a value") }
                result.systemPrompt = args[i]

            case "--system-file":
                i += 1
                guard i < args.count else { throw CLIParseError("--system-file requires a file path") }
                let path = args[i]
                do {
                    result.systemPrompt = try readFile(path)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } catch let e as CLIParseError {
                    throw e
                } catch {
                    throw CLIParseError(fileErrorMessage(path: path))
                }

            // -- Output --

            case "-o", "--output":
                i += 1
                guard i < args.count else {
                    throw CLIParseError("--output requires a value (plain or json)")
                }
                guard let fmt = OutputFormat(rawValue: args[i]) else {
                    throw CLIParseError("unknown output format: \(args[i]) (use plain or json)")
                }
                result.outputFormat = fmt

            case "-q", "--quiet":
                result.quiet = true

            case "--no-color":
                result.noColor = true

            // -- Modes (conflict-detected) --

            case "--chat":
                try setMode(.chat, flagName: "--chat")

            case "--stream":
                try setMode(.stream, flagName: "--stream")

            case "--serve":
                try setMode(.serve, flagName: "--serve")

            case "--benchmark":
                try setMode(.benchmark, flagName: "--benchmark")

            case "--model-info":
                try setMode(.modelInfo, flagName: "--model-info")

            case "--update":
                try setMode(.update, flagName: "--update")

            // -- Server --

            case "--port":
                i += 1
                guard i < args.count, let p = Int(args[i]), p > 0, p < 65536 else {
                    throw CLIParseError("--port requires a valid port number (1-65535)")
                }
                result.serverPort = p

            case "--host":
                i += 1
                guard i < args.count else { throw CLIParseError("--host requires an address") }
                result.serverHost = args[i]

            case "--cors":
                result.serverCORS = true

            case "--max-concurrent":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIParseError("--max-concurrent requires a positive number")
                }
                result.serverMaxConcurrent = n

            case "--debug":
                result.debug = true

            case "--allowed-origins":
                i += 1
                guard i < args.count else {
                    throw CLIParseError("--allowed-origins requires a comma-separated list of origins")
                }
                let origins = parseAllowedOrigins(args[i])
                guard !origins.isEmpty else {
                    throw CLIParseError("--allowed-origins requires at least one non-empty origin")
                }
                for origin in origins where !result.serverAllowedOrigins.contains(origin) {
                    result.serverAllowedOrigins.append(origin)
                }

            case "--no-origin-check":
                result.serverOriginCheckEnabled = false

            case "--token":
                i += 1
                guard i < args.count else { throw CLIParseError("--token requires a secret value") }
                result.serverToken = args[i]

            case "--token-auto":
                result.serverTokenAuto = true

            case "--public-health":
                result.serverPublicHealth = true

            case "--footgun":
                result.serverOriginCheckEnabled = false
                result.serverCORS = true

            // -- MCP --

            case "--mcp":
                i += 1
                guard i < args.count else {
                    throw CLIParseError("--mcp requires a path to an MCP server script")
                }
                result.mcpServerPaths.append(args[i])

            case "--mcp-timeout":
                i += 1
                guard i < args.count, let t = Int(args[i]), t > 0 else {
                    throw CLIParseError("--mcp-timeout requires a positive number (seconds)")
                }
                result.mcpTimeoutSeconds = min(t, 300)

            // -- Generation --

            case "--temperature":
                i += 1
                guard i < args.count, let t = Double(args[i]), t >= 0 else {
                    throw CLIParseError("--temperature requires a non-negative number (e.g., 0.7)")
                }
                result.temperature = t

            case "--seed":
                i += 1
                guard i < args.count, let s = UInt64(args[i]) else {
                    throw CLIParseError("--seed requires a positive integer")
                }
                result.seed = s

            case "--max-tokens":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIParseError("--max-tokens requires a positive number")
                }
                result.maxTokens = n

            case "--permissive":
                result.permissive = true

            // -- Retry --

            case "--retry":
                result.retryEnabled = true
                // Optional argument: --retry or --retry N (positive).
                if i + 1 < args.count, let n = Int(args[i + 1]), n > 0 {
                    result.retryCount = n
                    i += 1
                }

            // -- Context --

            case "--context-strategy":
                i += 1
                guard i < args.count, let s = ContextStrategy(rawValue: args[i]) else {
                    throw CLIParseError("--context-strategy requires: newest-first|oldest-first|sliding-window|summarize|strict")
                }
                result.contextStrategy = s

            case "--context-max-turns":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIParseError("--context-max-turns requires a positive number")
                }
                result.contextMaxTurns = n

            case "--context-output-reserve":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIParseError("--context-output-reserve requires a positive number")
                }
                result.contextOutputReserve = n

            // -- File attachment --

            case "-f", "--file":
                i += 1
                guard i < args.count else { throw CLIParseError("--file requires a file path") }
                let path = args[i]
                do {
                    result.fileContents.append(try readFile(path))
                } catch let e as CLIParseError {
                    throw e
                } catch {
                    throw CLIParseError(fileErrorMessage(path: path))
                }

            // -- Fallthrough: prompt or unknown flag --

            default:
                if args[i].hasPrefix("-") {
                    throw CLIParseError("unknown option: \(args[i])")
                }
                result.prompt = args[i...].joined(separator: " ")
                i = args.count
                continue
            }
            i += 1
        }

        return result
    }

    // MARK: - Helpers

    private static func parseAllowedOrigins(_ value: String) -> [String] {
        value.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Human-friendly error message for a file read failure. Inspects the path
    /// to detect common mistakes (missing file, permissions, binary/image).
    public static func fileErrorMessage(path: String) -> String {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            return "no such file: \(path)"
        }
        if !fm.isReadableFile(atPath: path) {
            return "permission denied: \(path)"
        }
        let ext = (path.lowercased() as NSString).pathExtension
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "bmp", "svg", "ico":
            return "cannot attach image: \(path) -- the on-device model is text-only (no vision). Try: tesseract \(path) stdout | apfel \"describe this\""
        case "pdf", "zip", "tar", "gz", "dmg", "pkg", "exe", "bin", "dat", "mp3", "mp4", "mov", "avi", "wav":
            return "cannot attach binary file: \(path) -- only text files are supported"
        default:
            return "file is not valid UTF-8 text: \(path) (binary file?)"
        }
    }
}
