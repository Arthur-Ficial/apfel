// apfel-tests — pure Swift test runner, no XCTest/Testing framework needed
// Run: swift run apfel-tests

import Foundation
import ApfelCLI

// MARK: - Minimal test harness

nonisolated(unsafe) var _passed = 0
nonisolated(unsafe) var _failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("  ✅ \(name)")
        _passed += 1
    } catch {
        print("  ❌ \(name): \(error)")
        _failed += 1
    }
}

/// Async variant — runs the block on a Task and waits synchronously via semaphore.
/// Enables unit-testing async functions without XCTest or Swift Testing.
func testAsync(_ name: String, _ block: @Sendable @escaping () async throws -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var failure: Error? = nil
    nonisolated(unsafe) var passed = false

    Task {
        do {
            try await block()
            passed = true
        } catch {
            failure = error
        }
        semaphore.signal()
    }
    semaphore.wait()

    if passed {
        print("  ✅ \(name)")
        _passed += 1
    } else {
        print("  ❌ \(name): \(failure!)")
        _failed += 1
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    guard a == b else { throw TestFailure("\(a) != \(b)\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertNil<T>(_ v: T?, _ msg: String = "") throws {
    guard v == nil else { throw TestFailure("Expected nil, got \(v!)\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertNotNil<T>(_ v: T?, _ msg: String = "") throws {
    guard v != nil else { throw TestFailure("Expected non-nil\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertTrue(_ v: Bool, _ msg: String = "") throws {
    guard v else { throw TestFailure("Expected true\(msg.isEmpty ? "" : " — \(msg)")") }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ msg: String) { description = msg }
}

func suite(_ name: String, _ block: () -> Void) {
    print("\n\(name)")
    block()
}

// MARK: - Run all test suites

suite("ApfelErrorTests") { runApfelErrorTests() }
suite("ExitCodeMapTests") { runExitCodeMapTests() }
suite("ToolCallHandlerTests") { runToolCallHandlerTests() }
suite("ContextStrategyTests") { runContextStrategyTests() }
suite("OpenAIModelsTests") { runOpenAIModelsTests() }
suite("JSONFenceStripperTests") { runJSONFenceStripperTests() }
suite("ChatRequestValidatorTests") { runChatRequestValidatorTests() }
suite("OriginValidatorTests") { runOriginValidatorTests() }
suite("MCPClientTests") { runMCPClientTests() }
suite("AsyncHarnessTests") { runAsyncHarnessTests() }
suite("RetryTests") { runRetryTests() }
suite("DebugLoggerTests") { runDebugLoggerTests() }
suite("BufferedLineReaderTests") { runBufferedLineReaderTests() }
suite("CLIArgumentsTests") { runCLIArgumentsTests() }
suite("ModelAvailabilityTests") { runModelAvailabilityTests() }
suite("CLIErrorsTests") { runCLIErrorsTests() }
suite("CLIValidateTests") { runCLIValidateTests() }
suite("SchemaParserTests") { runSchemaParserTests() }
suite("FinishReasonResolverTests") { runFinishReasonResolverTests() }
suite("StreamErrorResolverTests") { runStreamErrorResolverTests() }
suite("ToolResolutionTests") { runToolResolutionTests() }
suite("BodyLimitsTests") { runBodyLimitsTests() }
suite("CLIServerParityTests") { runCLIServerParityTests() }
suite("TraceBufferTests") { runTraceBufferTests() }
suite("StreamTaskBoxTests") { runStreamTaskBoxTests() }
suite("ManPageTests") { runManPageTests() }
suite("StreamCleanupTests") { runStreamCleanupTests() }
suite("BufferedLineReaderConcurrencyTests") { runBufferedLineReaderConcurrencyTests() }
suite("DebugFlagBaselineTests") { runDebugFlagBaselineTests() }
suite("ApfelErrorMessageTests") { runApfelErrorMessageTests() }
suite("OpenAIWireFormatTests") { runOpenAIWireFormatTests() }
suite("ApfelCorePublicAPIUsageTests") { runApfelCorePublicAPIUsageTests() }

// MARK: - Summary

print("\n─────────────────────────────────")
if _failed == 0 {
    print("✅ All \(_passed) tests passed")
} else {
    print("❌ \(_failed) failed, \(_passed) passed")
    exit(1)
}
