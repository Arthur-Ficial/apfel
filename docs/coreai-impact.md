# Apple Core AI - what it means for apfel

> Knowledge page. Last researched 2026-06-09 against the live (beta) docs at
> [developer.apple.com/documentation/coreai](https://developer.apple.com/documentation/coreai/).
> Tracking epic: [#189](https://github.com/Arthur-Ficial/apfel/issues/189).

## TL;DR

**Core AI does not change what apfel is.** apfel exposes Apple's on-device LLM through
the **FoundationModels** framework (`LanguageModelSession`, `SystemLanguageModel`). Core AI
is a different framework at a lower layer: it is the **modernized successor to Core ML**, a
tensor inference runtime for running arbitrary models (`.aimodel` files) on the CPU, GPU, and
Neural Engine. It has no chat, no prompts, no tool calling, no structured generation, no
embeddings, and no OpenAI-compatible or server surface.

- apfel keeps building on FoundationModels. No migration is required or possible.
- The real WWDC 2026 items to watch are **FoundationModels** changes shipping in the same OS
  release (notably any context-window increase beyond 4096 tokens), and **macOS 27** build and
  runtime compatibility.
- Core AI is, at most, a **future opportunity**: a bring-your-own-weights runtime that a
  separate sister tool could use. It is not a change to apfel core.

## What Core AI actually is

From the framework overview (quoted from the docs):

> "Core AI helps you build, run, and deploy AI models in your app. Designed with Apple silicon
> in mind, Core AI allows your app to use the latest model architectures and inference techniques
> across the CPU, GPU, and Neural Engine."

Tagline: *"Run AI models in your app on Apple silicon."*

Core AI is a low-level inference runtime. Its currency is tensors and named inference functions,
not conversations. The mental model:

1. You convert a model (e.g. from PyTorch via the **Core AI PyTorch Extensions** package) into an
   `.aimodel` file, or ahead-of-time compile it to `.aimodelc` with `xcrun coreai-build`.
2. You load and **specialize** it for the current device (`AIModel.specialize(...)`), choosing a
   preferred compute unit (`.cpu`, `.gpu`, `.neuralEngine`) and a cache policy.
3. You run inference functions on `NDArray` tensors or `CVMutablePixelBuffer` images
   (`InferenceFunction.run(inputs:...)`), synchronously or streamed via `ComputeStream`.

Key symbols: `AIModel`, `AIModelAsset`, `InferenceFunction`, `InferenceFunctionDescriptor`,
`InferenceValue`, `NDArray`, `NDArrayDescriptor`, `ComputeStream`, `ComputeUnitKind`,
`SpecializationOptions`, `AIModelCache`, `ImageDescriptor`, `AssetError`. Import is `import CoreAI`.

**Availability:** iOS / iPadOS / macOS / tvOS / visionOS / watchOS **27.0+, all Beta.** Announced at
WWDC 2026 (keynote 2026-06-08), shipping with the iOS 27 / macOS 27 generation. Building
`.aimodel` files needs the Xcode **Metal Toolchain** component.

## What Core AI is NOT

| Misconception | Reality |
|---|---|
| "Core AI replaces FoundationModels" | No. Different framework, different layer. FoundationModels is the developer-facing LLM API; Core AI is the Core ML successor (generic inference). |
| "apfel must migrate to Core AI" | No. There is nothing to migrate. apfel needs LLM sessions/prompts/tools, which Core AI does not provide. |
| "Core AI adds tool calling / structured output / embeddings" | No. None of these exist in Core AI. Those live in FoundationModels (and apfel's own out-of-band tool layer). |
| "Core AI deprecates FoundationModels" | No. FoundationModels is untouched by the Core AI announcement. Core ML continues in compatibility mode. |
| "Core AI gives apfel a new OpenAI-compatible server" | No. Core AI is purely on-device inference. No HTTP, no OpenAI compat, no MCP, no agents. |

## Where apfel sits in Apple's AI stack

```
apfel  (CLI + OpenAI-compatible server + chat)
  └─ FoundationModels      ← apfel is built ENTIRELY on this
       (on-device LLM: sessions, prompts, guided generation, tool support, tokenCount)
  └─ Core AI               ← the Core ML successor; apfel does NOT use this today
       (tensor inference runtime: AIModel / NDArray / InferenceFunction)
  └─ Apple silicon (CPU / GPU / Neural Engine)
```

FoundationModels is almost certainly implemented on top of the same runtime layer Core AI now
exposes, but apfel only ever talks to FoundationModels. Core AI is the layer below the line apfel
draws.

## Direct impact on apfel: effectively none

- **CLI tool** (`apfel "prompt"`): unaffected.
- **OpenAI-compatible server** (`apfel --serve`): unaffected. Core AI has no server or
  OpenAI-compatible concept to align with.
- **Chat / MCP / tool calling**: unaffected.
- **ApfelCore library**: unaffected. It is FoundationModels-free pure Swift; Core AI adds nothing
  it needs to model.
- **TokenCounter** (`SystemLanguageModel.tokenCount(for:)`, SDK 26.4+): a FoundationModels API,
  not a Core AI one. No change from the Core AI announcement.

The golden goal (UNIX tool + OpenAI-compatible server, on FoundationModels, 100% on-device) is
intact.

## Indirect / adjacent items worth tracking

These are the things that actually matter for apfel from the WWDC 2026 / OS 27 cycle. None are
Core AI per se, but they ship in the same window and Core AI is the headline that surfaced them.

> **Update 2026-06-09: these are now confirmed by Apple's official
> [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
> page (June 2026 / OS 27 entries), not just press reporting.** Details folded into the items below.

1. **FoundationModels context window - on-device window appears UNCHANGED at 4096.** apfel's docs and
   behavior are built around a hard **4096-token** context (input + output combined). The figure
   appears across `README.md`, `docs/context-strategies.md`, `docs/integrations.md`,
   `docs/openai-api-compatibility.md`, `docs/mcp-calculator.md` and is the basis for the whole
   context-strategy subsystem. The OS 27 updates page still references **4,096 tokens** for the
   on-device model; the "larger context size" Apple advertises is via the new
   `PrivateCloudComputeLanguageModel` (a **cloud** path apfel deliberately does not use). So apfel's
   on-device 4096 assumption most likely **holds** on OS 27. Still confirm the real number on OS 27
   hardware via `SystemLanguageModel.contextSize` (the API added in 26.4 that removes the hardcode).

2. **FoundationModels base model change - CONFIRMED.** Apple's updates page states verbatim: *"the
   model changes when a person updates to iOS 27, iPadOS 27, macOS 27, and visionOS 27, test your
   prompts with the new model to verify your app's behavior."* (The new on-device model is reported to
   be distilled from Google Gemini under a multi-year Apple/Google deal.) apfel inherits any change in
   tool-call formatting, refusal behavior, tokenization, or token counts. These are exactly the
   surfaces apfel's recent bug fixes (#176-#183, #187) hardened, so re-qualification on OS 27 hardware
   is required, not optional.

3. **New FoundationModels APIs in OS 27 that touch apfel.** The June 2026 updates also add:
   `GenerationOptions.ToolCallingMode` (control how the model interacts with tools - relevant to
   apfel's out-of-band tool layer); improved error types `LanguageModelError`,
   `SystemLanguageModel.Error`, `LanguageModelSession.Error` (relevant to `ApfelError.classify` and
   parked ticket #119); a `DynamicProfile` agentic API; and image analysis (`OCRTool`,
   `BarcodeReaderTool`). apfel should evaluate whether to adopt `ToolCallingMode` and the new error
   types; the rest (image, agentic, cloud) are out of scope for apfel's golden goal.

4. **macOS 27 build + runtime compatibility.** apfel pins `platforms: [.macOS(.v26)]`. We need to
   confirm: apfel builds against the OS 27 SDK, FoundationModels availability gates still hold,
   `SystemLanguageModel.tokenCount` and `GenerationOptions` are unchanged, and the test suite is
   green on an OS 27 machine. The "macOS 26 Tahoe required" gotcha messaging may need a note.

5. **User confusion ("why doesn't apfel use Core AI?").** Once Core AI is in the press, expect
   issues asking why apfel is not "on Core AI", or requests to run third-party models. We should
   have a one-paragraph canned answer (this page) so triage is fast and consistent.

## Opportunity: bring-your-own-model (future, likely a sister tool)

> **Update 2026-06-09: there is now an official Core AI <-> FoundationModels bridge.** The June 2026
> FoundationModels updates add a `LanguageModel` protocol - *"Adopt the LanguageModel protocol to use
> any large language model - server or on-device"* - plus open-source `CoreAILanguageModel` and
> `MLXLanguageModel` backends. That means a Core AI `.aimodel` (or an MLX model) can be driven through
> the **existing** FoundationModels session API (prompts, tool calling, structured generation) instead
> of reimplementing that stack from scratch. This is materially easier than my first read below, and
> it changes the spike from "build an LLM server on raw tensors" to "wire a `CoreAILanguageModel` into
> a `LanguageModel`-backed session and serve it." Still a separate project, but a much shorter one.

Core AI's genuinely new capability is running **non-Apple model weights** on Apple silicon from an
`.aimodel` file, with explicit compute-unit and caching control. With the new bridge it is more
tractable, but it is still a different project from apfel core:

- It would mean shipping/loading model weights (apfel today downloads nothing - "no downloads" is a
  selling point).
- The hard parts (tokenizer, sampling, KV cache, chat templating) are largely handled if you go
  through `LanguageModel` + `CoreAILanguageModel`, rather than calling `InferenceFunction.run` on raw
  `NDArray`s yourself. The spike should confirm exactly how much the bridge gives you for free.
- It fits the apfel-family pattern (apfel-tag, apfel-spot, apfel-mcp, apfel-server-kit) far better
  than apfel core. If pursued, it should be a **separate repo** (working name e.g. `apfel-coreai` or
  `aimodel-serve`), evaluated with a research spike first.

Recommendation: **do not** put Core AI into apfel core. Track it, write a spike against the
`LanguageModel`/`CoreAILanguageModel` bridge, decide later.

## Decision / recommendation

1. **No code changes to apfel for Core AI itself.** Nothing to do.
2. **Add this page + a short README/FAQ pointer** so the positioning is clear and triage is fast.
3. **Open a tracking epic** covering the adjacent OS 27 / FoundationModels items above, gated on real
   OS 27 hardware availability.
4. **Park the bring-your-own-model idea** as a research spike for a possible sister tool, not apfel
   core.

## Sources

Primary (live beta JSON docs, fetched 2026-06-09):

- [developer.apple.com/documentation/coreai](https://developer.apple.com/documentation/coreai/) - framework root
- `coreai/integrating-on-device-ai-models-in-your-app-with-core-ai` - getting-started article
- `coreai/aimodel`, `coreai/aimodelasset`, `coreai/inferencefunction`, `coreai/inferencevalue`,
  `coreai/ndarray`, `coreai/computestream`, `coreai/computeunitkind`, `coreai/specializationoptions`,
  `coreai/aimodelcache` - symbol references
- `coreai/managing-model-specialization-and-caching`, `coreai/compiling-core-ai-models-ahead-of-time` - articles

FoundationModels OS 27 updates (official, fetched 2026-06-09):

- [developer.apple.com/documentation/updates/foundationmodels](https://developer.apple.com/documentation/updates/foundationmodels) -
  June 2026 entries: updated on-device `SystemLanguageModel` ("the model changes when a person updates
  to ... 27"), `LanguageModel` protocol, open-source `CoreAILanguageModel` / `MLXLanguageModel`,
  `GenerationOptions.ToolCallingMode`, improved error types, `DynamicProfile`, image analysis,
  `PrivateCloudComputeLanguageModel` (cloud, larger context).
- The on-device context window still reads **4,096 tokens** on this page; the larger context is the
  cloud `PrivateCloudComputeLanguageModel`, which apfel does not use.

Context / reporting: WWDC 2026 keynote coverage (2026-06-08) on the Core ML to Core AI rename, the
FoundationModels coexistence story, and the Apple/Google Gemini base-model collaboration. The
on-device base-model change and the new APIs above are confirmed by Apple's updates page; the exact
on-device context window should still be read at runtime via `SystemLanguageModel.contextSize` on OS 27
hardware rather than hardcoded.
