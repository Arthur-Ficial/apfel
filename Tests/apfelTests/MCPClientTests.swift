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

    test("parseToolCallResponse returns the first content item when multiple are present") {
        let json = """
        {"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"first"},{"type":"text","text":"second"}],"isError":false}}
        """
        let result = try MCPProtocol.parseToolCallResponse(json)
        try assertEqual(result.text, "first")
        try assertTrue(!result.isError)
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
}
