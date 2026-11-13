// ============================================================================
// InputTokensCountTests.swift - POST /v1/responses/input_tokens (#485)
//
// Model-free coverage for the token preflight endpoint:
//   - the request contract (which Responses parameters count, which are
//     honest 501s or 400s),
//   - the wire report and the x_apfel extension,
//   - the overflow and tokenizer-unavailable errors (never an estimate),
//   - the Engine preflight driven by a scripted counter: zero generation,
//     zero tool execution, deterministic truncation, runtime context sizes,
//     and the same prepared input generation uses (schema + tool overhead).
// The scripted counter prices one character as one token so expectations are
// exact; no FoundationModels runtime or model is needed.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore
import ApfelEngine

/// Deterministic exact counter: 1 character of every text segment = 1 token,
/// plus 10 tokens per tool definition and 7 per prompt response format. It
/// records every call so tests can prove what the preflight asked for, and
/// can be told to fail on the Nth call (runtime tokenizer failure).
actor ScriptedExactCounter: ExactTranscriptCounter {
    private(set) var calls: [[Transcript.Entry]] = []
    private let failure: TokenCountingError?
    private let failOnCall: Int?

    init(failure: TokenCountingError? = nil, failOnCall: Int? = nil) {
        self.failure = failure
        self.failOnCall = failOnCall
    }

    func exactCount(entries: [Transcript.Entry]) async throws -> Int {
        calls.append(entries)
        if let failure, failOnCall == nil || failOnCall == calls.count {
            throw failure
        }
        return entries.reduce(0) { $0 + Self.price($1) }
    }

    var callCount: Int { calls.count }

    static func price(_ entry: Transcript.Entry) -> Int {
        func text(_ segments: [Transcript.Segment]) -> Int {
            segments.reduce(0) { total, seg in
                if case .text(let t) = seg { return total + t.content.count }
                return total
            }
        }
        switch entry {
        case .instructions(let i):
            return text(i.segments) + 10 * i.toolDefinitions.count
        case .prompt(let p):
            return text(p.segments) + (p.responseFormat == nil ? 0 : 7)
        case .response(let r):
            return text(r.segments)
        case .toolOutput(let o):
            return text(o.segments)
        case .toolCalls:
            return 5
        default:
            return 0
        }
    }
}

private func decodeResponses(_ json: String) throws -> ResponsesRequest {
    try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
}

private func validate(_ json: String) throws -> ResponsesInputTokensValidator.Failure? {
    let data = Data(json.utf8)
    let request = try JSONDecoder().decode(ResponsesRequest.self, from: data)
    return ResponsesInputTokensValidator.validate(
        request, presentKeys: ResponsesInputTokensValidator.topLevelKeys(of: data))
}

private func user(_ text: String) -> OpenAIMessage {
    OpenAIMessage(role: "user", content: .text(text))
}

private func assistant(_ text: String) -> OpenAIMessage {
    OpenAIMessage(role: "assistant", content: .text(text))
}

