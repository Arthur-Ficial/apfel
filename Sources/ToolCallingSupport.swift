// ============================================================================
// ToolCallingSupport.swift — macOS 27 GenerationOptions.ToolCallingMode (#510)
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
/// No-op on macOS 26 and for directive-free (tool-free) requests, so those
/// options stay byte-identical to today's.
func applyToolCallingDirective(_ directive: ToolCallingDirective?, to options: inout GenerationOptions) {
    guard let directive else { return }
    if #available(macOS 27, *) {
        switch directive {
        case .allowed:
            options.toolCallingMode = .allowed
        case .disallowed:
            options.toolCallingMode = .disallowed
        }
    }
}
