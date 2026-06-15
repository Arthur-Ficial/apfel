# Anthropic Messages API Compatibility

> **Experiment branch.** This endpoint lives on `experiment/anthropic-messages-api` and is additive and unreleased. The OpenAI `/v1/chat/completions` default is unchanged. Both APIs run on the same always-on server with no extra CLI flag.

**Base URL:** `http://localhost:11434`

`apfel` speaks the [Anthropic Messages API](https://docs.anthropic.com/en/api/messages) for Apple's on-device model, so the [anthropics/ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) Swift library can target on-device FoundationModels through apfel. Point the library at apfel in `.proxied` mode and answers come from Apple Intelligence locally - no cloud, no API key, no network.

## Endpoint

| Endpoint | Status | Notes |
|----------|--------|-------|
| `POST /v1/messages` | Supported | Streaming + non-streaming. The single Messages endpoint |

The OpenAI surface (`POST /v1/chat/completions`, `GET /v1/models`, `GET /health`) is documented in [docs/openai-api-compatibility.md](openai-api-compatibility.md) and runs on the same server unchanged.

## No auth (proxied mode)

The library's proxied mode sends no credential. `apfel` does **not** require `x-api-key` on `/v1/messages` and will not return 401 for its absence. Any `x-api-key` or `anthropic-version` header the client sends is accepted and ignored. apfel's own `--token` / origin checks (when enabled) still apply uniformly to every route - see [docs/server-security.md](server-security.md).

## Supported surface

| Feature | Status | Notes |
|---------|--------|-------|
| Text content (`{"type":"text"}`) | Supported | Block array or bare-string shorthand both decode |
| `system` (plain string) | Supported | Prepended to the on-device context |
| `stream: true` | Supported | `text/event-stream`; the library always streams. `stream: false` also supported |
| Tools (`tools`, `tool_choice`) | Supported | `name` / `description` / `input_schema`; `tool_use` + `tool_result` history replay |
| Structured output (`output_config.format`) | Supported | `{"type":"json_schema","schema":...}` via FoundationModels `DynamicGenerationSchema`; returned as ordinary text content |
| `temperature`, `top_p`, `max_tokens` | Supported | Mapped to `GenerationOptions` |
| `top_k` | Best-effort | Accepted; applied where the model supports it, otherwise ignored |
| Model string | Echoed | Any `model` value is accepted and echoed back verbatim |
| `usage` | Real counts | `input_tokens` + `output_tokens` are real token counts, never placeholders |
| Images (`{"type":"image"}`) | Ignored | apfel is text-only; image blocks are parsed and skipped, never crash |
| `thinking` (`{"type":"adaptive"}`) | Accepted, ignored | No extended thinking on-device |
| `cache_control` (`{"type":"ephemeral"}`) | Accepted, ignored | No prompt caching on-device |
| Server tools (`web_search`, `code_execution`, etc.) | Honest error | Not available on-device; rejected with an Anthropic error envelope |
| Embeddings, vision generation | Not available | On-device limits; see [README.md](../README.md) |

## Stop reasons

`stop_reason` is `end_turn` for a normal completion, `tool_use` when the response ends on a tool call, `max_tokens` when truncated, and `refusal` when the model declines (returned as a normal 200 response, not an error).

## Errors

Failures return HTTP >= 400 with the Anthropic error envelope:

```json
{"type":"error","error":{"type":"invalid_request_error","message":"..."},"request_id":"req_..."}
```

An over-budget prompt maps to `400 invalid_request_error` with the word `context` in the message, which the Swift client maps to `LanguageModelError.contextSizeExceeded`. Rate / concurrency limits map to `429 rate_limit_error`; decoding and unknown failures map to `500 api_error`.

## ClaudeForFoundationModels (Swift)

Point the library at apfel in proxied mode:

```swift
import ClaudeForFoundationModels

let model = ClaudeLanguageModel(
    name: .sonnet4_6,
    auth: .proxied(headers: [:]),
    baseURL: URL(string: "http://localhost:11434")!
)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Say hi in one word.")
print(response.content)
```

## curl

A raw non-streaming `POST /v1/messages` against the local server:

```bash
curl -s http://localhost:11434/v1/messages \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":64,"messages":[{"role":"user","content":"Say hi in one word."}]}'
```

A streaming request (`text/event-stream`):

```bash
curl -N -s http://localhost:11434/v1/messages \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":64,"stream":true,"messages":[{"role":"user","content":"Say hi in one word."}]}'
```

Full upstream schema reference: [https://docs.anthropic.com/en/api/messages](https://docs.anthropic.com/en/api/messages)
