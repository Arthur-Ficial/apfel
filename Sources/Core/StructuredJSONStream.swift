// ============================================================================
// StructuredJSONStream.swift - append-only streaming of schema-constrained JSON
// Part of ApfelCore - no FoundationModels dependency (#532)
//
// FoundationModels streams guided generation as cumulative snapshots of
// partially generated content. Their own `jsonString` is useless for a byte
// stream: every snapshot is a closed document (`{"title": "Wh"}` is not a
// prefix of `{"title": "Whispers"}`), the key order changes from snapshot to
// snapshot, and a partial number can change value before it completes
// (measured on macOS 27.0.1: `rating` went 4 -> 4.5).
//
// So apfel serializes the content itself, in schema order, and streams only
// the *stable prefix* of each snapshot: everything up to the value currently
// being generated, plus the text of an open string (strings only grow). Open
// numbers and booleans are held back until complete. The non-streamed path
// uses the same serializer, so the concatenated deltas equal the non-streamed
// document byte for byte.
// ============================================================================

import Foundation

/// A snapshot of (possibly partially) generated JSON, with object members in
/// schema order and a completeness flag per value.
package indirect enum PartialJSON: Equatable, Sendable {
    /// An object member, in schema order.
    package struct Member: Equatable, Sendable {
        package let key: String
        package let value: PartialJSON
        package init(key: String, value: PartialJSON) {
            self.key = key
            self.value = value
        }
    }

    case object([Member], complete: Bool)
    case array([PartialJSON], complete: Bool)
    case string(String, complete: Bool)
    case number(Double, complete: Bool)
    case bool(Bool, complete: Bool)
    case null

    var isComplete: Bool {
        switch self {
        case .object(_, let c), .array(_, let c), .string(_, let c), .number(_, let c), .bool(_, let c):
            return c
        case .null:
            return true
        }
    }
}

/// Serialization of `PartialJSON`: the full document, and the stable prefix
/// of a snapshot that can be streamed without ever rewriting sent text.
package enum StructuredJSON {

    /// The complete document. Compact layout with `", "` and `": "`
    /// separators; integral numbers print without a fraction.
    package static func serialize(_ value: PartialJSON) -> String {
        var out = ""
        write(value, into: &out)
        return out
    }

    /// The longest prefix of the eventual document this snapshot already
    /// determines. A complete value is serialized in full; an incomplete
    /// container stays open and stops at its first incomplete member; an open
    /// string is written without its closing quote; an open number or bool
    /// writes nothing.
    package static func stablePrefix(_ value: PartialJSON) -> String {
        var out = ""
        writePrefix(value, into: &out)
        return out
    }

    private static func write(_ value: PartialJSON, into out: inout String) {
        switch value {
        case .object(let members, _):
            out += "{"
            for (i, m) in members.enumerated() {
                if i > 0 { out += ", " }
                writeString(m.key, into: &out)
                out += ": "
                write(m.value, into: &out)
            }
            out += "}"
        case .array(let items, _):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += ", " }
                write(item, into: &out)
            }
            out += "]"
        case .string(let s, _):
            writeString(s, into: &out)
        case .number(let d, _):
            out += formatNumber(d)
        case .bool(let b, _):
            out += b ? "true" : "false"
        case .null:
            out += "null"
        }
    }

    private static func writePrefix(_ value: PartialJSON, into out: inout String) {
        if value.isComplete {
            write(value, into: &out)
            return
        }
        switch value {
        case .object(let members, _):
            out += "{"
            for (i, m) in members.enumerated() {
                if i > 0 { out += ", " }
                writeString(m.key, into: &out)
                out += ": "
                if !m.value.isComplete {
                    writePrefix(m.value, into: &out)
                    return
                }
                write(m.value, into: &out)
            }
        case .array(let items, _):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += ", " }
                if !item.isComplete {
                    writePrefix(item, into: &out)
                    return
                }
                write(item, into: &out)
            }
        case .string(let s, _):
            out += "\""
            out += escaped(s)
        case .number, .bool, .null:
            break
        }
    }

    private static func writeString(_ s: String, into out: inout String) {
        out += "\""
        out += escaped(s)
        out += "\""
    }

    /// JSON string escaping, one Unicode scalar at a time, so a growing string
    /// always produces a growing escaped text.
    private static func escaped(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.unicodeScalars.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }

    private static func formatNumber(_ d: Double) -> String {
        guard d.isFinite else { return "null" }
        if d == d.rounded(), abs(d) < 1e15 {
            return String(Int64(d))
        }
        return "\(d)"
    }
}

/// Thrown when the final document does not extend the text already streamed.
/// That would mean a client concatenating the deltas holds invalid JSON, so
/// it is reported as an error instead of being papered over.
package struct StructuredJSONStreamError: Error, Equatable, Sendable {
    package let message: String
}

/// Tracks what has been streamed and turns successive stable prefixes into
/// append-only deltas. Comparison and slicing work on Unicode scalars (#543),
/// so a combining mark that extends the previous character is a valid delta.
package struct StructuredJSONStreamer: Sendable {
    package private(set) var emitted = ""
    private var emittedScalars = 0

    package init() {}

    /// The new text beyond what was emitted, or nil when `prefix` adds nothing
    /// or would rewrite already-sent text (held back until it extends again).
    package mutating func advance(to prefix: String) -> String? {
        let scalars = prefix.unicodeScalars
        guard scalars.count > emittedScalars,
              scalars.starts(with: emitted.unicodeScalars) else { return nil }
        let start = scalars.index(scalars.startIndex, offsetBy: emittedScalars)
        let delta = String(scalars[start...])
        emitted = prefix
        emittedScalars = scalars.count
        return delta
    }

    /// The remainder of the final document, or nil when everything was sent.
    /// Throws when `final` does not start with the emitted text.
    package mutating func finish(with final: String) throws -> String? {
        guard final.unicodeScalars.starts(with: emitted.unicodeScalars) else {
            throw StructuredJSONStreamError(message:
                "structured stream is not append-only: the final JSON does not extend the \(emittedScalars) characters already sent")
        }
        return advance(to: final)
    }
}
