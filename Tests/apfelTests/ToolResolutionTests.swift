// ============================================================================
// ToolResolutionTests.swift — Unit tests for the pure tool-source resolver
// that decides whether to use client-supplied tools, MCP-injected tools, or none.
// ============================================================================

import Foundation
import ApfelCore

func runToolResolutionTests() {
    let dummyClientTool = OpenAITool(
        type: "function",
        function: OpenAIFunction(name: "client_fn", description: "c", parameters: nil))
    let dummyMCPTool = OpenAITool(
        type: "function",
        function: OpenAIFunction(name: "mcp_fn", description: "m", parameters: nil))

    test("client tools present: client wins, not injected") {
        let r = ToolResolution.resolve(clientTools: [dummyClientTool], mcpTools: [dummyMCPTool])
        try assertEqual(r.tools?.count ?? 0, 1)
        try assertEqual(r.tools?.first?.function.name, "client_fn")
        try assertEqual(r.injected, false)
    }

    test("no client tools, MCP available: MCP wins, injected=true") {
        let r = ToolResolution.resolve(clientTools: nil, mcpTools: [dummyMCPTool])
        try assertEqual(r.tools?.count ?? 0, 1)
        try assertEqual(r.tools?.first?.function.name, "mcp_fn")
        try assertEqual(r.injected, true)
    }

    test("empty client tools array, MCP available: MCP wins, injected=true") {
        let r = ToolResolution.resolve(clientTools: [], mcpTools: [dummyMCPTool])
        try assertEqual(r.tools?.first?.function.name, "mcp_fn")
        try assertEqual(r.injected, true)
    }

    test("no client tools, no MCP: nil tools, not injected") {
        let r = ToolResolution.resolve(clientTools: nil, mcpTools: nil)
        try assertNil(r.tools)
        try assertEqual(r.injected, false)
    }

    test("no client tools, empty MCP list: empty tools, not injected") {
        let r = ToolResolution.resolve(clientTools: nil, mcpTools: [])
        try assertNil(r.tools)
        try assertEqual(r.injected, false)
    }

    test("client tools present even when MCP empty: client wins") {
        let r = ToolResolution.resolve(clientTools: [dummyClientTool], mcpTools: [])
        try assertEqual(r.tools?.first?.function.name, "client_fn")
        try assertEqual(r.injected, false)
    }
}
