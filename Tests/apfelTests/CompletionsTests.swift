// CompletionsTests - shell completion generator (#259)

import Foundation
import ApfelCLI
import ApfelCore

func runCompletionsTests() {

    test("completion flag table matches the parser's knownFlags exactly") {
        // The parser (CLIArguments.knownFlags) is the single source of truth
        // for which flags exist. The richer completion table only adds
        // metadata; its name set must equal knownFlags so a new parser flag
        // forces a completion-table update.
        try assertEqual(ShellCompletions.allFlagNames, CLIArguments.knownFlags)
    }

    test("every shell mentions every long flag the parser knows") {
        // Long flag appears verbatim in bash/zsh (--flag) and as its bare name
        // in fish (-l flag); the bare name (sans --) is a substring in all.
        let longFlags = CLIArguments.knownFlags.filter { $0.hasPrefix("--") }
        for shell in CompletionShell.allCases {
            let out = ShellCompletions.generate(for: shell)
            for flag in longFlags {
                let bare = String(flag.dropFirst(2))
                try assertTrue(out.contains(bare),
                    "\(shell.rawValue) completion missing \(flag)")
            }
        }
    }

    test("bash output has the correct registration markers") {
        let out = ShellCompletions.generate(for: .bash)
        try assertTrue(out.contains("_apfel()"), "missing _apfel() function")
        try assertTrue(out.contains("complete -F _apfel apfel"), "missing complete -F")
    }

    test("zsh output has the #compdef marker") {
        let out = ShellCompletions.generate(for: .zsh)
        try assertTrue(out.hasPrefix("#compdef apfel"), "missing #compdef header")
        try assertTrue(out.contains("_arguments"), "missing _arguments")
    }

    test("fish output has the complete -c apfel marker") {
        let out = ShellCompletions.generate(for: .fish)
        try assertTrue(out.contains("complete -c apfel"), "missing complete -c apfel")
    }

    test("all five context strategies appear as completion values") {
        for shell in CompletionShell.allCases {
            let out = ShellCompletions.generate(for: shell)
            for strategy in ContextStrategy.allCases {
                try assertTrue(out.contains(strategy.rawValue),
                    "\(shell.rawValue) missing strategy \(strategy.rawValue)")
            }
        }
    }

    test("-f gets file completion in every shell") {
        // bash/zsh: _files or compgen -f near the file flags; fish: -F force-files.
        let bash = ShellCompletions.generate(for: .bash)
        try assertTrue(bash.contains("compgen -f"), "bash missing file completion")
        let zsh = ShellCompletions.generate(for: .zsh)
        try assertTrue(zsh.contains("-f[Attach file content to prompt]:file:_files"),
            "zsh missing -f file completion")
        let fish = ShellCompletions.generate(for: .fish)
        try assertTrue(fish.contains("-l file -s f -r -F"), "fish missing -f file completion")
    }

    test("each shell's script ends with a single trailing newline") {
        for shell in CompletionShell.allCases {
            let out = ShellCompletions.generate(for: shell)
            try assertTrue(out.hasSuffix("\n"), "\(shell.rawValue) missing trailing newline")
            try assertTrue(!out.hasSuffix("\n\n"), "\(shell.rawValue) has double trailing newline")
        }
    }

    test("completions subcommand offers the three shell names in each script") {
        for shell in CompletionShell.allCases {
            let out = ShellCompletions.generate(for: shell)
            try assertTrue(out.contains("bash zsh fish"),
                "\(shell.rawValue) missing shell-name completion for the subcommand")
        }
    }

    // MARK: - parser: `completions <shell>` subcommand

    test("parse: `completions zsh` sets mode and shell") {
        let args = try CLIArguments.parse(["completions", "zsh"])
        try assertEqual(args.mode, .completions)
        try assertEqual(args.completionsShell, .zsh)
    }

    test("parse: `completions` with no shell is a usage error") {
        do {
            _ = try CLIArguments.parse(["completions"])
            throw TestFailure("expected a parse error")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("requires a shell"), e.message)
        }
    }

    test("parse: `completions badshell` is a usage error") {
        do {
            _ = try CLIArguments.parse(["completions", "powershell"])
            throw TestFailure("expected a parse error")
        } catch let e as CLIParseError {
            try assertTrue(e.message.lowercased().contains("shell"), e.message)
        }
    }

    test("parse: `completions bash --extra` rejects the extra token") {
        do {
            _ = try CLIArguments.parse(["completions", "bash", "--extra"])
            throw TestFailure("expected a parse error")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--extra") || e.message.lowercased().contains("unknown"), e.message)
        }
    }

    test("parse: `completions -h` shows help") {
        let args = try CLIArguments.parse(["completions", "-h"])
        try assertEqual(args.mode, .help)
    }
}
