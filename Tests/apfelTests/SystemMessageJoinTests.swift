// SystemMessageJoinTests - joinedSystemContent (#390)

import Foundation
import ApfelCore

func runSystemMessageJoinTests() {

    test("single system message returns its content unchanged") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "user", content: .text("Hi")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "Be concise.")
    }

    test("two system messages are joined with double newline") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Be concise.")),
            OpenAIMessage(role: "system", content: .text("Reply in French.")),
            OpenAIMessage(role: "user", content: .text("Hi")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "Be concise.\n\nReply in French.")
    }

    test("three system messages preserve order and all content") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("First.")),
            OpenAIMessage(role: "user", content: .text("ignored")),
            OpenAIMessage(role: "system", content: .text("Second.")),
            OpenAIMessage(role: "system", content: .text("Third.")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "First.\n\nSecond.\n\nThird.")
    }

    test("no system messages returns nil") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "user", content: .text("Hi")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertNil(result)
    }

    test("empty messages array returns nil") {
        let result = OpenAIMessage.joinedSystemContent(from: [])
        try assertNil(result)
    }

    test("system messages with empty content are skipped") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Keep this.")),
            OpenAIMessage(role: "system", content: .text("")),
            OpenAIMessage(role: "system", content: .text("And this.")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "Keep this.\n\nAnd this.")
    }

    test("system message with nil content is skipped") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Real.")),
            OpenAIMessage(role: "system", content: nil),
            OpenAIMessage(role: "user", content: .text("Hi")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "Real.")
    }

    test("only empty system messages returns nil") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("")),
            OpenAIMessage(role: "system", content: nil),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertNil(result)
    }

    test("developer-mapped system messages from Responses path are joined") {
        let msgs: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: .text("Instructions from request.")),
            OpenAIMessage(role: "system", content: .text("Developer policy.")),
            OpenAIMessage(role: "user", content: .text("Go")),
        ]
        let result = OpenAIMessage.joinedSystemContent(from: msgs)
        try assertEqual(result, "Instructions from request.\n\nDeveloper policy.")
    }
}
