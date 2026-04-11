// ============================================================================
// CLIErrorsTests.swift - Unit tests for the CLIErrors template helpers.
// These helpers replace 22 hand-written CLIParseError strings in
// CLIArguments.swift with 5 reusable templates. Tests here verify the
// template output shape. Tests in CLIArgumentsTests.swift verify the
// helpers are actually wired in at the 22 call sites.
// ============================================================================

import Foundation
import ApfelCLI

func runCLIErrorsTests() {

    // -- requiresValue --

    test("requiresValue returns CLIParseError with flag name and 'requires'") {
        let err = CLIErrors.requiresValue("--system")
        try assertTrue(err.message.contains("--system"))
        try assertTrue(err.message.contains("requires"))
    }

    test("requiresValue with hint appends the hint in parentheses") {
        let err = CLIErrors.requiresValue("--output", hint: "plain or json")
        try assertTrue(err.message.contains("--output"))
        try assertTrue(err.message.contains("requires"))
        try assertTrue(err.message.contains("plain or json"))
    }

    test("requiresValue without hint has no parentheses") {
        let err = CLIErrors.requiresValue("--host")
        try assertTrue(!err.message.contains("("))
    }

    // -- invalidValue --

    test("invalidValue preserves the bad value, kind, and 'unknown'") {
        let err = CLIErrors.invalidValue(got: "xml", kind: "output format", hint: "use plain or json")
        try assertTrue(err.message.contains("unknown output format"))
        try assertTrue(err.message.contains("xml"))
    }

    test("invalidValue includes the hint") {
        let err = CLIErrors.invalidValue(got: "bogus", kind: "strategy", hint: "newest-first|oldest-first|sliding-window|summarize|strict")
        try assertTrue(err.message.contains("bogus"))
        try assertTrue(err.message.contains("newest-first"))
    }

    // -- unknownOption --

    test("unknownOption contains 'unknown option' and the flag name") {
        let err = CLIErrors.unknownOption("--nonexistent")
        try assertTrue(err.message.contains("unknown option"))
        try assertTrue(err.message.contains("--nonexistent"))
    }

    // -- modeConflict --

    test("modeConflict contains 'cannot combine' and both flags") {
        let err = CLIErrors.modeConflict("--chat", "--serve")
        try assertTrue(err.message.contains("cannot combine"))
        try assertTrue(err.message.contains("--chat"))
        try assertTrue(err.message.contains("--serve"))
    }

    test("modeConflict preserves flag order in the message") {
        let err = CLIErrors.modeConflict("--serve", "--chat")
        let msg = err.message
        // "--serve" comes before "--chat" in the message
        if let serveRange = msg.range(of: "--serve"),
           let chatRange = msg.range(of: "--chat") {
            try assertTrue(serveRange.lowerBound < chatRange.lowerBound)
        } else {
            try assertTrue(false, "one of the flag names was missing from the message")
        }
    }

    // -- fileReadError --

    test("fileReadError contains the path") {
        let err = CLIErrors.fileReadError(path: "missing.txt", reason: "no such file")
        try assertTrue(err.message.contains("missing.txt"))
    }

    test("fileReadError contains the reason text") {
        let err = CLIErrors.fileReadError(path: "binary.dat", reason: "cannot attach binary file")
        try assertTrue(err.message.contains("cannot attach binary file"))
        try assertTrue(err.message.contains("binary.dat"))
    }

    // -- type check: all helpers return CLIParseError --

    test("all CLIErrors helpers return CLIParseError type") {
        let a: CLIParseError = CLIErrors.requiresValue("--foo")
        let b: CLIParseError = CLIErrors.invalidValue(got: "x", kind: "foo kind", hint: "y")
        let c: CLIParseError = CLIErrors.unknownOption("--foo")
        let d: CLIParseError = CLIErrors.modeConflict("--a", "--b")
        let e: CLIParseError = CLIErrors.fileReadError(path: "p", reason: "r")
        // If this compiles and each value is non-empty, we are done.
        try assertTrue(!a.message.isEmpty)
        try assertTrue(!b.message.isEmpty)
        try assertTrue(!c.message.isEmpty)
        try assertTrue(!d.message.isEmpty)
        try assertTrue(!e.message.isEmpty)
    }
}
