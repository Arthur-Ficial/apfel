// Tests for OnDeviceEngine conversation logic, driven through a fake
// GenerationBackend so no model (and no FoundationModels runtime) is needed.
// Token counts in the fake are 1 character = 1 token, so expectations are exact.

import Foundation
import ApfelCore
import ApfelEngine

/// Scripted backend: each turn yields cumulative snapshots, then succeeds or
/// throws. Mirrors the real backend's contract — the backend owns appending
/// the prompt and the (possibly partial) response to the conversation.
actor FakeBackend: GenerationBackend {
    struct Turn: Sendable {
        var snapshots: [String]
        var error: ApfelError?
        init(_ snapshots: [String], error: ApfelError? = nil) {
            self.snapshots = snapshots
            self.error = error
        }
    }

    private(set) var conversation: [EngineTranscript.Entry]
    private var turns: [Turn]
    var windowTokens: Int

    init(initial: [EngineTranscript.Entry] = [], turns: [Turn] = [], windowTokens: Int = 10_000) {
        self.conversation = initial
        self.turns = turns
        self.windowTokens = windowTokens
    }

    func reset(entries: [EngineTranscript.Entry]) {
        conversation = entries
    }

    func entries() -> [EngineTranscript.Entry] {
        conversation
    }

    func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let turn = turns.isEmpty ? Turn([""]) : turns.removeFirst()
        conversation.append(.prompt(prompt))
        let final = turn.snapshots.last ?? ""
        if turn.error == nil {
            conversation.append(.response(final))
        } else if !final.isEmpty {
            // The runtime may leave a partial response behind on failure.
            conversation.append(.response(final))
        }
        return AsyncThrowingStream { continuation in
            for snapshot in turn.snapshots {
                continuation.yield(snapshot)
            }
            continuation.finish(throwing: turn.error)
        }
    }

    private func length(_ entry: EngineTranscript.Entry) -> Int {
        switch entry {
        case .instructions(let s), .prompt(let s), .response(let s):
            return s.count
        case .toolCall(let name, let json):
            return name.count + json.count
        case .toolOutput(let name, let content):
            return name.count + content.count
        }
    }

    func count(text: String) -> Int { text.count }

    func count(entries: [EngineTranscript.Entry]) -> Int {
        entries.reduce(0) { $0 + length($1) }
    }

    func inputBudget(outputReserve: Int) -> Int {
        windowTokens - outputReserve
    }

    func contextWindow() -> ContextWindow {
        ContextWindow(tokens: windowTokens, isMeasured: true)
    }

    func modelInfo() -> EngineModelInfo {
        EngineModelInfo(
            availability: .available,
            contextWindow: ContextWindow(tokens: windowTokens, isMeasured: true),
            capabilities: .notReported)
    }

    func prewarm() {}
}

/// Collects every event of one send into arrays the assertions can read.
private func collect(_ stream: AsyncThrowingStream<EngineEvent, Error>) async throws
    -> (deltas: [String], usage: [TokenUsage], finished: [EngineResponse]) {
    var deltas: [String] = []
    var usage: [TokenUsage] = []
    var finished: [EngineResponse] = []
    for try await event in stream {
        switch event {
        case .delta(let d): deltas.append(d)
        case .usage(let u): usage.append(u)
        case .finished(let r): finished.append(r)
        }
    }
    return (deltas, usage, finished)
}

