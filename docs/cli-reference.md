# CLI Reference

`apfel` has four primary modes: single prompt, `--stream`, `--chat`, and `--serve`. This page is the full flag, exit-code, and environment reference for the installed CLI.

## Modes

```text
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
  apfel --mcp-token <token> <prompt>      Bearer token for remote MCP servers
  apfel --mcp-timeout <n> <prompt>        MCP timeout in seconds [default: 5]

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
  --context-status                        Print chat context fill at startup and after each turn

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

## Examples By Flag

```bash
# -f, --file - attach file content to prompt (repeatable)
apfel -f main.swift "Explain this code"
apfel -f before.txt -f after.txt "What changed?"

# -s, --system - set a system prompt
apfel -s "You are a pirate" "What is recursion?"
apfel -s "Reply in JSON only" "List 3 colors"

# --system-file - read system prompt from a file
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

# --permissive
apfel --permissive "Write a villain monologue"
apfel --permissive -f long-document.md "Summarize this"

# --retry
apfel --retry "What is 2+2?"

# --debug
apfel --debug "Hello world"
apfel --serve --debug

# --stream
apfel --stream "Write a haiku about code"

# --chat
apfel --chat
apfel --chat -s "You are a helpful coding assistant"

# --chat slash commands (only in interactive chat mode)
# /clear    — erase the terminal screen; conversation context is kept
# /new      — erase screen + reset to a completely fresh session (model forgets everything)
# /context  — print current context-window usage
# /cmd      — natural language to shell command
# /oneliner — complex pipe chains from plain English
# /naming   — naming suggestions for functions, variables, files
# /explain  — explain a command, error, or code snippet
# /wtd      — "what is this directory?"
# /port     — what process is using this port?
# /process  — identify a process by PID
# /daemon   — explain a macOS daemon or system service
# /docs-apple — Apple developer documentation + code helper
# /mdn      — search MDN Web Docs (HTML, CSS, JavaScript, Web APIs)
#
# Slash commands dispatch to built-in scripts instantly (no model load).
# Bare words (without /) always go to the LLM.
#
# Quoting: the slash command parser joins non-flag words into one query
# string. Double quotes group multi-word queries and are stripped before
# dispatch; single quotes are preserved for shell snippets. These are equivalent:
#   you› /docs-apple SwiftUI Button
#   you› /docs-apple "SwiftUI Button"
#   you› /docs-apple --3000 SwiftData
#   you› /docs-apple --1000 explain "SwiftData"
#   you› /docs-apple --3000 Foundation Models overview
#   you› /docs-apple --no-sosumi SwiftUI Button
#   you› /docs-apple --1000 --no-sosumi "explain NetworkExtension in a few sentences"
#   you› /explain awk -F: '{print $1}' /etc/passwd
#   you› /explain "awk -F: '{print $1}' /etc/passwd"
#
# Numeric flags like --1000, --2000, --3000 set the approximate
# docs-context token budget for /docs-apple before apfel sees it.
# --no-sosumi forces native Apple DocC fetching/parsing even when sosumi exists.
#
# Explicit @keyword syntax: prefix any word with @ to force it
# as the exact Apple docs search/fetch term. Bypasses all auto-detection.
# @ has no special shell meaning — works unquoted in terminal and chat.
#   you› /docs-apple @CoreData
#   you› /docs-apple @SwiftUI @NavigationSplitView
#   you› /docs-apple explain @NetworkExtension in a few sentences
#
# /mdn: search MDN Web Docs for HTML, CSS, JavaScript, and Web API documentation.
# Numeric flags (--1000, --2000, --3000) set the result character budget.
# @keyword forces an exact MDN search term. Default budget is 1000 chars.
#   you› /mdn CSS flexbox
#   you› /mdn @flexbox
#   you› /mdn --2000 Array.prototype.map
#   you› /mdn --3000 @closures
#   you› /mdn @fetch @API
#
# Quotes and punctuation are stripped before framework/symbol detection
# when <keyword> tags are not used.
#
# Flags (-c, -x) are parsed separately but blocked in chat mode.
# Run those directly:  apfel docs-apple -c Combine Publisher
#
# Examples inside a session:
#   you› /port 3000
#   you› /explain awk -F: '{print $1}' /etc/passwd
#   you› /docs-apple SwiftUI Button
#   you› /context
#   you› /clear
#   you› /new

# --context-strategy
apfel --chat --context-strategy newest-first
apfel --chat --context-strategy sliding-window --context-max-turns 6
apfel --chat --context-strategy summarize
apfel --chat --context-output-reserve 256
apfel --chat --context-status
# --context-status uses the input budget: 4096 minus --context-output-reserve.
# Inside chat: /context prints "XXX / XXX tokens context window" on demand.

# --serve
apfel --serve
apfel --serve --port 3000 --host 0.0.0.0

# --cors, --token, --footgun
apfel --serve --cors
apfel --serve --token "my-secret-token"
apfel --serve --footgun

# --token-auto, --public-health
apfel --serve --token-auto --host 0.0.0.0 --public-health

# --allowed-origins, --no-origin-check
apfel --serve --allowed-origins "https://myapp.com,https://staging.myapp.com"
apfel --serve --no-origin-check

# --max-concurrent
apfel --serve --max-concurrent 2

# --benchmark, --model-info, --update, --release, --version, --help
apfel --benchmark -o json | jq '.benchmarks[] | {name, speedup_ratio}'
apfel --model-info
apfel --update
apfel --release
apfel --version
apfel --help
```

Security details live in [server-security.md](server-security.md). Background-service usage lives in [background-service.md](background-service.md).

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Usage error (bad flags) |
| 3 | Guardrail blocked |
| 4 | Context overflow |
| 5 | Model unavailable |
| 6 | Rate limited |

## Environment Variables

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
| `APFEL_MCP` | MCP server paths - colon-separated for local paths, comma-separated for mixed local+remote URLs |
| `APFEL_MCP_TOKEN` | Bearer token for remote HTTP MCP servers (preferred over `--mcp-token`; not visible in `ps aux`) |
| `APFEL_MCP_TIMEOUT` | MCP timeout in seconds (default: 5, max: 300) |
| `NO_COLOR` | Disable colors ([https://no-color.org](https://no-color.org)) |
