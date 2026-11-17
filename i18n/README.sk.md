<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Preložené z [anglického README](../README.md). Záväzná je anglická verzia.

# apfel

### Bezplatná AI, ktorá už je vo vašom Macu.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macy s Apple Silicon majú vstavaný LLM cez [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` ho sprístupňuje ako nástroj UNIX a lokálny server kompatibilný s OpenAI. 100 % na zariadení. Žiadne API kľúče, žiadny cloud.

| Režim | Príkaz | Čo získate |
|-------|--------|------------|
| Nástroj UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Odpovede vhodné pre rúry, prílohy súborov, výstup JSON, návratové kódy |
| Server kompatibilný s OpenAI | `apfel --serve` | Lokálny backend `http://localhost:11434/v1` ako priama náhrada pre SDK OpenAI |

`apfel --chat` - interaktívny REPL.

[![Ukážkové video apfel v termináli: skutočné príkazy, skutočné odpovede priamo v zariadení (82 sekúnd)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/sk/a/apfel-ai-tutorial/#video)

Volanie nástrojov funguje vo všetkých kontextoch.

![apfel CLI](../screenshots/cli.png)

## Požiadavky a inštalácia

macOS 26 Tahoe+, Apple Silicon (M1+), [zapnuté Apple Intelligence](https://support.apple.com/en-us/121115). Na macOS 27 spúšťajú Macy s čipom M3 alebo novším a 12 GB+ väčší model Apple na zariadení s oknom 8192 tokenov; Macy M1/M2 a každý Mac s macOS 26 majú 4096. `apfel --model-info` ukáže vašu hodnotu.

```bash
brew install apfel
```

Aktualizácia:

```bash
brew upgrade apfel
```

Zostavenie zo zdrojov (Command Line Tools so SDK macOS 27 / Swift 6.3, bez Xcode; binárka beží na macOS 26 aj 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap so zmenami toho istého dňa, Mint, mise, riešenie problémov: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | **Slovenčina** | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Rýchly štart

### Nástroj UNIX

Prompty obsahujúce `!` dávajte do jednoduchých úvodzoviek (expanzia histórie v zsh/bash): `apfel 'Hello, Mac!'`.

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

### Server kompatibilný s OpenAI

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

Podrobnosti o službe na pozadí: [docs/background-service.md](../docs/background-service.md).

### Chat na rýchle testovanie

`apfel --chat` je malý REPL na testovanie promptov alebo MCP serverov. Chatovaciu aplikáciu s grafickým rozhraním nájdete v [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C ukončí reláciu. Kontext sa orezáva automaticky ([docs/context-strategies.md](../docs/context-strategies.md)).

Obmedzenia, ktoré je dobré poznať, kým začnete písať skripty (kontextové okno podľa Macu, guardrails, žiadne embeddingy): [Obmedzenia](../README.md#limitations).

## Ukážky

Skutočné shellové skripty obaľujúce `apfel`: `cmd` (angličtina na shellový príkaz), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Sú zabudované v binárke - bez klonovania repozitára. Zapíšte ich tam, odkiaľ ste apfel nainštalovali (homebrew-core, tap alebo zdroje):

```bash
apfel demos ./apfel-demos
```

Tým sa do `./apfel-demos` zapíše každá ukážka (spustiteľná) a `README.md`. Potom ich spúšťajte odtiaľ:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Po `brew upgrade apfel` spustite `apfel demos` znova na obnovenie. Zdroje: [`demo/`](../demo/). Návody krok za krokom a shellová funkcia `cmd` na skopírovanie do `.zshrc`: [docs/demos.md](../docs/demos.md).

## Podpora nástrojov MCP

Pripájajte servery [Model Context Protocol](https://modelcontextprotocol.io/) pomocou `--mcp`. apfel nástroje objaví, zavolá ich a vráti výsledok.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Pomocou `-q` potlačíte informácie o nástrojoch.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Súčasťou je kalkulačka v [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Vzdialené servery MCP** (Streamable HTTP, špecifikácia MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Zabezpečenie:** používajte `APFEL_MCP_TOKEN` namiesto `--mcp-token` (ps aux). apfel odmieta posielať bearer tokeny cez nešifrované `http://`.

## apfel-run: voliteľná vrstva konfigurácie

Samotný apfel nemá konfiguračný súbor - príznaky a premenné prostredia, ako každý nástroj UNIX. Ak chcete konfiguráciu v TOML (veľa MCP, profily, tímové konfigurácie v gite), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) je obal pod licenciou MIT, ktorý ju pridáva ako priamu náhradu cez `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Kompatibilita s API OpenAI

**Base URL:** `http://localhost:11434/v1`

| Funkcia | Stav | Poznámky |
|---------|------|----------|
| `POST /v1/chat/completions` | Podporované | Streaming aj bez streamingu |
| `POST /v1/responses` | Podporované | OpenAI Responses API: vstup ako string/správa, `instructions`, streaming (kanonická postupnosť udalostí), `text.format` (vrátane `json_schema`), funkčné nástroje (bez streamingu). Stavové funkcie (`previous_response_id`, `store: true`, `background`, `reasoning`, hostované nástroje) vracajú úprimné 501 |
| `POST /v1/responses/input_tokens` | Podporované | Predbežný počet tokenov (`client.responses.input_tokens.count(...)`): presný počet z tokenizéra Apple, bez generovania; pod macOS 26.4 vracia 501 namiesto odhadu. Pozri [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Podporované | Vracia `apple-foundationmodel` (všeobecný, predvolený) a `apple-foundationmodel-content-tagging` (štítky, nie súvislý text). Pozri [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Podporované | Dostupnosť modelu, kontextové okno, jazyky, hlásené schopnosti modelu (`capabilities`, `capabilities_reported`), varianta obsluhujúceho modelu (`variant`, napr. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Iba ladenie | Vyžaduje `--debug` |
| Volanie nástrojov | Podporované | Volanie sa zapisuje riadeným generovaním (`--tool-calling guided`, predvolené) alebo ako JSON, ktorý parsuje server (`--tool-calling text`). Pozri [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Podporované | Vloženie do systémového promptu; ohrady markdownu sa z výstupu odstránia |
| `response_format: json_schema` | Podporované | Zaručený výstup zodpovedajúci schéme cez FoundationModels `DynamicGenerationSchema`; funguje so `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Podporované | Mapované na `GenerationOptions`. `top_p` je nucleus sampling; `temperature` pod 0.001 (vrátane 0) sa mapuje na greedy (deterministické) vzorkovanie. Vynechanie `max_tokens` použije zostávajúce kontextové okno (sémantika priamej náhrady OpenAI) - pozri [Predvolený limit odpovede](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Podporované | SSE; záverečný chunk s `usage` iba so `stream_options: {"include_usage": true}` (podľa špecifikácie OpenAI) |
| `usage` | Podporované | Skutočné počty z tokenizéra na macOS 26.4+ (nižšie odhad znaky/4). macOS 27: vlastné účtovanie behového prostredia vrátane rámovania chat šablóny Apple (asi 46 ďalších `prompt_tokens` pri jednoriadkovom prompte); macOS 26: apfel počíta text správy. Podrobnosti v [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Podporované | `stop`, `tool_calls`, `length` |
| Stratégie kontextu | Podporované | Rozširujúce polia `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Podporované | Zapnite pomocou `--cors` |
| `POST /v1/completions` | 501 | Staršie dopĺňanie textu nie je podporované |
| `POST /v1/embeddings` | 501 | Embeddingy nie sú na zariadení k dispozícii |
| `stop` | Podporované | String alebo až 4 stringy; iba čistý text (400, ak sú v hre nástroje alebo `json_object`/`json_schema`). Aplikuje sa na strane výstupu, zhodne pri streamingu aj bez neho. Pozri [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Výslovne odmietnuté. `n=1` a `logprobs=false` sa prijímajú ako bez účinku |
| Multimodalita (obrázky) | Podporované na macOS 27 | Časti `image_url` ako base64 data URL idú natívne do modelu na zariadení (limit 20 MB base64, dlhšia strana zmenšená na 4096 px). Vzdialené URL `http(s)` a cesty k súborom vždy dávajú 400 - apfel nikdy nesťahuje obrázky ani nečíta súbory na požiadanie HTTP klienta. Na macOS 26: 400 s jasnou chybou. Pozri [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Hlavička `Authorization` | Podporované | Vyžadovaná, ak je nastavené `--token`. Pozri [docs/server-security.md](../docs/server-security.md) |

Úplná špecifikácia API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Predvolený limit odpovede (`max_tokens`)

Keď je `max_tokens` vynechané, **CLI aj server kompatibilný s OpenAI sa správajú rovnako**: hodnota prejde ako `nil` a model využije všetko miesto, ktoré zostáva v kontextovom okne. Je to sémantika priamej náhrady OpenAI - žiadna ľubovoľná záložná konštanta.

Kontextové okno na zariadení pojme vstup *aj* výstup dokopy: **4096 tokenov na macOS 26 a na Macoch M1/M2, 8192 tokenov na macOS 27 s čipom M3 alebo novším a 12 GB+**. apfel skutočnú veľkosť zisťuje za behu cez `SystemLanguageModel.contextSize` - vašu zistíte pomocou `apfel --model-info`. Ak generovanie narazí na strop, odpoveď čisto skončí s `finish_reason: "length"` a vráti sa čiastočný obsah (server: HTTP 200; CLI: exit 0 s varovaním na stderr, alebo exit 8 s `--require-complete` - pozri [docs/cli-reference.md](../docs/cli-reference.md)). Zadajte `max_tokens` výslovne, keď chcete prísnejší rozpočet latencie alebo známy limit pre svojho klienta.

### Príklady

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

### Výber hodnoty

| Prípad použitia                        | `max_tokens`  |
|----------------------------------------|---------------|
| Jednoslovná odpoveď / klasifikácia     | 16 - 32       |
| Jednoriadková inštrukcia               | 64 - 128      |
| Krátky odsek                           | 256 - 512     |
| Dlhý odsek / štruktúrovaný JSON        | 1024 - 2048   |
| Toľko, koľko kontextové okno dovolí    | vynechať      |

Držte `input_tokens + max_tokens` s pohodlnou rezervou pod kontextovým oknom (4096 tokenov na macOS 26 a na Macoch M1/M2, 8192 na macOS 27 s čipom M3 alebo novším a 12 GB+ (model AFM 3 Core Advanced od Apple)). Ak samotný prompt okno presiahne, generovanie nemôže začať a požiadavka zlyhá s `[context overflow]` (HTTP 400 / CLI exit 4). Validátor odmieta nekladné hodnoty (`max_tokens <= 0`).

### Zhoda s CLI

CLI a server zdieľajú jedno pravidlo: vynechané = použi zostávajúce okno. Žiadna konštanta, ktorá by sa mohla rozísť. Prepíšte pomocou `--max-tokens N` alebo `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permisívne guardrails pre server

`apfel --serve --permissive` spôsobí, že server používa guardrails Apple `.permissiveContentTransformations` pre **každú požiadavku** spracovanú procesom. Rovnaký príznak, rovnaká sémantika ako `--permissive` v CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Prepísanie na úrovni požiadavky neexistuje - rozhoduje prevádzkovateľ servera pre celý proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Obmedzenia

| Obmedzenie | Podrobnosti |
|------------|-------------|
| Kontextové okno | **4096 tokenov na macOS 26 a na Macoch M1/M2, 8192 tokenov na macOS 27 s čipom M3 alebo novším a 12 GB+** (vstup + výstup dokopy). Nie je to pevne zadaná konštanta - apfel číta `SystemLanguageModel.contextSize` za behu; `apfel --model-info` vypíše aktuálnu hodnotu |
| Platforma | macOS 26+, iba Apple Silicon |
| Model | Jeden model na zariadení (~3 mld parametrov), poskytovaný ako `apple-foundationmodel` (všeobecný) a `apple-foundationmodel-content-tagging` (adaptér Apple na štítkovanie obsahu; bez nástrojov) |
| Guardrails | Bezpečnostný systém Apple môže blokovať neškodné prompty. `--permissive` znižuje počet falošných poplachov ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Rýchlosť | Na zariadení, nie v mierke cloudu - niekoľko sekúnd na odpoveď |
| Žiadne embeddingy | Na zariadení nie sú k dispozícii |
| Videnie | Obrazový vstup sa k modelu dostane iba na macOS 27 (server: data URL; CLI: `-f photo.jpg` a obrázky cez rúru, navyše k textu z OCR). Na macOS 26 sú obrázky iba text cez OCR/klasifikáciu. Popisy scén modelu 3B sú hrubé - OCR zostáva spoľahlivým kanálom na čítanie tlače |
| Trénovacie dáta / hranica znalostí | Apple nezverejnil presný dátum hranice znalostí modelu na zariadení. Keď je model nútený ho uviesť, **pri každej vzorke si vymyslí iný dátum** (napr. "October 2023", "April 2023"). Všetky sebahlásenia modelu o jeho vlastnom trénovaní považujte za nespoľahlivé. |
| Žiadny aktuálny dátum ani povedomie o reálnom čase | Model nepozná dnešný dátum a nemá prístup k sieti ani k hodinám. Pri otázke buď odmietne, alebo dátum vymyslí. Ak výpočet na dátume závisí, vložte aktuálny dátum cez systémový prompt (pozri riešenie nižšie). |

**Riešenie pre prompty závislé od dátumu** - vložte aktuálny dátum ako systémovú správu:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Poznámka: aj s vloženým dátumom môže model 3B stále halucinovať (najmä pri priamej otázke na hranicu jeho vlastného trénovania). Vloženie pomáha generatívnym promptom, ktoré dátum *používajú*; neprekoná reflex sebahlásenia modelu.

Pozadie: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referenčná dokumentácia

Návody, ako používať apfel z [Pythonu](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - pozri [docs/guides/index.md](../docs/guides/index.md). Empiricky otestované; spustiteľný dôkaz v [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - inštalácia, riešenie problémov a nastavenie Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - každý príznak, návratový kód a premenná prostredia
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` a extrakcia PDF / obrázkov / textu cez rúru (OCR + porozumenie obrazu)
- [docs/background-service.md](../docs/background-service.md) - použitie `brew services` a launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - podrobná matica podpory `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - kontroly origin, CORS, tokeny a `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - stratégie orezávania chatu
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokálne a vzdialené použitie MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - podrobné správanie volania nástrojov
- [docs/integrations.md](../docs/integrations.md) - integrácie nástrojov tretích strán (opencode atď.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokálna revízia s apfel + druhým modelom na úpravy/aplikáciu vo VS Code
- [docs/demos.md](../docs/demos.md) - dlhšie návody k shellovým ukážkam
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ skutočných promptov s needitovaným výstupom
- [docs/swift-library.md](../docs/swift-library.md) - balík Swift `ApfelCore` pre vývojárov
- [docs/coreai-impact.md](../docs/coreai-impact.md) - prečo apfel beží na FoundationModels, a nie na novom Core AI od Apple (nástupcovi Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel v porovnaní s vlastným CLI `fm` od Apple (macOS 27), funkciu po funkcii s nameranými číslami

## Architektúra

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 so striktnou súbežnosťou. Tri targety: `ApfelCore` (čistá logika, testovateľná jednotkovými testami, dostupná aj ako produkt Swift Package - odkaz v Referenčnej dokumentácii vyššie), `apfel` (CLI + server) a `apfel-tests` (čistý runner Swift, bez XCTest).

## Zostavenie a testy

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

`.version` je jediný zdroj pravdy. Verzie zvyšuje iba `make release`. Lokálne buildy verziu nemenia.

## Strom apfel

Projekty postavené na apfel. Každý má vlastný repozitár a formulu Homebrew.

| Projekt | Čo robí | Inštalácia |
|---------|---------|------------|
| [**apfel**](https://apfel.franzai.com) | Koreň. CLI FoundationModels na zariadení + server kompatibilný s OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Chatovací klient pre macOS: streaming markdownu, hlasový vstup/výstup, analýza obrázkov cez Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Akcie AI v lište ponúk nad schránkou: zhrnutie, preklad, prepis. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Okamžitý prekryv s AI: stlačte kláves, opýtajte sa, odpoveď, zavrieť. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Poznámkový blok so vzorcami - AI na zariadení ako funkcia bunky priamo v texte. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP optimalizované na rozpočet tokenov pre malé okno na zariadení: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Ladiaci inšpektor v SwiftUI: časová os požiadaviek, prehliadač protokolu MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Obal UNIX pridávajúci trvalý register MCP + konfiguráciu TOML nad `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI na značkovanie obsahu na zariadení: pošlite text rúrou, dostanete tagy/témy/emócie. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Balík Swift pre nástroje ekosystému: objavte, spustite a streamujte z lokálneho `apfel --serve`. | Swift Package |

## Projekty komunity

Postavili ste niečo na apfel? Otvorte issue a projekt možno pridať sem.

| Projekt | Čo robí | Odkazy |
|---------|---------|--------|
| **apfelclaw** od [@julianYaman](https://github.com/julianYaman) | Lokálny AI agent, ktorý číta súbory, kalendár, poštu a stav Macu cez nástroje iba na čítanie | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** od [@bhaskarvilles](https://github.com/bhaskarvilles) | Chatovacie rozhranie v prehliadači komunikujúce s `apfel --serve` cez API kompatibilné s OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** od [@lucaspwo](https://github.com/lucaspwo) | Obal okolo Claude Code, ktorý cez malý proxy Anthropic-OpenAI nahradí backend lokálnym apfel | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** od [@hasit](https://github.com/hasit) | Správca aplikácií pre lokálne shellové aplikácie postavené okolo apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** od [@eggsy](https://github.com/eggsy) | Rozšírenie príkazového riadka Raycast: pýtajte sa, prekladajte, vysvetľujte súbory a adresáre, história konverzácií, vlastné systémové prompty. Na zariadení cez apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Prispievanie

Issues a PR vítané v ktoromkoľvek repozitári `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR od AI agentov sú v poriadku. Prečítajte si `CLAUDE.md` repozitára, spustite testy, uveďte nástroj v traileri `Co-Authored-By`. Rovnaká latka ako pre ľudí: čistý kód, prechádzajúce testy, úprimné obmedzenia. Pre agentov najprívetivejší vstupný bod: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([pravidlá prispievania](https://apfel-mcp.franzai.com/#contribute)).

## Licencia

[MIT](../LICENSE)
