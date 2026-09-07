import Foundation
import ApfelCore

/// Broken-pipe handling (#389).
///
/// `main.swift` ignores SIGPIPE process-wide (#215) so a vanished pipe reader
/// cannot kill us by signal. That hardening had a sharp edge: the legacy
/// non-throwing `FileHandle.write(_:)` turns the resulting EPIPE into an
/// Objective-C `NSFileHandleOperationException`, which Swift cannot catch, so
/// `apfel --stream ... | head -1` aborted with a stack trace instead of
/// finishing quietly. These tests pin the replacement.
func runBrokenPipeTests() {
    // `writeTolerantly` can only report a broken pipe as a Swift error while
    // SIGPIPE is ignored -- otherwise the signal kills the process before the
    // write returns. The shipping binary establishes that at startup
    // (`Sources/main.swift`, #215); the test runner has no such main, so it
    // must establish the same precondition or these tests take the whole
    // suite down with signal 13.
    signal(SIGPIPE, SIG_IGN)

    test("brokenPipeExitStatus is 141 (128 + SIGPIPE)") {
        try assertEqual(brokenPipeExitStatus, 141,
            "UNIX convention: 128 + signal number, SIGPIPE is 13")
    }

    test("writeTolerantly reports failure on a pipe whose reader is gone (#389)") {
        // The real mechanism, not a stand-in: a pipe with a closed read end is
        // exactly what `| head -1` leaves behind.
        let pipe = Pipe()
        try pipe.fileHandleForReading.close()
        let ok = writeTolerantly("data after the reader left\n",
                                 to: pipe.fileHandleForWriting)
        try assertFalse(ok, "a write to a pipe with no reader must report failure")
    }

    test("writeTolerantly reports success on a live pipe (#389)") {
        let pipe = Pipe()
        let ok = writeTolerantly("hello", to: pipe.fileHandleForWriting)
        try assertTrue(ok, "a write to a pipe with a live reader must succeed")
        try pipe.fileHandleForWriting.close()
        let read = pipe.fileHandleForReading.readDataToEndOfFile()
        try assertEqual(String(decoding: read, as: UTF8.self), "hello",
            "the bytes must actually reach the reader")
    }

    test("writeTolerantly does not raise on a closed handle (#389)") {
        // The regression itself: this call used to abort the process with an
        // uncatchable NSFileHandleOperationException. Reaching the next line
        // at all is the assertion.
        let pipe = Pipe()
        try pipe.fileHandleForReading.close()
        for _ in 0..<3 {
            _ = writeTolerantly("x", to: pipe.fileHandleForWriting)
        }
        try assertTrue(true, "three writes to a dead pipe returned normally")
    }
}
