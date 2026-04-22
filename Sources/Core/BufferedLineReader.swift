// ============================================================================
// BufferedLineReader.swift — Buffered newline-delimited reader for file descriptors
// Part of ApfelCore — pure Swift, no FoundationModels dependency
// ============================================================================

import Foundation
import os
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Reads newline-delimited lines from a file descriptor using buffered I/O.
/// Each `readLine()` call returns one complete line (without the trailing newline).
/// Bytes arriving after the newline are stashed for the next call.
public final class BufferedLineReader: Sendable {
    private struct State {
        var leftover = Data()
    }

    private let fd: Int32
    private let bufferSize: Int
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    /// Creates a reader for a newline-delimited byte stream.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The file descriptor to read from.
    ///   - bufferSize: The chunk size to use for each low-level read.
    public init(fileDescriptor: Int32, bufferSize: Int = 4096) {
        self.fd = fileDescriptor
        self.bufferSize = bufferSize
    }

    /// Read one newline-delimited line from the file descriptor.
    /// - Parameters:
    ///   - timeoutMilliseconds: Maximum time to wait for a complete line.
    ///   - operationDescription: Human-readable label for error messages.
    /// - Returns: The line content (without trailing newline).
    /// - Throws: `MCPError.timedOut` or `MCPError.processError` on failure.
    public func readLine(timeoutMilliseconds: Int, operationDescription: String) throws -> String {
        try state.withLock { state in
            var lineBuffer = Data()
            let deadline = Date().timeIntervalSinceReferenceDate + (Double(timeoutMilliseconds) / 1000.0)

            // Drain any leftover bytes from a previous read that crossed a message boundary.
            if let newlineIndex = state.leftover.firstIndex(of: UInt8(ascii: "\n")) {
                lineBuffer.append(state.leftover[state.leftover.startIndex..<newlineIndex])
                state.leftover = Data(state.leftover[(newlineIndex + 1)...])
                if let line = String(data: lineBuffer, encoding: .utf8), !line.isEmpty {
                    return line
                }
            } else if !state.leftover.isEmpty {
                lineBuffer.append(state.leftover)
                state.leftover = Data()
            }

            var chunk = [UInt8](repeating: 0, count: bufferSize)

            while true {
                let remainingMilliseconds = Int((deadline - Date().timeIntervalSinceReferenceDate) * 1000.0)
                if remainingMilliseconds <= 0 {
                    throw MCPError.timedOut("\(operationDescription.capitalized) timed out after \(timeoutMilliseconds / 1000)s")
                }

                var pollDescriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
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

                let readCount = read(fd, &chunk, chunk.count)
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
                    let afterNewline = bytes.index(after: newlineOffset)
                    if afterNewline < bytes.endIndex {
                        state.leftover = Data(bytes[afterNewline...])
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
}
