# apfel

[![Version 0.6.26](https://img.shields.io/badge/version-0.6.26-blue)](https://github.com/Arthur-Ficial/apfel)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)

Use the **FREE** local Apple Intelligence LLM on your Mac - your model, your machine, your way.

No API keys. No cloud. No subscriptions. No per-token billing. The AI is already on your computer - apfel lets you use it.

## What is this

Every Mac with Apple Silicon has a **built-in LLM** - Apple's on-device foundation model, shipped as part of Apple Intelligence. Apple provides the [FoundationModels framework](https://developer.apple.com/documentation/foundationmodels) (macOS 26+) to access it, but only exposes it through Siri and system features. **apfel wraps it** in a CLI and an HTTP server - so you can actually use it. All inference runs **on-device**, no network calls.

- **UNIX tool** - `echo "summarize this" | apfel` - pipe-friendly, file attachments, JSON output, exit codes
- **OpenAI-compatible server** - `apfel --serve` - drop-in replacement at `localhost:11434`, works with any OpenAI SDK
- **Tool calling** - function calling with schema conversion, full round-trip support
- **Zero cost** - no API keys, no cloud, no subscriptions, 4096-token context window

![apfel CLI](screenshots/cli.png)

## Requirements & Install

- Apple Silicon Mac, macOS 26 Tahoe or newer, [Apple Intelligence enabled](https://support.apple.com/en-us/121115)
- Building from source requires Command Line Tools with macOS 26.4 SDK (ships Swift 6.3). No Xcode required.

**Homebrew** (recommended):

```bash
brew tap Arthur-Ficial/tap
brew install Arthur-Ficial/tap/apfel
```

**Build from source:**

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install
```

Troubleshooting: [docs/install.md](docs/install.md)

## Quick Start

### UNIX tool

```bash
# Single prompt
apfel "What is the capital of Austria?"

# Stream output
apfel --stream "Write a haiku about code"

# Pipe input
echo "Summarize: $(cat README.md)" | apfel

# Attach file content to prompt
apfel -f README.md "Summarize this project"

# Attach multiple files
apfel -f old.swift -f new.swift "What changed between these two files?"

# Combine files with piped input
git diff HEAD~1 | apfel -f CONVENTIONS.md "Review this diff against our conventions"

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

Context window is managed automatically with configurable strategies:

```bash
apfel --chat --context-strategy newest-first     # default: keep recent turns
apfel --chat --context-strategy oldest-first     # keep earliest turns
apfel --chat --context-strategy sliding-window --context-max-turns 6
apfel --chat --context-strategy summarize        # compress old turns via on-device model
apfel --chat --context-strategy strict           # error on overflow, no trimming
apfel --chat --context-output-reserve 256        # custom output token reserve
```

### File attachments (`-f/--file`)

Attach one or more files to any prompt with `-f`. File contents are prepended to your prompt text. The flag is repeatable - use it as many times as you need.

```bash
# Explain a file
apfel -f main.swift "Explain what this code does"

# Compare two files
apfel -f before.txt -f after.txt "What are the differences?"

# Code review a git diff
jj diff | apfel -f CONVENTIONS.md "Review this diff against our coding conventions"
git diff HEAD~1 | apfel -f style-guide.md "Any style violations in this diff?"

# Summarize a commit
git show HEAD | apfel -f CHANGELOG.md "Write a changelog entry for this commit"

# Combine with other flags
apfel -f data.csv -o json "Extract the top 5 rows" | jq .content
apfel -f code.py -s "You are a senior code reviewer" "Find bugs"
apfel -f spec.md --stream "Generate test cases for this spec"
```

Files, stdin, and prompt arguments all compose naturally:

```bash
# File only (file content becomes the prompt)
apfel -f poem.txt

# File + prompt argument
apfel -f poem.txt "Translate this to German"

# Stdin + prompt argument
echo "some text" | apfel "Summarize this"

# File + stdin + prompt argument (all three combined)
echo "extra context" | apfel -f code.swift "Explain this code with the context above"
```

## Demos

See [`demo/`](./demo/) for real-world shell scripts powered by apfel.

**[cmd](./demo/cmd)** - natural language to shell command:

```bash
demo/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

demo/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
demo/cmd -c "list open ports"                   # -c = copy to clipboard
```

**Shell function version** - add to your `.zshrc` and use `cmd` from anywhere:

```bash
# cmd - natural language to shell command (apfel). Add to .zshrc:
cmd(){ local x c r a; while [[ $1 == -* ]]; do case $1 in -x)x=1;shift;; -c)c=1;shift;; *)break;; esac; done; r=$(apfel -q -s 'Output only a shell command.' "$*" | sed '/^```/d;/^#/d;s/\x1b\[[0-9;]*[a-zA-Z]//g;s/^[[:space:]]*//;/^$/d' | head -1); [[ $r ]] || { echo "no command generated"; return 1; }; printf '\e[32m$\e[0m %s\n' "$r"; [[ $c ]] && printf %s "$r" | pbcopy && echo "(copied)"; [[ $x ]] && { printf 'Run? [y/N] '; read -r a; [[ $a == y ]] && eval "$r"; }; return 0; }
```

```bash
cmd find all swift files larger than 1MB     # shows: $ find . -name "*.swift" -size +1M
cmd -c show disk usage sorted by size        # shows command + copies to clipboard
cmd -x what process is using port 3000       # shows command + asks to run it
cmd list all git branches merged into main
cmd count lines of code by language
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

### Debug GUI

**[apfel-gui](https://github.com/Arthur-Ficial/apfel-gui)** - native macOS SwiftUI app for chatting with Apple Intelligence and inspecting every request/response.

![apfel GUI](screenshots/gui-chat.png)

```bash
# Install (requires apfel):
brew install Arthur-Ficial/tap/apfel    # if you don't have apfel yet
git clone https://github.com/Arthur-Ficial/apfel-gui.git
cd apfel-gui && make install

# Run:
apfel-gui
```

Chat, debug inspector, request logs, context settings, speech-to-text, text-to-speech - all on-device. See the [apfel-gui repo](https://github.com/Arthur-Ficial/apfel-gui) for details.

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
| Context strategies | Supported | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` extension fields |
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
apfel -f <file> <prompt>       Attach file content to prompt
apfel --chat                   Interactive conversation
apfel --stream <prompt>        Stream response tokens
apfel --serve                  Start OpenAI-compatible server
apfel --model-info             Print model capabilities
apfel --release                Show detailed release and build info
```

**General options** (all modes):

| Flag | Description |
|------|-------------|
| `-f, --file <path>` | Attach file content to prompt (repeatable) |
| `-s, --system <text>` | System prompt |
| `--system-file <path>` | Read system prompt from file |
| `-o, --output <fmt>` | Output format: `plain` or `json` |
| `-q, --quiet` | Suppress non-essential output |
| `--no-color` | Disable ANSI colors |
| `--temperature <n>` | Sampling temperature |
| `--seed <n>` | Random seed for reproducibility |
| `--max-tokens <n>` | Maximum response tokens |
| `--permissive` | Use permissive content guardrails |
| `--model-info` | Print model capabilities and exit |
| `--release` | Show detailed version, build, and capability info |
| `-v, --version` | Print version |
| `-h, --help` | Show help |

**Context options** (`--chat`):

| Flag | Description |
|------|-------------|
| `--context-strategy <s>` | `newest-first` (default), `oldest-first`, `sliding-window`, `summarize`, `strict` |
| `--context-max-turns <n>` | Max history turns (`sliding-window` only) |
| `--context-output-reserve <n>` | Tokens reserved for output (default: 512) |

**Server options** (`--serve`):

| Flag | Description |
|------|-------------|
| `--port <n>` | Server port (default: 11434) |
| `--host <addr>` | Bind address (default: 127.0.0.1) |
| `--cors` | Enable CORS headers for browser clients |
| `--allowed-origins <origins>` | Add comma-separated allowed origins to the localhost defaults |
| `--no-origin-check` | Disable origin checking (allow all origins) |
| `--token <secret>` | Require Bearer token authentication |
| `--token-auto` | Generate and print a random Bearer token |
| `--footgun` | Disable all protections (`--no-origin-check` + `--cors`) |
| `--max-concurrent <n>` | Max concurrent requests (default: 5) |
| `--debug` | Verbose logging |

See [Server Security](docs/server-security.md) for detailed documentation on security options.

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
| `APFEL_TOKEN` | Bearer token for server authentication |
| `APFEL_TEMPERATURE` | Default temperature |
| `APFEL_MAX_TOKENS` | Default max tokens |
| `APFEL_CONTEXT_STRATEGY` | Default context strategy |
| `APFEL_CONTEXT_MAX_TURNS` | Max turns for sliding-window |
| `APFEL_CONTEXT_OUTPUT_RESERVE` | Tokens reserved for output |
| `NO_COLOR` | Disable colors ([no-color.org](https://no-color.org)) |

## Architecture

```
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Built with Swift 6.3 strict concurrency. Single `Package.swift`, three targets:
- `ApfelCore` - pure logic library (no FoundationModels dependency, unit-testable)
- `apfel` - executable (CLI + server)
- `apfel-tests` - 48 unit tests

**No Xcode required.** Builds and tests with Command Line Tools only.

## Build & Test

```bash
# Build + install (auto-bumps patch version each time)
make install                             # build release + install to /usr/local/bin
make build                               # build release only (no install)

# Version management (zero manual editing)
make version                             # print current version
make release-minor                       # bump minor: 0.6.x -> 0.7.0
make release-major                       # bump major: 0.x.y -> 1.0.0

# Debug build (no version bump, uses swift directly)
swift build                              # quick debug build

# Tests
swift run apfel-tests                    # 48 pure Swift unit tests (no XCTest needed)
apfel --serve &                          # start server for integration tests
python3 -m pytest Tests/integration/ -v  # 51 integration tests
```

Every `make build`/`make install` automatically:
- Bumps the patch version (`.version` file is the single source of truth)
- Updates the README version badge
- Generates build metadata (commit, date, Swift version) viewable via `apfel --release`

## Related Projects

- [apfel-clip](https://github.com/Arthur-Ficial/apfel-clip) - AI-powered clipboard actions from the menu bar (fix grammar, translate, explain code, and more)
- [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui) - Native macOS SwiftUI debug GUI for apfel (chat, request inspector, logs, TTS/STT)

## Examples

See [docs/EXAMPLES.md](docs/EXAMPLES.md) for 50 real prompts and unedited model outputs.

## License

[MIT](LICENSE)
