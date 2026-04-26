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

    /// Default cap applied to model responses when neither the CLI nor the
    /// HTTP client provides max_tokens. Sized to cover typical short-to-medium
    /// chat replies and structured JSON output, while leaving 3072 tokens of
    /// the 4096-token context window for input.
    /// Read by both surfaces (CLI: main.swift, server: Handlers.swift) so the
    /// two stay in lock-step.
    public static let defaultMaxResponseTokens: Int = 1024
}
