// ============================================================================
// BenchmarkTests.swift - Benchmark timing helper rethrow + validated semantics
// Part of apfel test suite
//
// The actual measure() function is private in the main target (which depends
// on FoundationModels). These tests verify the behavioral contract: a
// rethrowing timing helper propagates errors from its body, and a benchmark
// case that throws must not report validated: true.
// ============================================================================

import Foundation

private struct BenchmarkTestError: Error {}

func runBenchmarkTests() {

    // -- measure rethrow contract --

    testAsync("rethrowing measure propagates error from body on first iteration") {
        var iterationsRun = 0
        do {
            _ = try await measureRethrowing(iterations: 5) {
                iterationsRun += 1
                throw BenchmarkTestError()
            }
            throw TestFailure("expected BenchmarkTestError, but measure completed normally")
        } catch is BenchmarkTestError {
            try assertEqual(iterationsRun, 1,
                "measure should stop on the first throwing iteration")
        }
    }

    testAsync("rethrowing measure completes all iterations when body does not throw") {
        var iterationsRun = 0
        let result = try await measureRethrowing(iterations: 5) {
            iterationsRun += 1
        }
        try assertEqual(iterationsRun, 5)
        try assertTrue(result > 0, "timing must be positive")
    }

    testAsync("rethrowing measure propagates error mid-sequence") {
        var iterationsRun = 0
        do {
            _ = try await measureRethrowing(iterations: 10) {
                iterationsRun += 1
                if iterationsRun == 3 { throw BenchmarkTestError() }
            }
            throw TestFailure("expected BenchmarkTestError on iteration 3")
        } catch is BenchmarkTestError {
            try assertEqual(iterationsRun, 3)
        }
    }

    // -- validated flag semantics --

    testAsync("a throwing body prevents reaching the validated assignment") {
        var reachedValidated = false
        do {
            _ = try await measureRethrowing(iterations: 1) {
                throw BenchmarkTestError()
            }
            reachedValidated = true
        } catch {
            // expected
        }
        try assertTrue(!reachedValidated,
            "a throwing timed operation must prevent the validated: true assignment")
    }

    // -- try? silently swallows errors (the bug this fix addresses) --

    testAsync("non-throwing measure with try? body silently completes -- the bug pattern") {
        var iterationsRun = 0
        let result = await measureNonThrowing(iterations: 5) {
            iterationsRun += 1
            _ = try? { () -> Int in throw BenchmarkTestError() }()
        }
        try assertEqual(iterationsRun, 5,
            "non-throwing measure runs all iterations even when every one fails via try?")
        try assertTrue(result > 0,
            "the bug: measure reports a timing for iterations that did no real work")
    }
}

// Local reimplementations matching the old and new measure() signatures.
// These mirror the actual function in Sources/Benchmark.swift.

private func measureRethrowing(
    iterations: Int,
    _ body: () async throws -> Void
) async rethrows -> Double {
    var totalNanoseconds: UInt64 = 0
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        try await body()
        totalNanoseconds += DispatchTime.now().uptimeNanoseconds - start
    }
    return Double(totalNanoseconds) / Double(iterations) / 1_000_000
}

private func measureNonThrowing(
    iterations: Int,
    _ body: () async -> Void
) async -> Double {
    var totalNanoseconds: UInt64 = 0
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        await body()
        totalNanoseconds += DispatchTime.now().uptimeNanoseconds - start
    }
    return Double(totalNanoseconds) / Double(iterations) / 1_000_000
}
