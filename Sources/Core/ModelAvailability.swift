// ============================================================================
// ModelAvailability.swift - Pure enum mirroring the shape of
// SystemLanguageModel.Availability from FoundationModels.
//
// Living in ApfelCore (no FoundationModels import) so it's unit-testable
// from apfel-tests and reusable. TokenCounter.swift in the main target
// adapts the real Apple enum into this type.
// ============================================================================

import Foundation

/// The three unavailable reasons Apple's FoundationModels framework exposes,
/// plus an `available` case and an `unknown` fallback for forward-compatibility
/// if Apple adds new cases.
///
/// See:
/// https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason
public enum ModelAvailability: Sendable, Equatable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    case available
    case appleIntelligenceNotEnabled
    case deviceNotEligible
    case modelNotReady
    case unknownUnavailable

    /// True when the model can handle requests right now.
    public var isAvailable: Bool {
        self == .available
    }

    /// Short machine-friendly label. Used by `--model-info` and the
    /// `/health` endpoint for stable programmatic consumption.
    public var shortLabel: String {
        switch self {
        case .available:                  return "yes"
        case .appleIntelligenceNotEnabled: return "no (Apple Intelligence not enabled)"
        case .deviceNotEligible:          return "no (device not eligible)"
        case .modelNotReady:              return "no (model not ready - still downloading?)"
        case .unknownUnavailable:         return "no (unknown reason)"
        }
    }

    /// Multi-line actionable remediation text. Used by `apfel --model-info`
    /// and the runtime "model unavailable" error to point the user at the
    /// exact fix for their situation.
    public var remediation: String {
        switch self {
        case .available:
            return "Model is ready for requests."
        case .appleIntelligenceNotEnabled:
            return """
                Apple Intelligence is not turned on for this Mac.

                Fix:
                  1. Open System Settings > Apple Intelligence & Siri
                  2. Turn Apple Intelligence ON
                  3. Ensure Device Language and Siri Language are set to the
                     SAME supported language (English, Danish, Dutch, French,
                     German, Italian, Norwegian, Portuguese, Spanish, Swedish,
                     Turkish, Chinese (Simplified), Chinese (Traditional),
                     Japanese, Korean, or Vietnamese)
                  4. Wait for the on-device model to download (~3-4 GB, keep
                     your Mac on Wi-Fi and power)

                Details: https://support.apple.com/en-us/121115
                """
        case .deviceNotEligible:
            return """
                This Mac is not eligible for Apple Intelligence.

                Apple Intelligence requires an Apple Silicon Mac (M1 or later).
                Intel Macs are not supported - this is a hard Apple requirement,
                not an apfel limitation.

                Details: https://support.apple.com/en-us/121115
                """
        case .modelNotReady:
            return """
                The on-device model is still downloading or not yet ready.

                Apple Intelligence models are ~3-4 GB and download in the
                background after you first enable the feature. Until the
                download completes, the model cannot answer prompts.

                Fix:
                  1. Keep your Mac on Wi-Fi and power
                  2. Check System Settings > Apple Intelligence & Siri for
                     download progress
                  3. Try again in a few minutes

                Details: https://support.apple.com/en-us/121115
                """
        case .unknownUnavailable:
            return """
                The Apple Intelligence model reported an unknown unavailable
                reason. Apple may have added a new case that this version of
                apfel does not recognize.

                Try:
                  - Updating apfel: brew upgrade apfel
                  - Checking System Settings > Apple Intelligence & Siri
                  - Filing an issue at
                    https://github.com/Arthur-Ficial/apfel/issues
                """
        }
    }

    public var description: String { shortLabel }

    public var debugDescription: String {
        switch self {
        case .available:
            return "ModelAvailability.available"
        case .appleIntelligenceNotEnabled:
            return "ModelAvailability.appleIntelligenceNotEnabled"
        case .deviceNotEligible:
            return "ModelAvailability.deviceNotEligible"
        case .modelNotReady:
            return "ModelAvailability.modelNotReady"
        case .unknownUnavailable:
            return "ModelAvailability.unknownUnavailable"
        }
    }
}
