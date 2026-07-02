// OriginValidatorTests — TDD tests for localhost CSRF protection
// Tests origin validation and token authentication logic

import ApfelCore

func runOriginValidatorTests() {
    let defaults = OriginValidator.defaultAllowedOrigins

    // MARK: - Default allowed origins

    test("defaultAllowedOrigins contains 3 entries") {
        try assertEqual(defaults.count, 3)
    }

    test("defaultAllowedOrigins contains http://127.0.0.1") {
        try assertTrue(defaults.contains("http://127.0.0.1"))
    }

    test("defaultAllowedOrigins contains http://localhost") {
        try assertTrue(defaults.contains("http://localhost"))
    }

    test("defaultAllowedOrigins contains http://[::1]") {
        try assertTrue(defaults.contains("http://[::1]"))
    }

    // MARK: - isAllowed: no Origin header (backward compat)

    test("nil origin is always allowed") {
        try assertTrue(OriginValidator.isAllowed(origin: nil, allowedOrigins: defaults))
    }

    test("nil origin allowed even with empty list") {
        try assertTrue(OriginValidator.isAllowed(origin: nil, allowedOrigins: []))
    }

    // MARK: - isAllowed: localhost origins (should pass)

    test("http://127.0.0.1 allowed with defaults") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://127.0.0.1", allowedOrigins: defaults))
    }

    test("http://localhost allowed with defaults") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://localhost", allowedOrigins: defaults))
    }

    test("http://[::1] allowed with defaults") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://[::1]", allowedOrigins: defaults))
    }

    test("http://localhost:3000 allowed (port variant)") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://localhost:3000", allowedOrigins: defaults))
    }

    test("http://127.0.0.1:5173 allowed (port variant)") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://127.0.0.1:5173", allowedOrigins: defaults))
    }

    test("http://[::1]:8080 allowed (port variant)") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://[::1]:8080", allowedOrigins: defaults))
    }

    test("https://localhost allowed (https variant)") {
        try assertTrue(OriginValidator.isAllowed(origin: "https://localhost", allowedOrigins: defaults))
    }

    test("https://127.0.0.1:3000 allowed (https + port)") {
        try assertTrue(OriginValidator.isAllowed(origin: "https://127.0.0.1:3000", allowedOrigins: defaults))
    }

    // MARK: - isAllowed: foreign origins (should be rejected)

    test("http://evil.com rejected with defaults") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://evil.com", allowedOrigins: defaults))
    }

    test("http://localhost.evil.com rejected (subdomain attack)") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://localhost.evil.com", allowedOrigins: defaults))
    }

    test("empty string rejected") {
        try assertTrue(!OriginValidator.isAllowed(origin: "", allowedOrigins: defaults))
    }

    test("http://192.168.1.1 rejected (not localhost)") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://192.168.1.1", allowedOrigins: defaults))
    }

    test("http://127.0.0.2 rejected (not 127.0.0.1)") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://127.0.0.2", allowedOrigins: defaults))
    }

    test("http://0.0.0.0 rejected") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://0.0.0.0", allowedOrigins: defaults))
    }

    // MARK: - isAllowed: custom allowed list

    test("custom origin allowed when in list") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://myapp.com", allowedOrigins: ["http://myapp.com"]))
    }

    test("custom origin with port allowed") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://myapp.com:443", allowedOrigins: ["http://myapp.com"]))
    }

    test("custom origin rejected when not in list") {
        try assertTrue(!OriginValidator.isAllowed(origin: "http://other.com", allowedOrigins: ["http://myapp.com"]))
    }

    // MARK: - isAllowed: wildcard

    test("wildcard allows everything") {
        try assertTrue(OriginValidator.isAllowed(origin: "http://anything.com", allowedOrigins: ["*"]))
    }

    test("wildcard allows empty string") {
        try assertTrue(OriginValidator.isAllowed(origin: "", allowedOrigins: ["*"]))
    }

    // MARK: - isValidToken: no auth required

    test("nil expected token always valid") {
        try assertTrue(OriginValidator.isValidToken(provided: nil, expected: nil))
    }

    test("nil expected token valid even with provided token") {
        try assertTrue(OriginValidator.isValidToken(provided: "Bearer abc", expected: nil))
    }

    // MARK: - isValidToken: auth required

    test("missing token rejected when required") {
        try assertTrue(!OriginValidator.isValidToken(provided: nil, expected: "secret123"))
    }

    test("wrong token rejected") {
        try assertTrue(!OriginValidator.isValidToken(provided: "Bearer wrong", expected: "secret123"))
    }

    test("correct Bearer token accepted") {
        try assertTrue(OriginValidator.isValidToken(provided: "Bearer secret123", expected: "secret123"))
    }

    test("bare token without Bearer prefix accepted") {
        try assertTrue(OriginValidator.isValidToken(provided: "secret123", expected: "secret123"))
    }

    test("empty token rejected when required") {
        try assertTrue(!OriginValidator.isValidToken(provided: "", expected: "secret123"))
    }

    test("Bearer with empty value rejected") {
        try assertTrue(!OriginValidator.isValidToken(provided: "Bearer ", expected: "secret123"))
    }

    // MARK: - isValidToken: constant-time comparison (#231)

    test("token differing only in last byte rejected (#231)") {
        try assertTrue(!OriginValidator.isValidToken(provided: "Bearer abcdef0", expected: "abcdef1"))
    }

    test("token differing only in first byte rejected (#231)") {
        try assertTrue(!OriginValidator.isValidToken(provided: "Bearer Xbcdefg", expected: "abcdefg"))
    }

    test("token with different length rejected (#231)") {
        try assertTrue(!OriginValidator.isValidToken(provided: "Bearer short", expected: "a-longer-token"))
    }

    test("UUID-format token accepted when matching (#231)") {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        try assertTrue(OriginValidator.isValidToken(provided: "Bearer \(uuid)", expected: uuid))
    }

    test("UUID-format token rejected when last digit differs (#231)") {
        try assertTrue(!OriginValidator.isValidToken(
            provided: "Bearer 550e8400-e29b-41d4-a716-446655440000",
            expected: "550e8400-e29b-41d4-a716-446655440001"
        ))
    }
}
