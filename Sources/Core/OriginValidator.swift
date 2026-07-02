// ============================================================================
// OriginValidator.swift - Localhost CSRF protection logic
// Part of apfel - Apple Intelligence from the command line
// ============================================================================

/// Pure validation logic for origin checking and token authentication.
/// Lives in ApfelCore so it's unit-testable without Hummingbird.
public enum OriginValidator {

    /// Default allowed origins - localhost patterns only.
    public static let defaultAllowedOrigins = [
        "http://127.0.0.1",
        "http://localhost",
        "http://[::1]"
    ]

    /// Check if a request should be allowed based on its Origin header.
    ///
    /// - No Origin header (nil) = non-browser client (curl, SDK) = always allow
    /// - Wildcard "*" in allowed list = allow everything
    /// - Otherwise, origin must match an entry (exact or port variant)
    public static func isAllowed(origin: String?, allowedOrigins: [String]) -> Bool {
        guard let origin else { return true }

        if allowedOrigins.contains("*") { return true }

        for pattern in allowedOrigins {
            if matches(origin: origin, pattern: pattern) { return true }
        }

        // Also check https variants of the allowed origins
        for pattern in allowedOrigins {
            let httpsPattern: String
            if pattern.hasPrefix("http://") {
                httpsPattern = "https://" + pattern.dropFirst(7)
            } else {
                continue
            }
            if matches(origin: origin, pattern: httpsPattern) { return true }
        }

        return false
    }

    /// Check if a provided token matches the expected token.
    ///
    /// - No expected token (nil) = auth not required = always valid
    /// - Accepts both "Bearer <token>" and bare "<token>" formats
    public static func isValidToken(provided: String?, expected: String?) -> Bool {
        guard let expected else { return true }
        guard let provided, !provided.isEmpty else { return false }

        let token: String
        if provided.hasPrefix("Bearer ") {
            token = String(provided.dropFirst(7))
        } else {
            token = provided
        }
        return !token.isEmpty && constantTimeEqual(token, expected)
    }

    // MARK: - Private

    /// Constant-time string comparison to prevent timing side-channel attacks.
    /// XOR-accumulates over the longer of the two byte arrays; the loop length
    /// and the length-mismatch flag are folded into the result without early return.
    private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        var result: UInt8 = aBytes.count == bBytes.count ? 0 : 1
        let count = max(aBytes.count, bBytes.count)
        for i in 0..<count {
            let aByte: UInt8 = i < aBytes.count ? aBytes[i] : 0
            let bByte: UInt8 = i < bBytes.count ? bBytes[i] : 0
            result |= aByte ^ bByte
        }
        return result == 0
    }

    /// Match origin against pattern. Allows exact match or port variants.
    /// Guards against subdomain attacks: "http://localhost.evil.com" must NOT match "http://localhost".
    private static func matches(origin: String, pattern: String) -> Bool {
        if origin == pattern { return true }
        // Port variant: origin is pattern + ":" + port number
        if origin.hasPrefix(pattern + ":") { return true }
        return false
    }
}
