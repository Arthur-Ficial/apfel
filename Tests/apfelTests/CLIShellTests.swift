// ============================================================================
// CLIShellTests.swift - Unit tests for shellOutput (Sources/CLI/ShellRunner.swift)
//
// Covers the pipe-before-wait fix (#433): large output, non-zero exit, and
// missing-executable paths all return the correct result instead of deadlocking
// or silently swallowing failures.
// ============================================================================

import Foundation
import ApfelCLI

func runShellOutputTests() {

    test("successful command returns stdout") {
        let result = shellOutput("/bin/echo", args: ["hello"])
        try assertNotNil(result)
        try assertEqual(result?.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    test("non-zero exit returns nil") {
        let result = shellOutput("/usr/bin/false", args: [])
        try assertNil(result)
    }

    test("missing executable returns nil") {
        let result = shellOutput("/nonexistent/binary/path", args: [])
        try assertNil(result)
    }

    test("large output does not deadlock") {
        // 256 KiB of null bytes - well above the typical 64 KiB pipe buffer.
        // If readDataToEndOfFile ran after waitUntilExit, this would hang forever.
        let result = shellOutput("/usr/bin/head", args: ["-c", "262144", "/dev/zero"])
        try assertNotNil(result, "large stdout must not deadlock")
    }

    test("empty stdout from successful command returns empty string") {
        let result = shellOutput("/usr/bin/true", args: [])
        try assertNotNil(result)
        try assertEqual(result, "")
    }
}