func runOnDeviceEngineTests() {
    testAsync("send reassembles cumulative snapshots into true deltas") {
        let backend = FakeBackend(turns: [.init(["Hel", "Hello", "Hello!"])])
        let engine = OnDeviceEngine(backend: backend)
        let result = try await collect(await engine.send("hi"))
        try assertEqual(result.deltas, ["Hel", "lo", "!"])
        try assertEqual(result.finished.map(\.text), ["Hello!"])
    }

    testAsync("a turn reports counted usage on the event and the response") {
        let backend = FakeBackend(turns: [.init(["Hello"])])
        let engine = OnDeviceEngine(backend: backend)
        let result = try await collect(await engine.send("hi"))
        // Fake counts 1 char = 1 token: prompt "hi" = 2, completion "Hello" = 5.
        let expected = TokenUsage(promptTokens: 2, completionTokens: 5)
        try assertEqual(result.usage, [expected])
        try assertEqual(result.finished.first?.usage, expected)
    }

    testAsync("prompt usage includes the prior conversation") {
        let backend = FakeBackend(
            initial: [.instructions("be terse")],  // 8 tokens
            turns: [.init(["ok"])])
        let engine = OnDeviceEngine(backend: backend)
        let result = try await collect(await engine.send("hi"))
        try assertEqual(result.usage.first?.promptTokens, 8 + 2)
    }

    testAsync("session usage accumulates across turns") {
        let backend = FakeBackend(turns: [.init(["Hello"]), .init(["Bye now"])])
        let engine = OnDeviceEngine(backend: backend)
        _ = try await collect(await engine.send("hi"))
        _ = try await collect(await engine.send("more"))
        // Turn 1: prompt 2, completion 5. Turn 2: prompt (2+5+4)=11, completion 7.
        try assertEqual(
            await engine.sessionUsage(),
            TokenUsage(promptTokens: 13, completionTokens: 12))
    }

    testAsync("session usage starts at zero") {
        let engine = OnDeviceEngine(backend: FakeBackend())
        try assertEqual(await engine.sessionUsage(), TokenUsage(promptTokens: 0, completionTokens: 0))
    }

    testAsync("reset clears session usage and installs the system prompt") {
        let backend = FakeBackend(turns: [.init(["Hello"])])
        let engine = OnDeviceEngine(backend: backend)
        _ = try await collect(await engine.send("hi"))
        await engine.reset(systemPrompt: "sys")
        try assertEqual(await engine.sessionUsage(), TokenUsage(promptTokens: 0, completionTokens: 0))
        try assertEqual(await backend.entries(), [.instructions("sys")])
    }

    testAsync("reset with no system prompt empties the conversation") {
        let backend = FakeBackend(initial: [.prompt("old"), .response("turn")])
        let engine = OnDeviceEngine(backend: backend)
        await engine.reset(systemPrompt: nil)
        try assertEqual(await backend.entries(), [])
    }

    testAsync("context rotation drops oldest turns but keeps instructions") {
        // Window 20, reserve 512 handled via a big window instead: use
        // windowTokens so budget = windowTokens - 512.
        let backend = FakeBackend(
            initial: [
                .instructions("sys"),       // 3
                .prompt("old question"),    // 12
                .response("old answer"),    // 10
            ],
            turns: [.init(["fresh reply"])],
            windowTokens: 512 + 30)
        let engine = OnDeviceEngine(backend: backend)
        _ = try await collect(await engine.send("q2"))
        // After the turn: 3+12+10+2+11 = 38 > 30 — oldest non-instruction
        // entries drop until it fits.
        let after = await backend.entries()
        try assertEqual(after.first, .instructions("sys"))
        try assertTrue(await backend.count(entries: after) <= 30, "rotated under budget")
        try assertEqual(after.last, .response("fresh reply"))
    }

    testAsync("contextStatus reads the backend, never a literal") {
        let backend = FakeBackend(initial: [.prompt("abcd")], windowTokens: 2048)
        let engine = OnDeviceEngine(backend: backend)
        let status = await engine.contextStatus(outputReserve: 512)
        try assertEqual(status.usedTokens, 4)
        try assertEqual(status.budgetTokens, 2048 - 512)
        try assertEqual(status.contextWindow, ContextWindow(tokens: 2048, isMeasured: true))
    }

    testAsync("transcript() snapshots the conversation as EngineTranscript") {
        let backend = FakeBackend(turns: [.init(["Hello"])])
        let engine = OnDeviceEngine(backend: backend)
        _ = try await collect(await engine.send("hi"))
        try assertEqual(
            await engine.transcript(),
            EngineTranscript(entries: [.prompt("hi"), .response("Hello")]))
    }

    testAsync("resume installs a persisted transcript and zeroes session usage") {
        let backend = FakeBackend(turns: [.init(["Hello"])])
        let engine = OnDeviceEngine(backend: backend)
        _ = try await collect(await engine.send("hi"))  // non-zero session usage
        let saved = EngineTranscript(entries: [
            .instructions("be terse"), .prompt("q"), .response("a"),
        ])
        await engine.resume(saved)
        try assertEqual(await backend.entries(), saved.entries)
        try assertEqual(await engine.sessionUsage(), TokenUsage(promptTokens: 0, completionTokens: 0))
    }

    testAsync("save -> encode -> decode -> resume round-trips a conversation") {
        let source = FakeBackend(turns: [.init(["First answer"])])
        let sourceEngine = OnDeviceEngine(backend: source)
        _ = try await collect(await sourceEngine.send("first question"))
        let data = try await sourceEngine.transcript().encode()

        let target = FakeBackend()
        let targetEngine = OnDeviceEngine(backend: target)
        await targetEngine.resume(try EngineTranscript.decode(from: data))
        // Compare the RE-READ conversation against the source's live one.
        try assertEqual(await target.entries(), await source.entries())
    }

    testAsync("modelInfo comes from the backend") {
        let backend = FakeBackend(windowTokens: 4096)
        let engine = OnDeviceEngine(backend: backend)
        let info = await engine.modelInfo()
        try assertEqual(info.availability, .available)
        try assertEqual(info.contextWindow, ContextWindow(tokens: 4096, isMeasured: true))
    }
}
