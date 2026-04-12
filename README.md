# apfel

[![Version 0.9.15](https://img.shields.io/badge/version-0.9.15-blue)](https://github.com/Arthur-Ficial/apfel)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](#contributing)

Use the free local Apple Intelligence LLM on your Mac as a UNIX tool, an OpenAI-compatible server, and a command-line chat client. No API keys, no cloud, no subscriptions, no per-token billing.

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
brew tap Arthur-Ficial/tap
brew install apfel
brew upgrade apfel
```

**Build from source:**

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install
```

Update with `brew upgrade apfel` or `apfel --update`.

Troubleshooting, alternative install methods, and Apple Intelligence setup notes: [docs/install.md](docs/install.md)

## Quick Start

### UNIX tool

Shell note: if your prompt contains `!`, prefer single quotes in `zsh` or `bash` so history expansion does not break copy-paste.

```bash
apfel "What is the capital of Austria?"
apfel --permissive "Write a dramatic opening for a thriller novel"
apfel --stream "Write a haiku about code"
echo "Summarize: $(cat README.md)" | apfel
apfel -f README.md "Summarize this project"
apfel -f old.swift -f new.swift "What changed between these two files?"
apfel -o json "Translate to German: hello" | jq .content
apfel -s "You are a pirate" "What is recursion?"
```

More on `--system-file`, quiet mode, retries, exit codes, and environment variables: [docs/cli-reference.md](docs/cli-reference.md)

### OpenAI-compatible server

```bash
apfel --serve
brew services start apfel
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

Background operation, service configuration, and security settings: [docs/background-service.md](docs/background-service.md), [docs/openai-api-compatibility.md](docs/openai-api-compatibility.md), [docs/server-security.md](docs/server-security.md)

### Command-line chat

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py
apfel --chat --debug
```

Ctrl-C exits cleanly. Context rotation, history trimming, and output reserves: [docs/context-strategies.md](docs/context-strategies.md)

## MCP Tool Support

Attach [https://modelcontextprotocol.io/](https://modelcontextprotocol.io/) servers with `--mcp`. `apfel` discovers tools, executes them automatically, and returns the final answer.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
```

`mcp/calculator/` ships with the repo. Remote `https://` MCP servers, bearer-token handling, timeout tuning, server-mode auto-execution, and protocol details live in [docs/mcp-calculator.md](docs/mcp-calculator.md) and [docs/tool-calling-guide.md](docs/tool-calling-guide.md).

**Want web search and URL fetching?** [apfel-mcp.franzai.com](https://apfel-mcp.franzai.com/) ships three token-budget-optimized MCP servers for apfel's 4096-token context window: `url-fetch` (Readability article extraction with SSRF guards), `ddg-search` (DuckDuckGo web search, no API key), and `search-and-fetch` (the flagship compound tool - search AND fetch the top N pages in ONE tool call). Install with `brew install Arthur-Ficial/tap/apfel-mcp`. The repo is open for contributions of new apfel-optimized MCPs - ideas and rules at [apfel-mcp.franzai.com](https://apfel-mcp.franzai.com/#contribute).

## OpenAI API Compatibility

`apfel` exposes `http://localhost:11434/v1` with `POST /v1/chat/completions`, `GET /v1/models`, `GET /health`, streaming, tool calling, and `response_format: json_object`. Unsupported surfaces such as embeddings, legacy completions, and multimodal inputs return honest `501` or `400` errors. Full compatibility matrix: [docs/openai-api-compatibility.md](docs/openai-api-compatibility.md)

## Demos

- [docs/demos.md](docs/demos.md) - longer walkthroughs for `demo/cmd`, `demo/oneliner`, `demo/mac-narrator`, and the reusable `cmd()` shell function
- [demo/README.md](demo/README.md) - quick overview of every shipped demo
- [demo/wtd](demo/wtd), [demo/explain](demo/explain), [demo/naming](demo/naming), [demo/port](demo/port), and [demo/gitsum](demo/gitsum) cover project orientation, explanation, naming, port inspection, and git summaries

## Limitations

| Constraint | Detail |
|------------|--------|
| Context window | **4096 tokens** (input + output combined) |
| Platform | macOS 26+, Apple Silicon only |
| Model | One model (`apple-foundationmodel`), not configurable |
| Guardrails | Apple's safety system may block benign prompts. `--permissive` reduces false positives: [docs/PERMISSIVE.md](docs/PERMISSIVE.md) |
| Speed | On-device, not cloud-scale |
| No embeddings / vision | Not available on-device |

## Reference Docs

- [docs/install.md](docs/install.md) - install, troubleshooting, and Apple Intelligence setup
- [docs/cli-reference.md](docs/cli-reference.md) - modes, flags, exit codes, and environment variables
- [docs/background-service.md](docs/background-service.md) - `brew services` and launchd usage
- [docs/openai-api-compatibility.md](docs/openai-api-compatibility.md) - `/v1/*` support matrix
- [docs/server-security.md](docs/server-security.md) - origin checks, CORS, tokens, and `--footgun`
- [docs/context-strategies.md](docs/context-strategies.md) - chat trimming strategies
- [docs/mcp-calculator.md](docs/mcp-calculator.md) - local and remote MCP usage
- [docs/tool-calling-guide.md](docs/tool-calling-guide.md) - detailed tool-calling behavior
- [docs/integrations.md](docs/integrations.md) - third-party tool integrations
- [docs/EXAMPLES.md](docs/EXAMPLES.md) - 50+ real prompts with unedited output

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

Every `make build` or `make install` auto-bumps the patch version, updates the README badge, and generates build metadata. `.version` is the single source of truth.

## Integrations

- [docs/integrations.md](docs/integrations.md) - verified configs for tools such as opencode
- [docs/local-setup-with-vs-code.md](docs/local-setup-with-vs-code.md) - local review with `apfel` plus a second edit/apply model in Visual Studio Code

## The apfel tree

Everything that grows out of apfel. Each project ships as its own repo, its own landing page, and its own Homebrew formula or cask.

### Trunk

- **apfel** - on-device Apple FoundationModels CLI and OpenAI-compatible server. The root of the tree; every other project uses it for inference.
  - Site: [https://apfel.franzai.com](https://apfel.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel](https://github.com/Arthur-Ficial/apfel)
  - Install: `brew install Arthur-Ficial/tap/apfel`

### Apps

- **apfel-chat** - multi-conversation macOS chat client. Streaming markdown, speech I/O, image analysis via Apple Vision. Runs 100% on-device.
  - Site: [https://apfel-chat.franzai.com](https://apfel-chat.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)
  - Install: `brew install Arthur-Ficial/tap/apfel-chat`

- **apfel-clip** - AI clipboard actions from the macOS menu bar. Summarize, translate, rewrite, and reshape whatever you just copied, without leaving the keyboard.
  - Site: [https://apfel-clip.franzai.com](https://apfel-clip.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-clip](https://github.com/Arthur-Ficial/apfel-clip)
  - Install: `brew install Arthur-Ficial/tap/apfel-clip`

- **apfel-quick** - instant AI overlay for macOS. Press a key, ask anything, get an on-device answer - then dismiss.
  - Site: [https://apfel-quick.franzai.com](https://apfel-quick.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-quick](https://github.com/Arthur-Ficial/apfel-quick)
  - Install: `brew install Arthur-Ficial/tap/apfel-quick`

- **apfelpad** - a formula notepad for thinking. On-device AI as a first-class function you can call inline from cells, the way a spreadsheet treats `SUM`.
  - Site: [https://apfelpad.franzai.com](https://apfelpad.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfelpad](https://github.com/Arthur-Ficial/apfelpad)
  - Install: `brew install Arthur-Ficial/tap/apfelpad`

### Extensions

- **apfel-mcp** - three token-budget-optimized MCP (Model Context Protocol) servers for apfel's 4096-token context window. `url-fetch` (Readability article extraction with SSRF guards), `ddg-search` (DuckDuckGo web search, no API key), and the flagship compound `search-and-fetch` tool. Open for contributions of more apfel-optimized MCPs.
  - Site: [https://apfel-mcp.franzai.com](https://apfel-mcp.franzai.com)
  - Repo: [https://github.com/Arthur-Ficial/apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp)
  - Install: `brew install Arthur-Ficial/tap/apfel-mcp`

- **apfel-gui** - native SwiftUI debug inspector for apfel with request timeline, MCP protocol viewer, chat, and TTS/STT. Built for developers who want to watch exactly what apfel sends to the model.
  - Repo: [https://github.com/Arthur-Ficial/apfel-gui](https://github.com/Arthur-Ficial/apfel-gui)
  - Install: `brew install Arthur-Ficial/tap/apfel-gui`

## Community Projects

Built something on top of apfel? Open an issue and it can be added here.

- [https://apfelclaw.yamanlabs.com/](https://apfelclaw.yamanlabs.com/), [https://github.com/julianyaman/apfelclaw](https://github.com/julianyaman/apfelclaw), by [https://github.com/julianYaman](https://github.com/julianYaman) - local AI agent that reads files, calendar, mail, and Mac status via read-only tools

## Contributing

Bug reports, feature ideas, pull requests, and new community projects all welcome. Open an issue or a PR on the relevant repo.

**#agentswelcome** - AI agent contributions are welcome across the entire apfel tree - apfel itself and every `Arthur-Ficial/apfel-*` repo. Claude Code, Codex, Cursor, Aider, any autonomous coding agent: if you can read the repo's `CLAUDE.md`, run the tests, and open a pull request, you can contribute. Credit your tool in the commit trailer (e.g. `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`), include a passing test suite, and submit. Humans and agents are reviewed on the same bar: clean code, passing tests, honesty about limits.

The most agent-friendly entry point is [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) - its contribution rules and idea list at [apfel-mcp.franzai.com/#contribute](https://apfel-mcp.franzai.com/#contribute) are written to be unambiguous enough for an agent to follow without human translation.

## Examples

See [docs/EXAMPLES.md](docs/EXAMPLES.md) for 50+ real prompts with unedited model output.

## License

[MIT](LICENSE)
