# apfel

[![Version 0.9.15](https://img.shields.io/badge/version-0.9.15-blue)](https://github.com/Arthur-Ficial/apfel)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)

Use the **FREE** local Apple Intelligence LLM on your Mac - your model, your machine, your way.

No API keys. No cloud. No subscriptions. No per-token billing. The AI is already on your computer - apfel lets you use it.

## What is this

Every Mac with Apple Silicon has a **built-in LLM** - Apple's on-device foundation model, shipped as part of Apple Intelligence. Apple provides the [FoundationModels framework](https://developer.apple.com/documentation/foundationmodels) (macOS 26+) to access it, but only exposes it through Siri and system features. **apfel wraps it** in a CLI and an HTTP server - so you can actually use it. All **inference** runs on-device with no network calls for the LLM itself. Optional remote MCP tool servers (`--mcp https://...`) do make network calls for tool arguments — see [MCP Tool Support](#mcp-tool-support).

- **UNIX tool** - `echo "summarize this" | apfel` - pipe-friendly, file attachments, JSON output, exit codes
- **Interactive chat** - `apfel --chat` - multi-turn conversation with context window management
- **OpenAI-compatible server** - `apfel --serve` - drop-in replacement at `localhost:11434`, works with any OpenAI SDK
- **Tool calling** - function calling with schema conversion, full round-trip support
- **Zero cost** - no API keys, no cloud, no subscriptions, 4096-token context window
- **GUI apps** - chat client [apfel-chat](https://apfel-chat.franzai.com) ([gh](https://github.com/Arthur-Ficial/apfel-chat)), clipboard actions [apfel-clip](https://apfel-clip.franzai.com) ([gh](https://github.com/Arthur-Ficial/apfel-clip)), debug inspector [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui) ([gh](https://github.com/Arthur-Ficial/apfel-gui))

![apfel CLI](screenshots/cli.png)

## Requirements & Install

- **macOS 26 Tahoe or newer**, Apple Silicon (M1+), [Apple Intelligence enabled](https://support.apple.com/en-us/121115). Older macOS is not supported - Apple's FoundationModels framework does not exist before macOS 26.
- Building from source requires Command Line Tools with macOS 26.4 SDK (ships Swift 6.3). No Xcode required.

**Homebrew** (recommended):

```bash
brew tap Arthur-Ficial/tap
brew install apfel
brew upgrade apfel
```

**Update:**

```bash
brew upgrade apfel
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

Shell note: if your prompt contains `!`, prefer single quotes in `zsh`/`bash` so history expansion does not break copy-paste. Example: `apfel 'Hello, Mac!'`

```bash
# Single prompt
apfel "What is the capital of Austria?"

# Permissive mode -- reduces guardrail false positives for creative/long prompts
apfel --permissive "Write a dramatic opening for a thriller novel"

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
apfel --serve                              # foreground
brew services start apfel                  # background (like Ollama)
```

Then in another terminal:

```bash
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

Run in background (auto-restarts, starts at login - [docs/background-service.md](docs/background-service.md)):

```bash
brew services start apfel
brew services stop apfel
APFEL_TOKEN=$(uuidgen) APFEL_MCP=/path/to/tools.py brew services start apfel
```

### Interactive chat

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C exits cleanly. Context window is managed automatically with configurable strategies: [docs/context-strategies.md](docs/context-strategies.md).

### Updating

```bash
apfel --update
```

Or directly via Homebrew: `brew upgrade apfel`

### Benchmarking

Measure internal overhead on the installed release binary:

```bash
apfel --benchmark -o json
make benchmark
```

### File attachments (`-f/--file`)

Attach files to any prompt with `-f` (repeatable). Contents are prepended to your prompt.

```bash
apfel -f main.swift "Explain what this code does"
apfel -f before.txt -f after.txt "What are the differences?"
git diff HEAD~1 | apfel -f style-guide.md "Any style violations in this diff?"
apfel -f data.csv -o json "Extract the top 5 rows" | jq .content
```

Files, stdin, and prompt arguments all compose:

```bash
apfel -f poem.txt                                    # file only
apfel -f poem.txt "Translate this to German"          # file + prompt
echo "some text" | apfel "Summarize this"             # stdin + prompt
echo "ctx" | apfel -f code.swift "Explain with context" # all three
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

```bash
brew install Arthur-Ficial/tap/apfel-gui
```

![apfel GUI](screenshots/gui-chat.png)

Native SwiftUI debug inspector with request timeline, MCP protocol viewer, chat, TTS/STT - all on-device. **[apfel-gui repo ->](https://github.com/Arthur-Ficial/apfel-gui)**

## MCP Tool Support

Attach [MCP](https://modelcontextprotocol.io/) tool servers with `--mcp`. apfel discovers tools, executes them automatically, and returns the final answer. No glue code needed.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Tool info goes to stderr; only the answer goes to stdout. Use `-q` to suppress tool info.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"  # multiple servers
apfel --serve --mcp ./mcp/calculator/server.py                   # server mode
apfel --chat --mcp ./mcp/calculator/server.py                    # chat mode
```

Ships with a calculator MCP server at `mcp/calculator/`. See [docs/mcp-calculator.md](docs/mcp-calculator.md) for details.

**Remote MCP servers** (Streamable HTTP transport, MCP spec 2025-03-26):

```bash
# Remote MCP server over HTTPS
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# With bearer token auth - prefer the env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."
apfel --mcp https://mcp.example.com/v1 --mcp-token mytoken "..."

# Mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Security:** Use `APFEL_MCP_TOKEN` env var rather than `--mcp-token` — CLI flags are visible in `ps aux`. apfel refuses to send a bearer token over plaintext `http://` (use `https://`).

## OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| `GET /v1/logs`, `/v1/logs/stats` | Debug only | Requires `--debug` |
| Tool calling | Supported | Native `ToolDefinition` + JSON detection. See [docs/tool-calling-guide.md](docs/tool-calling-guide.md) |
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
| `Authorization` header | Supported | Required when `--token` is set. See [docs/server-security.md](docs/server-security.md) |

Full API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi)


## Limitations

| Constraint | Detail |
|------------|--------|
| Context window | **4096 tokens** (input + output combined) |
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-foundationmodel`), not configurable |
| Guardrails | Apple's safety system may block benign prompts (use `--permissive` to reduce false positives). See [docs/PERMISSIVE.md](docs/PERMISSIVE.md) |
| Speed | On-device, not cloud-scale - a few seconds per response |
| No embeddings / vision | Not available on-device |

## CLI Reference

```
MODES
  apfel <prompt>                          Single prompt (default)
  apfel --stream <prompt>                 Stream response tokens
  apfel --chat                            Interactive conversation
  apfel --serve                           Start OpenAI-compatible server
  apfel --benchmark                       Run internal performance benchmarks

INPUT
  apfel -f, --file <path> <prompt>        Attach file content (repeatable)
  apfel -s, --system <text> <prompt>      Set system prompt
  apfel --system-file <path> <prompt>     Read system prompt from file
  apfel --mcp <path|url> <prompt>         Attach local or remote MCP tool server (repeatable)
  apfel --mcp-token <token> <prompt>     Bearer token for remote MCP servers
  apfel --mcp-timeout <n> <prompt>       MCP timeout in seconds [default: 5]

OUTPUT
  -o, --output <fmt>                      Output format: plain, json
  -q, --quiet                             Suppress non-essential output
  --no-color                              Disable ANSI colors

MODEL
  --temperature <n>                       Sampling temperature (e.g., 0.7)
  --seed <n>                              Random seed for reproducibility
  --max-tokens <n>                        Maximum response tokens
  --permissive                            Relaxed guardrails (reduces false positives)
  --retry [n]                             Retry transient errors with backoff (default: 3)
  --debug                                 Enable debug logging to stderr (all modes)

CONTEXT (--chat)
  --context-strategy <s>                  newest-first, oldest-first, sliding-window, summarize, strict
  --context-max-turns <n>                 Max history turns (sliding-window only)
  --context-output-reserve <n>            Tokens reserved for output (default: 512)

SERVER (--serve)
  --port <n>                              Server port (default: 11434)
  --host <addr>                           Bind address (default: 127.0.0.1)
  --cors                                  Enable CORS headers
  --allowed-origins <origins>             Comma-separated allowed origins
  --no-origin-check                       Disable origin checking
  --token <secret>                        Require Bearer token auth
  --token-auto                            Generate random Bearer token
  --public-health                         Keep /health unauthenticated
  --footgun                               Disable all protections
  --max-concurrent <n>                    Max concurrent requests (default: 5)

META
  -v, --version                           Print version
  -h, --help                              Show help
  --release                               Detailed build info
  --model-info                            Print model capabilities
  --update                                Check for updates via Homebrew
```

**Examples by flag:**

```bash
# -f, --file — attach file content to prompt (repeatable)
apfel -f main.swift "Explain this code"
apfel -f before.txt -f after.txt "What changed?"

# -s, --system — set a system prompt
apfel -s "You are a pirate" "What is recursion?"
apfel -s "Reply in JSON only" "List 3 colors"

# --system-file — read system prompt from a file
apfel --system-file persona.txt "Introduce yourself"

# --mcp — attach MCP tool servers (repeatable)
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
apfel --mcp ./calc.py --mcp ./weather.py "Use both tools"

# -f, --file
apfel -f main.swift "Explain this code"
apfel -f before.txt -f after.txt "What changed?"

# -s, --system
apfel -s "You are a pirate" "What is recursion?"

# --system-file
apfel --system-file persona.txt "Introduce yourself"

# --mcp, --mcp-token, --mcp-timeout
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
apfel --mcp ./calc.py --mcp ./weather.py "Use both tools"
apfel --mcp https://mcp.example.com/v1 "Remote MCP server"
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "With auth"
apfel --mcp-timeout 30 --mcp ./slow-remote-server.py "hello"

# -o, --output
apfel -o json "Translate to German: hello" | jq .content

# -q, --quiet
apfel -q "Give me a UUID"

# --no-color
NO_COLOR=1 apfel "Hello"

# --temperature
apfel --temperature 0.0 "What is 2+2?"
apfel --temperature 1.5 "Write a wild poem"

# --seed
apfel --seed 42 "Tell me a joke"

# --max-tokens
apfel --max-tokens 50 "Explain quantum computing"

# --permissive — relaxed guardrails (see docs/PERMISSIVE.md for comparison)
apfel --permissive "Write a villain monologue"
apfel --permissive -f long-document.md "Summarize this"

# --retry
apfel --retry "What is 2+2?"

# --debug
apfel --debug "Hello world"

# --stream
apfel --stream "Write a haiku about code"

# --chat
apfel --chat
apfel --chat -s "You are a helpful coding assistant"

# --context-strategy
apfel --chat --context-strategy newest-first      # default
apfel --chat --context-strategy sliding-window --context-max-turns 6
apfel --chat --context-strategy summarize          # compress old turns

# --serve
apfel --serve
apfel --serve --port 3000 --host 0.0.0.0

# --cors, --token, --footgun
apfel --serve --cors
apfel --serve --token "my-secret-token"
apfel --serve --footgun   # only for local development!

# --token-auto, --public-health
apfel --serve --token-auto --host 0.0.0.0 --public-health

# --allowed-origins, --no-origin-check
apfel --serve --allowed-origins "https://myapp.com,https://staging.myapp.com"
apfel --serve --no-origin-check

# --max-concurrent
apfel --serve --max-concurrent 2

# --debug (server: also enables /v1/logs)
apfel --serve --debug

# --context-output-reserve
apfel --chat --context-output-reserve 256

# --benchmark, --model-info, --update, --release, --version, --help
apfel --benchmark -o json | jq '.benchmarks[] | {name, speedup_ratio}'
apfel --model-info
apfel --update
apfel --release
apfel --version
apfel --help
```

See [docs/server-security.md](docs/server-security.md) for detailed documentation on security options.

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
| `APFEL_MCP` | MCP server paths — colon-separated for local paths, comma-separated for mixed local+remote URLs |
| `APFEL_MCP_TOKEN` | Bearer token for remote HTTP MCP servers (preferred over `--mcp-token`; not visible in `ps aux`) |
| `APFEL_MCP_TIMEOUT` | MCP timeout in seconds (default: 5, max: 300) |
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

Swift 6.3 strict concurrency. Three targets: `ApfelCore` (pure logic, unit-testable), `apfel` (CLI + server), `apfel-tests` (pure Swift runner, no XCTest). **No Xcode required.**


## Build & Test

```bash
make install                             # build release + install to /usr/local/bin
make build                               # build release only
make version                             # print current version
make release-minor                       # bump minor: 0.6.x -> 0.7.0
swift build                              # quick debug build (no version bump)
swift run apfel-tests                    # unit tests
python3 -m pytest Tests/integration/ -v  # integration tests (auto-starts servers)
apfel --benchmark -o json                # performance report
```

Every `make build`/`make install` auto-bumps the patch version, updates the README badge, and generates build metadata (`.version` is the single source of truth).

## Integrations

apfel works with any tool that speaks the OpenAI API. Verified configs:

- **opencode** - AI coding assistant with apfel as local backend. [docs/integrations.md](docs/integrations.md)
- **Visual Studio Code + Continue** - local review/chat model paired with a hosted model for edit/apply. [docs/local-setup-with-vs-code.md](docs/local-setup-with-vs-code.md)

## Related Projects

- [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) - Multi-conversation macOS chat client. Private, on-device, no API keys. Streaming markdown, speech I/O, image analysis. Install: `brew install Arthur-Ficial/tap/apfel-chat`
- [apfel-clip](https://github.com/Arthur-Ficial/apfel-clip) - AI clipboard actions from the menu bar
- [apfel-gui](https://github.com/Arthur-Ficial/apfel-gui) - Native macOS debug GUI (inspector, MCP viewer, TTS/STT)
- [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) - Three token-budget-optimized MCP servers (url-fetch, ddg-search, compound search+fetch) tuned for apfel's 4096-token context window. Install: `brew install Arthur-Ficial/tap/apfel-mcp`

## Community Projects

Things the community has built on top of apfel. Built something? Open an issue and we will add it.

- [apfelclaw](https://apfelclaw.yamanlabs.com/) ([gh](https://github.com/julianyaman/apfelclaw)) by [@julianYaman](https://github.com/julianYaman) - Local AI agent that reads files, calendar, mail, and Mac status via read-only tools. Swift + Vapor backend, Bun TUI, optional Telegram remote.

## Examples

See [docs/EXAMPLES.md](docs/EXAMPLES.md) for 50+ real prompts with unedited model output.

## License

[MIT](LICENSE)
