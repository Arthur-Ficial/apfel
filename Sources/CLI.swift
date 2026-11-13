// ============================================================================
// CLI.swift — Command-line interface commands
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore
import ApfelEngine
import ApfelCLI
import CReadline

// MARK: - Chat Header

/// Print the chat mode header (app name, version, separator line).
/// Suppressed in --quiet mode. Routed to stderr in JSON mode.
func printHeader() {
    guard !quietMode else { return }
    let header = styled("Apple Intelligence", .cyan, .bold)
        + styled(" · on-device LLM · \(appName) v\(version)", .dim)
    let line = styled(String(repeating: "─", count: 56), .dim)
    if outputFormat == .json {
        printStderr(header)
        printStderr(line)
    } else {
        print(header)
        print(line)
    }
}

// MARK: - Single Prompt

/// Handle a single (non-interactive) prompt.
///
/// Behavior depends on output format:
/// - **plain**: Print response directly. If streaming, print tokens as they arrive.
/// - **json**: Buffer the complete response, then emit a single JSON object.
/// Returns the process exit code: 0, `ApfelExitCodes.noCode` when
/// `codeOnly` found no fenced block, or `ApfelExitCodes.incomplete` when
/// `requireComplete` saw a length finish (#484). A matched `--stop`
/// delimiter is a `stop` finish, so it is complete (#483).
func singlePrompt(_ prompt: String, systemPrompt: String?, stream: Bool, options: SessionOptions = .defaults, mcpManager: MCPManager? = nil, codeOnly: Bool = false, requireComplete: Bool = false, images: [PromptImage] = [], stopSequences: [String] = []) async throws -> Int32 {
    let mcpTools = await mcpManager?.allTools() ?? []
    let hasMCPTools = !mcpTools.isEmpty

    debugLog("single", "prompt_length=\(prompt.count) stream=\(stream) mcp=\(hasMCPTools) code=\(codeOnly) images=\(images.count)")

    let session: LanguageModelSession
    let finalPrompt: String
    if hasMCPTools {
        var msgs: [OpenAIMessage] = []
        if let sys = systemPrompt { msgs.append(OpenAIMessage(role: "system", content: .text(sys))) }
        msgs.append(OpenAIMessage(role: "user", content: .text(prompt)))
        (session, finalPrompt, _, _) = try await ContextManager.makeSession(
            messages: msgs, tools: mcpTools, options: options, jsonMode: false, toolChoice: nil)
    } else {
        // An oversized prompt is a context overflow (exit 4) on every OS, not
        // whatever the runtime happens to reject first (macOS 26.1 said
        // "unsupported language", #544). Only prompts that could be near the
        // budget pay for the exact count.
        let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
        let characters = prompt.count + (systemPrompt?.count ?? 0)
        if PromptBudgetCheck.needsExactCount(characters: characters, budget: budget) {
            var total = await TokenCounter.shared.count(prompt)
            if let systemPrompt {
                total += await TokenCounter.shared.count(systemPrompt)
            }
            if total > budget {
                throw contextOverflowError(tokenCount: total, contextSize: await TokenCounter.shared.contextSize)
            }
        }
        session = makeSession(systemPrompt: systemPrompt, options: options)
        finalPrompt = prompt
    }
    let genOpts = makeGenerationOptions(options)

    // --code buffers the whole response (the crop needs the closing fence),
    // so delta printing is off even on the bare-pipe streaming path.
    // Native image attachment (macOS 27, #510): the extracted OCR text stays
    // in the prompt, and the image itself rides along as an attachment.
    let pieces: [PromptPiece]? = images.isEmpty
        ? nil
        : [PromptPiece.text(finalPrompt)] + images.map { PromptPiece.image($0) }
    let result = try await processPrompt(
        prompt: finalPrompt, pieces: pieces, systemPrompt: systemPrompt, session: session,
        options: options, genOpts: genOpts, stream: stream,
        printDelta: outputFormat == .plain && !codeOnly, mcpManager: mcpManager, hasMCPTools: hasMCPTools,
        stopSequences: stopSequences)
    return emitOneShotResult(
        result, stream: stream, hasMCPTools: hasMCPTools,
        codeOnly: codeOnly, requireComplete: requireComplete,
        unknownFinishNote: CompletionPolicy.unknownFinishNote(
            maxTokens: options.maxTokens,
            tokenCountFallback: await TokenCounter.shared.tokenCountFallback,
            jsonOutput: outputFormat == .json))
}

