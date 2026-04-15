# apfel

### The free AI already on your Mac.

[![Version 1.0.4](https://img.shields.io/badge/version-1.0.4-blue)](https://github.com/Arthur-Ficial/apfel)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](#contributing)

Every Mac with Apple Silicon ships a built-in language model as part of Apple Intelligence. `apfel` gives you access to it — from the terminal, as a local OpenAI-compatible server, or as an interactive chat. No API keys, no cloud, no downloads. It's already on your machine.

## What It Is

Every Apple Silicon Mac with Apple Intelligence includes Apple's on-device foundation model. `apfel` exposes it through [https://developer.apple.com/documentation/foundationmodels](https://developer.apple.com/documentation/foundationmodels) so you can use it directly from the shell and from OpenAI-compatible clients.

| Mode | Command | What you get |
|------|---------|--------------|
| UNIX tool | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-friendly answers, file attachments, JSON output, exit codes |
| OpenAI-compatible server | `apfel --serve` | Drop-in local `http://localhost:11434/v1` backend for OpenAI SDKs |
| Command-line chat | `apfel --chat` | Multi-turn chat with context-window management |

Tool calling works across CLI, chat, and server. Inference stays 100% on-device. The context window is 4096 tokens.

![apfel CLI](screenshots/cli.png)

## Requirements & Install

- **macOS 26 Tahoe or newer**, Apple Silicon (M1+), and Apple Intelligence enabled: [https://support.apple.com/en-us/121115](https://support.apple.com/en-us/121115)
- Building from source requires Command Line Tools with the macOS 26.4 SDK (Swift 6.3). No Xcode required.

**Homebrew** (recommended):

```bash
brew install apfel
brew upgrade apfel
```

Latest release immediately via tap: `brew install Arthur-Ficial/tap/apfel` (homebrew-core autobump can lag up to 24h).

**Build from source:**

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install
```

Update with `brew upgrade apfel` or `apfel --update`. Troubleshooting and Apple Intelligence setup notes: [docs/install.md](docs/install.md).

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

Ctrl-C exits cleanly. Context window is managed automatically with configurable strategies ([docs/context-strategies.md](docs/context-strategies.md)).

## Demos

See [`demo/`](./demo/) for real-world shell scripts powered by apfel.

**[cmd](./demo/cmd)** — natural language to shell command:

```bash
demo/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

demo/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
demo/cmd -c "list open ports"                   # -c = copy to clipboard
```

**Shell function version** — add to your `.zshrc` and use `cmd` from anywhere:

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

**[oneliner](./demo/oneliner)** — complex pipe chains from plain English:

```bash
demo/oneliner "sum the third column of a CSV"
# $ awk -F',' '{sum += $3} END {print sum}' file.csv

demo/oneliner "count unique IPs in access.log"
# $ awk '{print $1}' access.log | sort | uniq -c | sort -rn
```

**[mac-narrator](./demo/mac-narrator)** — your Mac's inner monologue:

```bash
demo/mac-narrator              # one-shot: what's happening right now?
demo/mac-narrator --watch      # continuous narration every 60s
```

Also in `demo/`:

- **[wtd](./demo/wtd)** — "what's this directory?" instant project orientation
- **[explain](./demo/explain)** — explain a command, error, or code snippet
- **[naming](./demo/naming)** — naming suggestions for functions, variables, files
- **[port](./demo/port)** — what's using this port?
- **[gitsum](./demo/gitsum)** — summarize recent git activity

Longer walkthroughs: [docs/demos.md](docs/demos.md).

## MCP Tool Support

Attach [Model Context Protocol](https://modelcontextprotocol.io/) tool servers with `--mcp`. apfel discovers tools, executes them automatically, and returns the final answer. No glue code needed.

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

Ships with a calculator MCP server at [`mcp/calculator/`](./mcp/calculator/). See [docs/mcp-calculator.md](docs/mcp-calculator.md) for details.

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

**Ready-made MCPs.** [apfel-mcp.franzai.com](https://apfel-mcp.franzai.com/) ships three token-budget-optimized MCP servers designed for apfel's 4096-token window: `url-fetch` (Readability article extraction with SSRF guards), `ddg-search` (DuckDuckGo web search, no API key), and the flagship compound `search-and-fetch` tool. Install with `brew install Arthur-Ficial/tap/apfel-mcp`. The repo is open for contributions of new apfel-optimized MCPs — rules at [apfel-mcp.franzai.com/#contribute](https://apfel-mcp.franzai.com/#contribute).

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
| `temperature`, `max_tokens`, `seed` | Supported | Mapped to `GenerationOptions` |
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

## Limitations

| Constraint | Detail |
|------------|--------|
| Context window | **4096 tokens** (input + output combined) |
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-foundationmodel`), not configurable |
| Guardrails | Apple's safety system may block benign prompts. `--permissive` reduces false positives ([docs/PERMISSIVE.md](docs/PERMISSIVE.md)) |
| Speed | On-device, not cloud-scale — a few seconds per response |
| No embeddings / vision | Not available on-device |

## Reference Docs

Guides to use apfel from [Python](docs/guides/python.md), [Node.js](docs/guides/nodejs.md), [Ruby](docs/guides/ruby.md), [PHP](docs/guides/php.md), [Bash/curl](docs/guides/bash-curl.md), [Zsh](docs/guides/zsh.md), [AppleScript](docs/guides/applescript.md), [Swift](docs/guides/swift-scripting.md), [Perl](docs/guides/perl.md), [AWK](docs/guides/awk.md) — see [docs/guides/index.md](docs/guides/index.md). Empirically tested; runnable proof at [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](docs/install.md) — install, troubleshooting, and Apple Intelligence setup
- [docs/cli-reference.md](docs/cli-reference.md) — every flag, exit code, and environment variable
- [docs/background-service.md](docs/background-service.md) — `brew services` and launchd usage
- [docs/openai-api-compatibility.md](docs/openai-api-compatibility.md) — `/v1/*` support matrix in depth
- [docs/server-security.md](docs/server-security.md) — origin checks, CORS, tokens, and `--footgun`
- [docs/context-strategies.md](docs/context-strategies.md) — chat trimming strategies
- [docs/mcp-calculator.md](docs/mcp-calculator.md) — local and remote MCP usage
- [docs/tool-calling-guide.md](docs/tool-calling-guide.md) — detailed tool-calling behavior
- [docs/integrations.md](docs/integrations.md) — third-party tool integrations (opencode, etc.)
- [docs/local-setup-with-vs-code.md](docs/local-setup-with-vs-code.md) — local review with apfel + a second edit/apply model in VS Code
- [docs/demos.md](docs/demos.md) — longer walkthroughs of the shell demos
- [docs/EXAMPLES.md](docs/EXAMPLES.md) — 50+ real prompts with unedited output

## Architecture

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Three targets: `ApfelCore` (pure logic, unit-testable), `apfel` (CLI + server), and `apfel-tests` (pure Swift runner, no XCTest).

## Build & Test

```bash
make install                             # build release + install to /usr/local/bin
make build                               # build release only
make version                             # print current version
make release-minor                       # bump minor: 0.6.x -> 0.7.0
swift build                              # quick debug build (no version bump)
swift run apfel-tests                    # unit tests
python3 -m pytest Tests/integration/ -v  # integration tests
apfel --benchmark -o json                # performance report
```

`.version` is the single source of truth. Only `make release` (via CI) bumps versions. Local builds do not change the version.

## The apfel tree

Everything that grows out of apfel. Each project ships as its own repo, its own landing page, and its own Homebrew formula or cask.

### Trunk

- **apfel** — on-device Apple FoundationModels CLI and OpenAI-compatible server. The root of the tree; every other project uses it for inference.
  - Site: [https://apfel.franzai.com](https://apfel.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel](https://github.com/Arthur-Ficial/apfel)
  - Install: `brew install apfel`

### Apps

- **apfel-chat** — multi-conversation macOS chat client. Streaming markdown, speech I/O, image analysis via Apple Vision. Runs 100% on-device.
  - Site: [https://apfel-chat.franzai.com](https://apfel-chat.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)
  - Install: `brew install Arthur-Ficial/tap/apfel-chat`

- **apfel-clip** — AI clipboard actions from the macOS menu bar. Summarize, translate, rewrite, and reshape whatever you just copied, without leaving the keyboard.
  - Site: [https://apfel-clip.franzai.com](https://apfel-clip.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-clip](https://github.com/Arthur-Ficial/apfel-clip)
  - Install: `brew install Arthur-Ficial/tap/apfel-clip`

- **apfel-quick** — instant AI overlay for macOS. Press a key, ask anything, get an on-device answer — then dismiss.
  - Site: [https://apfel-quick.franzai.com](https://apfel-quick.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-quick](https://github.com/Arthur-Ficial/apfel-quick)
  - Install: `brew install Arthur-Ficial/tap/apfel-quick`

- **apfelpad** — a formula notepad for thinking. On-device AI as a first-class function you can call inline from cells, the way a spreadsheet treats `SUM`.
  - Site: [https://apfelpad.franzai.com](https://apfelpad.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfelpad](https://github.com/Arthur-Ficial/apfelpad)
  - Install: `brew install Arthur-Ficial/tap/apfelpad`

### Extensions

- **apfel-mcp** — three token-budget-optimized MCP servers for apfel's 4096-token context window: `url-fetch` (Readability article extraction with SSRF guards), `ddg-search` (DuckDuckGo web search, no API key), and the flagship compound `search-and-fetch` tool. Open for contributions of more apfel-optimized MCPs.
  - Site: [https://apfel-mcp.franzai.com](https://apfel-mcp.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp)
  - Install: `brew install Arthur-Ficial/tap/apfel-mcp`

- **apfel-gui** — native SwiftUI debug inspector for apfel with request timeline, MCP protocol viewer, chat, and TTS/STT. Built for developers who want to watch exactly what apfel sends to the model.
  - Repo: [https://github.com/Arthur-Ficial/apfel-gui](https://github.com/Arthur-Ficial/apfel-gui)
  - Install: `brew install Arthur-Ficial/tap/apfel-gui`

## Community Projects

Built something on top of apfel? Open an issue and it can be added here.

- [https://apfelclaw.yamanlabs.com/](https://apfelclaw.yamanlabs.com/), [https://github.com/julianyaman/apfelclaw](https://github.com/julianyaman/apfelclaw), by [https://github.com/julianYaman](https://github.com/julianYaman) — local AI agent that reads files, calendar, mail, and Mac status via read-only tools
- [https://github.com/bhaskarvilles/fruit-chat](https://github.com/bhaskarvilles/fruit-chat), by [https://github.com/bhaskarvilles](https://github.com/bhaskarvilles) — "Apple Intelligence in your browser" — browser-based chat UI that talks to `apfel --serve` over the OpenAI-compatible API
- [https://github.com/lucaspwo/local-claude](https://github.com/lucaspwo/local-claude), by [https://github.com/lucaspwo](https://github.com/lucaspwo) — Claude Code wrapper that swaps in apfel as a local backend via a small Anthropic↔OpenAI proxy; keeps cloud claude untouched
- [apfeller](https://github.com/hasit/apfeller), by [hasit](https://github.com/hasit) - [apfeller](https://hasit.github.io/apfeller/) is a small app manager for local shell apps built around apfel. Install the manager once, browse the published [Catalog](https://hasit.github.io/apfeller/catalog/), and install only the apps you want. New apps are welcome at [apfeller-apps](https://github.com/hasit/apfeller-apps).

## Contributing

Bug reports, feature ideas, pull requests, and new community projects all welcome. Open an issue or a PR on the relevant repo.

**#agentswelcome** — AI agent contributions are welcome across the entire apfel tree — apfel itself and every `Arthur-Ficial/apfel-*` repo. Claude Code, Codex, Cursor, Aider, any autonomous coding agent: if you can read the repo's `CLAUDE.md`, run the tests, and open a pull request, you can contribute. Credit your tool in the commit trailer (e.g. `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`), include a passing test suite, and submit. Humans and agents are reviewed on the same bar: clean code, passing tests, honesty about limits.

The most agent-friendly entry point is [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) — its contribution rules and idea list at [apfel-mcp.franzai.com/#contribute](https://apfel-mcp.franzai.com/#contribute) are written to be unambiguous enough for an agent to follow without human translation.

## License

[MIT](LICENSE)
