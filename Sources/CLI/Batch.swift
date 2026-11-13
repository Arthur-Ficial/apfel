// ============================================================================
// Batch.swift - The pure pieces of `apfel --batch` (#481): JSONL records in,
// one JSON result line per record out. Part of ApfelCLI (no FoundationModels)
// so framing, record validation, the result contract and the aggregate exit
// status are unit-testable; the executable's runner (Sources/BatchRunner.swift)
// only reads stdin, generates, and writes the lines built here.
//
// Memory is independent of the record count: the framer holds at most one
// record (BatchLimits.maxRecordBytes) plus the unread tail of one read chunk,
// and every result is written before the next chunk is read.
// ============================================================================

import Foundation
import ApfelCore

/// Size bounds for `--batch` input. Part of the documented record contract.
public enum BatchLimits {
    /// Largest accepted record line in bytes (without the newline). A longer
    /// line becomes an `invalid_record` error and is discarded unbuffered.
    public static let maxRecordBytes = 1_048_576
    /// Bytes requested per stdin read: the bound on read-ahead.
    public static let readChunkBytes = 65_536
}

/// One framed input line.
public enum BatchFrame: Sendable, Equatable {
    /// A complete line (newline, CRLF and a leading UTF-8 BOM stripped).
    case line(number: Int, bytes: [UInt8])
    /// A line longer than the record limit; its bytes were discarded.
    case oversized(number: Int)
}

/// Incremental newline framer over raw bytes. Splits on 0x0A only, so a
/// multi-byte UTF-8 character split across reads is reassembled intact
/// (0x0A never occurs inside a multi-byte sequence). Line numbers are
/// 1-based and count every line, blank ones included, so `line` in a result
/// matches the input file.
public struct BatchLineFramer: Sendable {
    private let maxRecordBytes: Int
    private var buffer: [UInt8] = []
    private var discarding = false
    private var lineNumber = 0
    private var sawAnyByte = false

    public init(maxRecordBytes: Int = BatchLimits.maxRecordBytes) {
        self.maxRecordBytes = maxRecordBytes
    }

    /// Bytes held for the current, not yet terminated line.
    public var bufferedByteCount: Int { buffer.count }

    /// Feed the next chunk; returns every line it completes, in order.
    public mutating func feed<C: Collection>(_ chunk: C) -> [BatchFrame] where C.Element == UInt8 {
        var frames: [BatchFrame] = []
        var start = chunk.startIndex
        while start != chunk.endIndex {
            if let nl = chunk[start...].firstIndex(of: 0x0A) {
                append(chunk[start..<nl])
                frames.append(completeLine())
                start = chunk.index(after: nl)
            } else {
                append(chunk[start...])
                start = chunk.endIndex
            }
        }
        return frames
    }

    /// End of input: an unterminated final line is still a record.
    public mutating func finish() -> [BatchFrame] {
        guard discarding || !buffer.isEmpty else { return [] }
        return [completeLine()]
    }

    private mutating func append<S: Collection>(_ bytes: S) where S.Element == UInt8 {
        guard !bytes.isEmpty else { return }
        if !sawAnyByte { sawAnyByte = true }
        guard !discarding else { return }
        // +1 leaves room for a trailing \r that CRLF stripping removes.
        if buffer.count + bytes.count > maxRecordBytes + 1 {
            discarding = true
            buffer = []
            return
        }
        buffer.append(contentsOf: bytes)
    }

    private mutating func completeLine() -> BatchFrame {
        lineNumber += 1
        defer { buffer = []; discarding = false }
        if discarding { return .oversized(number: lineNumber) }
        var bytes = buffer
        if bytes.last == 0x0D { bytes.removeLast() }
        if lineNumber == 1, bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
        if bytes.count > maxRecordBytes { return .oversized(number: lineNumber) }
        return .line(number: lineNumber, bytes: bytes)
    }
}

/// One validated input record.
public struct BatchRecord: Sendable, Equatable {
    public enum Input: Sendable, Equatable {
        case prompt(String)
        /// Conversation JSON, already validated by `MessagesInput.decode`.
        case messages(String)
    }

