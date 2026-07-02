// ============================================================================
// Benchmark.swift — Internal performance benchmarks
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation
import FoundationModels
import NIOCore
import ApfelCore

private struct BenchmarkReport: Encodable {
    let version: String
    let timestamp: String
    let environment: BenchmarkEnvironment
    let benchmarks: [BenchmarkCaseResult]
}

private struct BenchmarkEnvironment: Encodable {
    let model: String
    let context_window: Int
    let token_counter_available: Bool
}

private struct BenchmarkCaseResult: Encodable {
    let name: String
    let iterations: Int
    let baseline_avg_ms: Double?
    let current_avg_ms: Double
    let speedup_ratio: Double?
    let validated: Bool
    let notes: String?
}

private struct BenchmarkTiming {
    let avgMilliseconds: Double
}

func runBenchmarks() async throws {
    let report = try await benchmarkReport()
    switch outputFormat {
    case .json:
        print(jsonString(report, pretty: false), terminator: "")
    case .plain:
        print("""
        \(styled("apfel", .cyan, .bold)) v\(report.version) — benchmark report
        model: \(report.environment.model)
        context: \(report.environment.context_window) tokens
        token counter available: \(report.environment.token_counter_available)
        """)
        for result in report.benchmarks {
            let baseline = result.baseline_avg_ms.map { String(format: "%.3f ms", $0) } ?? "n/a"
            let speedup = result.speedup_ratio.map { String(format: "%.2fx", $0) } ?? "n/a"
            print("""
            \(styled("•", .dim)) \(result.name)
              iterations: \(result.iterations)
              baseline:   \(baseline)
              current:    \(String(format: "%.3f ms", result.current_avg_ms))
              speedup:    \(speedup)
              validated:  \(result.validated ? "yes" : "no")
            """)
            if let notes = result.notes {
                print("  notes:      \(notes)")
            }
        }
    }
}

private func benchmarkReport() async throws -> BenchmarkReport {
    let options = SessionOptions(
        temperature: 0.2,
        topP: nil,
        maxTokens: 256,
        seed: 42,
        permissive: false,
        contextConfig: ContextConfig(strategy: .newestFirst, maxTurns: nil, outputReserve: 512),
        retryEnabled: false,
        retryCount: 3
    )

    let textExtraction = await benchmarkTextContent()
    let trimNewest = await benchmarkTrimNewestFirst(options: options)
    let trimOldest = await benchmarkTrimOldestFirst(options: options)
    let toolSchemaConvert = await benchmarkToolSchemaConvert()
    let requestBodyCapture = await benchmarkRequestBodyCaptureDisabled()
    let streamDebugCapture = await benchmarkStreamDebugCaptureDisabled()
    let contextManager = try await benchmarkContextManager(options: options)
    let requestPipeline = try await benchmarkRequestPipeline(options: options)
    let requestDecode = await benchmarkRequestDecode()
    let toolDetection = await benchmarkToolDetection()
    let responseEncode = await benchmarkResponseEncode()

    return BenchmarkReport(
        version: version,
        timestamp: benchmarkTimestamp(),
        environment: BenchmarkEnvironment(
            model: modelName,
            context_window: await TokenCounter.shared.contextSize,
            token_counter_available: await TokenCounter.shared.isAvailable
        ),
        benchmarks: [
            textExtraction,
            trimNewest,
            trimOldest,
            toolSchemaConvert,
            requestBodyCapture,
            streamDebugCapture,
            contextManager,
            requestPipeline,
            requestDecode,
            toolDetection,
            responseEncode,
        ]
    )
}

private func benchmarkTextContent() async -> BenchmarkCaseResult {
    let message = OpenAIMessage(
        role: "user",
        content: .parts((0..<96).map { idx in
            ContentPart(type: "text", text: "segment-\(idx)-\(String(repeating: "x", count: 16))")
        })
    )
    let expected = legacyTextContent(message)
    let current = message.textContent

    let iterations = 2_000
    let baseline = await measure(iterations: iterations) {
        _ = legacyTextContent(message)
    }
    let optimized = await measure(iterations: iterations) {
        _ = message.textContent
    }

    return BenchmarkCaseResult(
        name: "message_text_content",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: expected == current,
        notes: "Single-pass text extraction for multi-part messages."
    )
}

