// ============================================================================
// ContextManager.swift — Convert OpenAI messages to LanguageModelSession
// Part of apfel — Apple Intelligence from the command line
//
// Uses FoundationModels Transcript API to reconstruct session state from
// OpenAI's stateless message history — NO re-inference on history.
// Uses native Transcript.ToolDefinition and Transcript.ToolCalls where possible.
// ============================================================================

import FoundationModels
import Foundation
import ApfelCore

package enum ContextManager {

    // MARK: - Session Factory

    /// Build a LanguageModelSession from OpenAI messages + optional tools.
    /// Returns the session (with history baked in) + the final user prompt.
    ///
    /// Architecture:
    /// - system message → Transcript.Instructions (with native ToolDefinitions)
    /// - user messages in history → Transcript.Prompt
    /// - assistant tool_calls → Transcript.ToolCalls (native, not serialized JSON)
    /// - assistant text → Transcript.Response
    /// - tool result messages → Transcript.ToolOutput
    /// - last user message → returned as finalPrompt (caller sends it via respond())
    public static func makeSession(
        messages: [OpenAIMessage],
        tools: [OpenAITool]?,
        options: SessionOptions,
        jsonMode: Bool = false,
        toolChoice: ToolChoice? = nil,
        responseSchema: GenerationSchema? = nil
    ) async throws -> (session: LanguageModelSession, finalPrompt: String, inputEntries: [Transcript.Entry], finalPieces: [PromptPiece]) {
        let prepared = try await prepareEntries(
            messages: messages, tools: tools, options: options, jsonMode: jsonMode,
            toolChoice: toolChoice, responseSchema: responseSchema)
        let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
        guard let entries = await trimHistoryEntriesToBudget(
            baseEntries: prepared.base,
            historyEntries: prepared.history,
            finalEntry: prepared.final,
            budget: budget,
            config: options.contextConfig,
            // A trailing tool result is answered from its exchange: keep that
            // exchange whole and in the window (#482).
            pinLast: prepared.pinsTrailingExchange
        ) else {
            // Overflow with the same detail the runtime's typed
            // contextSizeExceeded would carry (macOS 27): the counted input
            // tokens and the runtime-reported window. On macOS 26 this is
            // the unchanged generic .contextOverflow (#510, #197).
            let inputTokens = await TokenCounter.shared.countInput(
                entries: prepared.base + prepared.history + [prepared.final])
            throw contextOverflowError(
                tokenCount: inputTokens,
                contextSize: await TokenCounter.shared.contextSize)
        }

        let session = makeTranscriptSession(model: makeModel(permissive: options.permissive), entries: entries)
        return (session, prepared.finalPrompt, entries, prepared.finalPieces)
    }

    /// The transcript entries for a conversation before any trimming: the
    /// instructions block, one entry per history message, and the final prompt
    /// entry that callers send separately via respond(). Also used to price a
    /// follow-up exactly as it will be built (#221, #482).
    public struct PreparedEntries {
        public let base: [Transcript.Entry]
        public let history: [Transcript.Entry]
        public let final: Transcript.Entry
        public let finalPrompt: String
        /// The final user turn's ordered text/image pieces (#510). Callers
        /// build the respond() prompt from these; text-only turns carry one
        /// text piece and behave exactly as before.
        public let finalPieces: [PromptPiece]
        /// True when the conversation ends with a tool result, whose exchange
        /// must stay whole and in the window (#482).
        public let pinsTrailingExchange: Bool
    }

    /// `responseSchema` is a structured-output schema the caller will pass to
    /// respond(schema:). The runtime prices it as part of the prompt, so the
    /// final entry carries it as its response format and every budget check
    /// and token preflight sees that overhead (#485).
    public static func prepareEntries(
        messages: [OpenAIMessage],
        tools: [OpenAITool]?,
        options: SessionOptions,
        jsonMode: Bool = false,
        toolChoice: ToolChoice? = nil,
        responseSchema: GenerationSchema? = nil
    ) async throws -> PreparedEntries {
        // Instruction roles never take a conversation turn -- they are folded
        // into the instructions block below. `developer` used to survive this
        // filter, then get dropped by historyEntry's nil return, which is the
        // silent history loss #405 is about.
        let conversation = messages.filter {
            ![OpenAIMessage].instructionRoles.contains($0.role)
        }
        let effectiveTools: [OpenAITool]?
        if case .some(.none) = toolChoice {
            effectiveTools = nil
        } else {
            effectiveTools = tools
        }

        // When last message is role:"tool", the model should respond using the tool result.
        // We put all messages (including the tool result) into history and use a
        // synthetic prompt asking the model to respond based on the tool output.
        let finalPrompt: String
        let finalPieces: [PromptPiece]
        let history: [OpenAIMessage]
        if conversation.last?.role == "tool" {
            finalPrompt = "Respond to the user based on the tool result above."
            finalPieces = [.text(finalPrompt)]
            history = conversation
        } else if let last = conversation.last, last.containsImageContent {
            // An image-bearing final user turn (#510): decode the images and
            // keep the pieces in part order. Text may legitimately be empty -
            // the image IS the prompt then.
            let pieces = try promptPieces(of: last)
            finalPrompt = last.textIgnoringImages ?? ""
            finalPieces = pieces
            history = Array(conversation.dropLast())
        } else {
            guard let text = conversation.last?.textContent, !text.isEmpty else {
                throw ApfelError.unknown("Last message has no text content")
            }
            finalPrompt = text
            finalPieces = [.text(text)]
            history = Array(conversation.dropLast())
        }

        // All tool schemas are rendered as instruction text (#555): on macOS 27
        // transcript-only ToolDefinitions are silently ignored when the session
        // has no registered tools, so descriptions and parameter schemas never
        // reach the model. Text rendering matches the CLI chat-mode pattern
        // (#144) and keeps the token budget aligned with what the runtime sees.
        var textToolDefs: [ToolDef] = []
        if let tools = effectiveTools, !tools.isEmpty {
            textToolDefs = tools.map {
                ToolDef(
                    name: $0.function.name,
                    description: $0.function.description,
                    parametersJSON: $0.function.parameters?.value
                )
            }
        }

        // Build instruction text
        let instrText = buildInstructions(
            messages: messages,
            tools: effectiveTools,
            textToolDefs: textToolDefs,
            jsonMode: jsonMode,
            toolChoice: toolChoice
        )

        // Build transcript entries
        var baseEntries: [Transcript.Entry] = []

        // Instructions with tool schemas as text (#555)
        if !instrText.isEmpty {
            let segments: [Transcript.Segment] = [
                .text(Transcript.TextSegment(content: instrText))
            ]
            let instr = Transcript.Instructions(segments: segments, toolDefinitions: [])
            baseEntries.append(.instructions(instr))
        }

        // Tool results resolve their name through the call they answer (#482).
        let callNames = ToolExchangeGrouping.callNames(in: history)
        let historyEntries = try history.compactMap { try historyEntry(for: $0, options: options, callNames: callNames) }
        // Image-bearing final turns are built from their pieces so the entry
        // matches what respond() will actually send (#510); the text-only
        // path is byte-identical to before.
        let finalEntry = hasImagePiece(finalPieces)
            ? makePromptEntry(pieces: finalPieces, options: options, responseSchema: responseSchema)
            : makePromptEntry(finalPrompt, options: options, responseSchema: responseSchema)
        return PreparedEntries(
            base: baseEntries,
            history: historyEntries,
            final: finalEntry,
            finalPrompt: finalPrompt,
            finalPieces: finalPieces,
            pinsTrailingExchange: conversation.last?.role == "tool"
        )
    }

    // MARK: - Instructions Builder

    private static func buildInstructions(
        messages: [OpenAIMessage],
        tools: [OpenAITool]?,
        textToolDefs: [ToolDef],
        jsonMode: Bool,
        toolChoice: ToolChoice?
    ) -> String {
        var parts: [String] = []

        // JSON mode instruction
        if jsonMode {
            parts.append("You must respond with valid JSON only. No markdown code fences, no explanation text, no preamble. Output raw JSON.")
        }

        // Every system/developer message, in order - not just the first (#390, #405)
        if let instructions = messages.joinedInstructionContent {
            parts.append(instructions)
        }

        if case .some(.none) = toolChoice {
            parts.append("Do not call any tools. Respond with plain text only.")
        }

        // Tool output format instructions (always needed when tools are present)
        if let tools = tools, !tools.isEmpty {
            let names = tools.map(\.function.name)
            parts.append(ToolCallHandler.buildOutputFormatInstructions(toolNames: names))
            switch toolChoice {
            case .some(.required):
                parts.append("You must call one of the available functions in your next response. Do not answer with plain text.")
            case .some(.specific(let name)):
                parts.append("You must call the function \(name) in your next response. Do not answer with plain text.")
            default:
                break
            }
        }

        // All tool schemas as text so the model sees descriptions and
        // parameters (#555); native ToolDefinitions are no longer used.
        if !textToolDefs.isEmpty {
            parts.append(ToolCallHandler.buildToolSchemaPrompt(tools: textToolDefs))
        }

        return parts.joined(separator: "\n\n")
    }

    private static func historyEntry(
        for message: OpenAIMessage,
        options: SessionOptions,
        callNames: [String: String]
    ) throws -> Transcript.Entry? {
        switch message.role {
        case "user":
            // An image-bearing history turn keeps its images as native
            // attachment segments (macOS 27, #510) so they survive trimming,
            // tool-round session rebuilds, and retries.
            if message.containsImageContent {
                let pieces = try promptPieces(of: message)
                guard !pieces.isEmpty else { return nil }
                return makePromptEntry(pieces: pieces, options: options)
            }
            guard let text = message.textContent else { return nil }
            return makePromptEntry(text, options: options)

        case "assistant":
            if let calls = message.tool_calls, !calls.isEmpty {
                let transcriptCalls = calls.compactMap { call -> Transcript.ToolCall? in
                    // Unparseable client-supplied arguments must not drop the
                    // call and orphan its results (#482): keep it with empty
                    // arguments instead.
                    guard let arguments = SchemaConverter.makeArguments(call.function.arguments)
                            ?? SchemaConverter.makeArguments("{}") else {
                        return nil
                    }
                    return Transcript.ToolCall(
                        id: call.id,
                        toolName: call.function.name,
                        arguments: arguments
                    )
                }
                guard !transcriptCalls.isEmpty else { return nil }
                return .toolCalls(Transcript.ToolCalls(transcriptCalls))
            }

            let text = message.textContent ?? ""
            let segment = Transcript.TextSegment(content: text)
            return .response(Transcript.Response(assetIDs: [], segments: [.text(segment)]))

        case "tool":
            let text = message.textContent ?? ""
            let segment = Transcript.TextSegment(content: text)
            let output = Transcript.ToolOutput(
                id: message.tool_call_id ?? UUID().uuidString,
                toolName: message.tool_call_id.flatMap { callNames[$0] } ?? message.name ?? "tool",
                segments: [.text(segment)]
            )
            return .toolOutput(output)

        default:
            return nil
        }
    }
}
