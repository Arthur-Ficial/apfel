# OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

`apfel` implements the OpenAI Chat Completions and Responses surfaces for Apple's on-device model: a drop-in local backend for SDKs and tools that target a custom `base_url`.

## Supported Surface

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `POST /v1/responses` | Supported | See [Responses API](#responses-api) below |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| `GET /v1/logs`, `/v1/logs/stats` | Debug only | Requires `--debug` |
| Tool calling | Supported | Native `ToolDefinition` + JSON detection. See [tool-calling-guide.md](tool-calling-guide.md) |
| `tool_choice`, `parallel_tool_calls` | Enforced | `none`, `auto`, `required`, `{"type":"function",...}`; `parallel_tool_calls: false` returns at most one call. Enforced at the response boundary, not just steered. See [tool-calling-guide.md](tool-calling-guide.md#tool_choice-and-parallel_tool_calls-are-enforced) |
| `response_format: json_object` | Supported | System-prompt injection; markdown fences stripped from output |
| `response_format: json_schema` | Supported | Guaranteed schema-conforming output via FoundationModels `DynamicGenerationSchema`; works with `stream: true`. Local `$ref`/`$defs`, numeric and array bounds; unsupported keywords are a 400. See [JSON Schema support](#json-schema-support) |
| `temperature`, `top_p`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions`. `top_p` is nucleus sampling; `temperature: 0` maps to greedy (deterministic). Omitting `max_tokens` uses the remaining context window (drop-in OpenAI semantics; see Notes) |
| `stream: true` | Supported | SSE; final usage chunk only when `stream_options: {"include_usage": true}` (per OpenAI spec) |
| `stream_options.include_usage` | Supported | Opt-in for the empty-`choices` usage chunk before `[DONE]` |
| `finish_reason` | Supported | `stop`, `tool_calls`, `length` |
| Context strategies | Supported | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` extension fields |
| CORS | Supported | Enable with `--cors` |
| `POST /v1/completions` | 501 | Legacy text completions not supported |
| `POST /v1/embeddings` | 501 | Embeddings not available on-device |
| `logprobs=true`, `n>1`, `stop`, `presence_penalty`, `frequency_penalty` | 400 | Rejected explicitly. `n=1` and `logprobs=false` are accepted as no-ops |
| Multi-modal (images) | 400 | Rejected with clear error |
| `Authorization` header | Supported | Required when `--token` is set. See [server-security.md](server-security.md) |

## Responses API

`POST /v1/responses` is served as a translation layer over the same on-device pipeline as Chat Completions. apfel is stateless; the Responses API's server-side conversation state is deliberately not implemented.

| Feature | Status | Notes |
|---------|--------|-------|
| `input` as a string or message list | Supported | Roles `system`, `developer` (folded into system), `user`, `assistant`; string content or `input_text` parts |
| `instructions` | Supported | Becomes the system prompt |
| `stream: true` | Supported | Canonical event sequence: `response.created` ... `response.output_text.delta` ... `response.completed`, with `sequence_number` |
| `temperature`, `top_p`, `max_output_tokens`, `metadata` | Supported | Same semantics as chat; metadata echoed back |
| `text.format: json_object` / `json_schema` | Supported | json_schema is non-streaming only (501 with `stream: true`); same schema subset as Chat Completions, see [JSON Schema support](#json-schema-support) |
| Function tools (flat Responses shape) | Supported | Non-streaming only; the call comes back as a `function_call` output item for the client to execute |
| `usage` | Supported | `input_tokens` / `output_tokens` / `total_tokens` |
| `previous_response_id` | 501 | apfel is stateless: resend the full conversation in `input` |
| `store: true` | 501 | Responses are never stored; every response reports `"store": false` |
| `background`, `reasoning`, `include` | 501 | Not available on-device |
| Hosted tools (`web_search`, `file_search`, `computer_use`, ...) | 501 | The on-device model has no hosted tools |
| `function_call_output` input items | 501 | Tool-result round-trips are not yet supported on this endpoint; use Chat Completions |

MCP tools attached with `--mcp` are auto-executed on Chat Completions only; `/v1/responses` serves client-defined function tools.

## JSON Schema support

One compiler serves `response_format.json_schema`, Responses `text.format`, `apfel --schema` and `tools[].function.parameters`: `SchemaParser` (in `ApfelCore`) parses the JSON Schema into an intermediate representation, and apfel compiles that into a FoundationModels `DynamicGenerationSchema`, which constrains decoding. The output therefore conforms to the schema as written - within the subset below. Anything outside it is rejected **before generation** with the keyword and the JSON pointer of the node to fix, for example:

```text
"multipleOf" at #/properties/price cannot be enforced by on-device schema-guided generation; remove it or express the constraint with a supported keyword
```

- `/v1/chat/completions` and `/v1/responses`: HTTP 400, `type: "invalid_request_error"` (also when `stream: true` was requested - nothing is streamed).
- `apfel --schema file.json`: exit code 2, the message prefixed with the file name.
- `tools[].function.parameters`: not rejected; the tool falls back to prompt-text injection as described in [tool-calling-guide.md](tool-calling-guide.md).

`strict` is accepted and changes nothing: apfel always generates against the compiled schema, so there is no non-strict mode to relax into.

### Supported

| JSON Schema | apfel |
|-------------|-------|
| `type`: `object`, `string`, `integer`, `number`, `boolean`, `array` | Native. A node without `type` is an object; a string `enum` or `const` without `type` is a string |
| `properties`, `required` | Native. A property not listed in `required` is optional |
| `enum` of strings, `const` string | Fixed set of choices |
| `anyOf` / `oneOf` `[X, {"type": "null"}]`, `type: [X, "null"]` | `X`, and the property becomes optional. The model cannot emit `null`; a nullable property is omitted instead (#219) |
| `$ref` to a local JSON pointer (`#/$defs/Address`, `#/definitions/Address`, `#/properties/home`, ...) | Resolved by expanding the referenced schema in place. `~0` / `~1` escapes and percent-encoding are decoded; a `description` next to the `$ref` overrides the definition's; definitions may reference other definitions |
| `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum` on `integer` / `number` | Generation guides. Exclusive bounds become the adjacent inclusive value (integer: plus or minus one; number: the next representable `Double`). The draft-4 boolean form (`"exclusiveMinimum": true`) is honoured |
| `minItems`, `maxItems` | Array element limits |
| `additionalProperties: true` / `false`, `unevaluatedProperties: true` / `false`, `unevaluatedItems: true` / `false` | Accepted. Generation never emits undeclared properties, so both values are always satisfied |
| `title`, `description`, `default`, `examples`, `format`, `$schema`, `$id`, `$comment`, `$anchor`, `deprecated`, `readOnly`, `writeOnly`, `nullable`, `x-*`, unknown keywords | Accepted as annotations. **`format` is not enforced**: `"format": "date-time"` does not guarantee a parseable timestamp |
| A keyword that does not apply to the node's type (`minLength` on an integer, `minItems` on an object) | Ignored, as JSON Schema scopes it to another type |

### Rejected (400 / exit 2, with the JSON pointer)

| Keyword | Why |
|---------|-----|
| `multipleOf` | No numeric step guide on-device |
| `minLength`, `maxLength`, `pattern`, `contentEncoding`, `contentMediaType`, `contentSchema` | No string-shape guides |
| `uniqueItems: true`, `contains`, `minContains`, `maxContains`, `prefixItems`, `additionalItems`, schema-valued `unevaluatedItems` | Not representable as an array-of-one-item-schema |
| `minProperties`, `maxProperties`, `patternProperties`, `propertyNames`, `dependentRequired`, `dependentSchemas`, `dependencies`, schema-valued `additionalProperties` / `unevaluatedProperties` | Objects are generated from declared properties only; free-form maps cannot be produced |
| `enum` / `const` on a non-string type | Only string choices are representable |
| `not`, `if`, `then`, `else`, `allOf`, any `anyOf` / `oneOf` other than the nullable form, `type` arrays other than `[X, "null"]` | No conditional or combined schemas |
| `$ref` that is not `#/...` (`https://...`, `other.json#/X`), `$dynamicRef`, `$recursiveRef` | apfel never fetches or opens another document to resolve a schema |
| `$ref` that does not resolve, or that is recursive | Unresolvable; recursive schemas are not supported |
| `minimum` above `maximum`, `minItems` above `maxItems`, negative or fractional counts, empty `enum`, `required` naming an undeclared property | Unsatisfiable - every output would violate the schema |
| More than 16 nested references, or more than 512 schema nodes after expansion | Bounds on the work a schema can cause |

### Names

FoundationModels hoists every object and every string enum into `$defs` by name. apfel names inline objects and enums after their property key (`<key>_item` for array items, the request's `name` for the root) and referenced definitions after their `$defs` key. Names are made unique per distinct shape within one schema: two identically shaped nodes share one name, a later differently shaped node with the same key is titled `contact_2`. The suffix is visible only in the schema shown to the model; the generated JSON uses your property names unchanged.

## Notes

- `GET /health` stays useful for local availability checks even when the rest of the server is token-protected, if you opt into `--public-health`.
- Debug log endpoints exist only when the server is started with `--debug`.
- Browser access, origin checks, bearer tokens, and `--footgun` behavior are documented in [server-security.md](server-security.md).
- **`max_tokens` omitted = use the remaining context window** (4096 tokens on macOS 26, 8192 on macOS 27 - read at runtime; drop-in OpenAI semantics). If the model runs into the ceiling, the response ends cleanly with `finish_reason: "length"` and the partial content is returned (HTTP 200). Pass `max_tokens` explicitly when you want a tighter latency budget or a known cap. Full rationale and examples in [README.md](../README.md#default-response-cap-max_tokens).

Full upstream schema reference: [https://github.com/openai/openai-openapi](https://github.com/openai/openai-openapi)
