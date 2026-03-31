// ============================================================================
// APIClient.swift — HTTP client to apfel --serve
// Part of apfel GUI — talks to the server via OpenAI-compatible API
// NO FoundationModels import — all AI logic lives in the server.
// ============================================================================

import Foundation

/// HTTP client that talks to the apfel server's OpenAI-compatible API.
/// This is the ONLY file that makes network requests. Pure URLSession.
final class APIClient: Sendable {
    struct StreamError: LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    let baseURL: URL

    init(port: Int) {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: baseURL) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Chat Completion (Non-Streaming)

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let x_context_strategy: String?
        let x_context_max_turns: Int?
        let x_context_output_reserve: Int?

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    struct ChatResponse: Decodable {
        let id: String
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Decodable {
            let message: ResponseMessage
            let finish_reason: String?
        }
        struct ResponseMessage: Decodable {
            let role: String
            let content: String
        }
        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let total_tokens: Int?
        }
    }

    func chatCompletion(
        messages: [(role: String, content: String)],
        systemPrompt: String?,
        contextStrategy: String? = nil,
        contextMaxTurns: Int? = nil,
        contextOutputReserve: Int? = nil
    ) async throws -> (response: ChatResponse, requestJSON: String, responseJSON: String, durationMs: Int) {
        let start = Date()
        let apiMessages = buildMessages(messages: messages, systemPrompt: systemPrompt)
        let request = ChatRequest(
            model: "apple-foundationmodel",
            messages: apiMessages,
            stream: false,
            x_context_strategy: contextStrategy,
            x_context_max_turns: contextMaxTurns,
            x_context_output_reserve: contextOutputReserve
        )
        let requestJSON = prettyJSON(request)

        var urlRequest = URLRequest(url: URL(string: "/v1/chat/completions", relativeTo: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let responseJSON = String(data: data, encoding: .utf8) ?? "{}"
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)

        return (decoded, requestJSON, prettyFormatJSON(responseJSON), durationMs)
    }

    // MARK: - Chat Completion (Streaming)

    /// Collected raw SSE lines from the last streaming request.
    /// Access after the stream finishes to get the truthful server response.
    nonisolated(unsafe) static var lastRawSSEResponse: String = ""

    /// Usage stats from the last streaming response (prompt_tokens, completion_tokens, total_tokens).
    nonisolated(unsafe) static var lastStreamingUsage: StreamUsage?

    struct StreamUsage: Sendable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }

    func streamChatCompletion(
        messages: [(role: String, content: String)],
        systemPrompt: String?,
        contextStrategy: String? = nil,
        contextMaxTurns: Int? = nil,
        contextOutputReserve: Int? = nil
    ) -> (stream: AsyncThrowingStream<String, Error>, requestJSON: String) {
        let apiMessages = buildMessages(messages: messages, systemPrompt: systemPrompt)
        let request = ChatRequest(
            model: "apple-foundationmodel",
            messages: apiMessages,
            stream: true,
            x_context_strategy: contextStrategy,
            x_context_max_turns: contextMaxTurns,
            x_context_output_reserve: contextOutputReserve
        )
        let requestJSON = prettyJSON(request)
        let url = URL(string: "/v1/chat/completions", relativeTo: baseURL)!

        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                var rawLines: [String] = []
                do {
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, _) = try await URLSession.shared.bytes(for: urlRequest)
                    APIClient.lastStreamingUsage = nil
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: [DONE]") {
                            rawLines.append("data: [DONE]")
                            break
                        }
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            // Pretty-print each SSE chunk for the debug panel
                            let prettyChunk = Self.prettyFormatInline(json)
                            rawLines.append("data: \(prettyChunk)")

                            if let data = json.data(using: .utf8) {
                                // Check for usage stats line
                                if let usageData = try? JSONDecoder().decode(StreamUsageChunk.self, from: data) {
                                    APIClient.lastStreamingUsage = StreamUsage(
                                        promptTokens: usageData.usage.prompt_tokens,
                                        completionTokens: usageData.usage.completion_tokens,
                                        totalTokens: usageData.usage.total_tokens
                                    )
                                    continue
                                }

                                if let errorChunk = try? JSONDecoder().decode(StreamErrorChunk.self, from: data) {
                                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n\n")
                                    continuation.finish(throwing: StreamError(message: Self.userFacingErrorMessage(errorChunk.error)))
                                    return
                                }

                                if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                                   let content = chunk.choices.first?.delta.content {
                                    continuation.yield(content)
                                }
                            }
                        }
                    }
                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n\n")
                    continuation.finish()
                } catch {
                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n") + "\nerror: \(error.localizedDescription)"
                    continuation.finish(throwing: error)
                }
            }
        }

        return (stream, requestJSON)
    }

    private struct StreamChunk: Decodable {
        let choices: [ChunkChoice]
        struct ChunkChoice: Decodable {
            let delta: Delta
        }
        struct Delta: Decodable {
            let content: String?
        }
    }

    private struct StreamErrorChunk: Decodable {
        let error: String
    }

    private struct StreamUsageChunk: Decodable {
        let usage: Usage
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }

    // MARK: - Logs

    struct LogEntry: Decodable, Identifiable {
        let id: String
        let timestamp: String
        let method: String
        let path: String
        let status: Int
        let duration_ms: Int
        let stream: Bool
        let estimated_tokens: Int?
        let error: String?
        let request_body: String?
        let response_body: String?
        let events: [String]?
    }

    struct LogListResponse: Decodable {
        let count: Int
        let data: [LogEntry]
    }

    func fetchLogs(errorsOnly: Bool = false, limit: Int = 100) async throws -> [LogEntry] {
        var urlStr = "/v1/logs?limit=\(limit)"
        if errorsOnly { urlStr += "&errors=true" }
        let url = URL(string: urlStr, relativeTo: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(LogListResponse.self, from: data)
        return response.data
    }

    // MARK: - Stats

    struct ServerStats: Decodable {
        let uptime_seconds: Int
        let total_requests: Int
        let total_errors: Int
        let avg_duration_ms: Int
        let requests_per_minute: Double
        let active_requests: Int
        let max_concurrent: Int
    }

    func fetchStats() async throws -> ServerStats {
        let url = URL(string: "/v1/logs/stats", relativeTo: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ServerStats.self, from: data)
    }

    // MARK: - Helpers

    private func buildMessages(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> [ChatRequest.Message] {
        var apiMessages: [ChatRequest.Message] = []
        if let sys = systemPrompt, !sys.isEmpty {
            apiMessages.append(.init(role: "system", content: sys))
        }
        for msg in messages {
            apiMessages.append(.init(role: msg.role, content: msg.content))
        }
        return apiMessages
    }

    private func prettyJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// Pretty-print a single JSON string (static, for use in closures).
    static func prettyFormatInline(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }

    static func userFacingErrorMessage(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("unsafe") || lowered.contains("safety") {
            return "The model blocked this response for safety reasons. Try rephrasing the prompt."
        }
        return raw
    }

    static func isSafetyError(_ raw: String) -> Bool {
        let lowered = raw.lowercased()
        return lowered.contains("unsafe") || lowered.contains("safety")
    }

    private func prettyFormatJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }
}