    public let line: Int
    public let customID: String
    public let input: Input

    public init(line: Int, customID: String, input: Input) {
        self.line = line
        self.customID = customID
        self.input = input
    }
}

/// Result of parsing one framed line.
public enum BatchParseOutcome: Sendable, Equatable {
    /// Empty or whitespace-only line: skipped, no result line.
    case blank
    case record(BatchRecord)
    /// Record-local failure; `customID` is echoed when it could be read.
    case invalid(customID: String?, message: String)
}

/// Validates one JSONL line into a `BatchRecord`. Stateless: records are
/// independent by construction.
public enum BatchRecordParser {
    static let allowedFields: Set<String> = ["custom_id", "prompt", "messages"]

    public static func parse(_ bytes: [UInt8], line: Int) -> BatchParseOutcome {
        guard let text = String(validating: bytes, as: UTF8.self) else {
            return .invalid(customID: nil, message: "record is not valid UTF-8")
        }
        if text.allSatisfy({ $0.isWhitespace }) { return .blank }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: Data(bytes), options: [.fragmentsAllowed])
        } catch {
            return .invalid(customID: nil, message: "record is not valid JSON")
        }
        guard let object = parsed as? [String: Any] else {
            return .invalid(customID: nil, message: "record must be a JSON object with custom_id and prompt or messages")
        }

        let customID: String
        switch object["custom_id"] {
        case nil, is NSNull:
            return .invalid(customID: nil, message: "missing custom_id")
        case let id as String:
            guard !id.isEmpty else { return .invalid(customID: nil, message: "custom_id is empty") }
            customID = id
        default:
            return .invalid(customID: nil, message: "custom_id must be a string (use tostring in jq)")
        }

        if let unknown = object.keys.sorted().first(where: { !allowedFields.contains($0) }) {
            return .invalid(customID: customID, message: "unknown field \"\(unknown)\" (allowed: custom_id, prompt, messages; use -s for a system prompt)")
        }

        let prompt = object["prompt"]
        let messages = object["messages"]
        guard (prompt == nil) != (messages == nil) else {
            return .invalid(customID: customID, message: "record needs exactly one of prompt or messages")
        }

        if let prompt {
            guard let text = prompt as? String else {
                return .invalid(customID: customID, message: "prompt must be a string")
            }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .invalid(customID: customID, message: "prompt is empty")
            }
            return .record(BatchRecord(line: line, customID: customID, input: .prompt(text)))
        }

        guard let messages = messages as? [Any],
              let data = try? JSONSerialization.data(withJSONObject: messages),
              let json = String(data: data, encoding: .utf8) else {
            return .invalid(customID: customID, message: "messages must be an array of OpenAI-style message objects")
        }
        do {
            _ = try MessagesInput.decode(json)
        } catch let e as MessagesInput.Error {
            return .invalid(customID: customID, message: "invalid messages: \(e.message)")
        } catch let e as ToolExchangeGrouping.AssociationError {
            return .invalid(customID: customID, message: "invalid messages: \(e.message)")
        } catch {
            return .invalid(customID: customID, message: "invalid messages")
        }
        return .record(BatchRecord(line: line, customID: customID, input: .messages(json)))
    }
}

/// One output line of `--batch`. Every field is always present, in a fixed
/// order: line, custom_id, status, content, finish_reason, partial_content,
/// error.
public struct BatchResult: Sendable, Equatable {
    public enum Status: String, Sendable {
        case ok
        case error
        /// finish_reason=length: the answer was cut off. A failure; the
        /// partial text is in `partial_content`, never in `content`.
        case incomplete
    }

    public struct ErrorInfo: Sendable, Equatable {
        public let type: String
        public let message: String
        /// The exit code the same failure has in a one-shot run.
        public let exitCode: Int32
    }

    public let line: Int
    public let customID: String?
    public let status: Status
    public let content: String?
    public let finishReason: String?
    public let partialContent: String?
    public let error: ErrorInfo?

