// ============================================================================
// Logging.swift — Request logging with ring buffer and query API
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation

// MARK: - Request Log Entry

/// A single logged request. Stored in the ring buffer and returned by /v1/logs.
struct RequestLog: Codable, Sendable {
    let id: String
    let timestamp: String
    let method: String
    let path: String
    let status: Int
    let duration_ms: Int
    let stream: Bool
    let estimated_tokens: Int?
    let error: String?
    let request_body: String?   // only populated in --debug mode
    let response_body: String?  // only populated in --debug mode
    let events: [String]?
}

// MARK: - Log Store

/// Thread-safe ring buffer for request logs. Stores the last `capacity` entries.
actor LogStore {
    private var logs: [RequestLog] = []
    private let capacity: Int
    private let startTime = Date()
    private var totalRequests: Int = 0
    private var totalErrors: Int = 0
    private var totalDurationMs: Int = 0
    private var totalTokens: Int = 0
    private var _activeRequests: Int = 0

    init(capacity: Int = 1000) {
        self.capacity = capacity
    }

    /// Add a log entry. Evicts oldest if at capacity.
    func append(_ log: RequestLog) {
        totalRequests += 1
        totalDurationMs += log.duration_ms
        if let tokens = log.estimated_tokens {
            totalTokens += tokens
        }
        if log.status >= 400 {
            totalErrors += 1
        }
        logs.append(log)
        if logs.count > capacity {
            logs.removeFirst()
        }

        // Print to stderr
        let streamLabel = log.stream ? " stream" : ""
        let tokenLabel = log.estimated_tokens.map { " tokens=~\($0)" } ?? ""
        let errorLabel = log.error.map { " error=\"\($0)\"" } ?? ""
        let line = "[\(log.timestamp)] \(log.method) \(log.path) \(log.status) \(log.duration_ms)ms\(streamLabel)\(tokenLabel)\(errorLabel)"
        printStderr(line)
        if let events = log.events {
            for event in events {
                printStderr("  \(styledErr("•", .dim)) \(event)")
            }
        }
    }

    /// Increment active request counter.
    func requestStarted() { _activeRequests += 1 }

    /// Decrement active request counter.
    func requestFinished() { _activeRequests -= 1 }

    /// Current number of in-flight requests.
    var activeRequests: Int { _activeRequests }

    /// Query logs with optional filters.
    func query(
        status: Int? = nil,
        path: String? = nil,
        errorsOnly: Bool = false,
        since: Date? = nil,
        limit: Int = 50
    ) -> [RequestLog] {
        var result = logs

        if let status {
            result = result.filter { $0.status == status }
        }
        if let path {
            result = result.filter { $0.path == path }
        }
        if errorsOnly {
            result = result.filter { $0.status >= 400 }
        }
        if let since {
            let sinceStr = ISO8601DateFormatter().string(from: since)
            result = result.filter { $0.timestamp >= sinceStr }
        }

        // Return last N entries (most recent)
        if result.count > limit {
            result = Array(result.suffix(limit))
        }

        return result
    }

    /// Aggregate statistics.
    func stats(maxConcurrent: Int) -> LogStats {
        let uptimeSeconds = Int(Date().timeIntervalSince(startTime))
        let rpm = uptimeSeconds > 0 ? Double(totalRequests) / (Double(uptimeSeconds) / 60.0) : 0
        let avgDuration = totalRequests > 0 ? totalDurationMs / totalRequests : 0

        return LogStats(
            uptime_seconds: uptimeSeconds,
            total_requests: totalRequests,
            total_errors: totalErrors,
            avg_duration_ms: avgDuration,
            requests_per_minute: round(rpm * 10) / 10,
            estimated_tokens_total: totalTokens,
            active_requests: _activeRequests,
            max_concurrent: maxConcurrent
        )
    }
}

func truncateForLog(_ value: String, limit: Int = 4000) -> String {
    if value.count <= limit { return value }
    let end = value.index(value.startIndex, offsetBy: limit)
    return String(value[..<end]) + "\n...[truncated]"
}

func captureTruncatedLogBody(_ value: @autoclosure () -> String, enabled: Bool) -> String? {
    guard enabled else { return nil }
    return truncateForLog(value())
}

// MARK: - Log Stats Response

struct LogStats: Codable, Sendable {
    let uptime_seconds: Int
    let total_requests: Int
    let total_errors: Int
    let avg_duration_ms: Int
    let requests_per_minute: Double
    let estimated_tokens_total: Int
    let active_requests: Int
    let max_concurrent: Int
}

// MARK: - Log List Response

struct LogListResponse: Encodable, Sendable {
    let object: String
    let count: Int
    let data: [RequestLog]
}
