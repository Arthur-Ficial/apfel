// ============================================================================
// ChatHistory.swift - Persistent chat-history file policy (pure, testable)
// Part of ApfelCLI - decides *whether* and *where* chat history persists.
//
// The actual libedit read_history/write_history wiring lives in the root
// target (Sources/ChatLineEditor.swift), which is not unit-testable. The
// opt-in decision - the security-relevant part - lives here so apfel-tests
// can cover it.
// ============================================================================

import Foundation

/// Persistent chat-history policy for interactive `--chat` sessions.
///
/// History persistence is OFF by default: chat history is in-memory only
/// unless the user explicitly opts in by setting `APFEL_HISTFILE` to a path.
/// This is the honest, secure default - apfel never writes a transcript of
/// your prompts to disk unless you ask it to.
public enum ChatHistory {

    /// Environment variable that opts into persistent history and names the file.
    public static let envVar = "APFEL_HISTFILE"

    /// Maximum number of history entries retained in the file (matches the
    /// in-memory `stifle_history` bound so the file stays bounded).
    public static let maxEntries = 500

    /// Resolve the history file path from the environment.
    ///
    /// Returns `nil` (in-memory-only, the default) unless `APFEL_HISTFILE` is
    /// set to a non-empty value. A set-but-blank value (empty or whitespace)
    /// is treated as absence, consistent with how the parser treats other
    /// `APFEL_*` vars. A leading `~` is expanded to the user's home directory
    /// so `APFEL_HISTFILE=~/.apfel_history` works without shell expansion.
    public static func filePath(env: [String: String]) -> String? {
        guard let raw = env[envVar] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (trimmed as NSString).expandingTildeInPath
    }

    /// Ensure the history file and its parent directories exist with
    /// restrictive permissions BEFORE libedit writes prompts into it.
    ///
    /// libedit's `write_history` uses `fopen(path, "w")` which creates at
    /// `0666 & ~umask` (typically `0644`). Calling this first guarantees the
    /// file is never observable at a mode other than `0600`, closing the
    /// race window where prompts sit in a world-readable file (#473).
    public static func prepareHistoryPath(_ path: String) {
        let fm = FileManager.default
        let dir = (path as NSString).deletingLastPathComponent
        if !dir.isEmpty {
            try? fm.createDirectory(
                atPath: dir, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
        }
        if fm.fileExists(atPath: path) {
            try? fm.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: path)
        } else {
            fm.createFile(atPath: path, contents: nil,
                          attributes: [.posixPermissions: 0o600])
        }
    }
}