/// Write a finished one-shot generation (single prompt or `--messages`) to
/// stdout and return the process exit code. Shared so plain output, the JSON
/// envelope and `--code` agree on status (#484).
///
/// `--require-complete` is checked before any buffered stdout write: a length
/// finish writes nothing more and returns `ApfelExitCodes.incomplete` (8).
/// Live-streamed deltas are already on stdout and cannot be retracted; the
/// nonzero exit is the contract there.
func emitOneShotResult(
    _ result: ProcessPromptResult,
    stream: Bool,
    hasMCPTools: Bool,
    codeOnly: Bool,
    requireComplete: Bool,
    unknownFinishNote: String? = nil
) -> Int32 {
    printToolLog(result.toolLog)
    let streamedLive = stream && outputFormat == .plain && !codeOnly && !hasMCPTools
    // Below macOS 26.4 with an explicit cap the stop/length decision is an
    // estimate: report it as unknown rather than as fact (PR #551 review).
    let reported = CompletionPolicy.reportedFinishReason(
        result.finishReason, truncation: result.truncation,
        finishSignalExact: unknownFinishNote == nil,
        stopMatched: result.matchedStop != nil)
    let decision = reported.map {
        CompletionPolicy.decide(finishReason: $0, requireComplete: requireComplete)
    } ?? .complete
    if let forced = decision.exitCode {
        if streamedLive {
            print()          // terminate the partial streamed line
            fflush(stdout)   // ...before the stderr error, so they don't interleave
        }
        printError(CompletionPolicy.incompleteMessage(cause: result.truncation))
        return forced
    }
    let finishReason = reported?.openAIValue
    if reported == nil, let unknownFinishNote, !quietMode {
        printStderr("\(styledErr("apfel:", .yellow)) \(unknownFinishNote)")
    }

    if codeOnly {
        let exitCode = printCroppedResponse(result.content, finishReason: finishReason)
        if decision.warnsTruncation { printLengthWarning(cause: result.truncation) }
        return exitCode
    }

    switch outputFormat {
    case .plain:
        if streamedLive { print() } else { print(result.content) }
    case .json:
        let obj = ApfelResponse(
            model: modelName, content: result.content, finishReason: finishReason,
            metadata: .init(onDevice: true, version: version))
        print(jsonString(obj))
    }

    if decision.warnsTruncation { printLengthWarning(cause: result.truncation) }
    return 0
}

/// Print the `--code` output contract (#373): the first fenced block's
/// content (or, with no fence anywhere, the bare response — a fully steered
/// model omits the fence and the response IS the code) to stdout, nothing
/// else. Empty extracted code (empty response, empty block, or a capped run
/// that produced only the opening fence) exits `noCode` (7) so scripts can
/// branch on "no code" vs "run failed"; it is never a silent exit 0.
func printCroppedResponse(_ content: String, finishReason: String? = nil) -> Int32 {
    let resolution = CodeOutputPolicy.resolve(response: content)
    guard case .code(let crop) = resolution else {
        if case .noCode(let message) = resolution {
            printStderr("\(styledErr("apfel:", .yellow)) \(message)")
        }
        return resolution.exitCode
    }
    switch outputFormat {
    case .plain:
        // crop.code already ends with exactly one newline (or is empty for a
        // deliberately empty block) — print verbatim, no extra terminator.
        print(crop.code, terminator: "")
    case .json:
        let obj = ApfelResponse(
            model: modelName, content: crop.code, language: crop.language,
            finishReason: finishReason,
            metadata: .init(onDevice: true, version: version))
        print(jsonString(obj))
    }
    return 0
}

/// Default stderr warning for a response truncated with finish_reason=length
/// (no `--require-complete`; output was still printed), naming the real cause.
func printLengthWarning(cause: TruncationCause?) {
    printStderr("\(styledErr("apfel:", .yellow)) \(CompletionPolicy.lengthWarning(cause: cause))")
}

// MARK: - Structured Single Prompt (#361)

/// Handle a single prompt with schema-guaranteed structured output (`--schema`).
///
/// The compiled `GenerationSchema` constrains decoding, so the output is
/// always a schema-valid JSON object - no fence stripping, no retry-on-invalid
/// JSON. Plain output prints the raw JSON (newline-terminated, jq-ready);
/// `-o json` wraps it as a string in the standard ApfelResponse envelope.
/// With `stream` (`--stream --schema`, #532) plain output prints the same
/// JSON as it is generated, append-only, byte-identical to the buffered one.
func structuredSinglePrompt(
    _ prompt: String,
    systemPrompt: String?,
    schemaJSON: String,
    schemaName: String,
    stream: Bool = false,
    options: SessionOptions = .defaults
) async throws {
    let session = makeSession(systemPrompt: systemPrompt, options: options)
    debugLog("schema", "prompt_length=\(prompt.count) schema_name=\(schemaName) stream=\(stream)")
    try await respondStructured(
        session: session, prompt: Prompt(prompt), schemaJSON: schemaJSON, schemaName: schemaName,
        stream: stream, options: options)
}

