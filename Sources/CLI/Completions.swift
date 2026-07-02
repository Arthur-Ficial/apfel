// ============================================================================
// Completions.swift - Shell completion generation (pure, testable)
// Part of ApfelCLI.
//
// The flag table below is the single richer view of the parser's flags: its
// flattened name set MUST equal CLIArguments.knownFlags (enforced by a unit
// test), so the parser stays the single source of truth for "what flags
// exist" and this file only adds per-flag completion metadata (does it take a
// value, and what values). `apfel completions <shell>` prints the generated
// script to stdout; the three generated files under completions/ are committed
// for packagers and kept in sync by a drift test.
// ============================================================================

import Foundation
import ApfelCore

/// A shell for which completions can be generated.
public enum CompletionShell: String, Sendable, CaseIterable {
    case bash
    case zsh
    case fish
}

/// How a flag consumes its following argument, for completion purposes.
public enum CompletionArg: Sendable, Equatable {
    /// Boolean flag - takes no argument.
    case none
    /// Takes a value with no specific completion (a number, free text, etc.).
    case generic
    /// Completes file paths.
    case file
    /// Completes directory paths.
    case directory
    /// Completes from a fixed list of values.
    case values([String])
}

/// One parser flag with its spellings and completion metadata.
public struct CompletionFlag: Sendable, Equatable {
    public let names: [String]     // e.g. ["-o", "--output"]
    public let arg: CompletionArg
    public let help: String

    public init(_ names: [String], _ arg: CompletionArg, _ help: String) {
        self.names = names
        self.arg = arg
        self.help = help
    }

    /// The long spelling (first name starting with `--`), if any.
    public var longName: String? { names.first { $0.hasPrefix("--") } }
    /// The short spelling (first single-dash name), if any.
    public var shortName: String? { names.first { !$0.hasPrefix("--") && $0.hasPrefix("-") } }
}

public enum ShellCompletions {

    /// The `completions <shell>` subcommand's shell arguments.
    static var shellArgs: [String] { CompletionShell.allCases.map(\.rawValue) }

    /// Context-strategy values, sourced from ApfelCore's enum so they cannot
    /// drift from the parser's accepted set.
    static var contextStrategyValues: [String] { ContextStrategy.allCases.map(\.rawValue) }

    /// The richer flag table. Its flattened name set equals
    /// `CLIArguments.knownFlags` (unit-enforced). Each entry adds the
    /// completion metadata the bare name set cannot carry.
    public static var flags: [CompletionFlag] {
        [
            CompletionFlag(["-h", "--help"], .none, "Show help"),
            CompletionFlag(["-v", "--version"], .none, "Print version"),
            CompletionFlag(["--release"], .none, "Show detailed build info"),
            CompletionFlag(["-s", "--system"], .generic, "Set a system prompt"),
            CompletionFlag(["--system-file"], .file, "Read system prompt from file"),
            CompletionFlag(["-o", "--output"], .values(["plain", "json"]), "Output format"),
            CompletionFlag(["-q", "--quiet"], .none, "Suppress non-essential output"),
            CompletionFlag(["--no-color"], .none, "Disable colored output"),
            CompletionFlag(["--chat"], .none, "Interactive conversation"),
            CompletionFlag(["--stream"], .none, "Stream a single response"),
            CompletionFlag(["--serve"], .none, "Start OpenAI-compatible HTTP server"),
            CompletionFlag(["--benchmark"], .none, "Run internal benchmarks"),
            CompletionFlag(["--count-tokens"], .none, "Count tokens without calling the model"),
            CompletionFlag(["--strict"], .none, "With --count-tokens: exit 4 if over budget"),
            CompletionFlag(["--model-info"], .none, "Print model capabilities"),
            CompletionFlag(["--update"], .none, "Check for updates via Homebrew"),
            CompletionFlag(["--demos"], .directory, "Write bundled demo scripts to dir"),
            CompletionFlag(["--port"], .generic, "Server port"),
            CompletionFlag(["--host"], .generic, "Server bind address"),
            CompletionFlag(["--cors"], .none, "Enable CORS headers"),
            CompletionFlag(["--max-concurrent"], .generic, "Max concurrent requests"),
            CompletionFlag(["--debug"], .none, "Enable debug logging"),
            CompletionFlag(["--allowed-origins"], .generic, "Comma-separated allowed origins"),
            CompletionFlag(["--no-origin-check"], .none, "Disable origin checking"),
            CompletionFlag(["--token"], .generic, "Require Bearer token auth"),
            CompletionFlag(["--token-auto"], .none, "Generate a random Bearer token"),
            CompletionFlag(["--public-health"], .none, "Keep /health unauthenticated"),
            CompletionFlag(["--footgun"], .none, "Disable all protections"),
            CompletionFlag(["--mcp"], .file, "Attach local or remote MCP server"),
            CompletionFlag(["--mcp-timeout"], .generic, "MCP timeout in seconds"),
            CompletionFlag(["--mcp-token"], .generic, "Bearer token for remote MCP servers"),
            CompletionFlag(["--temperature"], .generic, "Sampling temperature"),
            CompletionFlag(["--top-p"], .generic, "Nucleus sampling threshold"),
            CompletionFlag(["--seed"], .generic, "Random seed"),
            CompletionFlag(["--max-tokens"], .generic, "Maximum response tokens"),
            CompletionFlag(["--permissive"], .none, "Use permissive guardrails"),
            CompletionFlag(["--retry"], .none, "Enable retry with backoff"),
            CompletionFlag(["--context-strategy"], .values(contextStrategyValues), "Context management strategy"),
            CompletionFlag(["--context-max-turns"], .generic, "Max history turns"),
            CompletionFlag(["--context-output-reserve"], .generic, "Tokens reserved for output"),
            CompletionFlag(["--context-status"], .none, "Print context fill after each turn"),
            CompletionFlag(["-f", "--file"], .file, "Attach file content to prompt"),
        ]
    }

