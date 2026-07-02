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
    /// Call `validateToolArguments(name:arguments:)` first: malformed arguments
    /// hit the `[:]` formatting fallback here, which must never be reached
    /// silently with model-emitted input (#241).
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

    /// Validates model-emitted tool-call arguments before they are sent to an
    /// MCP server.
    ///
    /// The model can emit truncated or otherwise malformed JSON arguments.
    /// Those must fail loudly with a typed error the caller can surface as a
    /// retryable tool-error result - not be silently replaced with `{}` by the
    /// formatting fallback in `toolsCallRequest(id:name:arguments:)`, which
    /// makes an all-optional-params tool "succeed" with defaults (#241).
    ///
    /// Empty or whitespace-only arguments are valid (a call with no arguments).
    ///
    /// - Parameters:
    ///   - name: The tool name, used in the error message.
    ///   - arguments: JSON text describing the tool-call arguments.
    /// - Throws: `MCPError.invalidArguments` when `arguments` is non-empty and
    ///   not a JSON object or array.
    public static func validateToolArguments(name: String, arguments: String) throws {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Default options (no .fragmentsAllowed): a bare scalar is not a valid
        // MCP arguments payload either.
        guard (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil else {
            throw MCPError.invalidArguments(
                "Tool '\(name)' arguments are not valid JSON: \(trimmed.prefix(200))"
            )
        }
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
    ///
    /// Spec-legal results (#242): every `type == "text"` content block is kept
    /// and joined with newlines (not just block 0); an empty `content` array is
    /// a valid empty result; when no text blocks exist, `structuredContent`
    /// (2025-06-18 spec) is serialized as the result text. Only a result with
    /// neither `content` nor `structuredContent` is rejected.
    public static func parseToolCallResponse(_ json: String) throws -> ToolCallResult {
        let obj = try parseJSON(json)

        // JSON-RPC error
        if let error = obj["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown MCP error"
            return ToolCallResult(text: message, isError: true)
        }

        guard let result = obj["result"] as? [String: Any] else {
            throw MCPError.invalidResponse("Missing result in tools/call response")
        }
        let isError = result["isError"] as? Bool ?? false
        let content = result["content"] as? [[String: Any]]

        if let content {
            let textBlocks = content.compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }
            if !textBlocks.isEmpty {
                return ToolCallResult(text: textBlocks.joined(separator: "\n"), isError: isError)
            }
        }

        if let structured = result["structuredContent"],
           JSONSerialization.isValidJSONObject(structured),
           let data = try? JSONSerialization.data(withJSONObject: structured, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return ToolCallResult(text: text, isError: isError)
        }

        // Empty or non-text-only content (e.g. a side-effect tool) is valid.
        if content != nil {
            return ToolCallResult(text: "", isError: isError)
        }

        throw MCPError.invalidResponse("Missing content in tools/call response")
    }

    // MARK: - Incoming message routing (#217)

    /// How one incoming JSON-RPC message relates to an awaited response id.
    public enum IncomingMessage: Equatable, Sendable {
        /// The response whose `"id"` matches the awaited request id.
        case matchingResponse
        /// A notification, a response to a different id, a server request we
        /// cannot serve, or stray non-JSON noise - skip it and keep reading.
        case unrelated
        /// A server `ping` request: send `reply`, then keep reading.
        case pingRequest(reply: String)
    }

    /// Classifies one incoming stdout line against the request id being
    /// awaited.
    ///
    /// MCP servers legitimately interleave server-to-client traffic with
    /// responses (`notifications/message` logging, `ping`, ...). Returning the
    /// next line as "the response" desyncs the connection permanently after a
    /// single log line, so readers must skip everything that is not the
    /// response to the awaited id (#217).
    public static func classifyIncoming(_ json: String, awaitingId: Int) -> IncomingMessage {
        guard let data = json.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .unrelated
        }
        // Server-to-client traffic carries a method: requests have an id,
        // notifications do not. Answer pings; skip everything else.
        if let method = obj["method"] as? String {
            if method == "ping", let pingId = obj["id"] {
                let reply: [String: Any] = ["jsonrpc": "2.0", "id": pingId, "result": [:] as [String: Any]]
                if JSONSerialization.isValidJSONObject(reply),
                   let replyData = try? JSONSerialization.data(withJSONObject: reply, options: [.sortedKeys]),
                   let replyString = String(data: replyData, encoding: .utf8) {
                    return .pingRequest(reply: replyString)
                }
            }
            return .unrelated
        }
        // A response: ours only when the id matches the awaited request id.
        // Requests always carry Int ids; tolerate a server echoing it back as
        // a numeric string.
        if let id = obj["id"] as? Int, id == awaitingId {
            return .matchingResponse
        }
        if let id = obj["id"] as? String, id == String(awaitingId) {
            return .matchingResponse
        }
        return .unrelated
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
    /// The model emitted malformed tool-call arguments (#241).
    case invalidArguments(String)
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
        case .invalidArguments(let message):
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
