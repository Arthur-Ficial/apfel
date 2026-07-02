// ============================================================================
// MCPClient.swift - MCP server connection and tool execution
// Part of apfel - spawns MCP servers and manages tool calling
// ============================================================================

import Foundation
import Darwin
import ApfelCore

/// Grace period after SIGTERM before escalating to SIGKILL when reaping a local
/// MCP child (#216).
private let mcpShutdownGraceSeconds: TimeInterval = 2.0

/// A connection to a single MCP server process (stdio transport).
///
/// Thread safety (justifying `@unchecked Sendable`): in `--serve` mode,
/// `AnyMCPConnection.callTool` runs this connection's blocking stdio I/O via
/// `Task.detached`, so concurrent requests reach one instance from multiple
/// threads. All mutable state is confined behind locks: `nextId` is guarded by
/// `lock` (`allocId()`), and every wire exchange - the full send+receive pair
/// in `sendAndReceive` and standalone notification writes via `sendLocked` -
/// is serialized by `ioLock`, so two concurrent tool calls can neither
/// interleave stdin writes (corruption for payloads > PIPE_BUF) nor consume
/// each other's stdout lines (cross-delivered or dropped responses, #218).
/// `tools` is written once during `init`, before the instance is published to
/// any other thread, and is read-only afterwards. `process`, the pipes, and
/// `lineReader` are `let` bindings set in `init`; post-init writes to the
/// child's stdin all go through the `ioLock`-guarded paths.
final class MCPConnection: @unchecked Sendable {
    private let timeoutMilliseconds: Int

    let path: String
    private(set) var tools: [OpenAITool]

    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let lineReader: BufferedLineReader
    private let lock = NSLock()
    /// Serializes complete wire exchanges (send+receive) per connection (#218).
    private let ioLock = NSLock()
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
        // Scrub the child's environment so a third-party MCP script never
        // inherits APFEL_TOKEN/APFEL_MCP_TOKEN or any cloud/API keys in the
        // shell. With environment == nil, Process inherits the full parent env
        // (#229). The allowlist keeps what python3/FastMCP/venv servers need.
        proc.environment = ServerSecurity.scrubbedMCPEnvironment(from: ProcessInfo.processInfo.environment)

        self.process = proc
        self.stdinPipe = stdinP
        self.stdoutPipe = stdoutP
        self.lineReader = BufferedLineReader(fileDescriptor: stdoutP.fileHandleForReading.fileDescriptor)
        self.tools = [] // placeholder, filled below

        try proc.run()

