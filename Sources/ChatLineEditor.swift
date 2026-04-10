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

    init(outputFormat: OutputFormat, historyLimit: Int = 500) {
        previousInstream = apfel_get_rl_instream()
        previousOutstream = apfel_get_rl_outstream()

        using_history()
        stifle_history(Int32(historyLimit))

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
}
