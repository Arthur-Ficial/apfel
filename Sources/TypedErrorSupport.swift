// ============================================================================
// TypedErrorSupport.swift - macOS 27 typed LanguageModelError classification
// (#510 item 4, #197).
//
// A binary linked against the macOS 27 SDK receives FoundationModels'
// typed `LanguageModelError` from the runtime on macOS 27. macOS 26 keeps
// throwing `GenerationError`, and a 26-SDK-linked binary running on 27
// receives a case-less `GenerationError` - both stay classified by
// ApfelCore's pure `ApfelError.classify` (mirror + keyword fallback,
// #181/#193), which also remains the fallback here for anything that is
// not a `LanguageModelError`. The availability decision is made HERE, once
// (same pattern as UsageAccounting.swift); the payload -> message mapping
// is pure ApfelCore (`ApfelError.contextWindowExceeded`,
// `.rateLimitedUntil`, `retryAfterSeconds(until:now:)`).
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

/// Classify any thrown error into a typed ApfelError, preferring macOS 27's
/// typed `LanguageModelError` cases over string matching. Every main-target
/// catch site uses this; ApfelCore-internal callers (retry banners) keep the
/// pure `ApfelError.classify`.
func classifyModelError(_ error: Error) -> ApfelError {
    if #available(macOS 27, *), let typed = error as? LanguageModelError {
        return classifyTypedError(typed)
    }
    return ApfelError.classify(error)
}

@available(macOS 27, *)
private func classifyTypedError(_ error: LanguageModelError) -> ApfelError {
    switch error {
    case .contextSizeExceeded(let payload):
        // The runtime's own numbers, never a hardcoded window (#330, #192).
        return .contextWindowExceeded(tokenCount: payload.tokenCount, contextSize: payload.contextSize)
    case .rateLimited(let payload):
        guard let resetDate = payload.resetDate else { return .rateLimited }
        return .rateLimitedUntil(retryAfterSeconds: ApfelError.retryAfterSeconds(until: resetDate))
    case .guardrailViolation:
        return .guardrailViolation
    case .refusal:
        return .refusal(error.localizedDescription)
    case .unsupportedGenerationGuide:
        return .unsupportedGuide
    case .unsupportedLanguageOrLocale:
        return .unsupportedLanguage(error.localizedDescription)
    case .unsupportedCapability, .unsupportedTranscriptContent, .timeout:
        // No dedicated ApfelError home (and none is invented for cases apfel
        // cannot trigger today): closest existing case, SDK message preserved.
        return .unknown(error.localizedDescription)
    @unknown default:
        return ApfelError.classify(error)
    }
}

/// Context-overflow error for apfel's own pre-generation budget check
/// (ContextManager): on macOS 27 it carries the counted input tokens and the
/// runtime window, matching the detail of the SDK's typed
/// `contextSizeExceeded`; on macOS 26 the message is byte-identical to
/// yesterday's generic `.contextOverflow`.
func contextOverflowError(tokenCount: Int, contextSize: Int) -> ApfelError {
    if #available(macOS 27, *) {
        return .contextWindowExceeded(tokenCount: tokenCount, contextSize: contextSize)
    }
    return .contextOverflow
}