/// Schema-guided generation shared by `--schema` and `--messages --schema`.
/// Output is rendered in schema property order (`StructuredJSONRenderer`), so
/// the buffered and the streamed JSON are the same bytes. Streaming only
/// applies to plain output; `-o json` prints the finished envelope.
func respondStructured(
    session: LanguageModelSession,
    prompt: Prompt,
    schemaJSON: String,
    schemaName: String,
    stream: Bool,
    options: SessionOptions
) async throws {
    let schema = try SchemaConverter.generationSchema(fromJSON: schemaJSON, name: schemaName)
    let renderer = StructuredJSONRenderer(schemaJSON: schemaJSON, name: schemaName)
    let genOpts = makeGenerationOptions(options)
    let retryMax = options.retryEnabled ? options.retryCount : 0

    if stream && outputFormat == .plain {
        // One sink across retries: a re-run never reprints the sent prefix (#182).
        let sink = StreamPrintSink()
        try await withModelRetry(maxRetries: retryMax) {
            var last: GeneratedContent?
            for try await snapshot in session.streamResponse(to: prompt, schema: schema, options: genOpts) {
                last = snapshot.content
                await sink.feed(cumulative: renderer.stablePrefix(snapshot.content))
            }
            if let last { await sink.feed(cumulative: renderer.finalJSON(last)) }
        }
        print("")
        return
    }

    let content = try await withModelRetry(maxRetries: retryMax) {
        renderer.finalJSON(try await session.respond(to: prompt, schema: schema, options: genOpts).content)
    }
    switch outputFormat {
    case .plain:
        print(content)
    case .json:
        let obj = ApfelResponse(
            model: modelName, content: content,
            metadata: .init(onDevice: true, version: version))
        print(jsonString(obj))
    }
}

// MARK: - One-Shot Multi-Turn (#363)

/// Handle `--messages`: a whole OpenAI-style conversation in, the next
/// assistant message out. Reuses the server's transcript building
/// (`ContextManager.makeSession`) so CLI and server multi-turn semantics
/// cannot drift. Composes with `--stream` (delta printing) and `--schema`
/// (schema-guaranteed reply to the conversation).
/// Returns the process exit code: 0, or `ApfelExitCodes.noCode` when
/// `codeOnly` found no fenced block, or `ApfelExitCodes.incomplete` (same
/// contract as `singlePrompt`).
func messagesPrompt(
    messagesJSON: String,
    systemPrompt: String?,
    stream: Bool,
    schemaJSON: String?,
    schemaName: String?,
    options: SessionOptions = .defaults,
    mcpManager: MCPManager? = nil,
    codeOnly: Bool = false,
    requireComplete: Bool = false,
    stopSequences: [String] = []
) async throws -> Int32 {
    var messages = try MessagesInput.decode(messagesJSON)
    if let sys = systemPrompt {
        messages.insert(OpenAIMessage(role: "system", content: .text(sys)), at: 0)
    }
    let mcpTools = await mcpManager?.allTools() ?? []
    let hasMCPTools = !mcpTools.isEmpty
    debugLog("messages", "count=\(messages.count) stream=\(stream) mcp=\(hasMCPTools) schema=\(schemaJSON != nil)")

    let (session, finalPrompt, _, finalPieces) = try await ContextManager.makeSession(
        messages: messages, tools: mcpTools, options: options, jsonMode: false, toolChoice: nil)
    let genOpts = makeGenerationOptions(options)

    if let schemaJSON {
        try await respondStructured(
            session: session, prompt: makeUserPrompt(text: finalPrompt, pieces: finalPieces),
            schemaJSON: schemaJSON, schemaName: schemaName ?? "schema",
            stream: stream, options: options)
        return 0
    }

    let result = try await processPrompt(
        prompt: finalPrompt, pieces: finalPieces, systemPrompt: systemPrompt, session: session,
        options: options, genOpts: genOpts, stream: stream,
        printDelta: outputFormat == .plain && !codeOnly, mcpManager: mcpManager, hasMCPTools: hasMCPTools,
        stopSequences: stopSequences)
    return emitOneShotResult(
        result, stream: stream, hasMCPTools: hasMCPTools,
        codeOnly: codeOnly, requireComplete: requireComplete,
        unknownFinishNote: CompletionPolicy.unknownFinishNote(
            maxTokens: options.maxTokens,
            tokenCountFallback: await TokenCounter.shared.tokenCountFallback,
            jsonOutput: outputFormat == .json))
}

// MARK: - Token Budget Preflight

