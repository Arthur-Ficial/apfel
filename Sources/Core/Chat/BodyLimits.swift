// ============================================================================
// BodyLimits.swift — Named server resource limits
// ============================================================================

import Foundation

package enum BodyLimits {
    /// Cap on the size of a decoded HTTP request body (1 MiB).
    /// Prevents OOM from a malicious or misconfigured client.
    public static let maxRequestBodyBytes: Int = 1024 * 1024

    /// Tokens reserved for the model's response when fitting the prompt
    /// into the 4096-token context window.
    public static let defaultOutputReserveTokens: Int = 512

    // No fallback for max_tokens lives here on purpose. Omitted max_tokens
    // flows through as nil; FoundationModels uses whatever room is left in
    // the 4096-token window. Output-side overflow is handled by
    // StreamErrorResolver as finish_reason: "length", so no arbitrary cap
    // is needed. Drop-in OpenAI semantics, full window utilisation.
}