    /// Every flag spelling covered by the completion table. Kept equal to
    /// `CLIArguments.knownFlags` by a unit test.
    public static var allFlagNames: Set<String> {
        Set(flags.flatMap(\.names))
    }

    /// Generate a completion script for the given shell. The returned string
    /// ends with a single trailing newline.
    public static func generate(for shell: CompletionShell) -> String {
        switch shell {
        case .bash: return bash()
        case .zsh: return zsh()
        case .fish: return fish()
        }
    }

    // MARK: - bash

    private static func bash() -> String {
        var valueCases: [String] = []
        var fileFlags: [String] = []
        var dirFlags: [String] = []
        var genericFlags: [String] = []
        for f in flags {
            let pattern = f.names.joined(separator: "|")
            switch f.arg {
            case .values(let vs):
                valueCases.append("        \(pattern))\n            COMPREPLY=( $(compgen -W \"\(vs.joined(separator: " "))\" -- \"$cur\") ); return 0 ;;")
            case .file: fileFlags.append(pattern)
            case .directory: dirFlags.append(pattern)
            case .generic: genericFlags.append(pattern)
            case .none: break
            }
        }
        let allNames = flags.flatMap(\.names).sorted().joined(separator: " ")

        var lines: [String] = []
        lines.append("# apfel(1) bash completion - generated by `apfel completions bash`")
        lines.append("_apfel() {")
        lines.append("    local cur prev")
        lines.append("    cur=\"${COMP_WORDS[COMP_CWORD]}\"")
        lines.append("    prev=\"${COMP_WORDS[COMP_CWORD-1]}\"")
        lines.append("")
        lines.append("    # `apfel completions <shell>` subcommand")
        lines.append("    if [ \"${COMP_WORDS[1]}\" = \"completions\" ] && [ \"$COMP_CWORD\" -eq 2 ]; then")
        lines.append("        COMPREPLY=( $(compgen -W \"\(shellArgs.joined(separator: " "))\" -- \"$cur\") ); return 0")
        lines.append("    fi")
        lines.append("")
        lines.append("    case \"$prev\" in")
        lines.append(contentsOf: valueCases)
        if !fileFlags.isEmpty {
            lines.append("        \(fileFlags.joined(separator: "|")))\n            COMPREPLY=( $(compgen -f -- \"$cur\") ); return 0 ;;")
        }
        if !dirFlags.isEmpty {
            lines.append("        \(dirFlags.joined(separator: "|")))\n            COMPREPLY=( $(compgen -d -- \"$cur\") ); return 0 ;;")
        }
        if !genericFlags.isEmpty {
            lines.append("        \(genericFlags.joined(separator: "|")))\n            return 0 ;;")
        }
        lines.append("    esac")
        lines.append("")
        lines.append("    if [[ \"$cur\" == -* ]]; then")
        lines.append("        COMPREPLY=( $(compgen -W \"\(allNames) completions\" -- \"$cur\") ); return 0")
        lines.append("    fi")
        lines.append("    COMPREPLY=( $(compgen -f -- \"$cur\") ); return 0")
        lines.append("}")
        lines.append("complete -F _apfel apfel")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - zsh

    private static func zsh() -> String {
        var lines: [String] = []
        lines.append("#compdef apfel")
        lines.append("# apfel(1) zsh completion - generated by `apfel completions zsh`")
        lines.append("_apfel() {")
        lines.append("  if (( CURRENT == 3 )) && [[ ${words[2]} == completions ]]; then")
        lines.append("    _values 'shell' \(shellArgs.joined(separator: " "))")
        lines.append("    return")
        lines.append("  fi")
        lines.append("  _arguments -s \\")
        var specLines: [String] = []
        for f in flags {
            let action: String
            switch f.arg {
            case .none: action = ""
            case .generic: action = ":value:"
            case .file: action = ":file:_files"
            case .directory: action = ":dir:_files -/"
            case .values(let vs): action = ":value:(\(vs.joined(separator: " ")))"
            }
            for name in f.names {
                specLines.append("    '\(name)[\(f.help)]\(action)'")
            }
        }
        // completions subcommand as a positional word.
        specLines.append("    '1:command:(completions)'")
        specLines.append("    '*:file:_files'")
        lines.append(specLines.joined(separator: " \\\n"))
        lines.append("}")
        lines.append("_apfel \"$@\"")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - fish

    private static func fish() -> String {
        var lines: [String] = []
        lines.append("# apfel(1) fish completion - generated by `apfel completions fish`")
        // Disable default file completion; re-enable per file/dir flag.
        lines.append("complete -c apfel -f")
        // completions subcommand.
        lines.append("complete -c apfel -n '__fish_use_subcommand' -a completions -d 'Generate shell completions'")
        lines.append("complete -c apfel -n '__fish_seen_subcommand_from completions' -a '\(shellArgs.joined(separator: " "))'")
        for f in flags {
            var parts = ["complete -c apfel"]
            if let long = f.longName { parts.append("-l \(String(long.dropFirst(2)))") }
            if let short = f.shortName { parts.append("-s \(String(short.dropFirst(1)))") }
            switch f.arg {
            case .none: break
            case .generic: parts.append("-x")
            case .file: parts.append("-r -F")
            case .directory: parts.append("-x -a '(__fish_complete_directories)'")
            case .values(let vs): parts.append("-x -a '\(vs.joined(separator: " "))'")
            }
            parts.append("-d '\(f.help)'")
            lines.append(parts.joined(separator: " "))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