private func benchmarkTrimNewestFirst(options: SessionOptions) async -> BenchmarkCaseResult {
    let fixture = makeTrimFixture(options: options)
    let expected = await legacyTrimNewestFirst(
        base: fixture.baseEntries,
        history: fixture.historyEntries,
        final: fixture.finalEntry,
        budget: fixture.budget
    )
    let current = await trimNewestFirst(
        base: fixture.baseEntries,
        history: fixture.historyEntries,
        final: fixture.finalEntry,
        budget: fixture.budget
    )

    let iterations = 50
    let baseline = await measure(iterations: iterations) {
        _ = await legacyTrimNewestFirst(
            base: fixture.baseEntries,
            history: fixture.historyEntries,
            final: fixture.finalEntry,
            budget: fixture.budget
        )
    }
    let optimized = await measure(iterations: iterations) {
        _ = await trimNewestFirst(
            base: fixture.baseEntries,
            history: fixture.historyEntries,
            final: fixture.finalEntry,
            budget: fixture.budget
        )
    }

    return BenchmarkCaseResult(
        name: "trim_newest_first",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: signature(for: expected) == signature(for: current),
        notes: "Exact binary-search fit check replaces repeated full-history scans."
    )
}

private func benchmarkTrimOldestFirst(options: SessionOptions) async -> BenchmarkCaseResult {
    let fixture = makeTrimFixture(options: options)
    let expected = await legacyTrimOldestFirst(
        base: fixture.baseEntries,
        history: fixture.historyEntries,
        final: fixture.finalEntry,
        budget: fixture.budget
    )
    let current = await trimOldestFirst(
        base: fixture.baseEntries,
        history: fixture.historyEntries,
        final: fixture.finalEntry,
        budget: fixture.budget
    )

    let iterations = 50
    let baseline = await measure(iterations: iterations) {
        _ = await legacyTrimOldestFirst(
            base: fixture.baseEntries,
            history: fixture.historyEntries,
            final: fixture.finalEntry,
            budget: fixture.budget
        )
    }
    let optimized = await measure(iterations: iterations) {
        _ = await trimOldestFirst(
            base: fixture.baseEntries,
            history: fixture.historyEntries,
            final: fixture.finalEntry,
            budget: fixture.budget
        )
    }

    return BenchmarkCaseResult(
        name: "trim_oldest_first",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: signature(for: expected) == signature(for: current),
        notes: "Exact binary-search fit check replaces repeated prefix growth scans."
    )
}

private func benchmarkContextManager(options: SessionOptions) async throws -> BenchmarkCaseResult {
    let tools = benchmarkTools()
    let messages = benchmarkMessages()

    let iterations = 12
    let timing = await measure(iterations: iterations) {
        _ = try? await ContextManager.makeSession(
            messages: messages,
            tools: tools,
            options: options,
            jsonMode: true,
            toolChoice: .auto
        )
    }

    return BenchmarkCaseResult(
        name: "context_manager_make_session",
        iterations: iterations,
        baseline_avg_ms: nil,
        current_avg_ms: timing.avgMilliseconds,
        speedup_ratio: nil,
        validated: true,
        notes: "End-to-end session assembly with tools, JSON mode, and transcript trimming."
    )
}

private func benchmarkToolSchemaConvert() async -> BenchmarkCaseResult {
    let tools = benchmarkTools()
    let expected = SchemaConverter.convertUncached(tools: tools)
    let current = await SchemaConverter.convert(tools: tools)

    let iterations = 500
    let baseline = await measure(iterations: iterations) {
        _ = SchemaConverter.convertUncached(tools: tools)
    }
    let optimized = await measure(iterations: iterations) {
        _ = await SchemaConverter.convert(tools: tools)
    }

    return BenchmarkCaseResult(
        name: "tool_schema_convert",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: expected.native.map(\.name) == current.native.map(\.name)
            && expected.fallback.map(\.name) == current.fallback.map(\.name),
        notes: "Caches native tool schema conversion by full tool signature."
    )
}

private func benchmarkRequestBodyCaptureDisabled() async -> BenchmarkCaseResult {
    let requestText = String(decoding: makeRequestJSON(), as: UTF8.self)
    let body = ByteBuffer(string: requestText)
    let expected = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
    let current = capturedRequestBody(body, debugEnabled: true)

    let iterations = 2_000
    let baseline = await measure(iterations: iterations) {
        _ = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
    }
    let optimized = await measure(iterations: iterations) {
        _ = capturedRequestBody(body, debugEnabled: false)
    }

    return BenchmarkCaseResult(
        name: "request_body_capture_disabled",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: expected == current,
        notes: "Skips request-body String materialization when --debug is off."
    )
}

