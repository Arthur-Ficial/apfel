// ============================================================================
// ShellOutput.swift - Run a subprocess and capture its stdout.
//
// Reads the pipe before waitUntilExit() to avoid deadlocking when the child
// writes more than the OS pipe buffer (typically 64 KiB). Returns nil when
// the command cannot be launched or exits non-zero so callers can distinguish
// failure from empty output (#433).
// ============================================================================

import Foundation

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