/// Count tokens for a prompt without calling the model (`--count-tokens`).
func countTokens(
    mergedPrompt: String,
    positionalPrompt: String,
    pipedContent: String?,
    fileAttachments: [FileAttachment],
    systemPrompt: String?,
    options: SessionOptions = .defaults,
    mcpManager: MCPManager? = nil,
    nativeImageCount: Int = 0
) async throws -> TokenBudgetReport {
    let mcpTools = await mcpManager?.allTools() ?? []
    let outputReserve = options.contextConfig.outputReserve
    let contextSize = await TokenCounter.shared.contextSize
    let tokenCountFallback = await TokenCounter.shared.tokenCountFallback
    await TokenCounter.shared.resetRuntimeFallbackFlag()
    let approximate = tokenCountFallback != nil
    // Session/entry construction is only unsafe when the MODEL is unavailable.
    // Under .osTooOld generation works fine: entries are built normally and
    // counted via the chars/4 fallback, which prices tool definitions too -
    // so MCP tool schemas are not silently counted as 0 and --strict cannot
    // false-pass on macOS < 26.4 (#326).
    let modelUnavailable = tokenCountFallback == .modelUnavailable

    let inputEntries: [Transcript.Entry]
    let noToolEntries: [Transcript.Entry]?

    if modelUnavailable {
        // Avoid LanguageModelSession construction when the model is unavailable.
        inputEntries = []
        noToolEntries = nil
    } else if !mcpTools.isEmpty {
        var msgs: [OpenAIMessage] = []
        if let sys = systemPrompt { msgs.append(OpenAIMessage(role: "system", content: .text(sys))) }
        msgs.append(OpenAIMessage(role: "user", content: .text(mergedPrompt)))
        let (_, _, withTools, _) = try await ContextManager.makeSession(
            messages: msgs, tools: mcpTools, options: options, jsonMode: false, toolChoice: nil)
        inputEntries = sessionInputEntries(
            builtEntries: withTools, finalPrompt: mergedPrompt, options: options)
        let (_, _, withoutTools, _) = try await ContextManager.makeSession(
            messages: msgs, tools: nil, options: options, jsonMode: false, toolChoice: nil)
        noToolEntries = sessionInputEntries(
            builtEntries: withoutTools, finalPrompt: mergedPrompt, options: options)
    } else {
        var builtEntries: [Transcript.Entry] = []
        if let sys = systemPrompt, !sys.isEmpty {
            builtEntries = transcriptEntries(makeSession(systemPrompt: sys, options: options).transcript)
        }
        inputEntries = sessionInputEntries(builtEntries: builtEntries, finalPrompt: mergedPrompt, options: options)
        noToolEntries = nil
    }

    let total: Int
    if modelUnavailable {
        var approxTotal = await TokenCounter.shared.count(mergedPrompt)
        if let sys = systemPrompt, !sys.isEmpty {
            approxTotal += await TokenCounter.shared.count(sys)
        }
        total = approxTotal
    } else {
        total = await TokenCounter.shared.count(entries: inputEntries)
    }

    var promptParts: [String] = []
    if let piped = pipedContent, !piped.isEmpty { promptParts.append(piped) }
    if !positionalPrompt.isEmpty { promptParts.append(positionalPrompt) }
    let promptText = promptParts.joined(separator: "\n\n")
    let promptTokens = await TokenCounter.shared.count(promptText)

    let systemTokens: Int
    if let sys = systemPrompt, !sys.isEmpty {
        systemTokens = await TokenCounter.shared.count(sys)
    } else {
        systemTokens = 0
    }

    var fileTokenCounts: [FileTokenCount] = []
    for attachment in fileAttachments {
        let tokens = await TokenCounter.shared.count(attachment.content)
        fileTokenCounts.append(FileTokenCount(path: attachment.path, tokens: tokens))
    }

    let mcpToolTokens: Int
    if modelUnavailable {
        mcpToolTokens = 0
    } else if let baseline = noToolEntries {
        let baselineCount = await TokenCounter.shared.count(entries: baseline)
        mcpToolTokens = max(0, total - baselineCount)
    } else {
        mcpToolTokens = 0
    }

    // The pre-flight decision can be wrong at runtime: tokenCount(for:) can
    // throw, or availability can flip between the check and the counts. The
    // counter records any actual fallback so the report never claims exact
    // numbers that were really chars/4 (#327).
    let runtimeFellBack = await TokenCounter.shared.runtimeFellBack
    let fellBackAtRuntime = tokenCountFallback == nil && runtimeFellBack

    let report = TokenBudgetReport.make(
        promptTokens: promptTokens,
        systemTokens: systemTokens,
        fileTokens: fileTokenCounts,
        mcpToolTokens: mcpToolTokens,
        total: total,
        contextSize: contextSize,
        outputReserve: outputReserve,
        approximate: approximate || fellBackAtRuntime
    )

    if let tokenCountFallback, !quietMode {
        printStderr("\(styledErr("apfel:", .yellow)) \(tokenCountFallback.message)")
    } else if fellBackAtRuntime, !quietMode {
        printStderr("\(styledErr("apfel:", .yellow)) token count is approximate (the on-device tokenizer failed at runtime; using chars/4 fallback)")
    }
    if nativeImageCount > 0, !quietMode {
        // Image attachments cannot be priced without a model call; the
        // runtime reports their real cost in usage at generation time (#510).
        printStderr("\(styledErr("apfel:", .yellow)) \(nativeImageCount) image attachment\(nativeImageCount == 1 ? "" : "s") not included in this count - the runtime reports image token cost at generation time")
    }

    switch outputFormat {
    case .plain:
        let fitLabel = report.fits ? "fits" : "over budget"
        print("\(report.total)/\(report.budget) tokens (\(fitLabel))")
        if !quietMode {
            var parts: [String] = []
            if report.promptTokens > 0 { parts.append("prompt=\(report.promptTokens)") }
            if report.systemTokens > 0 { parts.append("system=\(report.systemTokens)") }
            for ft in report.fileTokens where ft.tokens > 0 {
                parts.append("\(ft.path)=\(ft.tokens)")
            }
            if report.mcpToolTokens > 0 { parts.append("mcp_tools=\(report.mcpToolTokens)") }
            if !parts.isEmpty {
                printStderr(styledErr("  " + parts.joined(separator: ", "), .dim))
            }
        }
    case .json:
        print(jsonString(TokenBudgetJSONResponse(report: report), pretty: false))
        fflush(stdout)
    }

    return report
}