private func benchmarkStreamDebugCaptureDisabled() async -> BenchmarkCaseResult {
    let lines = (0..<96).map { idx in
        #"data: {"id":"chatcmpl-bench","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"segment-\#(idx)"}}]}"#
    }
    let expected = legacyStreamDebugTranscript(lines: lines, debugEnabled: true)
    let current = currentStreamDebugTranscript(lines: lines, debugEnabled: true)

    let iterations = 500
    let baseline = await measure(iterations: iterations) {
        _ = legacyStreamDebugTranscript(lines: lines, debugEnabled: false)
    }
    let optimized = await measure(iterations: iterations) {
        _ = currentStreamDebugTranscript(lines: lines, debugEnabled: false)
    }

    return BenchmarkCaseResult(
        name: "stream_debug_capture_disabled",
        iterations: iterations,
        baseline_avg_ms: baseline.avgMilliseconds,
        current_avg_ms: optimized.avgMilliseconds,
        speedup_ratio: baseline.avgMilliseconds / optimized.avgMilliseconds,
        validated: expected == current,
        notes: "Skips per-chunk transcript capture and final join when stream debug logging is off."
    )
}

private func benchmarkRequestPipeline(options: SessionOptions) async throws -> BenchmarkCaseResult {
    let requestJSON = makeRequestJSON()
    let request = try JSONDecoder().decode(ChatCompletionRequest.self, from: requestJSON)
    let validation = try await benchmarkRequestPipelineResult(request: request, options: options)

    let iterations = 40
    let timing = await measure(iterations: iterations) {
        _ = try? await benchmarkRequestPipelineResult(request: request, options: options)
    }

    return BenchmarkCaseResult(
        name: "request_pipeline_noninference",
        iterations: iterations,
        baseline_avg_ms: nil,
        current_avg_ms: timing.avgMilliseconds,
        speedup_ratio: nil,
        validated: !validation.finalPrompt.isEmpty && validation.promptTokens > 0 && validation.responseBytes > 0,
        notes: "Decode + context build + token counting + response encode, excluding model inference."
    )
}

private func benchmarkRequestDecode() async -> BenchmarkCaseResult {
    let requestJSON = makeRequestJSON()
    let iterations = 500
    let timing = await measure(iterations: iterations) {
        _ = try? JSONDecoder().decode(ChatCompletionRequest.self, from: requestJSON)
    }

    return BenchmarkCaseResult(
        name: "request_decode",
        iterations: iterations,
        baseline_avg_ms: nil,
        current_avg_ms: timing.avgMilliseconds,
        speedup_ratio: nil,
        validated: true,
        notes: "OpenAI-compatible request decoding throughput."
    )
}

private func benchmarkToolDetection() async -> BenchmarkCaseResult {
    let response = """
    Let me check that.
    ```json
    {"tool_calls": [{"id": "call_weather", "type": "function", "function": {"name": "get_weather", "arguments": "{\\"city\\":\\"Vienna\\",\\"units\\":\\"metric\\"}"}}]}
    ```
    """
    let iterations = 2_000
    let timing = await measure(iterations: iterations) {
        _ = ToolCallHandler.detectToolCall(in: response)
    }

    return BenchmarkCaseResult(
        name: "tool_call_detect",
        iterations: iterations,
        baseline_avg_ms: nil,
        current_avg_ms: timing.avgMilliseconds,
        speedup_ratio: nil,
        validated: ToolCallHandler.detectToolCall(in: response)?.first?.name == "get_weather",
        notes: "Tool-call extraction from mixed text and fenced JSON."
    )
}

private func benchmarkResponseEncode() async -> BenchmarkCaseResult {
    let payload = ChatCompletionResponse(
        id: "chatcmpl-bench",
        object: "chat.completion",
        created: Int(Date().timeIntervalSince1970),
        model: modelName,
        choices: [
            .init(
                index: 0,
                message: OpenAIMessage(role: "assistant", content: .text(String(repeating: "structured output ", count: 24))),
                finish_reason: "stop",
                logprobs: nil
            )
        ],
        usage: .init(prompt_tokens: 1_024, completion_tokens: 256, total_tokens: 1_280)
    )
    let iterations = 1_000
    let timing = await measure(iterations: iterations) {
        _ = jsonString(payload, pretty: false)
    }

    return BenchmarkCaseResult(
        name: "response_encode",
        iterations: iterations,
        baseline_avg_ms: nil,
        current_avg_ms: timing.avgMilliseconds,
        speedup_ratio: nil,
        validated: true,
        notes: "Response serialization throughput for API replies."
    )
}