func runInputTokensCountTests() {

    // MARK: - Request contract

    test("input_tokens: plain string input with model is valid") {
        try assertNil(try validate(#"{"model":"apple-foundationmodel","input":"hi"}"#))
    }

    test("input_tokens: instructions, tools, tool_choice, text, truncation, parallel_tool_calls are counted parameters") {
        let body = """
        {"model":"apple-foundationmodel","input":"hi","instructions":"be brief",
         "tools":[{"type":"function","name":"add","parameters":{"type":"object","properties":{}}}],
         "tool_choice":"auto","text":{"format":{"type":"text"}},"truncation":"disabled",
         "parallel_tool_calls":true}
        """
        try assertNil(try validate(body))
    }

    test("input_tokens: generation-only parameter is a 400 naming the parameter") {
        for key in ["stream", "temperature", "top_p", "max_output_tokens", "metadata", "store", "background", "include"] {
            let value = key == "metadata" ? "{}" : (key == "include" ? "[]" : (key == "stream" || key == "store" || key == "background" ? "false" : "1"))
            let failure = try validate(#"{"model":"apple-foundationmodel","input":"hi","\#(key)":\#(value)}"#)
            guard case .unsupportedParameter(let name)? = failure else {
                throw TestFailure("\(key): expected unsupportedParameter, got \(String(describing: failure))")
            }
            try assertEqual(name, key)
            try assertEqual(failure!.httpStatusCode, 400)
            try assertEqual(failure!.errorParam, key)
            try assertTrue(failure!.message.contains("'\(key)'"))
            try assertTrue(failure!.message.contains("/v1/responses/input_tokens"))
        }
    }

    test("input_tokens: unknown parameter is a 400 too") {
        let failure = try validate(#"{"model":"apple-foundationmodel","input":"hi","frobnicate":1}"#)
        try assertEqual(failure, .unsupportedParameter("frobnicate"))
    }

    test("input_tokens: conversation is an honest 501 (stateless server)") {
        let failure = try validate(#"{"model":"apple-foundationmodel","input":"hi","conversation":"conv_1"}"#)
        try assertEqual(failure, .conversation)
        try assertEqual(failure!.httpStatusCode, 501)
        try assertTrue(failure!.message.contains("stateless"))
    }

    test("input_tokens: previous_response_id and reasoning reuse the Responses 501s") {
        let prev = try validate(#"{"model":"apple-foundationmodel","input":"hi","previous_response_id":"resp_1"}"#)
        try assertEqual(prev, .request(.unsupported("previous_response_id")))
        try assertEqual(prev!.httpStatusCode, 501)
        let reasoning = try validate(#"{"model":"apple-foundationmodel","input":"hi","reasoning":{"effort":"low"}}"#)
        try assertEqual(reasoning!.httpStatusCode, 501)
    }

    test("input_tokens: unknown model is a 404 model_not_found") {
        let failure = try validate(#"{"model":"gpt-4o","input":"hi"}"#)
        try assertEqual(failure!.httpStatusCode, 404)
        try assertEqual(failure!.errorCode, "model_not_found")
        try assertEqual(failure!.errorParam, "model")
    }

    test("input_tokens: missing input is a 400") {
        let failure = try validate(#"{"model":"apple-foundationmodel"}"#)
        try assertEqual(failure, .request(.missingInput))
    }

    test("input_tokens: image input is an honest 501, never a text-only count") {
        let body = """
        {"model":"apple-foundationmodel","input":[{"role":"user","content":[
          {"type":"input_text","text":"what is this"},
          {"type":"input_image","image_url":"data:image/png;base64,iVBORw0KGgo="}]}]}
        """
        let failure = try validate(body)
        try assertEqual(failure, .imageInput)
        try assertEqual(failure!.httpStatusCode, 501)
        try assertTrue(failure!.message.contains("image"))
    }

    test("input_tokens: file input part is rejected, never silently dropped") {
        let body = """
        {"model":"apple-foundationmodel","input":[{"role":"user","content":[
          {"type":"input_text","text":"read this"},{"type":"input_file","file_id":"file_1"}]}]}
        """
        let failure = try validate(body)
        try assertNotNil(failure)
        try assertTrue(failure!.message.contains("input_file"))
    }

    test("input_tokens: hosted tools are a 501 like /v1/responses") {
        let failure = try validate(#"{"model":"apple-foundationmodel","input":"hi","tools":[{"type":"web_search"}]}"#)
        try assertEqual(failure!.httpStatusCode, 501)
    }

    test("input_tokens: invalid truncation value is a 400 on param truncation") {
        let failure = try validate(#"{"model":"apple-foundationmodel","input":"hi","truncation":"middle"}"#)
        try assertEqual(failure!.httpStatusCode, 400)
        try assertEqual(failure!.errorParam, "truncation")
    }

    test("input_tokens: topLevelKeys reads the object's keys, empty for non-objects") {
        try assertEqual(ResponsesInputTokensValidator.topLevelKeys(of: Data(#"{"a":1,"b":{"c":2}}"#.utf8)), ["a", "b"])
        try assertEqual(ResponsesInputTokensValidator.topLevelKeys(of: Data("[1]".utf8)), [])
    }

    // MARK: - Truncation mode (shared with /v1/responses generation)

    test("truncation: auto (and absent) trims newest-first, disabled is strict") {
        try assertEqual(ResponsesTruncation(requestValue: nil), .auto)
        try assertEqual(ResponsesTruncation(requestValue: "auto"), .auto)
        try assertEqual(ResponsesTruncation(requestValue: "disabled"), .disabled)
        try assertEqual(ResponsesTruncation.auto.contextStrategy, .newestFirst)
        try assertEqual(ResponsesTruncation.disabled.contextStrategy, .strict)
        try assertEqual(ResponsesTruncation.auto.rawValue, "auto")
    }

    // MARK: - Removed input item mapping

    test("conversationInputIndices maps conversation turns back to input item indices") {
        let request = try decodeResponses("""
        {"model":"apple-foundationmodel","instructions":"x","input":[
          {"role":"developer","content":"rules"},
          {"role":"user","content":"a"},
          {"role":"assistant","content":"b"},
          {"role":"system","content":"more rules"},
          {"role":"user","content":"c"}]}
        """)
        try assertEqual(ResponsesMapper.conversationInputIndices(from: request), [1, 2, 4])
    }

    test("conversationInputIndices for string input is [0]") {
        let request = try decodeResponses(#"{"model":"apple-foundationmodel","input":"hello"}"#)
        try assertEqual(ResponsesMapper.conversationInputIndices(from: request), [0])
    }

    // MARK: - Wire report

    test("report: wire shape is the OpenAI object plus the x_apfel extension") {
        let report = InputTokensReport(
            inputTokens: 120, untrimmedInputTokens: 300,
            contextSize: 4096, contextSizeMeasured: true,
            outputReserve: 512, truncation: .auto, removedInputItems: [1, 2])
        let obj = try JSONSerialization.jsonObject(with: Data(report.jsonString.utf8)) as! [String: Any]
        try assertEqual(obj["object"] as? String, "response.input_tokens")
        try assertEqual(obj["input_tokens"] as? Int, 120)
        let ext = obj["x_apfel"] as! [String: Any]
        try assertEqual(ext["context_size"] as? Int, 4096)
        try assertEqual(ext["context_size_measured"] as? Bool, true)
        try assertEqual(ext["output_reserve"] as? Int, 512)
        try assertEqual(ext["input_budget"] as? Int, 3584)
        try assertEqual(ext["untrimmed_input_tokens"] as? Int, 300)
        try assertEqual(ext["input_tokens"] as? Int, 120)
        try assertEqual(ext["truncation"] as? String, "auto")
        try assertEqual(ext["fits"] as? Bool, true)
        try assertEqual(ext["trimmed"] as? Bool, true)
        try assertEqual(ext["removed_input_items"] as? [Int], [1, 2])
        try assertEqual(ext["tokenizer"] as? String, "apple-foundationmodels")
    }

    test("report: budget follows the runtime context size, no fixed window") {
        for size in [4096, 8192, 5000] {
            let report = InputTokensReport(
                inputTokens: 10, untrimmedInputTokens: 10, contextSize: size,
                contextSizeMeasured: true, outputReserve: 512, truncation: .disabled,
                removedInputItems: [])
            try assertEqual(report.inputBudget, size - 512)
            try assertEqual(report.trimmed, false)
        }
    }

    // MARK: - Errors: overflow and tokenizer unavailability

    test("overflow: disabled truncation names the counted input, budget and window") {
        let overflow = InputTokensOverflow(
            untrimmedInputTokens: 5000, contextSize: 4096, outputReserve: 512, truncation: .disabled)
        try assertEqual(overflow.httpStatusCode, 400)
        try assertEqual(overflow.code, "context_length_exceeded")
        try assertEqual(overflow.openAIType, "context_length_exceeded")
        try assertEqual(overflow.param, "input")
        try assertEqual(overflow.inputBudget, 3584)
        for needle in ["5000", "3584", "4096", "512", "disabled"] {
            try assertTrue(overflow.message.contains(needle), "message lacks \(needle): \(overflow.message)")
        }
    }

    test("overflow: auto truncation explains the input cannot fit even after trimming") {
        let overflow = InputTokensOverflow(
            untrimmedInputTokens: 9000, contextSize: 8192, outputReserve: 512, truncation: .auto)
        try assertTrue(overflow.message.contains("9000"))
        try assertTrue(overflow.message.contains("7680"))
        try assertTrue(overflow.message.contains("even after"))
    }

    test("tokenizer unavailable on old macOS is a 501, never an estimate") {
        let err = TokenCountingError.unavailable(.osTooOld(currentOS: "26.1.0"))
        try assertEqual(err.httpStatusCode, 501)
        try assertEqual(err.code, "token_counting_unavailable")
        try assertTrue(err.message.contains("26.4"))
        try assertTrue(err.message.contains("26.1.0"))
        try assertTrue(err.message.contains("no estimate"))
    }

    test("tokenizer unavailable because Apple Intelligence is down is a 503") {
        let err = TokenCountingError.unavailable(.modelUnavailable)
        try assertEqual(err.httpStatusCode, 503)
        try assertEqual(err.openAIType, "server_error")
        try assertEqual(err.code, "token_counting_unavailable")
        try assertTrue(err.message.contains("no estimate"))
    }

    test("runtime tokenizer failure is a 503 that says nothing was substituted") {
        let err = TokenCountingError.failed("boom")
        try assertEqual(err.httpStatusCode, 503)
        try assertEqual(err.code, "token_counting_failed")
        try assertTrue(err.message.contains("boom"))
        try assertTrue(err.message.contains("no estimate"))
    }

    // MARK: - Engine: prepared input + preflight (scripted counter, no model)

    testAsync("prepared input: json_schema rides on the final prompt entry (schema overhead counted)") {
        let schema = try SchemaConverter.generationSchema(
            fromJSON: #"{"type":"object","properties":{"city":{"type":"string"}}}"#, name: "city")
        let prepared = try await ContextManager.prepareEntries(
            messages: [user("name a city")], tools: nil, options: .defaults, responseSchema: schema)
        guard case .prompt(let p) = prepared.final else { throw TestFailure("final is not a prompt") }
        try assertNotNil(p.responseFormat, "final prompt must carry the response format")
        let plain = try await ContextManager.prepareEntries(
            messages: [user("name a city")], tools: nil, options: .defaults)
        guard case .prompt(let q) = plain.final else { throw TestFailure("final is not a prompt") }
        try assertNil(q.responseFormat)
    }

    testAsync("prepared input: function tools are rendered as instruction text, not native definitions (#555)") {
        let tool = OpenAITool(type: "function", function: OpenAIFunction(
            name: "add", description: "Add numbers",
            parameters: RawJSON(rawValue: #"{"type":"object","properties":{"a":{"type":"number"}}}"#)))
        let prepared = try await ContextManager.prepareEntries(
            messages: [user("add 1 and 2")], tools: [tool], options: .defaults)
        guard case .instructions(let i)? = prepared.base.first else { throw TestFailure("no instructions") }
        // The macOS 27 runtime ignores transcript-only ToolDefinitions (#555),
        // so the count must price the schema text the model actually reads.
        try assertTrue(i.toolDefinitions.isEmpty, "no native definitions")
        let text = i.segments.compactMap { seg -> String? in
            if case .text(let t) = seg { return t.content } else { return nil }
        }.joined()
        try assertTrue(text.contains("Add numbers") && text.contains(#""a""#), "schema rendered as text: \(text)")
    }

    test("runtime input entries: a transcript without instructions gets the runtime's default slot") {
        let prompt = makePromptEntry("hi")
        let normalized = runtimeInputEntries([prompt])
        try assertEqual(normalized.count, 2)
        guard case .instructions(let i) = normalized[0] else { throw TestFailure("first is not instructions") }
        try assertTrue(i.segments.isEmpty && i.toolDefinitions.isEmpty)
        let instr = Transcript.Entry.instructions(Transcript.Instructions(
            segments: [.text(Transcript.TextSegment(content: "sys"))], toolDefinitions: []))
        try assertEqual(runtimeInputEntries([instr, prompt]).count, 2)
    }

    testAsync("preflight: fitting input is counted once, no trimming, zero generation") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [OpenAIMessage(role: "system", content: .text("sys")), user("aa"), assistant("bbb"), user("cccc")],
            tools: nil, options: .defaults)
        let counter = ScriptedExactCounter()
        let outcome = try await InputTokenPreflight.run(
            prepared: prepared, budget: 1000, strategy: .newestFirst, counter: counter)
        guard case .counted(let result) = outcome else { throw TestFailure("expected counted, got \(outcome)") }
        try assertEqual(result.untrimmedInputTokens, 3 + 2 + 3 + 4)
        try assertEqual(result.inputTokens, result.untrimmedInputTokens)
        try assertEqual(result.removedHistoryPositions, [])
        // The only side effect of a preflight is counting: the scripted counter
        // is the sole dependency, so no session, no generation, no tool run.
        let calls = await counter.calls
        try assertTrue(!calls.isEmpty)
        try assertEqual(calls[0].count, prepared.base.count + prepared.history.count + 1)
    }

    testAsync("preflight: tool definitions are counted, never executed") {
        let tool = OpenAITool(type: "function", function: OpenAIFunction(
            name: "explode", description: "Must never run",
            parameters: RawJSON(rawValue: #"{"type":"object","properties":{}}"#)))
        let prepared = try await ContextManager.prepareEntries(
            messages: [user("call explode")], tools: [tool], options: .defaults)
        let counter = ScriptedExactCounter()
        let outcome = try await InputTokenPreflight.run(
            prepared: prepared, budget: 100_000, strategy: .newestFirst, counter: counter)
        guard case .counted(let result) = outcome else { throw TestFailure("expected counted") }
        let withoutTool = try await ContextManager.prepareEntries(
            messages: [user("call explode")], tools: nil, options: .defaults)
        let plain = try await InputTokenPreflight.run(
            prepared: withoutTool, budget: 100_000, strategy: .newestFirst, counter: ScriptedExactCounter())
        guard case .counted(let plainResult) = plain else { throw TestFailure("expected counted") }
        try assertTrue(result.inputTokens > plainResult.inputTokens + 10 - 1,
                       "tool definition overhead must be in the count")
    }

    testAsync("preflight: disabled truncation over budget is an overflow, nothing removed") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [user(String(repeating: "a", count: 50)), assistant(String(repeating: "b", count: 50)), user("q")],
            tools: nil, options: .defaults)
        let outcome = try await InputTokenPreflight.run(
            prepared: prepared, budget: 60, strategy: .strict, counter: ScriptedExactCounter())
        guard case .overflow(let untrimmed) = outcome else { throw TestFailure("expected overflow, got \(outcome)") }
        try assertEqual(untrimmed, 101)
    }

    testAsync("preflight: auto truncation drops the oldest history and reports it") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [user(String(repeating: "a", count: 50)), assistant(String(repeating: "b", count: 20)), user("q")],
            tools: nil, options: .defaults)
        let outcome = try await InputTokenPreflight.run(
            prepared: prepared, budget: 30, strategy: .newestFirst, counter: ScriptedExactCounter())
        guard case .counted(let result) = outcome else { throw TestFailure("expected counted, got \(outcome)") }
        try assertEqual(result.untrimmedInputTokens, 71)
        try assertEqual(result.inputTokens, 21)
        try assertEqual(result.removedHistoryPositions, [0])
    }

    testAsync("preflight: auto truncation that cannot fit even the final prompt is an overflow") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [assistant("b"), user(String(repeating: "q", count: 40))],
            tools: nil, options: .defaults)
        let outcome = try await InputTokenPreflight.run(
            prepared: prepared, budget: 30, strategy: .newestFirst, counter: ScriptedExactCounter())
        guard case .overflow(let untrimmed) = outcome else { throw TestFailure("expected overflow") }
        try assertEqual(untrimmed, 41)
    }

    testAsync("preflight: a smaller runtime context trims more, deterministically") {
        let messages = [user(String(repeating: "a", count: 30)), assistant(String(repeating: "b", count: 30)),
                        user(String(repeating: "c", count: 30)), user("q")]
        let prepared = try await ContextManager.prepareEntries(messages: messages, tools: nil, options: .defaults)
        var removedByBudget: [Int: [Int]] = [:]
        for budget in [200, 70, 40] {
            let first = try await InputTokenPreflight.run(
                prepared: prepared, budget: budget, strategy: .newestFirst, counter: ScriptedExactCounter())
            let second = try await InputTokenPreflight.run(
                prepared: prepared, budget: budget, strategy: .newestFirst, counter: ScriptedExactCounter())
            guard case .counted(let a) = first, case .counted(let b) = second else {
                throw TestFailure("budget \(budget) did not count")
            }
            try assertEqual(a, b, "same input + same budget must give the same report")
            try assertTrue(a.inputTokens <= budget)
            removedByBudget[budget] = a.removedHistoryPositions
        }
        try assertEqual(removedByBudget[200], [])
        try assertEqual(removedByBudget[70], [0])
        try assertEqual(removedByBudget[40], [0, 1])
    }

    testAsync("preflight: tokenizer unavailable propagates, no estimate is produced") {
        let prepared = try await ContextManager.prepareEntries(messages: [user("hi")], tools: nil, options: .defaults)
        let counter = ScriptedExactCounter(failure: .unavailable(.osTooOld(currentOS: "26.1.0")))
        do {
            _ = try await InputTokenPreflight.run(
                prepared: prepared, budget: 100, strategy: .newestFirst, counter: counter)
            throw TestFailure("expected TokenCountingError")
        } catch let e as TokenCountingError {
            try assertEqual(e, .unavailable(.osTooOld(currentOS: "26.1.0")))
        }
    }

    testAsync("preflight: a tokenizer failure during trimming is an error, not a guessed trim") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [user(String(repeating: "a", count: 50)), assistant("b"), user("q")],
            tools: nil, options: .defaults)
        // Call 1 (untrimmed) succeeds, call 2 (inside trimming) fails.
        let counter = ScriptedExactCounter(failure: .failed("tokenizer crashed"), failOnCall: 2)
        do {
            _ = try await InputTokenPreflight.run(
                prepared: prepared, budget: 10, strategy: .newestFirst, counter: counter)
            throw TestFailure("expected TokenCountingError")
        } catch let e as TokenCountingError {
            try assertEqual(e, .failed("tokenizer crashed"))
        }
    }

    testAsync("trimming: the shared trimmer honors an injected counter") {
        let prepared = try await ContextManager.prepareEntries(
            messages: [user(String(repeating: "a", count: 50)), assistant("bb"), user("q")],
            tools: nil, options: .defaults)
        let kept = await trimHistoryEntriesToBudget(
            baseEntries: prepared.base, historyEntries: prepared.history, finalEntry: prepared.final,
            budget: 5, config: ContextConfig(strategy: .newestFirst),
            count: { entries in entries.reduce(0) { $0 + ScriptedExactCounter.price($1) } })
        try assertEqual(kept?.count, 1, "only the assistant turn fits a 5-token budget")
    }
}
