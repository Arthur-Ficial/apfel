// ============================================================================
// ShellRunner.swift - Run a subprocess and capture its stdout.
// ============================================================================

import Foundation

/// Run `executable` with `args` and return its stdout, or nil when the
/// command could not be launched or exited non-zero.
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
    // Drain before waiting: the child blocks in write(2) once the pipe
    // buffer fills, so waitUntilExit() would never return.
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)
}
