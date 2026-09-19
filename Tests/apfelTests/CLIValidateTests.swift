// ============================================================================
// CLIValidateTests.swift - Unit tests for CLIArguments.validate(context:).
//
// validate() is the post-parse semantic check phase. parse() populates a
// CLIArguments struct syntactically; validate() runs cross-flag invariants
// (currently just mode-conflict detection, more in the future). Tests here
// exercise validate() directly on hand-built CLIArguments + ValidationContext
// values without going through parse().
//
// The end-to-end mode-conflict tests that call parse(["--chat", "--serve"])
// live in CLIArgumentsTests.swift and are unchanged by PR #2 - parse() still
// throws the same error via its internal validate() call.
// ============================================================================

import Foundation
import ApfelCLI

func runCLIValidateTests() {

    // -- ValidationContext construction --

    test("ValidationContext default-inits empty") {
        let ctx = ValidationContext()
        try assertEqual(ctx.modeFlagsSeen.count, 0)
    }

    test("ValidationContext can be constructed with a non-empty flag list") {
        let ctx = ValidationContext(modeFlagsSeen: ["--chat"])
        try assertEqual(ctx.modeFlagsSeen, ["--chat"])
    }

    // -- validate() clean cases --

    test("validate() returns cleanly for empty context") {
        var a = CLIArguments(); try a.validate()
    }

    test("validate() returns cleanly for context with default init") {
        var a = CLIArguments(); try a.validate(context: .init())
    }

    test("validate() returns cleanly for single mode flag seen") {
        var a = CLIArguments(); try a.validate(context: .init(modeFlagsSeen: ["--chat"]))
    }

    test("validate() returns cleanly for any single-mode variant") {
        for flag in ["--chat", "--serve", "--stream", "--benchmark", "--model-info", "--update"] {
            var a = CLIArguments(); try a.validate(context: .init(modeFlagsSeen: [flag]))
        }
    }

    // -- validate() throws on mode conflicts --

    test("validate() throws on two mode flags seen") {
        do {
            var a = CLIArguments(); try a.validate(context: .init(modeFlagsSeen: ["--chat", "--serve"]))
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
            try assertTrue(e.message.contains("--chat"))
            try assertTrue(e.message.contains("--serve"))
        }
    }

    test("validate() error preserves flag order (first two win)") {
        do {
            var a = CLIArguments(); try a.validate(context: .init(modeFlagsSeen: ["--chat", "--serve", "--benchmark"]))
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--chat"))
            try assertTrue(e.message.contains("--serve"))
            // The third flag "--benchmark" is NOT mentioned in the error.
            // First-two-wins mirrors the pre-refactor behavior.
            try assertTrue(!e.message.contains("--benchmark"))
        }
    }

    test("validate() throws modeConflict via CLIErrors template") {
        // The error should match the exact wording produced by
        // CLIErrors.modeConflict, confirming validate() reuses the same
        // helper as the in-parse flow.
        do {
            var a = CLIArguments(); try a.validate(context: .init(modeFlagsSeen: ["--serve", "--chat"]))
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            let expected = CLIErrors.modeConflict("--serve", "--chat").message
            try assertEqual(e.message, expected)
        }
    }

    // -- validate() silent-drop guard (#370 audit): input-ignoring modes --

    test("validate() rejects a positional prompt in serve mode") {
        var a = CLIArguments(); a.mode = .serve; a.prompt = "hello"
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("positional prompt")) }
    }

    test("validate() rejects -f file content in benchmark mode") {
        var a = CLIArguments(); a.mode = .benchmark; a.fileContents = ["some file"]
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("file")) }
    }

    test("validate() rejects -s/--system in serve mode") {
        var a = CLIArguments(); a.mode = .serve; a.systemPrompt = "be terse"
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("system")) }
    }

    test("validate() rejects generation tuning in model-info mode") {
        var a = CLIArguments(); a.mode = .modelInfo; a.temperature = 0.5
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("temperature")) }
    }

    test("validate() rejects --seed in update mode") {
        var a = CLIArguments(); a.mode = .update; a.seed = 7
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("seed")) }
    }

    test("validate() rejects --context-status outside chat") {
        var a = CLIArguments(); a.mode = .single; a.contextStatus = true
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("context-status")) }
    }

    // -- validate() still allows the legitimate combinations --

    test("validate() allows --context-status in chat mode") {
        var a = CLIArguments(); a.mode = .chat; a.contextStatus = true
        try a.validate()
    }

    test("validate() allows serve mode with server-consumed flags") {
        var a = CLIArguments(); a.mode = .serve; a.permissive = true; a.retryEnabled = true
        try a.validate()
    }

    test("validate() still allows a prompt and tuning in single mode") {
        var a = CLIArguments(); a.mode = .single; a.prompt = "hello"; a.temperature = 0.5; a.seed = 3
        try a.validate()
    }

    // -- parse() end-to-end still works: parse() should internally invoke validate() --

    test("parse() still throws on mode conflicts (parse internally calls validate)") {
        do {
            _ = try CLIArguments.parse(["--chat", "--serve"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("cannot combine"))
        }
    }

    test("parse() accepts a single mode flag without throwing") {
        let args = try CLIArguments.parse(["--chat"])
        try assertEqual(args.mode, .chat)
    }

    // -- #496: env-sourced fields downgrade to warning in input-ignoring modes --

    test("validate() warns instead of throwing for env-sourced systemPrompt in serve mode") {
        var a = CLIArguments()
        a.mode = .serve
        a.systemPrompt = "be terse"
        a.envSourcedFields.insert("systemPrompt")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_SYSTEM_PROMPT") && $0.contains("--serve") })
        try assertNil(a.systemPrompt)
    }

    test("validate() warns instead of throwing for env-sourced temperature in serve mode") {
        var a = CLIArguments()
        a.mode = .serve
        a.temperature = 0.5
        a.envSourcedFields.insert("temperature")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_TEMPERATURE") && $0.contains("--serve") })
        try assertNil(a.temperature)
    }

    test("validate() warns instead of throwing for env-sourced contextOutputReserve in serve mode") {
        var a = CLIArguments()
        a.mode = .serve
        a.contextOutputReserve = 1024
        a.envSourcedFields.insert("contextOutputReserve")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_CONTEXT_OUTPUT_RESERVE") && $0.contains("--serve") })
        try assertNil(a.contextOutputReserve)
    }

    test("validate() warns instead of throwing for env-sourced maxTokens in benchmark mode") {
        var a = CLIArguments()
        a.mode = .benchmark
        a.maxTokens = 512
        a.envSourcedFields.insert("maxTokens")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_MAX_TOKENS") && $0.contains("--benchmark") })
        try assertNil(a.maxTokens)
    }

    test("validate() warns instead of throwing for env-sourced contextStrategy in model-info mode") {
        var a = CLIArguments()
        a.mode = .modelInfo
        a.contextStrategy = .newestFirst
        a.envSourcedFields.insert("contextStrategy")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_CONTEXT_STRATEGY") && $0.contains("--model-info") })
        try assertNil(a.contextStrategy)
    }

    test("validate() warns instead of throwing for env-sourced contextMaxTurns in update mode") {
        var a = CLIArguments()
        a.mode = .update
        a.contextMaxTurns = 20
        a.envSourcedFields.insert("contextMaxTurns")
        try a.validate()
        try assertTrue(a.warnings.contains { $0.contains("APFEL_CONTEXT_MAX_TURNS") && $0.contains("--update") })
        try assertNil(a.contextMaxTurns)
    }

    test("validate() still throws for explicit flag in serve mode even when other fields are env-sourced") {
        var a = CLIArguments()
        a.mode = .serve
        a.temperature = 0.5
        // temperature is NOT in envSourcedFields - it came from --temperature
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("temperature")) }
    }

    test("validate() collects multiple env-sourced warnings in one pass") {
        var a = CLIArguments()
        a.mode = .serve
        a.systemPrompt = "be terse"
        a.temperature = 0.5
        a.contextOutputReserve = 1024
        a.envSourcedFields = ["systemPrompt", "temperature", "contextOutputReserve"]
        try a.validate()
        try assertEqual(a.warnings.count, 3)
        try assertNil(a.systemPrompt)
        try assertNil(a.temperature)
        try assertNil(a.contextOutputReserve)
    }

    test("validate() throws on explicit flag even when env-sourced fields precede it") {
        var a = CLIArguments()
        a.mode = .serve
        a.systemPrompt = "be terse"
        a.envSourcedFields.insert("systemPrompt")
        a.prompt = "hello"
        // prompt is never env-sourced - it's positional
        do { try a.validate(); try assertTrue(false, "should have thrown") }
        catch let e as CLIParseError { try assertTrue(e.message.contains("positional prompt")) }
    }

    // -- #496: parse() end-to-end env-sourced downgrade --

    test("parse() --serve with APFEL_CONTEXT_OUTPUT_RESERVE warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_CONTEXT_OUTPUT_RESERVE": "1024"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.contextOutputReserve)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_CONTEXT_OUTPUT_RESERVE") })
    }

    test("parse() --serve with APFEL_SYSTEM_PROMPT warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_SYSTEM_PROMPT": "be terse"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.systemPrompt)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_SYSTEM_PROMPT") })
    }

    test("parse() --serve with APFEL_TEMPERATURE warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_TEMPERATURE": "0.5"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.temperature)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_TEMPERATURE") })
    }

    test("parse() --serve with APFEL_MAX_TOKENS warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_MAX_TOKENS": "512"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.maxTokens)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_MAX_TOKENS") })
    }

    test("parse() --serve with APFEL_CONTEXT_STRATEGY warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_CONTEXT_STRATEGY": "newest-first"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.contextStrategy)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_CONTEXT_STRATEGY") })
    }

    test("parse() --serve with APFEL_CONTEXT_MAX_TURNS warns and clears (#496)") {
        let args = try CLIArguments.parse(["--serve"], env: ["APFEL_CONTEXT_MAX_TURNS": "20"])
        try assertEqual(args.mode, .serve)
        try assertNil(args.contextMaxTurns)
        try assertTrue(args.warnings.contains { $0.contains("APFEL_CONTEXT_MAX_TURNS") })
    }

    test("parse() --benchmark with multiple env defaults warns for each (#496)") {
        let args = try CLIArguments.parse(["--benchmark"], env: [
            "APFEL_SYSTEM_PROMPT": "be terse",
            "APFEL_TEMPERATURE": "0.7",
            "APFEL_CONTEXT_OUTPUT_RESERVE": "512",
        ])
        try assertEqual(args.mode, .benchmark)
        try assertNil(args.systemPrompt)
        try assertNil(args.temperature)
        try assertNil(args.contextOutputReserve)
        try assertEqual(args.warnings.count, 3)
    }

    test("parse() --serve still rejects explicit --temperature flag (#496 preserves #370)") {
        do {
            _ = try CLIArguments.parse(["--serve", "--temperature", "0.5"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("temperature"))
            try assertTrue(e.message.contains("--serve"))
        }
    }

    test("parse() --serve with explicit flag overriding env still rejects (#496)") {
        do {
            _ = try CLIArguments.parse(
                ["--serve", "--temperature", "0.5"],
                env: ["APFEL_TEMPERATURE": "0.3"]
            )
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("temperature"))
        }
    }

    test("parse() env-sourced fields are allowed in prompt modes (#496 regression)") {
        let args = try CLIArguments.parse(["hello"], env: [
            "APFEL_SYSTEM_PROMPT": "be terse",
            "APFEL_TEMPERATURE": "0.5",
            "APFEL_CONTEXT_OUTPUT_RESERVE": "1024",
        ])
        try assertEqual(args.mode, .single)
        try assertEqual(args.systemPrompt, "be terse")
        try assertEqual(args.temperature, 0.5)
        try assertEqual(args.contextOutputReserve, 1024)
        try assertEqual(args.warnings.count, 0)
    }
}
