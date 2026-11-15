<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> [ഇംഗ്ലീഷ് README](../README.md) ൽ നിന്ന് വിവർത്തനം ചെയ്തത്. ഇംഗ്ലീഷ് പതിപ്പാണ് ആധികാരികം.

# apfel

### നിങ്ങളുടെ Mac-ൽ ഇതിനകം ഉള്ള സൗജന്യ AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac-കളിൽ [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) വഴി ഒരു ബിൽറ്റ്-ഇൻ LLM ഉണ്ട്. `apfel` അതിനെ ഒരു UNIX ടൂളായും ലോക്കൽ OpenAI-അനുയോജ്യ സെർവറായും ലഭ്യമാക്കുന്നു. 100% ഓൺ-ഡിവൈസ്. API കീ ഇല്ല, ക്ലൗഡ് ഇല്ല.

| മോഡ് | കമാൻഡ് | നിങ്ങൾക്ക് എന്ത് ലഭിക്കുന്നു |
|------|---------|--------------|
| UNIX ടൂൾ | `apfel "prompt"` / `echo "text" \| apfel` | പൈപ്പ്-സൗഹൃദ ഉത്തരങ്ങൾ, ഫയൽ അറ്റാച്ച്മെന്റുകൾ, JSON ഔട്ട്പുട്ട്, എക്സിറ്റ് കോഡുകൾ |
| OpenAI-അനുയോജ്യ സെർവർ | `apfel --serve` | OpenAI SDK-കൾക്കായി ലോക്കൽ `http://localhost:11434/v1` ബാക്കെൻഡ്, നേരിട്ടുള്ള പകരക്കാരൻ |

`apfel --chat` - ഇന്ററാക്ടീവ് REPL.

