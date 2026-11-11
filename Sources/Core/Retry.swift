// ============================================================================
// Retry.swift — Exponential backoff retry for transient model errors
// Part of apfel — Apple Intelligence from the command line
// ============================================================================

import Foundation

/// Execute an async operation with exponential backoff retry.
/// When maxRetries is 0, acts as a simple passthrough (no retry).
/// Uses `isRetryableError()` to determine if an error should trigger retry.
public func withRetry<T: Sendable>(
    maxRetries: Int = 3,
    delays: [Double] = [0.1, 0.5, 2.0],
    operation: @Sendable () async throws -> T
) async throws -> T {
    try await withRetry(maxRetries: maxRetries, delays: delays,
                        classify: { ApfelError.classify($0) }, operation: operation)
}

/// `withRetry` with an injected classifier (#522). ApfelCore is
/// FoundationModels-free, so its pure `ApfelError.classify` cannot see macOS
/// 27's typed `LanguageModelError`; a host that can (apfel's main target)
/// passes its own classifier, which then decides both whether to retry and
/// the label of the retry banner.
public func withRetry<T: Sendable>(
    maxRetries: Int = 3,
    delays: [Double] = [0.1, 0.5, 2.0],
    classify: @Sendable (Error) -> ApfelError,
    operation: @Sendable () async throws -> T
) async throws -> T {
    guard maxRetries > 0 else {
        return try await operation()
    }

    var lastError: Error?

    for attempt in 0...maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error

            // Don't retry non-retryable errors
            let classified = classify(error)
            guard classified.isRetryable else {
                throw error
            }

            // Don't retry if we've exhausted attempts
            guard attempt < maxRetries else {
                break
            }

            // Exponential backoff
            let delay = attempt < delays.count ? delays[attempt] : delays.last ?? 2.0
            let msg = classified.cliLabel
            // Swallowed on a closed stderr: losing a retry banner must never
            // abort the run or change the exit status (#389).
            writeTolerantly("  retry \(attempt + 1)/\(maxRetries) after \(delay)s: \(msg)\n",
                            to: FileHandle.standardError)
            try await Task.sleep(for: .seconds(delay))
        }
    }

    throw lastError!
}
