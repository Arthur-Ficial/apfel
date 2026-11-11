// ============================================================================
// LogBodyTests.swift - --debug request-body capture is bounded (Fable F13)
// ============================================================================

import Foundation
import ApfelCore

func runLogBodyTests() {
    test("LogBody keeps a body under the limit unchanged") {
        try assertEqual(LogBody.truncatedUTF8(Array("{\"a\":1}".utf8), limit: 64), "{\"a\":1}")
    }

    test("LogBody truncates a large body and marks it") {
        let body = Array(String(repeating: "x", count: 100).utf8)
        let out = LogBody.truncatedUTF8(body, limit: 10)
        try assertTrue(out.hasPrefix("xxxxxxxxxx"), out)
        try assertTrue(out.contains("[truncated, 100 bytes total]"), out)
    }

    test("LogBody never fails on a cut inside a multi-byte character") {
        let body = Array("ab\u{00FC}cd".utf8)   // "ü" is two bytes; cut after its first byte
        let out = LogBody.truncatedUTF8(body, limit: 3)
        try assertTrue(out.hasPrefix("ab"), out)
    }

    test("LogBody default limit is 64 KiB") {
        try assertEqual(LogBody.defaultLimit, 64 * 1024)
    }
}
