// MCPClientTests - TDD tests for MCP JSON-RPC protocol handling
// Tests the pure protocol logic (message formatting, parsing) without spawning processes

import Foundation
import ApfelCore

func runMCPClientTests() {

    // MARK: - JSON-RPC message formatting

    test("formatInitialize produces valid JSON-RPC") {
        let msg = MCPProtocol.initializeRequest(id: 1)
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertEqual(obj["jsonrpc"] as! String, "2.0")
        try assertEqual(obj["id"] as! Int, 1)
        try assertEqual(obj["method"] as! String, "initialize")
        let params = obj["params"] as! [String: Any]
        try assertEqual(params["protocolVersion"] as! String, "2025-06-18")
    }

    test("formatToolsList produces valid JSON-RPC") {
        let msg = MCPProtocol.toolsListRequest(id: 2)
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertEqual(obj["method"] as! String, "tools/list")
        try assertEqual(obj["id"] as! Int, 2)
    }

    test("formatToolsCall produces valid JSON-RPC") {
        let msg = MCPProtocol.toolsCallRequest(id: 3, name: "multiply", arguments: "{\"a\":247,\"b\":83}")
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertEqual(obj["method"] as! String, "tools/call")
        let params = obj["params"] as! [String: Any]
        try assertEqual(params["name"] as! String, "multiply")
        let args = params["arguments"] as! [String: Any]
        try assertEqual(args["a"] as! Int, 247)
    }

    test("formatToolsCall falls back to empty object when arguments are invalid JSON") {
        let msg = MCPProtocol.toolsCallRequest(id: 3, name: "multiply", arguments: "{not json}")
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let params = obj["params"] as! [String: Any]
        let args = params["arguments"] as! [String: Any]
        try assertEqual(args.count, 0)
    }

    test("formatToolsCall preserves JSON array arguments") {
        let msg = MCPProtocol.toolsCallRequest(id: 3, name: "sum", arguments: "[1,2,3]")
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let params = obj["params"] as! [String: Any]
        let args = params["arguments"] as! [Any]
        try assertEqual(args.count, 3)
        try assertEqual(args[0] as? Int, 1)
        try assertEqual(args[2] as? Int, 3)
    }

    test("formatNotificationInitialized has no id") {
        let msg = MCPProtocol.initializedNotification()
        let data = msg.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertEqual(obj["method"] as! String, "notifications/initialized")
        try assertNil(obj["id"])
    }

    // MARK: - Response parsing

    test("parseInitializeResponse extracts server info") {
        let json = """
        {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"calc","version":"1.0"}}}
        """
        let info = try MCPProtocol.parseInitializeResponse(json)
        try assertEqual(info.name, "calc")
        try assertEqual(info.version, "1.0")
    }

    test("parseInitializeResponse defaults missing name and version to unknown") {
        let json = """
        {"jsonrpc":"2.0","id":1,"result":{"serverInfo":{}}}
        """
        let info = try MCPProtocol.parseInitializeResponse(json)
        try assertEqual(info.name, "unknown")
        try assertEqual(info.version, "unknown")
    }

    test("parseToolsListResponse extracts tool definitions") {
        let json = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"add","description":"Add two numbers","inputSchema":{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}},"required":["a","b"]}}]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(json)
        try assertEqual(tools.count, 1)
        try assertEqual(tools[0].function.name, "add")
        try assertEqual(tools[0].function.description, "Add two numbers")
        try assertEqual(tools[0].type, "function")
    }

    test("parseToolsListResponse handles multiple tools") {
        let json = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"add","description":"Add","inputSchema":{"type":"object","properties":{}}},{"name":"multiply","description":"Multiply","inputSchema":{"type":"object","properties":{}}}]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(json)
        try assertEqual(tools.count, 2)
        try assertEqual(tools[0].function.name, "add")
        try assertEqual(tools[1].function.name, "multiply")
    }

    test("parseToolsListResponse drops nameless tool entries") {
        let json = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"description":"broken","inputSchema":{"type":"object","properties":{}}},{"name":"multiply","description":"Multiply","inputSchema":{"type":"object","properties":{}}}]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(json)
        try assertEqual(tools.count, 1)
        try assertEqual(tools[0].function.name, "multiply")
    }

    test("parseToolCallResponse extracts text result") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"20501"}],"isError":false}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "20501")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse joins all text content blocks with newline (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"first"},{"type":"text","text":"second"}],"isError":false}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "first\nsecond")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse extracts text blocks around non-text blocks (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"image","data":"aGk=","mimeType":"image/png"},{"type":"text","text":"caption"}],"isError":false}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "caption")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse accepts an empty content array as an empty result (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[],"isError":false}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse accepts non-text-only content as an empty result (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"image","data":"aGk=","mimeType":"image/png"}]}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse falls back to structuredContent when no text blocks exist (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[],"structuredContent":{"temperature":22.5,"unit":"C"}}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertTrue(result.text.contains("\"temperature\""), "must serialize structuredContent: \(result.text)")
        try assertTrue(result.text.contains("22.5"), "must serialize structuredContent values: \(result.text)")
        try assertTrue(!result.isError)
    }

    test("parseToolCallResponse handles structuredContent-only results with no content key (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"structuredContent":{"ok":true}}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertTrue(result.text.contains("\"ok\""), "must serialize structuredContent: \(result.text)")
    }

    test("parseToolCallResponse prefers text blocks over structuredContent (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"22.5C"}],"structuredContent":{"temperature":22.5}}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "22.5C")
    }

    test("parseToolCallResponse preserves isError on empty content (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[],"isError":true}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertTrue(result.isError)
    }

    test("parseToolCallResponse throws only when content and structuredContent are both missing (#242)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{}}
        """
        var thrown: MCPError?
        do {
            _ = try MCPProtocol.parseToolCallResponse(json)
        } catch let e as MCPError {
            thrown = e
        }
        guard case .invalidResponse(let message)? = thrown else {
            throw TestFailure("expected MCPError.invalidResponse, got \(String(describing: thrown))")
        }
        try assertTrue(message.contains("content"), "message must name the missing field: \(message)")
    }

    test("parseToolCallResponse detects errors") {
        let json = """
        {"jsonrpc":"2.0","id":4,"result":{"content":[{"type":"text","text":"Error: division by zero"}],"isError":true}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "Error: division by zero")
        try assertTrue(result.isError)
    }

    test("parseToolCallResponse handles JSON-RPC error") {
        let json = """
        {"jsonrpc":"2.0","id":5,"error":{"code":-32602,"message":"Unknown tool: fake"}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertTrue(result.isError)
        try assertTrue(result.text.contains("Unknown tool"))
    }

    test("parseToolCallResponse uses fallback text when JSON-RPC error omits message") {
        let json = """
        {"jsonrpc":"2.0","id":5,"error":{"code":-32603}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertTrue(result.isError)
        try assertEqual(result.text, "Unknown MCP error")
    }

    // MARK: - Edge cases

    test("parseToolsListResponse handles empty tools array") {
        let json = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(json)
        try assertEqual(tools.count, 0)
    }

    test("parseToolCallResponse handles missing isError (defaults to false)") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"42"}]}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "42")
        try assertTrue(!result.isError)
    }

    test("tool schema converts to OpenAI format with parameters") {
        let json = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"sqrt","description":"Square root","inputSchema":{"type":"object","properties":{"a":{"type":"number","description":"The number"}},"required":["a"]}}]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(json)
        try assertNotNil(tools[0].function.parameters)
    }

    // MARK: - Chat mode MCP integration (issue #37)
    // These tests verify the building blocks that chat mode must use for MCP tools.
    // The bug was that chat mode ignored MCP tools entirely.

    test("MCP tools can generate system prompt for chat session") {
        // When MCP tools are available, chat mode must inject tool instructions
        // into the session. This tests the tool → system prompt pipeline.
        let toolsJSON = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"get_boards","description":"List Jira boards","inputSchema":{"type":"object","properties":{}}}]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(toolsJSON)
        try assertEqual(tools.count, 1)
        try assertEqual(tools[0].function.name, "get_boards")

        // Convert to ToolDef for system prompt injection (same path chat mode should use)
        let toolDefs = tools.map { tool in
            ToolDef(
                name: tool.function.name,
                description: tool.function.description,
                parametersJSON: tool.function.parameters?.value
            )
        }
        let instructions = ToolCallHandler.buildFallbackPrompt(tools: toolDefs)
        let format = ToolCallHandler.buildOutputFormatInstructions(toolNames: toolDefs.map(\.name))
        try assertTrue(instructions.contains("get_boards"), "fallback prompt must contain tool name")
        try assertTrue(format.contains("tool_calls"), "format instructions must contain call format")
    }

    test("tool call detection works on streamed chat responses") {
        // In chat mode, the model response comes via streaming. After collecting
        // the full response, tool call detection must still work.
        let streamedResponse = #"{"tool_calls": [{"id": "call_chat1", "type": "function", "function": {"name": "get_boards", "arguments": "{}"}}]}"#
        let calls = ToolCallHandler.detectToolCall(in: streamedResponse)
        try assertNotNil(calls, "tool calls must be detected in chat mode responses")
        try assertEqual(calls!.count, 1)
        try assertEqual(calls!.first?.name, "get_boards")
        try assertEqual(calls!.first?.id, "call_chat1")
    }

    test("ToolLogEntry captures tool execution for multi-turn chat context") {
        // After executing a tool in chat mode, the result is captured in a ToolLogEntry
        let entry = ToolLogEntry(
            name: "get_boards",
            args: "{}",
            result: "[{\"id\": 1, \"name\": \"Sprint Board\"}]",
            isError: false
        )
        try assertEqual(entry.name, "get_boards")
        try assertTrue(entry.result.contains("Sprint Board"), "entry must contain tool output")
        try assertTrue(!entry.isError)
    }

    test("MCP tools from multiple servers merge for chat session") {
        // When multiple --mcp servers are specified, chat mode must present
        // all tools combined (same as single-query mode does).
        let server1JSON = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"add","description":"Add numbers","inputSchema":{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}}}}]}}
        """
        let server2JSON = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"multiply","description":"Multiply numbers","inputSchema":{"type":"object","properties":{"a":{"type":"number"},"b":{"type":"number"}}}}]}}
        """
        let tools1 = try MCPProtocol.parseToolsListResponse(server1JSON)
        let tools2 = try MCPProtocol.parseToolsListResponse(server2JSON)
        let allTools = tools1 + tools2
        try assertEqual(allTools.count, 2)

        // Build system prompt with combined tools (what chat mode should do)
        let toolDefs = allTools.map { tool in
            ToolDef(
                name: tool.function.name,
                description: tool.function.description,
                parametersJSON: tool.function.parameters?.value
            )
        }
        let instructions = ToolCallHandler.buildFallbackPrompt(tools: toolDefs)
        try assertTrue(instructions.contains("add"), "combined prompt must contain first tool")
        try assertTrue(instructions.contains("multiply"), "combined prompt must contain second tool")
    }

    // MARK: - Chat mode text-only tool instructions (#144)
    // Native toolDefinitions can cause the framework to intercept tool calls,
    // preventing text-based detection. Chat mode must use text-only instructions.

    test("Chat text-only instructions include all schemas even when native conversion would succeed") {
        // Reproduces the #144 scenario: tools that convert to native format just fine
        // must STILL have their schemas available as text, because chat mode cannot
        // rely on native toolDefinitions (the framework may intercept instead of
        // producing text output that detectToolCall can parse).
        let toolsJSON = """
        {"jsonrpc":"2.0","id":2,"result":{"tools":[
            {"name":"read","description":"Read a file","inputSchema":{"type":"object","properties":{"file":{"type":"string","description":"File path"}}}},
            {"name":"edit","description":"Edit a file","inputSchema":{"type":"object","properties":{"file":{"type":"string"},"content":{"type":"string"}}}}
        ]}}
        """
        let tools = try MCPProtocol.parseToolsListResponse(toolsJSON)
        try assertEqual(tools.count, 2)

        // Build text-only instructions (ALL tools as text, no native defs)
        let allToolDefs = tools.map { ToolDef(name: $0.function.name, description: $0.function.description, parametersJSON: $0.function.parameters?.value) }
        let fallbackPrompt = ToolCallHandler.buildFallbackPrompt(tools: allToolDefs)
        let formatInstructions = ToolCallHandler.buildOutputFormatInstructions(toolNames: tools.map { $0.function.name })

        // ALL tool schemas must be in the text
        try assertTrue(fallbackPrompt.contains("read"), "text must contain 'read' tool schema")
        try assertTrue(fallbackPrompt.contains("edit"), "text must contain 'edit' tool schema")
        try assertTrue(fallbackPrompt.contains("file"), "text must contain parameter names")
        try assertTrue(formatInstructions.contains("read"), "format must list 'read'")
        try assertTrue(formatInstructions.contains("edit"), "format must list 'edit'")
        try assertTrue(formatInstructions.contains("tool_calls"), "format must contain call format")
    }

    // MARK: - JSON-RPC id correlation (#217)
    // sendAndReceive must keep reading until the response whose "id" matches
    // the request id arrives: notifications (no id) and other-id responses are
    // skipped, server "ping" requests are answered.

    test("classifyIncoming matches the response with the awaited id") {
        let line = #"{"jsonrpc":"2.0","id":7,"result":{"content":[{"type":"text","text":"42"}]}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .matchingResponse)
    }

    test("classifyIncoming skips a notification (method, no id)") {
        let line = #"{"jsonrpc":"2.0","method":"notifications/message","params":{"level":"info","data":"tool starting"}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .unrelated)
    }

    test("classifyIncoming skips a response with a different id") {
        let line = #"{"jsonrpc":"2.0","id":6,"result":{}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .unrelated)
    }

    test("classifyIncoming skips an error response with a different id") {
        let line = #"{"jsonrpc":"2.0","id":6,"error":{"code":-32603,"message":"boom"}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .unrelated)
    }

    test("classifyIncoming matches an error response with the awaited id") {
        let line = #"{"jsonrpc":"2.0","id":7,"error":{"code":-32603,"message":"boom"}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .matchingResponse)
    }

    test("classifyIncoming answers a server ping request, echoing its id") {
        let line = #"{"jsonrpc":"2.0","id":9001,"method":"ping"}"#
        guard case .pingRequest(let reply) = MCPProtocol.classifyIncoming(line, awaitingId: 7) else {
            throw TestFailure("expected .pingRequest")
        }
        let obj = try JSONSerialization.jsonObject(with: Data(reply.utf8)) as! [String: Any]
        try assertEqual(obj["jsonrpc"] as! String, "2.0")
        try assertEqual(obj["id"] as! Int, 9001)
        try assertEqual((obj["result"] as! [String: Any]).count, 0)
        try assertNil(obj["method"])
    }

    test("classifyIncoming answers a ping with a string id, echoing it verbatim") {
        let line = #"{"jsonrpc":"2.0","id":"ping-1","method":"ping"}"#
        guard case .pingRequest(let reply) = MCPProtocol.classifyIncoming(line, awaitingId: 7) else {
            throw TestFailure("expected .pingRequest")
        }
        let obj = try JSONSerialization.jsonObject(with: Data(reply.utf8)) as! [String: Any]
        try assertEqual(obj["id"] as! String, "ping-1")
    }

    test("classifyIncoming skips a non-ping server request") {
        let line = #"{"jsonrpc":"2.0","id":9002,"method":"roots/list"}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .unrelated)
    }

    test("classifyIncoming skips stray non-JSON stdout noise") {
        try assertEqual(MCPProtocol.classifyIncoming("INFO: server warming up", awaitingId: 7), .unrelated)
    }

    test("classifyIncoming matches a string-typed echo of the awaited id") {
        let line = #"{"jsonrpc":"2.0","id":"7","result":{}}"#
        try assertEqual(MCPProtocol.classifyIncoming(line, awaitingId: 7), .matchingResponse)
    }

    test("classifyIncoming skips an id-less, method-less message") {
        try assertEqual(MCPProtocol.classifyIncoming(#"{"jsonrpc":"2.0"}"#, awaitingId: 7), .unrelated)
    }

    // MARK: - Malformed model-emitted arguments must fail loudly (#241)
    // The formatting fallback in toolsCallRequest silently replaced malformed
    // JSON with {}; the call sites must validate first and throw a typed error.

    test("validateToolArguments accepts a JSON object") {
        try MCPProtocol.validateToolArguments(name: "multiply", arguments: "{\"a\":247,\"b\":83}")
    }

    test("validateToolArguments accepts a JSON array") {
        try MCPProtocol.validateToolArguments(name: "sum", arguments: "[1,2,3]")
    }

    test("validateToolArguments accepts empty and whitespace-only arguments") {
        try MCPProtocol.validateToolArguments(name: "list", arguments: "")
        try MCPProtocol.validateToolArguments(name: "list", arguments: "  \n")
    }

    test("validateToolArguments throws typed invalidArguments on truncated JSON") {
        var thrown: MCPError?
        do {
            try MCPProtocol.validateToolArguments(name: "get_weather", arguments: "{\"lat\": 48.2, \"lon\":")
        } catch let e as MCPError {
            thrown = e
        }
        guard case .invalidArguments(let message)? = thrown else {
            throw TestFailure("expected MCPError.invalidArguments, got \(String(describing: thrown))")
        }
        try assertTrue(message.contains("get_weather"), "message must name the tool: \(message)")
        try assertTrue(message.contains("not valid JSON"), "message must say the arguments are invalid: \(message)")
        try assertTrue(message.contains("lat"), "message must include the offending arguments: \(message)")
    }

    test("validateToolArguments throws typed invalidArguments on unquoted-key JSON") {
        var thrown: MCPError?
        do {
            try MCPProtocol.validateToolArguments(name: "multiply", arguments: "{a: 1, b: 2}")
        } catch let e as MCPError {
            thrown = e
        }
        guard case .invalidArguments = thrown else {
            throw TestFailure("expected MCPError.invalidArguments, got \(String(describing: thrown))")
        }
    }

    test("validateToolArguments rejects a bare scalar (not an object or array)") {
        var thrown: MCPError?
        do {
            try MCPProtocol.validateToolArguments(name: "multiply", arguments: "42")
        } catch let e as MCPError {
            thrown = e
        }
        guard case .invalidArguments = thrown else {
            throw TestFailure("expected MCPError.invalidArguments, got \(String(describing: thrown))")
        }
    }

    test("MCPError.invalidArguments description carries the message") {
        let err = MCPError.invalidArguments("Tool 'x' arguments are not valid JSON")
        try assertEqual("\(err)", "Tool 'x' arguments are not valid JSON")
    }

    test("Tool call detection works on object-argument format from #144 report") {
        // The #144 reporter showed the model producing arguments as a JSON object
        // (not an escaped string). Detection must handle both forms.
        let modelOutput = #"{"tool_calls": [{"id": "call_001", "type": "function", "function": {"name": "read", "arguments": {"file": "CLAUDE.md"}}}]}"#
        let calls = ToolCallHandler.detectToolCall(in: modelOutput)
        try assertNotNil(calls, "tool calls must be detected with object arguments")
        try assertEqual(calls!.count, 1)
        try assertEqual(calls!.first?.name, "read")
        try assertEqual(calls!.first?.id, "call_001")
        try assertTrue(calls!.first!.argumentsString.contains("CLAUDE.md"), "arguments must contain the file path")
    }
}
