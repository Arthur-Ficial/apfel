// ============================================================================
// MCPClient.swift - MCP server connection and tool execution
// Part of apfel - spawns MCP servers and manages tool calling
// ============================================================================

import Foundation
import Darwin
import ApfelCore

// MARK: - Local (stdio) connection

/// A connection to a single MCP server process (stdio transport).
final class MCPConnection: @unchecked Sendable {
    private let timeoutMilliseconds: Int

    let path: String
    private(set) var tools: [OpenAITool]

    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let lineReader: BufferedLineReader
    private let lock = NSLock()
    private var nextId = 1

    init(path: String, timeoutSeconds: Int = 5) async throws {
        self.timeoutMilliseconds = timeoutSeconds * 1000
        self.path = path

        guard FileManager.default.fileExists(atPath: path) else {
            throw MCPError.processError("MCP server not found: \(path)")
        }

        let proc = Process()
        let stdinP = Pipe()
        let stdoutP = Pipe()

        if path.hasSuffix(".py") {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["python3", path]
        } else {
            proc.executableURL = URL(fileURLWithPath: path)
        }
        proc.standardInput = stdinP
        proc.standardOutput = stdoutP
        proc.standardError = FileHandle.nullDevice

        self.process = proc
        self.stdinPipe = stdinP
        self.stdoutPipe = stdoutP
        self.lineReader = BufferedLineReader(fileDescriptor: stdoutP.fileHandleForReading.fileDescriptor)
        self.tools = [] // placeholder, filled below

        try proc.run()

        do {
            // Initialize handshake
            let initResp = try sendAndReceive(
                MCPProtocol.initializeRequest(id: allocId()),
                timeoutMilliseconds: timeoutMilliseconds,
                operationDescription: "initialize"
            )
            let _ = try MCPProtocol.parseInitializeResponse(initResp)
            send(MCPProtocol.initializedNotification())

            // Discover tools
            let toolsResp = try sendAndReceive(
                MCPProtocol.toolsListRequest(id: allocId()),
                timeoutMilliseconds: timeoutMilliseconds,
                operationDescription: "tools/list"
            )
            self.tools = try MCPProtocol.parseToolsListResponse(toolsResp)
        } catch {
            if proc.isRunning {
                proc.terminate()
            }
            throw error
        }
    }

    func callTool(name: String, arguments: String) throws -> String {
        let resp: String
        do {
            resp = try sendAndReceive(
                MCPProtocol.toolsCallRequest(id: allocId(), name: name, arguments: arguments),
                timeoutMilliseconds: timeoutMilliseconds,
                operationDescription: "tool '\(name)'"
            )
        } catch {
            if case .timedOut = error as? MCPError {
                shutdown()
            }
            throw error
        }
        let result = try MCPProtocol.parseToolCallResponse(resp)
        if result.isError {
            throw MCPError.serverError("Tool '\(name)' failed: \(result.text)")
        }
        return result.text
    }

    func shutdown() {
        process.terminate()
    }

    deinit {
        if process.isRunning { process.terminate() }
    }

    // MARK: - Private

    private func allocId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    private func send(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        stdinPipe.fileHandleForWriting.write(data)
    }

    private func sendAndReceive(
        _ message: String,
        timeoutMilliseconds: Int,
        operationDescription: String
    ) throws -> String {
        send(message)
        return try lineReader.readLine(
            timeoutMilliseconds: timeoutMilliseconds,
            operationDescription: operationDescription
        )
    }
}

// MARK: - Remote (Streamable HTTP) connection

/// A connection to a remote MCP server using the Streamable HTTP transport (MCP spec 2025-03-26).
final class RemoteMCPConnection: @unchecked Sendable {
    let urlString: String
    private(set) var tools: [OpenAITool]

    private let url: URL
    private let bearerToken: String?
    private let timeoutSeconds: Int
    private let lock = NSLock()
    private var nextId = 1
    private var sessionId: String?

    init(urlString: String, bearerToken: String?, timeoutSeconds: Int = 5) async throws {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            throw MCPError.processError("Invalid MCP server URL: \(urlString) (must be http:// or https://)")
        }
        if bearerToken != nil && scheme == "http" {
            throw MCPError.processError(
                "refusing to send --mcp-token over plaintext http:// - use https:// to protect credentials"
            )
        }
        self.urlString = urlString
        self.url = url
        self.bearerToken = bearerToken
        self.timeoutSeconds = timeoutSeconds
        self.tools = []