    /// Whether this record makes the batch exit nonzero.
    public var isFailure: Bool { status != .ok }

    public static func invalidRecord(line: Int, customID: String?, message: String) -> BatchResult {
        BatchResult(line: line, customID: customID, status: .error, content: nil, finishReason: nil, partialContent: nil,
                    error: ErrorInfo(type: "invalid_record", message: message, exitCode: ApfelExitCodes.usageError))
    }

    public static func oversized(line: Int) -> BatchResult {
        invalidRecord(line: line, customID: nil,
                      message: "record exceeds \(BatchLimits.maxRecordBytes) bytes; it was skipped")
    }

    public static func failure(line: Int, customID: String?, error: ApfelError) -> BatchResult {
        BatchResult(line: line, customID: customID, status: .error, content: nil, finishReason: nil, partialContent: nil,
                    error: ErrorInfo(type: error.openAIType, message: error.openAIMessage,
                                     exitCode: ApfelExitCodes.code(for: error)))
    }

    /// A finished generation. `finishReason` nil means unknown (schema
    /// output, or a cap this Mac cannot detect) and is reported as null.
    package static func generated(
        line: Int, customID: String, content: String,
        finishReason: FinishReason?, truncation: TruncationCause?
    ) -> BatchResult {
        switch finishReason {
        case .length:
            return BatchResult(
                line: line, customID: customID, status: .incomplete, content: nil,
                finishReason: FinishReason.length.openAIValue, partialContent: content,
                error: ErrorInfo(
                    type: "incomplete",
                    message: "incomplete response (finish_reason=length): \(CompletionPolicy.causePhrase(truncation)); the partial text is in partial_content",
                    exitCode: ApfelExitCodes.incomplete))
        case .contentFilter:
            return BatchResult(
                line: line, customID: customID, status: .error, content: nil,
                finishReason: FinishReason.contentFilter.openAIValue, partialContent: nil,
                error: ErrorInfo(type: ApfelError.guardrailViolation.openAIType,
                                 message: content.isEmpty ? ApfelError.guardrailViolation.openAIMessage : content,
                                 exitCode: ApfelExitCodes.guardrail))
        default:
            return BatchResult(line: line, customID: customID, status: .ok, content: content,
                               finishReason: finishReason?.openAIValue, partialContent: nil, error: nil)
        }
    }

    /// The compact, single-line JSON for this result (no trailing newline).
    public var jsonLine: String {
        func str(_ s: String?) -> String { s.map(Self.encode) ?? "null" }
        let errorJSON = error.map {
            "{\"type\":\(Self.encode($0.type)),\"message\":\(Self.encode($0.message)),\"exit_code\":\($0.exitCode)}"
        } ?? "null"
        return "{\"line\":\(line),\"custom_id\":\(str(customID)),\"status\":\(Self.encode(status.rawValue)),"
            + "\"content\":\(str(content)),\"finish_reason\":\(str(finishReason)),"
            + "\"partial_content\":\(str(partialContent)),\"error\":\(errorJSON)}"
    }

    private static func encode(_ s: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(s), let json = String(data: data, encoding: .utf8) else {
            return "\"\""  // unreachable: a Swift String always encodes
        }
        return json
    }
}

/// Aggregate outcome of a batch run.
public struct BatchTally: Sendable, Equatable {
    public private(set) var ok = 0
    public private(set) var failed = 0

    public init() {}

    public mutating func add(_ result: BatchResult) {
        if result.isFailure { failed += 1 } else { ok += 1 }
    }

    /// 0 when every record succeeded (or there were none), 1 when any failed.
    public var exitCode: Int32 { failed > 0 ? ApfelExitCodes.runtimeError : ApfelExitCodes.success }

    /// The stderr summary (printed unless --quiet).
    public var summary: String {
        let total = ok + failed
        return "batch: \(total) record\(total == 1 ? "" : "s"), \(ok) ok, \(failed) failed"
    }
}
