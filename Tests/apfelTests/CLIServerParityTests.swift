// ============================================================================
// CLIServerParityTests.swift — Asserts CLI and server stay in lock-step
// for shared policy decisions (defaults, flag wiring).
// Source-level checks: if anyone removes a parity wiring on one side, this
// fails. Behavioural checks live in the integration suite.
// ============================================================================

import Foundation
import ApfelCore

func runCLIServerParityTests() {
    let mainSrc = (try? String(contentsOfFile: "Sources/main.swift", encoding: .utf8)) ?? ""
    let handlersSrc = (try? String(contentsOfFile: "Sources/Handlers.swift", encoding: .utf8)) ?? ""
    let serverSrc = (try? String(contentsOfFile: "Sources/Server.swift", encoding: .utf8)) ?? ""

    test("max_tokens fallback: CLI references the SSOT constant") {
        try assertTrue(mainSrc.contains("?? BodyLimits.defaultMaxResponseTokens"),
                       "Sources/main.swift must apply BodyLimits.defaultMaxResponseTokens as the fallback (parity with server)")
    }

    test("max_tokens fallback: server references the SSOT constant") {
        try assertTrue(handlersSrc.contains("?? BodyLimits.defaultMaxResponseTokens"),
                       "Sources/Handlers.swift must apply BodyLimits.defaultMaxResponseTokens as the fallback (parity with CLI)")
    }

    test("permissive: ServerConfig declares the field") {
        try assertTrue(serverSrc.contains("let permissive: Bool"),
                       "Sources/Server.swift ServerConfig must declare 'let permissive: Bool' so --permissive flows through")
    }

    test("permissive: main.swift wires --permissive into ServerConfig") {
        try assertTrue(mainSrc.contains("permissive: parsed.permissive"),
                       "Sources/main.swift must pass parsed.permissive into ServerConfig (apfel --serve --permissive)")
    }

    test("permissive: handler reads from ServerConfig, not hard-coded false") {
        try assertTrue(handlersSrc.contains("permissive: serverState.config.permissive"),
                       "Sources/Handlers.swift must read permissive from ServerConfig, not hard-code false")
        try assertTrue(!handlersSrc.contains("        permissive: false,"),
                       "Sources/Handlers.swift must NOT hard-code 'permissive: false,' anywhere")
    }
}
