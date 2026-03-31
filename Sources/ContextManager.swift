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

enum ContextManager {

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
    static func makeSession(
        messages: [OpenAIMessage],
        tools: [OpenAITool]?,
        options: SessionOptions,
        jsonMode: Bool = false,
        toolChoice: ToolChoice? = nil
    ) async throws -> (session: LanguageModelSession, finalPrompt: String) {
        let conversation = messages.filter { $0.role != "system" }
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
        let history: [OpenAIMessage]
        if conversation.last?.role == "tool" {
            finalPrompt = "Respond to the user based on the tool result above."
            history = conversation
        } else {
            guard let text = conversation.last?.textContent, !text.isEmpty else {
                throw ApfelError.unknown("Last message has no text content")
            }
            finalPrompt = text
            history = Array(conversation.dropLast())
        }
        let model = makeModel(permissive: options.permissive)

        // Convert tools: native ToolDefinitions + text fallback for failures
        var nativeToolDefs: [Transcript.ToolDefinition] = []
        var fallbackTools: [ToolDef] = []
        if let tools = effectiveTools, !tools.isEmpty {
            let converted = SchemaConverter.convert(tools: tools)
            nativeToolDefs = converted.native
            fallbackTools = converted.fallback
        }

        // Build instruction text
        let instrText = buildInstructions(
            messages: messages,
            tools: effectiveTools,
            fallbackTools: fallbackTools,
            jsonMode: jsonMode,
            toolChoice: toolChoice
        )

        // Build transcript entries
        var baseEntries: [Transcript.Entry] = []

        // Instructions with native tool definitions
        if !instrText.isEmpty || !nativeToolDefs.isEmpty {
            let segments: [Transcript.Segment] = instrText.isEmpty ? [] : [
                .text(Transcript.TextSegment(content: instrText))
            ]
            let instr = Transcript.Instructions(segments: segments, toolDefinitions: nativeToolDefs)
            baseEntries.append(.instructions(instr))
        }

        let historyEntries = history.compactMap { historyEntry(for: $0, options: options) }
        let finalPromptEntry = makePromptEntry(finalPrompt, options: options)
        let budget = await TokenCounter.shared.inputBudget(reservedForOutput: options.contextConfig.outputReserve)
        guard let entries = await trimHistoryEntriesToBudget(
            baseEntries: baseEntries,
            historyEntries: historyEntries,
            finalEntry: finalPromptEntry,
            budget: budget,
            config: options.contextConfig
        ) else {
            throw ApfelError.contextOverflow
        }

        let session = makeTranscriptSession(model: model, entries: entries)
        return (session, finalPrompt)
    }

    // MARK: - Instructions Builder

    private static func buildInstructions(
        messages: [OpenAIMessage],
        tools: [OpenAITool]?,
        fallbackTools: [ToolDef],
        jsonMode: Bool,
        toolChoice: ToolChoice?
    ) -> String {
        var parts: [String] = []

        // JSON mode instruction
        if jsonMode {
            parts.append("You must respond with valid JSON only. No markdown code fences, no explanation text, no preamble. Output raw JSON.")
        }

        // System prompt
        if let sys = messages.first(where: { $0.role == "system" })?.textContent {
            parts.append(sys)
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

        // Text fallback for tools that failed native conversion
        if !fallbackTools.isEmpty {
            parts.append(ToolCallHandler.buildFallbackPrompt(tools: fallbackTools))
        }

        return parts.joined(separator: "\n\n")
    }

    private static func historyEntry(
        for message: OpenAIMessage,
        options: SessionOptions
    ) -> Transcript.Entry? {
        switch message.role {
        case "user":
            guard let text = message.textContent else { return nil }
            return makePromptEntry(text, options: options)

        case "assistant":
            if let calls = message.tool_calls, !calls.isEmpty {
                let transcriptCalls = calls.map { call in
                    Transcript.ToolCall(
                        id: call.id,
                        toolName: call.function.name,
                        arguments: SchemaConverter.makeArguments(call.function.arguments)
                    )
                }
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
                toolName: message.name ?? "tool",
                segments: [.text(segment)]
            )
            return .toolOutput(output)

        default:
            return nil
        }
    }
}
