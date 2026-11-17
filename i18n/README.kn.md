<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> [ಇಂಗ್ಲಿಷ್ README](../README.md) ನಿಂದ ಅನುವಾದಿಸಲಾಗಿದೆ. ಇಂಗ್ಲಿಷ್ ಆವೃತ್ತಿಯೇ ಅಧಿಕೃತ.

# apfel

### ನಿಮ್ಮ Mac ನಲ್ಲಿ ಈಗಾಗಲೇ ಇರುವ ಉಚಿತ AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac ಗಳಲ್ಲಿ [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) ಮೂಲಕ ಅಂತರ್ನಿರ್ಮಿತ LLM ಬರುತ್ತದೆ. `apfel` ಅದನ್ನು UNIX ಟೂಲ್ ಆಗಿ ಮತ್ತು ಸ್ಥಳೀಯ OpenAI-ಹೊಂದಾಣಿಕೆಯ ಸರ್ವರ್ ಆಗಿ ಒದಗಿಸುತ್ತದೆ. 100% ಆನ್-ಡಿವೈಸ್. API ಕೀ ಇಲ್ಲ, ಕ್ಲೌಡ್ ಇಲ್ಲ.

| ಮೋಡ್ | ಕಮಾಂಡ್ | ನಿಮಗೆ ಏನು ಸಿಗುತ್ತದೆ |
|------|---------|--------------|
| UNIX ಟೂಲ್ | `apfel "prompt"` / `echo "text" \| apfel` | ಪೈಪ್-ಸ್ನೇಹಿ ಉತ್ತರಗಳು, ಫೈಲ್ ಅಟ್ಯಾಚ್‌ಮೆಂಟ್, JSON ಔಟ್‌ಪುಟ್, ಎಕ್ಸಿಟ್ ಕೋಡ್ |
| OpenAI-ಹೊಂದಾಣಿಕೆಯ ಸರ್ವರ್ | `apfel --serve` | OpenAI SDK ಗಳಿಗೆ ಸ್ಥಳೀಯ `http://localhost:11434/v1` ಬ್ಯಾಕೆಂಡ್, ನೇರ ಬದಲಿ |

`apfel --chat` - ಇಂಟರ್ಯಾಕ್ಟಿವ್ REPL.

