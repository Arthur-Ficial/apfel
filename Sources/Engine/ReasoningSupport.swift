// ============================================================================
// ReasoningSupport.swift - macOS 27 ContextOptions.reasoningLevel.
//
// The availability decision for the 27-only reasoning API is made HERE,
// once (same pattern as ToolCallingSupport.swift). Reasoning is additionally
// model-gated: `core3` rejects every level with "The selected model does not
// support reasoning" (probed 2026-11-02), so clients only pass an effort when
// `CapabilitiesReport` includes `reasoning` - which macOS 26 never reports,
// making the 26 fallback below unreachable in practice (kept honest: the
// request simply proceeds without a reasoning level there).
// ============================================================================

import FoundationModels
import ApfelCore

/// One text stream for a user turn, with the optional reasoning effort
/// applied where the OS supports it.
func makeTextStream(
    session: LanguageModelSession, prompt: Prompt, options: GenerationOptions,
    reasoning: EngineOptions.ReasoningEffort?
) -> LanguageModelSession.ResponseStream<String> {
    guard let reasoning else {
        return session.streamResponse(to: prompt, options: options)
    }
    if #available(macOS 27, *) {
        let level: ContextOptions.ReasoningLevel
        switch reasoning {
        case .light: level = .light
        case .moderate: level = .moderate
        case .deep: level = .deep
        }
        return session.streamResponse(
            to: prompt, options: options,
            contextOptions: ContextOptions(reasoningLevel: level))
    }
    return session.streamResponse(to: prompt, options: options)
}
