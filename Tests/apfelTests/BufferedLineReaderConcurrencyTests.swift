// ============================================================================
// BufferedLineReaderConcurrencyTests.swift — Concurrency BASELINE for the
// upcoming @unchecked Sendable → Mutex refactor in #105.
//
// What's green today, what we must not lose:
//   1. BufferedLineReader is Sendable (can be passed across isolation domains).
//   2. Two readers on two pipes run concurrently without cross-talk.
//   3. A single reader can be handed off sequentially between tasks (one
//      call finishes before the next starts) and the leftover buffer remains
//      consistent.
//
// The key future-safe guarantee added by #105 is that simultaneous readLine()
// calls on the same reader are serialized safely instead of racing on the
// leftover buffer.
// ============================================================================

import Foundation
import ApfelCore
#if canImport(Darwin)
import Darwin
#endif

func runBufferedLineReaderConcurrencyTests() {
    @Sendable func makePipePair() -> (Int32, Int32) {
        var fds: [Int32] = [0, 0]
        pipe(&fds)
        return (fds[0], fds[1])
    }

    @Sendable func writeString(_ fd: Int32, _ string: String) {
        let data = Array(string.utf8)
        data.withUnsafeBufferPointer { buf in
            _ = Darwin.write(fd, buf.baseAddress, buf.count)
        }
    }

    // Compile-time: the @unchecked Sendable claim is what allows
    // StreamCleanup/onTermination/Task handoffs to take ownership of a reader.
    // If the refactor replaces @unchecked Sendable with something that is NOT
    // Sendable, this line stops compiling and the API change is surfaced.
    test("BufferedLineReader conforms to Sendable") {
        let (r, w) = makePipePair()
        defer { close(r); close(w) }
        let _: any Sendable = BufferedLineReader(fileDescriptor: r)
    }

    testAsync("two readers on two pipes read concurrently without cross-talk") {
        let (rA, wA) = makePipePair()
        let (rB, wB) = makePipePair()
        defer { close(rA); close(wA); close(rB); close(wB) }

        let readerA = BufferedLineReader(fileDescriptor: rA)
        let readerB = BufferedLineReader(fileDescriptor: rB)

        // Seed both pipes with three distinct lines each.
        for i in 0..<3 {
            writeString(wA, "A-line-\(i)\n")
            writeString(wB, "B-line-\(i)\n")
        }

        async let linesA: [String] = Task.detached {
            var out: [String] = []
            for _ in 0..<3 {
                out.append(try readerA.readLine(timeoutMilliseconds: 2000, operationDescription: "A"))
            }
            return out
        }.value

        async let linesB: [String] = Task.detached {
            var out: [String] = []
            for _ in 0..<3 {
                out.append(try readerB.readLine(timeoutMilliseconds: 2000, operationDescription: "B"))
            }
            return out
        }.value

        let (gotA, gotB) = try await (linesA, linesB)
        guard gotA == ["A-line-0", "A-line-1", "A-line-2"] else {
            throw TestFailure("reader A cross-contaminated: \(gotA)")
        }
        guard gotB == ["B-line-0", "B-line-1", "B-line-2"] else {
            throw TestFailure("reader B cross-contaminated: \(gotB)")
        }
    }

    testAsync("sequential handoff of one reader across tasks preserves leftover buffer") {
        let (r, w) = makePipePair()
        defer { close(r); close(w) }

        // Two lines in one write — forces leftover handling.
        writeString(w, "first-half\nsecond-half\n")
        let reader = BufferedLineReader(fileDescriptor: r)

        // Task 1 drains the first line. The second line's bytes sit in
        // `leftover`. We await full completion before starting task 2 — no
        // simultaneous calls — so today's implementation is safe.
        let first = try await Task.detached { () throws -> String in
            try reader.readLine(timeoutMilliseconds: 2000, operationDescription: "first")
        }.value
        guard first == "first-half" else {
            throw TestFailure("task 1 got wrong first line: \(first)")
        }

        // Task 2 must see the leftover buffer from task 1's call. A refactor
        // that resets or scopes `leftover` per-task would break this.
        let second = try await Task.detached { () throws -> String in
            try reader.readLine(timeoutMilliseconds: 2000, operationDescription: "second")
        }.value
        guard second == "second-half" else {
            throw TestFailure("task 2 lost leftover, got: \(second)")
        }
    }

    testAsync("many sequential handoffs preserve line order and completeness") {
        let (r, w) = makePipePair()
        defer { close(r); close(w) }

        let lineCount = 100
        var combined = ""
        for i in 0..<lineCount {
            combined += "line-\(i)\n"
        }
        writeString(w, combined)

        let reader = BufferedLineReader(fileDescriptor: r)

        // One-at-a-time handoff between detached tasks. No simultaneous access.
        var collected: [String] = []
        for _ in 0..<lineCount {
            let line = try await Task.detached { () throws -> String in
                try reader.readLine(timeoutMilliseconds: 2000, operationDescription: "seq")
            }.value
            collected.append(line)
        }

        guard collected.count == lineCount else {
            throw TestFailure("lost lines across handoffs: got \(collected.count) of \(lineCount)")
        }
        for i in 0..<lineCount {
            guard collected[i] == "line-\(i)" else {
                throw TestFailure("order broken at index \(i): \(collected[i])")
            }
        }
    }

    testAsync("simultaneous reads on one reader return distinct complete lines") {
        let (r, w) = makePipePair()
        defer { close(r); close(w) }

        writeString(w, "alpha\nbeta\n")
        let reader = BufferedLineReader(fileDescriptor: r)

        async let first: String = Task.detached {
            try reader.readLine(timeoutMilliseconds: 2000, operationDescription: "parallel-a")
        }.value
        async let second: String = Task.detached {
            try reader.readLine(timeoutMilliseconds: 2000, operationDescription: "parallel-b")
        }.value

        let got = try await [first, second].sorted()
        guard got == ["alpha", "beta"] else {
            throw TestFailure("simultaneous same-reader reads lost or duplicated lines: \(got)")
        }
    }
}
