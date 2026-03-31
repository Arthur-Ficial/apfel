// apfel-tests — pure Swift test runner, no XCTest/Testing framework needed
// Run: swift run apfel-tests

import Foundation

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
suite("ToolCallHandlerTests") { runToolCallHandlerTests() }
suite("ContextStrategyTests") { runContextStrategyTests() }

// MARK: - Summary

print("\n─────────────────────────────────")
if _failed == 0 {
    print("✅ All \(_passed) tests passed")
} else {
    print("❌ \(_failed) failed, \(_passed) passed")
    exit(1)
}
