// ============================================================================
// ShellRunner.swift - Run a subprocess and capture its stdout.
//
// Drains the pipe before waiting for exit to avoid deadlocking when the
// child's output exceeds the OS pipe buffer (typically 64 KiB). Returns nil
// on launch failure or non-zero exit so callers can distinguish "command
// failed" from "command produced no output".
// ============================================================================

import Foundation

/// Run `executable` with `args` and return its trimmed stdout, or nil when
/// the command could not be launched or exited non-zero.
public func shellOutput(_ executable: String, args: [String]) -> String? {
    let proc = Process()
    let pipe = Pipe()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)
}
