// Tests for OnDeviceEngine conversation logic, driven through a fake
// GenerationBackend so no model (and no FoundationModels runtime) is needed.
// Token counts in the fake are 1 character = 1 token, so expectations are exact.

import Foundation
import ApfelCore
import ApfelEngine
import CoreGraphics

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

    private(set) var appliedOptions: EngineOptions?
    private(set) var lastImageCount = 0

    func apply(options: EngineOptions) {
        appliedOptions = options
    }

    func stream(prompt: String, images: [PromptImage]) -> AsyncThrowingStream<String, Error> {
        lastImageCount = images.count
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

    test("ErrorRecovery is a two-case pure policy") {
        try assertEqual(ErrorRecovery.allCases, [.preserve, .revert])
        try assertEqual(ErrorRecovery.preserve.rawValue, "preserve")
        try assertEqual(ErrorRecovery.revert.rawValue, "revert")
    }

    testAsync("a failed turn with .revert restores the pre-turn conversation") {
        let backend = FakeBackend(
            initial: [.instructions("sys")],
            turns: [.init(["partial answ"], error: .unknown("boom"))])
        let engine = OnDeviceEngine(backend: backend, errorRecovery: .revert)
        do {
            _ = try await collect(await engine.send("hi"))
            throw TestFailure("expected the turn to throw")
        } catch is TestFailure {
            throw TestFailure("expected the turn to throw")
        } catch let e as ApfelError {
            try assertTrue(e.openAIMessage.contains("boom"), "classified error carries the cause")
        }
        try assertEqual(await backend.entries(), [.instructions("sys")])
    }

    testAsync("a failed turn with .preserve keeps what the runtime left") {
        let backend = FakeBackend(
            initial: [.instructions("sys")],
            turns: [.init(["partial answ"], error: .unknown("boom"))])
        let engine = OnDeviceEngine(backend: backend, errorRecovery: .preserve)
        do {
            _ = try await collect(await engine.send("hi"))
            throw TestFailure("expected the turn to throw")
        } catch is TestFailure {
            throw TestFailure("expected the turn to throw")
        } catch {
            // classified ApfelError - asserted in the .revert test
        }
        try assertEqual(
            await backend.entries(),
            [.instructions("sys"), .prompt("hi"), .response("partial answ")])
    }

    testAsync("a failed turn never counts toward session usage") {
        let backend = FakeBackend(
            turns: [.init(["partial"], error: .unknown("boom"))])
        let engine = OnDeviceEngine(backend: backend, errorRecovery: .revert)
        _ = try? await collect(await engine.send("hi"))
        try assertEqual(await engine.sessionUsage(), TokenUsage(promptTokens: 0, completionTokens: 0))
    }

    testAsync("after a reverted failure the next turn still works") {
        let backend = FakeBackend(
            turns: [
                .init(["partial"], error: .unknown("boom")),
                .init(["recovered"]),
            ])
        let engine = OnDeviceEngine(backend: backend, errorRecovery: .revert)
        _ = try? await collect(await engine.send("hi"))
        let result = try await collect(await engine.send("again"))
        try assertEqual(result.finished.map(\.text), ["recovered"])
        try assertEqual(await backend.entries(), [.prompt("again"), .response("recovered")])
    }

    test("EngineModelInfo.variantName defaults to nil (macOS 26: not reported)") {
        let info = EngineModelInfo(
            availability: .available,
            contextWindow: ContextWindow(tokens: 4096, isMeasured: true),
            capabilities: .notReported)
        try assertNil(info.variantName)
    }

    test("the variant reader defaults to nil") {
        try assertNil(TokenCounter.variantReader())
    }

    testAsync("FoundationModelsBackend.modelInfo carries the injected variant name") {
        let saved = TokenCounter.variantReader
        defer { TokenCounter.variantReader = saved }
        TokenCounter.variantReader = { "AFM 3 Core" }
        let info = await FoundationModelsBackend().modelInfo()
        try assertEqual(info.variantName, "AFM 3 Core")
        // The window still comes from the runtime tracker, never a literal.
        try assertTrue(info.contextWindow.tokens > 0)
    }
}

// MARK: - EngineOptions plumbing (host options -> engine -> backend)

func runEngineOptionsPlumbingTests() {
    testAsync("setOptions normalizes and forwards the options to the backend") {
        let backend = FakeBackend()
        let engine = OnDeviceEngine(backend: backend)
        var options = EngineOptions()
        options.temperature = 5.0  // out of range: engine must clamp before the SDK
        options.useCase = .contentTagging
        await engine.setOptions(options)
        let applied = await backend.appliedOptions
        try assertEqual(applied?.temperature, 2.0)
        try assertEqual(applied?.useCase, .contentTagging)
    }

    testAsync("errorRecovery .revert from setOptions restores the pre-turn conversation") {
        let backend = FakeBackend(
            initial: [.instructions("sys")],
            turns: [.init(["partial"], error: .guardrailViolation)])
        let engine = OnDeviceEngine(backend: backend)
        var options = EngineOptions()
        options.errorRecovery = .revert
        await engine.setOptions(options)
        do {
            _ = try await collect(await engine.send("boom"))
            try assertTrue(false, "send should have thrown")
        } catch {}
        let entries = await backend.entries()
        try assertEqual(entries, [.instructions("sys")])
    }

    testAsync("send with images forwards them to the backend stream") {
        let backend = FakeBackend(turns: [.init(["Red."])])
        let engine = OnDeviceEngine(backend: backend)
        let image = try makeTinyPromptImage()
        let result = try await collect(await engine.send("what color?", images: [image]))
        try assertEqual(result.finished.map(\.text), ["Red."])
        let seen = await backend.lastImageCount
        try assertEqual(seen, 1)
    }
}

/// 1x1 CGImage for plumbing tests (no model, no FoundationModels).
private func makeTinyPromptImage() throws -> PromptImage {
    guard let ctx = CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
        let image = ctx.makeImage() else {
        throw TestFailure("could not build a 1x1 CGImage")
    }
    return PromptImage(image: image)
}
