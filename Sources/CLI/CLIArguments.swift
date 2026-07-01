// ============================================================================
// CLIArguments.swift - Parsed CLI arguments as a testable value type
// Part of ApfelCLI - CLI-specific parsing, separate from ApfelCore domain logic
//
// parse() is a pure function: no side effects, no exit() calls, no direct file
// I/O. File reading is injectable via the `readFile` closure for testability.
// ============================================================================

import Foundation
import ApfelCore

/// A file attached via `-f` / `--file` with its source path retained.
public struct FileAttachment: Sendable, Equatable {
    public let path: String
    public let content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

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
        case demos
        case countTokens = "count-tokens"
        case help
        case version
        case release

        /// Whether this mode supports reading piped stdin as prompt input.
        /// Modes that accept a user prompt from the command line also accept
        /// it (or a prefix to it) from stdin.
        public var acceptsStdinInput: Bool {
            switch self {
            case .single, .stream, .countTokens: return true
            default: return false
            }
        }
    }

    public var mode: Mode = .single

    /// Target directory for `--demos` / `demos <dir>` (nil => default chosen at run time).
    public var demosTarget: String? = nil

    // MARK: - Prompt & Content

    public var prompt: String = ""
    public var systemPrompt: String? = nil
    public var fileContents: [String] = []
    /// Path + content for each `-f` / `--file` attachment (for `--count-tokens` breakdown).
    public var fileAttachments: [FileAttachment] = []

    /// Exit 4 when over budget (only valid with `--count-tokens`).
    public var strictCount: Bool = false

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
    public var mcpBearerToken: String? = nil

    // MARK: - Generation

    public var temperature: Double? = nil
    public var topP: Double? = nil
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
    public var contextStatus: Bool = false

    public init() {}
}

/// Errors thrown during argument parsing. Contains a user-facing message.
public struct CLIParseError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

// MARK: - Validation

/// Parser-phase state passed into `CLIArguments.validate(context:)`. Carries
/// information that is needed for semantic checks but does not belong on the
/// `CLIArguments` result struct itself (because it is process state, not
/// user-visible output).
///
/// Today this only tracks which mode flags were seen in which order so that
/// `validate()` can produce a friendly "cannot combine --X and --Y" error
/// when more than one is set. Future cross-flag checks will add more fields.
public struct ValidationContext: Sendable, Equatable {
    public var modeFlagsSeen: [String]

    public init() {
        self.modeFlagsSeen = []
    }

    public init(modeFlagsSeen: [String]) {
        self.modeFlagsSeen = modeFlagsSeen
    }
}

extension CLIArguments {

