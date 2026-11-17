<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Översatt från den [engelska README](../README.md). Den engelska versionen är den gällande.

# apfel

### Den gratis AI:n som redan finns på din Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macar med Apple Silicon levereras med en inbyggd LLM via [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` gör den tillgänglig som ett UNIX-verktyg och som en lokal OpenAI-kompatibel server. 100% on-device. Inga API-nycklar, inget moln.

| Läge | Kommando | Vad du får |
|------|---------|--------------|
| UNIX-verktyg | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-vänliga svar, filbilagor, JSON-utdata, exitkoder |
| OpenAI-kompatibel server | `apfel --serve` | Lokal drop-in-backend på `http://localhost:11434/v1` för OpenAI-SDK:er |

`apfel --chat` - interaktiv REPL.

[![Demovideo av apfel i terminalen: riktiga kommandon, riktiga svar direkt på enheten (82 sekunder)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/sv/a/apfel-ai-tutorial/#video)

Tool calling fungerar i alla sammanhang.

![apfel CLI](../screenshots/cli.png)

## Krav & installation

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence aktiverat](https://support.apple.com/en-us/121115). På macOS 27 kör Macar med M3 eller nyare chip och 12 GB+ Apples större on-device-modell med ett fönster på 8192 tokens; M1/M2-Macar och alla Macar på macOS 26 har 4096. `apfel --model-info` visar ditt.

```bash
brew install apfel
```

Uppdatera:

```bash
brew upgrade apfel
```

Bygg från källkod (Command Line Tools med macOS 27 SDK / Swift 6.3, ingen Xcode; binären körs på macOS 26 och 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, felsökning: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | **Svenska** | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Snabbstart

### UNIX-verktyg

Sätt prompts med `!` inom enkla citattecken (history-expansion i zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-kompatibel server

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

Detaljer om bakgrundstjänsten: [docs/background-service.md](../docs/background-service.md).

### Chatt för snabb testning

`apfel --chat` är en liten REPL för att testa prompts eller MCP-servrar. För en chattapp med GUI, se [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C avslutar. Kontexten trimmas automatiskt ([docs/context-strategies.md](../docs/context-strategies.md)).

Begränsningar att känna till innan du skriptar mot den (kontextfönster per Mac, guardrails, inga embeddings): [Begränsningar](../README.md#limitations).

## Demos

Riktiga shellskript som omsluter `apfel`: `cmd` (engelska till shellkommando), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. De är inbyggda i binären - ingen repo-klon behövs. Skriv ut dem där du installerade apfel ifrån (homebrew-core, tappen eller källkoden):

```bash
apfel demos ./apfel-demos
```

Det skriver varje demo (körbar) plus en `README.md` till `./apfel-demos`. Kör dem sedan därifrån:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Kör `apfel demos` igen efter `brew upgrade apfel` för att uppdatera. Källor: [`demo/`](../demo/). Genomgångar och en `cmd`-shellfunktion att kopiera in i din `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP-verktygsstöd

Anslut [Model Context Protocol](https://modelcontextprotocol.io/)-servrar med `--mcp`. apfel upptäcker, anropar och returnerar.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Använd `-q` för att dölja verktygsinfo.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Levereras med en miniräknare i [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Fjärr-MCP-servrar** (Streamable HTTP, MCP-spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Säkerhet:** föredra `APFEL_MCP_TOKEN` framför `--mcp-token` (ps aux). apfel vägrar bearer-tokens över okrypterad `http://`.

## apfel-run: valfritt konfigurationslager

apfel självt har ingen konfigurationsfil - flaggor + miljövariabler, som vilket UNIX-verktyg som helst. Vill du ha en TOML-konfiguration (många MCP:er, profiler, teamkonfigurationer i git) är [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) en MIT-wrapper som lägger till en via `execve`-drop-in.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI-API-kompatibilitet

**Base-URL:** `http://localhost:11434/v1`

| Funktion | Status | Anmärkningar |
|---------|--------|-------|
| `POST /v1/chat/completions` | Stöds | Streaming + icke-streaming |
| `POST /v1/responses` | Stöds | OpenAI Responses API: sträng-/message-indata, `instructions`, streaming (kanonisk eventsekvens), `text.format` (inkl. `json_schema`), function tools (icke-streaming). Tillståndsbaserade funktioner (`previous_response_id`, `store: true`, `background`, `reasoning`, hostade verktyg) ger ärliga 501:or |
| `POST /v1/responses/input_tokens` | Stöds | Token-preflight (`client.responses.input_tokens.count(...)`): exakt räkning med Apples tokenizer, utan generering; 501 under macOS 26.4 i stället för en uppskattning. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Stöds | Returnerar `apple-foundationmodel` (allmän, standard) och `apple-foundationmodel-content-tagging` (etiketter, inte prosa). Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Stöds | Modelltillgänglighet, kontextfönster, språk, rapporterade modellegenskaper (`capabilities`, `capabilities_reported`), den betjänande modellvarianten (`variant`, t.ex. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Endast debug | Kräver `--debug` |
| Tool calling | Stöds | Anropet skrivs med styrd generering (`--tool-calling guided`, standard) eller som JSON som servern tolkar (`--tool-calling text`). Se [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Stöds | Injektion via systemprompten; markdown-fences tas bort från utdata |
| `response_format: json_schema` | Stöds | Garanterat schemakonform utdata via FoundationModels `DynamicGenerationSchema`; fungerar med `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Stöds | Mappat till `GenerationOptions`. `top_p` är nucleus sampling; `temperature` under 0.001 (0 inkluderat) mappas till greedy (deterministiskt). Utelämnas `max_tokens` används återstående kontextfönster (drop-in OpenAI-semantik) - se [Standardgräns för svar](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Stöds | SSE; avslutande usage-chunk endast med `stream_options: {"include_usage": true}` (enligt OpenAI-spec) |
| `usage` | Stöds | Verkliga tokenizer-räkningar på macOS 26.4+ (under det en uppskattning tecken/4). macOS 27: körtidens egen räkning inkl. Apples chat-template-inramning (cirka 46 extra `prompt_tokens` på en enradig prompt); macOS 26: apfel räknar meddelandetexten. Detaljer i [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Stöds | `stop`, `tool_calls`, `length` |
| Kontextstrategier | Stöds | Tilläggsfälten `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Stöds | Aktivera med `--cors` |
| `POST /v1/completions` | 501 | Äldre textkompletteringar stöds inte |
| `POST /v1/embeddings` | 501 | Embeddings är inte tillgängliga on-device |
| `stop` | Stöds | Sträng eller upp till 4 strängar; endast ren text (400 med verktyg i scope eller `json_object`/`json_schema`). Tillämpas på utdatasidan, identiskt vid streaming och icke-streaming. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Avvisas uttryckligen. `n=1` och `logprobs=false` accepteras som no-ops |
| Multimodal (bilder) | Stöds på macOS 27 | `image_url`-delar som base64-data-URL:er går native till on-device-modellen (gräns 20 MB base64, längsta sidan nedskalad till 4096 px). Fjärr-`http(s)`-URL:er och filsökvägar ger alltid 400 - apfel hämtar aldrig bilder och läser aldrig filer åt en HTTP-klient. På macOS 26: 400 med ett tydligt fel. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization`-header | Stöds | Krävs när `--token` är satt. Se [docs/server-security.md](../docs/server-security.md) |

Fullständig API-spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Standardgräns för svar (`max_tokens`)

När `max_tokens` utelämnas **beter sig CLI och OpenAI-kompatibel server identiskt**: värdet skickas vidare som `nil` och modellen använder det utrymme som finns kvar i kontextfönstret. Det är drop-in OpenAI-semantik - ingen godtycklig reservkonstant.

Det on-device kontextfönstret rymmer indata *och* utdata tillsammans: **4096 tokens på macOS 26 och på M1/M2-Macar, 8192 tokens på macOS 27 med M3 eller nyare chip och 12 GB+**. apfel läser den verkliga storleken vid körning via `SystemLanguageModel.contextSize` - kontrollera ditt med `apfel --model-info`. Om genereringen når taket slutar svaret rent med `finish_reason: "length"` och det partiella innehållet returneras (server: HTTP 200; CLI: exit 0 med en varning på stderr, eller exit 8 med `--require-complete` - se [docs/cli-reference.md](../docs/cli-reference.md)). Ange `max_tokens` uttryckligen om du vill ha en snävare latensbudget eller en känd gräns för din klient.

### Exempel

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

### Välja ett värde

| Användningsfall                        | `max_tokens`  |
|----------------------------------------|---------------|
| Enordssvar / klassificering            | 16 - 32       |
| Enradig instruktion                    | 64 - 128      |
| Kort stycke                            | 256 - 512     |
| Långt stycke / strukturerad JSON       | 1024 - 2048   |
| Så långt kontextfönstret tillåter      | utelämna      |

Håll `input_tokens + max_tokens` med god marginal under kontextfönstret (4096 tokens på macOS 26 och på M1/M2-Macar, 8192 på macOS 27 med M3 eller nyare chip och 12 GB+ (Apples modell AFM 3 Core Advanced)). Om själva prompten överskrider fönstret kan genereringen inte starta och begäran misslyckas med `[context overflow]` (HTTP 400 / CLI-exit 4). Valideraren avvisar icke-positiva värden (`max_tokens <= 0`).

### CLI-paritet

CLI och server delar en regel: utelämnat = använd återstående fönster. Ingen konstant som kan glida isär. Åsidosätt med `--max-tokens N` eller `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails för servern

`apfel --serve --permissive` får servern att använda Apples `.permissiveContentTransformations`-guardrails för **varje begäran** som processen hanterar. Samma flagga, samma semantik som CLI:ns `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Det finns ingen åsidosättning per begäran - serveroperatören bestämmer för hela processen.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Begränsningar

| Begränsning | Detalj |
|------------|--------|
| Kontextfönster | **4096 tokens på macOS 26 och på M1/M2-Macar, 8192 tokens på macOS 27 med M3 eller nyare chip och 12 GB+** (indata + utdata tillsammans). Ingen hårdkodad konstant - apfel läser `SystemLanguageModel.contextSize` vid körning; `apfel --model-info` skriver ut det aktuella värdet |
| Plattform | macOS 26+, endast Apple Silicon |
| Modell | En modell på enheten (~3B parametrar), tillgänglig som `apple-foundationmodel` (allmän) och `apple-foundationmodel-content-tagging` (Apples adapter för innehållstaggning; inga verktyg) |
| Guardrails | Apples säkerhetssystem kan blockera harmlösa prompts. `--permissive` minskar falska positiva ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Hastighet | On-device, inte molnskala - några sekunder per svar |
| Inga embeddings | Inte tillgängliga on-device |
| Vision | Bildindata når modellen endast på macOS 27 (server: data-URL:er; CLI: `-f photo.jpg` och pipade bilder, utöver OCR-texten). På macOS 26 är bilder endast text via OCR/klassificering. 3B-modellens scenbeskrivningar är grova - OCR är fortfarande den pålitliga kanalen för att läsa tryck |
| Träningsdata / kunskapsgräns | Apple har inte publicerat någon exakt kunskapsgräns för on-device-modellen. När den pressas att nämna en **hittar modellen på ett nytt datum vid varje försök** (t.ex. "oktober 2023", "april 2023"). Betrakta all självrapportering från modellen om dess egen träning som opålitlig. |
| Inget aktuellt datum eller realtidsmedvetenhet | Modellen känner inte till dagens datum och har ingen nätverks- eller klockåtkomst. Tillfrågad kommer den antingen att vägra eller hitta på ett datum. Mata in aktuellt datum via systemprompten när en beräkning beror på det (se workaround nedan). |

**Workaround för datumberoende prompts** - mata in aktuellt datum som systemmeddelande:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Obs: även med ett inmatat datum kan 3B-modellen fortfarande hallucinera (särskilt när man frågar direkt om dess egen träningsgräns). Inmatningen hjälper generativa prompts som *använder* datumet; den åsidosätter inte modellens reflex att rapportera om sig själv.

Bakgrund: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referensdokumentation

Guider för att använda apfel från [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - se [docs/guides/index.md](../docs/guides/index.md). Empiriskt testade; körbart bevis på [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - installation, felsökning och uppsättning av Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - varje flagga, exitkod och miljövariabel
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` och pipad extraktion av PDF / bild / text (OCR + bildförståelse)
- [docs/background-service.md](../docs/background-service.md) - användning av `brew services` och launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - supportmatris för `/v1/*` på djupet
- [docs/server-security.md](../docs/server-security.md) - origin-kontroller, CORS, tokens och `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategier för trimning av chatten
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokal och fjärr-MCP-användning
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - detaljerat tool-calling-beteende
- [docs/integrations.md](../docs/integrations.md) - integrationer med tredjepartsverktyg (opencode m.fl.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokal granskning med apfel + en andra edit-/apply-modell i VS Code
- [docs/demos.md](../docs/demos.md) - längre genomgångar av shell-demona
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ riktiga prompts med oredigerad utdata
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` för downstream-utvecklare
- [docs/coreai-impact.md](../docs/coreai-impact.md) - varför apfel körs på FoundationModels och inte på Apples nya Core AI (efterträdaren till Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel jämfört med Apples egen `fm`-CLI (macOS 27), funktion för funktion med uppmätta siffror

## Arkitektur

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strikt concurrency. Tre targets: `ApfelCore` (ren logik, enhetstestbar, även tillgänglig som Swift Package-produkt - länkad ovan under Referensdokumentation), `apfel` (CLI + server) och `apfel-tests` (ren Swift-runner, ingen XCTest).

## Build & Test

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

`.version` är den enda sanningskällan. Bara `make release` höjer versioner. Lokala byggen ändrar inte versionen.

## apfel-trädet

Projekt byggda på apfel. Vart och ett levereras som egen repo + Homebrew-formel.

| Projekt | Vad det gör | Installation |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Roten. On-device FoundationModels-CLI + OpenAI-kompatibel server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS-chattklient: streaming markdown, tal in/ut, bildanalys med Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | AI-åtgärder i menyraden för urklipp: sammanfatta, översätt, skriv om. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Omedelbar AI-overlay: tryck på en tangent, fråga, svar, stäng. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formelblock - on-device AI som inline-cellfunktion. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokenbudgetoptimerade MCP:er för det lilla on-device-fönstret: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI-debuginspektör: begärantidslinje, MCP-protokollvisare, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-wrapper som lägger till ett persistent MCP-register + TOML-konfiguration ovanpå `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | On-device CLI för innehållstaggning: pipa in text, få ut taggar/ämnen/känslor. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-paket för ekosystemverktyg: hitta, starta och streama från en lokal `apfel --serve`. | Swift Package |

## Communityprojekt

Har du byggt något ovanpå apfel? Öppna ett issue så kan det läggas till här.

| Projekt | Vad det gör | Länkar |
|---------|-------------|-------|
| **apfelclaw** av [@julianYaman](https://github.com/julianYaman) | Lokal AI-agent som läser filer, kalender, e-post och Mac-status via skrivskyddade verktyg | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** av [@bhaskarvilles](https://github.com/bhaskarvilles) | Webbläsarbaserat chatt-UI som pratar med `apfel --serve` via det OpenAI-kompatibla API:et | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** av [@lucaspwo](https://github.com/lucaspwo) | Claude Code-wrapper som byter in apfel som lokal backend via en liten Anthropic-OpenAI-proxy | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** av [@hasit](https://github.com/hasit) | Apphanterare för lokala shellappar byggda kring apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** av [@eggsy](https://github.com/eggsy) | Tillägg för Raycasts kommandorad: fråga, översätt, förklara filer och kataloger, konversationshistorik, egna systemprompts. On-device via apfel-CLI:n. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Bidra

Issues och PR:er är välkomna i alla `Arthur-Ficial/apfel*`-repon.

**#agentswelcome** - PR:er från AI-agenter är okej. Läs repots `CLAUDE.md`, kör testerna, ange verktyget i en `Co-Authored-By`-trailer. Samma ribba som för människor: ren kod, godkända tester, ärliga gränser. Mest agentvänliga ingången: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([regler för bidrag](https://apfel-mcp.franzai.com/#contribute)).

## Licens

[MIT](../LICENSE)
