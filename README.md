# apfel

### The free AI already on your Mac.

[![Version 1.3.2](https://img.shields.io/badge/version-1.3.2-blue)](https://github.com/Arthur-Ficial/apfel)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](#contributing)

Apple Silicon Macs ship a built-in LLM via [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` exposes it as a UNIX tool and a local OpenAI-compatible server. 100% on-device. No API keys, no cloud.

| Mode | Command | What you get |
|------|---------|--------------|
| UNIX tool | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-friendly answers, file attachments, JSON output, exit codes |
| OpenAI-compatible server | `apfel --serve` | Drop-in local `http://localhost:11434/v1` backend for OpenAI SDKs |

`apfel --chat` - interactive REPL.

Tool calling works in all contexts. 4096-token context.

![apfel CLI](screenshots/cli.png)

## Requirements & Install

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence enabled](https://support.apple.com/en-us/121115). Building from source needs Command Line Tools with the macOS 26.4 SDK (Swift 6.3) - no Xcode.

```bash
brew install apfel                          # homebrew-core
brew install Arthur-Ficial/tap/apfel        # tap, zero-latency
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Update: `brew upgrade apfel` or `apfel --update`. Troubleshooting: [docs/install.md](docs/install.md).

## Quick Start

### UNIX tool

Quote prompts with `!` in single quotes (zsh/bash history expansion): `apfel 'Hello, Mac!'`.

```bash
# Single prompt
apfel "What is the capital of Austria?"

# Permissive mode - reduces guardrail false positives for creative/long prompts
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
brew services stop apfel
APFEL_TOKEN=$(uuidgen) APFEL_MCP=/path/to/tools.py brew services start apfel
```

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-foundationmodel","messages":[{"role":"user","content":"Hello"}]}'
```

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="unused")
resp = client.chat.completions.create(
    model="apple-foundationmodel",
    messages=[{"role": "user", "content": "What is 1+1?"}],
)
print(resp.choices[0].message.content)
```

Background service details: [docs/background-service.md](docs/background-service.md).

### Quick testing chat

`apfel --chat` is a small REPL for testing prompts or MCP servers. For a GUI chat app, see [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C exits. Context is trimmed automatically ([docs/context-strategies.md](docs/context-strategies.md)).

## Demos

Shell scripts in [`demo/`](./demo/):

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

- **[wtd](./demo/wtd)** - "what's this directory?" instant project orientation
- **[explain](./demo/explain)** - explain a command, error, or code snippet
- **[naming](./demo/naming)** - naming suggestions for functions, variables, files
- **[port](./demo/port)** - what's using this port?
- **[gitsum](./demo/gitsum)** - summarize recent git activity

Longer walkthroughs: [docs/demos.md](docs/demos.md).

## MCP Tool Support

Attach [Model Context Protocol](https://modelcontextprotocol.io/) servers with `--mcp`. apfel discovers, invokes, and returns.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Use `-q` to suppress tool info.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Ships with a calculator at [`mcp/calculator/`](./mcp/calculator/) ([docs/mcp-calculator.md](docs/mcp-calculator.md)).

**Remote MCP servers** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Security:** prefer `APFEL_MCP_TOKEN` over `--mcp-token` (ps aux). apfel refuses bearer tokens over plaintext `http://`.

## apfel-run: optional config layer

apfel itself has no config file - flags + env vars, like any UNIX tool. If you want a TOML config (many MCPs, profiles, team configs in git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) is an MIT wrapper that adds one via `execve` drop-in.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API Compatibility

**Base URL:** `http://localhost:11434/v1`

| Feature | Status | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supported | Streaming + non-streaming |
| `GET /v1/models` | Supported | Returns `apple-foundationmodel` |
| `GET /health` | Supported | Model availability, context window, languages |
| `GET /v1/logs`, `/v1/logs/stats` | Debug only | Requires `--debug` |
| Tool calling | Supported | Native `ToolDefinition` + JSON detection. See [docs/tool-calling-guide.md](docs/tool-calling-guide.md) |
| `response_format: json_object` | Supported | System-prompt injection; markdown fences stripped from output |
| `temperature`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions`. Omitting `max_tokens` uses the remaining context window (drop-in OpenAI semantics) - see [Default response cap](#default-response-cap-max_tokens) |
| `stream: true` | Supported | SSE; final usage chunk only when `stream_options: {"include_usage": true}` (per OpenAI spec) |
| `finish_reason` | Supported | `stop`, `tool_calls`, `length` |
| Context strategies | Supported | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` extension fields |
| CORS | Supported | Enable with `--cors` |
| `POST /v1/completions` | 501 | Legacy text completions not supported |
| `POST /v1/embeddings` | 501 | Embeddings not available on-device |
| `logprobs=true`, `n>1`, `stop`, `presence_penalty`, `frequency_penalty` | 400 | Rejected explicitly. `n=1` and `logprobs=false` are accepted as no-ops |
| Multi-modal (images) | 400 | Rejected with clear error |
| `Authorization` header | Supported | Required when `--token` is set. See [docs/server-security.md](docs/server-security.md) |

Full API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Default response cap (`max_tokens`)

When `max_tokens` is omitted, **CLI and OpenAI-compatible server behave identically**: the value flows through as `nil` and the model uses whatever room is left in the 4096-token context window. This is drop-in OpenAI semantics - no arbitrary fallback constant.

The on-device model has a **4096-token context window** that holds input *and* output combined. If generation runs into the ceiling, the response ends cleanly with `finish_reason: "length"` and the partial content is returned (server: HTTP 200; CLI: exit 0 with a stderr warning). Pass `max_tokens` explicitly when you want a tighter latency budget or a known cap for your client.

### Examples

```bash
# Omitted: uses remaining window, finish_reason: "stop" or "length"
curl -sS http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-foundationmodel",
       "messages":[{"role":"user","content":"Reply SKIP, MOVE, or RENAME."}]}'

# Explicit cap (recommended for tight latency budgets)
curl -sS http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"apple-foundationmodel","max_tokens":128,
       "messages":[{"role":"user","content":"Summarise: ..."}]}'
```

### Picking a value

| Use case                               | `max_tokens`  |
|----------------------------------------|---------------|
| Single-word / classification reply     | 16 - 32       |
| One-line instruction                   | 64 - 128      |
| Short paragraph                        | 256 - 512     |
| Long paragraph / structured JSON       | 1024 - 2048   |
| As long as the context window allows   | omit it       |

Keep `input_tokens + max_tokens` comfortably below 4096. If the prompt itself exceeds the window, generation cannot start and the request fails with `[context overflow]` (HTTP 400 / CLI exit 4). The validator rejects non-positive values (`max_tokens <= 0`).

### CLI parity

CLI and server share one rule: omitted = use remaining window. No constant to drift. Override with `--max-tokens N` or `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails for the server

`apfel --serve --permissive` makes the server use Apple's `.permissiveContentTransformations` guardrails for **every request** the process handles. Same flag, same semantics as the CLI's `--permissive` ([docs/PERMISSIVE.md](docs/PERMISSIVE.md)). There is no per-request override - the server operator decides for the whole process.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitations

| Constraint | Detail |
|------------|--------|
| Context window | **4096 tokens** (input + output combined) |
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-foundationmodel`), not configurable |
| Guardrails | Apple's safety system may block benign prompts. `--permissive` reduces false positives ([docs/PERMISSIVE.md](docs/PERMISSIVE.md)) |
| Speed | On-device, not cloud-scale - a few seconds per response |
| No embeddings / vision | Not available on-device |

## Reference Docs

Guides to use apfel from [Python](docs/guides/python.md), [Node.js](docs/guides/nodejs.md), [Ruby](docs/guides/ruby.md), [PHP](docs/guides/php.md), [Bash/curl](docs/guides/bash-curl.md), [Zsh](docs/guides/zsh.md), [AppleScript](docs/guides/applescript.md), [Swift](docs/guides/swift-scripting.md), [Perl](docs/guides/perl.md), [AWK](docs/guides/awk.md) - see [docs/guides/index.md](docs/guides/index.md). Empirically tested; runnable proof at [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](docs/install.md) - install, troubleshooting, and Apple Intelligence setup
- [docs/cli-reference.md](docs/cli-reference.md) - every flag, exit code, and environment variable
- [docs/background-service.md](docs/background-service.md) - `brew services` and launchd usage
- [docs/openai-api-compatibility.md](docs/openai-api-compatibility.md) - `/v1/*` support matrix in depth
- [docs/server-security.md](docs/server-security.md) - origin checks, CORS, tokens, and `--footgun`
- [docs/context-strategies.md](docs/context-strategies.md) - chat trimming strategies
- [docs/mcp-calculator.md](docs/mcp-calculator.md) - local and remote MCP usage
- [docs/tool-calling-guide.md](docs/tool-calling-guide.md) - detailed tool-calling behavior
- [docs/integrations.md](docs/integrations.md) - third-party tool integrations (opencode, etc.)
- [docs/local-setup-with-vs-code.md](docs/local-setup-with-vs-code.md) - local review with apfel + a second edit/apply model in VS Code
- [docs/demos.md](docs/demos.md) - longer walkthroughs of the shell demos
- [docs/EXAMPLES.md](docs/EXAMPLES.md) - 50+ real prompts with unedited output
- [docs/swift-library.md](docs/swift-library.md) - `ApfelCore` Swift Package for downstream developers

## Architecture

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Three targets: `ApfelCore` (pure logic, unit-testable, also available as a Swift Package product - see [docs/swift-library.md](docs/swift-library.md)), `apfel` (CLI + server), and `apfel-tests` (pure Swift runner, no XCTest).

## Build & Test

```bash
make test                                # release build + all unit/integration tests
make preflight                           # full release qualification
make install                             # build release + install to /usr/local/bin
make build                               # build release only
make version                             # print current version
make release                             # patch release
make release TYPE=minor                  # minor release
make release TYPE=major                  # major release
swift build                              # quick debug build (no version bump)
swift run apfel-tests                    # unit tests
python3 -m pytest Tests/integration/ -v  # integration tests
apfel --benchmark -o json                # performance report
```

`.version` is the single source of truth. Only `make release` bumps versions. Local builds do not change the version.

## The apfel tree

Projects built on apfel. Each ships as its own repo + Homebrew formula.

| Project | What it does | Install |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | The root. On-device FoundationModels CLI + OpenAI-compatible server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS chat client: streaming markdown, speech I/O, Apple Vision image analysis. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Menu-bar AI actions on the clipboard: summarize, translate, rewrite. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Instant AI overlay: press a key, ask, answer, dismiss. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formula notepad - on-device AI as an inline cell function. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Token-budget-optimized MCPs for the 4096 window: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspector: request timeline, MCP protocol viewer, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX wrapper adding a persistent MCP registry + TOML config on top of `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift package for ecosystem tools: discover, spawn, and stream from a local `apfel --serve`. | Swift Package |

## Community Projects

Built something on top of apfel? Open an issue and it can be added here.

| Project | What it does | Links |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | Local AI agent that reads files, calendar, mail, and Mac status via read-only tools | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | Browser-based chat UI that talks to `apfel --serve` over the OpenAI-compatible API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | Claude Code wrapper that swaps in apfel as a local backend via a small Anthropic-OpenAI proxy | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | App manager for local shell apps built around apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |

## Contributing

Issues and PRs welcome on any `Arthur-Ficial/apfel*` repo.

**#agentswelcome** - AI agent PRs are fine. Read the repo's `CLAUDE.md`, run the tests, credit the tool in a `Co-Authored-By` trailer. Same bar as humans: clean code, passing tests, honest limits. Most agent-friendly entry point: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([contribution rules](https://apfel-mcp.franzai.com/#contribute)).

## License

[MIT](LICENSE)
