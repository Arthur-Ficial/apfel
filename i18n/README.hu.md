<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> Az [angol README](../README.md) fordítása. Az angol változat a mérvadó.

# apfel

### Az ingyenes AI, ami már ott van a Mac-eden.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Az Apple Silicon Mac-ek beépített LLM-mel érkeznek az [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) révén. Az `apfel` UNIX-eszközként és helyi, OpenAI-kompatibilis szerverként teszi elérhetővé. 100%-ban az eszközön fut. Nincs API-kulcs, nincs felhő.

| Mód | Parancs | Mit kapsz |
|------|---------|--------------|
| UNIX-eszköz | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-barát válaszok, fájlcsatolmányok, JSON-kimenet, kilépési kódok |
| OpenAI-kompatibilis szerver | `apfel --serve` | Helyi `http://localhost:11434/v1` backend, közvetlen csereként az OpenAI SDK-khoz |

`apfel --chat` - interaktív REPL.

[![apfel terminál-bemutatóvideó: valódi parancsok, valódi válaszok az eszközön (82 másodperc)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/hu/a/apfel-ai-tutorial/#video)

Az eszközhívás minden környezetben működik.

![apfel CLI](../screenshots/cli.png)

## Követelmények és telepítés

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence bekapcsolva](https://support.apple.com/en-us/121115). macOS 27-en az M3-as vagy újabb chippel és 12 GB+ memóriával rendelkező Mac-ek az Apple nagyobb, eszközön futó modelljét futtatják 8192 tokenes ablakkal; az M1/M2 Mac-ek és minden macOS 26-os Mac 4096-ot kap. Az `apfel --model-info` megmutatja a tiédet.

```bash
brew install apfel
```

Frissítés:

```bash
brew upgrade apfel
```

Fordítás forráskódból (Command Line Tools a macOS 27 SDK-val / Swift 6.3, Xcode nélkül; a bináris macOS 26-on és 27-en is fut):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, hibaelhárítás: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | **Magyar** | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Gyors kezdés

### UNIX-eszköz

A `!` karaktert tartalmazó prompt-okat tedd szimpla idézőjelbe (zsh/bash előzménybővítés): `apfel 'Hello, Mac!'`.

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

### OpenAI-kompatibilis szerver

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

A háttérszolgáltatás részletei: [docs/background-service.md](../docs/background-service.md).

### Chat gyors kipróbáláshoz

Az `apfel --chat` egy kis REPL prompt-ok vagy MCP-szerverek kipróbálásához. GUI-s chat alkalmazásért lásd az [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) projektet.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

A Ctrl-C kilép. A kontextus automatikusan vágódik ([docs/context-strategies.md](../docs/context-strategies.md)).

Korlátok, amelyeket érdemes ismerni, mielőtt scriptet írsz hozzá (Mac-enként eltérő kontextusablak, guardrails, nincs embeddings): [Korlátok](../README.md#limitations).

## Demók

Valódi shell scriptek, amelyek az `apfel`-t csomagolják: `cmd` (angol nyelvű leírásból shell-parancs), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. A binárisba vannak beépítve - nem kell klónozni a repót. Írd ki őket bárhová, onnan, ahonnan az apfel-t telepítetted (homebrew-core, a tap vagy a forráskód):

```bash
apfel demos ./apfel-demos
```

Ez kiírja az összes demót (futtathatóként) és egy `README.md`-t a `./apfel-demos` könyvtárba. Ezután onnan futtathatod őket:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

A `brew upgrade apfel` után futtasd újra az `apfel demos` parancsot a frissítéshez. Források: [`demo/`](../demo/). Részletes útmutatók és egy másolható `cmd` shell-függvény a `.zshrc`-dhez: [docs/demos.md](../docs/demos.md).

## MCP-eszköztámogatás

Csatlakoztass [Model Context Protocol](https://modelcontextprotocol.io/) szervereket a `--mcp` kapcsolóval. Az apfel felderíti, meghívja és visszaadja az eredményt.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

A `-q` elrejti az eszközinformációkat.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Egy számológép is jár hozzá a [`mcp/calculator/`](../mcp/calculator/) könyvtárban ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Távoli MCP-szerverek** (Streamable HTTP, MCP-specifikáció 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Biztonság:** az `APFEL_MCP_TOKEN` jobb, mint a `--mcp-token` (látszik a ps aux-ban). Az apfel megtagadja a bearer tokenek küldését titkosítatlan `http://` kapcsolaton.

## apfel-run: opcionális konfigurációs réteg

Magának az apfel-nek nincs konfigurációs fájlja - csak kapcsolók és környezeti változók, mint minden UNIX-eszköznek. Ha TOML-konfigurációt szeretnél (sok MCP, profilok, git-ben tárolt csapatkonfigurációk), az [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) egy MIT licencű wrapper, amely `execve`-alapú közvetlen cserével hozzáadja azt.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API-kompatibilitás

**Alap URL:** `http://localhost:11434/v1`

| Funkció | Állapot | Megjegyzések |
|---------|--------|-------|
| `POST /v1/chat/completions` | Támogatott | Streaminggel és anélkül |
| `POST /v1/responses` | Támogatott | OpenAI Responses API: string/üzenet bemenet, `instructions`, streaming (kanonikus eseménysorrend), `text.format` (beleértve a `json_schema`-t), function tools (streaming nélkül). Az állapotfüggő funkciók (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) őszinte 501-et adnak vissza |
| `POST /v1/responses/input_tokens` | Támogatott | Token-előellenőrzés (`client.responses.input_tokens.count(...)`): pontos szám az Apple tokenizeréből, generálás nélkül; macOS 26.4 alatt 501 becslés helyett. Lásd [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Támogatott | Az `apple-foundationmodel` (általános, alapértelmezett) és a `apple-foundationmodel-content-tagging` (címkék, nem folyó szöveg) modellt adja vissza. Lásd [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Támogatott | Modell-elérhetőség, kontextusablak, nyelvek, a modell jelentett képességei (`capabilities`, `capabilities_reported`), a kiszolgáló modellváltozat (`variant`, pl. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Csak debug | `--debug` szükséges |
| Eszközhívás | Támogatott | A hívás irányított generálással (`--tool-calling guided`, alapértelmezett) vagy a szerver által feldolgozott JSON-ként (`--tool-calling text`) készül. Lásd [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Támogatott | System prompt-beillesztés; a markdown kódblokk-keretek lekerülnek a kimenetről |
| `response_format: json_schema` | Támogatott | Garantáltan sémának megfelelő kimenet a FoundationModels `DynamicGenerationSchema`-n keresztül; működik `stream: true`-val |
| `temperature`, `top_p`, `max_tokens`, `seed` | Támogatott | A `GenerationOptions`-ra képezve. A `top_p` nucleus sampling; a 0.001 alatti `temperature` (a 0 is) greedy-re (determinisztikusra) képeződik. A `max_tokens` elhagyása a kontextusablak hátralévő részét használja (OpenAI-szemantika, közvetlen csere) - lásd [Alapértelmezett válaszkorlát](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Támogatott | SSE; a záró usage chunk csak `stream_options: {"include_usage": true}` esetén (az OpenAI specifikációja szerint) |
| `usage` | Támogatott | Valódi tokenizer-számok macOS 26.4+ rendszeren (alatta chars/4 becslés). macOS 27: a runtime saját elszámolása az Apple chat-template keretezésével (egysoros promptnál körülbelül 46-tal több `prompt_tokens`); macOS 26: az apfel az üzenetek szövegét számolja. Részletek: [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Támogatott | `stop`, `tool_calls`, `length` |
| Kontextusstratégiák | Támogatott | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` kiterjesztésmezők |
| CORS | Támogatott | A `--cors` kapcsolóval engedélyezhető |
| `POST /v1/completions` | 501 | A régi (legacy) szövegkiegészítés nem támogatott |
| `POST /v1/embeddings` | 501 | Az embeddings nem érhető el az eszközön |
| `stop` | Támogatott | String vagy legfeljebb 4 string; csak egyszerű szöveg (400, ha eszközök vannak hatókörben, vagy `json_object`/`json_schema` esetén). A kimeneti oldalon érvényesül, streaminggel és anélkül azonosan. Lásd [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Kifejezetten elutasítva. Az `n=1` és a `logprobs=false` no-opként elfogadott |
| Multimodális (képek) | Támogatott macOS 27-en | Az `image_url` részek base64 data URL-ként natívan jutnak az eszközön futó modellhez (20 MB base64 korlát, a hosszabbik oldal 4096 px-re kicsinyítve). A távoli `http(s)` URL-ek és a fájlutak mindig 400-at adnak - az apfel soha nem tölt le képet, és soha nem olvas fájlt egy HTTP-kliensnek. macOS 26-on: 400 érthető hibaüzenettel. Lásd [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` fejléc | Támogatott | Kötelező, ha a `--token` be van állítva. Lásd [docs/server-security.md](../docs/server-security.md) |

Teljes API-specifikáció: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Alapértelmezett válaszkorlát (`max_tokens`)

Ha a `max_tokens` hiányzik, **a CLI és az OpenAI-kompatibilis szerver azonosan viselkedik**: az érték `nil`-ként halad tovább, és a modell azt a helyet használja, ami a kontextusablakban megmaradt. Ez az OpenAI közvetlen cseréjét adó szemantika - nincs önkényes tartalék-konstans.

Az eszközön futó kontextusablak a bemenetet *és* a kimenetet együtt tartalmazza: **4096 token macOS 26-on és M1/M2 Mac-eken, 8192 token macOS 27-en M3-as vagy újabb chippel és 12 GB+ memóriával**. Az apfel a valódi méretet futásidőben olvassa a `SystemLanguageModel.contextSize`-on keresztül - a sajátodat az `apfel --model-info` mutatja. Ha a generálás eléri a korlátot, a válasz tisztán `finish_reason: "length"` értékkel ér véget, és a részleges tartalom visszajön (szerver: HTTP 200; CLI: 0-s kilépési kód stderr-figyelmeztetéssel, vagy 8-as kód `--require-complete` mellett - lásd [docs/cli-reference.md](../docs/cli-reference.md)). Add meg a `max_tokens` értékét kifejezetten, ha szűkebb késleltetési keretre vagy ismert korlátra van szükséged a kliensednél.

### Példák

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

### Érték kiválasztása

| Felhasználási eset                     | `max_tokens`  |
|----------------------------------------|---------------|
| Egyszavas válasz / osztályozás         | 16 - 32       |
| Egysoros utasítás                      | 64 - 128      |
| Rövid bekezdés                         | 256 - 512     |
| Hosszú bekezdés / strukturált JSON     | 1024 - 2048   |
| Amennyit a kontextusablak enged        | hagyd el      |

Tartsd az `input_tokens + max_tokens` értéket kényelmesen a kontextusablak alatt (4096 token macOS 26-on és M1/M2 Mac-eken, 8192 macOS 27-en M3-as vagy újabb chippel és 12 GB+ memóriával (az Apple AFM 3 Core Advanced modellje)). Ha maga a prompt meghaladja az ablakot, a generálás nem indulhat el, és a kérés `[context overflow]` hibával meghiúsul (HTTP 400 / CLI exit 4). A validátor elutasítja a nem pozitív értékeket (`max_tokens <= 0`).

### CLI-paritás

A CLI és a szerver egy szabályt követ: elhagyva = a hátralévő ablakot használja. Nincs konstans, ami elcsúszhatna. Felülírható a `--max-tokens N` kapcsolóval vagy az `APFEL_MAX_TOKENS=N` változóval.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails a szerverhez

Az `apfel --serve --permissive` hatására a szerver az Apple `.permissiveContentTransformations` guardrails-ét használja a folyamat által kezelt **minden kérésnél**. Ugyanaz a kapcsoló, ugyanaz a szemantika, mint a CLI `--permissive` kapcsolójánál ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Kérésenkénti felülbírálás nincs - a szerver üzemeltetője dönt a teljes folyamatra.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Korlátok

| Korlát | Részlet |
|------------|--------|
| Kontextusablak | **4096 token macOS 26-on és M1/M2 Mac-eken, 8192 token macOS 27-en M3-as vagy újabb chippel és 12 GB+ memóriával** (bemenet + kimenet együtt). Nem bekódolt konstans - az apfel futásidőben olvassa a `SystemLanguageModel.contextSize`-t; az `apfel --model-info` kiírja az aktuális értéket |
| Platform | macOS 26+, csak Apple Silicon |
| Modell | Egyetlen eszközön futó modell (~3B paraméter), `apple-foundationmodel` (általános) és `apple-foundationmodel-content-tagging` (az Apple tartalomcímkéző adaptere; eszközök nélkül) néven érhető el |
| Guardrails | Az Apple biztonsági rendszere ártalmatlan prompt-okat is blokkolhat. A `--permissive` csökkenti a téves riasztásokat ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Sebesség | Az eszközön fut, nem felhőléptékű - néhány másodperc válaszonként |
| Nincs embeddings | Az eszközön nem érhető el |
| Látás | A képbemenet csak macOS 27-en jut el a modellhez (szerver: data URL-ek; CLI: `-f photo.jpg` és pipe-olt képek, az OCR-szöveg mellett). macOS 26-on a képek csak szövegként, OCR/osztályozás útján jelennek meg. A 3B modell jelenetleírásai nagyvonalúak - nyomtatott szöveg olvasásához az OCR marad a megbízható csatorna |
| Tanítóadatok / tudásvágás | Az Apple nem közölt pontos vágási dátumot az eszközön futó modellhez. Ha megnevezésre kényszerítik, a modell **mintánként más dátumot találgat** (pl. "October 2023", "April 2023"). Tekints megbízhatatlannak minden olyan állítást, amit a modell a saját tanításáról mond. |
| Nincs aktuális dátum vagy valós idejű tudatosság | A modell nem tudja a mai dátumot, és nincs hálózat- vagy óra-hozzáférése. Ha rákérdezel, vagy megtagadja a választ, vagy kitalál egy dátumot. Add át az aktuális dátumot system prompt-tal, ha a számítás attól függ (lásd az alábbi megoldást). |

**Megoldás dátumfüggő prompt-okhoz** - add át az aktuális dátumot system üzenetként:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Megjegyzés: a megadott dátum mellett is előfordulhat, hogy a 3B modell hallucinál (különösen, ha közvetlenül a saját tanítási vágásáról kérdezed). A beillesztés azokon a generatív prompt-okon segít, amelyek *használják* a dátumot; nem írja felül a modell reflexét, hogy beszéljen önmagáról.

Háttér: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referenciadokumentáció

Útmutatók az apfel használatához [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) alól - lásd [docs/guides/index.md](../docs/guides/index.md). Empirikusan tesztelve; futtatható bizonyíték: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - telepítés, hibaelhárítás és az Apple Intelligence beállítása
- [docs/cli-reference.md](../docs/cli-reference.md) - minden kapcsoló, kilépési kód és környezeti változó
- [docs/file-extraction.md](../docs/file-extraction.md) - PDF / kép / szöveg kinyerése `-f` és pipe segítségével (OCR + képértelmezés)
- [docs/background-service.md](../docs/background-service.md) - a `brew services` és a launchd használata
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - a `/v1/*` támogatási mátrixa részletesen
- [docs/server-security.md](../docs/server-security.md) - origin-ellenőrzések, CORS, tokenek és `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - chat-vágási stratégiák
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - helyi és távoli MCP használata
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - az eszközhívás részletes működése
- [docs/integrations.md](../docs/integrations.md) - harmadik féltől származó eszközök integrációi (opencode stb.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - helyi review az apfel-lel és egy második szerkesztő/alkalmazó modellel a VS Code-ban
- [docs/demos.md](../docs/demos.md) - hosszabb végigvezetők a shell-demókhoz
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ valódi prompt szerkesztetlen kimenettel
- [docs/swift-library.md](../docs/swift-library.md) - `ApfelCore` Swift Package downstream fejlesztőknek
- [docs/coreai-impact.md](../docs/coreai-impact.md) - miért FoundationModels-en fut az apfel, és miért nem az Apple új Core AI-ján (a Core ML utódján)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - az apfel összehasonlítása az Apple saját `fm` CLI-jével (macOS 27), funkciónként, mért számokkal

## Architektúra

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Három target: `ApfelCore` (tiszta logika, unit-tesztelhető, Swift Package termékként is elérhető - lásd fent a Referenciadokumentációban), `apfel` (CLI + szerver) és az `apfel-tests` (tiszta Swift tesztfuttató, XCTest nélkül).

## Build és tesztelés

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

A `.version` az egyetlen igazságforrás. Csak a `make release` emeli a verziót. A helyi buildek nem változtatják meg.

## Az apfel fa

Az apfel-re épülő projektek. Mindegyik saját repóval + Homebrew formulával érkezik.

| Projekt | Mit csinál | Telepítés |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | A gyökér. Eszközön futó FoundationModels CLI + OpenAI-kompatibilis szerver. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS chat kliens: streaming markdown, beszéd be-/kimenet, képelemzés Apple Vision-nel. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Menüsoros AI-műveletek a vágólapon: összefoglalás, fordítás, átfogalmazás. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Azonnali AI-overlay: nyomj egy billentyűt, kérdezz, megkapod a választ, bezárod. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Képletes jegyzettömb - az eszközön futó AI mint soron belüli cellafüggvény. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokenkeretre optimalizált MCP-k a kis eszközön futó ablakhoz: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspector: kéréstörténet, MCP-protokollnézegető, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX wrapper, amely állandó MCP-regisztert + TOML-konfigurációt ad az `apfel` fölé. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Eszközön futó tartalomcímkéző CLI: szöveget adsz be, címkéket/témákat/érzelmeket kapsz. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift csomag az ökoszisztéma eszközeihez: helyi `apfel --serve` felderítése, indítása és streamelése. | Swift Package |

## Közösségi projektek

Építettél valamit az apfel-re? Nyiss egy issue-t, és felkerülhet ide.

| Projekt | Mit csinál | Linkek |
|---------|-------------|-------|
| **apfelclaw** - [@julianYaman](https://github.com/julianYaman) | Helyi AI-ügynök, amely csak olvasási eszközökkel olvas fájlokat, naptárat, levelezést és a Mac állapotát | [github](https://github.com/julianyaman/apfelclaw) - [oldal](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** - [@bhaskarvilles](https://github.com/bhaskarvilles) | Böngészős chat-felület, amely az OpenAI-kompatibilis API-n át beszél az `apfel --serve`-vel | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** - [@lucaspwo](https://github.com/lucaspwo) | Claude Code wrapper, amely egy kis Anthropic-OpenAI proxyn keresztül az apfel-t állítja be helyi backendnek | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** - [@hasit](https://github.com/hasit) | Alkalmazáskezelő az apfel köré épített helyi shell-alkalmazásokhoz | [github](https://github.com/hasit/apfeller) - [oldal](https://hasit.github.io/apfeller/) - [katalógus](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** - [@eggsy](https://github.com/eggsy) | Raycast parancssáv-bővítmény: kérdezés, fordítás, fájlok és könyvtárak magyarázata, beszélgetési előzmények, egyéni system prompt-ok. Az eszközön fut az apfel CLI-n keresztül. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Közreműködés

Issue-k és PR-ok szívesen látottak bármelyik `Arthur-Ficial/apfel*` repóban.

**#agentswelcome** - az AI-ügynökök PR-jai rendben vannak. Olvasd el a repó `CLAUDE.md` fájlját, futtasd a teszteket, és tüntesd fel az eszközt egy `Co-Authored-By` trailerben. Ugyanaz az elvárás, mint az embereknél: tiszta kód, átmenő tesztek, őszinte korlátok. Ügynököknek a legbarátibb belépési pont: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([közreműködési szabályok](https://apfel-mcp.franzai.com/#contribute)).

## Licenc

[MIT](../LICENSE)
