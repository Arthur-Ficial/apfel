// ============================================================================
// ChatViewModel.swift — State management for the chat interface
// Talks to apfel --serve via APIClient. No AI logic here.
// ============================================================================

import Foundation
import SwiftUI
import ApfelCore

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
    var includeInHistory: Bool = true
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
    var isSelfDiscussing: Bool = false
    var showSelfDiscussion: Bool = false
    var showContextSettings: Bool = false
    var contextStrategyRaw: String = ContextStrategy.newestFirst.rawValue
    var contextMaxTurns: Int? = nil
    var contextOutputReserve: Int = 512

    var contextStrategy: ContextStrategy {
        get { ContextStrategy(rawValue: contextStrategyRaw) ?? .newestFirst }
        set { contextStrategyRaw = newValue.rawValue }
    }

    let apiClient: APIClient
    let tts = TTSManager()
    let stt = STTManager()

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
        var history = messages.filter { ($0.role == "user" || $0.role == "assistant") && $0.includeInHistory }
            .map { (role: $0.role, content: $0.content) }
        history.append((role: "user", content: input))

        // Get request JSON early so user message can show it too
        let currentStrategy = ContextStrategy(rawValue: contextStrategyRaw) ?? .newestFirst
        let strategy = currentStrategy == .newestFirst ? nil : currentStrategy.rawValue
        let maxTurns = contextMaxTurns
        let reserve = contextOutputReserve == 512 ? nil : contextOutputReserve
        let (stream, requestJSON) = apiClient.streamChatCompletion(
            messages: history,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            contextStrategy: strategy,
            contextMaxTurns: maxTurns,
            contextOutputReserve: reserve
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
            let assistantContent = messages.first(where: { $0.id == assistantId })?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            updateMessage(id: assistantId) { msg in
                msg.isStreaming = false
                msg.durationMs = durationMs
                msg.tokenCount = APIClient.lastStreamingUsage?.totalTokens
                msg.responseJSON = rawResponse
            }
            if shouldExcludeTurnFromHistory(assistantContent) {
                updateMessage(id: userId) { $0.includeInHistory = false }
                updateMessage(id: assistantId) { $0.includeInHistory = false }
                if assistantContent.isEmpty {
                    updateMessage(id: assistantId) { $0.content = "Error: Empty response from model." }
                    errorMessage = "Empty response from model."
                }
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
                msg.includeInHistory = false
            }
            updateMessage(id: userId) { $0.includeInHistory = false }
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

    private func shouldExcludeTurnFromHistory(_ assistantContent: String) -> Bool {
        let lowered = assistantContent.lowercased()
        if assistantContent.isEmpty { return true }
        let refusalPatterns = [
            "can't assist with that request",
            "cannot assist with that request",
            "can't help with that request",
            "cannot help with that request",
            "i'm sorry, but i can't assist",
            "i'm sorry, but i cannot assist",
            "unsafe",
            "safety reasons",
            "error:"
        ]
        return refusalPatterns.contains { lowered.contains($0) }
    }

    // MARK: - Voice Input

    func toggleListening() {
        if stt.isListening {
            errorMessage = nil
            let transcript = stt.stopListening()
            if !transcript.isEmpty {
                currentInput += (currentInput.isEmpty ? "" : " ") + transcript
                Task {
                    await send()
                }
            }
        } else {
            Task {
                do {
                    errorMessage = nil
                    let authorized = await stt.requestPermissions()
                    if authorized {
                        stt.startListening()
                        if let err = stt.errorMessage {
                            errorMessage = err
                        }
                    } else {
                        errorMessage = stt.errorMessage ?? "Microphone/speech permission denied. Enable in System Settings → Privacy & Security."
                    }
                }
            }
        }
    }

    // MARK: - Self-Discussion

    /// AI debates itself for N turns on a topic, alternating between two system prompts.
    func startSelfDiscussion(
        topic: String,
        turns: Int,
        systemA: String,
        systemB: String,
        languageCodeA: String,
        languageCodeB: String
    ) async {
        guard !isSelfDiscussing else { return }
        isSelfDiscussing = true
        isStreaming = true

        // Add the topic as a user message
        let topicMsg = ChatMsg(
            id: UUID().uuidString,
            role: "user",
            content: "Topic: \(topic)",
            timestamp: Date()
        )
        messages.append(topicMsg)

        var previousResponse = topic

        for turn in 1...turns {
            let isA = turn % 2 == 1
            let systemPromptForTurn = localizedSystemPrompt(
                base: isA ? systemA : systemB,
                languageCode: isA ? languageCodeA : languageCodeB
            )
            let speechLanguage = isA ? languageCodeA : languageCodeB

            // Create assistant placeholder
            let msgId = UUID().uuidString
            messages.append(ChatMsg(
                id: msgId,
                role: "assistant",
                content: "",
                timestamp: Date(),
                isStreaming: true
            ))

            let prompt = turn == 1
                ? topic
                : "The previous speaker said: \"\(previousResponse)\"\n\nNow respond to this."

            let history: [(role: String, content: String)] = [(role: "user", content: prompt)]
            let (stream, requestJSON) = apiClient.streamChatCompletion(
                messages: history,
                systemPrompt: systemPromptForTurn
            )

            updateMessage(id: msgId) { $0.requestJSON = requestJSON }

            let start = Date()
            do {
                for try await delta in stream {
                    updateMessage(id: msgId) { $0.content += delta }
                }

                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                let rawResponse = APIClient.lastRawSSEResponse
                updateMessage(id: msgId) { msg in
                    msg.isStreaming = false
                    msg.durationMs = durationMs
                    msg.tokenCount = nil  // real count comes from server usage stats
                    msg.responseJSON = rawResponse
                }

                previousResponse = messages.first(where: { $0.id == msgId })?.content ?? ""

                if debugAutoFollow {
                    selectedMessageId = msgId
                }

                // Speak if enabled
                if speakEnabled, !previousResponse.isEmpty {
                    tts.speak(previousResponse, languageCode: speechLanguage, voiceVariant: isA ? 0 : 1)
                    // Wait for speech to finish before next turn
                    while tts.isSpeaking {
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                }

            } catch {
                updateMessage(id: msgId) { msg in
                    msg.content = "Error: \(error.localizedDescription)"
                    msg.isStreaming = false
                }
                break
            }
        }

        isSelfDiscussing = false
        isStreaming = false
    }

    private func localizedSystemPrompt(base: String, languageCode: String) -> String {
        let languageLabel = TTSManager.preferredVoices.first(where: { $0.languageCode == languageCode })?.label ?? languageCode
        return "\(base)\n\nRespond only in \(languageLabel)."
    }
}