// MARK: - Interactive Chat

/// Run an interactive multi-turn chat session with context window protection.
func chat(systemPrompt: String?, initialContext: String? = nil, options: SessionOptions = .defaults, mcpManager: MCPManager? = nil, contextStatus: Bool = false) async throws {
    guard isatty(STDIN_FILENO) != 0 else {
        printError("--chat requires an interactive terminal (stdin must be a TTY)")
        exit(exitUsageError)
    }

    // `-f file` (and any positional prompt) seed the conversation: the extracted
    // content is folded into the session instructions so the model already has
    // it in context on the first turn. Before #370 the .chat dispatch dropped
    // this content silently. Folding into instructions (rather than a dangling
    // user turn) keeps the transcript well-formed for the first respond() call.
    let contextPreamble: String? = {
        guard let seed = initialContext, !seed.isEmpty else { return nil }
        return "The following is content the user attached for reference. Use it to answer their questions:\n\n\(seed)\n\n(End of attached content.)"
    }()

    // Keep SIGINT blocked while chat bootstraps so background threads spawned
    // during model/session setup do not inherit an unblocked Ctrl-C.
    apfel_block_sigint()

    let mcpTools = await mcpManager?.allTools() ?? []
    let hasMCPTools = !mcpTools.isEmpty

    let model = makeModel(permissive: options.permissive)
    var session: LanguageModelSession
    if hasMCPTools {
        // Build session with ALL tool schemas as text instructions and NO native
        // toolDefinitions. Native defs cause the FoundationModels framework to
        // intercept tool calls instead of surfacing them as text in the stream.
        // apfel uses out-of-band text detection (ToolCallHandler.detectToolCall),
        // so native interception breaks tool execution in chat mode (#144).
        var instrParts: [String] = []
        if let sys = systemPrompt { instrParts.append(sys) }
        if let pre = contextPreamble { instrParts.append(pre) }
        let toolNames = mcpTools.map { $0.function.name }
        instrParts.append(ToolCallHandler.buildOutputFormatInstructions(toolNames: toolNames))
        instrParts.append("IMPORTANT: You may ONLY call the functions listed above (\(toolNames.joined(separator: ", "))). Do NOT invent function names. If the user's request cannot be handled by these specific functions, respond with plain text.")
        let allToolDefs = mcpTools.map { ToolDef(name: $0.function.name, description: $0.function.description, parametersJSON: $0.function.parameters?.value) }
        instrParts.append(ToolCallHandler.buildFallbackPrompt(tools: allToolDefs))
        let instrText = instrParts.joined(separator: "\n\n")
        let segments: [Transcript.Segment] = [.text(Transcript.TextSegment(content: instrText))]
        let instr = Transcript.Instructions(segments: segments, toolDefinitions: [])
        session = makeTranscriptSession(model: model, entries: [.instructions(instr)])
        debugLog("chat", "session created with \(mcpTools.count) text-injected tools")
    } else {
        let combinedSystem = [systemPrompt, contextPreamble]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        session = makeSession(systemPrompt: combinedSystem.isEmpty ? nil : combinedSystem, options: options)
    }
    let genOpts = makeGenerationOptions(options)
    // Persistent history is opt-in via APFEL_HISTFILE (off by default). The
    // path decision is a pure, unit-tested policy in ApfelCLI (#259).
    let historyFile = ChatHistory.filePath(env: ProcessInfo.processInfo.environment)
    let lineEditor = ChatLineEditor(
        outputFormat: outputFormat,
        historyLimit: ChatHistory.maxEntries,
        historyFile: historyFile)
    var turn = 0

    printHeader()
    if !quietMode {
        if let sys = systemPrompt {
            let sysLine = styled("system: ", .magenta, .bold) + styled(sys, .dim)
            if outputFormat == .json {
                printStderr(sysLine)
            } else {
                print(sysLine)
            }
        }
        if let seed = initialContext, !seed.isEmpty {
            let ctxLine = styled("context: ", .magenta, .bold) + styled("loaded \(seed.count) chars into the conversation", .dim)
            if outputFormat == .json {
                printStderr(ctxLine)
            } else {
                print(ctxLine)
            }
        }
        let hint = styled("Type 'quit' to exit.\n", .dim)
        if outputFormat == .json {
            printStderr(hint)
        } else {
            print(hint)
        }
    }

    // Set when context rotation fails mid-session (e.g. --context-strategy
    // strict over budget). Captured here and rethrown after the loop so the
    // top-level handler maps it to a nonzero exit; a plain `throw` inside the
    // turn body would be swallowed by the per-turn model-error catch and the
    // session would exit 0 as if it ended cleanly (#252).
    var rotationError: Error?
    while true {
        let prompt = quietMode ? "" : "you› "
        guard let input = lineEditor.readLine(prompt: prompt) else { break }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed.lowercased() == "quit" || trimmed.lowercased() == "exit" { break }

        turn += 1

        if outputFormat == .json {
            print(jsonString(
                ChatMessage(role: "user", content: trimmed, model: nil),
                pretty: false
            ))
            fflush(stdout)
        }

        if !quietMode && outputFormat == .plain {
            print(styled(" ai› ", .cyan, .bold), terminator: "")
            fflush(stdout)
        }

        do {
            let result = try await processPrompt(
                prompt: trimmed, systemPrompt: systemPrompt, session: session,
                options: options, genOpts: genOpts, stream: true,
                printDelta: outputFormat == .plain, mcpManager: mcpManager, hasMCPTools: hasMCPTools)
            if !hasMCPTools && outputFormat == .plain { print("\n") }
            printToolLog(result.toolLog)
            let content = result.content

            switch outputFormat {
            case .plain:
                if hasMCPTools { print(content + "\n") }
            case .json:
                print(jsonString(
                    ChatMessage(role: "assistant", content: content, model: modelName),
                    pretty: false
                ))
                fflush(stdout)
            }

            // Context window protection: check transcript size after each turn
            let transcript = session.transcript
            // Priced like the trimmer prices it (runtime input, #485).
            let tokenCount = await TokenCounter.shared.countInput(entries: transcriptEntries(transcript))
            let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
            if contextStatus && !quietMode {
                printContextStatus(tokenCount: tokenCount, budget: budget)
            }
            if tokenCount > budget {
                do {
                    let truncated = try await truncateTranscript(transcript, budget: budget, config: options.contextConfig)
                    // Tool schemas live in the Instructions text segments (not native
                    // toolDefinitions), so they survive truncation without re-injection.
                    session = LanguageModelSession(model: model, transcript: truncated)
                    debugLog("context", "rotated\(hasMCPTools ? " (tool text preserved)" : "")")
                    if !quietMode && outputFormat == .plain {
                        print(styled("  [context rotated — \(options.contextConfig.strategy.rawValue)]", .dim))
                    }
                } catch {
                    // Context rotation failed (e.g. --context-strategy strict with
                    // history over budget throws contextOverflow). Capture it and
                    // leave the loop; it is rethrown below so main.swift maps it via
                    // exitCode(for:) to a nonzero exit instead of exiting 0 (#252).
                    rotationError = error
                    break
                }
            }
        } catch {
            let classified = classifyModelError(error)
            printError("\(classified.cliLabel) \(classified.openAIMessage)")
        }
    }

    if let rotationError { throw rotationError }

    if !quietMode {
        let bye = styled("\nGoodbye.", .dim)
        if outputFormat == .json {
            printStderr(bye)
        } else {
            print(bye)
        }
    }
}

