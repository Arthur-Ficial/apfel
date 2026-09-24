// ============================================================================
// MessagesInput.swift - Pure decoder for --messages conversation JSON (#363)
// Part of ApfelCore - no FoundationModels dependency
//
// Accepts either a bare JSON array of OpenAI-style message objects or an
// object with a `messages` key (both shapes are common in the wild). The
// validation rules deliberately mirror the server's ChatRequestValidator so
// a conversation that 400s on /v1/chat/completions exits 2 on the CLI.
// ============================================================================

import Foundation

public enum MessagesInput {

    public enum Error: Swift.Error, Equatable {
        case invalidJSON
        case emptyMessages
        case unknownRole(String)
        case invalidLastRole(String)
        case emptyLastMessage

        /// User-facing description, phrased like the server's 400 messages.
        public var message: String {
            switch self {
            case .invalidJSON:
                return "not a JSON array of messages (or an object with a \"messages\" key)"
            case .emptyMessages:
                return "messages array is empty"
            case .unknownRole(let role):
                return "unknown role \"\(role)\" (allowed: system, user, assistant, tool)"
            case .invalidLastRole(let role):
                return "last message must have role user or tool, got \"\(role)\""
            case .emptyLastMessage:
                return "last user message has empty content"
            }
        }
    }

    static let allowedRoles: Set<String> = ["system", "user", "assistant", "tool"]

    private struct Wrapper: Decodable {
        let messages: [OpenAIMessage]
    }

    /// Decode and validate conversation JSON into OpenAI-style messages.
    /// Throws `MessagesInput.Error` for shape problems and
    /// `ToolExchangeGrouping.AssociationError` for a tool call/result mismatch.
    public static func decode(_ json: String) throws -> [OpenAIMessage] {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let messages: [OpenAIMessage]
        if let array = try? decoder.decode([OpenAIMessage].self, from: data) {
            messages = array
        } else if let wrapped = try? decoder.decode(Wrapper.self, from: data) {
            messages = wrapped.messages
        } else {
            throw Error.invalidJSON
        }

        guard let last = messages.last else { throw Error.emptyMessages }
        for m in messages where !allowedRoles.contains(m.role) {
            throw Error.unknownRole(m.role)
        }
        guard last.role == "user" || last.role == "tool" else {
            throw Error.invalidLastRole(last.role)
        }
        if last.role == "user" {
            let text = (last.textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw Error.emptyLastMessage }
        }
        // Tool calls and their results must pair up (server parity, #482).
        if let association = ToolExchangeGrouping.validate(messages) {
            throw association
        }
        return messages
    }
}
