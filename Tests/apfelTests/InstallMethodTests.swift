// ============================================================================
// InstallMethodTests.swift — Coverage for path-based install method detection.
//
// Real filesystem test: lay down a synthetic <prefix>/bin/apfel layout in a
// temp dir, then assert detection picks the right enum case. No mocking, no DI.
// ============================================================================

import Foundation
import ApfelCLI

func runInstallMethodTests() {
    test("Homebrew Cellar path -> .homebrew") {
        let path = "/opt/homebrew/Cellar/apfel/1.3.5/bin/apfel"
        try assertEqual(detectInstallMethod(binaryPath: path), .homebrew)
    }

    test("Homebrew opt symlink path -> .homebrew") {
        let path = "/opt/homebrew/opt/apfel/bin/apfel"
        try assertEqual(detectInstallMethod(binaryPath: path), .homebrew)
    }

    test("Intel Homebrew path -> .homebrew") {
        let path = "/usr/local/homebrew/Cellar/apfel/1.3.5/bin/apfel"
        try assertEqual(detectInstallMethod(binaryPath: path), .homebrew)
    }

    test("MacPorts default prefix with var/macports marker -> .macports") {
        let tmp = makeTempPrefix()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("var/macports"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("bin/apfel").path, contents: nil)

        let result = detectInstallMethod(binaryPath: tmp.appendingPathComponent("bin/apfel").path)
        try assertEqual(result, .macports)
    }

    test("Custom MacPorts prefix is detected the same way") {
        let tmp = makeTempPrefix()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let prefix = tmp.appendingPathComponent("opt/macports-custom")
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("var/macports"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: prefix.appendingPathComponent("bin/apfel").path, contents: nil)

        let result = detectInstallMethod(binaryPath: prefix.appendingPathComponent("bin/apfel").path)
        try assertEqual(result, .macports)
    }

    test("MacPorts marker that is a file (not a directory) -> .source") {
        let tmp = makeTempPrefix()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("var"), withIntermediateDirectories: true)
        // var/macports as a regular file, not a directory — should NOT count as MacPorts
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("var/macports").path, contents: nil)
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("bin/apfel").path, contents: nil)

        let result = detectInstallMethod(binaryPath: tmp.appendingPathComponent("bin/apfel").path)
        try assertEqual(result, .source)
    }

    test("Manual install at /usr/local/bin -> .source") {
        // Nothing on disk at /usr/local/var/macports, so this resolves to .source.
        // (If a user happens to have MacPorts at /usr/local with apfel hand-installed
        // there too, MacPorts wins — acceptable edge case.)
        let result = detectInstallMethod(binaryPath: "/usr/local/bin/apfel")
        // Real filesystem on a dev machine has no /usr/local/var/macports — assert source.
        var isDir: ObjCBool = false
        let macportsExists = FileManager.default.fileExists(atPath: "/usr/local/var/macports", isDirectory: &isDir) && isDir.boolValue
        if macportsExists {
            try assertEqual(result, .macports)
        } else {
            try assertEqual(result, .source)
        }
    }

    test("Arbitrary source path -> .source") {
        let tmp = makeTempPrefix()
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("bin"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("bin/apfel").path, contents: nil)

        let result = detectInstallMethod(binaryPath: tmp.appendingPathComponent("bin/apfel").path)
        try assertEqual(result, .source)
    }
}

private func makeTempPrefix() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("apfel-install-method-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
