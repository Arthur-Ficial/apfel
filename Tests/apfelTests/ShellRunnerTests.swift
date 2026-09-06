// ============================================================================
// ShellRunnerTests.swift - Unit tests for shellOutput (pipe deadlock fix, #433)
// ============================================================================

import Foundation
import ApfelCLI

func runShellRunnerTests() {

    test("successful command returns stdout") {
        let result = shellOutput("/bin/echo", args: ["hello"])
        try assertEqual(result, "hello\n")
    }

    test("successful command with no output returns empty string") {
        let result = shellOutput("/usr/bin/true", args: [])
        try assertNotNil(result)
        try assertEqual(result!, "")
    }

    test("non-zero exit returns nil") {
        let result = shellOutput("/usr/bin/false", args: [])
        try assertNil(result)
    }

    test("missing executable returns nil") {
        let result = shellOutput("/nonexistent/binary/path", args: [])
        try assertNil(result)
    }

    test("output beyond pipe buffer does not deadlock") {
        // 128 KiB exceeds the typical 64 KiB pipe buffer. With the old
        // wait-before-read ordering this would hang forever.
        let result = shellOutput("/bin/dd", args: ["if=/dev/zero", "bs=131072", "count=1"])
        try assertNotNil(result)
        try assertEqual(result!.utf8.count, 131072)
    }
}