func printContextStatus(tokenCount: Int, budget: Int) {
    let percent = budget > 0 ? min(999, (tokenCount * 100) / budget) : 0
    let remaining = max(0, budget - tokenCount)
    let line = styled("  [context \(tokenCount)/\(budget) tokens, \(percent)%, \(remaining) remaining]", .dim)
    if outputFormat == .json {
        printStderr(line)
    } else {
        print(line)
    }
}

// MARK: - Context Truncation

/// Truncate a transcript to fit within the token budget using the configured strategy.
func truncateTranscript(_ transcript: Transcript, budget: Int, config: ContextConfig = .defaults) async throws -> Transcript {
    let entries = transcriptEntries(transcript)
    guard !entries.isEmpty else { return transcript }

    let baseEntries: [Transcript.Entry]
    let historyEntries: [Transcript.Entry]
    if case .instructions = entries.first {
        baseEntries = [entries.first!]
        historyEntries = Array(entries.dropFirst())
    } else {
        baseEntries = []
        historyEntries = entries
    }

    guard let trimmed = await trimHistoryEntriesToBudget(
        baseEntries: baseEntries,
        historyEntries: historyEntries,
        budget: budget,
        config: config
    ) else {
        throw ApfelError.contextOverflow
    }

    return Transcript(entries: trimmed)
}

