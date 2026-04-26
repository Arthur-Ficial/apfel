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

    /// Default cap applied when a client (server or CLI) omits max_tokens.
    /// 1024 covers typical structured JSON and short-to-medium replies while
    /// leaving 3072 tokens for input inside the 4096-token window.
    public static let defaultMaxResponseTokens: Int = 1024
}
