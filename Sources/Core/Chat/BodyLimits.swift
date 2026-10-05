// ============================================================================
// BodyLimits.swift — Named server resource limits
// ============================================================================

import Foundation

package enum BodyLimits {
    /// Cap on the size of a decoded HTTP request body (1 MiB).
    /// Prevents OOM from a malicious or misconfigured client.
    public static let maxRequestBodyBytes: Int = 1024 * 1024

    /// Request body cap when image input is accepted (macOS 27, #510):
    /// room for one full-size 20 MB base64 image (`ImageInput.maxBase64Bytes`)
    /// plus JSON overhead. The main target picks this or
    /// `maxRequestBodyBytes` based on the runtime; macOS 26 keeps 1 MiB.
    public static let visionMaxRequestBodyBytes: Int = 24 * 1024 * 1024

    /// Tokens reserved for the model's response when fitting the prompt
    /// into the 4096-token context window.
    public static let defaultOutputReserveTokens: Int = 512

    // No fallback for max_tokens lives here on purpose. Omitted max_tokens
    // flows through as nil; FoundationModels uses whatever room is left in
    // the 4096-token window. Output-side overflow is handled by
    // StreamErrorResolver as finish_reason: "length", so no arbitrary cap
    // is needed. Drop-in OpenAI semantics, full window utilisation.

    /// Vestigial in v1.3.3+. Omitted max_tokens now flows through as nil and
    /// FoundationModels uses the remaining context window; this constant is
    /// no longer consulted anywhere in the codebase. Kept solely for ApfelCore
    /// API stability for one release, slated for removal in 2.0.0.
    @available(*, deprecated, message: "No longer used. Omitted max_tokens flows through as nil; FoundationModels uses the remaining 4096-token context window. Output-side overflow is surfaced as finish_reason: \"length\". Will be removed in 2.0.0.")
    public static let defaultMaxResponseTokens: Int = 0
}
