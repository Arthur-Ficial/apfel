// ============================================================================
// BenchmarkTests.swift - Benchmark timing helper contract tests
// Part of apfel test suite
//
// The production `measure` function lives in the FoundationModels-coupled
// executable target and cannot be imported here. These tests lock the
// rethrowing contract using a local replica with the identical signature,
// ensuring the pattern stays correct if the production code is refactored.
// ============================================================================

import Foundation

private struct BenchmarkTiming {
    let avgMilliseconds: Double
}

private func measure(
    iterations: Int,
    warmup: Int = 2,
    operation: @escaping () async throws -> Void
) async rethrows -> BenchmarkTiming {
    guard iterations > 0 else { return BenchmarkTiming(avgMilliseconds: 0) }

    for _ in 0..<warmup {
        try await operation()
    }

    var totalNanoseconds: UInt64 = 0
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        try await operation()
        totalNanoseconds += DispatchTime.now().uptimeNanoseconds - start
    }

    return BenchmarkTiming(
        avgMilliseconds: Double(totalNanoseconds) / Double(iterations) / 1_000_000
    )
}

private struct BenchmarkCaseResult {
    let name: String
    let validated: Bool
    let avgMs: Double
}

private struct ForcedBenchmarkError: Error {}

func runBenchmarkTests() {

    testAsync("measure rethrows when body throws") {
        var threw = false
        do {
            _ = try await measure(iterations: 3, warmup: 0) {
                throw ForcedBenchmarkError()
            }
        } catch is ForcedBenchmarkError {
            threw = true
        }
        try assertTrue(threw, "measure must propagate the body's error, not swallow it")
    }

    testAsync("measure returns timing when body succeeds") {
        var count = 0
        let timing = try await measure(iterations: 5, warmup: 0) {
            count += 1
        }
        try assertEqual(count, 5, "body should run exactly iterations times")
        try assertTrue(timing.avgMilliseconds >= 0, "timing must be non-negative")
    }

    testAsync("measure with zero iterations returns zero") {
        let timing = try await measure(iterations: 0, warmup: 0) {
            throw ForcedBenchmarkError()
        }
        try assertTrue(timing.avgMilliseconds == 0, "zero iterations must return 0 ms")
    }

    testAsync("failing case must not be reported as validated") {
        var validated = true
        do {
            _ = try await measure(iterations: 1, warmup: 0) {
                throw ForcedBenchmarkError()
            }
        } catch {
            validated = false
        }
        try assertTrue(!validated,
            "a benchmark case whose timed operation throws must not reach validated: true")
    }

    testAsync("measure runs warmup before timed iterations") {
        var callCount = 0
        _ = try await measure(iterations: 3, warmup: 2) {
            callCount += 1
        }
        try assertEqual(callCount, 5, "warmup (2) + iterations (3) = 5 total calls")
    }

    testAsync("measure rethrows during warmup") {
        var threw = false
        var callCount = 0
        do {
            _ = try await measure(iterations: 10, warmup: 1) {
                callCount += 1
                throw ForcedBenchmarkError()
            }
        } catch is ForcedBenchmarkError {
            threw = true
        }
        try assertTrue(threw, "measure must rethrow errors from warmup phase")
        try assertEqual(callCount, 1, "should fail on first warmup call")
    }
}
