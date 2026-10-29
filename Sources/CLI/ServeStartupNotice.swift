// ============================================================================
// ServeStartupNotice.swift - stderr warning for `--serve` when the model is
// unavailable (pure, testable). Part of ApfelCLI.
//
// The server deliberately still starts: /health and /v1/models work without
// the model, and availability can flip to available while the process runs
// (e.g. the model finishes downloading). The notice makes the state loud at
// startup instead of surprising the first /v1/chat/completions client.
// ============================================================================

import ApfelCore

public enum ServeStartupNotice {

    /// The startup warning for the given availability, or nil when the model
    /// is available and no warning is needed.
    public static func message(availability: ModelAvailability) -> String? {
        guard !availability.isAvailable else { return nil }
        return """
        model unavailable: \(availability.shortLabel) — starting anyway.
        The server will answer /health and /v1/models, but completion requests will fail until the model is available.

        \(availability.remediation)
        """
    }
}
