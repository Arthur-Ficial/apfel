<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Oversat fra den [engelske README](../README.md). Den engelske version er den gældende.

# apfel

### Den gratis AI, der allerede ligger på din Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macs med Apple Silicon leveres med en indbygget LLM via [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` gør den tilgængelig som et UNIX-værktøj og som en lokal OpenAI-kompatibel server. 100% on-device. Ingen API-nøgler, ingen cloud.

| Tilstand | Kommando | Hvad du får |
|------|---------|--------------|
| UNIX-værktøj | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-venlige svar, filvedhæftninger, JSON-output, exitkoder |
| OpenAI-kompatibel server | `apfel --serve` | Lokal drop-in-backend på `http://localhost:11434/v1` til OpenAI-SDK'er |

`apfel --chat` - interaktiv REPL.

Tool calling virker i alle kontekster.

![apfel CLI](../screenshots/cli.png)

## Krav & installation

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence aktiveret](https://support.apple.com/en-us/121115). På macOS 27 kører Macs med en M3 eller nyere chip og 12 GB+ Apples større on-device-model med et vindue på 8192 tokens; M1/M2-Macs og alle Macs på macOS 26 har 4096. `apfel --model-info` viser din.

```bash
brew install apfel
```

Opdater:

```bash
brew upgrade apfel
```

Byg fra kildekode (Command Line Tools med macOS 27 SDK / Swift 6.3, ingen Xcode; binæren kører på macOS 26 og 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, same-day tap, Mint, mise, fejlfinding: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | **Dansk** | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Hurtig start

### UNIX-værktøj

Sæt prompts med `!` i enkelte anførselstegn (history-udvidelse i zsh/bash): `apfel 'Hello, Mac!'`.

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

Detaljer om baggrundstjenesten: [docs/background-service.md](../docs/background-service.md).

### Chat til hurtig test

`apfel --chat` er en lille REPL til at teste prompts eller MCP-servere. Til en chat-app med GUI, se [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C afslutter. Konteksten beskæres automatisk ([docs/context-strategies.md](../docs/context-strategies.md)).

Begrænsninger, du bør kende, før du scripter mod den (kontekstvindue pr. Mac, guardrails, ingen embeddings): [Begrænsninger](../README.md#limitations).

## Demoer

Rigtige shell-scripts, der omslutter `apfel`: `cmd` (engelsk til shell-kommando), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. De er indbygget i binæren - ingen repo-klon nødvendig. Skriv dem ud, hvor du end har installeret apfel fra (homebrew-core, tappen eller kildekoden):

```bash
apfel demos ./apfel-demos
```

Det skriver alle demoer (kørbare) plus en `README.md` til `./apfel-demos`. Kør dem derefter derfra:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Kør `apfel demos` igen efter `brew upgrade apfel` for at opdatere. Kilder: [`demo/`](../demo/). Gennemgange og en `cmd`-shell-funktion til copy-paste i din `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP-værktøjsunderstøttelse

Tilslut [Model Context Protocol](https://modelcontextprotocol.io/)-servere med `--mcp`. apfel finder, kalder og returnerer.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Brug `-q` for at undertrykke værktøjsinfo.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Leveres med en lommeregner i [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Eksterne MCP-servere** (Streamable HTTP, MCP-spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Sikkerhed:** brug helst `APFEL_MCP_TOKEN` frem for `--mcp-token` (ps aux). apfel afviser bearer-tokens over ukrypteret `http://`.

## apfel-run: valgfrit konfigurationslag

apfel selv har ingen konfigurationsfil - flag + miljøvariabler, som ethvert UNIX-værktøj. Hvis du vil have en TOML-konfiguration (mange MCP'er, profiler, teamkonfigurationer i git), er [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) en MIT-wrapper, der tilføjer en via `execve`-drop-in.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI-API-kompatibilitet

**Base-URL:** `http://localhost:11434/v1`

| Funktion | Status | Bemærkninger |
|---------|--------|-------|
| `POST /v1/chat/completions` | Understøttet | Streaming + ikke-streaming |
| `POST /v1/responses` | Understøttet | OpenAI Responses API: string-/message-input, `instructions`, streaming (kanonisk eventrækkefølge), `text.format` (inkl. `json_schema`), function tools (ikke-streaming). Tilstandsfulde funktioner (`previous_response_id`, `store: true`, `background`, `reasoning`, hostede værktøjer) returnerer ærlige 501'ere |
| `POST /v1/responses/input_tokens` | Understøttet | Token-preflight (`client.responses.input_tokens.count(...)`): præcis optælling med Apples tokenizer, uden generering; 501 under macOS 26.4 i stedet for et estimat. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Understøttet | Returnerer `apple-foundationmodel` |
| `GET /health` | Understøttet | Modeltilgængelighed, kontekstvindue, sprog, rapporterede modelegenskaber (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Kun debug | Kræver `--debug` |
| Tool calling | Understøttet | Native `ToolDefinition` + JSON-detektion. Se [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Understøttet | Injektion via systemprompten; markdown-fences fjernes fra outputtet |
| `response_format: json_schema` | Understøttet | Garanteret skemakonformt output via FoundationModels `DynamicGenerationSchema`; virker med `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Understøttet | Mappet til `GenerationOptions`. `top_p` er nucleus sampling; `temperature` under 0.001 (0 inkluderet) mappes til greedy (deterministisk). Udelades `max_tokens`, bruges det resterende kontekstvindue (drop-in OpenAI-semantik) - se [Standardgrænse for svar](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Understøttet | SSE; sidste usage-chunk kun med `stream_options: {"include_usage": true}` (efter OpenAI-spec) |
| `usage` | Understøttet | Reelle tokenizer-optællinger på macOS 26.4+ (derunder et estimat tegn/4). macOS 27: runtimens egen optælling inkl. Apples chat-template-indramning (ca. 46 ekstra `prompt_tokens` på en enlinjes prompt); macOS 26: apfel tæller beskedteksten. Detaljer i [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Understøttet | `stop`, `tool_calls`, `length` |
| Kontekststrategier | Understøttet | Udvidelsesfelterne `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Understøttet | Aktivér med `--cors` |
| `POST /v1/completions` | 501 | Ældre tekstfuldførelser understøttes ikke |
| `POST /v1/embeddings` | 501 | Embeddings er ikke tilgængelige on-device |
| `stop` | Understøttet | Streng eller op til 4 strenge; kun ren tekst (400 med værktøjer i scope eller `json_object`/`json_schema`). Anvendes på outputsiden, identisk ved streaming og ikke-streaming. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Afvises eksplicit. `n=1` og `logprobs=false` accepteres som no-ops |
| Multimodal (billeder) | Understøttet på macOS 27 | `image_url`-dele som base64-data-URL'er går native til on-device-modellen (grænse 20 MB base64, længste side nedskaleret til 4096 px). Eksterne `http(s)`-URL'er og filstier er altid 400 - apfel henter aldrig billeder og læser aldrig filer for en HTTP-klient. På macOS 26: 400 med en tydelig fejl. Se [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization`-header | Understøttet | Påkrævet, når `--token` er sat. Se [docs/server-security.md](../docs/server-security.md) |

Fuld API-spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Standardgrænse for svar (`max_tokens`)

Når `max_tokens` udelades, **opfører CLI og OpenAI-kompatibel server sig ens**: værdien sendes videre som `nil`, og modellen bruger den plads, der er tilbage i kontekstvinduet. Det er drop-in OpenAI-semantik - ingen vilkårlig fallback-konstant.

Det on-device kontekstvindue rummer input *og* output tilsammen: **4096 tokens på macOS 26 og på M1/M2-Macs, 8192 tokens på macOS 27 med en M3 eller nyere chip og 12 GB+**. apfel læser den faktiske størrelse ved kørsel via `SystemLanguageModel.contextSize` - tjek din med `apfel --model-info`. Hvis genereringen løber ind i loftet, slutter svaret rent med `finish_reason: "length"`, og det delvise indhold returneres (server: HTTP 200; CLI: exit 0 med en advarsel på stderr, eller exit 8 med `--require-complete` - se [docs/cli-reference.md](../docs/cli-reference.md)). Angiv `max_tokens` eksplicit, hvis du vil have et strammere latensbudget eller en kendt grænse for din klient.

### Eksempler

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

### Vælg en værdi

| Anvendelse                             | `max_tokens`  |
|----------------------------------------|---------------|
| Enkeltords- / klassifikationssvar      | 16 - 32       |
| Enlinjes instruktion                   | 64 - 128      |
| Kort afsnit                            | 256 - 512     |
| Langt afsnit / struktureret JSON       | 1024 - 2048   |
| Så langt som kontekstvinduet tillader  | udelad        |

Hold `input_tokens + max_tokens` komfortabelt under kontekstvinduet (4096 tokens på macOS 26 og på M1/M2-Macs, 8192 på macOS 27 med en M3 eller nyere chip og 12 GB+ (Apples model AFM 3 Core Advanced)). Overskrider selve prompten vinduet, kan genereringen ikke starte, og forespørgslen fejler med `[context overflow]` (HTTP 400 / CLI-exit 4). Validatoren afviser ikke-positive værdier (`max_tokens <= 0`).

### CLI-paritet

CLI og server deler én regel: udeladt = brug det resterende vindue. Ingen konstant, der kan drive. Tilsidesæt med `--max-tokens N` eller `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails til serveren

`apfel --serve --permissive` får serveren til at bruge Apples `.permissiveContentTransformations`-guardrails for **hver forespørgsel**, processen håndterer. Samme flag, samme semantik som CLI'ens `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Der er ingen tilsidesættelse pr. forespørgsel - serveroperatøren bestemmer for hele processen.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Begrænsninger

| Begrænsning | Detalje |
|------------|--------|
| Kontekstvindue | **4096 tokens på macOS 26 og på M1/M2-Macs, 8192 tokens på macOS 27 med en M3 eller nyere chip og 12 GB+** (input + output tilsammen). Ikke en hårdkodet konstant - apfel læser `SystemLanguageModel.contextSize` ved kørsel; `apfel --model-info` udskriver den aktuelle værdi |
| Platform | macOS 26+, kun Apple Silicon |
| Model | Én model (`apple-foundationmodel`, ~3B parametre on-device), kan ikke konfigureres |
| Guardrails | Apples sikkerhedssystem kan blokere harmløse prompts. `--permissive` reducerer falske positiver ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Hastighed | On-device, ikke cloud-skala - nogle sekunder pr. svar |
| Ingen embeddings | Ikke tilgængelige on-device |
| Vision | Billedinput når kun modellen på macOS 27 (server: data-URL'er; CLI: `-f photo.jpg` og pipede billeder, oven i OCR-teksten). På macOS 26 er billeder kun tekst via OCR/klassifikation. 3B-modellens scenebeskrivelser er grove - OCR er stadig den pålidelige kanal til at læse tryk |
| Træningsdata / vidensgrænse | Apple har ikke offentliggjort en præcis vidensgrænse for on-device-modellen. Presset til at nævne en **opfinder modellen en ny dato ved hver prøve** (fx "oktober 2023", "april 2023"). Betragt alle modellens selvoplysninger om sin egen træning som upålidelige. |
| Ingen aktuel dato eller realtidsbevidsthed | Modellen kender ikke dagens dato og har ingen netværks- eller urtilgang. Spurgt vil den enten afvise eller opfinde en dato. Giv den aktuelle dato via systemprompten, når en udregning afhænger af den (se workaround nedenfor). |

**Workaround til datoafhængige prompts** - giv den aktuelle dato som systembesked:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Bemærk: selv med en indsat dato kan 3B-modellen stadig hallucinere (især hvis man spørger direkte om dens egen træningsgrænse). Indsprøjtningen hjælper generative prompts, der *bruger* datoen; den overstyrer ikke modellens refleks til selvoplysning.

Baggrund: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referencedokumentation

Guider til at bruge apfel fra [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - se [docs/guides/index.md](../docs/guides/index.md). Testet empirisk; kørbart bevis på [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - installation, fejlfinding og opsætning af Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - alle flag, exitkoder og miljøvariabler
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` og pipet udtræk af PDF / billede / tekst (OCR + billedforståelse)
- [docs/background-service.md](../docs/background-service.md) - brug af `brew services` og launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - supportmatrix for `/v1/*` i dybden
- [docs/server-security.md](../docs/server-security.md) - origin-tjek, CORS, tokens og `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategier til beskæring af chatten
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokal og ekstern MCP-brug
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - detaljeret tool-calling-adfærd
- [docs/integrations.md](../docs/integrations.md) - integrationer med tredjepartsværktøjer (opencode osv.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokal review med apfel + en anden edit-/apply-model i VS Code
- [docs/demos.md](../docs/demos.md) - længere gennemgange af shell-demoerne
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ rigtige prompts med uredigeret output
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` til downstream-udviklere
- [docs/coreai-impact.md](../docs/coreai-impact.md) - hvorfor apfel kører på FoundationModels og ikke på Apples nye Core AI (efterfølgeren til Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel sammenlignet med Apples egen `fm`-CLI (macOS 27), funktion for funktion med målte tal

## Arkitektur

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 streng concurrency. Tre targets: `ApfelCore` (ren logik, unit-testbar, også tilgængelig som Swift Package-produkt - linket ovenfor under Referencedokumentation), `apfel` (CLI + server) og `apfel-tests` (ren Swift-runner, ingen XCTest).

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

`.version` er den eneste sandhedskilde. Kun `make release` hæver versioner. Lokale builds ændrer ikke versionen.

## apfel-træet

Projekter bygget på apfel. Hvert udkommer som sit eget repo + Homebrew-formel.

| Projekt | Hvad det gør | Installation |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Roden. On-device FoundationModels-CLI + OpenAI-kompatibel server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS-chatklient: streaming markdown, tale ind/ud, billedanalyse med Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | AI-handlinger i menulinjen på udklipsholderen: opsummer, oversæt, omskriv. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Øjeblikkeligt AI-overlay: tryk på en tast, spørg, svar, luk. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formelnotesblok - on-device AI som inline-cellefunktion. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokenbudget-optimerede MCP'er til det lille on-device-vindue: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI-debuginspektør: forespørgselstidslinje, MCP-protokolviser, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-wrapper, der tilføjer et vedvarende MCP-register + TOML-konfiguration oven på `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | On-device CLI til indholdstagging: pipe tekst ind, få tags/emner/følelser ud. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-pakke til økosystemværktøjer: find, start og stream fra en lokal `apfel --serve`. | Swift Package |

## Community-projekter

Har du bygget noget oven på apfel? Opret et issue, så kan det blive tilføjet her.

| Projekt | Hvad det gør | Links |
|---------|-------------|-------|
| **apfelclaw** af [@julianYaman](https://github.com/julianYaman) | Lokal AI-agent, der læser filer, kalender, mail og Mac-status via skrivebeskyttede værktøjer | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** af [@bhaskarvilles](https://github.com/bhaskarvilles) | Browserbaseret chat-UI, der taler med `apfel --serve` via den OpenAI-kompatible API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** af [@lucaspwo](https://github.com/lucaspwo) | Claude Code-wrapper, der bruger apfel som lokal backend via en lille Anthropic-OpenAI-proxy | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** af [@hasit](https://github.com/hasit) | App-manager til lokale shell-apps bygget omkring apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** af [@eggsy](https://github.com/eggsy) | Raycast-kommandolinjeudvidelse: spørg, oversæt, forklar filer og mapper, samtalehistorik, egne systemprompts. On-device via apfel-CLI'en. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Bidrag

Issues og PR'er er velkomne i alle `Arthur-Ficial/apfel*`-repos.

**#agentswelcome** - PR'er fra AI-agenter er fine. Læs repoets `CLAUDE.md`, kør testene, kreditér værktøjet i en `Co-Authored-By`-trailer. Samme standard som for mennesker: ren kode, beståede tests, ærlige grænser. Mest agentvenlige indgang: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([regler for bidrag](https://apfel-mcp.franzai.com/#contribute)).

## Licens

[MIT](../LICENSE)
