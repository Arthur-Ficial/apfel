<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Tulkots no [angļu valodas README](../README.md). Angļu valodas versija ir noteicošā.

# apfel

### Bezmaksas MI, kas jau ir tavā Mac datorā.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac datoriem ir iebūvēts LLM, ko nodrošina [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` padara to pieejamu kā UNIX rīku un lokālu OpenAI saderīgu serveri. 100 % ierīcē. Bez API atslēgām, bez mākoņa.

| Režīms | Komanda | Ko tu iegūsti |
|------|---------|--------------|
| UNIX rīks | `apfel "prompt"` / `echo "text" \| apfel` | Atbildes, kas der pipe lietošanai, failu pielikumi, JSON izvade, izejas kodi |
| OpenAI saderīgs serveris | `apfel --serve` | Lokāls `http://localhost:11434/v1` backends, kas tieši aizstāj OpenAI SDK mērķi |

`apfel --chat` - interaktīvs REPL.

[![apfel demonstrācijas video terminālī: īstas komandas, īstas atbildes ierīcē (84 sekundes)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/lv/a/apfel-ai-tutorial/#video)

Rīku izsaukšana darbojas visos kontekstos.

![apfel CLI](../screenshots/cli.png)

## Prasības un instalēšana

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ieslēgts](https://support.apple.com/en-us/121115). macOS 27 sistēmā Mac datori ar M3 vai jaunāku mikroshēmu un vismaz 12 GB izmanto Apple lielāko ierīces modeli ar 8192 tokenu logu; M1/M2 Mac datoriem un visiem Mac datoriem ar macOS 26 ir 4096. `apfel --model-info` parāda tavējo.

```bash
brew install apfel
```

Atjaunināšana:

```bash
brew upgrade apfel
```

Būvēšana no pirmkoda (Command Line Tools ar macOS 27 SDK / Swift 6.3, bez Xcode; binārais fails darbojas macOS 26 un 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, problēmu novēršana: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | **Latviešu** | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Ātrā sākšana

### UNIX rīks

Promptus ar `!` ieliec vienkāršās pēdiņās (zsh/bash vēstures izvēršana): `apfel 'Hello, Mac!'`.

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

### OpenAI saderīgs serveris

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

Informācija par fona pakalpojumu: [docs/background-service.md](../docs/background-service.md).

### Čats ātrai testēšanai

`apfel --chat` ir neliels REPL promptu vai MCP serveru testēšanai. Čata lietotnei ar grafisko saskarni skaties [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C iziet. Konteksts tiek automātiski apgriezts ([docs/context-strategies.md](../docs/context-strategies.md)).

Ierobežojumi, kas jāzina pirms skriptēšanas pret to (konteksta logs katram Mac, guardrails, nav embeddings): [Ierobežojumi](../README.md#limitations).

## Demo

Īsti shell skripti, kas apvij `apfel`: `cmd` (angļu valoda uz shell komandu), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Tie ir iebūvēti binārajā failā - repozitorija klonēšana nav vajadzīga. Izraksti tos jebkur, no kurienes instalēji apfel (homebrew-core, tap vai pirmkods):

```bash
apfel demos ./apfel-demos
```

Tas izraksta visus demo (izpildāmus) un `README.md` mapē `./apfel-demos`. Pēc tam palaid tos no turienes:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Pēc `brew upgrade apfel` vēlreiz palaid `apfel demos`, lai atsvaidzinātu. Pirmkods: [`demo/`](../demo/). Pārskati un kopējama `cmd` shell funkcija tavam `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP rīku atbalsts

Pievieno [Model Context Protocol](https://modelcontextprotocol.io/) serverus ar `--mcp`. apfel atrod, izsauc un atgriež.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Izmanto `-q`, lai paslēptu informāciju par rīkiem.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Komplektā ir kalkulators mapē [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Attālie MCP serveri** (Streamable HTTP, MCP specifikācija 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Drošība:** dod priekšroku `APFEL_MCP_TOKEN` pār `--mcp-token` (ps aux). apfel atsakās sūtīt bearer tokenus pa nešifrētu `http://`.

## apfel-run: izvēles konfigurācijas slānis

Pašam apfel nav konfigurācijas faila - karodziņi + vides mainīgie, kā jebkuram UNIX rīkam. Ja vēlies TOML konfigurāciju (daudz MCP, profili, komandas konfigurācijas git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) ir MIT licencēts apvalks, kas to pievieno kā `execve` aizstājēju.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API saderība

**Bāzes URL:** `http://localhost:11434/v1`

| Funkcija | Statuss | Piezīmes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Atbalstīts | Streaming + bez streaming |
| `POST /v1/responses` | Atbalstīts | OpenAI Responses API: virknes/ziņojumu ievade, `instructions`, streaming (kanoniskā notikumu secība), `text.format` (t. sk. `json_schema`), funkciju rīki (bez streaming). Stāvokli saglabājošas funkcijas (`previous_response_id`, `store: true`, `background`, `reasoning`, hostētie rīki) atgriež godīgu 501 |
| `POST /v1/responses/input_tokens` | Atbalstīts | Tokenu priekšpārbaude (`client.responses.input_tokens.count(...)`): precīzs skaits no Apple tokenizētāja, bez ģenerēšanas; 501 zem macOS 26.4 aplēses vietā. Skat. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Atbalstīts | Atgriež `apple-foundationmodel` (vispārīgais, noklusējuma) un `apple-foundationmodel-content-tagging` (birkas, nevis proza). Skat. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Atbalstīts | Modeļa pieejamība, konteksta logs, valodas, paziņotās modeļa spējas (`capabilities`, `capabilities_reported`), apkalpojošā modeļa variants (`variant`, piem., AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Tikai atkļūdošanai | Nepieciešams `--debug` |
| Rīku izsaukšana | Atbalstīts | Izsaukums tiek rakstīts ar vadītu ģenerēšanu (`--tool-calling guided`, noklusējums) vai kā JSON, ko parsē serveris (`--tool-calling text`). Skat. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Atbalstīts | Sistēmas prompta injekcija; markdown žogi tiek noņemti no izvades |
| `response_format: json_schema` | Atbalstīts | Garantēti shēmai atbilstoša izvade, izmantojot FoundationModels `DynamicGenerationSchema`; darbojas ar `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Atbalstīts | Attēloti uz `GenerationOptions`. `top_p` ir nucleus sampling; `temperature` zem 0.001 (ieskaitot 0) attēlojas uz greedy (deterministisks). Izlaižot `max_tokens`, tiek izmantots atlikušais konteksta logs (OpenAI semantika kā tiešs aizstājējs) - skat. [Noklusējuma atbildes limits](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Atbalstīts | SSE; pēdējais usage chunk tikai tad, ja `stream_options: {"include_usage": true}` (saskaņā ar OpenAI specifikāciju) |
| `usage` | Atbalstīts | Reāli tokenizētāja skaitļi macOS 26.4+ (zemāk - aplēse rakstzīmes/4). macOS 27: izpildlaika paša uzskaite, ieskaitot Apple čata veidnes ietvarus (apmēram 46 papildu `prompt_tokens` vienas rindas promptam); macOS 26: apfel skaita ziņojuma tekstu. Sīkāk [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Atbalstīts | `stop`, `tool_calls`, `length` |
| Konteksta stratēģijas | Atbalstīts | Paplašinājuma lauki `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Atbalstīts | Ieslēdz ar `--cors` |
| `POST /v1/completions` | 501 | Mantotie teksta pabeigšanas izsaukumi netiek atbalstīti |
| `POST /v1/embeddings` | 501 | Embeddings nav pieejami ierīcē |
| `stop` | Atbalstīts | Viena virkne vai līdz 4 virknēm; tikai vienkāršs teksts (400, ja darbojas rīki vai `json_object`/`json_schema`). Piemēro izvades pusē, identiski ar streaming un bez tā. Skat. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Tiek noraidīti tieši. `n=1` un `logprobs=false` tiek pieņemti kā tukšas darbības |
| Multimodalitāte (attēli) | Atbalstīts macOS 27 | `image_url` daļas kā base64 data URL nonāk tieši pie ierīces modeļa (20 MB base64 limits, garākā mala tiek samazināta līdz 4096 px). Attālie `http(s)` URL un failu ceļi vienmēr dod 400 - apfel nekad neielādē attēlus un nekad nelasa failus HTTP klienta vārdā. macOS 26: 400 ar skaidru kļūdas ziņojumu. Skat. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` galvene | Atbalstīts | Nepieciešama, ja ir iestatīts `--token`. Skat. [docs/server-security.md](../docs/server-security.md) |

Pilna API specifikācija: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Noklusējuma atbildes limits (`max_tokens`)

Ja `max_tokens` ir izlaists, **CLI un OpenAI saderīgais serveris darbojas identiski**: vērtība tiek nodota kā `nil`, un modelis izmanto visu, kas palicis konteksta logā. Tā ir OpenAI semantika kā tiešs aizstājējs - bez patvaļīgas rezerves konstantes.

Ierīces konteksta logā ietilpst ievade *un* izvade kopā: **4096 tokeni macOS 26 un M1/M2 Mac datoros, 8192 tokeni macOS 27 ar M3 vai jaunāku mikroshēmu un vismaz 12 GB**. apfel izpildlaikā nolasa reālo izmēru, izmantojot `SystemLanguageModel.contextSize` - pārbaudi savu ar `apfel --model-info`. Ja ģenerēšana sasniedz griestus, atbilde beidzas tīri ar `finish_reason: "length"` un daļējais saturs tiek atgriezts (serveris: HTTP 200; CLI: exit 0 ar stderr brīdinājumu vai exit 8 ar `--require-complete` - skat. [docs/cli-reference.md](../docs/cli-reference.md)). Norādi `max_tokens` tieši, ja vēlies stingrāku latentuma budžetu vai zināmu limitu savam klientam.

### Piemēri

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

### Vērtības izvēle

| Lietojuma gadījums                     | `max_tokens`  |
|----------------------------------------|---------------|
| Viena vārda atbilde / klasifikācija    | 16 - 32       |
| Vienas rindas instrukcija              | 64 - 128      |
| Īss rindkopa                           | 256 - 512     |
| Gara rindkopa / strukturēts JSON       | 1024 - 2048   |
| Cik garu atļauj konteksta logs         | izlaid to     |

Tur `input_tokens + max_tokens` ērti zem konteksta loga (4096 tokeni macOS 26 un M1/M2 Mac datoros, 8192 macOS 27 ar M3 vai jaunāku mikroshēmu un vismaz 12 GB (Apple AFM 3 Core Advanced modelis)). Ja pats prompts pārsniedz logu, ģenerēšana nevar sākties un pieprasījums beidzas ar kļūdu `[context overflow]` (HTTP 400 / CLI exit 4). Validators noraida nepozitīvas vērtības (`max_tokens <= 0`).

### CLI paritāte

CLI un serveris ievēro vienu noteikumu: izlaists = izmanto atlikušo logu. Nav konstantes, kas varētu novirzīties. Pārsedz ar `--max-tokens N` vai `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Atlaidīgi guardrails serverim

`apfel --serve --permissive` liek serverim izmantot Apple `.permissiveContentTransformations` guardrails **katram pieprasījumam**, ko apstrādā process. Tas pats karodziņš, tā pati semantika kā CLI `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Pārsegšana katram pieprasījumam atsevišķi nav iespējama - servera operators lemj visam procesam.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ierobežojumi

| Ierobežojums | Detaļas |
|------------|--------|
| Konteksta logs | **4096 tokeni macOS 26 un M1/M2 Mac datoros, 8192 tokeni macOS 27 ar M3 vai jaunāku mikroshēmu un vismaz 12 GB** (ievade + izvade kopā). Nav iekodēta konstante - apfel izpildlaikā nolasa `SystemLanguageModel.contextSize`; `apfel --model-info` izdrukā aktuālo vērtību |
| Platforma | macOS 26+, tikai Apple Silicon |
| Modelis | Viens ierīcē darbināms modelis (~3B parametru), pieejams kā `apple-foundationmodel` (vispārīgais) un `apple-foundationmodel-content-tagging` (Apple satura marķēšanas adapteris; bez rīkiem) |
| Guardrails | Apple drošības sistēma var bloķēt nekaitīgus promptus. `--permissive` samazina viltus pozitīvos ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Ātrums | Ierīcē, nevis mākoņa mērogā - dažas sekundes uz atbildi |
| Nav embeddings | Nav pieejami ierīcē |
| Vision | Attēlu ievade sasniedz modeli tikai macOS 27 (serveris: data URL; CLI: `-f photo.jpg` un pārsūtīti attēli, papildus OCR tekstam). macOS 26 attēli ir tikai teksts, izmantojot OCR/klasifikāciju. 3B modeļa ainu apraksti ir rupji - OCR joprojām ir uzticamais kanāls drukāta teksta lasīšanai |
| Apmācības dati / zināšanu robeža | Apple nav publicējis precīzu robežu ierīces modelim. Kad modeli piespiež to nosaukt, tas **katru reizi izdomā citu datumu** (piem., "October 2023", "April 2023"). Uzskati visus modeļa paša ziņojumus par savu apmācību par neuzticamiem. |
| Nav pašreizējā datuma vai reāllaika apzināšanās | Modelis nezina šodienas datumu un tam nav piekļuves tīklam vai pulkstenim. Ja pajautā, tas vai nu atsakās, vai izdomā datumu. Ievadi pašreizējo datumu sistēmas promptā, ja aprēķins no tā ir atkarīgs (skat. apejas risinājumu zemāk). |

**Apejas risinājums no datuma atkarīgiem promptiem** - ievadi pašreizējo datumu kā sistēmas ziņojumu:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Piezīme: pat ar ievadītu datumu 3B modelis joprojām var halucinēt (īpaši, ja tieši jautā par paša apmācības robežu). Ievadīšana palīdz ģeneratīviem promptiem, kas *izmanto* datumu; tā nepārspēj modeļa refleksu atbildēt par sevi.

Fons: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Atsauces dokumentācija

Ceļveži apfel lietošanai no [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - skat. [docs/guides/index.md](../docs/guides/index.md). Empīriski pārbaudīts; palaižams pierādījums vietnē [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalēšana, problēmu novēršana un Apple Intelligence iestatīšana
- [docs/cli-reference.md](../docs/cli-reference.md) - visi karodziņi, izejas kodi un vides mainīgie
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` un pārsūtīta PDF / attēla / teksta izvilkšana (OCR + attēla izpratne)
- [docs/background-service.md](../docs/background-service.md) - `brew services` un launchd lietošana
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` atbalsta matrica detalizēti
- [docs/server-security.md](../docs/server-security.md) - origin pārbaudes, CORS, tokeni un `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - čata apgriešanas stratēģijas
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokāla un attālā MCP lietošana
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - detalizēta rīku izsaukšanas darbība
- [docs/integrations.md](../docs/integrations.md) - trešo pušu rīku integrācijas (opencode u. c.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokāla pārskatīšana ar apfel + otru edit/apply modeli VS Code
- [docs/demos.md](../docs/demos.md) - garāki shell demo pārskati
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ īsti prompti ar nerediģētu izvadi
- [docs/swift-library.md](../docs/swift-library.md) - Swift pakotne `ApfelCore` tālāk atkarīgajiem izstrādātājiem
- [docs/coreai-impact.md](../docs/coreai-impact.md) - kāpēc apfel darbojas uz FoundationModels, nevis uz Apple jaunā Core AI (Core ML pēctecis)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel salīdzinājums ar Apple paša `fm` CLI (macOS 27), funkcija pa funkcijai ar izmērītiem skaitļiem

## Arhitektūra

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Trīs targets: `ApfelCore` (tīra loģika, vienībtestējama, pieejama arī kā Swift Package produkts - saite iepriekš sadaļā Atsauces dokumentācija), `apfel` (CLI + serveris) un `apfel-tests` (tīrs Swift izpildītājs, bez XCTest).

## Būvēšana un testi

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

`.version` ir vienīgais patiesības avots. Versijas paaugstina tikai `make release`. Lokālās būves versiju nemaina.

## apfel koks

Projekti, kas būvēti uz apfel. Katrs tiek izplatīts kā atsevišķs repozitorijs + Homebrew formula.

| Projekts | Ko tas dara | Instalēšana |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Sakne. Ierīces FoundationModels CLI + OpenAI saderīgs serveris. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS čata klients: streaming markdown, runas ievade/izvade, attēlu analīze ar Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Izvēlņu joslas MI darbības ar starpliktuvi: apkopot, tulkot, pārrakstīt. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Tūlītējs MI pārklājums: nospied taustiņu, pajautā, saņem atbildi, aizver. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formulu piezīmju bloks - ierīces MI kā iekļauta šūnas funkcija. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokenu budžetam optimizēti MCP mazajam ierīces logam: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI atkļūdošanas inspektors: pieprasījumu laika josla, MCP protokola skatītājs, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX apvalks, kas pievieno pastāvīgu MCP reģistru + TOML konfigurāciju virs `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Ierīces satura atzīmēšanas CLI: ieliec tekstu pipe, saņem tagus/tēmas/emocijas. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift pakotne ekosistēmas rīkiem: atrast, palaist un straumēt no lokāla `apfel --serve`. | Swift Package |

## Kopienas projekti

Uzbūvēji kaut ko uz apfel bāzes? Atver issue, un to var pievienot šeit.

| Projekts | Ko tas dara | Saites |
|---------|-------------|-------|
| **apfelclaw**, autors [@julianYaman](https://github.com/julianYaman) | Lokāls MI aģents, kas lasa failus, kalendāru, pastu un Mac stāvokli ar tikai lasāmiem rīkiem | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, autors [@bhaskarvilles](https://github.com/bhaskarvilles) | Pārlūkprogrammas čata saskarne, kas sazinās ar `apfel --serve` pa OpenAI saderīgo API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, autors [@lucaspwo](https://github.com/lucaspwo) | Claude Code apvalks, kas apfel ievieš kā lokālu backend ar nelielu Anthropic-OpenAI starpniekserveri | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, autors [@hasit](https://github.com/hasit) | Lietotņu pārvaldnieks lokālām shell lietotnēm, kas būvētas ap apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, autors [@eggsy](https://github.com/eggsy) | Raycast komandjoslas paplašinājums: jautāt, tulkot, skaidrot failus un direktorijas, sarunu vēsture, pielāgoti sistēmas prompti. Ierīcē ar apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Līdzdalība

Issues un PR ir laipni gaidīti jebkurā `Arthur-Ficial/apfel*` repozitorijā.

**#agentswelcome** - MI aģentu PR ir pieņemami. Izlasi repozitorija `CLAUDE.md`, palaid testus, norādi rīku `Co-Authored-By` trailer. Tāda pati latiņa kā cilvēkiem: tīrs kods, izturēti testi, godīgi ierobežojumi. Aģentiem draudzīgākais sākumpunkts: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([līdzdalības noteikumi](https://apfel-mcp.franzai.com/#contribute)).

## Licence

[MIT](../LICENSE)
