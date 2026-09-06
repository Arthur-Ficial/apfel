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

    // -----------------------------------------------------------------------
    // prepareHistoryPath - file and directory permissions (#473)
    // -----------------------------------------------------------------------

    test("prepareHistoryPath creates file at 0600") {
        let tmp = NSTemporaryDirectory() + "apfel-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/hist"
        ChatHistory.prepareHistoryPath(path)
        let fm = FileManager.default
        try assertTrue(fm.fileExists(atPath: path))
        let attrs = try fm.attributesOfItem(atPath: path)
        let mode = (attrs[.posixPermissions] as? Int) ?? -1
        try assertEqual(mode, 0o600)
    }

    test("prepareHistoryPath creates parent directories at 0700") {
        let tmp = NSTemporaryDirectory() + "apfel-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let sub = tmp + "/a/b"
        let path = sub + "/hist"
        ChatHistory.prepareHistoryPath(path)
        let fm = FileManager.default
        for dir in [tmp, tmp + "/a", sub] {
            let attrs = try fm.attributesOfItem(atPath: dir)
            let mode = (attrs[.posixPermissions] as? Int) ?? -1
            try assertEqual(mode, 0o700)
        }
    }

    test("prepareHistoryPath does not overwrite existing file") {
        let tmp = NSTemporaryDirectory() + "apfel-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/hist"
        try FileManager.default.createDirectory(
            atPath: tmp, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: path, contents: "existing\n".data(using: .utf8))
        ChatHistory.prepareHistoryPath(path)
        let content = try String(contentsOfFile: path, encoding: .utf8)
        try assertEqual(content, "existing\n")
    }

    test("prepareHistoryPath corrects permissions on existing file") {
        let tmp = NSTemporaryDirectory() + "apfel-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/hist"
        try FileManager.default.createDirectory(
            atPath: tmp, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: path, contents: nil,
            attributes: [.posixPermissions: 0o644])
        ChatHistory.prepareHistoryPath(path)
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let mode = (attrs[.posixPermissions] as? Int) ?? -1
        try assertEqual(mode, 0o600)
    }
}
