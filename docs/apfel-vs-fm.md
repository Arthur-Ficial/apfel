# apfel vs Apple's fm CLI

macOS 27 ships Apple's own command-line front end for the on-device Foundation Model: `fm`, at `/usr/bin/fm`. apfel has been exposing the same model as a UNIX tool and an OpenAI-compatible server since macOS 26. Both call the same `SystemLanguageModel` through the same FoundationModels framework, so the model, its context window, its guardrails and its speed are identical. The difference is what sits around the model.

This page is the single source of truth for the comparison. Every number below was measured, and the exact commands are listed at the end so you can re-run them.

**Measured on:** apfel 1.14.0 (the released binary, built against the macOS 27.0 SDK, deployment floor macOS 26.0), Apple `fm` 1.0 (`/usr/bin/fm` as shipped with macOS 27.0.1, build 26A434), MacBook Air with Apple M2 and 24 GB (this chip gets the 4096-token AFM 3 Core model; M3+ Macs with 12 GB+ get the 8192-token AFM 3 Core Advanced model - the 8192 reading is [#192](https://github.com/Arthur-Ficial/apfel/issues/192), the first GA run on such a Mac is [#509](https://github.com/Arthur-Ficial/apfel/issues/509)), 2026-10-05. Numbers are re-measured for every apfel release and after every macOS point update.

## TL;DR

- **Same model, same limits.** Both read the same on-device model: 4096-token context window on this M2 Air (8192 on M3 or newer Macs with 12 GB+, which get Apple's larger AFM 3 Core Advanced model), same languages, same safety guardrails, same tokenizer. Neither is "smarter".
- **`fm` is the zero-install option.** It is already on every macOS 27 Mac, Apple-signed, with image input (OCR, barcode) and persistent chat transcripts. If you want to type one prompt once, use `fm`.
- **apfel is the integration option.** OpenAI-compatible server that real clients accept as a drop-in (non-streaming responses, `usage`, tool calling, `response_format: json_schema`, the Responses API, bearer auth, CORS), MCP tool servers, JSON Schema constrained output from the CLI, honest exit codes for scripts, file and PDF extraction, and it runs on macOS 26 as well as 27.
- **`fm serve` is close, but not a drop-in OpenAI server today.** It streams by default when `stream` is omitted (OpenAI clients expect JSON), ignores `max_tokens`, has no tool calling (the `tools` field makes it leak `<start_of_turn>model` template tokens into `content`), returns HTTP 500 for guardrail hits, and has no `/v1/responses`, no auth and no `usage` in streams. Explicit `stream: false` and `response_format: json_schema` work.

## A short history

apfel came first. Its first commit and v0.1.0 landed on 2026-03-24, the first GitHub release (v0.6.4) on 2026-03-31, and it reached the Hacker News front page on 2026-04-03 - at that point the only way to use Apple's on-device model from a terminal or from an OpenAI client. Apple announced `fm` at WWDC on 2026-06-08 (session 334, "Build AI-powered scripts with the fm CLI and Python SDK") and shipped it with macOS 27 on 2026-09-14. Both tools sit on the same FoundationModels framework; `fm` is Apple's first-party take, apfel is the open-source one and the one that also runs on macOS 26.

## What they are

| | apfel | Apple `fm` |
|---|---|---|
| Ships with | `brew install apfel` (also nixpkgs, MacPorts, source) | macOS 27 (`/usr/bin/fm`), nothing to install |
| macOS support | **26 and 27**, one binary | 27 only |
| First run | works immediately | `sudo fm license` in a terminal, type `yes` (machine-wide) |
| License | MIT, open source | Apple SLA, closed |
| Binary | 22.1 MB (arm64 only, Developer ID signed + notarized, statically includes the HTTP stack) | 3.4 MB (universal x86_64 / arm64e, Apple platform binary) |
| Model | Apple on-device Foundation Model via FoundationModels | same |
| Cloud model (Private Cloud Compute, 32k context) | never: apfel is 100 % on-device by principle | advertised as `--model pcc` at WWDC26; the shipped 27.0.1 `fm` accepts only `--model system` |
| Context window | read at runtime (`apfel --model-info`, `/health`); 4096 tokens on this M2, 8192 on M3+ Macs with 12 GB+ on macOS 27 | same model, same window on the same Mac; no `fm` command prints it. Empirically `fm respond` accepts 3988 prompt tokens and rejects 4039 here |

## Command-line tool

| Capability | apfel | `fm` |
|---|---|---|
| One-shot prompt | `apfel "prompt"` | `fm respond "prompt"` |
| Read prompt from stdin | yes, auto-detected (`echo text \| apfel`) | yes (`echo text \| fm respond`) |
| System prompt | `-s`, `--system-file`, `APFEL_SYSTEM_PROMPT` | `-i, --instructions` |
| Streaming | `--stream` (off by default, so output is pipe-safe) | on by default, `--no-stream` to disable |
| Machine-readable output | `-o json` (content, model, metadata incl. finish reason) | no (plain text only) |
| JSON Schema constrained output | `--schema file.json`: guaranteed schema-valid JSON, any local schema with `$ref`/`$defs`, bounds, enums | `--schema file`, schema authored with `fm schema object --name Person --string name --int age` |
| Code-only answers | `--code`: prints the first fenced block, bare command for shell scripts | no |
| Multi-turn in one shot | `--messages file.json` (OpenAI messages array) | `--resume transcript.json` + `--save-transcript` |
| Interactive chat | `apfel --chat` with context trimming strategies | `fm chat` with named sessions (`--resume name`, `--continue`) |
| Attach files | `-f` text, PDF, images (Vision OCR + image understanding), repeatable | `--image` (image input to the model), `--text` segments |
| Image understanding | OCR text via Vision today (works on 26 and 27); native image input to the model on macOS 27 is planned, see [#510](https://github.com/Arthur-Ficial/apfel/issues/510) | yes on macOS 27: `--image photo.jpg` goes to the model itself (the 3B model's descriptions are coarse: it called a metal plaque "a glass bottle wrapped in foil") |
| Built-in vision tools | no | `--tool ocr`, `--tool barcode` |
| External tools | MCP servers, local (`--mcp ./server.py`) and remote (`--mcp https://...`, bearer token, OAuth) | none |
| Sampling | `--temperature`, `--top-p`, `--seed`, `--max-tokens` | `--greedy` only |
| Guardrails | `--permissive` | `--guardrails permissive-content-transformations` |
| Token counting | `apfel --count-tokens` (prompt, system, files, tool schemas, budget, `--strict` exit 4) | `fm count-tokens` (prompt, instructions, images, transcript) |
| Model availability | `apfel --model-info` (context window, languages, framework) | `fm available` |
| Retry on transient errors | `--retry [n]`, exponential backoff | no |
| Exit codes | 0 ok, 1 runtime, 2 usage, 3 guardrail, 4 context overflow, 5 model unavailable, 6 rate limited, 7 empty code answer, 141 closed pipe | 0 ok, 1 for everything else (a guardrail hit exits 1 like any error) |
| Shell completions, man page | bash, zsh, fish; `man apfel` | no |
| Benchmark | `apfel --benchmark` | no |
| Debug logging | `--debug` on every mode | `-v` |
| Telemetry | none, no network except explicit `--update` | Apple binary, not auditable |

## HTTP server

Both tools start a local server. apfel: `apfel --serve` (port 11434). `fm`: `fm serve --port 1976` (TCP) or `--socket path` (Unix socket).

| Capability | apfel `--serve` | `fm serve` |
|---|---|---|
| `POST /v1/chat/completions` | yes | yes |
| Response when `stream` is omitted | one JSON object (OpenAI default) | **SSE stream** (OpenAI clients that did not ask for a stream get `text/event-stream`) |
| `stream: false` explicit | JSON object | JSON object |
| `usage` (prompt / completion tokens) | yes, also in streams with `stream_options.include_usage`; on macOS 27 straight from the runtime's `Response.usage` (same accounting `fm` uses), on macOS 26 counted with the tokenizer | yes in non-streaming responses; a `usage` chunk appears with `stream_options.include_usage` |
| `finish_reason` | `stop`, `length`, `tool_calls` | `stop` |
| Tool calling (`tools`, `tool_choice`) | yes: `finish_reason: tool_calls`, structured `tool_calls`, MCP auto-execution | no: `tools` is accepted, the reply is plain `content` such as `<start_of_turn>model\n{a:2,b:3}` with `finish_reason: stop` |
| `response_format: json_schema` | yes, schema-guaranteed, `$ref` and bounds supported, also streaming | yes (`{"fruit": "apple"}` for the test schema) |
| `response_format: json_object` | yes | not tested |
| `POST /v1/responses` (Responses API) | yes, incl. streaming and `text.format` | no |
| `GET /v1/models` | yes, with `context_window` and `context_window_measured` | yes (`id: "system"`) |
| `GET /health` | model availability, context window, languages, active requests, version | `{"status":"fm serve is running"}` plus model list |
| `max_tokens` | honoured, `finish_reason: length` at the cap | **ignored**: `max_tokens: 5` returned 141 completion tokens with `finish_reason: stop` |
| `temperature`, `top_p`, `seed` | mapped to `GenerationOptions`; `temperature: 0` is greedy | `temperature` accepted silently (effect not verified); `top_p`, `seed` not documented |
| Unsupported endpoints | honest `501` for `/v1/embeddings`, `/v1/completions` | `404 not_found` |
| Explicit `400` for unsupported params | yes for `n>1`, `logprobs`, `stop`, penalties, images | `n>1` gets a clear 400; `logprobs: true` is accepted silently |
| Guardrail hit | HTTP 400, `type: content_policy_violation` | HTTP 500, `type: server_error`; in a stream an `event: error` frame after HTTP 200 was already sent |
| Error body shape | OpenAI `error.type` / `error.code` with mapped HTTP status (400 guardrail, 429 rate limit, 503 unavailable) | OpenAI-like `error` object, `code` is the HTTP status as a string |
| CORS | opt-in `--cors`; unknown `Origin` gets 403 and no `Access-Control-Allow-Origin` | always on; unknown `Origin` gets 403 but the header still echoes the origin |
| Authentication | `--token` bearer auth, origin validation, `--footgun` for 0.0.0.0 | none |
| Bind address | `--host`, `--port` | `--host`, `--port`, `--socket` |
| Context strategies per request | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` | no |
| Concurrency | request semaphore, `/health` shows `active_requests` | undocumented |
| Run as a service | `brew services start apfel` (launchd) | manual |
| Client SDK compatibility | verified with the OpenAI Python/Node SDKs, Zed, opencode, VS Code Copilot, Continue, Open WebUI | `--socket` mode is documented for Apple's local Python bindings; OpenAI SDK clients must pass `stream=False` explicitly |

## Measured numbers

All measurements on the machine in the "Measured on" line above, warm model, no other load. Each latency is the median of 5 runs. The model is the same in both tools, so the differences below are process start-up and I/O overhead, not inference.

| Measurement | apfel | `fm` |
|---|---|---|
| CLI one-shot, "Reply with exactly: hello", warm model, median of 5 | 0.37 s (best 0.36 s) | 0.32 s (best 0.31 s) |
| CLI one-shot, "Write a haiku about autumn." | 0.86 s (best 0.83 s) | 0.87 s (best 0.79 s) |
| CLI one-shot, "List five European capitals, one per line." | 0.82 s (best 0.81 s) | 0.77 s (best 0.77 s) |
| Process start without the model (`apfel --version` / `fm --help`), median of 10 | 0.008 s | 0.008 s |
| HTTP `/v1/chat/completions`, "Reply with exactly: hello", non-streaming, median of 5 | 0.33 s | 0.29 s (`stream: false`) |
| Binary size on disk (SI megabytes) | 22.1 MB | 3.4 MB |

Since v1.14.0 apfel takes `usage` from the runtime's own `Response.usage` on macOS 27 instead of separate token-count round trips, which closed most of the earlier server gap (0.48 s to 0.33 s on this request; [#504](https://github.com/Arthur-Ficial/apfel/issues/504)). What remains - about 0.05 s per call - is apfel's context-budget pre-flight and the OpenAI response assembly; the model time itself is identical. All numbers were taken on an idle machine; an earlier run of the same script under background load read three times higher across the board, so compare only against measurements taken the same way.

Token counts agree exactly between the two tools because both call `SystemLanguageModel.tokenCount(for:)`:

| Prompt | `apfel --count-tokens` | `fm count-tokens -q` |
|---|---|---|
| `Summarize this short sentence.` | 7 | 7 |
| `The quick brown fox jumps over the lazy dog.` | 11 | 11 |
| `Erkläre mir bitte kurz, was ein Compiler macht.` | 13 | 13 |
| `{"a":1,"b":[1,2,3]}` | 14 | 14 |

## Where fm is the better choice

- You are on macOS 27 and want one prompt answered right now. Nothing to install.
- You need image input or the built-in OCR / barcode tools from the command line.
- You want chat sessions that persist and resume by name without any setup.
- You trust an Apple-signed binary more than a third-party Homebrew formula.

## Where apfel is the better choice

- Any existing OpenAI client or app: the server behaves like the API clients were written against (non-streaming JSON, `usage`, errors, tool calls, schemas, Responses API).
- Tool use: MCP servers, local or remote, with the tool loop handled for you.
- Scripts: `--code`, `-o json`, exit codes that mean something, `--count-tokens --strict` preflights, `--retry`.
- Guaranteed-valid JSON from the CLI with your own JSON Schema, including `$ref`.
- PDFs and text files as input, not just images.
- macOS 26 machines. `fm` does not exist there.
- Auditability: open source, no telemetry, reproducible build.

## How to reproduce

Install both and accept the `fm` license once:

```bash
brew install apfel
sudo fm license
```

Token count parity:

```bash
apfel --count-tokens -o json 'Summarize this short sentence.'
fm count-tokens -q 'Summarize this short sentence.'
```

Latency, one-shot prompt (idle machine, run each line five times, take the median):

```bash
time apfel "Reply with exactly: hello"
time fm respond --no-stream "Reply with exactly: hello"
```

Server behaviour. Start `fm serve --port 1976` in one terminal and `apfel --serve` in another, then:

```bash
curl -s localhost:1976/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"system","messages":[{"role":"user","content":"Say OK"}]}'
curl -s localhost:11434/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"apple-foundationmodel","messages":[{"role":"user","content":"Say OK"}]}'
```

The first returns SSE `data:` lines although `stream` was not requested; the second returns one JSON object with `usage`.

Binary sizes and signing:

```bash
ls -l /usr/bin/fm "$(which apfel)"
codesign -dv /usr/bin/fm "$(which apfel)"
```

Context window as the model reports it:

```bash
apfel --model-info
```

`fm` has no command that prints the context window. To find the limit empirically with `fm`, send prompts of known size (`fm count-tokens -q`) and watch for "The session's transcript exceeded the model's context size": on this M2 the boundary sits between 3988 and 4039 prompt tokens.
