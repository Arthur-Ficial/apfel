<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Přeloženo z [anglického README](../README.md). Závazná je anglická verze.

# apfel

### Bezplatná AI, která už je ve vašem Macu.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macy s Apple Silicon mají vestavěný LLM přes [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` ho zpřístupňuje jako nástroj UNIX a lokální server kompatibilní s OpenAI. 100% na zařízení. Žádné API klíče, žádný cloud.

| Režim | Příkaz | Co získáte |
|-------|--------|------------|
| Nástroj UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Odpovědi vhodné pro roury, přílohy souborů, výstup JSON, návratové kódy |
| Server kompatibilní s OpenAI | `apfel --serve` | Lokální backend `http://localhost:11434/v1` jako přímá náhrada pro SDK OpenAI |

`apfel --chat` - interaktivní REPL.

[![Ukázkové video apfel v terminálu: skutečné příkazy, skutečné odpovědi přímo v zařízení (82 sekund)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/cs/a/apfel-ai-tutorial/#video)

Volání nástrojů funguje ve všech kontextech.

![apfel CLI](../screenshots/cli.png)

## Požadavky a instalace

macOS 26 Tahoe+, Apple Silicon (M1+), [zapnuté Apple Intelligence](https://support.apple.com/en-us/121115). Na macOS 27 spouštějí Macy s čipem M3 nebo novějším a 12 GB+ větší model Apple na zařízení s oknem 8192 tokenů; Macy M1/M2 a každý Mac s macOS 26 mají 4096. `apfel --model-info` ukáže vaši hodnotu.

```bash
brew install apfel
```

Aktualizace:

```bash
brew upgrade apfel
```

Sestavení ze zdrojů (Command Line Tools s SDK macOS 27 / Swift 6.3, bez Xcode; binárka běží na macOS 26 i 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap se změnami téhož dne, Mint, mise, řešení potíží: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | **Čeština** | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Rychlý start

### Nástroj UNIX

Prompty obsahující `!` dávejte do jednoduchých uvozovek (expanze historie v zsh/bash): `apfel 'Hello, Mac!'`.

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

### Server kompatibilní s OpenAI

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

Podrobnosti o službě na pozadí: [docs/background-service.md](../docs/background-service.md).

### Chat pro rychlé testování

`apfel --chat` je malý REPL pro testování promptů nebo MCP serverů. Chatovací aplikaci s grafickým rozhraním najdete v [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C ukončí relaci. Kontext se ořezává automaticky ([docs/context-strategies.md](../docs/context-strategies.md)).

Omezení, která je dobré znát, než začnete psát skripty (kontextové okno podle Macu, guardrails, žádné embeddingy): [Omezení](../README.md#limitations).

## Ukázky

Skutečné shellové skripty obalující `apfel`: `cmd` (angličtina na shellový příkaz), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Jsou zabudované v binárce - bez klonování repozitáře. Zapište je tam, odkud jste apfel nainstalovali (homebrew-core, tap nebo zdroje):

```bash
apfel demos ./apfel-demos
```

Tím se do `./apfel-demos` zapíše každá ukázka (spustitelná) a `README.md`. Pak je spouštějte odtamtud:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Po `brew upgrade apfel` spusťte `apfel demos` znovu pro obnovení. Zdroje: [`demo/`](../demo/). Návody krok za krokem a shellová funkce `cmd` ke zkopírování do `.zshrc`: [docs/demos.md](../docs/demos.md).

## Podpora nástrojů MCP

Připojujte servery [Model Context Protocol](https://modelcontextprotocol.io/) pomocí `--mcp`. apfel nástroje objeví, zavolá je a vrátí výsledek.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Pomocí `-q` potlačíte informace o nástrojích.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Součástí je kalkulačka v [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Vzdálené servery MCP** (Streamable HTTP, specifikace MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Zabezpečení:** používejte `APFEL_MCP_TOKEN` místo `--mcp-token` (ps aux). apfel odmítá posílat bearer tokeny přes nešifrované `http://`.

## apfel-run: volitelná vrstva konfigurace

Samotný apfel nemá konfigurační soubor - příznaky a proměnné prostředí, jako každý nástroj UNIX. Pokud chcete konfiguraci v TOML (mnoho MCP, profily, týmové konfigurace v gitu), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) je obal pod licencí MIT, který ji přidává jako přímou náhradu přes `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Kompatibilita s API OpenAI

**Base URL:** `http://localhost:11434/v1`

| Funkce | Stav | Poznámky |
|--------|------|----------|
| `POST /v1/chat/completions` | Podporováno | Streaming i bez streamingu |
| `POST /v1/responses` | Podporováno | OpenAI Responses API: vstup jako string/zpráva, `instructions`, streaming (kanonická posloupnost událostí), `text.format` (včetně `json_schema`), funkční nástroje (bez streamingu). Stavové funkce (`previous_response_id`, `store: true`, `background`, `reasoning`, hostované nástroje) vracejí poctivé 501 |
| `POST /v1/responses/input_tokens` | Podporováno | Předběžný počet tokenů (`client.responses.input_tokens.count(...)`): přesný počet z tokenizéru Apple, bez generování; pod macOS 26.4 vrací 501 místo odhadu. Viz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Podporováno | Vrací `apple-foundationmodel` (obecný, výchozí) a `apple-foundationmodel-content-tagging` (štítky, ne souvislý text). Viz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Podporováno | Dostupnost modelu, kontextové okno, jazyky, hlášené schopnosti modelu (`capabilities`, `capabilities_reported`), varianta obsluhujícího modelu (`variant`, např. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Pouze ladění | Vyžaduje `--debug` |
| Volání nástrojů | Podporováno | Volání se zapisuje řízeným generováním (`--tool-calling guided`, výchozí) nebo jako JSON, který parsuje server (`--tool-calling text`). Viz [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Podporováno | Vložení do systémového promptu; ohrady markdownu se z výstupu odstraní |
| `response_format: json_schema` | Podporováno | Zaručený výstup odpovídající schématu přes FoundationModels `DynamicGenerationSchema`; funguje se `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Podporováno | Mapováno na `GenerationOptions`. `top_p` je nucleus sampling; `temperature` pod 0.001 (včetně 0) se mapuje na greedy (deterministické) vzorkování. Vynechání `max_tokens` použije zbývající kontextové okno (sémantika přímé náhrady OpenAI) - viz [Výchozí limit odpovědi](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Podporováno | SSE; závěrečný chunk s `usage` pouze s `stream_options: {"include_usage": true}` (podle specifikace OpenAI) |
| `usage` | Podporováno | Skutečné počty z tokenizéru na macOS 26.4+ (níže odhad znaky/4). macOS 27: vlastní účtování běhového prostředí včetně rámování chat šablony Apple (asi 46 dalších `prompt_tokens` u jednořádkového promptu); macOS 26: apfel počítá text zprávy. Podrobnosti v [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Podporováno | `stop`, `tool_calls`, `length` |
| Strategie kontextu | Podporováno | Rozšiřující pole `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Podporováno | Zapněte pomocí `--cors` |
| `POST /v1/completions` | 501 | Starší doplňování textu není podporováno |
| `POST /v1/embeddings` | 501 | Embeddingy nejsou na zařízení k dispozici |
| `stop` | Podporováno | String nebo až 4 stringy; pouze prostý text (400, pokud jsou ve hře nástroje nebo `json_object`/`json_schema`). Aplikuje se na straně výstupu, shodně při streamingu i bez něj. Viz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Výslovně odmítnuto. `n=1` a `logprobs=false` se přijímají jako bez efektu |
| Multimodalita (obrázky) | Podporováno na macOS 27 | Části `image_url` jako base64 data URL jdou nativně do modelu na zařízení (limit 20 MB base64, delší strana zmenšena na 4096 px). Vzdálené URL `http(s)` a cesty k souborům vždy dávají 400 - apfel nikdy nestahuje obrázky ani nečte soubory na žádost HTTP klienta. Na macOS 26: 400 s jasnou chybou. Viz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Hlavička `Authorization` | Podporováno | Vyžadována, je-li nastaveno `--token`. Viz [docs/server-security.md](../docs/server-security.md) |

Úplná specifikace API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Výchozí limit odpovědi (`max_tokens`)

Když je `max_tokens` vynecháno, **CLI i server kompatibilní s OpenAI se chovají shodně**: hodnota projde jako `nil` a model využije veškeré místo, které zbývá v kontextovém okně. Je to sémantika přímé náhrady OpenAI - žádná libovolná záložní konstanta.

Kontextové okno na zařízení pojme vstup *i* výstup dohromady: **4096 tokenů na macOS 26 a na Macích M1/M2, 8192 tokenů na macOS 27 s čipem M3 nebo novějším a 12 GB+**. apfel skutečnou velikost zjišťuje za běhu přes `SystemLanguageModel.contextSize` - vaši zjistíte pomocí `apfel --model-info`. Pokud generování narazí na strop, odpověď čistě skončí s `finish_reason: "length"` a vrátí se částečný obsah (server: HTTP 200; CLI: exit 0 s varováním na stderr, nebo exit 8 s `--require-complete` - viz [docs/cli-reference.md](../docs/cli-reference.md)). Zadejte `max_tokens` výslovně, když chcete přísnější rozpočet latence nebo známý limit pro svého klienta.

### Příklady

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

### Volba hodnoty

| Případ použití                         | `max_tokens`  |
|----------------------------------------|---------------|
| Jednoslovná odpověď / klasifikace      | 16 - 32       |
| Jednořádková instrukce                 | 64 - 128      |
| Krátký odstavec                        | 256 - 512     |
| Dlouhý odstavec / strukturovaný JSON   | 1024 - 2048   |
| Tolik, kolik kontextové okno dovolí    | vynechat      |

Držte `input_tokens + max_tokens` s pohodlnou rezervou pod kontextovým oknem (4096 tokenů na macOS 26 a na Macích M1/M2, 8192 na macOS 27 s čipem M3 nebo novějším a 12 GB+ (model AFM 3 Core Advanced od Apple)). Pokud samotný prompt okno překročí, generování nemůže začít a požadavek selže s `[context overflow]` (HTTP 400 / CLI exit 4). Validátor odmítá nekladné hodnoty (`max_tokens <= 0`).

### Shoda s CLI

CLI a server sdílejí jedno pravidlo: vynecháno = použij zbývající okno. Žádná konstanta, která by se mohla rozejít. Přepište pomocí `--max-tokens N` nebo `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permisivní guardrails pro server

`apfel --serve --permissive` způsobí, že server používá guardrails Apple `.permissiveContentTransformations` pro **každý požadavek** zpracovaný procesem. Stejný příznak, stejná sémantika jako `--permissive` v CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Přepsání na úrovni požadavku neexistuje - rozhoduje provozovatel serveru pro celý proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Omezení

| Omezení | Podrobnosti |
|---------|-------------|
| Kontextové okno | **4096 tokenů na macOS 26 a na Macích M1/M2, 8192 tokenů na macOS 27 s čipem M3 nebo novějším a 12 GB+** (vstup + výstup dohromady). Není to pevně zadaná konstanta - apfel čte `SystemLanguageModel.contextSize` za běhu; `apfel --model-info` vypíše aktuální hodnotu |
| Platforma | macOS 26+, pouze Apple Silicon |
| Model | Jeden model na zařízení (~3 mld parametrů), poskytovaný jako `apple-foundationmodel` (obecný) a `apple-foundationmodel-content-tagging` (adaptér Apple pro štítkování obsahu; bez nástrojů) |
| Guardrails | Bezpečnostní systém Apple může blokovat nezávadné prompty. `--permissive` snižuje počet falešných poplachů ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Rychlost | Na zařízení, ne v měřítku cloudu - několik sekund na odpověď |
| Žádné embeddingy | Na zařízení nejsou k dispozici |
| Vidění | Obrazový vstup se k modelu dostane pouze na macOS 27 (server: data URL; CLI: `-f photo.jpg` a obrázky přes rouru, navíc k textu z OCR). Na macOS 26 jsou obrázky pouze text přes OCR/klasifikaci. Popisy scén modelu 3B jsou hrubé - OCR zůstává spolehlivým kanálem pro čtení tisku |
| Trénovací data / hranice znalostí | Apple nezveřejnil přesné datum hranice znalostí modelu na zařízení. Když je model nucen ho uvést, **při každém vzorku si vymyslí jiné datum** (např. "October 2023", "April 2023"). Všechna sebehlášení modelu o jeho vlastním trénování považujte za nespolehlivá. |
| Žádné aktuální datum ani povědomí o reálném čase | Model nezná dnešní datum a nemá přístup k síti ani k hodinám. Při dotazu buď odmítne, nebo datum vymyslí. Pokud výpočet na datu závisí, vložte aktuální datum přes systémový prompt (viz řešení níže). |

**Řešení pro prompty závislé na datu** - vložte aktuální datum jako systémovou zprávu:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Poznámka: i s vloženým datem může model 3B stále halucinovat (zejména při přímém dotazu na hranici jeho vlastního trénování). Vložení pomáhá generativním promptům, které datum *používají*; nepřekoná reflex sebehlášení modelu.

Pozadí: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referenční dokumentace

Návody, jak používat apfel z [Pythonu](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - viz [docs/guides/index.md](../docs/guides/index.md). Empiricky otestováno; spustitelný důkaz v [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalace, řešení potíží a nastavení Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - každý příznak, návratový kód a proměnná prostředí
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` a extrakce PDF / obrázků / textu přes rouru (OCR + porozumění obrazu)
- [docs/background-service.md](../docs/background-service.md) - použití `brew services` a launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - podrobná matice podpory `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - kontroly origin, CORS, tokeny a `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategie ořezávání chatu
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokální a vzdálené použití MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - podrobné chování volání nástrojů
- [docs/integrations.md](../docs/integrations.md) - integrace nástrojů třetích stran (opencode atd.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokální revize s apfel + druhým modelem pro úpravy/aplikaci ve VS Code
- [docs/demos.md](../docs/demos.md) - delší návody k shellovým ukázkám
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ skutečných promptů s needitovaným výstupem
- [docs/swift-library.md](../docs/swift-library.md) - balíček Swift `ApfelCore` pro vývojáře
- [docs/coreai-impact.md](../docs/coreai-impact.md) - proč apfel běží na FoundationModels, a ne na novém Core AI od Apple (nástupci Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel v porovnání s vlastním CLI `fm` od Apple (macOS 27), funkci po funkci s naměřenými čísly

## Architektura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 se striktní souběžností. Tři targety: `ApfelCore` (čistá logika, testovatelná jednotkovými testy, dostupná i jako produkt Swift Package - odkaz v Referenční dokumentaci výše), `apfel` (CLI + server) a `apfel-tests` (čistý runner Swift, bez XCTest).

## Sestavení a testy

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

`.version` je jediný zdroj pravdy. Verze zvyšuje pouze `make release`. Lokální buildy verzi nemění.

## Strom apfel

Projekty postavené na apfel. Každý má vlastní repozitář a formuli Homebrew.

| Projekt | Co dělá | Instalace |
|---------|---------|-----------|
| [**apfel**](https://apfel.franzai.com) | Kořen. CLI FoundationModels na zařízení + server kompatibilní s OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Chatovací klient pro macOS: streaming markdownu, hlasový vstup/výstup, analýza obrázků přes Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Akce AI v liště nabídek nad schránkou: shrnutí, překlad, přepis. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Okamžitý překryv s AI: stiskněte klávesu, zeptejte se, odpověď, zavřít. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Poznámkový blok se vzorci - AI na zařízení jako funkce buňky přímo v textu. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP optimalizovaná na rozpočet tokenů pro malé okno na zařízení: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Ladicí inspektor v SwiftUI: časová osa požadavků, prohlížeč protokolu MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Obal UNIX přidávající trvalý registr MCP + konfiguraci TOML nad `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI pro značkování obsahu na zařízení: pošlete text rourou, dostanete tagy/témata/emoce. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Balíček Swift pro nástroje ekosystému: objevte, spusťte a streamujte z lokálního `apfel --serve`. | Swift Package |

## Projekty komunity

Postavili jste něco na apfel? Otevřete issue a projekt lze přidat sem.

| Projekt | Co dělá | Odkazy |
|---------|---------|--------|
| **apfelclaw** od [@julianYaman](https://github.com/julianYaman) | Lokální AI agent, který čte soubory, kalendář, poštu a stav Macu přes nástroje pouze pro čtení | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** od [@bhaskarvilles](https://github.com/bhaskarvilles) | Chatovací rozhraní v prohlížeči komunikující s `apfel --serve` přes API kompatibilní s OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** od [@lucaspwo](https://github.com/lucaspwo) | Obal kolem Claude Code, který přes malý proxy Anthropic-OpenAI nahradí backend lokálním apfel | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** od [@hasit](https://github.com/hasit) | Správce aplikací pro lokální shellové aplikace postavené kolem apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** od [@eggsy](https://github.com/eggsy) | Rozšíření příkazového řádku Raycast: ptejte se, překládejte, vysvětlujte soubory a adresáře, historie konverzací, vlastní systémové prompty. Na zařízení přes apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Přispívání

Issues a PR vítány v jakémkoli repozitáři `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR od AI agentů jsou v pořádku. Přečtěte si `CLAUDE.md` repozitáře, spusťte testy, uveďte nástroj v traileru `Co-Authored-By`. Stejná laťka jako pro lidi: čistý kód, procházející testy, poctivá omezení. Pro agenty nejpřívětivější vstupní bod: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([pravidla přispívání](https://apfel-mcp.franzai.com/#contribute)).

## Licence

[MIT](../LICENSE)
