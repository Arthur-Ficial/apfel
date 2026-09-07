import Foundation
import ApfelCore

/// JSON nesting-depth cap on caller-supplied raw JSON (#462).
///
/// `AnyCodable.init(from:)` recurses once per level of nesting. The server
/// decodes request bodies on a cooperative-pool thread whose stack is far
/// smaller than the ~512-level limit Foundation's own JSON scanner enforces, so
/// depths in between passed the scanner and then exhausted the stack -- a
/// ~1.3 KB unauthenticated POST aborted the whole process with SIGBUS.
///
/// The subtlety these tests exist to pin: a bare depth `guard` is NOT enough.
/// `init(from:)` probes its container branches with `try?`, which swallows the
/// depth error, sets the subtree to `nil`, and answers 200 with the caller's
/// schema silently truncated. Stopping the crash is not the requirement;
/// rejecting the request is.
///
/// Asserted through `ChatCompletionRequest`, not `AnyCodable` directly:
/// `AnyCodable` is internal to ApfelCore and this target imports it without
/// `@testable`, so a test naming it would not compile.
func runNestingDepthTests() {

    /// `{"a":{"a":...1...}}` nested `depth` levels deep.
    func nestedJSON(depth: Int) -> String {
        String(repeating: #"{"a":"#, count: depth) + "1" + String(repeating: "}", count: depth)
    }

    func chatRequest(parameters: String) -> Data {
        Data("""
        {"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],
         "tools":[{"type":"function","function":{"name":"t","parameters":\(parameters)}}]}
        """.utf8)
    }

    test("deeply nested tool parameters are rejected, not silently truncated (#462)") {
        let body = chatRequest(parameters: nestedJSON(depth: 200))
        var threw = false
        do {
            _ = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        } catch is DecodingError {
            threw = true
        }
        try assertTrue(threw, """
            expected a DecodingError, but decoding SUCCEEDED. A bare depth guard \
            that lets the `try?` container probes swallow the error produces \
            exactly this: no crash, but 200 with the caller's schema truncated \
            to null. The request must be rejected (#462).
            """)
    }

    test("deeply nested response_format schema is rejected (#462)") {
        let deep = nestedJSON(depth: 200)
        let body = Data("""
        {"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],
         "response_format":{"type":"json_schema",
                            "json_schema":{"name":"s","schema":\(deep)}}}
        """.utf8)
        var threw = false
        do {
            _ = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        } catch is DecodingError {
            threw = true
        }
        try assertTrue(threw, "over-nested response_format schema must be rejected")
    }

    test("the depth failure is a DecodingError, so consumers still catch it (#462)") {
        // ApfelCore's stability contract: a malformed body surfaces as
        // DecodingError. A bespoke error type here would escape every
        // `catch is DecodingError` in a downstream consumer and in our own
        // handler, turning a 400 into a 500.
        let body = chatRequest(parameters: nestedJSON(depth: 200))
        do {
            _ = try JSONDecoder().decode(ChatCompletionRequest.self, from: body)
            try assertTrue(false, "should have thrown")
        } catch is DecodingError {
            try assertTrue(true)
        } catch {
            try assertTrue(false, "threw \(type(of: error)), not a DecodingError")
        }
    }

    test("a realistic JSON Schema still decodes (#462)") {
        // Ten levels is deeper than any schema we have ever seen in the wild;
        // the cap must not touch it.
        let body = chatRequest(parameters: nestedJSON(depth: 10))
        let decoded = try? JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        try assertNotNil(decoded, "a 10-level schema must still decode")
        try assertEqual(decoded?.tools?.first?.function.name, "t")
        try assertNotNil(decoded?.tools?.first?.function.parameters,
            "the schema must survive decoding, not be truncated to nil")
    }

    test("a schema exactly at the depth limit still decodes (#462)") {
        let body = chatRequest(parameters: nestedJSON(depth: 32))
        let decoded = try? JSONDecoder().decode(ChatCompletionRequest.self, from: body)
        try assertNotNil(decoded, "a 32-level schema is within the cap and must decode")
        try assertNotNil(decoded?.tools?.first?.function.parameters)
    }
}
