// ============================================================================
// CLIErrors.swift - Template helpers for CLIParseError messages.
// Part of ApfelCLI - CLI-specific parsing, separate from ApfelCore domain logic.
//
// These helpers replace 22 hand-written `CLIParseError("...")` call sites in
// CLIArguments.swift with 5 reusable templates. The templates preserve the
// substrings that existing tests check ("requires", "unknown option",
// "cannot combine", flag names, file paths) so no existing tests break.
// ============================================================================

import Foundation

/// Template helpers for constructing `CLIParseError` values with consistent
/// wording across the parser. Prefer these over hand-written strings.
public enum CLIErrors {

    /// Build a "requires a value" error for a flag that was given on the
    /// command line without its argument.
    ///
    /// - Parameters:
    ///   - flag: The flag name, including dashes (e.g., `"--system"`).
    ///   - hint: Optional detail appended in parentheses (e.g., `"plain or json"`).
    public static func requiresValue(_ flag: String, hint: String? = nil) -> CLIParseError {
        let base = "\(flag) requires a value"
        if let hint = hint {
            return CLIParseError("\(base) (\(hint))")
        }
        return CLIParseError(base)
    }

    /// Build an "unknown <kind>: <got>" error for a value that was not in the
    /// flag's allowed set. The `kind` parameter lets the caller spell out the
    /// noun phrase exactly so the message reads naturally ("unknown output
    /// format", "unknown strategy", etc.) and matches the existing hand-written
    /// wording the tests check for.
    ///
    /// - Parameters:
    ///   - got: The invalid value the user passed (e.g., `"xml"`).
    ///   - kind: The noun phrase describing what kind of thing is invalid
    ///     (e.g., `"output format"`, `"strategy"`).
    ///   - hint: Detail appended in parentheses (e.g., `"use plain or json"`).
    public static func invalidValue(got: String, kind: String, hint: String) -> CLIParseError {
        CLIParseError("unknown \(kind): \(got) (\(hint))")
    }

    /// Build an "unknown option" error for a flag the parser does not know.
    public static func unknownOption(_ name: String) -> CLIParseError {
        CLIParseError("unknown option: \(name)")
    }

    /// Build a "cannot combine X and Y" error for two mutually exclusive
    /// mode flags (e.g., `--chat --serve`).
    public static func modeConflict(_ first: String, _ second: String) -> CLIParseError {
        CLIParseError("cannot combine \(first) and \(second)")
    }

    /// Build a file-read error with the reason and path.
    ///
    /// - Parameters:
    ///   - path: The file path that failed to read.
    ///   - reason: Human-readable cause (e.g., `"no such file"`).
    public static func fileReadError(path: String, reason: String) -> CLIParseError {
        CLIParseError("\(reason): \(path)")
    }
}
