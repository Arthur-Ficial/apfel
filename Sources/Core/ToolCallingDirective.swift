// ============================================================================
// ToolCallingDirective.swift - the pure tool_choice -> generation-directive
// mapping behind macOS 27's GenerationOptions.ToolCallingMode (#510, #197).
// Part of ApfelCore - pure Swift, no FoundationModels, no availability checks.
//
// The main target applies the directive to GenerationOptions under
// #available(macOS 27, *) (Sources/ToolCallingSupport.swift); macOS 26 has
// no such mode and keeps today's behavior untouched.
//
// Why `required` and named functions map to `.allowed`, not the SDK's
// `.required` (measured on macOS 27.0.1, M2, 2026-10-05): apfel's tool
// calling is out-of-band (#119) - tools reach the model only as
// Transcript.Instructions.toolDefinitions plus prompt text, never as
// registered FoundationModels.Tool implementations. With that setup,
// `toolCallingMode = .required` made the runtime throw LanguageModelError
// "An unsupported generation guide was used" on 10/10 seeded requests
// (greeting prompt, multiply tool), while apfel's existing prompt steering +
// ToolPolicy enforcement satisfied tool_choice "required" on 10/10 of the
// same requests. The SDK mode would replace a working contract with a
// guaranteed error, so the prompt-side steering stays the enforcement path
// on every OS. There is also no per-tool mode in the SDK, so a named
// tool_choice uses the same steering plus ToolPolicy's name check.
// ============================================================================

/// What macOS 27's generation options should say about tool calling for one
/// request. `nil` from `resolve` means "leave the options untouched" - the
/// request has no tools, so its GenerationOptions must stay byte-identical
/// to a plain request.
public enum ToolCallingDirective: String, Sendable, Equatable {
    /// The model may call the tools in scope or answer in plain text.
    /// Also the honest mapping for `required` and named choices - see the
    /// header for the measurement that rules out the SDK's `.required`.
    case allowed
    /// The model must not call tools (`tool_choice: none`). A runtime
    /// backstop on top of apfel already stripping the tool definitions and
    /// instructions from the prompt.
    case disallowed

    /// Resolve the directive for one request.
    ///
    /// - Parameters:
    ///   - toolChoice: the decoded `tool_choice`, `nil` when omitted.
    ///   - toolsInScope: whether any tool reaches the model (client `tools`
    ///     or server-attached MCP tools, after `ToolPolicy` scoping).
    public static func resolve(toolChoice: ToolChoice?, toolsInScope: Bool) -> ToolCallingDirective? {
        switch toolChoice {
        case .some(ToolChoice.none):
            return .disallowed
        case .some(.invalid):
            // The validator 400s invalid choices before generation; never
            // steer the runtime from an undecodable value.
            return nil
        case .some(.auto), .some(.required), .some(.specific), Optional<ToolChoice>.none:
            return toolsInScope ? .allowed : nil
        }
    }
}
