# OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

`apfel` implements the OpenAI Chat Completions surface for Apple's on-device model. It is intended to be a drop-in local backend for SDKs and tools that can target a custom `base_url`.

## Supported Surface

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| `GET /v1/logs`, `/v1/logs/stats` | Debug only | Requires `--debug` |
| Tool calling | Supported | Native `ToolDefinition` + JSON detection. See [tool-calling-guide.md](tool-calling-guide.md) |
| `response_format: json_object` | Supported | System-prompt injection; markdown fences stripped from output |
| `temperature`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions`. Omitting `max_tokens` uses the remaining context window (drop-in OpenAI semantics; see Notes) |
| `stream: true` | Supported | SSE; final usage chunk only when `stream_options: {"include_usage": true}` (per OpenAI spec) |
| `stream_options.include_usage` | Supported | Opt-in for the empty-`choices` usage chunk before `[DONE]` |
| `finish_reason` | Supported | `stop`, `tool_calls`, `length` |
| Context strategies | Supported | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` extension fields |
| CORS | Supported | Enable with `--cors` |
| `POST /v1/completions` | 501 | Legacy text completions not supported |
| `POST /v1/embeddings` | 501 | Embeddings not available on-device |
| `POST /v1/responses` | 501 | Use Chat Completions |
| `logprobs=true`, `n>1`, `stop`, `presence_penalty`, `frequency_penalty` | 400 | Rejected explicitly. `n=1` and `logprobs=false` are accepted as no-ops |
| Multi-modal (images) | 400 | Rejected with clear error |
| `Authorization` header | Supported | Required when `--token` is set. See [server-security.md](server-security.md) |

## Notes

- Use Chat Completions, not the newer Responses API.
- `GET /health` stays useful for local availability checks even when the rest of the server is token-protected, if you opt into `--public-health`.
- Debug log endpoints exist only when the server is started with `--debug`.
- Browser access, origin checks, bearer tokens, and `--footgun` behavior are documented in [server-security.md](server-security.md).
- **`max_tokens` omitted = use the remaining 4096-token context window** (drop-in OpenAI semantics). If the model runs into the ceiling, the response ends cleanly with `finish_reason: "length"` and the partial content is returned (HTTP 200). Pass `max_tokens` explicitly when you want a tighter latency budget or a known cap. Full rationale and examples in [README.md](../README.md#default-response-cap-max_tokens).

Full upstream schema reference: [https://github.com/openai/openai-openapi](https://github.com/openai/openai-openapi)