// MARK: - Model Info

/// Print model information and exit.
func printModelInfo() async {
    let tc = TokenCounter.shared
    let availability = await tc.availability
    let contextWindow = await tc.contextWindow
    let languages = await tc.supportedLanguages
    let capabilities = await tc.capabilitiesReport

    let availabilityLine = availability.isAvailable
        ? styled(availability.shortLabel, .green)
        : styled(availability.shortLabel, .red)

    print("""
    \(styled("apfel", .cyan, .bold)) v\(version) — model info
    \(styled("├", .dim)) model:      \(modelName)
    \(styled("├", .dim)) on-device:  true (always)
    \(styled("├", .dim)) available:  \(availabilityLine)
    \(styled("├", .dim)) context:    \(contextWindow.displayText)
    \(styled("├", .dim)) capabilities: \(capabilities.displayText)
    \(styled("├", .dim)) languages:  \(languages.joined(separator: ", "))
    \(styled("└", .dim)) framework:  FoundationModels (macOS 26+)
    """)

    if !availability.isAvailable {
        print("")
        print(styled("How to fix:", .yellow, .bold))
        print(availability.remediation)
    }
}

// MARK: - Release Info

func printRelease() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — release info

    \(styled("BUILD:", .yellow, .bold))
    \(styled("├", .dim)) version:    \(version)
    \(styled("├", .dim)) commit:     \(buildCommit)
    \(styled("├", .dim)) branch:     \(buildBranch)
    \(styled("├", .dim)) built:      \(buildDate)
    \(styled("├", .dim)) swift:      \(buildSwiftVersion)
    \(styled("└", .dim)) os:         \(buildOS)

    \(styled("CAPABILITIES:", .yellow, .bold))
    \(styled("├", .dim)) on-device:  100% local inference (no cloud, no API keys)
    \(styled("├", .dim)) model:      \(modelName) (FoundationModels framework)
    \(styled("├", .dim)) modes:      single, stream, chat, serve
    \(styled("├", .dim)) server:     OpenAI-compatible (/v1/chat/completions)
    \(styled("├", .dim)) tools:      function calling + MCP tool servers (--mcp)
    \(styled("├", .dim)) formats:    plain, json, streaming SSE
    \(styled("└", .dim)) strategies: newest-first, oldest-first, sliding-window, summarize, strict

    \(styled("LINKS:", .yellow, .bold))
    \(styled("├", .dim)) repo:       https://github.com/Arthur-Ficial/apfel
    \(styled("├", .dim)) gui:        https://github.com/Arthur-Ficial/apfel-gui
    \(styled("└", .dim)) requires:   macOS 26+, Apple Silicon, Apple Intelligence enabled
    """)
}

// MARK: - Demos

/// Write the bundled demo scripts to a directory. Because the demos are
/// embedded in the binary, this behaves identically across homebrew-core, the
/// tap, and source builds - there is no brew `--with-demo` option that could.
/// Returns a process exit code.
func runDemosInstall(target: String?) -> Int32 {
    let dirPath = target ?? "apfel-demos"
    let dir = URL(fileURLWithPath: dirPath)
    do {
        let installed = try DemoInstaller.install(into: dir)
        let resolved = dir.path
        print("\(styled("apfel:", .green, .bold)) wrote \(installed.count) demo files to \(styled(resolved, .cyan))")
        for demo in installed where demo.executable {
            print("  \(styled("•", .dim)) \(demo.name)")
        }
        print("")
        print("Try one:")
        print("  \(styled("\(resolved)/cmd", .cyan)) \"find files larger than 100MB\"")
        print("  \(styled("cat", .dim)) README.md | \(styled("\(resolved)/explain", .cyan)) ")
        print("")
        print("See \(styled("\(resolved)/README.md", .cyan)) for what each demo does.")
        return exitSuccess
    } catch {
        printError("could not write demos to \(dirPath): \(error)")
        return exitRuntimeError
    }
}

// MARK: - Self-Update

/// Check for updates and optionally run `brew upgrade apfel`.
/// Detects install method from the binary path, prompts y/N on TTY.
func performUpdate() {
    let current = version
    let execPath = ProcessInfo.processInfo.arguments[0]
    let resolved = (execPath as NSString).resolvingSymlinksInPath

    let installMethod = detectInstallMethod(binaryPath: resolved)

    // Derive the Homebrew prefix from the resolved binary path instead of
    // hardcoding /opt/homebrew, so a non-default prefix (Intel /usr/local, a
    // custom ~/homebrew, etc.) works. Fall back to a PATH lookup of brew (#260).
    let brewExec = homebrewPrefix(fromBinaryPath: resolved).map { "\($0)/bin/brew" }
        ?? findExecutableInPath("brew")
        ?? "brew"
    let apfelExec = homebrewPrefix(fromBinaryPath: resolved).map { "\($0)/bin/apfel" }
        ?? findExecutableInPath("apfel")
        ?? resolved

    switch installMethod {
    case .homebrew:
        print("\(appName) v\(current) (installed via Homebrew)")
    case .macports:
        print("\(appName) v\(current) (installed via MacPorts)")
        print("To update: sudo port sync && sudo port update apfel")
        return
    case .source:
        print("\(appName) v\(current) (installed from source)")
        print("To update: git pull && make install")
        print("Or visit: https://github.com/Arthur-Ficial/apfel/releases")
        return
    }

    // Check for updates via brew
    guard let outdatedJSON = shellOutput(brewExec, args: ["info", "--json=v2", "apfel"]),
          let data = outdatedJSON.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let formulae = json["formulae"] as? [[String: Any]],
          let formula = formulae.first,
          let installed = formula["installed"] as? [[String: Any]],
          let installedVersion = installed.first?["version"] as? String,
          let stable = (formula["versions"] as? [String: Any])?["stable"] as? String else {
        print("Could not check for updates. Try: brew upgrade apfel")
        return
    }

    if installedVersion == stable {
        print(styled("Already up to date.", .green))
        return
    }

    print("Update available: \(styled("v\(stable)", .green))")
    print("")

    // Non-interactive: report only
    guard isatty(STDIN_FILENO) != 0 else {
        print("Run `apfel --update` in a terminal to update.")
        return
    }

    print("Update now? [y/N] ", terminator: "")
    fflush(stdout)
    guard let answer = readLine(), answer.lowercased() == "y" else {
        print("Cancelled.")
        return
    }

    print(styled("Running: brew upgrade apfel", .dim))
    let result = shellPassthrough(brewExec, args: ["upgrade", "apfel"])
    if result == 0 {
        if let newVersion = shellOutput(apfelExec, args: ["--version"])?.trimmingCharacters(in: .whitespacesAndNewlines), !newVersion.isEmpty {
            print(styled("Updated to \(newVersion)", .green))
        } else {
            print(styled("Upgrade complete.", .green))
        }
    } else {
        printError("brew upgrade failed (exit \(result)). Try manually: brew upgrade apfel")
    }
}

/// Locate an executable by scanning `PATH`. Returns the first absolute path
/// that exists and is executable, or nil. Used as a fallback for `brew`/`apfel`
/// when the binary path is not a recognizable Homebrew layout (#260).
private func findExecutableInPath(_ name: String) -> String? {
    guard let pathVar = ProcessInfo.processInfo.environment["PATH"] else { return nil }
    let fm = FileManager.default
    for dir in pathVar.split(separator: ":", omittingEmptySubsequences: true) {
        let candidate = "\(dir)/\(name)"
        if fm.isExecutableFile(atPath: candidate) { return candidate }
    }
    return nil
}

/// Run a command with stdout/stderr passed through to the terminal.
@discardableResult
private func shellPassthrough(_ executable: String, args: [String]) -> Int32 {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    do {
        try proc.run()
        proc.waitUntilExit()
    } catch {
        return 1
    }
    return proc.terminationStatus
}

// MARK: - Usage

/// Print the help/usage text to the given destination.
///
/// `--help`/`.help` prints to stdout and exits 0. Usage-error paths (exit 2)
/// print to stderr so stdout stays empty for downstream pipes (#250). ANSI
/// color is gated on the destination's own TTY-ness so a redirected error
/// stream stays escape-free (see styledErr, #249).
func printUsage(to handle: FileHandle = .standardOutput) {
    let toStderr = handle === FileHandle.standardError
    let colorize = ColorPolicy.shouldColorize(
        isTTY: isatty(toStderr ? STDERR_FILENO : STDOUT_FILENO) != 0,
        noColorEnv: noColorEnv,
        noColorFlag: noColorFlag)
    // The text itself lives in ApfelCLI (UsageText) so unit tests can guard
    // flag coverage and the grouped OPTIONS layout.
    let text = UsageText.render(appName: appName, version: version) { header in
        applyStyle(header, colorize: colorize, [.yellow, .bold])
    }
    handle.write(Data((text + "\n").utf8))
}
