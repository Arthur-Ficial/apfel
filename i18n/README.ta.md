<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [ஆங்கில README](../README.md) இலிருந்து மொழிபெயர்க்கப்பட்டது. ஆங்கிலப் பதிப்பே அதிகாரபூர்வமானது.

# apfel

### உங்கள் Mac-இல் ஏற்கெனவே உள்ள இலவச AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac-களில் [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) மூலம் உள்ளமைந்த LLM வருகிறது. `apfel` அதை ஒரு UNIX கருவியாகவும், உள்ளூர் OpenAI-இணக்க சேவையகமாகவும் வழங்குகிறது. 100% சாதனத்திலேயே இயங்கும். API விசைகள் தேவையில்லை, கிளவுடும் தேவையில்லை.

| முறை | கட்டளை | கிடைப்பது |
|------|---------|--------------|
| UNIX கருவி | `apfel "prompt"` / `echo "text" \| apfel` | pipe-க்கு ஏற்ற பதில்கள், கோப்பு இணைப்புகள், JSON வெளியீடு, exit குறியீடுகள் |
| OpenAI-இணக்க சேவையகம் | `apfel --serve` | OpenAI SDK-களுக்கு அப்படியே மாற்றாகப் பயன்படுத்தக்கூடிய உள்ளூர் `http://localhost:11434/v1` பின்தளம் |

`apfel --chat` - உரையாடல் REPL.