    /// Run semantic validation on a parsed `CLIArguments` value. This is the
    /// post-parse phase where cross-flag invariants are checked. Call this
    /// after `parse()` has returned a fully-populated struct, or call it
    /// directly on a hand-built struct (with an explicit context) to unit-test
    /// individual invariants.
    ///
    /// `parse()` invokes `validate()` internally as its last step, so callers
    /// using the normal API path (`CLIArguments.parse(args)`) do not need to
    /// call `validate()` themselves.
    ///
    /// - Parameter context: Parser-phase state (e.g., which mode flags were
    ///   seen in which order). Defaults to an empty context, which is
    ///   sufficient for checks that only need the `CLIArguments` struct
    ///   itself.
    public func validate(context: ValidationContext = .init()) throws {
        // Mode conflict: more than one mode flag was set during parsing.
        // First two flags seen win the error message, matching pre-refactor
        // behavior.
        if context.modeFlagsSeen.count > 1 {
            throw CLIErrors.modeConflict(
                context.modeFlagsSeen[0],
                context.modeFlagsSeen[1]
            )
        }
        if strictCount && mode != .countTokens {
            throw CLIParseError("--strict requires --count-tokens")
        }
        // Future cross-flag checks live here.
    }
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
    ///     `String(contentsOfFile:)`. Injectable for testing. Used by `--system-file`
    ///     (which stays text-only).
    ///   - extractFile: Closure that turns a `-f` file into prompt-ready text. Defaults to
    ///     the same plain UTF-8 read as `readFile`; the executable injects a lesbar-backed
    ///     extractor that also handles PDF and images (OCR + classification). Injectable so
    ///     `parse` stays pure and framework-free.
    public static func parse(
        _ args: [String],
        env: [String: String] = [:],
        readFile: (_ path: String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) },
        extractFile: (_ path: String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) }
    ) throws -> CLIArguments {
        var result = CLIArguments()

        // Environment variable defaults (CLI flags override these).
        result.systemPrompt = env["APFEL_SYSTEM_PROMPT"]
        result.serverPort = Int(env["APFEL_PORT"] ?? "")
            .flatMap { (1...65535).contains($0) ? $0 : nil } ?? 11434
        result.serverHost = env["APFEL_HOST"] ?? "127.0.0.1"
        result.serverToken = env["APFEL_TOKEN"]
        result.mcpServerPaths = env["APFEL_MCP"].map { parseMCPServerPaths($0) } ?? []
        result.mcpTimeoutSeconds = Int(env["APFEL_MCP_TIMEOUT"] ?? "")
            .flatMap { $0 > 0 ? min($0, 300) : nil } ?? 5
        result.mcpBearerToken = env["APFEL_MCP_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
        result.temperature = Double(env["APFEL_TEMPERATURE"] ?? "").flatMap { $0 >= 0 ? $0 : nil }
        result.maxTokens = Int(env["APFEL_MAX_TOKENS"] ?? "").flatMap { $0 > 0 ? $0 : nil }
        result.contextStrategy = env["APFEL_CONTEXT_STRATEGY"].flatMap { ContextStrategy(rawValue: $0) }
        result.contextMaxTurns = env["APFEL_CONTEXT_MAX_TURNS"].flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
        result.contextOutputReserve = env["APFEL_CONTEXT_OUTPUT_RESERVE"]
            .flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
        // APFEL_DEBUG=<any non-empty value> enables debug logging, same as --debug (#164).
        if let debugVal = env["APFEL_DEBUG"], !debugVal.isEmpty {
            result.debug = true
        }

        // Parser-phase state. Mode-setting flags are recorded in
        // `context.modeFlagsSeen` so the post-parse validate() step can detect
        // conflicts like `apfel --chat --serve`. --help/-h/--version/-v
        // /--release short-circuit out of parse entirely and do not
        // participate in conflict detection.
        var context = ValidationContext()

        // Subcommand form: `apfel demos [dir]`. Bare `demos` as the first token
        // is the friendly alias for `--demos`; a quoted prompt ("demos") still
        // works as a normal prompt because it is not the literal first arg here.
        if args.first == "demos" {
            result.mode = .demos
            if args.count > 1, !args[1].hasPrefix("-") {
                result.demosTarget = args[1]
            }
            return result
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
                guard i < args.count else { throw CLIErrors.requires("--system", "a value") }
                result.systemPrompt = args[i]

            case "--system-file":
                i += 1
                guard i < args.count else { throw CLIErrors.requires("--system-file", "a file path") }
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
                    throw CLIErrors.requires("--output", "a value (plain or json)")
                }
                guard let fmt = OutputFormat(rawValue: args[i]) else {
                    throw CLIErrors.invalidValue(got: args[i], kind: "output format", hint: "use plain or json")
                }
                result.outputFormat = fmt

            case "-q", "--quiet":
                result.quiet = true

            case "--no-color":
                result.noColor = true

            // -- Modes (conflict-detected via post-parse validate() step) --

            case "--chat":
                context.modeFlagsSeen.append("--chat")
                result.mode = .chat

            case "--stream":
                context.modeFlagsSeen.append("--stream")
                result.mode = .stream

            case "--serve":
                context.modeFlagsSeen.append("--serve")
                result.mode = .serve

            case "--benchmark":
                context.modeFlagsSeen.append("--benchmark")
                result.mode = .benchmark

            case "--count-tokens":
                context.modeFlagsSeen.append("--count-tokens")
                result.mode = .countTokens

            case "--strict":
                result.strictCount = true

            case "--model-info":
                context.modeFlagsSeen.append("--model-info")
                result.mode = .modelInfo

            case "--update":
                context.modeFlagsSeen.append("--update")
                result.mode = .update

            case "--demos":
                context.modeFlagsSeen.append("--demos")
                result.mode = .demos
                // Optional positional target dir directly after the flag.
                if i + 1 < args.count, !args[i + 1].hasPrefix("-") {
                    i += 1
                    result.demosTarget = args[i]
                }

            // -- Server --

            case "--port":
                i += 1
                guard i < args.count, let p = Int(args[i]), p > 0, p < 65536 else {
                    throw CLIErrors.requires("--port", "a valid port number (1-65535)")
                }
                result.serverPort = p

            case "--host":
                i += 1
                guard i < args.count else { throw CLIErrors.requires("--host", "an address") }
                result.serverHost = args[i]

            case "--cors":
                result.serverCORS = true

            case "--max-concurrent":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIErrors.requires("--max-concurrent", "a positive number")
                }
                result.serverMaxConcurrent = n

            case "--debug":
                result.debug = true

            case "--allowed-origins":
                i += 1
                guard i < args.count else {
                    throw CLIErrors.requires("--allowed-origins", "a comma-separated list of origins")
                }
                let origins = parseAllowedOrigins(args[i])
                guard !origins.isEmpty else {
                    throw CLIErrors.requires("--allowed-origins", "at least one non-empty origin")
                }
                for origin in origins where !result.serverAllowedOrigins.contains(origin) {
                    result.serverAllowedOrigins.append(origin)
                }

            case "--no-origin-check":
                result.serverOriginCheckEnabled = false

            case "--token":
                i += 1
                guard i < args.count else { throw CLIErrors.requires("--token", "a secret value") }
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
                    throw CLIErrors.requires("--mcp", "a path to an MCP server script")
                }
                result.mcpServerPaths.append(args[i])

            case "--mcp-timeout":
                i += 1
                guard i < args.count, let t = Int(args[i]), t > 0 else {
                    throw CLIErrors.requires("--mcp-timeout", "a positive number (seconds)")
                }
                result.mcpTimeoutSeconds = min(t, 300)

            case "--mcp-token":
                i += 1
                guard i < args.count else {
                    throw CLIErrors.requires("--mcp-token", "a token value")
                }
                result.mcpBearerToken = args[i]

            // -- Generation --

            case "--temperature":
                i += 1
                guard i < args.count, let t = Double(args[i]), t >= 0 else {
                    throw CLIErrors.requires("--temperature", "a non-negative number (e.g., 0.7)")
                }
                result.temperature = t

            case "--top-p":
                i += 1
                guard i < args.count, let p = Double(args[i]), p > 0, p <= 1 else {
                    throw CLIErrors.requires("--top-p", "a number in (0, 1] (e.g., 0.9)")
                }
                result.topP = p

            case "--seed":
                i += 1
                guard i < args.count, let s = UInt64(args[i]) else {
                    throw CLIErrors.requires("--seed", "a positive integer")
                }
                result.seed = s

            case "--max-tokens":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIErrors.requires("--max-tokens", "a positive number")
                }
                result.maxTokens = n

            case "--permissive":
                result.permissive = true

            // -- Retry --

            case "--retry":
                result.retryEnabled = true
                // Optional argument: --retry or --retry N (positive).
                // A next token that parses as an integer is treated as the
                // count; if it is non-positive, reject it like other numeric
                // flags rather than silently ignoring it.
                if i + 1 < args.count, let n = Int(args[i + 1]) {
                    guard n > 0 else {
                        throw CLIErrors.requires("--retry", "a positive number")
                    }
                    result.retryCount = n
                    i += 1
                }

            // -- Context --

            case "--context-strategy":
                i += 1
                guard i < args.count, let s = ContextStrategy(rawValue: args[i]) else {
                    throw CLIErrors.requires("--context-strategy", "one of: newest-first|oldest-first|sliding-window|summarize|strict")
                }
                result.contextStrategy = s

            case "--context-max-turns":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIErrors.requires("--context-max-turns", "a positive number")
                }
                result.contextMaxTurns = n

            case "--context-output-reserve":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIErrors.requires("--context-output-reserve", "a positive number")
                }
                result.contextOutputReserve = n

            case "--context-status":
                result.contextStatus = true

            // -- File attachment --

            case "-f", "--file":
                i += 1
                guard i < args.count else { throw CLIErrors.requires("--file", "a file path") }
                let path = args[i]
                do {
                    let content = try extractFile(path)
                    result.fileContents.append(content)
                    result.fileAttachments.append(FileAttachment(path: path, content: content))
                } catch let e as CLIParseError {
                    throw e
                } catch {
                    throw CLIParseError(fileErrorMessage(path: path))
                }

            // -- End of options (UNIX convention) --

            case "--":
                // Everything after "--" is the prompt verbatim, even if it
                // starts with a dash. A bare trailing "--" leaves the prompt
                // empty so stdin handling is unchanged.
                let rest = args[(i + 1)...]
                if !rest.isEmpty {
                    result.prompt = rest.joined(separator: " ")
                }
                i = args.count
                continue

            // -- Fallthrough: prompt or unknown flag --

            default:
                if args[i].hasPrefix("-") {
                    throw CLIErrors.unknownOption(args[i])
                }
                result.prompt = args[i...].joined(separator: " ")
                i = args.count
                continue
            }
            i += 1
        }

        // Post-parse semantic validation: mode conflicts, cross-flag
        // invariants, etc. Runs as the final step so parse() preserves its
        // end-to-end contract (callers catch the same errors they did
        // before).
        try result.validate(context: context)

        return result
    }

    // MARK: - Helpers

    /// Parse a colon- or comma-separated list of MCP server paths/URLs.
    ///
    /// Commas are the canonical separator and always work, including with
    /// http(s):// URLs. Colons work only for local paths (legacy); URL schemes
    /// are reassembled to avoid splitting "https://host:8080/mcp" incorrectly.
    private static func parseMCPServerPaths(_ value: String) -> [String] {
        if value.contains(",") {
            return value.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let parts = value.split(separator: ":").map(String.init).filter { !$0.isEmpty }
        var result: [String] = []
        var i = parts.startIndex
        while i < parts.endIndex {
            let part = parts[i]
            let next = parts.index(after: i)
            if (part == "http" || part == "https"),
               next < parts.endIndex,
               parts[next].hasPrefix("//") {
                var url = part + ":" + parts[next]
                var j = parts.index(after: next)
                while j < parts.endIndex, !parts[j].hasPrefix("//"),
                      !parts[j].hasPrefix("/"),   // absolute local path = end of URL
                      parts[j] != "http", parts[j] != "https" {
                    url += ":" + parts[j]
                    j = parts.index(after: j)
                }
                result.append(url)
                i = j
            } else {
                result.append(part)
                i = parts.index(after: i)
            }
        }
        return result.filter { !$0.isEmpty }
    }

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
        case "zip", "tar", "gz", "dmg", "pkg", "exe", "bin", "dat", "mp3", "mp4", "mov", "avi", "wav":
            return "unsupported file: \(path) -- apfel -f reads text, PDF, and images (JPEG, PNG, HEIC, TIFF, ...)"
        default:
            return "file is not valid UTF-8 text: \(path) (binary file?)"
        }
    }
}