[![apfel ടെർമിനൽ ഡെമോ വീഡിയോ: യഥാർത്ഥ കമാൻഡുകൾ, ഉപകരണത്തിൽ തന്നെ യഥാർത്ഥ ഉത്തരങ്ങൾ (84 സെക്കൻഡ്)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ml/a/apfel-ai-tutorial/#video)

ടൂൾ കോളിംഗ് എല്ലാ സാഹചര്യങ്ങളിലും പ്രവർത്തിക്കുന്നു.

![apfel CLI](../screenshots/cli.png)

## ആവശ്യകതകളും ഇൻസ്റ്റാളും

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ഓൺ ചെയ്തിരിക്കണം](https://support.apple.com/en-us/121115). macOS 27-ൽ, M3 അല്ലെങ്കിൽ പുതിയ ചിപ്പും 12 GB+ ഉം ഉള്ള Mac-കൾ Apple-ന്റെ വലിയ ഓൺ-ഡിവൈസ് മോഡൽ 8192-ടോക്കൺ വിൻഡോയോടെ പ്രവർത്തിപ്പിക്കുന്നു; M1/M2 Mac-കളിലും macOS 26-ലെ എല്ലാ Mac-കളിലും 4096 ആണ്. `apfel --model-info` നിങ്ങളുടേത് കാണിക്കും.

```bash
brew install apfel
```

അപ്ഡേറ്റ്:

```bash
brew upgrade apfel
```

സോഴ്സിൽ നിന്ന് ബിൽഡ് ചെയ്യുക (macOS 27 SDK / Swift 6.3 ഉള്ള Command Line Tools, Xcode വേണ്ട; ബൈനറി macOS 26-ലും 27-ലും പ്രവർത്തിക്കുന്നു):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, same-day tap, Mint, mise, ട്രബിൾഷൂട്ടിംഗ്: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | **മലയാളം** | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## ദ്രുത തുടക്കം

### UNIX ടൂൾ

`!` ഉള്ള prompt-കൾ സിംഗിൾ ക്വോട്ടിൽ എഴുതുക (zsh/bash ഹിസ്റ്ററി എക്സ്പാൻഷൻ): `apfel 'Hello, Mac!'`.

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

### OpenAI-അനുയോജ്യ സെർവർ

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

ബാക്ക്ഗ്രൗണ്ട് സർവീസ് വിശദാംശങ്ങൾ: [docs/background-service.md](../docs/background-service.md).

### ദ്രുത ടെസ്റ്റിംഗ് ചാറ്റ്

`apfel --chat` prompt-കളോ MCP സെർവറുകളോ പരീക്ഷിക്കാനുള്ള ഒരു ചെറിയ REPL ആണ്. GUI ചാറ്റ് ആപ്പിനായി [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) കാണുക.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C കൊണ്ട് പുറത്തുകടക്കാം. കോൺടെക്സ്റ്റ് സ്വയമേവ ട്രിം ചെയ്യപ്പെടുന്നു ([docs/context-strategies.md](../docs/context-strategies.md)).

ഇതിനെതിരെ സ്ക്രിപ്റ്റ് എഴുതുന്നതിനു മുമ്പ് അറിയേണ്ട പരിമിതികൾ (ഓരോ Mac-നും കോൺടെക്സ്റ്റ് വിൻഡോ, ഗാർഡ്റെയിലുകൾ, എംബെഡിംഗ് ഇല്ല): [പരിമിതികൾ](../README.md#limitations).

## ഡെമോകൾ

`apfel` നെ പൊതിഞ്ഞ യഥാർത്ഥ ഷെൽ സ്ക്രിപ്റ്റുകൾ: `cmd` (ഇംഗ്ലീഷിൽ നിന്ന് ഷെൽ കമാൻഡ്), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. അവ ബൈനറിയിൽ തന്നെ ഉൾപ്പെടുത്തിയിട്ടുണ്ട് - റെപ്പോ ക്ലോൺ ചെയ്യേണ്ട. apfel ഇൻസ്റ്റാൾ ചെയ്ത സ്ഥലത്തു നിന്ന് (homebrew-core, tap, അല്ലെങ്കിൽ സോഴ്സ്) ആവശ്യമുള്ളിടത്തേക്ക് എഴുതുക:

```bash
apfel demos ./apfel-demos
```

ഇത് എല്ലാ ഡെമോകളും (എക്സിക്യൂട്ടബിൾ) ഒരു `README.md` ഉം `./apfel-demos` ലേക്ക് എഴുതുന്നു. തുടർന്ന് അവിടെ നിന്ന് പ്രവർത്തിപ്പിക്കുക:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

പുതുക്കാൻ `brew upgrade apfel` ന് ശേഷം വീണ്ടും `apfel demos` പ്രവർത്തിപ്പിക്കുക. സോഴ്സ്: [`demo/`](../demo/). വോക്ക്ത്രൂകളും നിങ്ങളുടെ `.zshrc` നായി കോപ്പി-പേസ്റ്റ് `cmd` ഷെൽ ഫംഗ്ഷനും: [docs/demos.md](../docs/demos.md).

## MCP ടൂൾ പിന്തുണ

`--mcp` ഉപയോഗിച്ച് [Model Context Protocol](https://modelcontextprotocol.io/) സെർവറുകൾ ബന്ധിപ്പിക്കുക. apfel കണ്ടെത്തുകയും പ്രവർത്തിപ്പിക്കുകയും ഫലം തിരികെ നൽകുകയും ചെയ്യുന്നു.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

ടൂൾ വിവരങ്ങൾ ഒഴിവാക്കാൻ `-q` ഉപയോഗിക്കുക.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

[`mcp/calculator/`](../mcp/calculator/) ൽ ഒരു കാൽക്കുലേറ്ററുമായി വരുന്നു ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**റിമോട്ട് MCP സെർവറുകൾ** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **സുരക്ഷ:** `--mcp-token` (ps aux) നേക്കാൾ `APFEL_MCP_TOKEN` ഉപയോഗിക്കുക. പ്ലെയിൻ `http://` വഴി bearer token അയയ്ക്കാൻ apfel വിസമ്മതിക്കുന്നു.

## apfel-run: ഓപ്ഷണൽ കോൺഫിഗ് ലെയർ

apfel-ന് സ്വന്തമായി കോൺഫിഗ് ഫയൽ ഇല്ല - ഫ്ലാഗുകൾ + env വേരിയബിളുകൾ, ഏതൊരു UNIX ടൂളിനെയും പോലെ. നിങ്ങൾക്ക് TOML കോൺഫിഗ് വേണമെങ്കിൽ (പല MCP-കൾ, പ്രൊഫൈലുകൾ, git-ലെ ടീം കോൺഫിഗുകൾ), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) `execve` ഡ്രോപ്പ്-ഇൻ വഴി അത് ചേർക്കുന്ന ഒരു MIT റാപ്പറാണ്.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API അനുയോജ്യത

**ബേസ് URL:** `http://localhost:11434/v1`

| ഫീച്ചർ | സ്ഥിതി | കുറിപ്പുകൾ |
|---------|--------|-------|
| `POST /v1/chat/completions` | പിന്തുണയ്ക്കുന്നു | സ്ട്രീമിംഗ് + നോൺ-സ്ട്രീമിംഗ് |
| `POST /v1/responses` | പിന്തുണയ്ക്കുന്നു | OpenAI Responses API: string/message ഇൻപുട്ട്, `instructions`, സ്ട്രീമിംഗ് (canonical event sequence), `text.format` (`json_schema` ഉൾപ്പെടെ), ഫംഗ്ഷൻ ടൂളുകൾ (നോൺ-സ്ട്രീമിംഗ്). സ്റ്റേറ്റ്ഫുൾ ഫീച്ചറുകൾ (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) സത്യസന്ധമായ 501 നൽകുന്നു |
| `POST /v1/responses/input_tokens` | പിന്തുണയ്ക്കുന്നു | ടോക്കൺ പ്രീഫ്ലൈറ്റ് (`client.responses.input_tokens.count(...)`): Apple-ന്റെ ടോക്കനൈസറിൽ നിന്നുള്ള കൃത്യമായ എണ്ണം, ജനറേഷൻ ഇല്ല; macOS 26.4 ന് താഴെ എസ്റ്റിമേറ്റിന് പകരം 501. കാണുക [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | പിന്തുണയ്ക്കുന്നു | `apple-foundationmodel` തിരികെ നൽകുന്നു |
| `GET /health` | പിന്തുണയ്ക്കുന്നു | മോഡൽ ലഭ്യത, കോൺടെക്സ്റ്റ് വിൻഡോ, ഭാഷകൾ, റിപ്പോർട്ട് ചെയ്ത മോഡൽ കഴിവുകൾ (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | ഡീബഗ് മാത്രം | `--debug` ആവശ്യമാണ് |
| ടൂൾ കോളിംഗ് | പിന്തുണയ്ക്കുന്നു | നേറ്റീവ് `ToolDefinition` + JSON ഡിറ്റക്ഷൻ. കാണുക [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | പിന്തുണയ്ക്കുന്നു | സിസ്റ്റം-പ്രോംപ്റ്റ് ഇൻജക്ഷൻ; ഔട്ട്പുട്ടിൽ നിന്ന് markdown ഫെൻസുകൾ നീക്കുന്നു |
| `response_format: json_schema` | പിന്തുണയ്ക്കുന്നു | FoundationModels `DynamicGenerationSchema` വഴി സ്കീമയ്ക്ക് അനുസൃതമായ ഔട്ട്പുട്ടിന് ഉറപ്പ്; `stream: true` ഉപയോഗിച്ചും പ്രവർത്തിക്കുന്നു |
| `temperature`, `top_p`, `max_tokens`, `seed` | പിന്തുണയ്ക്കുന്നു | `GenerationOptions` ലേക്ക് മാപ്പ് ചെയ്യുന്നു. `top_p` എന്നാൽ nucleus sampling; 0.001 ന് താഴെയുള്ള `temperature` (0 ഉൾപ്പെടെ) greedy (നിർണ്ണയാത്മക) ആയി മാപ്പ് ചെയ്യുന്നു. `max_tokens` ഒഴിവാക്കിയാൽ ബാക്കിയുള്ള കോൺടെക്സ്റ്റ് വിൻഡോ ഉപയോഗിക്കും (OpenAI-യുടെ അതേ സെമാന്റിക്സ്) - കാണുക [ഡിഫോൾട്ട് റെസ്പോൺസ് പരിധി](../README.md#default-response-cap-max_tokens) |
| `stream: true` | പിന്തുണയ്ക്കുന്നു | SSE; അവസാന usage chunk `stream_options: {"include_usage": true}` ഉള്ളപ്പോൾ മാത്രം (OpenAI spec പ്രകാരം) |
| `usage` | പിന്തുണയ്ക്കുന്നു | macOS 26.4+ ൽ യഥാർത്ഥ ടോക്കനൈസർ എണ്ണം (അതിനു താഴെ chars/4 എസ്റ്റിമേറ്റ്). macOS 27: റൺടൈമിന്റെ സ്വന്തം കണക്ക്, Apple-ന്റെ chat-template framing ഉൾപ്പെടെ (ഒരു വരി prompt ൽ ഏകദേശം 46 അധിക `prompt_tokens`); macOS 26: apfel സന്ദേശ ടെക്സ്റ്റ് എണ്ണുന്നു. വിശദാംശങ്ങൾ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) ൽ |
| `finish_reason` | പിന്തുണയ്ക്കുന്നു | `stop`, `tool_calls`, `length` |
| കോൺടെക്സ്റ്റ് സ്ട്രാറ്റജികൾ | പിന്തുണയ്ക്കുന്നു | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` എക്സ്റ്റൻഷൻ ഫീൽഡുകൾ |
| CORS | പിന്തുണയ്ക്കുന്നു | `--cors` ഉപയോഗിച്ച് ഓണാക്കുക |
| `POST /v1/completions` | 501 | ലെഗസി ടെക്സ്റ്റ് കംപ്ലീഷനുകൾ പിന്തുണയ്ക്കുന്നില്ല |
| `POST /v1/embeddings` | 501 | ഓൺ-ഡിവൈസ് എംബെഡിംഗുകൾ ലഭ്യമല്ല |
| `stop` | പിന്തുണയ്ക്കുന്നു | ഒരു string അല്ലെങ്കിൽ 4 വരെ strings; പ്ലെയിൻ ടെക്സ്റ്റ് മാത്രം (ടൂളുകൾ പരിധിയിലുണ്ടെങ്കിൽ അല്ലെങ്കിൽ `json_object`/`json_schema` ആണെങ്കിൽ 400). ഔട്ട്പുട്ട് വശത്ത് പ്രയോഗിക്കുന്നു, സ്ട്രീമിംഗിലും നോൺ-സ്ട്രീമിംഗിലും ഒരുപോലെ. കാണുക [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | വ്യക്തമായി നിരസിക്കുന്നു. `n=1` ഉം `logprobs=false` ഉം ഒന്നും ചെയ്യാത്തവയായി സ്വീകരിക്കുന്നു |
| മൾട്ടി-മോഡൽ (ചിത്രങ്ങൾ) | macOS 27-ൽ പിന്തുണയ്ക്കുന്നു | base64 data URL ആയ `image_url` ഭാഗങ്ങൾ നേരിട്ട് ഓൺ-ഡിവൈസ് മോഡലിലേക്ക് പോകുന്നു (20 MB base64 പരിധി, ഏറ്റവും നീളമുള്ള വശം 4096 px ആയി ചുരുക്കുന്നു). റിമോട്ട് `http(s)` URL-കളും ഫയൽ പാത്തുകളും എപ്പോഴും 400 - apfel ഒരിക്കലും ചിത്രങ്ങൾ ഫെച്ച് ചെയ്യുന്നില്ല, HTTP ക്ലയന്റിനായി ഫയലുകൾ വായിക്കുന്നുമില്ല. macOS 26-ൽ: വ്യക്തമായ പിശകോടെ 400. കാണുക [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` ഹെഡർ | പിന്തുണയ്ക്കുന്നു | `--token` സെറ്റ് ചെയ്തിരിക്കുമ്പോൾ ആവശ്യമാണ്. കാണുക [docs/server-security.md](../docs/server-security.md) |

പൂർണ്ണ API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## ഡിഫോൾട്ട് റെസ്പോൺസ് പരിധി (`max_tokens`)

`max_tokens` ഒഴിവാക്കിയാൽ **CLI യും OpenAI-അനുയോജ്യ സെർവറും ഒരുപോലെ പെരുമാറുന്നു**: മൂല്യം `nil` ആയി കടന്നുപോകുന്നു, മോഡൽ കോൺടെക്സ്റ്റ് വിൻഡോയിൽ ബാക്കിയുള്ള ഇടം ഉപയോഗിക്കുന്നു. ഇത് OpenAI-യുടെ അതേ സെമാന്റിക്സ് ആണ് - ഏകപക്ഷീയമായ ഫാൾബാക്ക് സ്ഥിരാങ്കം ഇല്ല.

ഓൺ-ഡിവൈസ് കോൺടെക്സ്റ്റ് വിൻഡോയിൽ ഇൻപുട്ടും *ഔട്ട്പുട്ടും* ചേർന്ന് ഉൾക്കൊള്ളുന്നു: **macOS 26-ലും M1/M2 Mac-കളിലും 4096 ടോക്കണുകൾ, M3 അല്ലെങ്കിൽ പുതിയ ചിപ്പും 12 GB+ ഉം ഉള്ള macOS 27-ൽ 8192 ടോക്കണുകൾ**. apfel യഥാർത്ഥ വലുപ്പം റൺടൈമിൽ `SystemLanguageModel.contextSize` വഴി വായിക്കുന്നു - നിങ്ങളുടേത് `apfel --model-info` ഉപയോഗിച്ച് പരിശോധിക്കുക. ജനറേഷൻ പരിധിയിൽ എത്തിയാൽ, റെസ്പോൺസ് `finish_reason: "length"` ഓടെ വൃത്തിയായി അവസാനിക്കുകയും ഭാഗിക ഉള്ളടക്കം തിരികെ നൽകുകയും ചെയ്യുന്നു (സെർവർ: HTTP 200; CLI: stderr മുന്നറിയിപ്പോടെ exit 0, അല്ലെങ്കിൽ `--require-complete` ഉപയോഗിച്ച് exit 8 - കാണുക [docs/cli-reference.md](../docs/cli-reference.md)). കർശനമായ ലേറ്റൻസി ബജറ്റോ നിങ്ങളുടെ ക്ലയന്റിന് അറിയപ്പെടുന്ന പരിധിയോ വേണമെങ്കിൽ `max_tokens` വ്യക്തമായി നൽകുക.

### ഉദാഹരണങ്ങൾ

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

### മൂല്യം തിരഞ്ഞെടുക്കൽ

| ഉപയോഗം                               | `max_tokens`  |
|----------------------------------------|---------------|
| ഒറ്റ വാക്ക് / വർഗ്ഗീകരണ മറുപടി     | 16 - 32       |
| ഒരു വരി നിർദ്ദേശം                    | 64 - 128      |
| ചെറിയ ഖണ്ഡിക                        | 256 - 512     |
| നീണ്ട ഖണ്ഡിക / ഘടനാപരമായ JSON       | 1024 - 2048   |
| കോൺടെക്സ്റ്റ് വിൻഡോ അനുവദിക്കുന്നത്ര നീളം   | ഒഴിവാക്കുക       |

`input_tokens + max_tokens` കോൺടെക്സ്റ്റ് വിൻഡോയ്ക്ക് സുഖകരമായി താഴെ നിർത്തുക (macOS 26-ലും M1/M2 Mac-കളിലും 4096 ടോക്കണുകൾ, M3 അല്ലെങ്കിൽ പുതിയ ചിപ്പും 12 GB+ ഉം ഉള്ള macOS 27-ൽ 8192 (Apple-ന്റെ AFM 3 Core Advanced മോഡൽ)). prompt തന്നെ വിൻഡോ കവിഞ്ഞാൽ, ജനറേഷൻ തുടങ്ങാനാവില്ല, അഭ്യർത്ഥന `[context overflow]` ഓടെ പരാജയപ്പെടുന്നു (HTTP 400 / CLI exit 4). പോസിറ്റീവ് അല്ലാത്ത മൂല്യങ്ങൾ (`max_tokens <= 0`) വാലിഡേറ്റർ നിരസിക്കുന്നു.

### CLI തുല്യത

CLI യും സെർവറും ഒരേ നിയമം പങ്കിടുന്നു: ഒഴിവാക്കിയാൽ = ബാക്കിയുള്ള വിൻഡോ ഉപയോഗിക്കുക. വഴുതിപ്പോകാവുന്ന സ്ഥിരാങ്കം ഇല്ല. `--max-tokens N` അല്ലെങ്കിൽ `APFEL_MAX_TOKENS=N` ഉപയോഗിച്ച് മാറ്റുക.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### സെർവറിനുള്ള permissive ഗാർഡ്റെയിലുകൾ

`apfel --serve --permissive` പ്രോസസ് കൈകാര്യം ചെയ്യുന്ന **ഓരോ അഭ്യർത്ഥനയ്ക്കും** Apple-ന്റെ `.permissiveContentTransformations` ഗാർഡ്റെയിലുകൾ ഉപയോഗിക്കാൻ സെർവറിനെ പ്രേരിപ്പിക്കുന്നു. CLI-യുടെ `--permissive` ന്റെ അതേ ഫ്ലാഗ്, അതേ സെമാന്റിക്സ് ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). അഭ്യർത്ഥന-തോറും ഓവർറൈഡ് ഇല്ല - മുഴുവൻ പ്രോസസിനും സെർവർ ഓപ്പറേറ്റർ തീരുമാനിക്കുന്നു.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## പരിമിതികൾ

| നിയന്ത്രണം | വിശദാംശം |
|------------|--------|
| കോൺടെക്സ്റ്റ് വിൻഡോ | **macOS 26-ലും M1/M2 Mac-കളിലും 4096 ടോക്കണുകൾ, M3 അല്ലെങ്കിൽ പുതിയ ചിപ്പും 12 GB+ ഉം ഉള്ള macOS 27-ൽ 8192 ടോക്കണുകൾ** (ഇൻപുട്ട് + ഔട്ട്പുട്ട് ചേർന്ന്). ഹാർഡ്കോഡ് ചെയ്ത സ്ഥിരാങ്കമല്ല - apfel റൺടൈമിൽ `SystemLanguageModel.contextSize` വായിക്കുന്നു; `apfel --model-info` നിലവിലെ മൂല്യം അച്ചടിക്കുന്നു |
| പ്ലാറ്റ്ഫോം | macOS 26+, Apple Silicon മാത്രം |
| മോഡൽ | ഒരൊറ്റ മോഡൽ (`apple-foundationmodel`, ഓൺ-ഡിവൈസ് ~3B പാരാമീറ്ററുകൾ), കോൺഫിഗർ ചെയ്യാനാവില്ല |
| ഗാർഡ്റെയിലുകൾ | Apple-ന്റെ സുരക്ഷാ സംവിധാനം നിരുപദ്രവകരമായ prompt-കളെയും തടഞ്ഞേക്കാം. `--permissive` തെറ്റായ പോസിറ്റീവുകൾ കുറയ്ക്കുന്നു ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| വേഗത | ഓൺ-ഡിവൈസ്, ക്ലൗഡ് സ്കെയിൽ അല്ല - ഓരോ പ്രതികരണത്തിനും കുറച്ച് സെക്കൻഡുകൾ |
| എംബെഡിംഗ് ഇല്ല | ഓൺ-ഡിവൈസ് ലഭ്യമല്ല |
| വിഷൻ | ചിത്ര ഇൻപുട്ട് മോഡലിൽ എത്തുന്നത് macOS 27-ൽ മാത്രം (സെർവർ: data URL-കൾ; CLI: `-f photo.jpg` ഉം പൈപ്പ് ചെയ്ത ചിത്രങ്ങളും, OCR ടെക്സ്റ്റിന് പുറമെ). macOS 26-ൽ ചിത്രങ്ങൾ OCR/വർഗ്ഗീകരണം വഴി ടെക്സ്റ്റ് മാത്രം. 3B മോഡലിന്റെ ദൃശ്യ വിവരണങ്ങൾ സ്ഥൂലമാണ് - അച്ചടിച്ചത് വായിക്കാൻ OCR തന്നെയാണ് വിശ്വസനീയമായ മാർഗം |
| ട്രെയിനിംഗ് ഡാറ്റ / നോളജ് കട്ട്ഓഫ് | ഓൺ-ഡിവൈസ് മോഡലിന് Apple കൃത്യമായ കട്ട്ഓഫ് പ്രസിദ്ധീകരിച്ചിട്ടില്ല. പേര് പറയാൻ നിർബന്ധിച്ചാൽ മോഡൽ **ഓരോ സാമ്പിളിലും വ്യത്യസ്ത തീയതി മെനഞ്ഞെടുക്കുന്നു** (ഉദാ. "October 2023", "April 2023"). മോഡൽ സ്വന്തം ട്രെയിനിംഗിനെക്കുറിച്ച് പറയുന്നതെല്ലാം വിശ്വസനീയമല്ലെന്ന് കരുതുക. |
| നിലവിലെ തീയതിയോ തത്സമയ അവബോധമോ ഇല്ല | മോഡലിന് ഇന്നത്തെ തീയതി അറിയില്ല, നെറ്റ്‌വർക്ക്/ക്ലോക്ക് ആക്സസും ഇല്ല. ചോദിച്ചാൽ അത് നിരസിക്കുകയോ തീയതി മെനയുകയോ ചെയ്യും. കണക്കുകൂട്ടൽ തീയതിയെ ആശ്രയിക്കുമ്പോൾ നിലവിലെ തീയതി system prompt വഴി നൽകുക (താഴെയുള്ള പരിഹാരം കാണുക). |

**തീയതി ആശ്രയിക്കുന്ന prompt-കൾക്കുള്ള പരിഹാരം** - നിലവിലെ തീയതി ഒരു system സന്ദേശമായി നൽകുക:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

കുറിപ്പ്: തീയതി നൽകിയാലും 3B മോഡൽ ഇപ്പോഴും തെറ്റായ വിവരം സൃഷ്ടിച്ചേക്കാം (പ്രത്യേകിച്ച് സ്വന്തം ട്രെയിനിംഗ് കട്ട്ഓഫിനെക്കുറിച്ച് നേരിട്ട് ചോദിക്കുമ്പോൾ). ഈ ഇൻജക്ഷൻ തീയതി *ഉപയോഗിക്കുന്ന* ജനറേറ്റീവ് prompt-കളെ സഹായിക്കുന്നു; മോഡലിന്റെ സ്വയം-റിപ്പോർട്ട് ശീലത്തെ അത് മറികടക്കുന്നില്ല.

പശ്ചാത്തലം: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## റഫറൻസ് ഡോക്സ്

apfel ഉപയോഗിക്കാനുള്ള ഗൈഡുകൾ [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) എന്നിവയിൽ നിന്ന് - കാണുക [docs/guides/index.md](../docs/guides/index.md). പ്രായോഗികമായി പരീക്ഷിച്ചത്; പ്രവർത്തിപ്പിക്കാവുന്ന തെളിവ് [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) ൽ.

- [docs/install.md](../docs/install.md) - ഇൻസ്റ്റാൾ, ട്രബിൾഷൂട്ടിംഗ്, Apple Intelligence സെറ്റപ്പ്
- [docs/cli-reference.md](../docs/cli-reference.md) - ഓരോ ഫ്ലാഗും, എക്സിറ്റ് കോഡും, എൻവയോൺമെന്റ് വേരിയബിളും
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ഉം പൈപ്പ് ചെയ്ത PDF / ചിത്രം / ടെക്സ്റ്റ് എക്സ്ട്രാക്ഷനും (OCR + ചിത്ര ധാരണ)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ഉം launchd ഉപയോഗവും
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` പിന്തുണ മാട്രിക്സ് വിശദമായി
- [docs/server-security.md](../docs/server-security.md) - origin പരിശോധനകൾ, CORS, ടോക്കണുകൾ, `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - ചാറ്റ് ട്രിമ്മിംഗ് സ്ട്രാറ്റജികൾ
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - ലോക്കൽ, റിമോട്ട് MCP ഉപയോഗം
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ടൂൾ-കോളിംഗ് പെരുമാറ്റത്തിന്റെ വിശദ വിവരണം
- [docs/integrations.md](../docs/integrations.md) - മൂന്നാം-കക്ഷി ടൂൾ ഇന്റഗ്രേഷനുകൾ (opencode, മുതലായവ)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code-ൽ apfel + രണ്ടാമത്തെ edit/apply മോഡൽ ഉപയോഗിച്ച് ലോക്കൽ റിവ്യൂ
- [docs/demos.md](../docs/demos.md) - ഷെൽ ഡെമോകളുടെ നീണ്ട വോക്ക്ത്രൂകൾ
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - എഡിറ്റ് ചെയ്യാത്ത ഔട്ട്പുട്ടോടെ 50+ യഥാർത്ഥ prompt-കൾ
- [docs/swift-library.md](../docs/swift-library.md) - ഡൗൺസ്ട്രീം ഡെവലപ്പർമാർക്കായുള്ള `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel എന്തുകൊണ്ട് FoundationModels-ൽ പ്രവർത്തിക്കുന്നു, Apple-ന്റെ പുതിയ Core AI (Core ML-ന്റെ പിൻഗാമി) യിൽ അല്ല
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel നെ Apple-ന്റെ സ്വന്തം `fm` CLI (macOS 27) യുമായി താരതമ്യം, ഫീച്ചർ തോറും, അളന്ന സംഖ്യകളോടെ

## ആർക്കിടെക്ചർ

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 സ്ട്രിക്റ്റ് കോൺകറൻസി. മൂന്ന് ടാർഗറ്റുകൾ: `ApfelCore` (ശുദ്ധ ലോജിക്, യൂണിറ്റ്-ടെസ്റ്റ് ചെയ്യാവുന്നത്, Swift Package ഉൽപ്പന്നമായും ലഭ്യം - മുകളിൽ റഫറൻസ് ഡോക്സിൽ ലിങ്ക് ചെയ്തിരിക്കുന്നു), `apfel` (CLI + സെർവർ), `apfel-tests` (ശുദ്ധ Swift റണ്ണർ, XCTest ഇല്ല).

## ബിൽഡും ടെസ്റ്റും

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

`.version` ആണ് ഏക സത്യ-സ്രോതസ്സ്. `make release` മാത്രമാണ് പതിപ്പുകൾ ഉയർത്തുന്നത്. ലോക്കൽ ബിൽഡുകൾ പതിപ്പ് മാറ്റില്ല.

## apfel വൃക്ഷം

apfel-ന് മുകളിൽ നിർമ്മിച്ച പ്രോജക്റ്റുകൾ. ഓരോന്നും സ്വന്തം റെപ്പോ + Homebrew ഫോർമുലയോടെ വരുന്നു.

| പ്രോജക്റ്റ് | അത് എന്ത് ചെയ്യുന്നു | ഇൻസ്റ്റാൾ |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | അടിസ്ഥാനം. ഓൺ-ഡിവൈസ് FoundationModels CLI + OpenAI-അനുയോജ്യ സെർവർ. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS ചാറ്റ് ക്ലയന്റ്: സ്ട്രീമിംഗ് markdown, സ്പീച്ച് I/O, Apple Vision ചിത്ര വിശകലനം. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ക്ലിപ്പ്ബോർഡിൽ മെനു-ബാർ AI പ്രവർത്തനങ്ങൾ: സംഗ്രഹിക്കുക, വിവർത്തനം ചെയ്യുക, മാറ്റിയെഴുതുക. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | തൽക്ഷണ AI ഓവർലേ: ഒരു കീ അമർത്തുക, ചോദിക്കുക, ഉത്തരം നേടുക, അടയ്ക്കുക. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | ഫോർമുല നോട്ട്പാഡ് - ഓൺ-ഡിവൈസ് AI ഇൻലൈൻ സെൽ ഫംഗ്ഷനായി. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | ചെറിയ ഓൺ-ഡിവൈസ് വിൻഡോയ്ക്കായി ടോക്കൺ-ബജറ്റ് ഒപ്റ്റിമൈസ് ചെയ്ത MCP-കൾ: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI ഡീബഗ് ഇൻസ്പെക്ടർ: അഭ്യർത്ഥന ടൈംലൈൻ, MCP പ്രോട്ടോക്കോൾ വ്യൂവർ, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` ന് മുകളിൽ സ്ഥിരമായ MCP രജിസ്ട്രിയും TOML കോൺഫിഗും ചേർക്കുന്ന UNIX റാപ്പർ. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | ഓൺ-ഡിവൈസ് ഉള്ളടക്ക ടാഗിംഗ് CLI: ടെക്സ്റ്റ് പൈപ്പ് ചെയ്യുക, ടാഗുകൾ/വിഷയങ്ങൾ/വികാരങ്ങൾ നേടുക. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ഇക്കോസിസ്റ്റം ടൂളുകൾക്കുള്ള Swift package: ലോക്കൽ `apfel --serve` കണ്ടെത്തുക, ആരംഭിക്കുക, അതിൽ നിന്ന് സ്ട്രീം ചെയ്യുക. | Swift Package |

## കമ്മ്യൂണിറ്റി പ്രോജക്റ്റുകൾ

apfel-ന് മുകളിൽ എന്തെങ്കിലും നിർമ്മിച്ചോ? ഒരു issue തുറക്കൂ, അത് ഇവിടെ ചേർക്കാം.

| പ്രോജക്റ്റ് | അത് എന്ത് ചെയ്യുന്നു | ലിങ്കുകൾ |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | ഫയലുകൾ, കലണ്ടർ, മെയിൽ, Mac സ്ഥിതി എന്നിവ read-only ടൂളുകൾ വഴി വായിക്കുന്ന ലോക്കൽ AI ഏജന്റ് | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-അനുയോജ്യ API വഴി `apfel --serve` മായി സംസാരിക്കുന്ന ബ്രൗസർ-അധിഷ്ഠിത ചാറ്റ് UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | ചെറിയ Anthropic-OpenAI പ്രോക്സി വഴി apfel നെ ലോക്കൽ ബാക്കെൻഡ് ആയി മാറ്റുന്ന Claude Code റാപ്പർ | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel കേന്ദ്രീകരിച്ച് നിർമ്മിച്ച ലോക്കൽ ഷെൽ ആപ്പുകൾക്കുള്ള ആപ്പ് മാനേജർ | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast കമാൻഡ് ബാർ എക്സ്റ്റൻഷൻ: ചോദിക്കുക, വിവർത്തനം ചെയ്യുക, ഫയലുകളും ഡയറക്ടറികളും വിശദീകരിക്കുക, സംഭാഷണ ചരിത്രം, ഇഷ്ടാനുസൃത system prompt-കൾ. apfel CLI വഴി ഓൺ-ഡിവൈസ്. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## സംഭാവന ചെയ്യൽ

ഏതെങ്കിലും `Arthur-Ficial/apfel*` റെപ്പോയിൽ issue-കളും PR-കളും സ്വാഗതം.

**#agentswelcome** - AI ഏജന്റ് PR-കൾ സ്വീകാര്യമാണ്. റെപ്പോയുടെ `CLAUDE.md` വായിക്കുക, ടെസ്റ്റുകൾ പ്രവർത്തിപ്പിക്കുക, `Co-Authored-By` ട്രെയിലറിൽ ടൂളിന് ക്രെഡിറ്റ് നൽകുക. മനുഷ്യർക്കുള്ള അതേ മാനദണ്ഡം: വൃത്തിയുള്ള കോഡ്, വിജയിക്കുന്ന ടെസ്റ്റുകൾ, സത്യസന്ധമായ പരിമിതികൾ. ഏറ്റവും ഏജന്റ്-സൗഹൃദ പ്രവേശന പോയിന്റ്: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([സംഭാവന നിയമങ്ങൾ](https://apfel-mcp.franzai.com/#contribute)).

## ലൈസൻസ്

[MIT](../LICENSE)
