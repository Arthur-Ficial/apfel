// ============================================================================
// BatchRunner.swift - `apfel --batch` (#481): read JSONL records from stdin
// incrementally, generate each in a fresh session, write one JSON result line
// per record before reading further input.
// Part of apfel - the pure framing/validation/result contract lives in
// ApfelCLI (Sources/CLI/Batch.swift).
//
// Serial by design: one record at a time, one LanguageModelSession per record
// (no transcript is shared, so nothing from record A can reach record B), one
// process and one warmed model for the whole run. stdin is read in bounded
// chunks only after the previous chunk's records were written, and stdout is
// written with blocking writes, so a slow consumer suspends intake.
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore
import ApfelEngine
import ApfelCLI

/// Run a batch over stdin and return the process exit code: 0 when every
/// record succeeded (or there were none), 1 when any record failed or stdin
/// could not be read. A closed stdout exits 141 like a UNIX filter.
func runBatch(
    systemPrompt: String?,
    schemaJSON: String?,
    schemaName: String?,
    options: SessionOptions,
    stopSequences: [String]
) async -> Int32 {
    let schema: GenerationSchema?
    // Same key order as --schema, --stream --schema and the server (#532).
    let renderer = StructuredJSONRenderer(schemaJSON: schemaJSON ?? "", name: schemaName ?? "schema")
    if let schemaJSON {
        do {
            schema = try SchemaConverter.generationSchema(fromJSON: schemaJSON, name: schemaName ?? "schema")
        } catch {
            printError("could not compile --schema: \(error)")
            return exitRuntimeError
        }
    } else {
        schema = nil
    }

    // main.swift refuses an undetectable explicit cap before we get here
    // (CompletionPolicy.batchPreflightRefusal); this stays as the guard that
    // an inexact finish signal is reported as unknown (null), never a guess.
    let finishSignalExact = CompletionPolicy.unknownFinishNote(
        maxTokens: options.maxTokens,
        tokenCountFallback: await TokenCounter.shared.tokenCountFallback) == nil

    var framer = BatchLineFramer()
    var tally = BatchTally()
    var chunk = [UInt8](repeating: 0, count: BatchLimits.readChunkBytes)
    var readFailed = false

    func handle(_ frames: [BatchFrame]) async {
        for frame in frames {
            let result: BatchResult
            switch frame {
            case .oversized(let line):
                result = .oversized(line: line)
            case .line(let line, let bytes):
                switch BatchRecordParser.parse(bytes, line: line) {
                case .blank:
                    continue
                case .invalid(let customID, let message):
                    result = .invalidRecord(line: line, customID: customID, message: message)
                case .record(let record):
                    result = await generateBatchRecord(
                        record, systemPrompt: systemPrompt, schema: schema, renderer: renderer, options: options,
                        stopSequences: stopSequences, finishSignalExact: finishSignalExact)
                }
            }
            tally.add(result)
            // One write per record: a line is either fully written or not at all.
            if !writeTolerantly(result.jsonLine + "\n", to: FileHandle.standardOutput) {
                exit(brokenPipeExitStatus)
            }
        }
    }

    while true {
        let n = chunk.withUnsafeMutableBytes { read(STDIN_FILENO, $0.baseAddress, $0.count) }
        if n == 0 { break }
        if n < 0 {
            if errno == EINTR { continue }
            printError("could not read stdin: \(String(cString: strerror(errno)))")
            readFailed = true
            break
        }
        await handle(framer.feed(chunk[0..<n]))
    }
    if !readFailed {
        await handle(framer.finish())
    }

    if !quietMode {
        printStderr("\(styledErr("apfel:", .yellow)) \(tally.summary)")
    }
    return readFailed ? exitRuntimeError : tally.exitCode
}

/// Generate one record in its own session and turn the outcome into a
/// result line. Every model error is record-local.
private func generateBatchRecord(
    _ record: BatchRecord,
    systemPrompt: String?,
    schema: GenerationSchema?,
    renderer: StructuredJSONRenderer,
    options: SessionOptions,
    stopSequences: [String],
    finishSignalExact: Bool
) async -> BatchResult {
    debugLog("batch", "line=\(record.line) custom_id=\(record.customID)")
    do {
        let session: LanguageModelSession
        let finalPrompt: String
        let pieces: [PromptPiece]?
        switch record.input {
        case .prompt(let prompt):
            // Same overflow handling as a one-shot prompt: an oversized
            // record is a context_length_exceeded error on every OS.
            let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
            let characters = prompt.count + (systemPrompt?.count ?? 0)
            if PromptBudgetCheck.needsExactCount(characters: characters, budget: budget) {
                var total = await TokenCounter.shared.count(prompt)
                if let systemPrompt { total += await TokenCounter.shared.count(systemPrompt) }
                if total > budget {
                    throw contextOverflowError(tokenCount: total, contextSize: await TokenCounter.shared.contextSize)
                }
            }
            session = makeSession(systemPrompt: systemPrompt, options: options)
            finalPrompt = prompt
            pieces = nil
        case .messages(let json):
            var messages = try MessagesInput.decode(json)
            if let systemPrompt {
                messages.insert(OpenAIMessage(role: "system", content: .text(systemPrompt)), at: 0)
            }
            let built = try await ContextManager.makeSession(
                messages: messages, tools: nil, options: options, jsonMode: false, toolChoice: nil)
            session = built.session
            finalPrompt = built.finalPrompt
            pieces = built.finalPieces
        }
        let genOpts = makeGenerationOptions(options)

        if let schema {
            let retryMax = options.retryEnabled ? options.retryCount : 0
            let content = try await withModelRetry(maxRetries: retryMax) {
                renderer.finalJSON(try await session.respond(
                    to: makeUserPrompt(text: finalPrompt, pieces: pieces ?? [.text(finalPrompt)]),
                    schema: schema, options: genOpts).content)
            }
            // Schema-constrained decoding reports no finish reason.
            return .generated(line: record.line, customID: record.customID, content: content,
                              finishReason: nil, truncation: nil)
        }

        let result = try await processPrompt(
            prompt: finalPrompt, pieces: pieces, systemPrompt: systemPrompt, session: session,
            options: options, genOpts: genOpts, stream: false, printDelta: false,
            mcpManager: nil, hasMCPTools: false, stopSequences: stopSequences)
        let reported = CompletionPolicy.reportedFinishReason(
            result.finishReason, truncation: result.truncation,
            finishSignalExact: finishSignalExact, stopMatched: result.matchedStop != nil)
        return .generated(line: record.line, customID: record.customID, content: result.content,
                          finishReason: reported, truncation: result.truncation)
    } catch {
        let classified = classifyModelError(error)
        debugLog("batch", "line=\(record.line) error=\(classified)")
        return .failure(line: record.line, customID: record.customID, error: classified)
    }
}
