// ============================================================================
// TokenCountFallback.swift — Why token counting fell back to chars/4 (ApfelCore)
// ============================================================================

import Foundation

/// Why the real `tokenCount(for:)` API was not used and token counts fell
/// back to the chars/4 approximation. Pure: callers supply the runtime facts
/// (OS capability and model availability), this type only decides and phrases
/// the reason. `nil` from `reason` means the real API is usable.
public enum TokenCountFallback: Sendable, Equatable {
    /// The running macOS is older than 26.4, which introduced
    /// `SystemLanguageModel.tokenCount(for:)`. The model itself may be
    /// fully available for generation (#315).
    case osTooOld(currentOS: String)
    /// The on-device model reports unavailable (Apple Intelligence disabled,
    /// device not eligible, model not ready).
    case modelUnavailable

    /// Decide the fallback reason from runtime facts. The OS check wins over
    /// model availability: on an old OS the real API does not exist at all,
    /// regardless of model state.
    public static func reason(
        modelAvailable: Bool,
        osSupportsTokenCounting: Bool,
        currentOS: String
    ) -> TokenCountFallback? {
        if !osSupportsTokenCounting { return .osTooOld(currentOS: currentOS) }
        if !modelAvailable { return .modelUnavailable }
        return nil
    }

    /// Human-readable explanation for the stderr warning.
    public var message: String {
        switch self {
        case .osTooOld(let currentOS):
            return "token count is approximate (the on-device tokenizer API requires macOS 26.4+; this Mac runs macOS \(currentOS); using chars/4 fallback)"
        case .modelUnavailable:
            return "token count is approximate (Apple Intelligence unavailable; using chars/4 fallback)"
        }
    }
}
