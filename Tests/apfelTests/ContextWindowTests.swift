// ============================================================================
// ContextWindowTests.swift — ContextWindow pure-type tests (#491)
// ============================================================================

import Foundation
import ApfelCore

func runContextWindowTests() {

    test("measured context window carries size and measured true") {
        let cw = ContextWindow(size: 8192, measured: true)
        try assertEqual(cw.size, 8192)
        try assertTrue(cw.measured)
    }

    test("assumed context window carries size and measured false") {
        let cw = ContextWindow(size: 4096, measured: false)
        try assertEqual(cw.size, 4096)
        try assertFalse(cw.measured)
    }

    test("equality compares both fields") {
        let a = ContextWindow(size: 4096, measured: true)
        let b = ContextWindow(size: 4096, measured: false)
        let c = ContextWindow(size: 4096, measured: true)
        try assertTrue(a == c)
        try assertTrue(a != b)
    }

    test("ContextWindow is Sendable") {
        let cw = ContextWindow(size: 4096, measured: false)
        let _: any Sendable = cw
        try assertTrue(true)
    }
}
