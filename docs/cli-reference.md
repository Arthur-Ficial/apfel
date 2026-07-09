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
  apfel --count-tokens <prompt>           Preflight token count (no inference)

INPUT
  apfel -f, --file <path> <prompt>        Attach file content (repeatable)
  apfel -s, --system <text> <prompt>      Set system prompt
  apfel --system-file <path> <prompt>     Read system prompt from file
  apfel --mcp <path|url> <prompt>         Attach local or remote MCP tool server (repeatable)
  apfel --mcp-token <token> <prompt>      Bearer token for remote MCP servers
  apfel --mcp-timeout <n> <prompt>        MCP timeout in seconds [default: 5]
  apfel --messages <path|->               One-shot multi-turn from OpenAI messages JSON (file or stdin)

OUTPUT
  -o, --output <fmt>                      Output format: plain, json
  -q, --quiet                             Suppress non-essential output
  --no-color                              Disable ANSI colors
  --code                                  Print only the code: first fenced block, or the bare response (exit 7 if empty)
  --schema <path>                         Constrain output to a JSON Schema file (guaranteed valid JSON)

MODEL
  --temperature <n>                       Sampling temperature (e.g., 0.7); 0 = deterministic
  --top-p <n>                             Nucleus sampling threshold in (0, 1] (e.g., 0.9)
  --seed <n>                              Random seed for reproducibility
  --max-tokens <n>                        Maximum response tokens
  --permissive                            Relaxed guardrails (reduces false positives)
  --retry [n]                             Retry transient errors with backoff (default: 3)
  --debug                                 Enable debug logging to stderr (all modes)
  --count-tokens                          Count tokens without calling the model
  --strict                                With --count-tokens: exit 4 if over budget

CONTEXT (--chat)
  --context-strategy <s>                  newest-first, oldest-first, sliding-window, summarize, strict
  --context-max-turns <n>                 Max history turns (sliding-window only)
  --context-output-reserve <n>            Tokens reserved for output (default: 512)
  --context-status                        Print chat context fill after each turn

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
  --demos [dir]                           Write bundled demo scripts to dir [default: ./apfel-demos]

SUBCOMMANDS
  apfel completions <shell>               Print shell completions (bash, zsh, fish)
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

# --schema - guaranteed schema-valid JSON output (single-prompt mode only)
apfel --schema person.schema.json "Extract the person: Alice is 30 years old."
apfel --schema invoice.schema.json -f invoice.txt "Extract the invoice data" | jq .total

# --code - only the code, no prose, no fences (pipe-safe)
apfel --code "a python function that deduplicates a list" > dedupe.py
apfel --code "shell one-liner to find the 10 largest files here" | pbcopy

# --messages - one-shot multi-turn: conversation JSON in, next assistant turn out
apfel --messages conversation.json
jq '. += [{"role":"user","content":"and in German?"}]' conv.json | apfel --messages -

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

# --top-p
apfel --top-p 0.9 "Write a short poem"

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

# --count-tokens, --strict
apfel --count-tokens -f README.md "Summarize this"
apfel --count-tokens -o json "hello" | jq .
apfel --count-tokens --strict -f large-file.txt "process"
# Counts use the on-device tokenizer API (macOS 26.4+). When it is unusable
# (older macOS, or Apple Intelligence off), counts are a chars/4 approximation:
# a stderr warning names the reason and JSON output carries "approximate": true.

# --stream
apfel --stream "Write a haiku about code"

# --chat
apfel --chat
apfel --chat -s "You are a helpful coding assistant"

# --chat with persistent history across sessions (opt-in, off by default)
APFEL_HISTFILE=~/.apfel_history apfel --chat

# --context-strategy
apfel --chat --context-strategy newest-first
apfel --chat --context-strategy sliding-window --context-max-turns 6
apfel --chat --context-strategy summarize
apfel --chat --context-output-reserve 256
apfel --chat --context-status

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

# --demos: write the bundled demo scripts out (works on every install channel)
apfel demos ./apfel-demos
apfel --demos ./apfel-demos
```

Security details live in [server-security.md](server-security.md). Background-service usage lives in [background-service.md](background-service.md).

## Shell Completions

`apfel completions <shell>` prints a completion script to stdout for `bash`, `zsh`, or `fish`. Homebrew installs them automatically. To enable them for a source/manual install, write the script to your shell's completion directory.

bash:

```bash
apfel completions bash | sudo tee "$(brew --prefix)/etc/bash_completion.d/apfel" >/dev/null
```

zsh (a directory already on your `$fpath`):

```bash
apfel completions zsh > "${fpath[1]}/_apfel"
```

fish:

```fish
apfel completions fish > ~/.config/fish/completions/apfel.fish
```

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
| 130 | Interrupted (Ctrl-C at chat prompt) |

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
| `APFEL_DEBUG` | Enable debug logging (same as `--debug`) |
| `APFEL_HISTFILE` | Persist `--chat` line-editing history to this file across sessions (off by default; bounded to 500 entries, mode 0600) |
| `NO_COLOR` | Disable colors ([https://no-color.org](https://no-color.org)) |
