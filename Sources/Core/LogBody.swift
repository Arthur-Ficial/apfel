// ============================================================================
// LogBody.swift - bounded capture of request bodies for --debug logs.
// Part of ApfelCore.
//
// With --debug the server keeps request bodies for the log store (1000
// entries) and stderr. Bodies can be 24 MiB on macOS 27 (image input), so an
// untruncated capture let a debug server hold gigabytes (Fable review F13).
// ============================================================================

import Foundation

public enum LogBody {
    /// Bytes of a request body kept in a debug log entry.
    public static let defaultLimit = 64 * 1024

    /// The first `limit` bytes of `bytes` as text, with a marker naming the
    /// full size when cut. A cut inside a multi-byte character never fails:
    /// invalid trailing bytes decode as U+FFFD.
    public static func truncatedUTF8<C: Collection>(_ bytes: C, limit: Int = defaultLimit) -> String
    where C.Element == UInt8 {
        guard bytes.count > limit else { return String(decoding: bytes, as: UTF8.self) }
        return String(decoding: bytes.prefix(limit), as: UTF8.self)
            + "\n...[truncated, \(bytes.count) bytes total]"
    }
}
