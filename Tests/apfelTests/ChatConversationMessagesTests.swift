// Tests for conversationMessages(systemPrompt:transcript:currentTurn:) -
// the chat transcript rebuilt as OpenAI messages for the guided tool step
// (#590 item 1), so the decision sees the conversation so far, not only the
// current turn ("Now add 9 to that result." must be able to resolve "that").

import Foundation
import FoundationModels
import ApfelCore
import ApfelEngine

private func entry(prompt text: String) -> Transcript.Entry {
    .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: text))]))
}

private func entry(response text: String) -> Transcript.Entry {
    .response(Transcript.Response(assetIDs: [], segments: [.text(Transcript.TextSegment(content: text))]))
}

private func entry(instructions text: String) -> Transcript.Entry {
    .instructions(Transcript.Instructions(
        segments: [.text(Transcript.TextSegment(content: text))], toolDefinitions: []))
}

func runChatConversationMessagesTests() {
    test("turns become user/assistant messages with the current turn last (#590)") {
        let transcript = Transcript(entries: [
            entry(instructions: "tool list and calling format"),
            entry(prompt: "What's 17 times 23?"),
            entry(response: "17 times 23 is 391."),
        ])
        let messages = conversationMessages(
            systemPrompt: nil, transcript: transcript, currentTurn: "Now add 9 to that result.")
        try assertEqual(messages.map(\.role), ["user", "assistant", "user"])
        try assertEqual(messages[0].textContent, "What's 17 times 23?")
        try assertEqual(messages[1].textContent, "17 times 23 is 391.")
        try assertEqual(messages[2].textContent, "Now add 9 to that result.")
    }

    test("the system prompt leads; transcript instructions (tool text) are not repeated") {
        let transcript = Transcript(entries: [
            entry(instructions: "Be terse.\n\nAVAILABLE FUNCTIONS: ..."),
            entry(prompt: "hi"),
            entry(response: "hello"),
        ])
        let messages = conversationMessages(
            systemPrompt: "Be terse.", transcript: transcript, currentTurn: "and now?")
        try assertEqual(messages.map(\.role), ["system", "user", "assistant", "user"])
        try assertEqual(messages[0].textContent, "Be terse.")
        try assertTrue(!messages.contains { ($0.textContent ?? "").contains("AVAILABLE FUNCTIONS") })
    }

    test("an empty transcript yields system + current turn only") {
        let messages = conversationMessages(
            systemPrompt: "sys", transcript: Transcript(entries: []), currentTurn: "first")
        try assertEqual(messages.map(\.role), ["system", "user"])
        try assertEqual(messages[1].textContent, "first")
    }

    test("empty-text entries are dropped") {
        let transcript = Transcript(entries: [
            entry(prompt: ""),
            entry(response: "ok"),
        ])
        let messages = conversationMessages(
            systemPrompt: nil, transcript: transcript, currentTurn: "next")
        try assertEqual(messages.map(\.role), ["assistant", "user"])
    }
}
