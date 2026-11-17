<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Traduït del [README en anglès](../README.md). La versió anglesa és la que preval.

# apfel

### La IA gratuïta que ja tens al teu Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Els Mac amb Apple Silicon porten un LLM integrat mitjançant [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` l'exposa com a eina UNIX i com a servidor local compatible amb OpenAI. 100% al dispositiu. Sense claus d'API, sense núvol.

| Mode | Ordre | Què obtens |
|------|-------|------------|
| Eina UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Respostes aptes per a pipes, fitxers adjunts, sortida JSON, codis de sortida |
| Servidor compatible amb OpenAI | `apfel --serve` | Backend local `http://localhost:11434/v1` per substituir directament en els SDK d'OpenAI |

`apfel --chat` - REPL interactiu.

[![Vídeo de demostració d'apfel al terminal: ordres reals, respostes reals al dispositiu (84 segons)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ca/a/apfel-ai-tutorial/#video)

La crida d'eines (tool calling) funciona en tots els contextos.

![apfel CLI](../screenshots/cli.png)

## Requisits i instal·lació

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence activada](https://support.apple.com/en-us/121115). A macOS 27, els Mac amb un xip M3 o més nou i 12 GB+ executen el model més gran d'Apple al dispositiu, amb una finestra de 8192 tokens; els Mac M1/M2 i tots els Mac amb macOS 26 tenen 4096. `apfel --model-info` mostra el teu.

```bash
brew install apfel
```

Actualitzar:

```bash
brew upgrade apfel
```

Compilar des del codi font (Command Line Tools amb el SDK de macOS 27 / Swift 6.3, sense Xcode; el binari funciona a macOS 26 i 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap del mateix dia, Mint, mise, resolució de problemes: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | **Català** | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Inici ràpid

### Eina UNIX

Posa entre cometes simples els prompts amb `!` (expansió de l'historial de zsh/bash): `apfel 'Hello, Mac!'`.

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

### Servidor compatible amb OpenAI

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

Detalls del servei en segon pla: [docs/background-service.md](../docs/background-service.md).

### Xat per provar ràpidament

`apfel --chat` és un petit REPL per provar prompts o servidors MCP. Per a una aplicació de xat amb interfície gràfica, mira [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C surt. El context es retalla automàticament ([docs/context-strategies.md](../docs/context-strategies.md)).

Limitacions que convé conèixer abans de fer scripts (finestra de context segons el Mac, guardrails, sense embeddings): [Limitacions](../README.md#limitations).

## Demos

Scripts de shell reals que envolten `apfel`: `cmd` (d'anglès a ordre de shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Vénen inclosos al binari - no cal clonar el repositori. Escriu-los allà on vulguis, des d'on hagis instal·lat apfel (homebrew-core, el tap o el codi font):

```bash
apfel demos ./apfel-demos
```

Això escriu totes les demos (executables) més un `README.md` a `./apfel-demos`. Després executa-les des d'allà:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Torna a executar `apfel demos` després de `brew upgrade apfel` per actualitzar-les. Fonts: [`demo/`](../demo/). Guies detallades i una funció de shell `cmd` per copiar i enganxar al teu `.zshrc`: [docs/demos.md](../docs/demos.md).

## Suport d'eines MCP

Connecta servidors [Model Context Protocol](https://modelcontextprotocol.io/) amb `--mcp`. apfel descobreix, invoca i retorna.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Usa `-q` per suprimir la informació de les eines.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Inclou una calculadora a [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Servidors MCP remots** (Streamable HTTP, especificació MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Seguretat:** prefereix `APFEL_MCP_TOKEN` a `--mcp-token` (ps aux). apfel rebutja els bearer tokens sobre `http://` en text pla.

## apfel-run: capa de configuració opcional

apfel en si no té fitxer de configuració - flags + variables d'entorn, com qualsevol eina UNIX. Si vols una configuració TOML (molts MCP, perfils, configuracions d'equip a git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) és un wrapper MIT que n'afegeix una mitjançant un reemplaçament directe amb `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilitat amb l'API d'OpenAI

**URL base:** `http://localhost:11434/v1`

| Funcionalitat | Estat | Notes |
|---------------|-------|-------|
| `POST /v1/chat/completions` | Compatible | Streaming i no streaming |
| `POST /v1/responses` | Compatible | API Responses d'OpenAI: entrada de cadena/missatge, `instructions`, streaming (seqüència d'esdeveniments canònica), `text.format` (inclòs `json_schema`), eines de funció (no streaming). Les funcionalitats amb estat (`previous_response_id`, `store: true`, `background`, `reasoning`, eines allotjades) retornen 501 honestos |
| `POST /v1/responses/input_tokens` | Compatible | Preavaluació de tokens (`client.responses.input_tokens.count(...)`): recompte exacte del tokenitzador d'Apple, sense generació; 501 per sota de macOS 26.4 en lloc d'una estimació. Vegeu [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Compatible | Retorna `apple-foundationmodel` (general, el predeterminat) i `apple-foundationmodel-content-tagging` (etiquetes, no prosa). Vegeu [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Compatible | Disponibilitat del model, finestra de context, idiomes, capacitats del model informades (`capabilities`, `capabilities_reported`), la variant del model que serveix (`variant`, p. ex. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Només depuració | Requereix `--debug` |
| Tool calling | Compatible | La crida s'escriu amb generació guiada (`--tool-calling guided`, per defecte) o com a JSON que el servidor analitza (`--tool-calling text`). Vegeu [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Compatible | Injecció al prompt de sistema; els blocs de codi markdown s'eliminen de la sortida |
| `response_format: json_schema` | Compatible | Sortida garantidament conforme a l'esquema mitjançant `DynamicGenerationSchema` de FoundationModels; funciona amb `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Compatible | Assignats a `GenerationOptions`. `top_p` és nucleus sampling; `temperature` per sota de 0.001 (0 inclòs) s'assigna a greedy (determinista). Si s'omet `max_tokens`, s'usa la finestra de context restant (semàntica d'OpenAI de substitució directa) - vegeu [Límit de resposta per defecte](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Compatible | SSE; el chunk final d'ús només amb `stream_options: {"include_usage": true}` (segons l'especificació d'OpenAI) |
| `usage` | Compatible | Recomptes reals del tokenitzador a macOS 26.4+ (estimació chars/4 per sota). macOS 27: el comptatge propi del runtime, incloent el marc de la plantilla de xat d'Apple (uns 46 `prompt_tokens` addicionals en un prompt d'una línia); macOS 26: apfel compta el text dels missatges. Detalls a [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Compatible | `stop`, `tool_calls`, `length` |
| Estratègies de context | Compatible | Camps d'extensió `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Compatible | S'activa amb `--cors` |
| `POST /v1/completions` | 501 | Les completions de text heretades no són compatibles |
| `POST /v1/embeddings` | 501 | Els embeddings no estan disponibles al dispositiu |
| `stop` | Compatible | Cadena o fins a 4 cadenes; només text pla (400 amb eines en abast o `json_object`/`json_schema`). S'aplica a la sortida, idèntic amb streaming i sense. Vegeu [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rebutjats explícitament. `n=1` i `logprobs=false` s'accepten com a no-op |
| Multimodal (imatges) | Compatible a macOS 27 | Les parts `image_url` com a data URL en base64 van al model del dispositiu de manera nativa (límit de 20 MB en base64, el costat més llarg es redueix a 4096 px). Els URL `http(s)` remots i les rutes de fitxer sempre donen 400 - apfel mai baixa imatges ni llegeix fitxers per a un client HTTP. A macOS 26: 400 amb un error clar. Vegeu [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Capçalera `Authorization` | Compatible | Obligatòria quan s'estableix `--token`. Vegeu [docs/server-security.md](../docs/server-security.md) |

Especificació completa de l'API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Límit de resposta per defecte (`max_tokens`)

Quan s'omet `max_tokens`, **la CLI i el servidor compatible amb OpenAI es comporten de manera idèntica**: el valor passa com a `nil` i el model usa l'espai que quedi a la finestra de context. Aquesta és la semàntica d'OpenAI de substitució directa - sense cap constant de reserva arbitrària.

La finestra de context al dispositiu conté entrada *i* sortida combinades: **4096 tokens a macOS 26 i als Mac M1/M2, 8192 tokens a macOS 27 amb un xip M3 o més nou i 12 GB+**. apfel llegeix la mida real en temps d'execució mitjançant `SystemLanguageModel.contextSize` - comprova la teva amb `apfel --model-info`. Si la generació arriba al límit, la resposta acaba netament amb `finish_reason: "length"` i es retorna el contingut parcial (servidor: HTTP 200; CLI: sortida 0 amb un avís a stderr, o sortida 8 amb `--require-complete` - vegeu [docs/cli-reference.md](../docs/cli-reference.md)). Passa `max_tokens` explícitament quan vulguis un pressupost de latència més ajustat o un límit conegut per al teu client.

### Exemples

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

### Triar un valor

| Cas d'ús                               | `max_tokens`  |
|----------------------------------------|---------------|
| Resposta d'una paraula / classificació | 16 - 32       |
| Instrucció d'una línia                 | 64 - 128      |
| Paràgraf curt                          | 256 - 512     |
| Paràgraf llarg / JSON estructurat      | 1024 - 2048   |
| Tant com permeti la finestra de context | omet-lo      |

Mantén `input_tokens + max_tokens` còmodament per sota de la finestra de context (4096 tokens a macOS 26 i als Mac M1/M2, 8192 a macOS 27 amb un xip M3 o més nou i 12 GB+ (el model AFM 3 Core Advanced d'Apple)). Si el prompt mateix supera la finestra, la generació no pot començar i la petició falla amb `[context overflow]` (HTTP 400 / sortida de la CLI 4). El validador rebutja els valors no positius (`max_tokens <= 0`).

### Paritat amb la CLI

La CLI i el servidor comparteixen una sola regla: omès = usa la finestra restant. Cap constant que es desviï. Sobreescriu-ho amb `--max-tokens N` o `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardrails permissius per al servidor

`apfel --serve --permissive` fa que el servidor usi els guardrails `.permissiveContentTransformations` d'Apple per a **cada petició** que gestiona el procés. Mateix flag, mateixa semàntica que el `--permissive` de la CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). No hi ha cap sobreescriptura per petició - l'operador del servidor decideix per a tot el procés.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitacions

| Restricció | Detall |
|------------|--------|
| Finestra de context | **4096 tokens a macOS 26 i als Mac M1/M2, 8192 tokens a macOS 27 amb un xip M3 o més nou i 12 GB+** (entrada + sortida combinades). No és una constant fixada al codi - apfel llegeix `SystemLanguageModel.contextSize` en temps d'execució; `apfel --model-info` mostra el valor actual |
| Plataforma | macOS 26+, només Apple Silicon |
| Model | Un sol model al dispositiu (~3B paràmetres), servit com a `apple-foundationmodel` (general) i `apple-foundationmodel-content-tagging` (l'adaptador d'etiquetatge de contingut d'Apple; sense eines) |
| Guardrails | El sistema de seguretat d'Apple pot bloquejar prompts inofensius. `--permissive` redueix els falsos positius ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Velocitat | Al dispositiu, no a escala de núvol - uns quants segons per resposta |
| Sense embeddings | No disponibles al dispositiu |
| Visió | L'entrada d'imatges només arriba al model a macOS 27 (servidor: data URL; CLI: `-f photo.jpg` i imatges per pipe, a més del text d'OCR). A macOS 26 les imatges són només text mitjançant OCR/classificació. Les descripcions d'escenes del model de 3B són toscos - l'OCR continua sent el canal fiable per llegir text imprès |
| Dades d'entrenament / data de tall del coneixement | Apple no ha publicat una data de tall precisa del model al dispositiu. Quan se l'empeny a donar-ne una, el model **confabula una data diferent a cada mostra** (p. ex. "October 2023", "April 2023"). Considera poc fiables totes les afirmacions del model sobre el seu propi entrenament. |
| Sense data actual ni consciència en temps real | El model no coneix la data d'avui i no té accés a la xarxa ni al rellotge. Si se li pregunta, es negarà a respondre o s'inventarà una data. Injecta la data actual mitjançant el prompt de sistema quan l'aritmètica en depengui (vegeu la solució alternativa més avall). |

**Solució alternativa per a prompts que depenen de la data** - injecta la data actual com a missatge de sistema:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Nota: fins i tot amb una data injectada, el model de 3B encara pot al·lucinar (sobretot si se li pregunta directament pel seu propi tall d'entrenament). La injecció ajuda els prompts generatius que *usen* la data; no anul·la el reflex del model d'informar sobre si mateix.

Context: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentació de referència

Guies per usar apfel des de [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - vegeu [docs/guides/index.md](../docs/guides/index.md). Provades empíricament; prova executable a [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instal·lació, resolució de problemes i configuració d'Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - cada flag, codi de sortida i variable d'entorn
- [docs/file-extraction.md](../docs/file-extraction.md) - extracció de PDF / imatge / text amb `-f` i per pipe (OCR + comprensió d'imatges)
- [docs/background-service.md](../docs/background-service.md) - ús de `brew services` i launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matriu de compatibilitat de `/v1/*` en profunditat
- [docs/server-security.md](../docs/server-security.md) - comprovacions d'origen, CORS, tokens i `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - estratègies de retall del xat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - ús d'MCP local i remot
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportament detallat de la crida d'eines
- [docs/integrations.md](../docs/integrations.md) - integracions d'eines de tercers (opencode, etc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revisió local amb apfel + un segon model d'edició/aplicació a VS Code
- [docs/demos.md](../docs/demos.md) - guies més llargues de les demos de shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - més de 50 prompts reals amb sortida sense editar
- [docs/swift-library.md](../docs/swift-library.md) - paquet Swift `ApfelCore` per a desenvolupadors posteriors
- [docs/coreai-impact.md](../docs/coreai-impact.md) - per què apfel funciona amb FoundationModels i no amb el nou Core AI d'Apple (el successor de Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel comparat amb la CLI `fm` d'Apple (macOS 27), funcionalitat per funcionalitat amb xifres mesurades

## Arquitectura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Concurrència estricta de Swift 6.3. Tres targets: `ApfelCore` (lògica pura, provable amb tests unitaris, també disponible com a producte de Swift Package - enllaçat a Documentació de referència més amunt), `apfel` (CLI + servidor) i `apfel-tests` (executor en Swift pur, sense XCTest).

## Compilar i provar

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

`.version` és l'única font de veritat. Només `make release` puja versions. Les compilacions locals no canvien la versió.

## L'arbre d'apfel

Projectes construïts sobre apfel. Cadascun s'entrega com a repositori propi + fórmula de Homebrew.

| Projecte | Què fa | Instal·lació |
|----------|--------|--------------|
| [**apfel**](https://apfel.franzai.com) | L'arrel. CLI de FoundationModels al dispositiu + servidor compatible amb OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Client de xat per a macOS: markdown en streaming, entrada/sortida de veu, anàlisi d'imatges amb Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Accions d'IA a la barra de menús sobre el porta-retalls: resumir, traduir, reescriure. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Superposició d'IA instantània: prem una tecla, pregunta, respon, descarta. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bloc de notes de fórmules - IA al dispositiu com a funció de cel·la en línia. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP optimitzats en pressupost de tokens per a la petita finestra del dispositiu: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspector de depuració en SwiftUI: cronologia de peticions, visor del protocol MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX que afegeix un registre MCP persistent + configuració TOML sobre `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI d'etiquetatge de contingut al dispositiu: entra text per pipe, obtén etiquetes/temes/emocions. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Paquet Swift per a eines de l'ecosistema: descobreix, llança i fes streaming d'un `apfel --serve` local. | Swift Package |

## Projectes de la comunitat

Has construït alguna cosa sobre apfel? Obre un issue i es pot afegir aquí.

| Projecte | Què fa | Enllaços |
|----------|--------|----------|
| **apfelclaw** de [@julianYaman](https://github.com/julianYaman) | Agent d'IA local que llegeix fitxers, calendari, correu i l'estat del Mac mitjançant eines de només lectura | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** de [@bhaskarvilles](https://github.com/bhaskarvilles) | Interfície de xat al navegador que parla amb `apfel --serve` mitjançant l'API compatible amb OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** de [@lucaspwo](https://github.com/lucaspwo) | Wrapper de Claude Code que posa apfel com a backend local mitjançant un petit proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** de [@hasit](https://github.com/hasit) | Gestor d'aplicacions per a aplicacions de shell locals construïdes al voltant d'apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** de [@eggsy](https://github.com/eggsy) | Extensió de la barra d'ordres de Raycast: pregunta, tradueix, explica fitxers i directoris, historial de converses, prompts de sistema personalitzats. Al dispositiu mitjançant la CLI d'apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuir

Els issues i els PR són benvinguts a qualsevol repositori `Arthur-Ficial/apfel*`.

**#agentswelcome** - Els PR d'agents d'IA estan bé. Llegeix el `CLAUDE.md` del repositori, executa els tests, reconeix l'eina en un trailer `Co-Authored-By`. Mateix nivell d'exigència que amb les persones: codi net, tests que passen, límits honestos. Punt d'entrada més amable per a agents: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([normes de contribució](https://apfel-mcp.franzai.com/#contribute)).

## Llicència

[MIT](../LICENSE)
