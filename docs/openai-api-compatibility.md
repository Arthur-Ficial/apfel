# OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

`apfel` implements the OpenAI Chat Completions and Responses surfaces for Apple's on-device model: a drop-in local backend for SDKs and tools that target a custom `base_url`.

## Supported Surface

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `POST /v1/responses` | Supported | See [Responses API](#responses-api) below |
| `POST /v1/responses/input_tokens` | Supported | Exact token preflight, no generation. See [Token preflight](#token-preflight-v1responsesinput_tokens) below |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| `GET /v1/logs`, `/v1/logs/stats` | Debug only | Requires `--debug` |
| Tool calling | Supported | Native `ToolDefinition` + JSON detection. See [tool-calling-guide.md](tool-calling-guide.md) |
| `tool_choice`, `parallel_tool_calls` | Enforced | `none`, `auto`, `required`, `{"type":"function",...}`; `parallel_tool_calls: false` returns at most one call. Enforced at the response boundary, not just steered. On macOS 27 `auto`/`none` are additionally mapped to the runtime's `ToolCallingMode` (`.allowed`/`.disallowed`); `required` and named functions stay prompt-steered plus enforced on both OSes (the SDK's `.required` mode rejects out-of-band tool definitions, and there is no per-tool mode). See [tool-calling-guide.md](tool-calling-guide.md#tool_choice-and-parallel_tool_calls-are-enforced) |
| `response_format: json_object` | Supported | System-prompt injection; markdown fences stripped from output |
| `response_format: json_schema` | Supported | Guaranteed schema-conforming output via FoundationModels `DynamicGenerationSchema`; works with `stream: true`, which delivers the JSON incrementally in append-only deltas whose concatenation equals the non-streamed document. Keys are in alphabetical order. Local `$ref`/`$defs`, numeric and array bounds; unsupported keywords are a 400. See [JSON Schema support](#json-schema-support) |
| `temperature`, `top_p`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions`. `top_p` is nucleus sampling; `temperature` below 0.001 (0 included) maps to greedy, also with `top_p` (deterministic). Omitting `max_tokens` uses the remaining context window (drop-in OpenAI semantics; see Notes) |
| `stream: true` | Supported | SSE; final usage chunk only when `stream_options: {"include_usage": true}` (per OpenAI spec) |
| `stream_options.include_usage` | Supported | Opt-in for the empty-`choices` usage chunk before `[DONE]` |
| `usage` accounting | Supported | On macOS 27 the numbers are the FoundationModels runtime's own accounting (`Response.usage`), which includes Apple's chat-template framing - a one-line prompt reports about 46 more `prompt_tokens` than the message text alone, and tool definitions are priced as the model actually receives them. On macOS 26 apfel counts the message text with `tokenCount(for:)`. Both are real tokenizer counts on macOS 26.4+ (below 26.4 the count is a chars/4 estimate, `--count-tokens` says `approximate`); budget against `context_window` either way. |
| `finish_reason` | Supported | `stop`, `tool_calls`, `length` |
| Context strategies | Supported | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` extension fields |
| CORS | Supported | Enable with `--cors` |
| `POST /v1/completions` | 501 | Legacy text completions not supported |
| `POST /v1/embeddings` | 501 | Embeddings not available on-device |
| `stop` | Supported | String or array of up to 4 strings; plain text only. See [Stop sequences](#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rejected explicitly. `n=1` and `logprobs=false` are accepted as no-ops |
| Multi-modal (images) | Supported on macOS 27 | `image_url` parts as base64 data URLs reach the model natively; `detail` is accepted and ignored. On macOS 26: 400 ("image input requires macOS 27"). See [Images](#images) |
| `Authorization` header | Supported | Required when `--token` is set. See [server-security.md](server-security.md) |

## Stop sequences

Apple's `GenerationOptions` has no stop field, so apfel applies `stop` on the output side, the same way for streaming and non-streaming requests (one shared matcher, `StopSequenceMatcher` in ApfelCore):

- **Forms:** a string, or an array of up to 4 strings (OpenAI's limit), at most 256 Unicode scalars in total. `null` and `[]` mean no stop sequences. An empty string, a non-string entry, a fifth sequence or a longer total is a 400 with `param: "stop"`.
- **Matching:** exact Unicode scalars, no normalization (a precomposed `é` does not match `e` plus a combining accent). The first delimiter to be completely generated wins; if two complete at the same position, the longer one wins.
- **Delivery:** everything before the delimiter is delivered; the delimiter and everything after it never are. While streaming, text that cannot become part of a delimiter is sent at once and only the ambiguous suffix (at most the longest delimiter minus one scalar) is held back. If the answer ends without a match, the held text is sent.
- **Ending:** a match ends the answer with `finish_reason: "stop"` and apfel stops consuming the model stream, which ends the request and releases its concurrency permit. Cancellation in FoundationModels is cooperative: the framework may still generate a few more tokens internally, but none of them are delivered.
- **Usage:** `completion_tokens` is not a count of the delivered text alone. On macOS 27 it is the runtime's own number for what the model generated up to the snapshot that completed the delimiter (so it includes the delimiter and can include a few tokens after it). On macOS 26 apfel counts the delivered text (the delimiter is not counted).
- **Plain text only (for now):** `stop` together with tools in scope (client `tools`, or the server's `--mcp` tools, unless `tool_choice` is `"none"`), `response_format: json_object` or `json_schema` is a 400 - a cut tool call or a cut JSON document would be invalid. `response_format: text` is fine.

LangChain's classic ReAct agent binds `stop: ["\nObservation"]` by default; this request is accepted and the answer ends before the observation line:

```bash
curl --fail-with-body http://localhost:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"apple-foundationmodel","messages":[{"role":"user","content":"Write one short action, then a line beginning Observation."}],"stop":["\nObservation"],"stream":true}'
```

The CLI twin is `--stop` (see [cli-reference.md](cli-reference.md)).

## Images

On macOS 27 the on-device model accepts image input, and apfel forwards it through the standard OpenAI shape: a `content` array with `image_url` parts. On macOS 26 the same request gets an honest 400 ("Image content is not supported by the Apple on-device model - image input requires macOS 27") - feature-detect via `capabilities` on `/health` or `/v1/models` (`capabilities_reported: false` means the OS does not report capabilities at all).

The rules, all enforced before the model runs:

- **Base64 data URLs only** (`data:image/png;base64,...`). Accepted media types: `image/png`, `image/jpeg`, `image/webp`, `image/heic`, `image/gif` (first frame).
- **Remote `http(s)` URLs are rejected** - apfel does not fetch remote images; it is 100% on-device.
- **`file://` URLs and local paths are rejected** - an HTTP client must not make the server read arbitrary local files.
- **20 MB base64 cap per image**; the request-body cap is 24 MiB on macOS 27 (1 MiB on macOS 26, unchanged). Images are downscaled to at most 4096 px on the longest side while decoding.
- **`detail` is accepted and ignored** - the on-device model has no detail levels.
- Image parts are allowed in `user` messages only; images in earlier user turns stay in the conversation across tool-calling rounds and retries.
- The image's token cost appears in `prompt_tokens` (the macOS 27 runtime prices it; a 64x64 PNG adds roughly 60-70 tokens, a photo roughly 120-220).

```bash
IMG=$(base64 -i photo.jpg)
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d @- << EOF
{
  "model": "apple-foundationmodel",
  "messages": [{"role": "user", "content": [
    {"type": "text", "text": "Describe this image in one sentence."},
    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$IMG"}}
  ]}]
}
EOF
```

Be honest about what to expect: the ~3B on-device model's scene understanding is coarse. Asked to describe the Apollo 11 plaque photo, it answered "A bottle of amber liquid is wrapped in clear plastic and placed on a metal shelf surrounded by leaves." Unambiguous content works well (a solid red square is reliably "Red"); for reading print, the CLI's OCR path (`apfel -f photo.jpg`) remains the reliable channel - on macOS 27 the CLI sends both.

## Responses API

`POST /v1/responses` is served as a translation layer over the same on-device pipeline as Chat Completions. apfel is stateless; the Responses API's server-side conversation state is deliberately not implemented.

| Feature | Status | Notes |
|---------|--------|-------|
| `input` as a string or message list | Supported | Roles `system`, `developer` (folded into system), `user`, `assistant`; string content or `input_text` parts |
| `input_image` parts | Supported on macOS 27 | Base64 data URLs only, same rules as [Images](#images); `detail` accepted and ignored. On macOS 26: 400 |
| `instructions` | Supported | Becomes the system prompt |
| `stream: true` | Supported | Canonical event sequence: `response.created` ... `response.output_text.delta` ... `response.completed`, with `sequence_number` |
| `temperature`, `top_p`, `max_output_tokens`, `metadata` | Supported | Same semantics as chat; metadata echoed back |
| `text.format: json_object` / `json_schema` | Supported | json_schema is non-streaming only (501 with `stream: true`); same schema subset as Chat Completions, see [JSON Schema support](#json-schema-support) |
| Function tools (flat Responses shape) | Supported | Non-streaming only; the call comes back as a `function_call` output item for the client to execute |
| `usage` | Supported | `input_tokens` / `output_tokens` / `total_tokens`; `input_tokens_details.cached_tokens` carries the runtime's prefix-cache number on macOS 27 (0 on macOS 26). Same accounting note as Chat Completions above |
| `previous_response_id` | 501 | apfel is stateless: resend the full conversation in `input` |
| `store: true` | 501 | Responses are never stored; every response reports `"store": false` |
| `background`, `reasoning`, `include` | 501 | Not available on-device |
| Hosted tools (`web_search`, `file_search`, `computer_use`, ...) | 501 | The on-device model has no hosted tools |
| `function_call_output` input items | 501 | Tool-result round-trips are not yet supported on this endpoint; use Chat Completions |

MCP tools attached with `--mcp` are auto-executed on Chat Completions only; `/v1/responses` serves client-defined function tools.

## Token preflight (`/v1/responses/input_tokens`)

`POST /v1/responses/input_tokens` answers "does this fit?" before you spend time on generation. It takes the same body as `/v1/responses` minus the sampling fields, prepares the input exactly as generation would (instructions, roles, tool definitions, `text.format` schema, truncation), and counts it with Apple's on-device tokenizer (`SystemLanguageModel.tokenCount(for:)`). It never generates and never runs a tool. The official SDK call works unchanged:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="local-placeholder")
report = client.responses.input_tokens.count(
    model="apple-foundationmodel",
    input="Summarize this local support ticket.",
)
print(report.input_tokens)
```

The response is OpenAI's object plus an additive `x_apfel` report of the runtime budget it was measured against:

```json
{"object": "response.input_tokens", "input_tokens": 62,
 "x_apfel": {"context_size": 4096, "context_size_measured": true, "output_reserve": 512,
             "input_budget": 3584, "untrimmed_input_tokens": 62, "input_tokens": 62,
             "truncation": "auto", "fits": true, "trimmed": false,
             "removed_input_items": [], "tokenizer": "apple-foundationmodels"}}
```

| Request | Result |
|---------|--------|
| `model`, `input` (string or messages), `instructions`, `tools` (function), `tool_choice`, `text.format`, `truncation`, `parallel_tool_calls` | Counted, same mapping and validation as `/v1/responses` |
| `truncation: "auto"` (default), input over budget | 200: oldest turns dropped exactly as generation drops them; `input_tokens` is the trimmed count, `removed_input_items` lists the dropped `input` indices |
| `truncation: "disabled"`, input over budget | 400, `code: context_length_exceeded`, message with the counted tokens, budget, window and reserve |
| Instructions, tools or the last message alone over budget | 400 `context_length_exceeded`, also with `auto` |
| macOS 26.0 to 26.3 (no tokenizer API) | 501, `code: token_counting_unavailable`. No estimate is returned |
| Apple Intelligence unavailable / tokenizer throws | 503, `code: token_counting_unavailable` / `token_counting_failed` |
| `input_image`, `input_file`, `conversation`, `previous_response_id`, `reasoning`, hosted tools | 501 or 400, named in the message |
| `stream`, `temperature`, `top_p`, `max_output_tokens`, `metadata`, `store`, other unknown keys | 400 naming the parameter: they do not change the input tokens |

Auth, origin checks, CORS, the body-size limit and `--max-concurrent` apply as on every other route.

What the number means, measured on macOS 27.0.1:

- **Text, instructions, multi-turn, `json_schema`, auto-truncated input:** the count equals the `usage.input_tokens` the runtime reports when the same request is generated. It includes the default instructions the runtime adds when there is no system message, and the schema's prompt overhead.
- **Function tools:** the count includes the full tool definitions (name, description, parameter schema), rendered into the instructions as compact JSON, which is the text the model reads (#555) and what apfel's own budget check uses. On macOS 27 it equals the runtime-reported `usage.input_tokens` (one `add` tool: 221 counted, 221 reported).
- **`context_size`** is read from the runtime per request, never hardcoded: 4096 on macOS 26 and on M1/M2 Macs, 8192 on macOS 27 with an M3 or newer chip and 12 GB+. `context_size_measured: false` means the runtime has not reported its window yet (cold start) and the assumed floor was used.
- **A count does not predict the response.** It prices the input only. How long the answer or a later summary will be, and what it will say, is decided at generation time; keep `output_reserve` (512 tokens) free for it.
- Counting does not generate, but it does use the model's tokenizer: the first count after boot can pay the model's start-up cost.

### Example: fit retrieved documents into the window

A local retrieval client can add documents, most relevant first, until the next one would not fit - with the real tokenizer instead of a guess:

```python
import openai
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="local-placeholder")
MODEL = "apple-foundationmodel"
INSTRUCTIONS = "Answer from the documents only. Say so if they do not contain the answer."

def build_input(question, docs):
    context = "\n\n".join(f"[{i + 1}] {doc}" for i, doc in enumerate(docs))
    return f"Documents:\n{context}\n\nQuestion: {question}"

def fit_documents(question, ranked_docs):
    """Keep the longest prefix of ranked_docs that fits the input budget."""
    kept = []
    for doc in ranked_docs:
        try:
            client.responses.input_tokens.count(
                model=MODEL, instructions=INSTRUCTIONS,
                input=build_input(question, kept + [doc]),
                truncation="disabled",
            )
        except openai.BadRequestError as err:
            if err.code == "context_length_exceeded":
                break
            raise
        kept.append(doc)
    return kept

docs = ["Ticket 4711: the printer on floor 2 shows error E05 after a paper jam.",
        "Runbook: E05 means the fuser is cold; power-cycle and wait 2 minutes."]
question = "How do I fix error E05?"
kept = fit_documents(question, docs)
answer = client.responses.create(model=MODEL, instructions=INSTRUCTIONS,
                                 input=build_input(question, kept))
print(f"{len(kept)} of {len(docs)} documents fit")
print(answer.output_text)
```

`truncation="disabled"` turns "the next document does not fit" into an explicit 400 `context_length_exceeded` instead of a silent trim. Which documents fit is decided before generation; how long the answer will be is not.

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
- **`max_tokens` omitted = use the remaining context window** (4096 tokens on macOS 26 and on M1/M2 Macs, 8192 on macOS 27 with an M3 or newer chip and 12 GB+ (Apple's AFM 3 Core Advanced model) - read at runtime; drop-in OpenAI semantics). If the model runs into the ceiling, the response ends cleanly with `finish_reason: "length"` and the partial content is returned (HTTP 200). Pass `max_tokens` explicitly when you want a tighter latency budget or a known cap. Full rationale and examples in [README.md](../README.md#default-response-cap-max_tokens).

Full upstream schema reference: [https://github.com/openai/openai-openapi](https://github.com/openai/openai-openapi)
