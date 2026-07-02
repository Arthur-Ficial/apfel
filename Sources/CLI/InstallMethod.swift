// ============================================================================
// InstallMethod.swift — Detect how the apfel binary was installed.
//
// The self-update flow (`apfel --update`) prints different instructions per
// install method. Detection is path-based (no network, no shell-outs), which
// keeps it cheap, fast, and offline.
// ============================================================================

import Foundation

public enum InstallMethod: Equatable, Sendable {
    case homebrew
    case macports
    case source
}

/// Classify how a binary was installed based on its absolute (symlink-resolved)
/// path on disk.
///
/// - `homebrew`: path lives under `*/homebrew/Cellar/apfel/` or `*/homebrew/opt/apfel/`.
/// - `macports`: binary lives at `<prefix>/bin/apfel` and `<prefix>/var/macports`
///   exists as a directory. This is the canonical MacPorts marker and works for
///   the default `/opt/local` prefix and custom prefixes alike.
/// - `source`: anything else (manual `make install`, `swift build`, custom dir).
public func detectInstallMethod(
    binaryPath: String,
    fileManager: FileManager = .default
) -> InstallMethod {
    if binaryPath.contains("/homebrew/Cellar/apfel/") || binaryPath.contains("/homebrew/opt/apfel/") {
        return .homebrew
    }

    let prefixURL = URL(fileURLWithPath: binaryPath)
        .deletingLastPathComponent()  // <prefix>/bin
        .deletingLastPathComponent()  // <prefix>
    let macportsMarker = prefixURL.appendingPathComponent("var/macports").path
    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: macportsMarker, isDirectory: &isDir), isDir.boolValue {
        return .macports
    }

    return .source
}

/// Derive the Homebrew prefix from a resolved binary path.
///
/// For a Cellar path like `/opt/homebrew/Cellar/apfel/1.3.5/bin/apfel`,
/// returns `/opt/homebrew`. For an opt symlink path like
/// `/usr/local/homebrew/opt/apfel/bin/apfel`, returns `/usr/local/homebrew`.
/// Falls back to `/opt/homebrew` if neither pattern matches (caller should
/// only invoke this after `detectInstallMethod` returned `.homebrew`).
public func brewPrefix(from binaryPath: String) -> String {
    if let range = binaryPath.range(of: "/Cellar/apfel/") {
        return String(binaryPath[..<range.lowerBound])
    }
    if let range = binaryPath.range(of: "/opt/apfel/") {
        return String(binaryPath[..<range.lowerBound])
    }
    return "/opt/homebrew"
}
