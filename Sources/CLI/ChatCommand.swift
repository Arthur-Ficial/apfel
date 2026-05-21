// ============================================================================
// ChatCommand.swift — Slash command recognition for --chat mode
// Part of ApfelCLI — pure, dependency-free, fully testable
// ============================================================================

/// A slash command the user can type in --chat mode.
///
/// ## Session commands
/// - `/clear` — clears the terminal screen visually; context is preserved.
/// - `/new`   — clears the screen AND resets the conversation to a fresh session.
/// - `/context` — prints the current chat context-window usage.
///
/// ## Developer tool shortcuts
/// - `/cmd <query>`          — natural language to shell command
/// - `/oneliner <query>`     — complex pipe chains from plain English
/// - `/naming <description>` — naming suggestions
/// - `/explain <snippet>`    — explain a command, error, or snippet
/// - `/wtd [directory]`      — "what's this directory?"
/// - `/port <number>`        — identify what is using a port
/// - `/process <pid>`        — identify a process by PID
/// - `/daemon <name>`        — explain a macOS daemon
    /// - `/docs-apple <query>`   — Apple developer documentation helper
    /// - `/mdn <query>`          — MDN Web Docs search (HTML, CSS, JavaScript, Web APIs)
public enum ChatCommand: Equatable, Sendable {
    case clear
    case new
    case context
    /// A premium developer tool invocation.
    /// `name` is always the canonical hyphenated form (e.g. `"docs-apple"`, never `"docs_apple"`).
    case tool(name: String, args: [String])

    /// The canonical names of developer tools that can be invoked via `/toolname` in chat.
    /// `docs-apple` appears once here; `docs_apple` is a recognised alias that normalises to it.
    public static let toolNames: [String] = [
        "cmd", "oneliner", "naming", "explain", "wtd",
        "port", "process", "daemon", "docs-apple", "mdn",
    ]

    /// Parse a raw user input string into a `ChatCommand`, or return `nil` if
    /// the input is not a recognised slash command.
    ///
    /// Rules:
    /// - Input must start with `/` (after whitespace trimming).
    /// - Keyword matching is case-insensitive.
    /// - `/clear`, `/new`, and `/context` require no arguments; extra words → `nil`.
    /// - Tool commands scan their tail for leading explicit flags (tokens
    ///   that start with `-`), then join the remainder into a single query
    ///   string. This prevents mid-query tokens such as `-l"` (from a user
    ///   typing `/explain "$ ls | wc -l"`) from being misrouted as bash flags.
    /// - `docs_apple` normalises to `docs-apple`.
    public static func parse(_ input: String) -> ChatCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/") else { return nil }

        let withoutSlash = String(trimmed.dropFirst())
        let parts = splitCommandLine(withoutSlash)
        guard !parts.isEmpty else { return nil }

        let keyword = parts[0].lowercased()
        let remainder = Array(parts.dropFirst())

        switch keyword {
        case "clear":
            return remainder.isEmpty ? .clear : nil
        case "new":
            return remainder.isEmpty ? .new : nil
        case "context":
            return remainder.isEmpty ? .context : nil
        case "docs-apple", "docs_apple":
            return .tool(name: "docs-apple", args: toolArgs(from: remainder))
        default:
            if Self.toolNames.contains(keyword) {
                return .tool(name: keyword, args: toolArgs(from: remainder))
            }
            return nil
        }
    }

    /// Partition a list of space-split tokens into leading explicit flags
    /// followed by a **single joined query string**.
    ///
    /// A token is treated as an explicit flag when it starts with `-` and
    /// appears before any non-flag token. Everything else is joined with
    /// spaces into one string, preserving the user's original phrasing
    /// (including quoted content, pipes, hyphens inside the query, etc.).
    ///
    /// Examples:
    /// ```
    /// ["-x", "show", "disk", "usage"]    → ["-x", "show disk usage"]
    /// ["\"$", "ls", "|", "wc", "-l\""]  → ["\"$ ls | wc -l\""]
    /// ["3000"]                           → ["3000"]
    /// []                                 → []
    /// ```
    private static func toolArgs(from tokens: [String]) -> [String] {
        var flags: [String] = []
        var rest: [String] = []
        var pastFlags = false
        for token in tokens {
            if !pastFlags && token.hasPrefix("-") {
                flags.append(token)
            } else {
                pastFlags = true
                rest.append(token)
            }
        }
        guard !rest.isEmpty else { return flags }
        return flags + [rest.joined(separator: " ")]
    }

    /// Split slash-command input on whitespace while treating double quotes as
    /// grouping markers. Single quotes are preserved because they are commonly
    /// meaningful in shell snippets passed to `/explain`.
    private static func splitCommandLine(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inDoubleQuotes = false
        var escaping = false

        for character in input {
            if escaping {
                current.append(character)
                escaping = false
                continue
            }

            if character == "\\" && inDoubleQuotes {
                escaping = true
                continue
            }

            if character == "\"" {
                inDoubleQuotes.toggle()
                continue
            }

            if character.isWhitespace && !inDoubleQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(character)
        }

        if escaping { current.append("\\") }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
