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
  apfel --batch < records.jsonl           JSONL records in, one JSON result line per record out

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
  --require-complete                      Exit 8 if the response was truncated (finish_reason=length); no stdout unless streaming
  --schema <path>                         Constrain output to a JSON Schema file (guaranteed valid JSON)

MODEL
  --temperature <n>                       Sampling temperature (e.g., 0.7); 0 = deterministic
  --top-p <n>                             Nucleus sampling threshold in (0, 1] (e.g., 0.9)
  --seed <n>                              Random seed for reproducibility
  --max-tokens <n>                        Maximum response tokens
  --permissive                            Relaxed guardrails (reduces false positives)
  --stop <text>                           End the output before <text> (repeatable, max 4; plain text only)
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

# --schema - guaranteed schema-valid JSON output (one-shot prompt, --messages or --batch)
# Local $ref/$defs, minimum/maximum and minItems/maxItems are honoured; a keyword the
# on-device model cannot enforce exits 2 naming it and its JSON pointer (see
# docs/openai-api-compatibility.md, "JSON Schema support")
apfel --schema person.schema.json "Extract the person: Alice is 30 years old."
apfel --schema invoice.schema.json -f invoice.txt "Extract the invoice data" | jq .total
apfel --schema order.schema.json "Extract the order: ship two notebooks to 12 Main Street, Vienna."

# --stream --schema - the same JSON, printed as it is generated (keys in declared schema order;
# the streamed bytes equal the buffered output)
apfel --stream --schema poem.schema.json "Write a four-line poem about the sea with a title."

# --code - only the code, no prose, no fences (pipe-safe)
apfel --code "a python function that deduplicates a list" > dedupe.py
apfel --code "shell one-liner to find the 10 largest files here" | pbcopy

# --require-complete - exit 8 instead of printing a truncated response
apfel --require-complete --code --max-tokens 128 "Write a small Python CSV reader." > reader.py

# --batch - one JSON result line per JSONL record, fresh session per record
jq -c '{custom_id:(.id|tostring),prompt:("Classify this ticket as billing, bug, or question: " + .text)}' tickets.jsonl \
  | apfel --batch | jq -c 'select(.status=="ok") | {id:.custom_id,category:.content}'

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

# --stop (repeatable; the delimiter and everything after it are not printed)
apfel --stop "5" "Count from 1 to 10, separated by spaces"
apfel --stream --stop $'\nObservation' "Write one short action, then a line beginning Observation."

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
| 1 | Runtime error (`--batch`: at least one record failed) |
| 2 | Usage error (bad flags; also `--require-complete` or `--batch` with `--max-tokens` below macOS 26.4) |
| 3 | Guardrail blocked |
| 4 | Context overflow |
| 5 | Model unavailable |
| 6 | Rate limited |
| 7 | No code in response (`--code` got an empty response or an empty code block) |
| 8 | Incomplete response (`--require-complete` saw `finish_reason=length`) |
| 130 | Interrupted (Ctrl-C at chat prompt or during `--batch`) |
| 141 | stdout was closed by its reader (`... \| head -1`) |

### Requiring a complete response (`--require-complete`)

By default a response that hits the token cap or the context window is still printed and apfel exits 0 with a stderr warning. Scripts that need the whole artifact (generated config, migrations, code) can opt in to a failure instead:

```bash
if result=$(apfel --require-complete --code --max-tokens 128 'Write a small Python CSV reader.'); then
  printf '%s\n' "$result"
fi
```

- Works with a single prompt, `--stream`, `--messages` and `--code`. Combining it with `--chat`, `--serve`, `--count-tokens`, `--schema` or MCP tools (`--mcp` / `APFEL_MCP`) is a usage error (exit 2): those paths do not report a finish reason apfel could check.
- An explicit output cap (`--max-tokens` or `APFEL_MAX_TOKENS`) needs the on-device tokenizer API (macOS 26.4+) to be detected exactly. Below 26.4 token counts are only estimated, so `--require-complete --max-tokens N` is refused before generating (exit 2) with a message naming the macOS version. Drop `--max-tokens` or update macOS. Without an explicit cap the flag works on every macOS 26 and 27, because a context-window cut-off is reported exactly.
- Non-streaming (including `-o json` and `--code`): a length finish writes nothing to stdout and exits 8. `--quiet` does not change the exit code.
- `--stream`: tokens already printed cannot be taken back; the exit code 8 is the contract.
- `-o json` always carries `finish_reason` (`"stop"` or `"length"`) next to `content`, with or without the flag. `--schema` output omits it, and so does a run with an explicit `--max-tokens` cap on macOS older than 26.4, where apfel can only estimate whether the cap cut the response (stderr says so). A missing key means unknown, never a guess.
- A matched `--stop` sequence ends the answer with `finish_reason=stop`, so it is complete (exit 0). The match is observed, not estimated, so `-o json` reports `"stop"` for it on every macOS, also with an explicit `--max-tokens` cap below 26.4. `--require-complete --max-tokens N --stop X` is still refused below 26.4, because a run that never reaches the delimiter could not be judged.
- Completion only means the engine stopped on its own. It is not a correctness check: a naturally finished answer can still be wrong or syntactically incomplete.