        do {
            // Initialize handshake
            let initResp = try await post(MCPProtocol.initializeRequest(id: allocId()))
            _ = try MCPProtocol.parseInitializeResponse(initResp)

            // Send initialized notification (202, no response body needed)
            _ = try? await post(MCPProtocol.initializedNotification())

            // Discover tools
            let toolsResp = try await post(MCPProtocol.toolsListRequest(id: allocId()))
            self.tools = try MCPProtocol.parseToolsListResponse(toolsResp)
        } catch let error as MCPError {
            throw error
        } catch {
            throw MCPError.processError("Remote MCP handshake failed for \(urlString): \(error)")
        }
    }

    func callTool(name: String, arguments: String) async throws -> String {
        let resp = try await post(MCPProtocol.toolsCallRequest(id: allocId(), name: name, arguments: arguments))
        let result = try MCPProtocol.parseToolCallResponse(resp)
        if result.isError {
            throw MCPError.serverError("Tool '\(name)' failed: \(result.text)")
        }
        return result.text
    }

    func shutdown() {
        guard let sid = sessionId else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "DELETE"
        if let token = bearerToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Private

    private func allocId() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    private func post(_ body: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(timeoutSeconds))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let sid = sessionId {
            request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        }
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            // Capture session ID for subsequent requests
            if let sid = httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id") {
                sessionId = sid
            }
            // 202 Accepted = notification delivered, no body to parse
            if httpResponse.statusCode == 202 {
                return "{}"
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                throw MCPError.serverError("HTTP \(httpResponse.statusCode) from \(urlString): \(body)")
            }
        }

        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else {
            return "{}"
        }

        // Streamable HTTP servers may respond with SSE even for single responses.
        // Extract the last non-empty `data:` line and use that as the JSON payload.
        if contentType.contains("text/event-stream") {
            let payload = raw.components(separatedBy: "\n")
                .filter { $0.hasPrefix("data:") }
                .compactMap { line -> String? in
                    let value = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                    return value.isEmpty ? nil : value
                }
                .last
            return payload ?? "{}"
        }

        return raw
    }
}

// MARK: - Unified connection wrapper

/// Wraps either a local (stdio) or remote (HTTP) MCP connection.
enum AnyMCPConnection: Sendable {
    case local(MCPConnection)
    case remote(RemoteMCPConnection)

    var tools: [OpenAITool] {
        switch self {
        case .local(let c): return c.tools
        case .remote(let c): return c.tools
        }
    }

    var identifier: String {
        switch self {
        case .local(let c): return c.path
        case .remote(let c): return c.urlString
        }
    }

    func callTool(name: String, arguments: String) async throws -> String {
        switch self {
        case .local(let c):
            // Run blocking stdio I/O off the cooperative thread pool
            return try await Task.detached { try c.callTool(name: name, arguments: arguments) }.value
        case .remote(let c):
            return try await c.callTool(name: name, arguments: arguments)
        }
    }

    func shutdown() {
        switch self {
        case .local(let c): c.shutdown()
        case .remote(let c): c.shutdown()
        }
    }
}

// MARK: - Manager

/// Manages multiple MCP server connections and routes tool calls.
actor MCPManager {
    private var connections: [AnyMCPConnection] = []
    private var toolMap: [String: AnyMCPConnection] = [:]

    init(paths: [String], bearerToken: String? = nil, timeoutSeconds: Int = 5) async throws {
        for path in paths {
            let conn: AnyMCPConnection
            if path.hasPrefix("http://") || path.hasPrefix("https://") {
                let remote = try await RemoteMCPConnection(
                    urlString: path, bearerToken: bearerToken, timeoutSeconds: timeoutSeconds)
                conn = .remote(remote)
            } else {
                let absPath = path.hasPrefix("/")
                    ? path
                    : FileManager.default.currentDirectoryPath + "/" + path
                let local = try await MCPConnection(path: absPath, timeoutSeconds: timeoutSeconds)
                conn = .local(local)
            }
            connections.append(conn)
            for tool in conn.tools {
                toolMap[tool.function.name] = conn
            }
            if !quietMode {
                printStderr("\(styled("mcp:", .cyan)) \(conn.identifier) - \(conn.tools.map(\.function.name).joined(separator: ", "))")
            }
        }
    }

    func allTools() -> [OpenAITool] {
        connections.flatMap(\.tools)
    }

    func execute(name: String, arguments: String) async throws -> String {
        guard let conn = toolMap[name] else {
            throw MCPError.toolNotFound("No MCP server provides tool '\(name)'")
        }
        return try await conn.callTool(name: name, arguments: arguments)
    }

    func shutdown() {
        for conn in connections {
            conn.shutdown()
        }
    }
}
