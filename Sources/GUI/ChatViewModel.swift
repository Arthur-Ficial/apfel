// ============================================================================
// ChatViewModel.swift — State management for the chat interface
// Talks to apfel --serve via APIClient. No AI logic here.
// ============================================================================

import Foundation
import SwiftUI

/// A single chat message with debug metadata.
struct ChatMsg: Identifiable {
    let id: String
    let role: String        // "user" or "assistant"
    var content: String     // grows during streaming
    let timestamp: Date
    var requestJSON: String?
    var responseJSON: String?
    var curlCommand: String?
    var durationMs: Int?
    var tokenCount: Int?
    var isStreaming: Bool = false
}

/// Observable state for the chat interface.
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMsg] = []
    var currentInput: String = ""
    var systemPrompt: String = ""
    var isStreaming: Bool = false
    var selectedMessageId: String?
    var errorMessage: String?
    var showDebugPanel: Bool = true
    var showLogPanel: Bool = true
    var debugAutoFollow: Bool = true
    var speakEnabled: Bool = false

    let apiClient: APIClient
    let tts = TTSManager()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// The currently selected message (for debug panel).
    var selectedMessage: ChatMsg? {
        guard let id = selectedMessageId else { return nil }
        return messages.first { $0.id == id }
    }

    /// Send the current input as a message and stream the response.
    func send() async {
        let input = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isStreaming else { return }

        // Build message history (before adding this message)
        var history = messages.filter { $0.role == "user" || $0.role == "assistant" }
            .map { (role: $0.role, content: $0.content) }
        history.append((role: "user", content: input))

        // Get request JSON early so user message can show it too
        let (stream, requestJSON) = apiClient.streamChatCompletion(
            messages: history,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )

        // Build curl command for debug
        let port = 11434
        let curlCmd = "curl -X POST http://127.0.0.1:\(port)/v1/chat/completions \\\n  -H \"Content-Type: application/json\" \\\n  -d '\(requestJSON.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  ", with: ""))'"

        // Add user message (with request JSON attached)
        let userId = UUID().uuidString
        let userMsg = ChatMsg(
            id: userId,
            role: "user",
            content: input,
            timestamp: Date(),
            requestJSON: requestJSON,
            curlCommand: curlCmd
        )
        messages.append(userMsg)
        currentInput = ""
        isStreaming = true
        errorMessage = nil

        // Create assistant message placeholder
        let assistantId = UUID().uuidString
        messages.append(ChatMsg(
            id: assistantId,
            role: "assistant",
            content: "",
            timestamp: Date(),
            requestJSON: requestJSON,
            curlCommand: curlCmd,
            isStreaming: true
        ))

        let start = Date()

        do {
            for try await delta in stream {
                updateMessage(id: assistantId) { $0.content += delta }
            }

            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let rawResponse = APIClient.lastRawSSEResponse
            updateMessage(id: assistantId) { msg in
                msg.isStreaming = false
                msg.durationMs = durationMs
                msg.tokenCount = max(1, msg.content.count / 4)
                msg.responseJSON = rawResponse
            }

            // Auto-follow: select the latest assistant message in debug panel
            if debugAutoFollow {
                selectedMessageId = assistantId
            }

            // Speak the response if TTS is enabled
            if speakEnabled, let content = messages.first(where: { $0.id == assistantId })?.content {
                tts.speak(content)
            }
        } catch {
            updateMessage(id: assistantId) { msg in
                msg.content = "Error: \(error.localizedDescription)"
                msg.isStreaming = false
            }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
    }

    /// Clear all messages.
    func clear() {
        messages.removeAll()
        selectedMessageId = nil
        errorMessage = nil
    }

    // MARK: - Helpers

    private func updateMessage(id: String, update: (inout ChatMsg) -> Void) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            update(&messages[idx])
        }
    }

    private func jsonEscape(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
