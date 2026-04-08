// ============================================================================
// MCPClient.swift - MCP server connection and tool execution
// Part of apfel - spawns MCP servers and manages tool calling
// ============================================================================

import Foundation
import Darwin
import ApfelCore

/// A connection to a single MCP server process (stdio transport).
final class MCPConnection: @unchecked Sendable {
    private let timeoutMilliseconds: Int

    let path: String
    private(set) var tools: [OpenAITool]

    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
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

    /// Leftover bytes from a previous buffered read that arrived after a newline.
    private var readBuffer = Data()

    private func sendAndReceive(
        _ message: String,
        timeoutMilliseconds: Int,
        operationDescription: String
    ) throws -> String {
        send(message)
        var lineBuffer = Data()
        let fd = stdoutPipe.fileHandleForReading.fileDescriptor
        let deadline = Date().timeIntervalSinceReferenceDate + (Double(timeoutMilliseconds) / 1000.0)

        // Drain any leftover bytes from the previous read that crossed a message boundary.
        if let newlineIndex = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            lineBuffer.append(readBuffer[readBuffer.startIndex..<newlineIndex])
            readBuffer = Data(readBuffer[(newlineIndex + 1)...])
            if let line = String(data: lineBuffer, encoding: .utf8), !line.isEmpty {
                return line
            }
        } else if !readBuffer.isEmpty {
            lineBuffer.append(readBuffer)
            readBuffer = Data()
        }

        var chunk = [UInt8](repeating: 0, count: 4096)

        while true {
            let remainingMilliseconds = Int((deadline - Date().timeIntervalSinceReferenceDate) * 1000.0)
            if remainingMilliseconds <= 0 {
                throw MCPError.timedOut("\(operationDescription.capitalized) timed out after \(timeoutMilliseconds / 1000)s")
            }

            var pollDescriptor = pollfd(fd: Int32(fd), events: Int16(POLLIN), revents: 0)
            let ready = poll(&pollDescriptor, 1, Int32(remainingMilliseconds))
            if ready == 0 {
                throw MCPError.timedOut("\(operationDescription.capitalized) timed out after \(timeoutMilliseconds / 1000)s")
            }
            if ready < 0 {
                if errno == EINTR { continue }
                throw MCPError.processError("Failed waiting for MCP response: \(String(cString: strerror(errno)))")
            }
            if (pollDescriptor.revents & Int16(POLLNVAL)) != 0 {
                throw MCPError.processError("MCP stdout became invalid")
            }
            if (pollDescriptor.revents & Int16(POLLERR)) != 0 {
                throw MCPError.processError("MCP stdout reported an I/O error")
            }
            if (pollDescriptor.revents & Int16(POLLHUP)) != 0 && (pollDescriptor.revents & Int16(POLLIN)) == 0 {
                throw MCPError.processError("MCP server closed unexpectedly")
            }
            if (pollDescriptor.revents & Int16(POLLIN)) == 0 {
                continue
            }

            let readCount = Darwin.read(fd, &chunk, chunk.count)
            if readCount == 0 {
                throw MCPError.processError("MCP server closed unexpectedly")
            }
            if readCount < 0 {
                if errno == EINTR { continue }
                throw MCPError.processError("Failed reading MCP response: \(String(cString: strerror(errno)))")
            }

            let bytes = chunk[..<readCount]
            if let newlineOffset = bytes.firstIndex(of: UInt8(ascii: "\n")) {
                lineBuffer.append(contentsOf: bytes[bytes.startIndex..<newlineOffset])
                // Stash anything after the newline for the next call.
                let afterNewline = bytes.index(after: newlineOffset)
                if afterNewline < bytes.endIndex {
                    readBuffer = Data(bytes[afterNewline...])
                }
                break
            }
            lineBuffer.append(contentsOf: bytes)
        }
        guard let line = String(data: lineBuffer, encoding: .utf8), !line.isEmpty else {
            throw MCPError.processError("Empty response from MCP server")
        }
        return line
    }
}

/// Manages multiple MCP server connections and routes tool calls.
actor MCPManager {
    private var connections: [MCPConnection] = []
    private var toolMap: [String: MCPConnection] = [:]

    init(paths: [String], timeoutSeconds: Int = 5) async throws {
        for path in paths {
            let absPath: String
            if path.hasPrefix("/") {
                absPath = path
            } else {
                absPath = FileManager.default.currentDirectoryPath + "/" + path
            }
            let conn = try await MCPConnection(path: absPath, timeoutSeconds: timeoutSeconds)
            connections.append(conn)
            for tool in conn.tools {
                toolMap[tool.function.name] = conn
            }
            if !quietMode {
                printStderr("\(styled("mcp:", .cyan)) \(conn.path) - \(conn.tools.map(\.function.name).joined(separator: ", "))")
            }
        }
    }

    func allTools() -> [OpenAITool] {
        connections.flatMap(\.tools)
    }

    func execute(name: String, arguments: String) throws -> String {
        guard let conn = toolMap[name] else {
            throw MCPError.toolNotFound("No MCP server provides tool '\(name)'")
        }
        return try conn.callTool(name: name, arguments: arguments)
    }

    func shutdown() {
        for conn in connections {
            conn.shutdown()
        }
    }
}
