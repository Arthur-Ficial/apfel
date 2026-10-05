// ============================================================================
// ModelCapability.swift — capability wire names + report (#510)
//
// macOS 27's FoundationModels reports what the on-device model can do
// (LanguageModelCapabilities); macOS 26 reports nothing. This file is the
// pure mapping: stable snake_case wire names and a report that carries
// whether the OS reported at all - mirroring the context_window_measured
// pattern (#491) so clients can feature-detect instead of guessing.
// The availability-gated read lives in the main target.
// ============================================================================

/// One capability of the on-device model, named as it appears on the wire.
public enum ModelCapability: String, CaseIterable, Sendable, Equatable, Hashable {
    case vision
    case toolCalling = "tool_calling"
    case guidedGeneration = "guided_generation"
    case reasoning
}

/// The model's reported capabilities, or the honest "this macOS does not
/// report capabilities" marker for macOS 26.
public struct CapabilitiesReport: Sendable, Equatable, Hashable {
    /// Snake_case capability names, in reporting order. Empty when nothing
    /// was reported (`reported == false`) or the model reported none.
    public let names: [String]
    /// False when the OS has no capability-reporting API (macOS 26).
    public let reported: Bool

    /// A report built from actually-read capabilities (macOS 27+).
    public init(capabilities: [ModelCapability]) {
        self.names = capabilities.map(\.rawValue)
        self.reported = true
    }

    private init(names: [String], reported: Bool) {
        self.names = names
        self.reported = reported
    }

    /// The marker for an OS that does not report capabilities.
    public static let notReported = CapabilitiesReport(names: [], reported: false)

    /// Rendering for `apfel --model-info`.
    public var displayText: String {
        guard reported else {
            return "not reported by this macOS (capability reporting requires macOS 27)"
        }
        return names.isEmpty ? "none reported" : names.joined(separator: ", ")
    }
}
