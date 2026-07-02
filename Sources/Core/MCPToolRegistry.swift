// ============================================================================
// MCPToolRegistry.swift - Tool-name collision detection and dedup across
// multiple MCP servers (#239). Pure logic, no subprocess/IO - part of ApfelCore.
// ============================================================================

import Foundation

/// Resolves tool-name collisions when several `--mcp` servers expose a tool
/// with the same name.
///
/// Policy: first registration wins. The first server that exposes a name owns
/// it; any later server exposing the same name is shadowed and its variant is
/// unreachable. This keeps routing predictable (no rename surprises) at the cost
/// of the shadowed tool - `collisions(servers:)` surfaces the shadowing so the
/// caller can warn loudly, and `deduplicate(_:)` drops the shadowed duplicates
/// so they are not injected into the 4096-token prompt twice.
public enum MCPToolRegistry {

    /// A tool name exposed by more than one server.
    public struct Collision: Equatable, Sendable {
        /// The colliding tool name.
        public let toolName: String
        /// The first server that registered the name (it wins).
        public let keptServer: String
        /// The later server whose same-named tool is shadowed/ignored.
        public let ignoredServer: String

        public init(toolName: String, keptServer: String, ignoredServer: String) {
            self.toolName = toolName
            self.keptServer = keptServer
            self.ignoredServer = ignoredServer
        }
    }

    /// Detect tool-name collisions across servers, in registration order.
    ///
    /// - Parameter servers: ordered `(server id, tool names)` pairs, in the
    ///   order the servers were registered.
    /// - Returns: one `Collision` per (name, shadowed server) pair, attributing
    ///   each duplicate to the first server that owns the name.
    public static func collisions(servers: [(id: String, toolNames: [String])]) -> [Collision] {
        var owner: [String: String] = [:]
        var result: [Collision] = []
        for server in servers {
            for name in server.toolNames {
                if let keptServer = owner[name] {
                    result.append(Collision(toolName: name, keptServer: keptServer, ignoredServer: server.id))
                } else {
                    owner[name] = server.id
                }
            }
        }
        return result
    }

    /// Deduplicate an ordered tool list by function name, keeping the first
    /// occurrence of each name (first registration wins).
    public static func deduplicate(_ tools: [OpenAITool]) -> [OpenAITool] {
        var seen: Set<String> = []
        var result: [OpenAITool] = []
        for tool in tools where seen.insert(tool.function.name).inserted {
            result.append(tool)
        }
        return result
    }
}
