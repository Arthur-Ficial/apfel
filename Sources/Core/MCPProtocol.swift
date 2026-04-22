// ============================================================================
// MCPProtocol.swift - MCP JSON-RPC message formatting and parsing
// Part of ApfelCore - pure protocol logic, no subprocess management
// ============================================================================

import Foundation

/// Pure MCP protocol handling - message formatting and response parsing.
/// No I/O, no subprocesses - just JSON-RPC 2.0 over MCP.
public enum MCPProtocol {

    /// The MCP protocol version ApfelCore speaks on the wire.
    public static let protocolVersion = "2025-06-18"

    // MARK: - Request formatting

    /// Formats the MCP `initialize` JSON-RPC request.
    public static func initializeRequest(id: Int) -> String {
        return jsonRPC(id: id, method: "initialize", params: [
            "protocolVersion": protocolVersion,
            "capabilities": [:] as [String: Any],
            "clientInfo": ["name": "apfel", "version": "1.0.0"]
        ])
    }

    /// Formats the MCP `notifications/initialized` JSON-RPC notification.
    public static func initializedNotification() -> String {
        return jsonRPC(method: "notifications/initialized")
    }

    /// Formats the MCP `tools/list` JSON-RPC request.
    public static func toolsListRequest(id: Int) -> String {
        return jsonRPC(id: id, method: "tools/list")
    }

    /// Formats the MCP `tools/call` JSON-RPC request.
    ///
    /// - Parameters:
    ///   - id: The JSON-RPC request identifier.
    ///   - name: The tool name to invoke.
    ///   - arguments: JSON text describing the tool-call arguments.
    public static func toolsCallRequest(id: Int, name: String, arguments: String) -> String {
        let argsObj = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) ?? [:]
        return jsonRPC(id: id, method: "tools/call", params: [
            "name": name,
            "arguments": argsObj
        ])
    }

    // MARK: - Response parsing

    /// MCP server identity returned from the initialize handshake.
    public struct ServerInfo: Sendable {
        /// The server name.
        public let name: String
        /// The server version string.
        public let version: String
    }

    /// Parses the result of an MCP `initialize` response.
    public static func parseInitializeResponse(_ json: String) throws -> ServerInfo {
        let obj = try parseJSON(json)
        guard let result = obj["result"] as? [String: Any],
              let info = result["serverInfo"] as? [String: Any] else {
            throw MCPError.invalidResponse("Missing serverInfo in initialize response")
        }
        return ServerInfo(
            name: info["name"] as? String ?? "unknown",
            version: info["version"] as? String ?? "unknown"
        )
    }

    /// Parses the result of an MCP `tools/list` response into OpenAI-style tools.
    public static func parseToolsListResponse(_ json: String) throws -> [OpenAITool] {
        let obj = try parseJSON(json)
        guard let result = obj["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]] else {
            throw MCPError.invalidResponse("Missing tools in tools/list response")
        }

        return tools.compactMap { tool -> OpenAITool? in
            guard let name = tool["name"] as? String else { return nil }
            let description = tool["description"] as? String
            let schema = tool["inputSchema"] as? [String: Any]

            var parametersJSON: RawJSON?
            if let schema, let data = try? JSONSerialization.data(withJSONObject: schema),
               let str = String(data: data, encoding: .utf8) {
                parametersJSON = RawJSON(rawValue: str)
            }

            return OpenAITool(
                type: "function",
                function: OpenAIFunction(
                    name: name,
                    description: description,
                    parameters: parametersJSON
                )
            )
        }
    }

    /// Result of an MCP `tools/call` response.
    public struct ToolCallResult: Sendable {
        /// The text returned by the tool.
        public let text: String
        /// Whether the MCP server marked the result as an error.
        public let isError: Bool
    }

    /// Parses an MCP `tools/call` response.
    public static func parseToolCallResponse(_ json: String) throws -> ToolCallResult {
        let obj = try parseJSON(json)

        // JSON-RPC error
        if let error = obj["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown MCP error"
            return ToolCallResult(text: message, isError: true)
        }

        guard let result = obj["result"] as? [String: Any],
              let content = result["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw MCPError.invalidResponse("Missing content in tools/call response")
        }

        let isError = result["isError"] as? Bool ?? false
        return ToolCallResult(text: text, isError: isError)
    }

    // MARK: - Private helpers

    private static func jsonRPC(id: Int? = nil, method: String, params: [String: Any]? = nil) -> String {
        var msg: [String: Any] = ["jsonrpc": "2.0", "method": method]
        if let id { msg["id"] = id }
        if let params { msg["params"] = params }
        guard JSONSerialization.isValidJSONObject(msg),
              let data = try? JSONSerialization.data(withJSONObject: msg, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            let idFragment = id.map { #","id":\#($0)"# } ?? ""
            return #"{"jsonrpc":"2.0"\#(idFragment),"method":"\#(method)"}"#
        }
        return string
    }

    private static func parseJSON(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.invalidResponse("Invalid JSON")
        }
        return obj
    }
}

/// Stable MCP protocol and transport failures surfaced by ApfelCore.
public enum MCPError: Error, Sendable, Equatable {
    /// The server returned malformed or incomplete JSON.
    case invalidResponse(String)
    /// The remote MCP server returned an application-level error.
    case serverError(String)
    /// The requested tool does not exist.
    case toolNotFound(String)
    /// The local subprocess or transport failed.
    case processError(String)
    /// The request exceeded its timeout budget.
    case timedOut(String)
}

extension MCPError: LocalizedError, CustomStringConvertible {
    public var errorDescription: String? { description }

    public var description: String {
        switch self {
        case .invalidResponse(let message):
            return message
        case .serverError(let message):
            return message
        case .toolNotFound(let message):
            return message
        case .processError(let message):
            return message
        case .timedOut(let message):
            return message
        }
    }
}
