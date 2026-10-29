// ============================================================================
// Welcome.swift - no-args launch policy + welcome banner (pure, testable).
// Part of ApfelCLI.
//
// `apfel` with no arguments at an interactive terminal used to print usage
// and exit 2. When BOTH stdin and stdout are TTYs the friendlier behavior is
// a short welcome plus an interactive chat. When stdout is redirected
// (scripts capturing output) the historical usage-error contract is kept
// (#250: usage on stderr, exit 2) so pipelines cannot hang on a hidden
// interactive prompt.
// ============================================================================

import Foundation

/// Decides what a bare `apfel` invocation with stdin on a TTY does.
public enum NoArgsLaunch {
    public enum Decision: Equatable, Sendable {
        /// Print usage to stderr and exit 2 (the historical contract).
        case usageError
        /// Print the welcome banner and start an interactive chat.
        case welcomeChat
    }

    /// Only called when stdin is already known to be a TTY. Chat is
    /// interactive output: it needs a TTY on stdout too.
    public static func decide(stdoutIsTTY: Bool) -> Decision {
        stdoutIsTTY ? .welcomeChat : .usageError
    }
}

/// The short banner shown before the auto-started chat. An easy aid to climb
/// out of (quit) and into the three real entry points.
public enum WelcomeBanner {
    public static func lines(appName: String) -> [String] {
        [
            "Welcome to \(appName) — Apple Intelligence from the command line.",
            "  one-shot prompt:  \(appName) \"What is the capital of Austria?\"",
            "  chat:             \(appName) --chat   (starting it for you now)",
            "  everything else:  \(appName) --help",
        ]
    }
}
