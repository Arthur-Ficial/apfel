<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Tradus din [README-ul în engleză](../README.md). Versiunea în engleză are prioritate.

# apfel

### AI-ul gratuit care se află deja pe Mac-ul tău.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac-urile cu Apple Silicon vin cu un LLM integrat, prin [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` îl expune ca instrument UNIX și ca server local compatibil OpenAI. 100% pe dispozitiv. Fără chei API, fără cloud.

| Mod | Comandă | Ce primești |
|------|---------|--------------|
| Instrument UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Răspunsuri potrivite pentru pipe, fișiere atașate, ieșire JSON, coduri de ieșire |
| Server compatibil OpenAI | `apfel --serve` | Backend local `http://localhost:11434/v1`, înlocuitor direct pentru SDK-urile OpenAI |

`apfel --chat` - REPL interactiv.

[![Video demonstrativ apfel în terminal: comenzi reale, răspunsuri reale pe dispozitiv (84 de secunde)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ro/a/apfel-ai-tutorial/#video)

Apelarea de instrumente funcționează în toate contextele.

![apfel CLI](../screenshots/cli.png)

## Cerințe și instalare

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence activat](https://support.apple.com/en-us/121115). Pe macOS 27, Mac-urile cu cip M3 sau mai nou și 12 GB+ rulează modelul mai mare al Apple, pe dispozitiv, cu o fereastră de 8192 de tokeni; Mac-urile M1/M2 și orice Mac cu macOS 26 au 4096. `apfel --model-info` îți arată valoarea ta.

```bash
brew install apfel
```

Actualizare:

```bash
brew upgrade apfel
```

Compilare din sursă (Command Line Tools cu SDK-ul macOS 27 / Swift 6.3, fără Xcode; binarul rulează pe macOS 26 și 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, same-day tap, Mint, mise, depanare: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | **Română** | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Pornire rapidă

### Instrument UNIX

Pune între ghilimele simple prompturile care conțin `!` (expandarea istoricului în zsh/bash): `apfel 'Hello, Mac!'`.

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

### Server compatibil OpenAI

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

Detalii despre serviciul de fundal: [docs/background-service.md](../docs/background-service.md).

### Chat pentru teste rapide

`apfel --chat` este un REPL mic pentru testarea prompturilor sau a serverelor MCP. Pentru o aplicație de chat cu GUI, vezi [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C închide sesiunea. Contextul este tăiat automat ([docs/context-strategies.md](../docs/context-strategies.md)).

Limitări bune de știut înainte să scrii scripturi (fereastra de context per Mac, guardrails, fără embeddings): [Limitări](../README.md#limitations).

## Demo-uri

Scripturi shell reale care învelesc `apfel`: `cmd` (engleză în comandă shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Sunt incluse în binar - fără clonarea repo-ului. Scrie-le oriunde, din canalul din care ai instalat apfel (homebrew-core, tap-ul sau sursa):

```bash
apfel demos ./apfel-demos
```

Aceasta scrie toate demo-urile (executabile) plus un `README.md` în `./apfel-demos`. Apoi rulează-le de acolo:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Rulează din nou `apfel demos` după `brew upgrade apfel` pentru a le reîmprospăta. Surse: [`demo/`](../demo/). Ghiduri detaliate și o funcție shell `cmd` de copiat în `.zshrc`: [docs/demos.md](../docs/demos.md).

## Suport pentru instrumente MCP

Atașează servere [Model Context Protocol](https://modelcontextprotocol.io/) cu `--mcp`. apfel descoperă, apelează și returnează.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Folosește `-q` pentru a ascunde informațiile despre instrumente.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Include un calculator în [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Servere MCP la distanță** (Streamable HTTP, specificația MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Securitate:** preferă `APFEL_MCP_TOKEN` în locul `--mcp-token` (vizibil în ps aux). apfel refuză token-urile bearer prin `http://` necriptat.

## apfel-run: strat opțional de configurare

apfel în sine nu are fișier de configurare - doar flaguri și variabile de mediu, ca orice instrument UNIX. Dacă vrei o configurare TOML (multe MCP-uri, profiluri, configurări de echipă în git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) este un wrapper MIT care o adaugă printr-un înlocuitor direct cu `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilitate cu OpenAI API

**URL de bază:** `http://localhost:11434/v1`

| Funcție | Stare | Note |
|---------|--------|-------|
| `POST /v1/chat/completions` | Suportat | Cu și fără streaming |
| `POST /v1/responses` | Suportat | OpenAI Responses API: intrare string/mesaj, `instructions`, streaming (secvență canonică de evenimente), `text.format` (inclusiv `json_schema`), function tools (fără streaming). Funcțiile cu stare (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) returnează 501 sincere |
| `POST /v1/responses/input_tokens` | Suportat | Verificare prealabilă a tokenilor (`client.responses.input_tokens.count(...)`): număr exact de la tokenizer-ul Apple, fără generare; 501 sub macOS 26.4 în loc de o estimare. Vezi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Suportat | Returnează `apple-foundationmodel` |
| `GET /health` | Suportat | Disponibilitatea modelului, fereastra de context, limbi, capabilitățile raportate ale modelului (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Doar pentru debug | Necesită `--debug` |
| Apelare de instrumente | Suportat | `ToolDefinition` nativ + detecție JSON. Vezi [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Suportat | Injecție în system prompt; blocurile markdown sunt eliminate din ieșire |
| `response_format: json_schema` | Suportat | Ieșire garantat conformă cu schema prin FoundationModels `DynamicGenerationSchema`; funcționează cu `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Suportat | Mapate la `GenerationOptions`. `top_p` este nucleus sampling; `temperature` sub 0.001 (inclusiv 0) se mapează la greedy (determinist). Dacă `max_tokens` este omis, se folosește restul ferestrei de context (semantică OpenAI de înlocuire directă) - vezi [Limita implicită a răspunsului](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Suportat | SSE; chunk-ul final de usage doar cu `stream_options: {"include_usage": true}` (conform specificației OpenAI) |
| `usage` | Suportat | Numărători reale ale tokenizer-ului pe macOS 26.4+ (sub această versiune, estimare chars/4). macOS 27: contabilitatea proprie a runtime-ului, inclusiv încadrarea chat-template a Apple (circa 46 de `prompt_tokens` în plus pentru un prompt de o linie); macOS 26: apfel numără textul mesajelor. Detalii în [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Suportat | `stop`, `tool_calls`, `length` |
| Strategii de context | Suportat | Câmpuri de extensie `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Suportat | Se activează cu `--cors` |
| `POST /v1/completions` | 501 | Completările de text legacy nu sunt suportate |
| `POST /v1/embeddings` | 501 | Embeddings nu sunt disponibile pe dispozitiv |
| `stop` | Suportat | String sau până la 4 string-uri; doar text simplu (400 cu instrumente în scop sau `json_object`/`json_schema`). Aplicat pe partea de ieșire, identic cu și fără streaming. Vezi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Respinse explicit. `n=1` și `logprobs=false` sunt acceptate ca no-op |
| Multimodal (imagini) | Suportat pe macOS 27 | Părțile `image_url` ca data URL-uri base64 ajung nativ la modelul de pe dispozitiv (limită 20 MB base64, latura cea mai lungă redusă la 4096 px). URL-urile `http(s)` la distanță și căile de fișiere dau întotdeauna 400 - apfel nu descarcă niciodată imagini și nu citește niciodată fișiere pentru un client HTTP. Pe macOS 26: 400 cu o eroare clară. Vezi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Antetul `Authorization` | Suportat | Obligatoriu când este setat `--token`. Vezi [docs/server-security.md](../docs/server-security.md) |

Specificația completă a API-ului: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Limita implicită a răspunsului (`max_tokens`)

Când `max_tokens` este omis, **CLI-ul și serverul compatibil OpenAI se comportă identic**: valoarea trece mai departe ca `nil`, iar modelul folosește tot spațiul rămas în fereastra de context. Aceasta este semantica OpenAI de înlocuire directă - fără o constantă de rezervă arbitrară.

Fereastra de context de pe dispozitiv cuprinde intrarea *și* ieșirea la un loc: **4096 de tokeni pe macOS 26 și pe Mac-uri M1/M2, 8192 de tokeni pe macOS 27 cu un cip M3 sau mai nou și 12 GB+**. apfel citește dimensiunea reală la runtime prin `SystemLanguageModel.contextSize` - verifică-o pe a ta cu `apfel --model-info`. Dacă generarea atinge limita, răspunsul se încheie curat cu `finish_reason: "length"` și se returnează conținutul parțial (server: HTTP 200; CLI: ieșire 0 cu un avertisment pe stderr, sau ieșire 8 cu `--require-complete` - vezi [docs/cli-reference.md](../docs/cli-reference.md)). Setează `max_tokens` explicit când vrei un buget de latență mai strâns sau o limită cunoscută pentru clientul tău.

### Exemple

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

### Alegerea unei valori

| Caz de utilizare                       | `max_tokens`  |
|----------------------------------------|---------------|
| Răspuns dintr-un cuvânt / clasificare  | 16 - 32       |
| Instrucțiune de o linie                | 64 - 128      |
| Paragraf scurt                         | 256 - 512     |
| Paragraf lung / JSON structurat        | 1024 - 2048   |
| Cât permite fereastra de context       | omite-l       |

Păstrează `input_tokens + max_tokens` confortabil sub fereastra de context (4096 de tokeni pe macOS 26 și pe Mac-uri M1/M2, 8192 pe macOS 27 cu un cip M3 sau mai nou și 12 GB+ (modelul AFM 3 Core Advanced al Apple)). Dacă promptul în sine depășește fereastra, generarea nu poate începe, iar cererea eșuează cu `[context overflow]` (HTTP 400 / CLI exit 4). Validatorul respinge valorile non-pozitive (`max_tokens <= 0`).

### Paritate cu CLI-ul

CLI-ul și serverul împart o singură regulă: omis = se folosește restul ferestrei. Nicio constantă care să deriveze. Suprascrie cu `--max-tokens N` sau `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardrails permisive pentru server

`apfel --serve --permissive` face ca serverul să folosească guardrails-urile `.permissiveContentTransformations` ale Apple pentru **fiecare cerere** pe care o tratează procesul. Același flag, aceeași semantică precum `--permissive` din CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Nu există suprascriere per cerere - operatorul serverului decide pentru întregul proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitări

| Constrângere | Detalii |
|------------|--------|
| Fereastra de context | **4096 de tokeni pe macOS 26 și pe Mac-uri M1/M2, 8192 de tokeni pe macOS 27 cu un cip M3 sau mai nou și 12 GB+** (intrare + ieșire la un loc). Nu este o constantă scrisă în cod - apfel citește `SystemLanguageModel.contextSize` la runtime; `apfel --model-info` afișează valoarea curentă |
| Platformă | macOS 26+, doar Apple Silicon |
| Model | Un singur model (`apple-foundationmodel`, ~3B parametri pe dispozitiv), nu poate fi configurat |
| Guardrails | Sistemul de siguranță al Apple poate bloca prompturi inofensive. `--permissive` reduce fals pozitivele ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Viteză | Pe dispozitiv, nu la scară cloud - câteva secunde per răspuns |
| Fără embeddings | Nu sunt disponibile pe dispozitiv |
| Viziune | Imaginile ajung la model doar pe macOS 27 (server: data URL-uri; CLI: `-f photo.jpg` și imagini prin pipe, pe lângă textul OCR). Pe macOS 26 imaginile sunt doar text, prin OCR/clasificare. Descrierile de scene ale modelului 3B sunt aproximative - OCR rămâne canalul de încredere pentru citirea textului tipărit |
| Date de antrenare / limita de cunoștințe | Apple nu a publicat o limită precisă pentru modelul de pe dispozitiv. Când este împins să dea una, modelul **inventează o altă dată la fiecare eșantion** (de ex. "October 2023", "April 2023"). Consideră nesigure toate declarațiile modelului despre propria antrenare. |
| Fără dată curentă sau conștiență în timp real | Modelul nu știe data de azi și nu are acces la rețea/ceas. Dacă este întrebat, fie refuză, fie inventează o dată. Injectează data curentă prin system prompt când calculele depind de ea (vezi soluția de mai jos). |

**Soluție pentru prompturile care depind de dată** - injectează data curentă ca mesaj de sistem:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Notă: chiar și cu o dată injectată, modelul 3B poate totuși halucina (mai ales când este întrebat direct despre limita propriei antrenări). Injecția ajută prompturile generative care *folosesc* data; nu anulează reflexul modelului de a vorbi despre sine.

Context: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentație de referință

Ghiduri pentru folosirea apfel din [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - vezi [docs/guides/index.md](../docs/guides/index.md). Testate empiric; dovadă executabilă la [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalare, depanare și configurarea Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - fiecare flag, cod de ieșire și variabilă de mediu
- [docs/file-extraction.md](../docs/file-extraction.md) - extragerea conținutului PDF / imagine / text cu `-f` și prin pipe (OCR + înțelegerea imaginilor)
- [docs/background-service.md](../docs/background-service.md) - utilizarea `brew services` și launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matricea detaliată de suport `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - verificări de origin, CORS, token-uri și `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategii de tăiere a chatului
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - utilizarea MCP local și la distanță
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportamentul detaliat al apelării de instrumente
- [docs/integrations.md](../docs/integrations.md) - integrări cu instrumente terțe (opencode etc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revizuire locală cu apfel + un al doilea model de editare/aplicare în VS Code
- [docs/demos.md](../docs/demos.md) - ghiduri mai lungi pentru demo-urile shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - peste 50 de prompturi reale cu ieșire needitată
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` pentru dezvoltatorii downstream
- [docs/coreai-impact.md](../docs/coreai-impact.md) - de ce apfel rulează pe FoundationModels și nu pe noul Core AI al Apple (succesorul Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel comparat cu propriul CLI `fm` al Apple (macOS 27), funcție cu funcție, cu cifre măsurate

## Arhitectură

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Trei ținte: `ApfelCore` (logică pură, testabilă unitar, disponibilă și ca produs Swift Package - legat în Documentația de referință de mai sus), `apfel` (CLI + server) și `apfel-tests` (runner în Swift pur, fără XCTest).

## Build și teste

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

`.version` este singura sursă de adevăr. Doar `make release` crește versiunile. Build-urile locale nu schimbă versiunea.

## Arborele apfel

Proiecte construite pe apfel. Fiecare vine ca propriul repo + formulă Homebrew.

| Proiect | Ce face | Instalare |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Rădăcina. CLI FoundationModels pe dispozitiv + server compatibil OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Client de chat pentru macOS: markdown în streaming, intrare/ieșire vocală, analiza imaginilor cu Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Acțiuni AI în bara de meniu pe clipboard: rezumat, traducere, rescriere. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Overlay AI instantaneu: apeși o tastă, întrebi, primești răspunsul, închizi. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Notepad cu formule - AI pe dispozitiv ca funcție inline într-o celulă. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP-uri optimizate pentru bugetul de tokeni al ferestrei mici de pe dispozitiv: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspector de debug în SwiftUI: cronologia cererilor, vizualizator de protocol MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX care adaugă un registru MCP persistent + configurare TOML peste `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI de etichetare a conținutului pe dispozitiv: dai text pe intrare, primești tag-uri/subiecte/emoții. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Pachet Swift pentru instrumentele ecosistemului: descoperă, pornește și primește streaming de la un `apfel --serve` local. | Swift Package |

## Proiecte ale comunității

Ai construit ceva pe apfel? Deschide un issue și poate fi adăugat aici.

| Proiect | Ce face | Linkuri |
|---------|-------------|-------|
| **apfelclaw** de [@julianYaman](https://github.com/julianYaman) | Agent AI local care citește fișiere, calendar, e-mail și starea Mac-ului prin instrumente doar în citire | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** de [@bhaskarvilles](https://github.com/bhaskarvilles) | Interfață de chat în browser care comunică cu `apfel --serve` prin API-ul compatibil OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** de [@lucaspwo](https://github.com/lucaspwo) | Wrapper pentru Claude Code care pune apfel ca backend local printr-un mic proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** de [@hasit](https://github.com/hasit) | Manager de aplicații pentru aplicații shell locale construite în jurul apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** de [@eggsy](https://github.com/eggsy) | Extensie pentru bara de comenzi Raycast: întrebări, traducere, explicarea fișierelor și directoarelor, istoric de conversații, system prompturi personalizate. Pe dispozitiv prin apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuții

Issue-urile și PR-urile sunt binevenite în orice repo `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR-urile de la agenți AI sunt în regulă. Citește `CLAUDE.md` din repo, rulează testele, menționează instrumentul într-un trailer `Co-Authored-By`. Același standard ca pentru oameni: cod curat, teste care trec, limite sincere. Cel mai prietenos punct de intrare pentru agenți: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([reguli de contribuție](https://apfel-mcp.franzai.com/#contribute)).

## Licență

[MIT](../LICENSE)