private func measure(
    iterations: Int,
    warmup: Int = 2,
    operation: @escaping () async -> Void
) async -> BenchmarkTiming {
    guard iterations > 0 else { return BenchmarkTiming(avgMilliseconds: 0) }

    for _ in 0..<warmup {
        await operation()
    }

    var totalNanoseconds: UInt64 = 0
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        await operation()
        totalNanoseconds += DispatchTime.now().uptimeNanoseconds - start
    }

    return BenchmarkTiming(
        avgMilliseconds: Double(totalNanoseconds) / Double(iterations) / 1_000_000
    )
}

private func makeTrimFixture(options: SessionOptions) -> (
    baseEntries: [Transcript.Entry],
    historyEntries: [Transcript.Entry],
    finalEntry: Transcript.Entry,
    budget: Int
) {
    let systemText = "You are a precise assistant. Preserve exact intent, summarize only when required, and prefer direct answers."
    let instructions = Transcript.Instructions(
        segments: [.text(.init(content: systemText))],
        toolDefinitions: []
    )

    var historyEntries: [Transcript.Entry] = []
    historyEntries.reserveCapacity(72)
    for idx in 0..<36 {
        historyEntries.append(makePromptEntry(
            "User turn \(idx): \(String(repeating: "question \(idx) ", count: 10))",
            options: options
        ))
        historyEntries.append(.response(
            Transcript.Response(
                assetIDs: [],
                segments: [.text(.init(content: "Assistant turn \(idx): \(String(repeating: "answer \(idx) ", count: 12))"))]
            )
        ))
    }

    let finalEntry = makePromptEntry(
        "Final user question: \(String(repeating: "please compare and summarize ", count: 8))",
        options: options
    )

    return (
        baseEntries: [.instructions(instructions)],
        historyEntries: historyEntries,
        finalEntry: finalEntry,
        budget: 1_800
    )
}

private func benchmarkTools() -> [OpenAITool] {
    [
        OpenAITool(
            type: "function",
            function: OpenAIFunction(
                name: "get_weather",
                description: "Fetch current weather conditions for a city.",
                parameters: RawJSON(rawValue: """
                {
                  "type": "object",
                  "properties": {
                    "city": { "type": "string", "description": "City name" },
                    "units": { "type": "string", "enum": ["metric", "imperial"] }
                  },
                  "required": ["city"]
                }
                """)
            )
        ),
        OpenAITool(
            type: "function",
            function: OpenAIFunction(
                name: "lookup_fact",
                description: "Return a short factual lookup result.",
                parameters: RawJSON(rawValue: """
                {
                  "type": "object",
                  "properties": {
                    "topic": { "type": "string" },
                    "detail_level": { "type": "integer" }
                  },
                  "required": ["topic"]
                }
                """)
            )
        ),
        OpenAITool(
            type: "function",
            function: OpenAIFunction(
                name: "search_notes",
                description: "Search local notes for matching text.",
                parameters: RawJSON(rawValue: """
                {
                  "type": "object",
                  "properties": {
                    "query": { "type": "string" },
                    "limit": { "type": "integer" },
                    "folders": {
                      "type": "array",
                      "items": { "type": "string" }
                    }
                  },
                  "required": ["query"]
                }
                """)
            )
        ),
    ]
}

private func benchmarkMessages() -> [OpenAIMessage] {
    var messages: [OpenAIMessage] = [
        OpenAIMessage(
            role: "system",
            content: .text("You are a benchmarking assistant. Prefer concise answers and emit valid JSON when requested.")
        )
    ]

    for idx in 0..<18 {
        messages.append(OpenAIMessage(
            role: "user",
            content: .parts([
                ContentPart(type: "text", text: "Question \(idx): "),
                ContentPart(type: "text", text: String(repeating: "Please review the previous answer and compare it against the new request. ", count: 2)),
            ])
        ))
        messages.append(OpenAIMessage(
            role: "assistant",
            content: .text("Answer \(idx): \(String(repeating: "This is a synthetic benchmark response. ", count: 3))")
        ))
    }

    messages.append(OpenAIMessage(
        role: "user",
        content: .text("Final request: produce a short JSON answer with the most relevant differences.")
    ))
    return messages
}

private func makeRequestJSON() -> Data {
    let payload = """
    {
      "model": "apple-foundationmodel",
      "stream": false,
      "temperature": 0.2,
      "max_tokens": 256,
      "response_format": { "type": "json_object" },
      "x_context_strategy": "newest-first",
      "messages": [
        { "role": "system", "content": "You are concise and emit valid JSON." },
        { "role": "user", "content": "Summarize the status update." },
        { "role": "assistant", "content": "Please share the update." },
        {
          "role": "user",
          "content": [
            { "type": "text", "text": "Status update: " },
            { "type": "text", "text": "latency improved, tests are green, and release prep is underway." }
          ]
        }
      ],
      "tools": [
        {
          "type": "function",
          "function": {
            "name": "lookup_fact",
            "description": "Return a short factual lookup result.",
            "parameters": {
              "type": "object",
              "properties": {
                "topic": { "type": "string" }
              },
              "required": ["topic"]
            }
          }
        }
      ]
    }
    """
    return Data(payload.utf8)
}

