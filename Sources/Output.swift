// ============================================================================
// Output.swift — Terminal output helpers (colors, stderr, formatting)
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

// MARK: - Global State
// Set during argument parsing (before any async work) and read during execution.
// Marked `nonisolated(unsafe)` because Swift 6 strict concurrency treats global
// mutable state as @MainActor-isolated. Safe here: single-threaded CLI, write-once.

/// True if the NO_COLOR environment variable is set (https://no-color.org)
let noColorEnv = ProcessInfo.processInfo.environment["NO_COLOR"] != nil

/// True if --no-color flag was passed
nonisolated(unsafe) var noColorFlag = false

/// Output format: plain (default) or json
nonisolated(unsafe) var outputFormat: OutputFormat = .plain

/// True if --quiet flag was passed (suppresses headers, prompts, chrome)
nonisolated(unsafe) var quietMode = false

// MARK: - ANSI Colors

enum ANSIColor: String, Sendable {
    case reset   = "\u{001B}[0m"
    case bold    = "\u{001B}[1m"
    case dim     = "\u{001B}[2m"
    case cyan    = "\u{001B}[36m"
    case green   = "\u{001B}[32m"
    case yellow  = "\u{001B}[33m"
    case magenta = "\u{001B}[35m"
    case red     = "\u{001B}[31m"
}

/// Apply ANSI color codes to text. Returns plain text if stdout is not a TTY,
/// NO_COLOR is set, or --no-color was passed.
func styled(_ text: String, _ colors: ANSIColor...) -> String {
    let isTerminal = isatty(STDOUT_FILENO) != 0
    guard isTerminal, !noColorEnv, !noColorFlag else { return text }
    let prefix = colors.map(\.rawValue).joined()
    return "\(prefix)\(text)\(ANSIColor.reset.rawValue)"
}

// MARK: - Output Helpers

let stderr = FileHandle.standardError

/// Print a message to stderr with a trailing newline.
func printStderr(_ message: String) {
    stderr.write(Data("\(message)\n".utf8))
}

/// Print a styled error message to stderr. Format: "error: <message>"
func printError(_ message: String) {
    stderr.write(Data("\(styled("error:", .red, .bold)) \(message)\n".utf8))
}

// MARK: - Debug Output

/// Print a debug message to stderr. Zero-cost when debug logging is disabled.
func debugLog(_ message: @autoclosure () -> String) {
    guard ApfelDebugConfiguration.isEnabled else { return }
    printStderr("\(styled("debug:", .dim)) \(message())")
}

/// Print a categorized debug message to stderr. Zero-cost when debug logging is disabled.
func debugLog(_ category: String, _ message: @autoclosure () -> String) {
    guard ApfelDebugConfiguration.isEnabled else { return }
    printStderr("\(styled("debug[\(category)]:", .dim)) \(message())")
}
