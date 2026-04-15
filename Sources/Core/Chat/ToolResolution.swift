// ============================================================================
// ToolResolution.swift — Pure tool-source resolver
// Decides whether the request uses client-supplied tools, MCP-injected tools,
// or no tools at all.
// ============================================================================

import Foundation

public struct ResolvedTools: Sendable {
    public let tools: [OpenAITool]?
    /// True when the tools came from the server's MCP manager rather than the client.
    /// Triggers auto-execution of tool calls against MCP servers.
    public let injected: Bool
}

public enum ToolResolution {
    public static func resolve(
        clientTools: [OpenAITool]?,
        mcpTools: [OpenAITool]?
    ) -> ResolvedTools {
        if let client = clientTools, !client.isEmpty {
            return ResolvedTools(tools: client, injected: false)
        }
        if let mcp = mcpTools, !mcp.isEmpty {
            return ResolvedTools(tools: mcp, injected: true)
        }
        return ResolvedTools(tools: nil, injected: false)
    }
}