When apfel runs inside a pipeline, the shell reports the exit status of the last command, so turn on `pipefail` to see exit 8:

```bash
set -o pipefail
apfel --require-complete 'List ten Unix commands.' | tee commands.txt
```

### Processing JSONL records (`--batch`)

`--batch` turns apfel into a record processor for local datasets: JSONL in on stdin, one compact JSON result line per record out on stdout. Records are processed serially, in input order, and each result is written as soon as its record is done, before the rest of the input arrives. One process and one loaded model serve the whole run; every record gets a fresh session, so nothing from one record (its prompt, its answer) reaches another; only the flags you pass, such as `-s`, are shared.

Input: one JSON object per line.

```json
{"custom_id": "101", "prompt": "Classify this ticket as billing, bug, or question: I was charged twice."}
{"custom_id": "102", "messages": [{"role": "system", "content": "Answer in one word."}, {"role": "user", "content": "What color is a ripe banana?"}]}
```

- `custom_id` (string, required, non-empty) is echoed back. It need not be unique: `line` tells repeated ids apart. With `jq`, turn a numeric id into a string with `(.id|tostring)`.
- Exactly one of `prompt` (non-empty string) or `messages` (an OpenAI messages array, same rules as `--messages`). Any other field is an `invalid_record` error, not silently ignored; use `-s` for a system prompt.
- UTF-8, one record per line, LF or CRLF. Newlines inside a prompt are JSON-escaped (`\n`). Blank lines are skipped. A final line without a newline is still a record. A record line may be at most 1048576 bytes.
- `-s`/`--system`/`--system-file`, `--schema`, `--stop`, `--temperature`, `--top-p`, `--seed`, `--max-tokens`, `--permissive`, `--retry` and the context flags apply to every record.

Output: one line per non-blank input line, always with all seven keys in this order.

```json
{"line":1,"custom_id":"101","status":"ok","content":"billing","finish_reason":"stop","partial_content":null,"error":null}
{"line":2,"custom_id":null,"status":"error","content":null,"finish_reason":null,"partial_content":null,"error":{"type":"invalid_record","message":"record is not valid JSON","exit_code":2}}
{"line":3,"custom_id":"103","status":"incomplete","content":null,"finish_reason":"length","partial_content":"### The Multi","error":{"type":"incomplete","message":"incomplete response (finish_reason=length): the --max-tokens 5 cap was reached; the partial text is in partial_content","exit_code":8}}
```

| Key | Meaning |
|-----|---------|
| `line` | 1-based input line number (blank lines count) |
| `custom_id` | echoed id, `null` when the line had no readable `custom_id` |
| `status` | `ok`, `error`, or `incomplete` (`finish_reason=length`) |
| `content` | the answer; `null` unless `status` is `ok`. With `--schema` it is the JSON document as a string (`.content \| fromjson`) |
| `finish_reason` | `stop` or `length`; `null` for `--schema` records (schema-constrained output reports none) |
| `partial_content` | the cut-off text of an `incomplete` record, else `null` |
| `error` | `null`, or `{"type", "message", "exit_code"}`; `type` is `invalid_record`, `incomplete`, or the OpenAI error type of a model error (`content_policy_violation`, `context_length_exceeded`, ...), and `exit_code` is what the same failure exits with as a one-shot run |

A failed record never stops the batch. apfel exits 0 when every record is `ok` (or there were none) and 1 when any record failed (`error` or `incomplete`); a one-line summary goes to stderr unless `--quiet`. Invocation errors exit 2 before anything is read: a positional prompt, `-f`, `--messages`, `-o`, `--code`, `--require-complete`, MCP tools (`--mcp` / `APFEL_MCP`), another mode, or a terminal on stdin. An explicit output cap (`--max-tokens` or `APFEL_MAX_TOKENS`) on macOS older than 26.4 is also refused with exit 2: without the on-device tokenizer API the cap cannot be detected, so a cut-off record would read as `ok`. Without an explicit cap `--batch` works on every macOS 26 and 27, because a context-window cut-off is reported exactly. With Apple Intelligence unavailable apfel exits 5 before reading. Ctrl-C exits 130 and a closed stdout exits 141; every line already written is a complete record.

Memory does not grow with the number of records: apfel holds at most one record plus one 64 KiB read chunk, and writes each result before reading more input, so a slow consumer pauses intake instead of filling memory. Use `pipefail` to keep the batch exit status through a downstream `jq`:

```bash
set -o pipefail
apfel --batch < records.jsonl | jq -c 'select(.status=="ok")' > ok.jsonl
```

Records are independent questions. One document larger than the context window is not split across records; that is the job of file ingestion, not `--batch`. Concurrency is not implemented: records run one at a time.

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
