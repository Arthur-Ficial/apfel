# apfel

[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)

Use the **FREE** local Apple Intelligence LLM on your Mac - your model, your machine, your way.

No API keys. No cloud. No subscriptions. No per-token billing. The AI is already on your computer - apfel lets you use it.

## What is this

Every Mac with Apple Silicon has a **built-in LLM** - Apple's on-device foundation model, shipped as part of Apple Intelligence. Apple provides the [FoundationModels framework](https://developer.apple.com/documentation/foundationmodels) (macOS 26+) to access it, but only exposes it through Siri and system features. **apfel wraps it** in a CLI, an HTTP server, and a debug GUI - so you can actually use it. All inference runs **on-device**, no network calls.

- **UNIX tool** - `echo "summarize this" | apfel` - pipe-friendly, JSON output, exit codes, env vars
- **OpenAI-compatible server** - `apfel --serve` - drop-in replacement at `localhost:11434`, works with any OpenAI SDK
- **Debug GUI** - `apfel --gui` - native SwiftUI inspector for requests, responses, and streaming events
- **Tool calling** - function calling with schema conversion, full round-trip support
- **Zero cost** - no API keys, no cloud, no subscriptions, 4096-token context window

![apfel CLI](screenshots/cli.png)

![apfel GUI Debug Inspector](screenshots/gui-chat.png)

## Install

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install    # builds release, installs to /usr/local/bin
```

Requires macOS 26+, Apple Silicon, and [Apple Intelligence enabled](https://support.apple.com/en-us/121115).

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

Context window is managed automatically - oldest messages rotate out when the 4096-token limit approaches.

### Debug GUI

```bash
apfel --gui
```

Inspect every request/response, copy curl commands, view SSE streams, track token budgets.

## Demos

See [`demo/`](./demo/) for real-world shell scripts powered by apfel.

**[cmd](./demo/cmd)** - natural language to shell command:

```bash
demo/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

demo/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
demo/cmd -c "list open ports"                   # -c = copy to clipboard
```

**[oneliner](./demo/oneliner)** - complex pipe chains from plain English:

```bash
demo/oneliner "sum the third column of a CSV"
# $ awk -F',' '{sum += $3} END {print sum}' file.csv

demo/oneliner "count unique IPs in access.log"
# $ awk '{print $1}' access.log | sort | uniq -c | sort -rn
```

**[mac-narrator](./demo/mac-narrator)** - your Mac's inner monologue:

```bash
demo/mac-narrator              # one-shot: what's happening right now?
demo/mac-narrator --watch      # continuous narration every 60s
```

Also in `demo/`:
- **[wtd](./demo/wtd)** - "what's this directory?" - instant project orientation
- **[explain](./demo/explain)** - explain a command, error, or code snippet
- **[naming](./demo/naming)** - naming suggestions for functions, variables, files
- **[port](./demo/port)** - what's using this port?
- **[gitsum](./demo/gitsum)** - summarize recent git activity

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
| `logprobs=true`, `n>1`, `stop`, `presence_penalty`, `frequency_penalty` | 400 | Rejected explicitly. `n=1` and `logprobs=false` are accepted as no-ops |
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
| Speed | On-device inference, not cloud-scale - expect a few seconds per response |
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
- `ApfelCore` - pure logic library (no FoundationModels dependency, unit-testable)
- `apfel` - executable (CLI + server + GUI)
- `apfel-tests` - 28 unit tests

## Build & Test

```bash
swift build                              # debug build
swift run apfel-tests                    # pure Swift unit tests
bash Tests/integration/run_tests.sh      # release-binary integration tests
```

## Examples

See [EXAMPLES.md](./EXAMPLES.md) for 50 real prompts and unedited model outputs.

## License

[MIT](LICENSE)
