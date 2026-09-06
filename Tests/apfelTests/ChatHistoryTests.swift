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

    // -- File-preparation security tests (#473) -------------------------

    test("prepareHistoryFile creates file at 0600 before any content is written") {
        let tmp = NSTemporaryDirectory() + "apfel-test-hist-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/sub/history"

        ChatHistory.prepareHistoryFile(at: path)

        let fm = FileManager.default
        try assertTrue(fm.fileExists(atPath: path), "file should exist")
        let attrs = try fm.attributesOfItem(atPath: path)
        let mode = (attrs[.posixPermissions] as? Int) ?? -1
        try assertEqual(mode, 0o600, "file mode should be 0600")
    }

    test("prepareHistoryFile creates parent directories at 0700") {
        let tmp = NSTemporaryDirectory() + "apfel-test-hist-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/nested/dir/history"

        ChatHistory.prepareHistoryFile(at: path)

        let fm = FileManager.default
        for dir in [tmp, tmp + "/nested", tmp + "/nested/dir"] {
            let attrs = try fm.attributesOfItem(atPath: dir)
            let mode = (attrs[.posixPermissions] as? Int) ?? -1
            try assertEqual(mode, 0o700, "directory \(dir) mode should be 0700")
        }
    }

    test("prepareHistoryFile does not change mode of an existing file") {
        let tmp = NSTemporaryDirectory() + "apfel-test-hist-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/history"

        let fm = FileManager.default
        try fm.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        fm.createFile(atPath: path, contents: Data("existing\n".utf8),
                      attributes: [.posixPermissions: 0o600])

        ChatHistory.prepareHistoryFile(at: path)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        try assertEqual(content, "existing\n", "existing content must be preserved")
        let attrs = try fm.attributesOfItem(atPath: path)
        let mode = (attrs[.posixPermissions] as? Int) ?? -1
        try assertEqual(mode, 0o600, "mode must stay 0600")
    }

    test("prepareHistoryFile corrects mode of an existing file to 0600") {
        let tmp = NSTemporaryDirectory() + "apfel-test-hist-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let path = tmp + "/history"

        let fm = FileManager.default
        try fm.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        fm.createFile(atPath: path, contents: Data("data\n".utf8),
                      attributes: [.posixPermissions: 0o644])

        ChatHistory.prepareHistoryFile(at: path)

        let attrs = try fm.attributesOfItem(atPath: path)
        let mode = (attrs[.posixPermissions] as? Int) ?? -1
        try assertEqual(mode, 0o600, "mode must be corrected to 0600")
    }
}