[![apfel ಟರ್ಮಿನಲ್ ಡೆಮೊ ವಿಡಿಯೋ: ನಿಜವಾದ ಕಮಾಂಡ್‌ಗಳು, ಸಾಧನದಲ್ಲೇ ನಿಜವಾದ ಉತ್ತರಗಳು (82 ಸೆಕೆಂಡುಗಳು)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/kn/a/apfel-ai-tutorial/#video)

ಟೂಲ್ ಕಾಲಿಂಗ್ ಎಲ್ಲಾ ಸಂದರ್ಭಗಳಲ್ಲಿ ಕೆಲಸ ಮಾಡುತ್ತದೆ.

![apfel CLI](../screenshots/cli.png)

## ಅಗತ್ಯತೆಗಳು ಮತ್ತು ಇನ್‌ಸ್ಟಾಲ್

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ಆನ್ ಮಾಡಿರಬೇಕು](https://support.apple.com/en-us/121115). macOS 27 ನಲ್ಲಿ, M3 ಅಥವಾ ಹೊಸ ಚಿಪ್ ಮತ್ತು 12 GB+ ಇರುವ Mac ಗಳು Apple ನ ದೊಡ್ಡ ಆನ್-ಡಿವೈಸ್ ಮಾಡೆಲ್ ಅನ್ನು 8192-ಟೋಕನ್ ವಿಂಡೋದೊಂದಿಗೆ ಚಲಾಯಿಸುತ್ತವೆ; M1/M2 Mac ಗಳು ಮತ್ತು macOS 26 ನಲ್ಲಿರುವ ಪ್ರತಿ Mac ನಲ್ಲಿ 4096 ಇರುತ್ತದೆ. `apfel --model-info` ನಿಮ್ಮದನ್ನು ತೋರಿಸುತ್ತದೆ.

```bash
brew install apfel
```

ಅಪ್‌ಡೇಟ್:

```bash
brew upgrade apfel
```

ಸೋರ್ಸ್‌ನಿಂದ ಬಿಲ್ಡ್ ಮಾಡಿ (macOS 27 SDK / Swift 6.3 ಜೊತೆ Command Line Tools, Xcode ಬೇಡ; ಬೈನರಿ macOS 26 ಮತ್ತು 27 ನಲ್ಲಿ ಚಲಿಸುತ್ತದೆ):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, ಟ್ರಬಲ್‌ಶೂಟಿಂಗ್: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | **ಕನ್ನಡ** | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## ತ್ವರಿತ ಪ್ರಾರಂಭ

### UNIX ಟೂಲ್

`!` ಇರುವ prompt ಗಳನ್ನು ಸಿಂಗಲ್ ಕೋಟ್‌ನಲ್ಲಿ ಬರೆಯಿರಿ (zsh/bash ಹಿಸ್ಟರಿ ಎಕ್ಸ್‌ಪ್ಯಾನ್ಷನ್): `apfel 'Hello, Mac!'`.

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

# Attach a PDF or image - on-device text extraction, OCR, and "what the image is about"
apfel -f report.pdf "Summarize the key findings"
apfel -f receipt.jpg "What is the total?"

# Pipe a file straight in (PDF, image, or text)
cat report.pdf | apfel "Summarize this"

# Combine files with piped input
git diff HEAD~1 | apfel -f CONVENTIONS.md "Review this diff against our conventions"

# Only the code - no prose, no markdown fences (pipe-safe, exit 7 if empty)
apfel --code "a python function that deduplicates a list" > dedupe.py
apfel --code "shell one-liner to find the 10 largest files here" | pbcopy

# JSON output for scripting
apfel -o json "Translate to German: hello" | jq .content

# Guaranteed schema-valid JSON output (guided generation)
apfel --schema person.schema.json "Extract the person: Alice is 30." | jq .name

# One-shot multi-turn: conversation JSON in, next assistant turn out
jq '. += [{"role":"user","content":"and in German?"}]' conv.json | apfel --messages -

# Batch: JSONL records in, one JSON result line per record out (fresh session each)
jq -c '{custom_id:(.id|tostring),prompt:("Classify as billing, bug, or question: " + .text)}' tickets.jsonl \
  | apfel --batch | jq -c 'select(.status=="ok") | {id:.custom_id,category:.content}'

# Preflight token budget before a large prompt
apfel --count-tokens -f README.md "Summarize this"

# System prompt
apfel -s "You are a pirate" "What is recursion?"

# System prompt from file
apfel --system-file persona.txt "Explain TCP/IP"

# Quiet mode for shell scripts
result=$(apfel -q "Capital of France? One word.")
```

### OpenAI-ಹೊಂದಾಣಿಕೆಯ ಸರ್ವರ್

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

ಬ್ಯಾಕ್‌ಗ್ರೌಂಡ್ ಸರ್ವೀಸ್ ವಿವರಗಳು: [docs/background-service.md](../docs/background-service.md).

### ತ್ವರಿತ ಟೆಸ್ಟಿಂಗ್ ಚಾಟ್

`apfel --chat` prompt ಗಳನ್ನು ಅಥವಾ MCP ಸರ್ವರ್‌ಗಳನ್ನು ಪರೀಕ್ಷಿಸಲು ಒಂದು ಸಣ್ಣ REPL. GUI ಚಾಟ್ ಆ್ಯಪ್‌ಗಾಗಿ [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) ನೋಡಿ.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C ಮೂಲಕ ನಿರ್ಗಮಿಸಬಹುದು. ಕಾಂಟೆಕ್ಸ್ಟ್ ತಾನಾಗಿಯೇ ಟ್ರಿಮ್ ಆಗುತ್ತದೆ ([docs/context-strategies.md](../docs/context-strategies.md)).

ಇದರ ವಿರುದ್ಧ ಸ್ಕ್ರಿಪ್ಟ್ ಬರೆಯುವ ಮೊದಲು ತಿಳಿದಿರಬೇಕಾದ ಮಿತಿಗಳು (ಪ್ರತಿ Mac ಗೆ ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋ, ಗಾರ್ಡ್‌ರೇಲ್‌ಗಳು, ಎಂಬೆಡಿಂಗ್ ಇಲ್ಲ): [ಮಿತಿಗಳು](../README.md#limitations).

## ಡೆಮೊಗಳು

`apfel` ಅನ್ನು ಸುತ್ತುವರಿದ ನಿಜವಾದ ಶೆಲ್ ಸ್ಕ್ರಿಪ್ಟ್‌ಗಳು: `cmd` (ಇಂಗ್ಲಿಷ್‌ನಿಂದ ಶೆಲ್ ಕಮಾಂಡ್), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. ಅವು ಬೈನರಿಯಲ್ಲೇ ಸೇರಿವೆ - ರೆಪೊ ಕ್ಲೋನ್ ಮಾಡುವ ಅಗತ್ಯವಿಲ್ಲ. ನೀವು apfel ಅನ್ನು ಎಲ್ಲಿಂದ ಇನ್‌ಸ್ಟಾಲ್ ಮಾಡಿದ್ದೀರೋ (homebrew-core, tap, ಅಥವಾ ಸೋರ್ಸ್) ಅಲ್ಲಿಂದ ಬೇಕಾದ ಸ್ಥಳಕ್ಕೆ ಬರೆಯಿರಿ:

```bash
apfel demos ./apfel-demos
```

ಇದು ಪ್ರತಿ ಡೆಮೊ (ಎಕ್ಸಿಕ್ಯೂಟಬಲ್) ಮತ್ತು ಒಂದು `README.md` ಅನ್ನು `./apfel-demos` ಗೆ ಬರೆಯುತ್ತದೆ. ನಂತರ ಅಲ್ಲಿಂದ ಚಲಾಯಿಸಿ:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

ರಿಫ್ರೆಶ್ ಮಾಡಲು `brew upgrade apfel` ನಂತರ ಮತ್ತೆ `apfel demos` ಚಲಾಯಿಸಿ. ಸೋರ್ಸ್: [`demo/`](../demo/). ವಾಕ್‌ಥ್ರೂಗಳು ಮತ್ತು ನಿಮ್ಮ `.zshrc` ಗಾಗಿ ಕಾಪಿ-ಪೇಸ್ಟ್ `cmd` ಶೆಲ್ ಫಂಕ್ಷನ್: [docs/demos.md](../docs/demos.md).

## MCP ಟೂಲ್ ಬೆಂಬಲ

`--mcp` ಮೂಲಕ [Model Context Protocol](https://modelcontextprotocol.io/) ಸರ್ವರ್‌ಗಳನ್ನು ಜೋಡಿಸಿ. apfel ಹುಡುಕುತ್ತದೆ, ಚಲಾಯಿಸುತ್ತದೆ ಮತ್ತು ಫಲಿತಾಂಶವನ್ನು ಹಿಂತಿರುಗಿಸುತ್ತದೆ.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

ಟೂಲ್ ಮಾಹಿತಿಯನ್ನು ಅಡಗಿಸಲು `-q` ಬಳಸಿ.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

[`mcp/calculator/`](../mcp/calculator/) ನಲ್ಲಿ ಒಂದು ಕ್ಯಾಲ್ಕುಲೇಟರ್‌ನೊಂದಿಗೆ ಬರುತ್ತದೆ ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**ರಿಮೋಟ್ MCP ಸರ್ವರ್‌ಗಳು** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **ಭದ್ರತೆ:** `--mcp-token` (ps aux) ಗಿಂತ `APFEL_MCP_TOKEN` ಬಳಸಿ. apfel ಸರಳ `http://` ಮೇಲೆ bearer token ಕಳುಹಿಸಲು ನಿರಾಕರಿಸುತ್ತದೆ.

## apfel-run: ಐಚ್ಛಿಕ ಕಾನ್ಫಿಗ್ ಪದರ

apfel ಗೆ ತನ್ನದೇ ಕಾನ್ಫಿಗ್ ಫೈಲ್ ಇಲ್ಲ - ಫ್ಲ್ಯಾಗ್‌ಗಳು + env ವೇರಿಯಬಲ್‌ಗಳು, ಯಾವುದೇ UNIX ಟೂಲ್‌ನಂತೆ. ನಿಮಗೆ TOML ಕಾನ್ಫಿಗ್ ಬೇಕಿದ್ದರೆ (ಹಲವು MCP, ಪ್ರೊಫೈಲ್‌ಗಳು, git ನಲ್ಲಿ ತಂಡದ ಕಾನ್ಫಿಗ್), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) ಒಂದು MIT ರ‍್ಯಾಪರ್ ಆಗಿದ್ದು `execve` ಡ್ರಾಪ್-ಇನ್ ಮೂಲಕ ಅದನ್ನು ಸೇರಿಸುತ್ತದೆ.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API ಹೊಂದಾಣಿಕೆ

**ಬೇಸ್ URL:** `http://localhost:11434/v1`

| ವೈಶಿಷ್ಟ್ಯ | ಸ್ಥಿತಿ | ಟಿಪ್ಪಣಿ |
|---------|--------|-------|
| `POST /v1/chat/completions` | ಬೆಂಬಲಿತ | ಸ್ಟ್ರೀಮಿಂಗ್ + ನಾನ್-ಸ್ಟ್ರೀಮಿಂಗ್ |
| `POST /v1/responses` | ಬೆಂಬಲಿತ | OpenAI Responses API: string/message ಇನ್‌ಪುಟ್, `instructions`, ಸ್ಟ್ರೀಮಿಂಗ್ (canonical event sequence), `text.format` (`json_schema` ಸೇರಿ), ಫಂಕ್ಷನ್ ಟೂಲ್‌ಗಳು (ನಾನ್-ಸ್ಟ್ರೀಮಿಂಗ್). ಸ್ಟೇಟ್‌ಫುಲ್ ವೈಶಿಷ್ಟ್ಯಗಳು (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) ಪ್ರಾಮಾಣಿಕ 501 ನೀಡುತ್ತವೆ |
| `POST /v1/responses/input_tokens` | ಬೆಂಬಲಿತ | ಟೋಕನ್ ಪ್ರೀಫ್ಲೈಟ್ (`client.responses.input_tokens.count(...)`): Apple ನ ಟೋಕನೈಸರ್‌ನಿಂದ ನಿಖರ ಎಣಿಕೆ, ಜನರೇಷನ್ ಇಲ್ಲ; macOS 26.4 ಗಿಂತ ಕೆಳಗೆ ಅಂದಾಜಿನ ಬದಲು 501. ನೋಡಿ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | ಬೆಂಬಲಿತ | `apple-foundationmodel` (ಸಾಮಾನ್ಯ, ಡೀಫಾಲ್ಟ್) ಮತ್ತು `apple-foundationmodel-content-tagging` (ಲೇಬಲ್‌ಗಳು, ಗದ್ಯವಲ್ಲ) ಹಿಂತಿರುಗಿಸುತ್ತದೆ. ನೋಡಿ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | ಬೆಂಬಲಿತ | ಮಾಡೆಲ್ ಲಭ್ಯತೆ, ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋ, ಭಾಷೆಗಳು, ವರದಿಯಾದ ಮಾಡೆಲ್ ಸಾಮರ್ಥ್ಯಗಳು (`capabilities`, `capabilities_reported`), ಸೇವೆ ನೀಡುತ್ತಿರುವ ಮಾಡೆಲ್ ವೇರಿಯಂಟ್ (`variant`, ಉದಾ. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | ಡೀಬಗ್ ಮಾತ್ರ | `--debug` ಅಗತ್ಯ |
| ಟೂಲ್ ಕಾಲಿಂಗ್ | ಬೆಂಬಲಿತ | ಕಾಲ್ ಅನ್ನು ಗೈಡೆಡ್ ಜನರೇಷನ್ ಮೂಲಕ (`--tool-calling guided`, ಡೀಫಾಲ್ಟ್) ಅಥವಾ ಸರ್ವರ್ ಪಾರ್ಸ್ ಮಾಡುವ JSON ಆಗಿ (`--tool-calling text`) ಬರೆಯಲಾಗುತ್ತದೆ. ನೋಡಿ [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | ಬೆಂಬಲಿತ | ಸಿಸ್ಟಮ್-ಪ್ರಾಂಪ್ಟ್ ಇಂಜೆಕ್ಷನ್; ಔಟ್‌ಪುಟ್‌ನಿಂದ markdown ಫೆನ್ಸ್ ತೆಗೆಯಲಾಗುತ್ತದೆ |
| `response_format: json_schema` | ಬೆಂಬಲಿತ | FoundationModels `DynamicGenerationSchema` ಮೂಲಕ ಸ್ಕೀಮಾಗೆ ಹೊಂದುವ ಔಟ್‌ಪುಟ್‌ನ ಖಾತರಿ; `stream: true` ಜೊತೆ ಕೆಲಸ ಮಾಡುತ್ತದೆ |
| `temperature`, `top_p`, `max_tokens`, `seed` | ಬೆಂಬಲಿತ | `GenerationOptions` ಗೆ ಮ್ಯಾಪ್ ಆಗುತ್ತವೆ. `top_p` ಎಂದರೆ nucleus sampling; 0.001 ಕ್ಕಿಂತ ಕಡಿಮೆ `temperature` (0 ಸೇರಿ) greedy (ನಿರ್ಧಾರಿತ) ಗೆ ಮ್ಯಾಪ್ ಆಗುತ್ತದೆ. `max_tokens` ಬಿಟ್ಟರೆ ಉಳಿದ ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋ ಬಳಕೆಯಾಗುತ್ತದೆ (OpenAI ನಂತೆಯೇ ಸೆಮ್ಯಾಂಟಿಕ್ಸ್) - ನೋಡಿ [ಡೀಫಾಲ್ಟ್ ರೆಸ್ಪಾನ್ಸ್ ಮಿತಿ](../README.md#default-response-cap-max_tokens) |
| `stream: true` | ಬೆಂಬಲಿತ | SSE; ಅಂತಿಮ usage chunk `stream_options: {"include_usage": true}` ಇದ್ದಾಗ ಮಾತ್ರ (OpenAI spec ಪ್ರಕಾರ) |
| `usage` | ಬೆಂಬಲಿತ | macOS 26.4+ ನಲ್ಲಿ ನಿಜವಾದ ಟೋಕನೈಸರ್ ಎಣಿಕೆ (ಅದಕ್ಕಿಂತ ಕೆಳಗೆ chars/4 ಅಂದಾಜು). macOS 27: ರನ್‌ಟೈಮ್‌ನ ಸ್ವಂತ ಲೆಕ್ಕಾಚಾರ, Apple ನ chat-template framing ಸೇರಿ (ಒಂದು ಸಾಲಿನ prompt ಮೇಲೆ ಸುಮಾರು 46 ಹೆಚ್ಚುವರಿ `prompt_tokens`); macOS 26: apfel ಸಂದೇಶದ ಪಠ್ಯವನ್ನು ಎಣಿಸುತ್ತದೆ. ವಿವರಗಳು [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) ನಲ್ಲಿ |
| `finish_reason` | ಬೆಂಬಲಿತ | `stop`, `tool_calls`, `length` |
| ಕಾಂಟೆಕ್ಸ್ಟ್ ಸ್ಟ್ರಾಟಜಿಗಳು | ಬೆಂಬಲಿತ | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` ಎಕ್ಸ್‌ಟೆನ್ಷನ್ ಫೀಲ್ಡ್‌ಗಳು |
| CORS | ಬೆಂಬಲಿತ | `--cors` ನಿಂದ ಆನ್ ಮಾಡಿ |
| `POST /v1/completions` | 501 | ಲೆಗಸಿ ಟೆಕ್ಸ್ಟ್ ಕಂಪ್ಲೀಷನ್‌ಗಳಿಗೆ ಬೆಂಬಲವಿಲ್ಲ |
| `POST /v1/embeddings` | 501 | ಆನ್-ಡಿವೈಸ್ ಎಂಬೆಡಿಂಗ್‌ಗಳು ಲಭ್ಯವಿಲ್ಲ |
| `stop` | ಬೆಂಬಲಿತ | ಒಂದು string ಅಥವಾ 4 ರವರೆಗೆ strings; ಸರಳ ಪಠ್ಯ ಮಾತ್ರ (ಟೂಲ್‌ಗಳು ವ್ಯಾಪ್ತಿಯಲ್ಲಿದ್ದರೆ ಅಥವಾ `json_object`/`json_schema` ಇದ್ದರೆ 400). ಔಟ್‌ಪುಟ್ ಬದಿಯಲ್ಲಿ ಅನ್ವಯವಾಗುತ್ತದೆ, ಸ್ಟ್ರೀಮಿಂಗ್ ಮತ್ತು ನಾನ್-ಸ್ಟ್ರೀಮಿಂಗ್‌ನಲ್ಲಿ ಒಂದೇ ರೀತಿ. ನೋಡಿ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | ಸ್ಪಷ್ಟವಾಗಿ ತಿರಸ್ಕರಿಸಲಾಗುತ್ತದೆ. `n=1` ಮತ್ತು `logprobs=false` ಏನೂ ಮಾಡದವು ಎಂದು ಸ್ವೀಕರಿಸಲಾಗುತ್ತದೆ |
| ಮಲ್ಟಿ-ಮೋಡಲ್ (ಚಿತ್ರಗಳು) | macOS 27 ನಲ್ಲಿ ಬೆಂಬಲಿತ | base64 data URL ಆಗಿ `image_url` ಭಾಗಗಳು ನೇರವಾಗಿ ಆನ್-ಡಿವೈಸ್ ಮಾಡೆಲ್‌ಗೆ ಹೋಗುತ್ತವೆ (20 MB base64 ಮಿತಿ, ಉದ್ದದ ಬದಿಯನ್ನು 4096 px ಗೆ ಇಳಿಸಲಾಗುತ್ತದೆ). ರಿಮೋಟ್ `http(s)` URL ಗಳು ಮತ್ತು ಫೈಲ್ ಪಾಥ್‌ಗಳು ಯಾವಾಗಲೂ 400 - apfel ಎಂದೂ ಚಿತ್ರಗಳನ್ನು ತರುವುದಿಲ್ಲ ಮತ್ತು HTTP ಕ್ಲೈಂಟ್‌ಗಾಗಿ ಎಂದೂ ಫೈಲ್ ಓದುವುದಿಲ್ಲ. macOS 26 ನಲ್ಲಿ: ಸ್ಪಷ್ಟ ದೋಷದೊಂದಿಗೆ 400. ನೋಡಿ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` ಹೆಡರ್ | ಬೆಂಬಲಿತ | `--token` ಸೆಟ್ ಆಗಿದ್ದಾಗ ಅಗತ್ಯ. ನೋಡಿ [docs/server-security.md](../docs/server-security.md) |

ಸಂಪೂರ್ಣ API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## ಡೀಫಾಲ್ಟ್ ರೆಸ್ಪಾನ್ಸ್ ಮಿತಿ (`max_tokens`)

`max_tokens` ಬಿಟ್ಟಾಗ **CLI ಮತ್ತು OpenAI-ಹೊಂದಾಣಿಕೆಯ ಸರ್ವರ್ ಒಂದೇ ರೀತಿ ವರ್ತಿಸುತ್ತವೆ**: ಮೌಲ್ಯ `nil` ಆಗಿ ಹರಿಯುತ್ತದೆ ಮತ್ತು ಮಾಡೆಲ್ ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋದಲ್ಲಿ ಉಳಿದಿರುವ ಜಾಗವನ್ನು ಬಳಸುತ್ತದೆ. ಇದು OpenAI ನಂತೆಯೇ ಸೆಮ್ಯಾಂಟಿಕ್ಸ್ - ಯಾವುದೇ ಅನಿಯಂತ್ರಿತ ಫಾಲ್‌ಬ್ಯಾಕ್ ಸ್ಥಿರಾಂಕ ಇಲ್ಲ.

ಆನ್-ಡಿವೈಸ್ ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋದಲ್ಲಿ ಇನ್‌ಪುಟ್ *ಮತ್ತು* ಔಟ್‌ಪುಟ್ ಎರಡೂ ಸೇರಿ ಹಿಡಿಯುತ್ತವೆ: **macOS 26 ನಲ್ಲಿ ಮತ್ತು M1/M2 Mac ಗಳಲ್ಲಿ 4096 ಟೋಕನ್‌ಗಳು, M3 ಅಥವಾ ಹೊಸ ಚಿಪ್ ಮತ್ತು 12 GB+ ಇರುವ macOS 27 ನಲ್ಲಿ 8192 ಟೋಕನ್‌ಗಳು**. apfel ನಿಜವಾದ ಗಾತ್ರವನ್ನು ರನ್‌ಟೈಮ್‌ನಲ್ಲಿ `SystemLanguageModel.contextSize` ಮೂಲಕ ಓದುತ್ತದೆ - ನಿಮ್ಮದನ್ನು `apfel --model-info` ನಿಂದ ಪರಿಶೀಲಿಸಿ. ಜನರೇಷನ್ ಮಿತಿಯನ್ನು ತಲುಪಿದರೆ, ರೆಸ್ಪಾನ್ಸ್ `finish_reason: "length"` ಜೊತೆ ಸ್ವಚ್ಛವಾಗಿ ಮುಗಿಯುತ್ತದೆ ಮತ್ತು ಭಾಗಶಃ ವಿಷಯ ಹಿಂತಿರುಗುತ್ತದೆ (ಸರ್ವರ್: HTTP 200; CLI: stderr ಎಚ್ಚರಿಕೆಯೊಂದಿಗೆ exit 0, ಅಥವಾ `--require-complete` ಜೊತೆ exit 8 - ನೋಡಿ [docs/cli-reference.md](../docs/cli-reference.md)). ಬಿಗಿಯಾದ ಲೇಟೆನ್ಸಿ ಬಜೆಟ್ ಅಥವಾ ನಿಮ್ಮ ಕ್ಲೈಂಟ್‌ಗೆ ತಿಳಿದ ಮಿತಿ ಬೇಕಾದಾಗ `max_tokens` ಅನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ನೀಡಿ.

### ಉದಾಹರಣೆಗಳು

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

### ಮೌಲ್ಯ ಆರಿಸುವುದು

| ಬಳಕೆ                               | `max_tokens`  |
|----------------------------------------|---------------|
| ಒಂದು ಪದ / ವರ್ಗೀಕರಣ ಉತ್ತರ     | 16 - 32       |
| ಒಂದು ಸಾಲಿನ ಸೂಚನೆ                    | 64 - 128      |
| ಚಿಕ್ಕ ಪ್ಯಾರಾಗ್ರಾಫ್                        | 256 - 512     |
| ಉದ್ದ ಪ್ಯಾರಾಗ್ರಾಫ್ / ರಚನಾತ್ಮಕ JSON       | 1024 - 2048   |
| ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋ ಅನುಮತಿಸುವಷ್ಟು ಉದ್ದ   | ಬಿಟ್ಟುಬಿಡಿ       |

`input_tokens + max_tokens` ಅನ್ನು ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋಗಿಂತ ಆರಾಮವಾಗಿ ಕೆಳಗೆ ಇರಿಸಿ (macOS 26 ನಲ್ಲಿ ಮತ್ತು M1/M2 Mac ಗಳಲ್ಲಿ 4096 ಟೋಕನ್‌ಗಳು, M3 ಅಥವಾ ಹೊಸ ಚಿಪ್ ಮತ್ತು 12 GB+ ಇರುವ macOS 27 ನಲ್ಲಿ 8192 (Apple ನ AFM 3 Core Advanced ಮಾಡೆಲ್)). prompt ಸ್ವತಃ ವಿಂಡೋವನ್ನು ಮೀರಿದರೆ, ಜನರೇಷನ್ ಶುರುವಾಗಲು ಸಾಧ್ಯವಿಲ್ಲ ಮತ್ತು ವಿನಂತಿ `[context overflow]` ಜೊತೆ ವಿಫಲವಾಗುತ್ತದೆ (HTTP 400 / CLI exit 4). ವ್ಯಾಲಿಡೇಟರ್ ಧನೇತರ ಮೌಲ್ಯಗಳನ್ನು (`max_tokens <= 0`) ತಿರಸ್ಕರಿಸುತ್ತದೆ.

### CLI ಸಮಾನತೆ

CLI ಮತ್ತು ಸರ್ವರ್ ಒಂದೇ ನಿಯಮ ಹಂಚಿಕೊಳ್ಳುತ್ತವೆ: ಬಿಟ್ಟರೆ = ಉಳಿದ ವಿಂಡೋ ಬಳಸಿ. ಬದಲಾಗಿ ಹೋಗುವ ಸ್ಥಿರಾಂಕ ಇಲ್ಲ. `--max-tokens N` ಅಥವಾ `APFEL_MAX_TOKENS=N` ನಿಂದ ಬದಲಿಸಿ.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### ಸರ್ವರ್‌ಗಾಗಿ permissive ಗಾರ್ಡ್‌ರೇಲ್‌ಗಳು

`apfel --serve --permissive` ಸರ್ವರ್ ನಿರ್ವಹಿಸುವ **ಪ್ರತಿ ವಿನಂತಿಗೂ** Apple ನ `.permissiveContentTransformations` ಗಾರ್ಡ್‌ರೇಲ್‌ಗಳನ್ನು ಬಳಸುವಂತೆ ಮಾಡುತ್ತದೆ. CLI ನ `--permissive` ನಂತೆಯೇ ಅದೇ ಫ್ಲ್ಯಾಗ್, ಅದೇ ಸೆಮ್ಯಾಂಟಿಕ್ಸ್ ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). ವಿನಂತಿ-ಪ್ರತಿ ಓವರ್‌ರೈಡ್ ಇಲ್ಲ - ಇಡೀ ಪ್ರೊಸೆಸ್‌ಗೆ ಸರ್ವರ್ ಆಪರೇಟರ್ ನಿರ್ಧರಿಸುತ್ತಾರೆ.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## ಮಿತಿಗಳು

| ನಿರ್ಬಂಧ | ವಿವರ |
|------------|--------|
| ಕಾಂಟೆಕ್ಸ್ಟ್ ವಿಂಡೋ | **macOS 26 ನಲ್ಲಿ ಮತ್ತು M1/M2 Mac ಗಳಲ್ಲಿ 4096 ಟೋಕನ್‌ಗಳು, M3 ಅಥವಾ ಹೊಸ ಚಿಪ್ ಮತ್ತು 12 GB+ ಇರುವ macOS 27 ನಲ್ಲಿ 8192 ಟೋಕನ್‌ಗಳು** (ಇನ್‌ಪುಟ್ + ಔಟ್‌ಪುಟ್ ಒಟ್ಟಾಗಿ). ಹಾರ್ಡ್‌ಕೋಡ್ ಮಾಡಿದ ಸ್ಥಿರಾಂಕವಲ್ಲ - apfel ರನ್‌ಟೈಮ್‌ನಲ್ಲಿ `SystemLanguageModel.contextSize` ಓದುತ್ತದೆ; `apfel --model-info` ಪ್ರಸ್ತುತ ಮೌಲ್ಯ ಮುದ್ರಿಸುತ್ತದೆ |
| ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ | macOS 26+, Apple Silicon ಮಾತ್ರ |
| ಮಾಡೆಲ್ | ಒಂದೇ ಆನ್-ಡಿವೈಸ್ ಮಾಡೆಲ್ (~3B ಪ್ಯಾರಾಮೀಟರ್), `apple-foundationmodel` (ಸಾಮಾನ್ಯ) ಮತ್ತು `apple-foundationmodel-content-tagging` (Apple ನ ಕಂಟೆಂಟ್-ಟ್ಯಾಗಿಂಗ್ ಅಡಾಪ್ಟರ್; ಟೂಲ್‌ಗಳಿಲ್ಲ) ಆಗಿ ಲಭ್ಯ |
| ಗಾರ್ಡ್‌ರೇಲ್‌ಗಳು | Apple ನ ಸುರಕ್ಷತಾ ವ್ಯವಸ್ಥೆ ನಿರುಪದ್ರವಿ prompt ಗಳನ್ನೂ ತಡೆಯಬಹುದು. `--permissive` ತಪ್ಪು ಪಾಸಿಟಿವ್‌ಗಳನ್ನು ಕಡಿಮೆ ಮಾಡುತ್ತದೆ ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| ವೇಗ | ಆನ್-ಡಿವೈಸ್, ಕ್ಲೌಡ್-ಮಟ್ಟವಲ್ಲ - ಪ್ರತಿ ಉತ್ತರಕ್ಕೆ ಕೆಲವು ಸೆಕೆಂಡುಗಳು |
| ಎಂಬೆಡಿಂಗ್ ಇಲ್ಲ | ಆನ್-ಡಿವೈಸ್ ಲಭ್ಯವಿಲ್ಲ |
| ವಿಷನ್ | ಚಿತ್ರ ಇನ್‌ಪುಟ್ ಮಾಡೆಲ್ ತಲುಪುವುದು macOS 27 ನಲ್ಲಿ ಮಾತ್ರ (ಸರ್ವರ್: data URL ಗಳು; CLI: `-f photo.jpg` ಮತ್ತು ಪೈಪ್ ಮಾಡಿದ ಚಿತ್ರಗಳು, OCR ಪಠ್ಯದ ಜೊತೆಗೆ). macOS 26 ನಲ್ಲಿ ಚಿತ್ರಗಳು OCR/ವರ್ಗೀಕರಣದ ಮೂಲಕ ಪಠ್ಯ ಮಾತ್ರ. 3B ಮಾಡೆಲ್‌ನ ದೃಶ್ಯ ವಿವರಣೆಗಳು ಸ್ಥೂಲ - ಮುದ್ರಿತ ಪಠ್ಯ ಓದಲು OCR ಇನ್ನೂ ನಂಬಲರ್ಹ ಮಾರ್ಗ |
| ಟ್ರೈನಿಂಗ್ ಡೇಟಾ / ಜ್ಞಾನ ಕಟ್‌ಆಫ್ | Apple ಆನ್-ಡಿವೈಸ್ ಮಾಡೆಲ್‌ಗೆ ನಿಖರ ಕಟ್‌ಆಫ್ ಪ್ರಕಟಿಸಿಲ್ಲ. ಹೆಸರಿಸಲು ಒತ್ತಾಯಿಸಿದಾಗ ಮಾಡೆಲ್ **ಪ್ರತಿ ಸ್ಯಾಂಪಲ್‌ನಲ್ಲಿ ಬೇರೆ ದಿನಾಂಕವನ್ನು ಕಲ್ಪಿಸುತ್ತದೆ** (ಉದಾ. "October 2023", "April 2023"). ಮಾಡೆಲ್ ತನ್ನ ಟ್ರೈನಿಂಗ್ ಬಗ್ಗೆ ಹೇಳುವ ಎಲ್ಲವನ್ನೂ ಅವಿಶ್ವಾಸಾರ್ಹ ಎಂದು ಪರಿಗಣಿಸಿ. |
| ಪ್ರಸ್ತುತ ದಿನಾಂಕ ಅಥವಾ ರಿಯಲ್-ಟೈಮ್ ಅರಿವು ಇಲ್ಲ | ಮಾಡೆಲ್‌ಗೆ ಇಂದಿನ ದಿನಾಂಕ ತಿಳಿದಿಲ್ಲ ಮತ್ತು ನೆಟ್‌ವರ್ಕ್/ಗಡಿಯಾರ ಪ್ರವೇಶವಿಲ್ಲ. ಕೇಳಿದರೆ ಅದು ನಿರಾಕರಿಸುತ್ತದೆ ಅಥವಾ ದಿನಾಂಕವನ್ನು ಕಲ್ಪಿಸುತ್ತದೆ. ಲೆಕ್ಕಾಚಾರ ದಿನಾಂಕದ ಮೇಲೆ ಅವಲಂಬಿತವಾದಾಗ ಪ್ರಸ್ತುತ ದಿನಾಂಕವನ್ನು system prompt ಮೂಲಕ ನೀಡಿ (ಕೆಳಗಿನ ಪರಿಹಾರ ನೋಡಿ). |

**ದಿನಾಂಕ-ಅವಲಂಬಿತ prompt ಗಳಿಗೆ ಪರಿಹಾರ** - ಪ್ರಸ್ತುತ ದಿನಾಂಕವನ್ನು system ಸಂದೇಶವಾಗಿ ನೀಡಿ:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

ಗಮನಿಸಿ: ದಿನಾಂಕ ನೀಡಿದರೂ 3B ಮಾಡೆಲ್ ಭ್ರಮೆ ಸೃಷ್ಟಿಸಬಹುದು (ವಿಶೇಷವಾಗಿ ತನ್ನ ಟ್ರೈನಿಂಗ್ ಕಟ್‌ಆಫ್ ಬಗ್ಗೆ ನೇರವಾಗಿ ಕೇಳಿದಾಗ). ಈ ಇಂಜೆಕ್ಷನ್ ದಿನಾಂಕವನ್ನು *ಬಳಸುವ* ಜನರೇಟಿವ್ prompt ಗಳಿಗೆ ಸಹಾಯ ಮಾಡುತ್ತದೆ; ಮಾಡೆಲ್ ತನ್ನ ಬಗ್ಗೆ ಹೇಳಿಕೊಳ್ಳುವ ಅಭ್ಯಾಸವನ್ನು ಇದು ಬದಲಿಸುವುದಿಲ್ಲ.

ಹಿನ್ನೆಲೆ: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## ರೆಫರೆನ್ಸ್ ಡಾಕ್ಸ್

apfel ಅನ್ನು [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) ನಿಂದ ಬಳಸುವ ಮಾರ್ಗದರ್ಶಿಗಳು - ನೋಡಿ [docs/guides/index.md](../docs/guides/index.md). ಪ್ರಾಯೋಗಿಕವಾಗಿ ಪರೀಕ್ಷಿಸಲಾಗಿದೆ; ಚಲಾಯಿಸಬಹುದಾದ ಪುರಾವೆ [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) ನಲ್ಲಿ.

- [docs/install.md](../docs/install.md) - ಇನ್‌ಸ್ಟಾಲ್, ಟ್ರಬಲ್‌ಶೂಟಿಂಗ್ ಮತ್ತು Apple Intelligence ಸೆಟಪ್
- [docs/cli-reference.md](../docs/cli-reference.md) - ಪ್ರತಿ ಫ್ಲ್ಯಾಗ್, ಎಕ್ಸಿಟ್ ಕೋಡ್ ಮತ್ತು ಎನ್ವಿರಾನ್‌ಮೆಂಟ್ ವೇರಿಯಬಲ್
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ಮತ್ತು ಪೈಪ್ ಮಾಡಿದ PDF / ಚಿತ್ರ / ಪಠ್ಯ ಎಕ್ಸ್‌ಟ್ರ್ಯಾಕ್ಷನ್ (OCR + ಚಿತ್ರ ಅರ್ಥೈಸುವಿಕೆ)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ಮತ್ತು launchd ಬಳಕೆ
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` ಬೆಂಬಲ ಮ್ಯಾಟ್ರಿಕ್ಸ್ ಆಳವಾಗಿ
- [docs/server-security.md](../docs/server-security.md) - origin ಪರಿಶೀಲನೆ, CORS, ಟೋಕನ್‌ಗಳು ಮತ್ತು `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - ಚಾಟ್ ಟ್ರಿಮ್ಮಿಂಗ್ ಸ್ಟ್ರಾಟಜಿಗಳು
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - ಸ್ಥಳೀಯ ಮತ್ತು ರಿಮೋಟ್ MCP ಬಳಕೆ
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ಟೂಲ್-ಕಾಲಿಂಗ್ ವರ್ತನೆಯ ವಿವರ
- [docs/integrations.md](../docs/integrations.md) - ಮೂರನೇ-ಪಕ್ಷದ ಟೂಲ್ ಇಂಟಿಗ್ರೇಷನ್‌ಗಳು (opencode, ಇತ್ಯಾದಿ)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code ನಲ್ಲಿ apfel + ಎರಡನೇ edit/apply ಮಾಡೆಲ್ ಜೊತೆ ಸ್ಥಳೀಯ ರಿವ್ಯೂ
- [docs/demos.md](../docs/demos.md) - ಶೆಲ್ ಡೆಮೊಗಳ ಉದ್ದ ವಾಕ್‌ಥ್ರೂಗಳು
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - ಸಂಪಾದಿಸದ ಔಟ್‌ಪುಟ್‌ನೊಂದಿಗೆ 50+ ನಿಜವಾದ prompt ಗಳು
- [docs/swift-library.md](../docs/swift-library.md) - ಡೌನ್‌ಸ್ಟ್ರೀಮ್ ಡೆವಲಪರ್‌ಗಳಿಗಾಗಿ `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel ಏಕೆ FoundationModels ಮೇಲೆ ಚಲಿಸುತ್ತದೆ, Apple ನ ಹೊಸ Core AI (Core ML ನ ಉತ್ತರಾಧಿಕಾರಿ) ಮೇಲಲ್ಲ
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel ಅನ್ನು Apple ನ ಸ್ವಂತ `fm` CLI (macOS 27) ಜೊತೆ ಹೋಲಿಕೆ, ವೈಶಿಷ್ಟ್ಯದ ಪ್ರಕಾರ, ಅಳೆದ ಸಂಖ್ಯೆಗಳೊಂದಿಗೆ

## ಆರ್ಕಿಟೆಕ್ಚರ್

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 ಸ್ಟ್ರಿಕ್ಟ್ ಕಾನ್ಕರೆನ್ಸಿ. ಮೂರು ಟಾರ್ಗೆಟ್‌ಗಳು: `ApfelCore` (ಶುದ್ಧ ಲಾಜಿಕ್, ಯೂನಿಟ್-ಟೆಸ್ಟ್ ಮಾಡಬಹುದಾದ, Swift Package ಉತ್ಪನ್ನವಾಗಿಯೂ ಲಭ್ಯ - ಮೇಲಿನ ರೆಫರೆನ್ಸ್ ಡಾಕ್ಸ್‌ನಲ್ಲಿ ಲಿಂಕ್), `apfel` (CLI + ಸರ್ವರ್), ಮತ್ತು `apfel-tests` (ಶುದ್ಧ Swift ರನ್ನರ್, XCTest ಇಲ್ಲ).

## ಬಿಲ್ಡ್ ಮತ್ತು ಟೆಸ್ಟ್

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

`.version` ಏಕೈಕ ಸತ್ಯ-ಮೂಲ. `make release` ಮಾತ್ರ ಆವೃತ್ತಿಗಳನ್ನು ಹೆಚ್ಚಿಸುತ್ತದೆ. ಸ್ಥಳೀಯ ಬಿಲ್ಡ್‌ಗಳು ಆವೃತ್ತಿಯನ್ನು ಬದಲಿಸುವುದಿಲ್ಲ.

## apfel ವೃಕ್ಷ

apfel ಮೇಲೆ ನಿರ್ಮಿತ ಪ್ರಾಜೆಕ್ಟ್‌ಗಳು. ಪ್ರತಿಯೊಂದೂ ತನ್ನದೇ ರೆಪೊ + Homebrew ಫಾರ್ಮುಲಾದೊಂದಿಗೆ ಬರುತ್ತದೆ.

| ಪ್ರಾಜೆಕ್ಟ್ | ಅದು ಏನು ಮಾಡುತ್ತದೆ | ಇನ್‌ಸ್ಟಾಲ್ |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | ಮೂಲ. ಆನ್-ಡಿವೈಸ್ FoundationModels CLI + OpenAI-ಹೊಂದಾಣಿಕೆಯ ಸರ್ವರ್. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS ಚಾಟ್ ಕ್ಲೈಂಟ್: ಸ್ಟ್ರೀಮಿಂಗ್ markdown, ಸ್ಪೀಚ್ I/O, Apple Vision ಚಿತ್ರ ವಿಶ್ಲೇಷಣೆ. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ಕ್ಲಿಪ್‌ಬೋರ್ಡ್ ಮೇಲೆ ಮೆನು-ಬಾರ್ AI ಕ್ರಿಯೆಗಳು: ಸಾರಾಂಶ, ಅನುವಾದ, ಪುನರ್ಬರಹ. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | ತತ್ಕ್ಷಣ AI ಓವರ್‌ಲೇ: ಕೀ ಒತ್ತಿ, ಕೇಳಿ, ಉತ್ತರ ಪಡೆಯಿರಿ, ಮುಚ್ಚಿ. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | ಫಾರ್ಮುಲಾ ನೋಟ್‌ಪ್ಯಾಡ್ - ಆನ್-ಡಿವೈಸ್ AI ಇನ್‌ಲೈನ್ ಸೆಲ್ ಫಂಕ್ಷನ್ ಆಗಿ. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | ಸಣ್ಣ ಆನ್-ಡಿವೈಸ್ ವಿಂಡೋಗಾಗಿ ಟೋಕನ್-ಬಜೆಟ್ ಆಪ್ಟಿಮೈಸ್ಡ್ MCP ಗಳು: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI ಡೀಬಗ್ ಇನ್‌ಸ್ಪೆಕ್ಟರ್: ವಿನಂತಿ ಟೈಮ್‌ಲೈನ್, MCP ಪ್ರೋಟೋಕಾಲ್ ವೀಕ್ಷಕ, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` ಮೇಲೆ ಶಾಶ್ವತ MCP ರಿಜಿಸ್ಟ್ರಿ + TOML ಕಾನ್ಫಿಗ್ ಸೇರಿಸುವ UNIX ರ‍್ಯಾಪರ್. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | ಆನ್-ಡಿವೈಸ್ ಕಂಟೆಂಟ್ ಟ್ಯಾಗಿಂಗ್ CLI: ಪಠ್ಯವನ್ನು ಪೈಪ್ ಮಾಡಿ, ಟ್ಯಾಗ್/ವಿಷಯ/ಭಾವನೆಗಳನ್ನು ಪಡೆಯಿರಿ. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ಇಕೋಸಿಸ್ಟಮ್ ಟೂಲ್‌ಗಳಿಗೆ Swift package: ಸ್ಥಳೀಯ `apfel --serve` ಅನ್ನು ಹುಡುಕಿ, ಪ್ರಾರಂಭಿಸಿ ಮತ್ತು ಅದರಿಂದ ಸ್ಟ್ರೀಮ್ ಮಾಡಿ. | Swift Package |

## ಸಮುದಾಯ ಪ್ರಾಜೆಕ್ಟ್‌ಗಳು

apfel ಮೇಲೆ ಏನಾದರೂ ನಿರ್ಮಿಸಿದ್ದೀರಾ? ಒಂದು issue ತೆರೆಯಿರಿ, ಅದನ್ನು ಇಲ್ಲಿ ಸೇರಿಸಬಹುದು.

| ಪ್ರಾಜೆಕ್ಟ್ | ಅದು ಏನು ಮಾಡುತ್ತದೆ | ಲಿಂಕ್‌ಗಳು |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | ಫೈಲ್‌ಗಳು, ಕ್ಯಾಲೆಂಡರ್, ಮೇಲ್ ಮತ್ತು Mac ಸ್ಥಿತಿಯನ್ನು read-only ಟೂಲ್‌ಗಳಿಂದ ಓದುವ ಸ್ಥಳೀಯ AI ಏಜೆಂಟ್ | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-ಹೊಂದಾಣಿಕೆಯ API ಮೂಲಕ `apfel --serve` ಜೊತೆ ಮಾತನಾಡುವ ಬ್ರೌಸರ್-ಆಧಾರಿತ ಚಾಟ್ UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | ಸಣ್ಣ Anthropic-OpenAI ಪ್ರಾಕ್ಸಿ ಮೂಲಕ apfel ಅನ್ನು ಸ್ಥಳೀಯ ಬ್ಯಾಕೆಂಡ್ ಆಗಿ ಬದಲಿಸುವ Claude Code ರ‍್ಯಾಪರ್ | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel ಸುತ್ತ ನಿರ್ಮಿಸಿದ ಸ್ಥಳೀಯ ಶೆಲ್ ಆ್ಯಪ್‌ಗಳಿಗೆ ಆ್ಯಪ್ ಮ್ಯಾನೇಜರ್ | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast ಕಮಾಂಡ್ ಬಾರ್ ಎಕ್ಸ್‌ಟೆನ್ಷನ್: ಕೇಳಿ, ಅನುವಾದಿಸಿ, ಫೈಲ್‌ಗಳು ಮತ್ತು ಡೈರೆಕ್ಟರಿಗಳನ್ನು ವಿವರಿಸಿ, ಸಂಭಾಷಣೆ ಇತಿಹಾಸ, ಕಸ್ಟಮ್ system prompt ಗಳು. apfel CLI ಮೂಲಕ ಆನ್-ಡಿವೈಸ್. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## ಕೊಡುಗೆ ನೀಡುವುದು

ಯಾವುದೇ `Arthur-Ficial/apfel*` ರೆಪೊದಲ್ಲಿ issue ಗಳು ಮತ್ತು PR ಗಳಿಗೆ ಸ್ವಾಗತ.

**#agentswelcome** - AI ಏಜೆಂಟ್ PR ಗಳು ಸರಿ. ರೆಪೊದ `CLAUDE.md` ಓದಿ, ಟೆಸ್ಟ್‌ಗಳನ್ನು ಚಲಾಯಿಸಿ, `Co-Authored-By` ಟ್ರೇಲರ್‌ನಲ್ಲಿ ಟೂಲ್‌ಗೆ ಶ್ರೇಯ ನೀಡಿ. ಮನುಷ್ಯರಿಗೆ ಇರುವ ಅದೇ ಮಾನದಂಡ: ಸ್ವಚ್ಛ ಕೋಡ್, ಪಾಸ್ ಆಗುವ ಟೆಸ್ಟ್‌ಗಳು, ಪ್ರಾಮಾಣಿಕ ಮಿತಿಗಳು. ಏಜೆಂಟ್-ಸ್ನೇಹಿ ಪ್ರವೇಶ ಬಿಂದು: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([ಕೊಡುಗೆ ನಿಯಮಗಳು](https://apfel-mcp.franzai.com/#contribute)).

## ಪರವಾನಗಿ

[MIT](../LICENSE)
