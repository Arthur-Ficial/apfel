// ============================================================================
// ChatLineEditor.swift — Minimal libedit-backed line editor for chat mode
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation
import ApfelCLI
import CReadline

final class ChatLineEditor: @unchecked Sendable {
    private let inputStream: UnsafeMutablePointer<FILE>?
    private let promptStream: UnsafeMutablePointer<FILE>?
    private let previousInstream: UnsafeMutablePointer<FILE>?
    private let previousOutstream: UnsafeMutablePointer<FILE>?
    private var lastHistoryEntry: String?

    /// Path to the persistent history file, or nil for in-memory-only (the
    /// default). Set only when the user opts in via APFEL_HISTFILE (#259).
    private let historyFile: String?
    private let historyLimit: Int

    init(outputFormat: OutputFormat, historyLimit: Int = 500, historyFile: String? = nil) {
        previousInstream = apfel_get_rl_instream()
        previousOutstream = apfel_get_rl_outstream()
        self.historyFile = historyFile
        self.historyLimit = historyLimit

        using_history()
        stifle_history(Int32(historyLimit))

        // Opt-in persistence: load prior history so up-arrow reaches earlier
        // sessions. read_history is a no-op (returns errno) when the file does
        // not yet exist, so the first run is harmless.
        if let historyFile {
            _ = historyFile.withCString { read_history($0) }
        }

        if outputFormat == .json,
           let ttyInput = fopen("/dev/tty", "r"),
           let ttyOutput = fopen("/dev/tty", "w") {
            setvbuf(ttyOutput, nil, _IONBF, 0)
            inputStream = ttyInput
            promptStream = ttyOutput
            apfel_set_rl_instream(ttyInput)
            apfel_set_rl_outstream(ttyOutput)
        } else {
            inputStream = nil
            promptStream = nil
        }
    }

    deinit {
        persistHistory()
        clear_history()
        apfel_set_rl_instream(previousInstream)
        apfel_set_rl_outstream(previousOutstream)

        if let inputStream {
            fclose(inputStream)
        }
        if let promptStream {
            fflush(promptStream)
            fclose(promptStream)
        }
    }

    func readLine(prompt: String) -> String? {
        guard let rawLine = prompt.withCString({ apfel_readline_interruptible($0) }) else {
            return nil
        }
        defer { free(rawLine) }

        let line = String(cString: rawLine)
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && line != lastHistoryEntry {
            _ = line.withCString { add_history($0) }
            lastHistoryEntry = line
        }
        return line
    }

    /// Persist the current in-memory history to `historyFile` on exit (opt-in).
    ///
    /// macOS libedit exposes `read_history`/`write_history`/`history_truncate_file`
    /// but NOT `append_history` (it is a GNU readline extension), so we write the
    /// full in-memory list - which already merges the entries read in at startup
    /// with this session's additions - and then truncate the file to the last
    /// `historyLimit` lines so it stays bounded. The file is chmod 0600 because
    /// it contains the user's prompts.
    private func persistHistory() {
        guard let historyFile else { return }

        ChatHistory.prepareHistoryFile(at: historyFile)

        let wrote = historyFile.withCString { write_history($0) }
        guard wrote == 0 else { return }
        _ = historyFile.withCString { history_truncate_file($0, Int32(historyLimit)) }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: historyFile)
    }
}
