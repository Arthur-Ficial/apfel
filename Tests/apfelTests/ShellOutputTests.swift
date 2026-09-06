// ============================================================================
// ShellOutputTests.swift - Unit tests for shellOutput() (#433)
//
// Verifies the pipe-before-wait ordering, non-zero exit handling, and
// missing-executable handling that the old private helper got wrong.
// ============================================================================

import Foundation
import ApfelCLI

func runShellOutputTests() {

    test("shellOutput returns stdout of a successful command") {
        let result = shellOutput("/bin/echo", args: ["hello"])
        try assertEqual(result, "hello\n")
    }

    test("shellOutput returns nil for a missing executable") {
        let result = shellOutput("/nonexistent/path/to/binary", args: [])
        try assertNil(result, "missing executable should return nil, not empty string")
    }

    test("shellOutput returns nil for a non-zero exit status") {
        let result = shellOutput("/usr/bin/false", args: [])
        try assertNil(result, "non-zero exit should return nil, not empty string")
    }

    test("shellOutput returns empty string for a command that produces no output") {
        let result = shellOutput("/usr/bin/true", args: [])
        try assertEqual(result, "", "successful empty output should be empty string, not nil")
    }

    test("shellOutput handles large output without deadlocking") {
        // Write 256 KiB via dd - well above the typical 64 KiB pipe buffer.
        // The old implementation would deadlock here because it called
        // waitUntilExit() before reading the pipe.
        let result = shellOutput("/bin/dd", args: ["if=/dev/zero", "bs=1024", "count=256", "status=none"])
        try assertNotNil(result, "large output must not deadlock")
        try assertEqual(result!.utf8.count, 256 * 1024, "expected 256 KiB of output")
    }

    test("shellOutput returns nil when executable exists but is not executable") {
        let result = shellOutput("/dev/null", args: [])
        try assertNil(result, "non-executable path should return nil")
    }
}
