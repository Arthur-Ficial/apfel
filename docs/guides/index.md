# Use Apple's Foundation Model from Any Scripting Language

apfel exposes Apple's on-device **Foundation Model** over a local OpenAI-compatible HTTP server. Any language that can `POST` JSON to `http://localhost:11434/v1/chat/completions` can use it - **100% on-device, zero API cost, no network required for inference**.

These guides show how, in the idioms each language uses. Every code block was run against a live `apfel --serve` before publishing.

## Guides

| Language | Guide | Typical user |
|----------|-------|--------------|
| Python | [python.md](python.md) | AI/ML scripts, data tools, backends |
| Node.js (JavaScript / TypeScript) | [nodejs.md](nodejs.md) | Web tools, CLI apps, desktop |
| Ruby | [ruby.md](ruby.md) | Rails integrations, scripting |
| PHP | [php.md](php.md) | Web apps, WordPress plugins |
| Bash / curl | [bash-curl.md](bash-curl.md) | CI pipelines, one-liners, quick tests |
| Zsh | [zsh.md](zsh.md) | Default macOS shell scripts |
| AppleScript | [applescript.md](applescript.md) | Shortcuts, Automator, system automation |
| Swift scripting | [swift-scripting.md](swift-scripting.md) | Native macOS scripting with URLSession |
| Perl | [perl.md](perl.md) | Text pipelines (ships with macOS) |
| AWK | [awk.md](awk.md) | Log/text processing with curl |

## What you need

1. **macOS 26+ Tahoe** on Apple Silicon
2. **Apple Intelligence enabled** (`System Settings -> Apple Intelligence & Siri`)
3. `brew install apfel`
4. `apfel --serve` running in a terminal (default port `11434`)

## Verify with curl

```bash
apfel --serve &
curl -s http://localhost:11434/health
# {"status":"ok"}
```

If `/health` responds, you're ready. Pick your language and follow the guide.

## Honest limits (same for all languages)

- **Context window:** 4096 tokens on macOS 26 and on M1/M2 Macs, 8192 on macOS 27 with an M3 or newer chip and 12 GB+ (Apple's AFM 3 Core Advanced model) (read at runtime; `apfel --model-info` prints the live value)
- **Embeddings:** not supported (returns HTTP 501 - see each guide's error-handling section)
- **Vision / audio:** not supported
- **JSON mode:** supported via `response_format: {type: "json_object"}` - occasionally wrapped in markdown fences, so the guides show a one-line fence-strip pattern
- **Streaming:** supported via `stream: true`
- **Tool calling:** supported via OpenAI `tools` parameter

## See the tests that produced these guides

Every guide links to its exact test script and captured output on [Arthur-Ficial/apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab). If you want to rerun them on your own Mac:

```bash
git clone https://github.com/Arthur-Ficial/apfel-guides-lab
cd apfel-guides-lab
apfel --serve &
python3 -m pytest -v
```
