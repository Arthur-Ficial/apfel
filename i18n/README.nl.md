<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> Vertaald vanuit de [Engelse README](../README.md). De Engelse versie is leidend.

# apfel

### De gratis AI die al op je Mac zit.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macs met Apple Silicon hebben een ingebouwd LLM via [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` maakt het beschikbaar als UNIX-tool en als lokale OpenAI-compatibele server. 100% on-device. Geen API-sleutels, geen cloud.

| Modus | Commando | Wat je krijgt |
|------|---------|--------------|
| UNIX-tool | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-vriendelijke antwoorden, bestandsbijlagen, JSON-uitvoer, exitcodes |
| OpenAI-compatibele server | `apfel --serve` | Lokale drop-in backend op `http://localhost:11434/v1` voor OpenAI-SDK's |

`apfel --chat` - interactieve REPL.

[![Demovideo van apfel in de terminal: echte commando's, echte antwoorden op het apparaat (82 seconden)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/nl/a/apfel-ai-tutorial/#video)

Tool calling werkt in alle contexten.

![apfel CLI](../screenshots/cli.png)

## Vereisten & installatie

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ingeschakeld](https://support.apple.com/en-us/121115). Op macOS 27 draaien Macs met een M3 of nieuwere chip en 12 GB+ Apples grotere on-device model met een venster van 8192 tokens; M1/M2-Macs en elke Mac op macOS 26 hebben 4096. `apfel --model-info` toont de jouwe.

```bash
brew install apfel
```

Bijwerken:

```bash
brew upgrade apfel
```

Bouwen vanuit de broncode (Command Line Tools met de macOS 27 SDK / Swift 6.3, geen Xcode; de binary draait op macOS 26 en 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, probleemoplossing: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | **Nederlands** | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Snelstart

### UNIX-tool

Zet prompts met `!` tussen enkele aanhalingstekens (history-expansie in zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-compatibele server

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

Details over de achtergrondservice: [docs/background-service.md](../docs/background-service.md).

### Chat om snel te testen

`apfel --chat` is een kleine REPL om prompts of MCP-servers te testen. Voor een chat-app met GUI, zie [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C sluit af. De context wordt automatisch ingekort ([docs/context-strategies.md](../docs/context-strategies.md)).

Beperkingen die je moet kennen voordat je ertegen scriptt (contextvenster per Mac, guardrails, geen embeddings): [Beperkingen](../README.md#limitations).

## Demo's

Echte shellscripts die `apfel` omhullen: `cmd` (Engels naar shellcommando), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Ze zitten in de binary - geen repo-clone nodig. Schrijf ze weg op de plek waar je apfel hebt geïnstalleerd (homebrew-core, de tap of de broncode):

```bash
apfel demos ./apfel-demos
```

Dat schrijft elke demo (uitvoerbaar) plus een `README.md` naar `./apfel-demos`. Voer ze daarna vandaar uit:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Draai `apfel demos` opnieuw na `brew upgrade apfel` om te verversen. Bronnen: [`demo/`](../demo/). Walkthroughs en een `cmd`-shellfunctie om te kopiëren voor je `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP-toolondersteuning

Koppel [Model Context Protocol](https://modelcontextprotocol.io/)-servers met `--mcp`. apfel ontdekt, roept aan en geeft terug.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Gebruik `-q` om toolinfo te onderdrukken.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Wordt geleverd met een rekenmachine in [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Externe MCP-servers** (Streamable HTTP, MCP-spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Beveiliging:** gebruik liever `APFEL_MCP_TOKEN` dan `--mcp-token` (ps aux). apfel weigert bearer-tokens over onversleutelde `http://`.

## apfel-run: optionele configuratielaag

apfel zelf heeft geen configuratiebestand - flags + omgevingsvariabelen, zoals elke UNIX-tool. Wil je een TOML-config (veel MCP's, profielen, teamconfigs in git), dan is [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) een MIT-wrapper die er een toevoegt als `execve`-drop-in.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI-API-compatibiliteit

**Base-URL:** `http://localhost:11434/v1`

| Functie | Status | Opmerkingen |
|---------|--------|-------|
| `POST /v1/chat/completions` | Ondersteund | Streaming + niet-streaming |
| `POST /v1/responses` | Ondersteund | OpenAI Responses API: string-/message-invoer, `instructions`, streaming (canonieke eventvolgorde), `text.format` (incl. `json_schema`), function tools (niet-streaming). Stateful functies (`previous_response_id`, `store: true`, `background`, `reasoning`, gehoste tools) geven eerlijke 501's |
| `POST /v1/responses/input_tokens` | Ondersteund | Token-preflight (`client.responses.input_tokens.count(...)`): exacte telling met Apples tokenizer, zonder generatie; 501 onder macOS 26.4 in plaats van een schatting. Zie [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Ondersteund | Geeft `apple-foundationmodel` (algemeen, de standaard) en `apple-foundationmodel-content-tagging` (labels, geen proza) terug. Zie [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Ondersteund | Modelbeschikbaarheid, contextvenster, talen, gerapporteerde modelmogelijkheden (`capabilities`, `capabilities_reported`), de serverende modelvariant (`variant`, bijv. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Alleen debug | Vereist `--debug` |
| Tool calling | Ondersteund | De aanroep wordt geschreven via guided generation (`--tool-calling guided`, standaard) of als JSON die de server parseert (`--tool-calling text`). Zie [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Ondersteund | Injectie via de systeemprompt; markdown-fences worden uit de uitvoer gehaald |
| `response_format: json_schema` | Ondersteund | Gegarandeerd schemaconforme uitvoer via FoundationModels `DynamicGenerationSchema`; werkt met `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Ondersteund | Gemapt op `GenerationOptions`. `top_p` is nucleus sampling; `temperature` onder 0.001 (0 inbegrepen) wordt gemapt op greedy (deterministisch). Zonder `max_tokens` geldt het resterende contextvenster (drop-in OpenAI-semantiek) - zie [Standaardlimiet voor antwoorden](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Ondersteund | SSE; laatste usage-chunk alleen bij `stream_options: {"include_usage": true}` (volgens de OpenAI-spec) |
| `usage` | Ondersteund | Echte tokenizer-tellingen op macOS 26.4+ (daaronder een schatting tekens/4). macOS 27: de eigen telling van de runtime incl. Apples chat-template-omkadering (ongeveer 46 extra `prompt_tokens` bij een prompt van een regel); macOS 26: apfel telt de berichttekst. Details in [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Ondersteund | `stop`, `tool_calls`, `length` |
| Contextstrategieën | Ondersteund | Extensievelden `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Ondersteund | Inschakelen met `--cors` |
| `POST /v1/completions` | 501 | Legacy-tekstaanvullingen niet ondersteund |
| `POST /v1/embeddings` | 501 | Embeddings zijn on-device niet beschikbaar |
| `stop` | Ondersteund | String of maximaal 4 strings; alleen platte tekst (400 met tools in scope of `json_object`/`json_schema`). Toegepast aan de uitvoerkant, identiek bij streaming en niet-streaming. Zie [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Expliciet geweigerd. `n=1` en `logprobs=false` worden als no-ops geaccepteerd |
| Multimodaal (afbeeldingen) | Ondersteund op macOS 27 | `image_url`-onderdelen als base64-data-URL's gaan native naar het on-device model (limiet 20 MB base64, langste zijde verkleind tot 4096 px). Externe `http(s)`-URL's en bestandspaden zijn altijd 400 - apfel haalt nooit afbeeldingen op en leest nooit bestanden voor een HTTP-client. Op macOS 26: 400 met een duidelijke foutmelding. Zie [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization`-header | Ondersteund | Vereist wanneer `--token` is ingesteld. Zie [docs/server-security.md](../docs/server-security.md) |

Volledige API-spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Standaardlimiet voor antwoorden (`max_tokens`)

Als `max_tokens` ontbreekt, **gedragen CLI en OpenAI-compatibele server zich identiek**: de waarde gaat door als `nil` en het model gebruikt de ruimte die nog over is in het contextvenster. Dit is drop-in OpenAI-semantiek - geen willekeurige terugvalconstante.

Het on-device contextvenster bevat invoer *en* uitvoer samen: **4096 tokens op macOS 26 en op M1/M2-Macs, 8192 tokens op macOS 27 met een M3 of nieuwere chip en 12 GB+**. apfel leest de echte grootte tijdens runtime via `SystemLanguageModel.contextSize` - controleer de jouwe met `apfel --model-info`. Loopt de generatie tegen de grens aan, dan eindigt het antwoord netjes met `finish_reason: "length"` en wordt de gedeeltelijke inhoud teruggegeven (server: HTTP 200; CLI: exit 0 met een waarschuwing op stderr, of exit 8 met `--require-complete` - zie [docs/cli-reference.md](../docs/cli-reference.md)). Geef `max_tokens` expliciet mee als je een krapper latentiebudget of een bekende limiet voor je client wilt.

### Voorbeelden

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

### Een waarde kiezen

| Toepassing                             | `max_tokens`  |
|----------------------------------------|---------------|
| Eenwoord- / classificatieantwoord      | 16 - 32       |
| Instructie van een regel               | 64 - 128      |
| Korte alinea                           | 256 - 512     |
| Lange alinea / gestructureerde JSON    | 1024 - 2048   |
| Zo lang als het contextvenster toestaat | weglaten     |

Houd `input_tokens + max_tokens` ruim onder het contextvenster (4096 tokens op macOS 26 en op M1/M2-Macs, 8192 op macOS 27 met een M3 of nieuwere chip en 12 GB+ (Apples model AFM 3 Core Advanced)). Past de prompt zelf al niet in het venster, dan kan de generatie niet starten en faalt het verzoek met `[context overflow]` (HTTP 400 / CLI-exit 4). De validator weigert niet-positieve waarden (`max_tokens <= 0`).

### CLI-pariteit

CLI en server delen een regel: weggelaten = resterend venster gebruiken. Geen constante die kan afwijken. Overschrijf met `--max-tokens N` of `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails voor de server

`apfel --serve --permissive` laat de server Apples `.permissiveContentTransformations`-guardrails gebruiken voor **elk verzoek** dat het proces afhandelt. Dezelfde flag, dezelfde semantiek als `--permissive` van de CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Er is geen override per verzoek - de serverbeheerder beslist voor het hele proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Beperkingen

| Beperking | Detail |
|------------|--------|
| Contextvenster | **4096 tokens op macOS 26 en op M1/M2-Macs, 8192 tokens op macOS 27 met een M3 of nieuwere chip en 12 GB+** (invoer + uitvoer samen). Geen hardgecodeerde constante - apfel leest `SystemLanguageModel.contextSize` tijdens runtime; `apfel --model-info` toont de actuele waarde |
| Platform | macOS 26+, alleen Apple Silicon |
| Model | Een on-device model (~3B parameters), aangeboden als `apple-foundationmodel` (algemeen) en `apple-foundationmodel-content-tagging` (Apples content-tagging-adapter; geen tools) |
| Guardrails | Apples veiligheidssysteem kan onschuldige prompts blokkeren. `--permissive` vermindert valse positieven ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Snelheid | On-device, geen cloudschaal - een paar seconden per antwoord |
| Geen embeddings | On-device niet beschikbaar |
| Vision | Afbeeldingsinvoer bereikt het model alleen op macOS 27 (server: data-URL's; CLI: `-f photo.jpg` en gepipete afbeeldingen, bovenop de OCR-tekst). Op macOS 26 zijn afbeeldingen alleen tekst via OCR/classificatie. De scenebeschrijvingen van het 3B-model zijn grof - OCR blijft het betrouwbare kanaal om gedrukte tekst te lezen |
| Trainingsdata / kennisgrens | Apple heeft geen exacte kennisgrens voor het on-device model gepubliceerd. Als je het dwingt er een te noemen, **verzint het model bij elke poging een andere datum** (bijv. "oktober 2023", "april 2023"). Beschouw alle uitspraken van het model over zijn eigen training als onbetrouwbaar. |
| Geen actuele datum of realtimebesef | Het model kent de datum van vandaag niet en heeft geen toegang tot netwerk of klok. Gevraagd zal het weigeren of een datum verzinnen. Geef de huidige datum mee via de systeemprompt wanneer een berekening ervan afhangt (zie de workaround hieronder). |

**Workaround voor datumafhankelijke prompts** - geef de huidige datum mee als systeembericht:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Let op: ook met een meegegeven datum kan het 3B-model nog hallucineren (vooral wanneer je direct naar de eigen trainingsgrens vraagt). De injectie helpt bij generatieve prompts die de datum *gebruiken*; ze overschrijft de zelfrapportage-reflex van het model niet.

Achtergrond: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referentiedocumentatie

Handleidingen om apfel te gebruiken vanuit [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - zie [docs/guides/index.md](../docs/guides/index.md). Empirisch getest; draaiend bewijs op [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - installatie, probleemoplossing en het instellen van Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - elke flag, exitcode en omgevingsvariabele
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` en gepipete extractie van PDF / afbeelding / tekst (OCR + beeldbegrip)
- [docs/background-service.md](../docs/background-service.md) - gebruik van `brew services` en launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - de ondersteuningsmatrix voor `/v1/*` in detail
- [docs/server-security.md](../docs/server-security.md) - origin-controles, CORS, tokens en `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategieën voor het inkorten van de chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokaal en extern MCP-gebruik
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - gedetailleerd tool-calling-gedrag
- [docs/integrations.md](../docs/integrations.md) - integraties met tools van derden (opencode, enz.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokale review met apfel + een tweede edit-/apply-model in VS Code
- [docs/demos.md](../docs/demos.md) - uitgebreidere walkthroughs van de shelldemo's
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ echte prompts met ongewijzigde uitvoer
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` voor downstream-ontwikkelaars
- [docs/coreai-impact.md](../docs/coreai-impact.md) - waarom apfel op FoundationModels draait en niet op Apples nieuwe Core AI (de opvolger van Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel vergeleken met Apples eigen `fm`-CLI (macOS 27), functie voor functie met gemeten cijfers

## Architectuur

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strikte concurrency. Drie targets: `ApfelCore` (pure logica, unit-testbaar, ook beschikbaar als Swift Package-product - hierboven gelinkt onder Referentiedocumentatie), `apfel` (CLI + server) en `apfel-tests` (pure Swift-runner, geen XCTest).

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

`.version` is de enige bron van waarheid. Alleen `make release` verhoogt versies. Lokale builds wijzigen de versie niet.

## De apfel-boom

Projecten die op apfel voortbouwen. Elk verschijnt als eigen repo + Homebrew-formule.

| Project | Wat het doet | Installatie |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | De wortel. On-device FoundationModels-CLI + OpenAI-compatibele server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS-chatclient: streaming markdown, spraak in/uit, beeldanalyse met Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | AI-acties in de menubalk voor het klembord: samenvatten, vertalen, herschrijven. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Directe AI-overlay: toets indrukken, vragen, antwoord, sluiten. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formuleblok - on-device AI als inline celfunctie. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Op tokenbudget geoptimaliseerde MCP's voor het kleine on-device venster: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI-debuginspector: verzoektijdlijn, MCP-protocolviewer, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-wrapper die een persistent MCP-register + TOML-config toevoegt bovenop `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | On-device CLI voor contenttagging: tekst erin pipen, tags/onderwerpen/emoties eruit. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-package voor ecosysteemtools: een lokale `apfel --serve` vinden, starten en ervan streamen. | Swift Package |

## Communityprojecten

Iets gebouwd op basis van apfel? Open een issue en het kan hier worden toegevoegd.

| Project | Wat het doet | Links |
|---------|-------------|-------|
| **apfelclaw** door [@julianYaman](https://github.com/julianYaman) | Lokale AI-agent die bestanden, agenda, mail en Mac-status leest via alleen-lezen tools | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** door [@bhaskarvilles](https://github.com/bhaskarvilles) | Browsergebaseerde chat-UI die via de OpenAI-compatibele API met `apfel --serve` praat | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** door [@lucaspwo](https://github.com/lucaspwo) | Claude Code-wrapper die apfel als lokale backend inzet via een kleine Anthropic-OpenAI-proxy | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** door [@hasit](https://github.com/hasit) | App-manager voor lokale shell-apps rond apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** door [@eggsy](https://github.com/eggsy) | Extensie voor de Raycast-opdrachtbalk: vragen, vertalen, bestanden en mappen uitleggen, gespreksgeschiedenis, eigen systeemprompts. On-device via de apfel-CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Bijdragen

Issues en PR's zijn welkom in elke `Arthur-Ficial/apfel*`-repo.

**#agentswelcome** - PR's van AI-agents zijn prima. Lees de `CLAUDE.md` van de repo, draai de tests, vermeld de tool in een `Co-Authored-By`-trailer. Dezelfde lat als voor mensen: schone code, slagende tests, eerlijke grenzen. Meest agentvriendelijke startpunt: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([regels voor bijdragen](https://apfel-mcp.franzai.com/#contribute)).

## Licentie

[MIT](../LICENSE)
