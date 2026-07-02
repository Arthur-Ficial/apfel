// ============================================================================
// MCPToolRegistryTests.swift - Pure MCP tool-name dedup/collision logic (#239)
// ============================================================================

import Foundation
import ApfelCore

private func tool(_ name: String) -> OpenAITool {
    OpenAITool(type: "function", function: OpenAIFunction(name: name, description: nil, parameters: nil))
}

func runMCPToolRegistryTests() {

    // MARK: - deduplicate (first registration wins)

    test("deduplicate keeps first occurrence of a duplicated name (#239)") {
        let deduped = MCPToolRegistry.deduplicate([tool("search"), tool("read"), tool("search")])
        try assertEqual(deduped.map(\.function.name), ["search", "read"])
    }

    test("deduplicate leaves a collision-free list unchanged (#239)") {
        let deduped = MCPToolRegistry.deduplicate([tool("a"), tool("b"), tool("c")])
        try assertEqual(deduped.map(\.function.name), ["a", "b", "c"])
    }

    test("deduplicate on empty input returns empty (#239)") {
        try assertTrue(MCPToolRegistry.deduplicate([]).isEmpty)
    }

    // MARK: - collisions (warning source)

    test("collisions reports the shadowed server, first server wins (#239)") {
        let found = MCPToolRegistry.collisions(servers: [
            (id: "fs-server.py", toolNames: ["search", "read"]),
            (id: "git-server.py", toolNames: ["search", "log"]),
        ])
        try assertEqual(found.count, 1)
        try assertEqual(found[0].toolName, "search")
        try assertEqual(found[0].keptServer, "fs-server.py")
        try assertEqual(found[0].ignoredServer, "git-server.py")
    }

    test("collisions is empty when all names are unique (#239)") {
        let found = MCPToolRegistry.collisions(servers: [
            (id: "s1", toolNames: ["a", "b"]),
            (id: "s2", toolNames: ["c", "d"]),
        ])
        try assertTrue(found.isEmpty)
    }

    test("collisions attributes each duplicate to the first server that owns the name (#239)") {
        let found = MCPToolRegistry.collisions(servers: [
            (id: "s1", toolNames: ["x"]),
            (id: "s2", toolNames: ["x"]),
            (id: "s3", toolNames: ["x"]),
        ])
        try assertEqual(found.count, 2)
        try assertEqual(found[0].keptServer, "s1")
        try assertEqual(found[0].ignoredServer, "s2")
        try assertEqual(found[1].keptServer, "s1")
        try assertEqual(found[1].ignoredServer, "s3")
    }
}
