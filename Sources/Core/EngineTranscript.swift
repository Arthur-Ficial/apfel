// ============================================================================
// EngineTranscript.swift — versioned, Codable conversation persistence.
//
// apfel's OWN on-disk conversation format, independent of Apple's Transcript
// type: a saved file must stay readable even if the SDK's Codable shape
// changes between macOS releases. The `version` field is the compatibility
// contract — a decoder refuses data written by a future format version with
// a clear error instead of misreading or crashing.
// ============================================================================

import Foundation

/// Why a persisted transcript could not be decoded.
public enum EngineTranscriptError: Error, Equatable, CustomStringConvertible {
    /// The data was written by an unknown format version (newer apfel, or
    /// a corrupted version field).
    case unsupportedVersion(found: Int, supported: Int)
    /// An entry names a kind this version does not know.
    case unrecognizedEntryKind(String)

    public var description: String {
        switch self {
        case .unsupportedVersion(let found, let supported):
            return "transcript format version \(found) is not supported (this apfel reads up to version \(supported) - written by a newer apfel?)"
        case .unrecognizedEntryKind(let kind):
            return "transcript contains an unrecognized entry kind \"\(kind)\""
        }
    }
}

/// A persisted conversation: version marker plus ordered entries.
///
/// Pure data - no FoundationModels. The engine converts these entries to and
/// from the runtime's transcript; tool exchanges are carried so out-of-band
/// tool-calling sessions (#119) survive a save/resume.
public struct EngineTranscript: Sendable, Equatable {
    /// The format version this apfel writes (and the highest it reads).
    public static let currentVersion = 1

    public let version: Int
    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.version = Self.currentVersion
        self.entries = entries
    }

    /// One conversation turn element.
    public enum Entry: Sendable, Equatable {
        case instructions(String)
        case prompt(String)
        case response(String)
        case toolCall(toolName: String, argumentsJSON: String)
        case toolOutput(toolName: String, content: String)
    }

    /// Serialize to JSON for persistence.
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Deserialize persisted JSON, refusing future format versions with a
    /// clear `EngineTranscriptError` (never a crash).
    public static func decode(from data: Data) throws -> EngineTranscript {
        try JSONDecoder().decode(EngineTranscript.self, from: data)
    }
}

extension EngineTranscript: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, entries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard (1...Self.currentVersion).contains(version) else {
            throw EngineTranscriptError.unsupportedVersion(
                found: version, supported: Self.currentVersion)
        }
        self.version = version
        self.entries = try container.decode([Entry].self, forKey: .entries)
    }
}

extension EngineTranscript.Entry: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, content, toolName, argumentsJSON
    }

    private enum Kind: String {
        case instructions, prompt, response, toolCall, toolOutput
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decode(String.self, forKey: .kind)
        guard let kind = Kind(rawValue: rawKind) else {
            throw EngineTranscriptError.unrecognizedEntryKind(rawKind)
        }
        switch kind {
        case .instructions:
            self = .instructions(try container.decode(String.self, forKey: .content))
        case .prompt:
            self = .prompt(try container.decode(String.self, forKey: .content))
        case .response:
            self = .response(try container.decode(String.self, forKey: .content))
        case .toolCall:
            self = .toolCall(
                toolName: try container.decode(String.self, forKey: .toolName),
                argumentsJSON: try container.decode(String.self, forKey: .argumentsJSON))
        case .toolOutput:
            self = .toolOutput(
                toolName: try container.decode(String.self, forKey: .toolName),
                content: try container.decode(String.self, forKey: .content))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .instructions(let content):
            try container.encode(Kind.instructions.rawValue, forKey: .kind)
            try container.encode(content, forKey: .content)
        case .prompt(let content):
            try container.encode(Kind.prompt.rawValue, forKey: .kind)
            try container.encode(content, forKey: .content)
        case .response(let content):
            try container.encode(Kind.response.rawValue, forKey: .kind)
            try container.encode(content, forKey: .content)
        case .toolCall(let toolName, let argumentsJSON):
            try container.encode(Kind.toolCall.rawValue, forKey: .kind)
            try container.encode(toolName, forKey: .toolName)
            try container.encode(argumentsJSON, forKey: .argumentsJSON)
        case .toolOutput(let toolName, let content):
            try container.encode(Kind.toolOutput.rawValue, forKey: .kind)
            try container.encode(toolName, forKey: .toolName)
            try container.encode(content, forKey: .content)
        }
    }
}
