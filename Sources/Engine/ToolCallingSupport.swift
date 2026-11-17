// ============================================================================
// ToolCallingSupport.swift - macOS 27 GenerationOptions.ToolCallingMode (#510)
//
// macOS 27's generation options can tell the runtime whether the model may
// (.allowed) or must not (.disallowed) call the tools presented through
// Transcript.Instructions.toolDefinitions; macOS 26 has no such mode. The
// availability decision is made HERE, once - the pure mapping from
// tool_choice to a ToolCallingDirective lives in ApfelCore
// (ToolCallingDirective.resolve), availability-free.
//
// The SDK's third mode, .required, is deliberately never set: with apfel's
// out-of-band tool calling (#119 - transcript tool definitions plus prompt
// steering, no registered FoundationModels.Tool implementations) the runtime
// threw LanguageModelError "An unsupported generation guide was used" on
// 10/10 seeded .required requests (macOS 27.0.1, M2, 2026-10-05), while the
// existing prompt steering + ToolPolicy enforcement satisfied tool_choice
// "required" on 10/10. See ToolCallingDirective's header for the mapping.
// ============================================================================

import FoundationModels
import ApfelCore

/// Apply a resolved tool-calling directive to the generation options.
/// No-op on macOS 26, for directive-free (tool-free) requests and for
/// `.allowed`; only `tool_choice: none` (`.disallowed`) sets the mode.
package func applyToolCallingDirective(_ directive: ToolCallingDirective?, to options: inout GenerationOptions) {
    guard let directive else { return }
    if #available(macOS 27, *) {
        switch directive {
        case .allowed:
            // Left unset on purpose. apfel registers no FoundationModels.Tool
            // (out-of-band calling, #119); with .allowed set explicitly the
            // macOS 27 runtime parses the model's own tool-call tokens and
            // throws "Failed to parse generated content" (5 of 120 tool
            // requests on 27.0.1, M2, 2026-11-17; 0 of 420 left unset). The
            // model may call tools either way: apfel steers it in the prompt.
            break
        case .disallowed:
            options.toolCallingMode = .disallowed
        }
    }
}
