// ============================================================================
// ToolCallingSupportTests.swift - how a ToolCallingDirective reaches macOS
// 27's GenerationOptions.toolCallingMode (Sources/Engine/ToolCallingSupport).
//
// `.allowed` must leave the runtime mode unset. apfel registers no
// FoundationModels.Tool (out-of-band tool calling, #119); with
// toolCallingMode = .allowed the macOS 27 runtime tries to parse the model's
// own tool-call tokens and throws "Failed to parse generated content" (an
// HTTP 500 for the client), measured on macOS 27.0.1 (M2, 2026-11-17).
// Left unset, the same requests never threw.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore
import ApfelEngine

func runToolCallingSupportTests() {
    test("an .allowed directive leaves macOS 27's toolCallingMode unset") {
        var options = GenerationOptions()
        applyToolCallingDirective(.allowed, to: &options)
        if #available(macOS 27, *) {
            try assertTrue(options.toolCallingMode == nil, "toolCallingMode must stay nil for .allowed")
        }
    }

    test("a .disallowed directive sets macOS 27's toolCallingMode to .disallowed") {
        var options = GenerationOptions()
        applyToolCallingDirective(.disallowed, to: &options)
        if #available(macOS 27, *) {
            try assertTrue(options.toolCallingMode == .disallowed, "tool_choice none keeps the runtime backstop")
        }
    }

    test("no directive leaves toolCallingMode unset") {
        var options = GenerationOptions()
        applyToolCallingDirective(nil, to: &options)
        if #available(macOS 27, *) {
            try assertTrue(options.toolCallingMode == nil)
        }
    }
}
