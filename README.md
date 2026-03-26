# apfel

[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)

Apple Intelligence as a UNIX tool and OpenAI-compatible API server.

No API keys. No cloud. No model downloads. Runs entirely on your Mac.

## What is this

- **A UNIX tool** — pipe-friendly CLI with JSON output, exit codes, env vars
- **An OpenAI-compatible server** — drop-in `localhost` replacement for the OpenAI API
- **A debug GUI** — native macOS inspector for requests, responses, and streaming events

One binary. One on-device model. Three interfaces.

![apfel CLI](screenshots/cli.png)

![apfel GUI Debug Inspector](screenshots/gui-chat.png)

## Install

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install    # builds release, installs to /usr/local/bin
```

Requires macOS 26+, Apple Silicon, and [Apple Intelligence enabled](https://support.apple.com/en-us/108380).

## Quick Start

### UNIX tool

```bash
# Single prompt
apfel "What is the capital of Austria?"

# Stream output
apfel --stream "Write a haiku about code"

# Pipe input
echo "Summarize: $(cat README.md)" | apfel

# JSON output for scripting
apfel -o json "Translate to German: hello" | jq .content

# System prompt
apfel -s "You are a pirate" "What is recursion?"

# System prompt from file
apfel --system-file persona.txt "Explain TCP/IP"

# Quiet mode for shell scripts
result=$(apfel -q "Capital of France? One word.")
```

### OpenAI-compatible server

```bash
# Start server
apfel --serve

# In another terminal:
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-foundationmodel","messages":[{"role":"user","content":"Hello"}]}'
```

Works with the official Python client:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="unused")
resp = client.chat.completions.create(
    model="apple-foundationmodel",
    messages=[{"role": "user", "content": "What is 1+1?"}],
)
print(resp.choices[0].message.content)
```

### Interactive chat

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
```

Context window is managed automatically — oldest messages rotate out when the 4096-token limit approaches.

### Debug GUI

```bash
apfel --gui
```

Inspect every request/response, copy curl commands, view SSE streams, track token budgets.

## Demos

See [`demo/`](./demo/) for 8 real-world shell scripts powered by apfel.

| Demo | What it does |
|------|-------------|
| **[cmd](./demo/cmd)** | Natural language to shell command |
| **[oneliner](./demo/oneliner)** | Complex pipe chains from plain English |
| **[wtf](./demo/wtf)** | "What is this directory?" — instant project orientation |
| **[explain](./demo/explain)** | Explain a command, error, or code snippet |
| **[naming](./demo/naming)** | Naming suggestions for functions, variables, files |
| **[port](./demo/port)** | What's using this port? |
| **[gitsum](./demo/gitsum)** | Summarize recent git activity |
| **[mac-narrator](./demo/mac-narrator)** | Your Mac's inner monologue |

```bash
demo/cmd "find all .log files modified today"        # shell command from English
demo/oneliner "sum the third column of a CSV"        # awk/sed/grep one-liners
demo/wtf ~/some/project                              # what is this repo?
demo/explain "awk -F: '{print \$1}' /etc/passwd"     # explain a command
demo/naming "function that retries with backoff"      # name things well
demo/port 3000                                        # what's on this port?
demo/gitsum                                           # summarize recent commits
demo/mac-narrator --watch                             # continuous narration
```

## OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| Tool calling | Supported | Native `Transcript.ToolDefinition` + JSON detection. See [Tool Calling Guide](docs/tool-calling-guide.md) |
| `response_format: json_object` | Supported | Via system prompt injection |
| `temperature`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions` |
| `stream: true` | Supported | SSE with usage stats in final chunk |
| `finish_reason` | Supported | `stop`, `tool_calls`, `length` |
| CORS | Supported | Enable with `--cors` |
| `POST /v1/completions` | 501 | Legacy text completions not supported |
| `POST /v1/embeddings` | 501 | Embeddings not available on-device |
| `logprobs`, `n`, `stop` | Ignored | Not supported by Apple's model |
| Multi-modal (images) | 400 | Rejected with clear error |
| `Authorization` header | Accepted | Ignored (no auth needed for localhost) |

Full API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi)

## Limitations

| Constraint | Detail |
|------------|--------|
| Context window | **4096 tokens** (input + output combined). ~3000 English words. |
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-foundationmodel`), not configurable |
| Guardrails | Apple's safety system may block benign prompts (false positives exist) |
| Speed | On-device inference, not cloud-scale — expect a few seconds per response |
| No embeddings | Apple's model doesn't support vector embeddings |
| No vision | Image/multi-modal input not supported |

## CLI Reference

```
apfel [OPTIONS] <prompt>       Single prompt
apfel --chat                   Interactive conversation
apfel --stream <prompt>        Stream response tokens
apfel --serve                  Start OpenAI-compatible server
apfel --gui                    Launch debug GUI
apfel --model-info             Print model capabilities
```

| Flag | Description |
|------|-------------|
| `-s, --system <text>` | System prompt |
| `--system-file <path>` | Read system prompt from file |
| `-o, --output <fmt>` | Output format: `plain` or `json` |
| `-q, --quiet` | Suppress non-essential output |
| `--no-color` | Disable ANSI colors |
| `--temperature <n>` | Sampling temperature |
| `--seed <n>` | Random seed for reproducibility |
| `--max-tokens <n>` | Maximum response tokens |
| `--permissive` | Use permissive guardrails |
| `--port <n>` | Server port (default: 11434) |
| `--host <addr>` | Server bind address (default: 127.0.0.1) |
| `--cors` | Enable CORS headers |
| `--max-concurrent <n>` | Max concurrent requests (default: 5) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Usage error (bad flags) |
| 3 | Guardrail blocked |
| 4 | Context overflow |
| 5 | Model unavailable |
| 6 | Rate limited |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `APFEL_SYSTEM_PROMPT` | Default system prompt |
| `APFEL_HOST` | Server bind address |
| `APFEL_PORT` | Server port |
| `APFEL_TEMPERATURE` | Default temperature |
| `APFEL_MAX_TOKENS` | Default max tokens |
| `NO_COLOR` | Disable colors ([no-color.org](https://no-color.org)) |

## Architecture

```
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┤   (100% on-device, zero network)
                           │
GUI (SwiftUI) ─── HTTP ────┘   ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Built with Swift 6.3 strict concurrency. Single `Package.swift`, three targets:
- `ApfelCore` — pure logic library (no FoundationModels dependency, unit-testable)
- `apfel` — executable (CLI + server + GUI)
- `apfel-tests` — 28 unit tests

## Build & Test

```bash
swift build                              # debug build
swift run apfel-tests                    # 28 unit tests
bash Tests/integration/run_tests.sh      # 33 integration tests (needs server)
```

## Examples

See [EXAMPLES.md](./EXAMPLES.md) for 50 real prompts and unedited model outputs.

## License

[MIT](LICENSE)
