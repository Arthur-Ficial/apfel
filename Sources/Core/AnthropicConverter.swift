// ============================================================================
// AnthropicConverter.swift — Pure INPUT-side converter.
//
// Turns an `AnthropicMessagesRequest` into the existing `ChatCompletionRequest`
// so the whole ContextManager.makeSession / ToolResolution / Session / token
// pipeline is reused verbatim. The OUTPUT side (Anthropic response + SSE) is
// emitted separately by AnthropicHandlers.
//
// Pure: no FoundationModels, unit-testable.
// ============================================================================

import Foundation

public enum AnthropicConverter {
    /// Convert an Anthropic Messages API request into an OpenAI-style
    /// `ChatCompletionRequest`.
    ///
    /// Mapping:
    ///   - `system` string          -> leading `OpenAIMessage(.system, .text)`
    ///   - user/assistant text       -> `OpenAIMessage(.user/.assistant, .text(joined))`
    ///   - assistant `tool_use`      -> `OpenAIMessage(.assistant, tool_calls:[ToolCall])`
    ///   - user `tool_result`        -> one `OpenAIMessage(.tool, tool_call_id, content)` per result
    ///   - image blocks              -> ignored (text placeholder, never crash)
    ///   - `tools`                   -> `[OpenAITool(function:{name,description,parameters})]`
    ///   - `tool_choice`             -> any->.required, none->.none, tool->.specific, auto/absent->nil
    ///   - `output_config.format`    -> `response_format` json_schema
    ///   - temperature/top_p/max_tokens/stream -> passthrough
    public static func toChatCompletionRequest(_ req: AnthropicMessagesRequest) -> ChatCompletionRequest {
        var messages: [OpenAIMessage] = []

        // Leading system message.
        if let system = req.system, !system.isEmpty {
            messages.append(OpenAIMessage(role: "system", content: .text(system)))
        }

        for message in req.messages {
            messages.append(contentsOf: convert(message: message))
        }

        // Tools.
        let tools: [OpenAITool]? = req.tools.map { anthropicTools in
            anthropicTools.map { tool in
                OpenAITool(
                    type: "function",
                    function: OpenAIFunction(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.inputSchema
                    )
                )
            }
        }

        // Tool choice.
        let toolChoice: ToolChoice? = req.toolChoice.flatMap { choice in
            switch choice {
            case .any: return .required
            case .none: return ToolChoice.none
            case .tool(let name): return .specific(name: name)
            case .auto: return nil
            }
        }

        // Structured output via output_config.format = json_schema.
        var responseFormat: ResponseFormat?
        if let format = req.outputConfig?.format, format.type == "json_schema" {
            responseFormat = ResponseFormat(
                type: "json_schema",
                json_schema: JSONSchemaSpec(name: "response", schema: format.schema, strict: nil)
            )
        }

        return ChatCompletionRequest(
            model: req.model,
            messages: messages,
            stream: req.stream,
            temperature: req.temperature,
            top_p: req.topP,
            max_tokens: req.maxTokens,
            tools: tools,
            tool_choice: toolChoice,
            response_format: responseFormat
        )
    }

    /// Convert one Anthropic message into one or more OpenAI messages.
    private static func convert(message: AnthropicMessage) -> [OpenAIMessage] {
        let blocks = message.content.asBlocks
        var out: [OpenAIMessage] = []

        // Collect text + tool_use / tool_result separately.
        var textSegments: [String] = []
        var toolCalls: [ToolCall] = []

        for block in blocks {
            switch block {
            case .text(let t):
                textSegments.append(t)
            case .image:
                // apfel is text-only: placeholder, never crash.
                textSegments.append("[image omitted]")
            case .toolUse(let id, let name, let input):
                toolCalls.append(ToolCall(
                    id: id,
                    type: "function",
                    function: ToolCallFunction(name: name, arguments: input.value)
                ))
            case .toolResult(let toolUseID, let content, _):
                // Each tool_result becomes its own tool-role message.
                out.append(OpenAIMessage(
                    role: "tool",
                    content: .text(content),
                    tool_call_id: toolUseID
                ))
            }
        }

        let joinedText = textSegments.joined()

        if message.role == "assistant", !toolCalls.isEmpty {
            // Assistant turn with tool calls. Carry any text alongside.
            out.append(OpenAIMessage(
                role: "assistant",
                content: joinedText.isEmpty ? nil : .text(joinedText),
                tool_calls: toolCalls
            ))
        } else if !joinedText.isEmpty || (out.isEmpty && toolCalls.isEmpty) {
            // Plain text message (user or assistant). Always emit at least an
            // empty message when there were no tool blocks, so the turn survives.
            let role = (message.role == "assistant") ? "assistant" : "user"
            // Don't emit an empty user/assistant message when tool_result blocks
            // already produced messages for this turn.
            if !joinedText.isEmpty {
                out.append(OpenAIMessage(role: role, content: .text(joinedText)))
            } else if out.isEmpty {
                out.append(OpenAIMessage(role: role, content: .text("")))
            }
        }

        return out
    }
}
