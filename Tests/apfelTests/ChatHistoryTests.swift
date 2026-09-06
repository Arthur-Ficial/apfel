// ChatHistoryTests - persistent chat-history opt-in decision logic (#259)

import Foundation
import ApfelCLI

func runChatHistoryTests() {
    test("history is off by default (env var absent -> nil)") {
        try assertNil(ChatHistory.filePath(env: [:]))
    }

    test("empty APFEL_HISTFILE is treated as absence (nil)") {
        try assertNil(ChatHistory.filePath(env: ["APFEL_HISTFILE": ""]))
    }

    test("whitespace-only APFEL_HISTFILE is treated as absence (nil)") {
        try assertNil(ChatHistory.filePath(env: ["APFEL_HISTFILE": "   "]))
    }

    test("APFEL_HISTFILE with an absolute path is returned verbatim") {
        try assertEqual(
            ChatHistory.filePath(env: ["APFEL_HISTFILE": "/tmp/apfel_hist"]),
            "/tmp/apfel_hist"
        )
    }

    test("APFEL_HISTFILE leading tilde is expanded to home") {
        let home = NSHomeDirectory()
        try assertEqual(
            ChatHistory.filePath(env: ["APFEL_HISTFILE": "~/.apfel_history"]),
            home + "/.apfel_history"
        )
    }

    test("surrounding whitespace is trimmed before use") {
        try assertEqual(
            ChatHistory.filePath(env: ["APFEL_HISTFILE": "  /tmp/h  "]),
            "/tmp/h"
        )
    }

    test("history bound matches the in-memory stifle limit") {
        try assertEqual(ChatHistory.maxEntries, 500)
    }

    test("prepareHistoryFile creates file at 0600 and directories at 0700") {
        let base = NSTemporaryDirectory() + "apfel-test-hist-\(ProcessInfo.processInfo.processIdentifier)"
        let path = base + "/sub/history"
        defer { try? FileManager.default.removeItem(atPath: base) }

        ChatHistory.prepareHistoryFile(at: path)

        let fm = FileManager.default
        func mode(_ p: String) -> Int? {
            (try? fm.attributesOfItem(atPath: p))?[.posixPermissions] as? Int
        }

        try assertEqual(mode(base), 0o700)
        try assertEqual(mode(base + "/sub"), 0o700)
        try assertEqual(mode(path), 0o600)
    }

    test("prepareHistoryFile does not alter an existing file's mode") {
        let base = NSTemporaryDirectory() + "apfel-test-hist2-\(ProcessInfo.processInfo.processIdentifier)"
        let path = base + "/history"
        defer { try? FileManager.default.removeItem(atPath: base) }

        let fm = FileManager.default
        try? fm.createDirectory(atPath: base, withIntermediateDirectories: true)
        fm.createFile(atPath: path, contents: Data("existing".utf8),
                      attributes: [.posixPermissions: 0o600])

        ChatHistory.prepareHistoryFile(at: path)

        let attrs = try? fm.attributesOfItem(atPath: path)
        let mode = attrs?[.posixPermissions] as? Int
        try assertEqual(mode, 0o600)
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        try assertEqual(content, "existing")
    }
}
