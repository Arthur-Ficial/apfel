// ============================================================================
// ToolCallingDirectiveTests.swift - pure tool_choice -> generation-directive
// mapping (#510 item 3, #197).
//
// The directive is apfel's OS-independent answer to "what should macOS 27's
// GenerationOptions.ToolCallingMode be for this request?". The main target
// applies it under #available(macOS 27, *); macOS 26 ignores it entirely.
//
// Deliberate mapping, measured on macOS 27.0.1 (M2, 2026-10-05):
//   - auto / omitted with tools in scope -> .allowed (the SDK default, set
//     explicitly so the debug trace names it).
//   - none                               -> .disallowed (runtime backstop on
//     top of apfel stripping the tools from the prompt).
//   - required / named function          -> .allowed, NOT the SDK's .required:
//     with transcript-only tool definitions (apfel's out-of-band Pattern B,
//     #119) the runtime throws LanguageModelError "unsupported generation
//     guide" on EVERY .required request (0/10 seeds survived). apfel's prompt
//     steering + ToolPolicy enforcement already satisfied tool_choice
//     "required" 10/10, so the SDK mode would only break what works.
//   - no tools in scope -> nil (GenerationOptions stays byte-identical to
//     the tool-free request apfel sent yesterday).
// ============================================================================

import Foundation
import ApfelCore

func runToolCallingDirectiveTests() {
    // MARK: - auto / omitted

    test("omitted tool_choice with tools in scope -> .allowed") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: nil, toolsInScope: true), .allowed)
    }
    test("tool_choice auto with tools in scope -> .allowed") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: .auto, toolsInScope: true), .allowed)
    }
    test("omitted tool_choice without tools -> nil (options untouched)") {
        try assertNil(ToolCallingDirective.resolve(toolChoice: nil, toolsInScope: false))
    }
    test("tool_choice auto without tools -> nil (options untouched)") {
        try assertNil(ToolCallingDirective.resolve(toolChoice: .auto, toolsInScope: false))
    }

    // MARK: - none

    test("tool_choice none -> .disallowed") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: ToolChoice.none, toolsInScope: false), .disallowed)
    }
    test("tool_choice none stays .disallowed even if tools were in scope") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: ToolChoice.none, toolsInScope: true), .disallowed)
    }

    // MARK: - required / named (the honest fallback, see header)

    test("tool_choice required -> .allowed, never the SDK's .required") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: .required, toolsInScope: true), .allowed)
    }
    test("named tool_choice -> .allowed (no per-tool mode in the SDK)") {
        try assertEqual(ToolCallingDirective.resolve(toolChoice: .specific(name: "multiply"), toolsInScope: true), .allowed)
    }
    test("named tool_choice with a non-ASCII case-changing name maps the same") {
        // "\u{1E9E}" (capital sharp s) and "\u{0130}" (dotted capital I):
        // the name must pass through untouched by any case fold.
        try assertEqual(
            ToolCallingDirective.resolve(toolChoice: .specific(name: "\u{1E9E}-rechner_\u{0130}"), toolsInScope: true),
            .allowed)
    }

    // MARK: - invalid (validator already rejected the request with a 400)

    test("invalid tool_choice -> nil (a 400 happened before generation)") {
        try assertNil(ToolCallingDirective.resolve(toolChoice: .invalid("sometimes"), toolsInScope: true))
    }

    // MARK: - raw values (used by the server debug trace)

    test("directive raw values name the SDK modes") {
        try assertEqual(ToolCallingDirective.allowed.rawValue, "allowed")
        try assertEqual(ToolCallingDirective.disallowed.rawValue, "disallowed")
    }
}
