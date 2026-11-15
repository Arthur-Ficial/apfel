<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> [ఇంగ్లీష్ README](../README.md) నుండి అనువదించబడింది. ఇంగ్లీష్ వెర్షనే ప్రామాణికం.

# apfel

### మీ Mac లో ఇప్పటికే ఉన్న ఉచిత AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac లలో [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) ద్వారా అంతర్నిర్మిత LLM వస్తుంది. `apfel` దాన్ని UNIX టూల్‌గా, స్థానిక OpenAI-అనుకూల సర్వర్‌గా అందిస్తుంది. 100% పరికరంలోనే నడుస్తుంది. API కీలు అవసరం లేదు, క్లౌడ్ అవసరం లేదు.

| మోడ్ | కమాండ్ | మీకు లభించేది |
|------|---------|--------------|
| UNIX టూల్ | `apfel "prompt"` / `echo "text" \| apfel` | pipe కు అనువైన సమాధానాలు, ఫైల్ అటాచ్‌మెంట్లు, JSON అవుట్‌పుట్, exit కోడ్‌లు |
| OpenAI-అనుకూల సర్వర్ | `apfel --serve` | OpenAI SDK లకు నేరుగా మార్చి వాడగల స్థానిక `http://localhost:11434/v1` బ్యాకెండ్ |

`apfel --chat` - ఇంటరాక్టివ్ REPL.