        do {
            // Initialize handshake
            let initId = allocId()
            let initResp = try sendAndReceive(
                MCPProtocol.initializeRequest(id: initId),
                id: initId,
                timeoutMilliseconds: timeoutMilliseconds,
                operationDescription: "initialize"
            )
            let _ = try MCPProtocol.parseInitializeResponse(initResp)
            try sendLocked(MCPProtocol.initializedNotification())

            // Discover tools
            let listId = allocId()
            let toolsResp = try sendAndReceive(
                MCPProtocol.toolsListRequest(id: listId),
                id: listId,
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

    func callTool(name: String, arguments: String) throws -> MCPProtocol.ToolCallResult {
        // Malformed model-emitted arguments must fail loudly instead of being
        // silently replaced with {} by the request formatter (#241).
        try MCPProtocol.validateToolArguments(name: name, arguments: arguments)
        // On timeout the manager deregisters and reaps this connection (#216);
        // callTool just surfaces the error.
        let requestId = allocId()
        let resp = try sendAndReceive(
            MCPProtocol.toolsCallRequest(id: requestId, name: name, arguments: arguments),
            id: requestId,
            timeoutMilliseconds: timeoutMilliseconds,
            operationDescription: "tool '\(name)'"
        )
        // An MCP-spec `isError: true` result is a tool-execution error, not a
        // transport failure: it is returned (not thrown) so the caller can feed
        // it back to the model to recover, per the MCP spec (#220). Only
        // transport/protocol failures throw.
        return try MCPProtocol.parseToolCallResponse(resp)
    }

    /// Terminate the child and reap it so it never lingers as a zombie (#216).
    /// SIGTERM first, then SIGKILL after a bounded grace period for a child that
    /// ignores SIGTERM, then a blocking waitUntilExit() to collect the exit
    /// status. Idempotent: safe to call on an already-exited process.
    func shutdown() {
        guard process.isRunning else {
            process.waitUntilExit()
            return
        }
        process.terminate() // SIGTERM
        let deadline = Date().addingTimeInterval(mcpShutdownGraceSeconds)
        while process.isRunning && Date() < deadline {
            usleep(20_000) // 20 ms
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL) // escalate
        }
        process.waitUntilExit() // reap - no zombie
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

    private func send(_ message: String) throws {
        guard let data = (message + "\n").data(using: .utf8) else { return }
        // Guard against writing to a crashed MCP server. Without this a closed
        // read end raises SIGPIPE (fatal by default) or, with the legacy
        // non-throwing FileHandle.write(_:), an uncatchable ObjC exception on
        // EPIPE. The isRunning check catches the common case fast; the throwing
        // write(contentsOf:) inside do/catch catches the crash-mid-write race
        // and maps it to a recoverable MCPError (#215).
        guard process.isRunning else {
            throw MCPError.processError("MCP server process is not running (\(path))")
        }
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            throw MCPError.processError("failed to write to MCP server stdin (\(path)): \(error.localizedDescription)")
        }
    }

    /// Standalone write (notification path) serialized against in-flight
    /// exchanges so it cannot interleave with another request's stdin bytes
    /// (#218). Never call while holding `ioLock` - NSLock is not reentrant.
    private func sendLocked(_ message: String) throws {
        ioLock.lock()
        defer { ioLock.unlock() }
        try send(message)
    }

    /// Sends `message` and reads until the response whose JSON-RPC `"id"`
    /// matches `id` arrives, under one shared deadline (#217). Notifications
    /// and responses to other ids are skipped; server `ping` requests are
    /// answered inline. Without this, a single server log notification
    /// (FastMCP `ctx.info()` emits `notifications/message` on stdout) was
    /// returned as the tool response and every later call was off-by-one.
    ///
    /// The whole exchange holds `ioLock` (#218): concurrent tool calls in
    /// `--serve` mode would otherwise interleave stdin writes and race for
    /// each other's stdout lines - id correlation alone drops the other
    /// request's response instead of leaving it for its owner.
    private func sendAndReceive(
        _ message: String,
        id: Int,
        timeoutMilliseconds: Int,
        operationDescription: String
    ) throws -> String {
        ioLock.lock()
        defer { ioLock.unlock() }
        try send(message)
        let deadline = Date().timeIntervalSinceReferenceDate + Double(timeoutMilliseconds) / 1000.0
        while true {
            let remainingMilliseconds = Int((deadline - Date().timeIntervalSinceReferenceDate) * 1000.0)
            guard remainingMilliseconds > 0 else {
                throw MCPError.timedOut("\(operationDescription.capitalized) timed out after \(timeoutMilliseconds / 1000)s")
            }
            let line = try lineReader.readLine(
                timeoutMilliseconds: remainingMilliseconds,
                operationDescription: operationDescription
            )
            switch MCPProtocol.classifyIncoming(line, awaitingId: id) {
            case .matchingResponse:
                return line
            case .pingRequest(let reply):
                try send(reply)
            case .unrelated:
                continue
            }
        }
    }
}

// MARK: - Remote (Streamable HTTP) connection

/// Maximum bytes accepted from a single remote MCP response (10 MB).
/// Prevents a malicious server from OOM-ing the client.
private let maxRemoteMCPResponseBytes = 10 * 1024 * 1024

/// Connection to a remote MCP server via Streamable HTTP transport (spec 2025-03-26).
/// Actor isolation serialises sessionId/nextId mutations with no manual locking.
actor RemoteMCPConnection: Sendable {
    nonisolated let urlString: String
    // Written once in init, read-only thereafter; nonisolated(unsafe) is safe
    // because init must complete before any caller can access this value.
    nonisolated(unsafe) private(set) var tools: [OpenAITool] = []

    private let url: URL
    private let bearerToken: String?
    private let timeoutSeconds: Int
    private let session: URLSession
    private var nextId = 1
    private var sessionId: String?

    init(urlString: String, bearerToken: String?, timeoutSeconds: Int = 5) async throws {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            throw MCPError.processError("Invalid MCP server URL: \(urlString) (must be http:// or https://)")
        }
        // Security: refuse to send bearer token over non-loopback plaintext HTTP.
        // Loopback traffic (127.0.0.1, ::1, localhost) never leaves the machine,
        // so http:// is acceptable there. Remote http:// would expose the token in plaintext.
        if bearerToken != nil && scheme == "http" {
            let host = url.host ?? ""
            let isLoopback = host == "127.0.0.1" || host == "::1" || host == "localhost"
            if !isLoopback {
                throw MCPError.processError(
                    "refusing to send --mcp-token over plaintext http:// to \(host) - use https:// to protect credentials"
                )
            }
        }
        self.urlString = urlString
        self.url = url
        self.bearerToken = bearerToken
        self.timeoutSeconds = timeoutSeconds
        // Ephemeral session: no shared cookie jar, no disk cache.
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["User-Agent": "apfel/\(buildVersion)"]
        self.session = URLSession(configuration: config)

        do {
            let initResp = try await post(MCPProtocol.initializeRequest(id: allocId()))
            _ = try MCPProtocol.parseInitializeResponse(initResp)
            _ = try? await post(MCPProtocol.initializedNotification())
            let toolsResp = try await post(MCPProtocol.toolsListRequest(id: allocId()))
            self.tools = try MCPProtocol.parseToolsListResponse(toolsResp)
        } catch let error as MCPError {
            throw error
        } catch {
            throw MCPError.processError("Remote MCP handshake failed for \(urlString): \(error)")
        }
    }

