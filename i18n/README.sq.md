<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Përkthyer nga [README në anglisht](../README.md). Versioni anglisht është autoritativ.

# apfel

### AI falas që e ke tashmë në Mac-un tënd.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac-et me Apple Silicon vijnë me një LLM të integruar përmes [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` e ekspozon si mjet UNIX dhe si server lokal të përputhshëm me OpenAI. 100% në pajisje. Pa çelësa API, pa cloud.

| Mënyra | Komanda | Çfarë merr |
|--------|---------|------------|
| Mjet UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Përgjigje të përshtatshme për pipe, bashkëngjitje skedarësh, dalje JSON, kode daljeje |
| Server i përputhshëm me OpenAI | `apfel --serve` | Backend lokal `http://localhost:11434/v1` si zëvendësim i drejtpërdrejtë për SDK-të e OpenAI |

`apfel --chat` - REPL interaktiv.

[![Video demonstruese e apfel në terminal: komanda të vërteta, përgjigje të vërteta në pajisje (82 sekonda)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/sq/a/apfel-ai-tutorial/#video)

Thirrja e mjeteve (tool calling) funksionon në të gjitha kontekstet.

![apfel CLI](../screenshots/cli.png)

## Kërkesat dhe instalimi

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence e aktivizuar](https://support.apple.com/en-us/121115). Në macOS 27, Mac-et me çip M3 ose më të ri dhe 12 GB+ ekzekutojnë modelin më të madh të Apple në pajisje me dritare 8192 tokenësh; Mac-et M1/M2 dhe çdo Mac me macOS 26 kanë 4096. `apfel --model-info` të tregon tëndin.

```bash
brew install apfel
```

Përditësimi:

```bash
brew upgrade apfel
```

Ndërtimi nga burimi (Command Line Tools me SDK-në e macOS 27 / Swift 6.3, pa Xcode; binari funksionon në macOS 26 dhe 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap i së njëjtës ditë, Mint, mise, zgjidhja e problemeve: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | **Shqip** | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Fillim i shpejtë

### Mjet UNIX

Vendos në thonjëza të vetme prompt-et me `!` (zgjerimi i historikut në zsh/bash): `apfel 'Hello, Mac!'`.

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

### Server i përputhshëm me OpenAI

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

Detaje për shërbimin në sfond: [docs/background-service.md](../docs/background-service.md).

### Chat për provë të shpejtë

`apfel --chat` është një REPL i vogël për të provuar prompt-e ose serverë MCP. Për një aplikacion chat me ndërfaqe grafike, shih [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C del. Konteksti shkurtohet automatikisht ([docs/context-strategies.md](../docs/context-strategies.md)).

Kufizime që vlen t'i dish përpara se të shkruash skripte (dritarja e kontekstit sipas Mac-ut, guardrails, pa embeddings): [Kufizimet](../README.md#limitations).

## Demo

Skripte shell të vërteta që e mbështjellin `apfel`: `cmd` (nga anglishtja në komandë shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Janë të përfshira në binar - nuk duhet klonuar repo-ja. Shkruaji kudo nga ku e ke instaluar apfel (homebrew-core, tap ose burimi):

```bash
apfel demos ./apfel-demos
```

Kjo shkruan çdo demo (të ekzekutueshme) plus një `README.md` te `./apfel-demos`. Pastaj ekzekutoji që andej:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Ekzekuto sërish `apfel demos` pas `brew upgrade apfel` për t'i rifreskuar. Burimet: [`demo/`](../demo/). Udhëzime të detajuara dhe një funksion shell `cmd` për kopjim te `.zshrc` jotë: [docs/demos.md](../docs/demos.md).

## Mbështetja për mjetet MCP

Lidh serverë [Model Context Protocol](https://modelcontextprotocol.io/) me `--mcp`. apfel i zbulon, i thërret dhe kthen rezultatin.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Përdor `-q` për të fshehur informacionin e mjeteve.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Vjen me një kalkulator te [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Serverë MCP në distancë** (Streamable HTTP, specifikimi MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Siguria:** preferoje `APFEL_MCP_TOKEN` në vend të `--mcp-token` (ps aux). apfel refuzon bearer token-ët mbi `http://` pa enkriptim.

## apfel-run: shtresë opsionale konfigurimi

apfel vetë nuk ka skedar konfigurimi - flag-e + ndryshore mjedisi, si çdo mjet UNIX. Nëse do një konfigurim TOML (shumë MCP, profile, konfigurime ekipi në git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) është një wrapper MIT që e shton atë si zëvendësim të drejtpërdrejtë përmes `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Përputhshmëria me API-n e OpenAI

**URL bazë:** `http://localhost:11434/v1`

| Veçoria | Statusi | Shënime |
|---------|---------|---------|
| `POST /v1/chat/completions` | I mbështetur | Me streaming dhe pa streaming |
| `POST /v1/responses` | I mbështetur | API Responses e OpenAI: hyrje string/mesazh, `instructions`, streaming (sekuencë kanonike ngjarjesh), `text.format` (përfshirë `json_schema`), mjete funksioni (pa streaming). Veçoritë me gjendje (`previous_response_id`, `store: true`, `background`, `reasoning`, mjete të hostuara) kthejnë 501 të sinqerta |
| `POST /v1/responses/input_tokens` | I mbështetur | Parallogaritje tokenësh (`client.responses.input_tokens.count(...)`): numërim i saktë nga tokenizuesi i Apple, pa gjenerim; 501 nën macOS 26.4 në vend të një vlerësimi. Shih [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | I mbështetur | Kthen `apple-foundationmodel` (i përgjithshëm, i parazgjedhuri) dhe `apple-foundationmodel-content-tagging` (etiketa, jo prozë). Shih [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | I mbështetur | Disponueshmëria e modelit, dritarja e kontekstit, gjuhët, aftësitë e raportuara të modelit (`capabilities`, `capabilities_reported`), varianti i modelit që shërben (`variant`, p.sh. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Vetëm për debug | Kërkon `--debug` |
| Tool calling | I mbështetur | Thirrja shkruhet përmes gjenerimit të drejtuar (`--tool-calling guided`, parazgjedhje) ose si JSON që serveri e analizon (`--tool-calling text`). Shih [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | I mbështetur | Injektim në system prompt; fence-t markdown hiqen nga dalja |
| `response_format: json_schema` | I mbështetur | Dalje e garantuar në përputhje me skemën përmes `DynamicGenerationSchema` të FoundationModels; funksionon me `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | I mbështetur | Përputhen me `GenerationOptions`. `top_p` është nucleus sampling; `temperature` nën 0.001 (përfshirë 0) përputhet me greedy (deterministik). Nëse `max_tokens` lihet pa vënë, përdoret dritarja e mbetur e kontekstit (semantikë OpenAI si zëvendësim i drejtpërdrejtë) - shih [Kufiri i parazgjedhur i përgjigjes](../README.md#default-response-cap-max_tokens) |
| `stream: true` | I mbështetur | SSE; chunk-u përfundimtar i përdorimit vetëm kur `stream_options: {"include_usage": true}` (sipas specifikimit të OpenAI) |
| `usage` | I mbështetur | Numërime reale nga tokenizuesi në macOS 26.4+ (vlerësim chars/4 më poshtë). macOS 27: llogaritja e vetë runtime-it përfshirë kornizën e chat-template të Apple (rreth 46 `prompt_tokens` shtesë për një prompt me një rresht); macOS 26: apfel numëron tekstin e mesazheve. Detaje te [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | I mbështetur | `stop`, `tool_calls`, `length` |
| Strategjitë e kontekstit | I mbështetur | Fushat shtesë `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | I mbështetur | Aktivizohet me `--cors` |
| `POST /v1/completions` | 501 | Completions-et e vjetra të tekstit nuk mbështeten |
| `POST /v1/embeddings` | 501 | Embeddings nuk disponohen në pajisje |
| `stop` | I mbështetur | Varg ose deri në 4 vargje; vetëm tekst i thjeshtë (400 me mjete në përdorim ose `json_object`/`json_schema`). Zbatohet në anën e daljes, njësoj me streaming dhe pa. Shih [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Refuzohen haptazi. `n=1` dhe `logprobs=false` pranohen si no-op |
| Multimodal (imazhe) | I mbështetur në macOS 27 | Pjesët `image_url` si data URL base64 shkojnë natyrshëm te modeli në pajisje (kufi 20 MB base64, ana më e gjatë zvogëlohet në 4096 px). URL-të `http(s)` në distancë dhe shtigjet e skedarëve japin gjithmonë 400 - apfel nuk merr kurrë imazhe dhe nuk lexon kurrë skedarë për një klient HTTP. Në macOS 26: 400 me gabim të qartë. Shih [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Header `Authorization` | I mbështetur | I detyrueshëm kur vendoset `--token`. Shih [docs/server-security.md](../docs/server-security.md) |

Specifikimi i plotë i API-t: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Kufiri i parazgjedhur i përgjigjes (`max_tokens`)

Kur `max_tokens` lihet pa vënë, **CLI dhe serveri i përputhshëm me OpenAI sillen njësoj**: vlera kalon si `nil` dhe modeli përdor çfarëdo hapësire që ka mbetur në dritaren e kontekstit. Kjo është semantika e OpenAI si zëvendësim i drejtpërdrejtë - pa konstante arbitrare rezervë.

Dritarja e kontekstit në pajisje mban hyrjen *dhe* daljen së bashku: **4096 tokenë në macOS 26 dhe në Mac-et M1/M2, 8192 tokenë në macOS 27 me çip M3 ose më të ri dhe 12 GB+**. apfel e lexon madhësinë reale gjatë ekzekutimit përmes `SystemLanguageModel.contextSize` - kontrollo tëndin me `apfel --model-info`. Nëse gjenerimi godet kufirin, përgjigjja mbaron pastër me `finish_reason: "length"` dhe kthehet përmbajtja e pjesshme (server: HTTP 200; CLI: dalje 0 me paralajmërim në stderr, ose dalje 8 me `--require-complete` - shih [docs/cli-reference.md](../docs/cli-reference.md)). Jepe `max_tokens` shprehimisht kur do një buxhet më të ngushtë vonese ose një kufi të njohur për klientin tënd.

### Shembuj

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

### Zgjedhja e një vlere

| Rasti i përdorimit                     | `max_tokens`  |
|----------------------------------------|---------------|
| Përgjigje me një fjalë / klasifikim    | 16 - 32       |
| Udhëzim me një rresht                  | 64 - 128      |
| Paragraf i shkurtër                    | 256 - 512     |
| Paragraf i gjatë / JSON i strukturuar  | 1024 - 2048   |
| Aq sa e lejon dritarja e kontekstit    | lëre pa vënë  |

Mbaje `input_tokens + max_tokens` rehat nën dritaren e kontekstit (4096 tokenë në macOS 26 dhe në Mac-et M1/M2, 8192 në macOS 27 me çip M3 ose më të ri dhe 12 GB+ (modeli AFM 3 Core Advanced i Apple)). Nëse vetë prompt-i e tejkalon dritaren, gjenerimi nuk mund të nisë dhe kërkesa dështon me `[context overflow]` (HTTP 400 / dalje CLI 4). Validuesi refuzon vlerat jopozitive (`max_tokens <= 0`).

### Barazia me CLI

CLI dhe serveri ndajnë një rregull të vetëm: e pavënë = përdor dritaren e mbetur. Pa konstante që të shkëputet. Mbishkruaje me `--max-tokens N` ose `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardrails lejuese për serverin

`apfel --serve --permissive` bën që serveri të përdorë guardrails `.permissiveContentTransformations` të Apple për **çdo kërkesë** që trajton procesi. I njëjti flag, e njëjta semantikë si `--permissive` i CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Nuk ka mbishkrim për kërkesë - vendos operatori i serverit për të gjithë procesin.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Kufizimet

| Kufizim | Detaje |
|---------|--------|
| Dritarja e kontekstit | **4096 tokenë në macOS 26 dhe në Mac-et M1/M2, 8192 tokenë në macOS 27 me çip M3 ose më të ri dhe 12 GB+** (hyrje + dalje së bashku). Nuk është konstante e fiksuar në kod - apfel lexon `SystemLanguageModel.contextSize` gjatë ekzekutimit; `apfel --model-info` shfaq vlerën aktuale |
| Platforma | macOS 26+, vetëm Apple Silicon |
| Modeli | Një model i vetëm në pajisje (~3B parametra), i ofruar si `apple-foundationmodel` (i përgjithshëm) dhe `apple-foundationmodel-content-tagging` (adaptori i Apple për etiketimin e përmbajtjes; pa mjete) |
| Guardrails | Sistemi i sigurisë i Apple mund të bllokojë prompt-e të padëmshme. `--permissive` ul rastet e rreme pozitive ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Shpejtësia | Në pajisje, jo në shkallë cloud - disa sekonda për përgjigje |
| Pa embeddings | Nuk disponohen në pajisje |
| Vizioni | Hyrja me imazhe i arrin modelit vetëm në macOS 27 (server: data URL; CLI: `-f photo.jpg` dhe imazhe me pipe, përveç tekstit OCR). Në macOS 26 imazhet janë vetëm tekst përmes OCR/klasifikimit. Përshkrimet e skenave nga modeli 3B janë të vrazhda - OCR mbetet kanali i besueshëm për leximin e tekstit të printuar |
| Të dhënat e trajnimit / data e prerjes së njohurive | Apple nuk ka publikuar një datë të saktë prerjeje për modelin në pajisje. Kur shtyhet ta tregojë, modeli **sajon një datë tjetër në çdo mostër** (p.sh. "October 2023", "April 2023"). Trajto si të pabesueshme të gjitha deklaratat e modelit për trajnimin e vet. |
| Pa datë aktuale dhe pa ndërgjegje në kohë reale | Modeli nuk e di datën e sotme dhe nuk ka qasje në rrjet ose orë. Nëse pyetet, ose do të refuzojë ose do të shpikë një datë. Injekto datën aktuale përmes system prompt kur aritmetika varet prej saj (shih zgjidhjen më poshtë). |

**Zgjidhje për prompt-e që varen nga data** - injekto datën aktuale si mesazh sistemi:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Shënim: edhe me datë të injektuar, modeli 3B mund të halucinojë prapë (sidomos kur pyetet drejtpërdrejt për prerjen e trajnimit të vet). Injektimi ndihmon prompt-et gjeneruese që *e përdorin* datën; nuk e mbisundon refleksin e modelit për të raportuar për veten.

Sfondi: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Dokumentacioni referues

Udhëzues për përdorimin e apfel nga [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - shih [docs/guides/index.md](../docs/guides/index.md). Të provuar empirikisht; provë e ekzekutueshme te [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalimi, zgjidhja e problemeve dhe konfigurimi i Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - çdo flag, kod daljeje dhe ndryshore mjedisi
- [docs/file-extraction.md](../docs/file-extraction.md) - nxjerrja e PDF / imazhi / teksti me `-f` dhe me pipe (OCR + kuptim imazhesh)
- [docs/background-service.md](../docs/background-service.md) - përdorimi i `brew services` dhe launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matrica e mbështetjes së `/v1/*` në thellësi
- [docs/server-security.md](../docs/server-security.md) - kontrollet e origjinës, CORS, tokenët dhe `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategjitë e shkurtimit të chat-it
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - përdorimi i MCP lokal dhe në distancë
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - sjellja e detajuar e thirrjes së mjeteve
- [docs/integrations.md](../docs/integrations.md) - integrime me mjete të palëve të treta (opencode, etj.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - rishikim lokal me apfel + një model i dytë edit/apply në VS Code
- [docs/demos.md](../docs/demos.md) - udhëzime më të gjata për demot shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - mbi 50 prompt-e reale me dalje të paredaktuar
- [docs/swift-library.md](../docs/swift-library.md) - paketa Swift `ApfelCore` për zhvilluesit pasues
- [docs/coreai-impact.md](../docs/coreai-impact.md) - pse apfel funksionon me FoundationModels dhe jo me Core AI të ri të Apple (pasuesi i Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel krahasuar me CLI-në `fm` të vetë Apple (macOS 27), veçori për veçori me numra të matur

## Arkitektura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Konkurrencë strikte e Swift 6.3. Tre target-e: `ApfelCore` (logjikë e pastër, e testueshme me unit test, e disponueshme edhe si produkt Swift Package - e lidhur te Dokumentacioni referues më sipër), `apfel` (CLI + server) dhe `apfel-tests` (ekzekutues në Swift të pastër, pa XCTest).

## Ndërtimi dhe testimi

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

`.version` është burimi i vetëm i së vërtetës. Vetëm `make release` rrit versionet. Ndërtimet lokale nuk e ndryshojnë versionin.

## Pema e apfel

Projekte të ndërtuara mbi apfel. Secili vjen si repo më vete + formulë Homebrew.

| Projekti | Çfarë bën | Instalimi |
|----------|-----------|-----------|
| [**apfel**](https://apfel.franzai.com) | Rrënja. CLI FoundationModels në pajisje + server i përputhshëm me OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Klient chat për macOS: markdown me streaming, hyrje/dalje zanore, analizë imazhesh me Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Veprime AI në menu bar mbi clipboard-in: përmbledhje, përkthim, rishkrim. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Overlay AI i çastit: shtyp një tast, pyet, merr përgjigje, mbylle. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bllok shënimesh me formula - AI në pajisje si funksion qelize brenda tekstit. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP të optimizuara për buxhetin e tokenëve në dritaren e vogël në pajisje: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspektor debug në SwiftUI: kronologji kërkesash, shfaqës i protokollit MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX që shton një regjistër të qëndrueshëm MCP + konfigurim TOML mbi `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI etiketimi përmbajtjeje në pajisje: jep tekst me pipe, merr etiketa/tema/emocione. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Paketë Swift për mjetet e ekosistemit: zbulo, nis dhe bëj streaming nga një `apfel --serve` lokal. | Swift Package |

## Projektet e komunitetit

Ke ndërtuar diçka mbi apfel? Hap një issue dhe mund të shtohet këtu.

| Projekti | Çfarë bën | Lidhjet |
|----------|-----------|---------|
| **apfelclaw** nga [@julianYaman](https://github.com/julianYaman) | Agjent AI lokal që lexon skedarë, kalendar, postë dhe gjendjen e Mac-ut përmes mjeteve vetëm për lexim | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** nga [@bhaskarvilles](https://github.com/bhaskarvilles) | Ndërfaqe chat në shfletues që komunikon me `apfel --serve` përmes API-t të përputhshëm me OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** nga [@lucaspwo](https://github.com/lucaspwo) | Wrapper i Claude Code që vendos apfel si backend lokal përmes një proxy të vogël Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** nga [@hasit](https://github.com/hasit) | Menaxher aplikacionesh për aplikacione shell lokale të ndërtuara rreth apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** nga [@eggsy](https://github.com/eggsy) | Zgjerim për shiritin e komandave Raycast: pyet, përkthe, shpjego skedarë dhe direktori, histori bisedash, system prompt-e të personalizuara. Në pajisje përmes CLI-t apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Kontribuimi

Issue-t dhe PR-të mirëpriten në çdo repo `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR-të nga agjentë AI janë të mirëpritura. Lexo `CLAUDE.md` të repo-s, ekzekuto testet, jep kredi për mjetin në një trailer `Co-Authored-By`. E njëjta kërkesë si për njerëzit: kod i pastër, teste që kalojnë, kufizime të sinqerta. Pika hyrëse më e përshtatshme për agjentë: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([rregullat e kontribuimit](https://apfel-mcp.franzai.com/#contribute)).

## Licenca

[MIT](../LICENSE)