[![apfel டெர்மினல் டெமோ வீடியோ: உண்மையான கட்டளைகள், சாதனத்திலேயே உண்மையான பதில்கள் (84 வினாடிகள்)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ta/a/apfel-ai-tutorial/#video)

கருவி அழைப்பு (tool calling) எல்லாச் சூழல்களிலும் வேலை செய்யும்.

![apfel CLI](../screenshots/cli.png)

## தேவைகளும் நிறுவலும்

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence இயக்கப்பட்டிருக்க வேண்டும்](https://support.apple.com/en-us/121115). macOS 27-இல், M3 அல்லது புதிய சிப்பும் 12 GB+ நினைவகமும் உள்ள Mac-கள் Apple-இன் பெரிய சாதன மாதிரியை 8192-டோக்கன் சாளரத்துடன் இயக்குகின்றன; M1/M2 Mac-களிலும் macOS 26-இல் உள்ள எல்லா Mac-களிலும் 4096. உங்களுடையதை `apfel --model-info` காட்டும்.

```bash
brew install apfel
```

புதுப்பிக்க:

```bash
brew upgrade apfel
```

மூலக்குறியீட்டிலிருந்து உருவாக்க (macOS 27 SDK / Swift 6.3 உடன் Command Line Tools, Xcode தேவையில்லை; பைனரி macOS 26 மற்றும் 27-இல் இயங்கும்):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

அதே நாள் tap, Mint, mise, சிக்கல் தீர்வு: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | **தமிழ்** | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## விரைவு தொடக்கம்

### UNIX கருவி

`!` உள்ள prompt-களை ஒற்றை மேற்கோளில் இடுங்கள் (zsh/bash history விரிவாக்கம்): `apfel 'Hello, Mac!'`.

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

### OpenAI-இணக்க சேவையகம்

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

பின்னணிச் சேவை விவரங்கள்: [docs/background-service.md](../docs/background-service.md).

### விரைவுச் சோதனை உரையாடல்

`apfel --chat` என்பது prompt-களையோ MCP சேவையகங்களையோ சோதிக்கும் சிறிய REPL. GUI உரையாடல் செயலிக்கு [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) பாருங்கள்.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C மூலம் வெளியேறலாம். சூழல் (context) தானாகவே சுருக்கப்படும் ([docs/context-strategies.md](../docs/context-strategies.md)).

இதற்கு எதிராக ஸ்கிரிப்ட் எழுதும் முன் தெரிந்துகொள்ள வேண்டிய வரம்புகள் (Mac-க்கு ஏற்ப சூழல் சாளரம், guardrails, embeddings இல்லை): [வரம்புகள்](../README.md#limitations).

## டெமோக்கள்

`apfel`-ஐச் சுற்றி எழுதப்பட்ட உண்மையான shell ஸ்கிரிப்ட்கள்: `cmd` (ஆங்கிலத்திலிருந்து shell கட்டளை), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. இவை பைனரியிலேயே சேர்க்கப்பட்டுள்ளன - repo-ஐ clone செய்ய வேண்டியதில்லை. apfel-ஐ எங்கிருந்து நிறுவினாலும் (homebrew-core, tap, அல்லது மூலக்குறியீடு) விரும்பிய இடத்தில் எழுதிக்கொள்ளலாம்:

```bash
apfel demos ./apfel-demos
```

இது ஒவ்வொரு டெமோவையும் (இயக்கத்தக்கதாக) ஒரு `README.md`-உடன் `./apfel-demos`-இல் எழுதும். பிறகு அங்கிருந்தே இயக்குங்கள்:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

`brew upgrade apfel`-க்குப் பிறகு `apfel demos`-ஐ மீண்டும் இயக்கிப் புதுப்பிக்கவும். மூலக்குறியீடு: [`demo/`](../demo/). விளக்கங்களும், உங்கள் `.zshrc`-க்கு நகலெடுத்து ஒட்டக்கூடிய `cmd` shell செயல்பாடும்: [docs/demos.md](../docs/demos.md).

## MCP கருவி ஆதரவு

`--mcp` மூலம் [Model Context Protocol](https://modelcontextprotocol.io/) சேவையகங்களை இணையுங்கள். apfel கருவிகளைக் கண்டறிந்து, இயக்கி, முடிவைத் தரும்.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

கருவித் தகவலை மறைக்க `-q` பயன்படுத்துங்கள்.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

ஒரு கணிப்பான் [`mcp/calculator/`](../mcp/calculator/)-இல் சேர்க்கப்பட்டுள்ளது ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**தொலைநிலை MCP சேவையகங்கள்** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **பாதுகாப்பு:** `--mcp-token`-ஐ விட (ps aux-இல் தெரியும்) `APFEL_MCP_TOKEN`-ஐப் பயன்படுத்துங்கள். எளிய உரை `http://` வழியாக bearer token அனுப்புவதை apfel மறுக்கிறது.

## apfel-run: விருப்பத் தேர்வான உள்ளமைவு அடுக்கு

apfel-க்கு உள்ளமைவுக் கோப்பு இல்லை - எந்த UNIX கருவியையும் போலவே flags + சூழல் மாறிகள் மட்டுமே. TOML உள்ளமைவு வேண்டுமெனில் (பல MCP-கள், சுயவிவரங்கள், git-இல் குழு உள்ளமைவுகள்), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) என்பது `execve` வழியாக அப்படியே மாற்றாக அமர்ந்து அதைச் சேர்க்கும் MIT உரிமமுள்ள wrapper.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API இணக்கத்தன்மை

**அடிப்படை URL:** `http://localhost:11434/v1`

| அம்சம் | நிலை | குறிப்புகள் |
|---------|--------|-------|
| `POST /v1/chat/completions` | ஆதரவு உண்டு | Streaming + non-streaming |
| `POST /v1/responses` | ஆதரவு உண்டு | OpenAI Responses API: string/message உள்ளீடு, `instructions`, streaming (நிலையான நிகழ்வு வரிசை), `text.format` (`json_schema` உட்பட), function tools (non-streaming). நிலை சார்ந்த அம்சங்கள் (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) நேர்மையாக 501 தரும் |
| `POST /v1/responses/input_tokens` | ஆதரவு உண்டு | Token முன்சோதனை (`client.responses.input_tokens.count(...)`): Apple-இன் tokenizer தரும் துல்லியமான எண்ணிக்கை, உருவாக்கம் இல்லை; macOS 26.4-க்குக் கீழ் மதிப்பீட்டுக்குப் பதிலாக 501. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) பாருங்கள் |
| `GET /v1/models` | ஆதரவு உண்டு | `apple-foundationmodel` (பொது, இயல்புநிலை) மற்றும் `apple-foundationmodel-content-tagging` (லேபிள்கள், உரைநடை அல்ல) ஐத் தரும். [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) பாருங்கள் |
| `GET /health` | ஆதரவு உண்டு | மாதிரி கிடைப்பு, சூழல் சாளரம், மொழிகள், தெரிவிக்கப்பட்ட மாதிரித் திறன்கள் (`capabilities`, `capabilities_reported`), சேவை செய்யும் மாதிரி வகை (`variant`, எ.கா. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | பிழைதிருத்தம் மட்டும் | `--debug` தேவை |
| கருவி அழைப்பு | ஆதரவு உண்டு | அழைப்பு வழிகாட்டப்பட்ட உருவாக்கம் மூலம் (`--tool-calling guided`, இயல்புநிலை) அல்லது சேவையகம் பகுப்பாய்வு செய்யும் JSON ஆக (`--tool-calling text`) எழுதப்படும். [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) பாருங்கள் |
| `response_format: json_object` | ஆதரவு உண்டு | System-prompt உட்செலுத்துதல்; வெளியீட்டிலிருந்து markdown வேலிகள் நீக்கப்படும் |
| `response_format: json_schema` | ஆதரவு உண்டு | FoundationModels `DynamicGenerationSchema` மூலம் schema-க்குப் பொருந்தும் வெளியீட்டிற்கு உத்தரவாதம்; `stream: true`-உடனும் வேலை செய்யும் |
| `temperature`, `top_p`, `max_tokens`, `seed` | ஆதரவு உண்டு | `GenerationOptions`-க்கு இணைக்கப்படும். `top_p` என்பது nucleus sampling; 0.001-க்குக் கீழுள்ள `temperature` (0 உட்பட) greedy (நிர்ணயமான) முறைக்கு இணைக்கப்படும். `max_tokens` தவிர்த்தால் மீதமுள்ள சூழல் சாளரம் பயன்படுத்தப்படும் (OpenAI-இன் அதே மாற்று நடத்தை) - [இயல்புநிலை பதில் வரம்பு](../README.md#default-response-cap-max_tokens) பாருங்கள் |
| `stream: true` | ஆதரவு உண்டு | SSE; இறுதி usage chunk `stream_options: {"include_usage": true}` இருக்கும்போது மட்டுமே (OpenAI spec-இன்படி) |
| `usage` | ஆதரவு உண்டு | macOS 26.4+-இல் உண்மையான tokenizer எண்ணிக்கை (அதற்குக் கீழ் chars/4 மதிப்பீடு). macOS 27: Apple-இன் chat-template சட்டகம் உட்பட runtime-இன் சொந்தக் கணக்கு (ஒரு வரி prompt-க்கு சுமார் 46 கூடுதல் `prompt_tokens`); macOS 26: apfel செய்தி உரையை எண்ணும். விவரங்கள் [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md)-இல் |
| `finish_reason` | ஆதரவு உண்டு | `stop`, `tool_calls`, `length` |
| சூழல் உத்திகள் | ஆதரவு உண்டு | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` நீட்சிப் புலங்கள் |
| CORS | ஆதரவு உண்டு | `--cors` மூலம் இயக்கலாம் |
| `POST /v1/completions` | 501 | பழைய text completions ஆதரவு இல்லை |
| `POST /v1/embeddings` | 501 | சாதனத்தில் embeddings கிடைக்காது |
| `stop` | ஆதரவு உண்டு | ஒரு string அல்லது 4 strings வரை; எளிய உரை மட்டும் (tools நடப்பில் இருந்தாலோ `json_object`/`json_schema` இருந்தாலோ 400). வெளியீட்டுப் பக்கத்தில் பயன்படுத்தப்படும், streaming-உம் non-streaming-உம் ஒரே மாதிரி. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) பாருங்கள் |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | வெளிப்படையாக நிராகரிக்கப்படும். `n=1` மற்றும் `logprobs=false` எதுவும் செய்யாமல் ஏற்கப்படும் |
| பல்முறை (படங்கள்) | macOS 27-இல் ஆதரவு | base64 data URL வடிவ `image_url` பகுதிகள் சாதன மாதிரிக்கு இயல்பாகச் செல்லும் (20 MB base64 வரம்பு, நீளமான பக்கம் 4096 px ஆகக் குறைக்கப்படும்). தொலைநிலை `http(s)` URL-களும் கோப்புப் பாதைகளும் எப்போதும் 400 - apfel படங்களைப் பெறுவதில்லை, HTTP கிளையண்டுக்காகக் கோப்புகளையும் படிப்பதில்லை. macOS 26-இல்: தெளிவான பிழையுடன் 400. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) பாருங்கள் |
| `Authorization` header | ஆதரவு உண்டு | `--token` அமைத்திருந்தால் கட்டாயம். [docs/server-security.md](../docs/server-security.md) பாருங்கள் |

முழு API விவரக்குறிப்பு: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## இயல்புநிலை பதில் வரம்பு (`max_tokens`)

`max_tokens` தவிர்க்கப்பட்டால், **CLI-உம் OpenAI-இணக்க சேவையகமும் ஒரே மாதிரி நடந்துகொள்ளும்**: மதிப்பு `nil` ஆகவே செல்லும், மாதிரி சூழல் சாளரத்தில் மீதமுள்ள இடம் முழுவதையும் பயன்படுத்தும். இது OpenAI-இன் அதே மாற்று நடத்தை - தன்னிச்சையான பின்னடைவு மாறிலி எதுவும் இல்லை.

சாதனத்தில் உள்ள சூழல் சாளரம் உள்ளீடு *மற்றும்* வெளியீடு இரண்டையும் சேர்த்துக் கொள்ளும்: **macOS 26-இலும் M1/M2 Mac-களிலும் 4096 டோக்கன்கள், M3 அல்லது புதிய சிப்பும் 12 GB+ நினைவகமும் உள்ள macOS 27-இல் 8192 டோக்கன்கள்**. apfel உண்மையான அளவை runtime-இல் `SystemLanguageModel.contextSize` மூலம் படிக்கிறது - உங்களுடையதை `apfel --model-info` மூலம் பாருங்கள். உருவாக்கம் உச்சவரம்பை எட்டினால், பதில் `finish_reason: "length"` உடன் சீராக முடியும், பகுதி உள்ளடக்கம் திருப்பித் தரப்படும் (சேவையகம்: HTTP 200; CLI: stderr எச்சரிக்கையுடன் exit 0, அல்லது `--require-complete` உடன் exit 8 - [docs/cli-reference.md](../docs/cli-reference.md) பாருங்கள்). இறுக்கமான தாமத வரம்போ, உங்கள் கிளையண்டுக்குத் தெரிந்த உச்சவரம்போ வேண்டுமெனில் `max_tokens` ஐ வெளிப்படையாக அனுப்புங்கள்.

### எடுத்துக்காட்டுகள்

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

### மதிப்பைத் தேர்ந்தெடுத்தல்

| பயன்பாடு                               | `max_tokens`  |
|----------------------------------------|---------------|
| ஒரு சொல் / வகைப்படுத்தல் பதில்     | 16 - 32       |
| ஒரு வரி அறிவுறுத்தல்                   | 64 - 128      |
| சிறு பத்தி                        | 256 - 512     |
| நீண்ட பத்தி / கட்டமைக்கப்பட்ட JSON       | 1024 - 2048   |
| சூழல் சாளரம் அனுமதிக்கும் வரை நீளமாக   | தவிர்த்துவிடுங்கள்       |

`input_tokens + max_tokens` சூழல் சாளரத்துக்குக் (macOS 26-இலும் M1/M2 Mac-களிலும் 4096 டோக்கன்கள், M3 அல்லது புதிய சிப்பும் 12 GB+ நினைவகமும் உள்ள macOS 27-இல் 8192 (Apple-இன் AFM 3 Core Advanced மாதிரி)) கீழே வசதியாக இருக்கட்டும். prompt-ஏ சாளரத்தைத் தாண்டினால் உருவாக்கத்தைத் தொடங்கவே முடியாது; கோரிக்கை `[context overflow]` உடன் தோல்வியடையும் (HTTP 400 / CLI exit 4). நேர்மமற்ற மதிப்புகளை (`max_tokens <= 0`) validator நிராகரிக்கும்.

### CLI ஒற்றுமை

CLI-உம் சேவையகமும் ஒரே விதியைப் பகிர்கின்றன: தவிர்த்தால் = மீதமுள்ள சாளரத்தைப் பயன்படுத்து. விலகிச்செல்லக்கூடிய மாறிலி எதுவும் இல்லை. `--max-tokens N` அல்லது `APFEL_MAX_TOKENS=N` மூலம் மாற்றலாம்.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### சேவையகத்துக்கான தளர்வான guardrails

`apfel --serve --permissive` அந்தச் செயல்முறை கையாளும் **ஒவ்வொரு கோரிக்கைக்கும்** Apple-இன் `.permissiveContentTransformations` guardrails ஐப் பயன்படுத்த வைக்கிறது. CLI-இன் `--permissive`-உடன் அதே flag, அதே பொருள் ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). கோரிக்கைக்கு ஒன்று எனத் தனியாக மாற்றும் வசதி இல்லை - முழுச் செயல்முறைக்கும் சேவையக இயக்குநரே முடிவு செய்கிறார்.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## வரம்புகள்

| கட்டுப்பாடு | விவரம் |
|------------|--------|
| சூழல் சாளரம் | **macOS 26-இலும் M1/M2 Mac-களிலும் 4096 டோக்கன்கள், M3 அல்லது புதிய சிப்பும் 12 GB+ நினைவகமும் உள்ள macOS 27-இல் 8192 டோக்கன்கள்** (உள்ளீடு + வெளியீடு சேர்த்து). கடினமாகக் குறியிடப்பட்ட மாறிலி அல்ல - apfel runtime-இல் `SystemLanguageModel.contextSize` ஐப் படிக்கிறது; `apfel --model-info` தற்போதைய மதிப்பை அச்சிடும் |
| தளம் | macOS 26+, Apple Silicon மட்டும் |
| மாதிரி | சாதனத்தில் இயங்கும் ஒரே மாதிரி (~3B அளவுருக்கள்), `apple-foundationmodel` (பொது) மற்றும் `apple-foundationmodel-content-tagging` (Apple-இன் உள்ளடக்கக் குறியிடல் அடாப்டர்; கருவிகள் இல்லை) ஆக வழங்கப்படுகிறது |
| Guardrails | Apple-இன் பாதுகாப்பு அமைப்பு பாதிப்பற்ற prompt-களையும் தடுக்கலாம். `--permissive` தவறான எச்சரிக்கைகளைக் குறைக்கும் ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| வேகம் | சாதனத்திலேயே இயங்குவதால், கிளவுட் அளவில் அல்ல - ஒரு பதிலுக்குச் சில வினாடிகள் ஆகும் |
| Embeddings இல்லை | சாதனத்தில் கிடைக்காது |
| பார்வை (Vision) | பட உள்ளீடு macOS 27-இல் மட்டுமே மாதிரியை எட்டும் (சேவையகம்: data URL-கள்; CLI: `-f photo.jpg` மற்றும் pipe செய்த படங்கள், OCR உரைக்கு மேலதிகமாக). macOS 26-இல் படங்கள் OCR/வகைப்படுத்தல் வழியாக உரையாக மட்டுமே கிடைக்கும். 3B மாதிரியின் காட்சி விவரிப்புகள் தோராயமானவை - அச்சிட்ட எழுத்தைப் படிக்க OCR-ஏ நம்பகமான வழி |
| பயிற்சித் தரவு / அறிவு எல்லைத் தேதி | Apple சாதன மாதிரிக்கு துல்லியமான எல்லைத் தேதியை வெளியிடவில்லை. ஒன்றைச் சொல்லுமாறு வற்புறுத்தினால், மாதிரி **ஒவ்வொரு முறையும் வேறு தேதியை உருவாக்கிச் சொல்லும்** (எ.கா. "October 2023", "April 2023"). மாதிரி தன் பயிற்சி பற்றிச் சொல்லும் எதையும் நம்பத்தகாததாகக் கருதுங்கள். |
| தற்போதைய தேதியோ நிகழ்நேர அறிவோ இல்லை | மாதிரிக்கு இன்றைய தேதி தெரியாது; நெட்வொர்க்/கடிகாரத்தையும் அணுக முடியாது. கேட்டால் மறுக்கும், அல்லது ஒரு தேதியைக் கற்பனை செய்யும். கணக்கீடு தேதியைச் சார்ந்திருந்தால் system prompt மூலம் தற்போதைய தேதியைச் செலுத்துங்கள் (கீழே உள்ள தீர்வைப் பாருங்கள்). |

**தேதி சார்ந்த prompt-களுக்கான தீர்வு** - தற்போதைய தேதியை system செய்தியாகச் செலுத்துங்கள்:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

குறிப்பு: தேதியைச் செலுத்தினாலும் 3B மாதிரி மாயைகளை (hallucination) உருவாக்கக்கூடும் (குறிப்பாகத் தன் பயிற்சி எல்லைத் தேதியைப் பற்றி நேரடியாகக் கேட்டால்). இந்தச் செலுத்துதல் தேதியைப் *பயன்படுத்தும்* உருவாக்கும் prompt-களுக்கு உதவும்; மாதிரி தன்னைப் பற்றிச் சொல்லும் பழக்கத்தை அது மாற்றாது.

பின்னணி: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## குறிப்பு ஆவணங்கள்

[Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) ஆகியவற்றிலிருந்து apfel-ஐப் பயன்படுத்தும் வழிகாட்டிகள் - [docs/guides/index.md](../docs/guides/index.md) பாருங்கள். நடைமுறையில் சோதிக்கப்பட்டவை; இயக்கிப் பார்க்கக்கூடிய சான்று [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab)-இல் உள்ளது.

- [docs/install.md](../docs/install.md) - நிறுவல், சிக்கல் தீர்வு, Apple Intelligence அமைப்பு
- [docs/cli-reference.md](../docs/cli-reference.md) - ஒவ்வொரு flag, exit குறியீடு, சூழல் மாறி
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` மற்றும் pipe செய்த PDF / படம் / உரை பிரித்தெடுப்பு (OCR + பட புரிதல்)
- [docs/background-service.md](../docs/background-service.md) - `brew services` மற்றும் launchd பயன்பாடு
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` ஆதரவு அட்டவணை விரிவாக
- [docs/server-security.md](../docs/server-security.md) - origin சோதனைகள், CORS, tokens, `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - உரையாடல் சுருக்க உத்திகள்
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - உள்ளூர் மற்றும் தொலைநிலை MCP பயன்பாடு
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - கருவி அழைப்பு நடத்தை விரிவாக
- [docs/integrations.md](../docs/integrations.md) - மூன்றாம் தரப்புக் கருவி ஒருங்கிணைப்புகள் (opencode, முதலியன)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code-இல் apfel + இரண்டாவது edit/apply மாதிரியுடன் உள்ளூர் மதிப்பாய்வு
- [docs/demos.md](../docs/demos.md) - shell டெமோக்களின் நீண்ட விளக்கங்கள்
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - திருத்தப்படாத வெளியீட்டுடன் 50+ உண்மையான prompt-கள்
- [docs/swift-library.md](../docs/swift-library.md) - கீழ்நிலை உருவாக்குநர்களுக்கான `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel ஏன் Apple-இன் புதிய Core AI (Core ML-இன் வாரிசு) மீது அல்லாமல் FoundationModels மீது இயங்குகிறது
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel-ஐ Apple-இன் சொந்த `fm` CLI (macOS 27) உடன் அளவிடப்பட்ட எண்களுடன் அம்சம் அம்சமாக ஒப்பிடுதல்

## கட்டமைப்பு

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. மூன்று targets: `ApfelCore` (தூய தர்க்கம், unit-test செய்யத்தக்கது, Swift Package தயாரிப்பாகவும் கிடைக்கும் - மேலே குறிப்பு ஆவணங்களில் இணைக்கப்பட்டுள்ளது), `apfel` (CLI + சேவையகம்), `apfel-tests` (தூய Swift runner, XCTest தேவையில்லை).

## உருவாக்கமும் சோதனையும்

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

`.version` தான் ஒரே உண்மை மூலம். `make release` மட்டுமே பதிப்புகளை உயர்த்தும். உள்ளூர் builds பதிப்பை மாற்றாது.

## apfel மரம்

apfel மீது கட்டப்பட்ட திட்டங்கள். ஒவ்வொன்றும் தனி repo + Homebrew formula ஆக வருகிறது.

| திட்டம் | என்ன செய்கிறது | நிறுவல் |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | வேர். சாதனத்தில் இயங்கும் FoundationModels CLI + OpenAI-இணக்க சேவையகம். | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS உரையாடல் கிளையண்ட்: streaming markdown, பேச்சு உள்ளீடு/வெளியீடு, Apple Vision பட ஆய்வு. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | clipboard மீது menu-bar AI செயல்கள்: சுருக்கம், மொழிபெயர்ப்பு, மறுவடிவம். | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | உடனடி AI overlay: ஒரு விசையை அழுத்தி, கேட்டு, பதில் பெற்று, மூடுங்கள். | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | சூத்திரக் குறிப்பேடு - சாதன AI ஒரு cell செயல்பாடாக. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | சிறிய சாதனச் சாளரத்துக்காக token-பட்ஜெட் மேம்படுத்தப்பட்ட MCP-கள்: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI பிழைதிருத்த ஆய்வி: கோரிக்கைக் காலவரிசை, MCP நெறிமுறைப் பார்வையாளர், TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` மேல் நிலையான MCP பதிவகமும் TOML உள்ளமைவும் சேர்க்கும் UNIX wrapper. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | சாதனத்திலேயே உள்ளடக்கத்துக்கு tag இடும் CLI: உரையை pipe செய்தால் tags/topics/emotions கிடைக்கும். | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | சூழல்தொகுதிக் கருவிகளுக்கான Swift package: உள்ளூர் `apfel --serve`-ஐக் கண்டறிந்து, தொடங்கி, அதிலிருந்து stream பெறும். | Swift Package |

## சமூகத் திட்டங்கள்

apfel மீது ஏதாவது உருவாக்கினீர்களா? ஒரு issue திறங்கள், இங்கே சேர்க்கலாம்.

| திட்டம் | என்ன செய்கிறது | இணைப்புகள் |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | படிக்க-மட்டும் கருவிகள் மூலம் கோப்புகள், நாட்காட்டி, மின்னஞ்சல், Mac நிலை ஆகியவற்றைப் படிக்கும் உள்ளூர் AI முகவர் | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-இணக்க API வழியாக `apfel --serve`-உடன் பேசும் உலாவி அடிப்படையிலான உரையாடல் UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | சிறிய Anthropic-OpenAI proxy வழியாக apfel-ஐ உள்ளூர் பின்தளமாக மாற்றும் Claude Code wrapper | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel-ஐச் சுற்றி உருவாக்கப்பட்ட உள்ளூர் shell செயலிகளுக்கான செயலி மேலாளர் | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast command bar நீட்சி: கேளுங்கள், மொழிபெயருங்கள், கோப்புகளையும் கோப்பகங்களையும் விளக்குங்கள், உரையாடல் வரலாறு, தனிப்பயன் system prompt-கள். apfel CLI வழியாகச் சாதனத்திலேயே இயங்கும். | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## பங்களிப்பு

எந்த `Arthur-Ficial/apfel*` repo-விலும் issues, PR-கள் வரவேற்கப்படுகின்றன.

**#agentswelcome** - AI முகவர்களின் PR-கள் ஏற்கத்தக்கவை. repo-வின் `CLAUDE.md` ஐப் படியுங்கள், சோதனைகளை இயக்குங்கள், `Co-Authored-By` trailer-இல் கருவியைக் குறிப்பிடுங்கள். மனிதர்களுக்கு உள்ள அதே தரம்தான்: தூய குறியீடு, தேறும் சோதனைகள், நேர்மையான வரம்புகள். முகவர்களுக்கு மிக ஏற்ற தொடக்கப்புள்ளி: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([பங்களிப்பு விதிகள்](https://apfel-mcp.franzai.com/#contribute)).

## உரிமம்

[MIT](../LICENSE)