    func callTool(name: String, arguments: String) async throws -> MCPProtocol.ToolCallResult {
        // Malformed model-emitted arguments must fail loudly instead of being
        // silently replaced with {} by the request formatter (#241).
        try MCPProtocol.validateToolArguments(name: name, arguments: arguments)
        let resp = try await post(MCPProtocol.toolsCallRequest(id: allocId(), name: name, arguments: arguments))
        // isError is a tool-execution error, returned (not thrown) so the model
        // can see it and recover; only transport/protocol failures throw (#220).
        return try MCPProtocol.parseToolCallResponse(resp)
    }

    func shutdown() async {
        guard let sid = sessionId else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "DELETE"
        if let token = bearerToken { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id")
        // Await the DELETE (bounded by the 5s timeoutInterval) so the session is
        // actually released before the process exits, instead of firing a
        // detached task that the exiting process never schedules (#246).
        _ = try? await session.data(for: req)
    }

    private func allocId() -> Int {
        let id = nextId; nextId += 1; return id
    }

    private func post(_ body: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(timeoutSeconds))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let token = bearerToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let sid = sessionId { request.setValue(sid, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard data.count <= maxRemoteMCPResponseBytes else {
            throw MCPError.serverError(
                "Response from \(urlString) exceeded size limit (\(maxRemoteMCPResponseBytes / (1024 * 1024)) MB)"
            )
        }

        if let httpResponse = response as? HTTPURLResponse {
            if let sid = httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id") { sessionId = sid }
            if httpResponse.statusCode == 202 { return "{}" }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                throw MCPError.serverError("HTTP \(httpResponse.statusCode) from \(urlString): \(body)")
            }
        }

        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard let raw = String(data: data, encoding: .utf8), !raw.isEmpty else { return "{}" }

        // Streamable HTTP may return SSE even for single-response requests.
        // Extract the last non-empty data: line as the JSON payload.
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

    func callTool(name: String, arguments: String) async throws -> MCPProtocol.ToolCallResult {
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
        // Best-effort: fire-and-forget (session will expire on the server).
        // Used on the deregister-on-timeout path (#216) where we cannot await.
        case .remote(let c): Task { await c.shutdown() }
        }
    }

    /// Awaited shutdown for the process-exit path: reap local children and await
    /// the remote DELETE so cleanup completes before exit (#246).
    func shutdownAndWait() async {
        switch self {
        case .local(let c): c.shutdown()
        case .remote(let c): await c.shutdown()
        }
    }
}

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
            // First registration wins: a tool name already owned by an earlier
            // server is NOT rebound here, so routing stays predictable and the
            // shadowed variant is unreachable (warned below) (#239).
            for tool in conn.tools where toolMap[tool.function.name] == nil {
                toolMap[tool.function.name] = conn
            }
            if !quietMode {
                if case .remote = conn {
                    printStderr("warning: remote MCP server attached (\(conn.identifier)) - tool arguments will be sent to this server")
                }
                printStderr("\(styledErr("mcp:", .cyan)) \(conn.identifier) - \(conn.tools.map(\.function.name).joined(separator: ", "))")
            }
        }

        // Loudly warn about tool-name collisions across servers. The shadowed
        // duplicate is unreachable and would otherwise silently waste context
        // tokens (both identical schemas were injected into the prompt) (#239).
        if !quietMode {
            let collisions = MCPToolRegistry.collisions(
                servers: connections.map { (id: $0.identifier, toolNames: $0.tools.map(\.function.name)) }
            )
            for collision in collisions {
                printStderr(
                    "\(styledErr("warning:", .yellow)) tool name '\(collision.toolName)' is exposed by both \(collision.keptServer) and \(collision.ignoredServer); using \(collision.keptServer), ignoring the one from \(collision.ignoredServer)"
                )
            }
        }
    }

    func allTools() -> [OpenAITool] {
        // Deduplicate by name (first registration wins) so a shadowed
        // duplicate is not injected into the prompt twice (#239).
        MCPToolRegistry.deduplicate(connections.flatMap(\.tools))
    }

    func execute(name: String, arguments: String) async throws -> MCPProtocol.ToolCallResult {
        guard let conn = toolMap[name] else {
            throw MCPError.toolNotFound("No MCP server provides tool '\(name)'")
        }
        do {
            return try await conn.callTool(name: name, arguments: arguments)
        } catch {
            // A timed-out connection is dead. Deregister it so its tools stop
            // being offered via allTools() and later calls fail fast with
            // toolNotFound instead of routing to the dead connection, and reap
            // its child. Without this the tool stayed permanently registered but
            // broken. (#216)
            if case .timedOut = error as? MCPError {
                deregister(conn)
            }
            throw error
        }
    }

    /// Remove a dead connection from the routing tables and reap its child.
    private func deregister(_ conn: AnyMCPConnection) {
        let id = conn.identifier
        connections.removeAll { $0.identifier == id }
        let deadToolNames = toolMap.filter { $0.value.identifier == id }.map(\.key)
        for name in deadToolNames {
            toolMap.removeValue(forKey: name)
        }
        conn.shutdown()
    }

    func shutdown() async {
        for conn in connections {
            await conn.shutdownAndWait()
        }
        connections.removeAll()
        toolMap.removeAll()
    }
}