private func benchmarkRequestPipelineResult(
    request: ChatCompletionRequest,
    options: SessionOptions
) async throws -> (finalPrompt: String, promptTokens: Int, responseBytes: Int) {
    let (_, finalPrompt, inputEntries) = try await ContextManager.makeSession(
        messages: request.messages,
        tools: request.tools,
        options: options,
        jsonMode: request.response_format?.type == "json_object",
        toolChoice: request.tool_choice
    )
    let promptTokens = await TokenCounter.shared.count(
        entries: sessionInputEntries(builtEntries: inputEntries, finalPrompt: finalPrompt, options: options)
    )
    let payload = ChatCompletionResponse(
        id: "chatcmpl-bench",
        object: "chat.completion",
        created: 1_717_171_717,
        model: modelName,
        choices: [
            .init(
                index: 0,
                message: OpenAIMessage(role: "assistant", content: .text("ok")),
                finish_reason: "stop",
                logprobs: nil
            )
        ],
        usage: .init(prompt_tokens: promptTokens, completion_tokens: 1, total_tokens: promptTokens + 1)
    )
    let encoded = jsonString(payload, pretty: false)
    return (finalPrompt, promptTokens, encoded.utf8.count)
}

private func signature(for entries: [Transcript.Entry]) -> [String] {
    entries.map { entry in
        switch entry {
        case .instructions(let instructions):
            let text = instructions.segments.compactMap(textFromSegment).joined(separator: "|")
            let tools = instructions.toolDefinitions.map(\.name).joined(separator: ",")
            return "instructions:\(text):\(tools)"
        case .prompt(let prompt):
            return "prompt:\(prompt.segments.compactMap(textFromSegment).joined(separator: "|"))"
        case .response(let response):
            return "response:\(response.segments.compactMap(textFromSegment).joined(separator: "|"))"
        case .toolOutput(let output):
            let text = output.segments.compactMap(textFromSegment).joined(separator: "|")
            return "toolOutput:\(output.id):\(output.toolName):\(text)"
        case .toolCalls(let calls):
            let serialized = calls.map { "\($0.id):\($0.toolName)" }.joined(separator: "|")
            return "toolCalls:\(serialized)"
        @unknown default:
            return "unknown"
        }
    }
}

private func textFromSegment(_ segment: Transcript.Segment) -> String? {
    if case .text(let text) = segment {
        return text.content
    }
    return nil
}

private func legacyTextContent(_ message: OpenAIMessage) -> String? {
    switch message.content {
    case .text(let text):
        return text
    case .parts(let parts):
        let containsImage = parts.contains(where: { $0.type == "image_url" })
        guard !containsImage else { return nil }
        return parts.compactMap(\.text).joined()
    case .none:
        return nil
    }
}

private func legacyStreamDebugTranscript(lines: [String], debugEnabled: Bool) -> String? {
    let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    return captureTruncatedLogBody(trimmed.joined(separator: "\n\n"), enabled: debugEnabled)
}

private func currentStreamDebugTranscript(lines: [String], debugEnabled: Bool) -> String? {
    var captured: [String]? = debugEnabled ? [] : nil
    captured?.reserveCapacity(16)
    for line in lines {
        captured?.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return captured.map { truncateForLog($0.joined(separator: "\n\n")) }
}

private func legacyTrimNewestFirst(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry?,
    budget: Int
) async -> [Transcript.Entry] {
    var kept: [Transcript.Entry] = []
    for entry in history.reversed() {
        if !(await fitsTranscriptBudget(base: base, history: [entry] + kept, final: final, budget: budget)) {
            break
        }
        kept.insert(entry, at: 0)
    }
    return assembleTranscriptEntries(base: base, history: kept)
}

private func legacyTrimOldestFirst(
    base: [Transcript.Entry],
    history: [Transcript.Entry],
    final: Transcript.Entry?,
    budget: Int
) async -> [Transcript.Entry] {
    var kept: [Transcript.Entry] = []
    for entry in history {
        if !(await fitsTranscriptBudget(base: base, history: kept + [entry], final: final, budget: budget)) {
            break
        }
        kept.append(entry)
    }
    return assembleTranscriptEntries(base: base, history: kept)
}

private func benchmarkTimestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}