[![apfel టెర్మినల్ డెమో వీడియో: నిజమైన కమాండ్‌లు, డివైస్‌లోనే నిజమైన సమాధానాలు (84 సెకన్లు)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/te/a/apfel-ai-tutorial/#video)

టూల్ కాలింగ్ అన్ని సందర్భాల్లోనూ పనిచేస్తుంది.

![apfel CLI](../screenshots/cli.png)

## అవసరాలు మరియు ఇన్‌స్టాల్

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ఎనేబుల్ చేసి ఉండాలి](https://support.apple.com/en-us/121115). macOS 27 లో, M3 లేదా కొత్త చిప్, 12 GB+ మెమరీ ఉన్న Mac లు Apple యొక్క పెద్ద ఆన్-డివైస్ మోడల్‌ను 8192-టోకెన్ విండోతో నడుపుతాయి; M1/M2 Mac లకు, macOS 26 లోని ప్రతి Mac కు 4096. మీ దాన్ని `apfel --model-info` చూపిస్తుంది.

```bash
brew install apfel
```

అప్‌డేట్ చేయడానికి:

```bash
brew upgrade apfel
```

సోర్స్ నుండి బిల్డ్ చేయడానికి (macOS 27 SDK / Swift 6.3 తో Command Line Tools, Xcode అవసరం లేదు; బైనరీ macOS 26 మరియు 27 లో నడుస్తుంది):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, అదే రోజు tap, Mint, mise, ట్రబుల్‌షూటింగ్: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | **తెలుగు** | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## త్వరిత ప్రారంభం

### UNIX టూల్

`!` ఉన్న prompt లను సింగిల్ కోట్స్‌లో పెట్టండి (zsh/bash history విస్తరణ కారణంగా): `apfel 'Hello, Mac!'`.

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

### OpenAI-అనుకూల సర్వర్

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

బ్యాక్‌గ్రౌండ్ సర్వీస్ వివరాలు: [docs/background-service.md](../docs/background-service.md).

### త్వరిత పరీక్ష చాట్

`apfel --chat` అనేది prompt లను లేదా MCP సర్వర్‌లను పరీక్షించడానికి ఒక చిన్న REPL. GUI చాట్ యాప్ కోసం [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) చూడండి.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C తో నిష్క్రమించవచ్చు. కాంటెక్స్ట్ ఆటోమేటిక్‌గా కుదించబడుతుంది ([docs/context-strategies.md](../docs/context-strategies.md)).

దీనిపై స్క్రిప్ట్ రాసే ముందు తెలుసుకోవాల్సిన పరిమితులు (Mac ను బట్టి కాంటెక్స్ట్ విండో, guardrails, embeddings లేవు): [పరిమితులు](../README.md#limitations).

## డెమోలు

`apfel` చుట్టూ రాసిన నిజమైన shell స్క్రిప్ట్‌లు: `cmd` (ఇంగ్లీష్ నుండి shell కమాండ్), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. ఇవి బైనరీలోనే ఉన్నాయి - repo ను clone చేయనవసరం లేదు. apfel ను ఎక్కడి నుండి ఇన్‌స్టాల్ చేసినా (homebrew-core, tap, లేదా సోర్స్) మీకు కావలసిన చోట వీటిని రాయవచ్చు:

```bash
apfel demos ./apfel-demos
```

ఇది ప్రతి డెమోను (ఎగ్జిక్యూటబుల్‌గా) ఒక `README.md` తో పాటు `./apfel-demos` లో రాస్తుంది. తర్వాత అక్కడి నుండే నడపండి:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

`brew upgrade apfel` తర్వాత `apfel demos` ను మళ్ళీ నడిపి రిఫ్రెష్ చేయండి. సోర్స్‌లు: [`demo/`](../demo/). వివరణలు, మీ `.zshrc` కోసం కాపీ చేసి పేస్ట్ చేయగల `cmd` shell ఫంక్షన్: [docs/demos.md](../docs/demos.md).

## MCP టూల్ మద్దతు

`--mcp` తో [Model Context Protocol](https://modelcontextprotocol.io/) సర్వర్‌లను అటాచ్ చేయండి. apfel టూల్స్‌ను కనుగొని, అమలు చేసి, ఫలితం ఇస్తుంది.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

టూల్ సమాచారాన్ని దాచడానికి `-q` వాడండి.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

ఒక క్యాలిక్యులేటర్ [`mcp/calculator/`](../mcp/calculator/) లో చేర్చబడింది ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**రిమోట్ MCP సర్వర్‌లు** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **భద్రత:** `--mcp-token` (ps aux లో కనిపిస్తుంది) కంటే `APFEL_MCP_TOKEN` ను వాడండి. సాదా `http://` ద్వారా bearer token లను apfel తిరస్కరిస్తుంది.

## apfel-run: ఐచ్ఛిక కాన్ఫిగ్ లేయర్

apfel కు స్వయంగా కాన్ఫిగ్ ఫైల్ లేదు - ఏ UNIX టూల్ లాగానే flags + env vars మాత్రమే. TOML కాన్ఫిగ్ కావాలంటే (అనేక MCP లు, ప్రొఫైల్‌లు, git లో టీమ్ కాన్ఫిగ్‌లు), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) అనేది `execve` ద్వారా నేరుగా అమరి దాన్ని జోడించే MIT లైసెన్స్ wrapper.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API అనుకూలత

**బేస్ URL:** `http://localhost:11434/v1`

| ఫీచర్ | స్థితి | గమనికలు |
|---------|--------|-------|
| `POST /v1/chat/completions` | మద్దతు ఉంది | Streaming + non-streaming |
| `POST /v1/responses` | మద్దతు ఉంది | OpenAI Responses API: string/message ఇన్‌పుట్, `instructions`, streaming (ప్రామాణిక ఈవెంట్ క్రమం), `text.format` (`json_schema` తో సహా), function tools (non-streaming). స్థితి ఆధారిత ఫీచర్లు (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) నిజాయితీగా 501 ఇస్తాయి |
| `POST /v1/responses/input_tokens` | మద్దతు ఉంది | టోకెన్ ముందస్తు తనిఖీ (`client.responses.input_tokens.count(...)`): Apple యొక్క tokenizer నుండి ఖచ్చితమైన సంఖ్య, జనరేషన్ లేదు; macOS 26.4 కంటే తక్కువలో అంచనాకు బదులు 501. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) చూడండి |
| `GET /v1/models` | మద్దతు ఉంది | `apple-foundationmodel` ను తిరిగి ఇస్తుంది |
| `GET /health` | మద్దతు ఉంది | మోడల్ లభ్యత, కాంటెక్స్ట్ విండో, భాషలు, నివేదించబడిన మోడల్ సామర్థ్యాలు (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | డీబగ్ మాత్రమే | `--debug` అవసరం |
| టూల్ కాలింగ్ | మద్దతు ఉంది | నేటివ్ `ToolDefinition` + JSON గుర్తింపు. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) చూడండి |
| `response_format: json_object` | మద్దతు ఉంది | System-prompt ఇంజెక్షన్; అవుట్‌పుట్ నుండి markdown fences తొలగించబడతాయి |
| `response_format: json_schema` | మద్దతు ఉంది | FoundationModels `DynamicGenerationSchema` ద్వారా schema కు సరిపోయే అవుట్‌పుట్‌కు హామీ; `stream: true` తో కూడా పనిచేస్తుంది |
| `temperature`, `top_p`, `max_tokens`, `seed` | మద్దతు ఉంది | `GenerationOptions` కు మ్యాప్ అవుతాయి. `top_p` అంటే nucleus sampling; 0.001 కంటే తక్కువ `temperature` (0 తో సహా) greedy (నిర్ధారిత) కు మ్యాప్ అవుతుంది. `max_tokens` వదిలేస్తే మిగిలిన కాంటెక్స్ట్ విండో వాడబడుతుంది (OpenAI లాంటి నేరుగా మార్చి వాడే ప్రవర్తన) - [డిఫాల్ట్ ప్రతిస్పందన పరిమితి](../README.md#default-response-cap-max_tokens) చూడండి |
| `stream: true` | మద్దతు ఉంది | SSE; చివరి usage chunk `stream_options: {"include_usage": true}` ఉన్నప్పుడు మాత్రమే (OpenAI spec ప్రకారం) |
| `usage` | మద్దతు ఉంది | macOS 26.4+ లో నిజమైన tokenizer లెక్కలు (అంతకంటే తక్కువలో chars/4 అంచనా). macOS 27: Apple యొక్క chat-template ఫ్రేమింగ్‌తో సహా runtime సొంత లెక్కింపు (ఒక-లైన్ prompt కు సుమారు 46 అదనపు `prompt_tokens`); macOS 26: apfel సందేశ టెక్స్ట్‌ను లెక్కిస్తుంది. వివరాలు [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) లో |
| `finish_reason` | మద్దతు ఉంది | `stop`, `tool_calls`, `length` |
| కాంటెక్స్ట్ వ్యూహాలు | మద్దతు ఉంది | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` పొడిగింపు ఫీల్డ్‌లు |
| CORS | మద్దతు ఉంది | `--cors` తో ఎనేబుల్ చేయండి |
| `POST /v1/completions` | 501 | పాత text completions కు మద్దతు లేదు |
| `POST /v1/embeddings` | 501 | పరికరంలో embeddings అందుబాటులో లేవు |
| `stop` | మద్దతు ఉంది | ఒక string లేదా గరిష్టంగా 4 strings; సాదా టెక్స్ట్ మాత్రమే (tools పరిధిలో ఉన్నా లేదా `json_object`/`json_schema` అయినా 400). అవుట్‌పుట్ వైపు వర్తిస్తుంది, streaming మరియు non-streaming లో ఒకేలా. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) చూడండి |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | స్పష్టంగా తిరస్కరించబడతాయి. `n=1` మరియు `logprobs=false` ఏమీ చేయకుండా అంగీకరించబడతాయి |
| బహుళ-మోడల్ (చిత్రాలు) | macOS 27 లో మద్దతు | base64 data URL లుగా `image_url` భాగాలు పరికరంలోని మోడల్‌కు నేరుగా వెళ్తాయి (20 MB base64 పరిమితి, పొడవైన వైపు 4096 px కు తగ్గించబడుతుంది). రిమోట్ `http(s)` URL లు, ఫైల్ పాత్‌లు ఎల్లప్పుడూ 400 - apfel చిత్రాలను తీసుకురాదు, HTTP క్లయింట్ కోసం ఫైల్‌లను చదవదు. macOS 26 లో: స్పష్టమైన ఎర్రర్‌తో 400. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) చూడండి |
| `Authorization` header | మద్దతు ఉంది | `--token` సెట్ చేసినప్పుడు తప్పనిసరి. [docs/server-security.md](../docs/server-security.md) చూడండి |

పూర్తి API స్పెక్: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## డిఫాల్ట్ ప్రతిస్పందన పరిమితి (`max_tokens`)

`max_tokens` వదిలేసినప్పుడు, **CLI మరియు OpenAI-అనుకూల సర్వర్ ఒకేలా ప్రవర్తిస్తాయి**: విలువ `nil` గానే వెళ్తుంది, మోడల్ కాంటెక్స్ట్ విండోలో మిగిలి ఉన్న స్థలమంతా వాడుతుంది. ఇది OpenAI లాంటి నేరుగా మార్చి వాడే ప్రవర్తన - ఏకపక్ష ఫాల్‌బ్యాక్ స్థిరాంకం ఏదీ లేదు.

పరికరంలోని కాంటెక్స్ట్ విండో ఇన్‌పుట్ *మరియు* అవుట్‌పుట్ రెండింటినీ కలిపి కలిగి ఉంటుంది: **macOS 26 లో, M1/M2 Mac లలో 4096 టోకెన్లు, M3 లేదా కొత్త చిప్, 12 GB+ ఉన్న macOS 27 లో 8192 టోకెన్లు**. apfel అసలు పరిమాణాన్ని runtime లో `SystemLanguageModel.contextSize` ద్వారా చదువుతుంది - మీ దాన్ని `apfel --model-info` తో చూడండి. జనరేషన్ పరిమితిని తాకితే, ప్రతిస్పందన `finish_reason: "length"` తో సాఫీగా ముగుస్తుంది, పాక్షిక కంటెంట్ తిరిగి ఇవ్వబడుతుంది (సర్వర్: HTTP 200; CLI: stderr హెచ్చరికతో exit 0, లేదా `--require-complete` తో exit 8 - [docs/cli-reference.md](../docs/cli-reference.md) చూడండి). కఠినమైన లేటెన్సీ బడ్జెట్ లేదా మీ క్లయింట్‌కు తెలిసిన పరిమితి కావాలంటే `max_tokens` ను స్పష్టంగా ఇవ్వండి.

### ఉదాహరణలు

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

### విలువను ఎంచుకోవడం

| వినియోగం                               | `max_tokens`  |
|----------------------------------------|---------------|
| ఒక పదం / వర్గీకరణ సమాధానం     | 16 - 32       |
| ఒక లైన్ సూచన                   | 64 - 128      |
| చిన్న పేరా                        | 256 - 512     |
| పొడవైన పేరా / నిర్మాణాత్మక JSON       | 1024 - 2048   |
| కాంటెక్స్ట్ విండో అనుమతించినంత పొడవు   | వదిలేయండి       |

`input_tokens + max_tokens` ను కాంటెక్స్ట్ విండో కంటే (macOS 26 లో, M1/M2 Mac లలో 4096 టోకెన్లు, M3 లేదా కొత్త చిప్, 12 GB+ ఉన్న macOS 27 లో 8192 (Apple యొక్క AFM 3 Core Advanced మోడల్)) సౌకర్యవంతంగా తక్కువగా ఉంచండి. prompt యే విండోను మించితే జనరేషన్ మొదలుకాదు, అభ్యర్థన `[context overflow]` తో విఫలమవుతుంది (HTTP 400 / CLI exit 4). ధనాత్మకం కాని విలువలను (`max_tokens <= 0`) validator తిరస్కరిస్తుంది.

### CLI సమానత్వం

CLI మరియు సర్వర్ ఒకే నియమాన్ని పంచుకుంటాయి: వదిలేస్తే = మిగిలిన విండోను వాడు. తప్పిపోగల స్థిరాంకం ఏదీ లేదు. `--max-tokens N` లేదా `APFEL_MAX_TOKENS=N` తో మార్చవచ్చు.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### సర్వర్ కోసం సడలించిన guardrails

`apfel --serve --permissive` ఆ ప్రాసెస్ నిర్వహించే **ప్రతి అభ్యర్థనకూ** Apple యొక్క `.permissiveContentTransformations` guardrails ను వాడేలా చేస్తుంది. CLI యొక్క `--permissive` తో అదే flag, అదే అర్థం ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). అభ్యర్థనకు ఒకటిగా మార్చే వీలు లేదు - మొత్తం ప్రాసెస్ కోసం సర్వర్ ఆపరేటరే నిర్ణయిస్తారు.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## పరిమితులు

| పరిమితి | వివరం |
|------------|--------|
| కాంటెక్స్ట్ విండో | **macOS 26 లో, M1/M2 Mac లలో 4096 టోకెన్లు, M3 లేదా కొత్త చిప్, 12 GB+ ఉన్న macOS 27 లో 8192 టోకెన్లు** (ఇన్‌పుట్ + అవుట్‌పుట్ కలిపి). హార్డ్‌కోడ్ చేసిన స్థిరాంకం కాదు - apfel runtime లో `SystemLanguageModel.contextSize` ను చదువుతుంది; `apfel --model-info` ప్రస్తుత విలువను ప్రింట్ చేస్తుంది |
| ప్లాట్‌ఫారమ్ | macOS 26+, Apple Silicon మాత్రమే |
| మోడల్ | ఒకే మోడల్ (`apple-foundationmodel`, పరికరంలో ~3B పారామీటర్లు), మార్చలేరు |
| Guardrails | Apple యొక్క భద్రతా వ్యవస్థ హానిలేని prompt లను కూడా అడ్డుకోవచ్చు. `--permissive` తప్పుడు హెచ్చరికలను తగ్గిస్తుంది ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| వేగం | పరికరంలోనే నడుస్తుంది, క్లౌడ్ స్థాయిలో కాదు - ప్రతి ప్రతిస్పందనకు కొన్ని సెకన్లు పడుతుంది |
| Embeddings లేవు | పరికరంలో అందుబాటులో లేవు |
| విజన్ | చిత్ర ఇన్‌పుట్ macOS 27 లో మాత్రమే మోడల్‌ను చేరుతుంది (సర్వర్: data URL లు; CLI: `-f photo.jpg` మరియు pipe చేసిన చిత్రాలు, OCR టెక్స్ట్‌కు అదనంగా). macOS 26 లో చిత్రాలు OCR/వర్గీకరణ ద్వారా టెక్స్ట్‌గా మాత్రమే అందుతాయి. 3B మోడల్ దృశ్య వర్ణనలు స్థూలంగా ఉంటాయి - ముద్రిత అక్షరాలను చదవడానికి OCR యే నమ్మదగిన మార్గం |
| శిక్షణ డేటా / జ్ఞాన కటాఫ్ | Apple పరికరంలోని మోడల్‌కు ఖచ్చితమైన కటాఫ్‌ను ప్రచురించలేదు. ఒకటి చెప్పమని ఒత్తిడి చేస్తే, మోడల్ **ప్రతిసారీ వేరే తేదీని కల్పించి చెబుతుంది** (ఉదా. "October 2023", "April 2023"). మోడల్ తన శిక్షణ గురించి చెప్పేవన్నీ నమ్మదగనివిగా భావించండి. |
| ప్రస్తుత తేదీ లేదా నిజ-సమయ అవగాహన లేదు | మోడల్‌కు ఈ రోజు తేదీ తెలియదు, నెట్‌వర్క్/గడియారం అందుబాటులో లేవు. అడిగితే తిరస్కరిస్తుంది, లేదా ఒక తేదీని కల్పిస్తుంది. లెక్కలు తేదీపై ఆధారపడితే system prompt ద్వారా ప్రస్తుత తేదీని ఇవ్వండి (కింద ఉన్న పరిష్కారం చూడండి). |

**తేదీపై ఆధారపడే prompt లకు పరిష్కారం** - ప్రస్తుత తేదీని system సందేశంగా ఇవ్వండి:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

గమనిక: తేదీని ఇచ్చినా 3B మోడల్ ఇప్పటికీ భ్రమలు (hallucination) సృష్టించవచ్చు (ముఖ్యంగా తన శిక్షణ కటాఫ్ గురించి నేరుగా అడిగినప్పుడు). ఈ ఇంజెక్షన్ తేదీని *వాడే* జనరేటివ్ prompt లకు సహాయపడుతుంది; మోడల్ తన గురించి తానే చెప్పుకునే అలవాటును అది మార్చదు.

నేపథ్యం: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## రిఫరెన్స్ డాక్స్

[Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) నుండి apfel ను వాడటానికి గైడ్‌లు - [docs/guides/index.md](../docs/guides/index.md) చూడండి. ఆచరణలో పరీక్షించినవి; నడిపి చూడగల రుజువు [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) లో ఉంది.

- [docs/install.md](../docs/install.md) - ఇన్‌స్టాల్, ట్రబుల్‌షూటింగ్, Apple Intelligence సెటప్
- [docs/cli-reference.md](../docs/cli-reference.md) - ప్రతి flag, exit కోడ్, environment variable
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` మరియు pipe చేసిన PDF / చిత్రం / టెక్స్ట్ వెలికితీత (OCR + చిత్ర అవగాహన)
- [docs/background-service.md](../docs/background-service.md) - `brew services` మరియు launchd వినియోగం
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` మద్దతు పట్టిక లోతుగా
- [docs/server-security.md](../docs/server-security.md) - origin తనిఖీలు, CORS, tokens, `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - చాట్ కుదింపు వ్యూహాలు
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - స్థానిక మరియు రిమోట్ MCP వినియోగం
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - టూల్ కాలింగ్ ప్రవర్తన వివరంగా
- [docs/integrations.md](../docs/integrations.md) - థర్డ్-పార్టీ టూల్ ఇంటిగ్రేషన్‌లు (opencode, మొదలైనవి)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code లో apfel + రెండవ edit/apply మోడల్‌తో స్థానిక సమీక్ష
- [docs/demos.md](../docs/demos.md) - shell డెమోల దీర్ఘ వివరణలు
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - సవరించని అవుట్‌పుట్‌తో 50+ నిజమైన prompt లు
- [docs/swift-library.md](../docs/swift-library.md) - దిగువ డెవలపర్ల కోసం `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel Apple యొక్క కొత్త Core AI (Core ML వారసుడు) పై కాకుండా FoundationModels పై ఎందుకు నడుస్తుంది
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel ను Apple యొక్క సొంత `fm` CLI (macOS 27) తో కొలిచిన సంఖ్యలతో ఫీచర్ల వారీగా పోల్చడం

## ఆర్కిటెక్చర్

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. మూడు targets: `ApfelCore` (స్వచ్ఛమైన లాజిక్, unit-test చేయదగినది, Swift Package ఉత్పత్తిగా కూడా లభ్యం - పైన రిఫరెన్స్ డాక్స్ లో లింక్ చేయబడింది), `apfel` (CLI + సర్వర్), `apfel-tests` (స్వచ్ఛమైన Swift runner, XCTest అవసరం లేదు).

## బిల్డ్ మరియు టెస్ట్

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

`.version` ఒక్కటే ఏకైక సత్య మూలం. `make release` మాత్రమే వెర్షన్‌లను పెంచుతుంది. స్థానిక బిల్డ్‌లు వెర్షన్‌ను మార్చవు.

## apfel వృక్షం

apfel పై నిర్మించిన ప్రాజెక్టులు. ప్రతిదీ సొంత repo + Homebrew formula తో వస్తుంది.

| ప్రాజెక్ట్ | ఏం చేస్తుంది | ఇన్‌స్టాల్ |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | మూలం. పరికరంలో నడిచే FoundationModels CLI + OpenAI-అనుకూల సర్వర్. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS చాట్ క్లయింట్: streaming markdown, స్పీచ్ ఇన్‌పుట్/అవుట్‌పుట్, Apple Vision చిత్ర విశ్లేషణ. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | క్లిప్‌బోర్డ్‌పై menu-bar AI చర్యలు: సంగ్రహం, అనువాదం, పునర్లేఖనం. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | తక్షణ AI ఓవర్‌లే: ఒక కీ నొక్కండి, అడగండి, సమాధానం పొందండి, మూసివేయండి. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | ఫార్ములా నోట్‌ప్యాడ్ - పరికరంలోని AI ను సెల్ ఫంక్షన్‌గా వాడండి. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | చిన్న ఆన్-డివైస్ విండో కోసం టోకెన్-బడ్జెట్‌కు అనుకూలీకరించిన MCP లు: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI డీబగ్ ఇన్‌స్పెక్టర్: అభ్యర్థన టైమ్‌లైన్, MCP ప్రోటోకాల్ వ్యూయర్, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` పై శాశ్వత MCP రిజిస్ట్రీ + TOML కాన్ఫిగ్‌ను జోడించే UNIX wrapper. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | పరికరంలోనే కంటెంట్ ట్యాగింగ్ CLI: టెక్స్ట్‌ను pipe చేస్తే tags/topics/emotions వస్తాయి. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ఎకోసిస్టమ్ టూల్స్ కోసం Swift package: స్థానిక `apfel --serve` ను కనుగొని, ప్రారంభించి, దాని నుండి stream పొందుతుంది. | Swift Package |

## కమ్యూనిటీ ప్రాజెక్టులు

apfel పై ఏదైనా నిర్మించారా? ఒక issue తెరవండి, ఇక్కడ చేర్చవచ్చు.

| ప్రాజెక్ట్ | ఏం చేస్తుంది | లింకులు |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | చదవడానికి-మాత్రమే టూల్స్ ద్వారా ఫైల్‌లు, క్యాలెండర్, మెయిల్, Mac స్థితిని చదివే స్థానిక AI ఏజెంట్ | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-అనుకూల API ద్వారా `apfel --serve` తో మాట్లాడే బ్రౌజర్ ఆధారిత చాట్ UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | చిన్న Anthropic-OpenAI proxy ద్వారా apfel ను స్థానిక బ్యాకెండ్‌గా మార్చే Claude Code wrapper | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel చుట్టూ నిర్మించిన స్థానిక shell యాప్‌ల కోసం యాప్ మేనేజర్ | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast command bar పొడిగింపు: అడగండి, అనువదించండి, ఫైల్‌లు మరియు డైరెక్టరీలను వివరించండి, సంభాషణ చరిత్ర, కస్టమ్ system prompt లు. apfel CLI ద్వారా పరికరంలోనే నడుస్తుంది. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## సహకారం

ఏ `Arthur-Ficial/apfel*` repo లోనైనా issues, PR లకు స్వాగతం.

**#agentswelcome** - AI ఏజెంట్ల PR లు సరే. repo యొక్క `CLAUDE.md` చదవండి, టెస్ట్‌లు నడపండి, `Co-Authored-By` trailer లో టూల్‌ను పేర్కొనండి. మనుషులకు ఉన్న ప్రమాణమే: శుభ్రమైన కోడ్, పాస్ అయ్యే టెస్ట్‌లు, నిజాయితీగా పరిమితులు. ఏజెంట్లకు అత్యంత అనువైన ప్రారంభ స్థానం: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([సహకార నియమాలు](https://apfel-mcp.franzai.com/#contribute)).

## లైసెన్స్

[MIT](../LICENSE)
