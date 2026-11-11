# Swift Libraries: ApfelCore and ApfelEngine

`ApfelCore` is the pure, FoundationModels-free Swift Package product inside this repo. It exists for Swift developers who want the reusable policy pieces - OpenAI-compatible types, validation, MCP helpers, schema parsing, retry classification, context-trimming strategies - without depending on the `apfel` executable.

**The main product is the `apfel` CLI and the `apfel --serve` OpenAI-compatible server.** The Swift library is a secondary surface for downstream developers. If you just want to talk to Apple's on-device model, use the CLI or the server - you do not need this library.

## When to depend on `ApfelCore`

Good fit:

- You are writing a Swift app that calls FoundationModels directly and want to speak OpenAI-shaped JSON over the wire.
- You want apfel's context-trimming strategies, tool-call parsing, or MCP protocol types without the CLI binary.
- You want the exact same error classification and retry logic that apfel itself uses.

Not a fit:

- You want to run prompts from the shell -> use the `apfel` CLI.
- You want a local OpenAI-compatible server -> use `apfel --serve`.
- You want FoundationModels itself -> depend on Apple's framework directly. `ApfelCore` is FoundationModels-free by design.
- You want a ready-made on-device chat engine (streaming, usage, context rotation, persistence) -> see [ApfelEngine (preview)](#apfelengine-preview) below.

## Install

The first tagged release that contains `ApfelCore` is `1.1.0`. Depend on the package product directly from `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Arthur-Ficial/apfel.git", from: "1.1.0")
],
targets: [
    .executableTarget(
        name: "MyTool",
        dependencies: [
            .product(name: "ApfelCore", package: "apfel")
        ]
    )
]
```

## Quick start

```swift
import ApfelCore

let request = ChatCompletionRequest(
    model: "apple-foundationmodel",
    messages: [OpenAIMessage(role: "user", content: .text("Hello"))]
)
```

See [Examples/](../Examples/) for runnable samples covering OpenAI types, tool calling, MCP protocol, error handling, and context strategies.

## API surface (high level)

| Area | Representative types |
|------|---------------------|
| OpenAI types | `ChatCompletionRequest`, `OpenAIMessage`, `MessageContent`, `OpenAITool`, `ToolChoice`, `ResponseFormat` |
| Validation | Request validators for unsupported features (embeddings, logprobs, n>1) |
| Context strategies | `ContextStrategy` with 5 trimming policies |
| Tool calling | `ToolCallHandler`, JSON tool-call detection, schema conversion |
| MCP protocol | Message types + transport-agnostic client primitives |
| Error handling | `ApfelError` with typed error classification |
| Retry logic | `withRetry` (optionally with an injected classifier), `isRetryableError` |

Full API reference lives in the DocC catalog at [Sources/Core/ApfelCore.docc/](../Sources/Core/ApfelCore.docc/).

## Stability contract

`ApfelCore` follows apfel's semver. Breaking changes require a major version bump and are guarded in CI via `swift package diagnose-api-breaking-changes`. Deprecations land with `@available(*, deprecated, ...)` one release before removal.

Full policy: [STABILITY.md](../STABILITY.md).

## Examples

| Topic | Directory |
|-------|-----------|
| OpenAI request/response shapes | [Examples/OpenAITypes/](../Examples/OpenAITypes/) |
| Tool calling end-to-end | [Examples/ToolCalling/](../Examples/ToolCalling/) |
| MCP protocol primitives | [Examples/MCPProtocol/](../Examples/MCPProtocol/) |
| Error handling + retry | [Examples/ErrorHandling/](../Examples/ErrorHandling/) |
| Context-trimming strategies | [Examples/ContextStrategies/](../Examples/ContextStrategies/) |

## ApfelEngine (preview)

`ApfelEngine` is the generation engine the `apfel` CLI and server run on, published as its own product for apps that want an on-device chat engine without writing the FoundationModels plumbing themselves (first shipped in `1.17.0`). Unlike `ApfelCore` it does depend on FoundationModels, so it runs on macOS 26 and 27 with Apple Intelligence.

**Preview:** the API may still change in a minor release until it has a shipped consumer; pin an exact version if you depend on it. See [STABILITY.md](../STABILITY.md).

```swift
dependencies: [
    .package(url: "https://github.com/Arthur-Ficial/apfel.git", exact: "1.17.0")
],
targets: [
    .executableTarget(
        name: "MyChat",
        dependencies: [.product(name: "ApfelEngine", package: "apfel")]
    )
]
```

```swift
import ApfelCore
import ApfelEngine

let engine = EngineFactory.make(systemPrompt: "You are terse.")
for try await event in await engine.send("Name three apple varieties.") {
    switch event {
    case .delta(let text): print(text, terminator: "")
    case .usage(let usage): print("\n[\(usage.totalTokens) tokens]")
    case .finished: print()
    }
}
```

What it gives you, all as plain data (no FoundationModels types on the surface):

| Area | API |
|------|-----|
| Generation | `Engine.send(_:)` / `send(_:images:)` streaming `EngineEvent` (`.delta`, `.usage`, `.finished`) |
| Model facts | `modelInfo()`: availability, the runtime context window (never a fixed number), capabilities and the variant name on macOS 27 |
| Accounting | `contextStatus(outputReserve:)`, `sessionUsage()` - counted with the on-device tokenizer |
| Persistence | `transcript()` / `resume(_:)` with `EngineTranscript` (versioned, Codable) |
| Options | `setOptions(_:)` with `EngineOptions` (clamped by `normalized()`), `ErrorRecovery` (`.preserve` / `.revert`) |

Errors are always a classified `ApfelError`. Images need the vision capability (macOS 27); check `modelInfo().capabilities` first.

## Architecture note

`ApfelCore` contains zero dependencies on FoundationModels or Hummingbird. That is on purpose. `ApfelEngine` sits on top of it and adds FoundationModels; the `apfel` executable adds Hummingbird and the CLI on top of both. The apfel executable composes `ApfelCore` with FoundationModels (for inference) and Hummingbird (for the HTTP server), but the library itself stays pure Swift so it can be unit-tested, cross-compiled, and embedded into apps that do their own FoundationModels calls.
