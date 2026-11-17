<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Išversta iš [angliško README](../README.md). Autoritetinga yra angliška versija.

# apfel

### Nemokamas DI, jau esantis jūsų Mac kompiuteryje.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac kompiuteriuose yra įmontuotas LLM per [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` jį pateikia kaip UNIX įrankį ir vietinį su OpenAI suderinamą serverį. 100 % įrenginyje. Be API raktų, be debesies.

| Režimas | Komanda | Ką gaunate |
|---------|---------|------------|
| UNIX įrankis | `apfel "prompt"` / `echo "text" \| apfel` | Atsakymai, tinkami konvejeriams, failų priedai, JSON išvestis, išėjimo kodai |
| Su OpenAI suderinamas serveris | `apfel --serve` | Vietinė `http://localhost:11434/v1` sąsaja, tiesiogiai pakeičianti OpenAI SDK paslaugą |

`apfel --chat` - interaktyvus REPL.

[![apfel demonstracinis vaizdo įrašas terminale: tikros komandos, tikri atsakymai įrenginyje (82 sekundės)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/lt/a/apfel-ai-tutorial/#video)

Įrankių iškvietimas veikia visuose kontekstuose.

![apfel CLI](../screenshots/cli.png)

## Reikalavimai ir diegimas

macOS 26 Tahoe+, Apple Silicon (M1+), [įjungtas Apple Intelligence](https://support.apple.com/en-us/121115). Sistemoje macOS 27 Mac kompiuteriai su M3 ar naujesniu lustu ir 12 GB+ atminties naudoja didesnį Apple įrenginyje veikiantį modelį su 8192 žetonų langu; M1/M2 Mac kompiuteriai ir visi Mac su macOS 26 turi 4096. `apfel --model-info` parodo jūsiškį.

```bash
brew install apfel
```

Atnaujinimas:

```bash
brew upgrade apfel
```

Kompiliavimas iš šaltinio (Command Line Tools su macOS 27 SDK / Swift 6.3, be Xcode; programa veikia macOS 26 ir 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tą pačią dieną atnaujinamas tap, Mint, mise, trikčių šalinimas: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | **Lietuvių** | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Greitas startas

### UNIX įrankis

Promptus su `!` rašykite tarp apostrofų (zsh/bash istorijos išplėtimas): `apfel 'Hello, Mac!'`.

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

### Su OpenAI suderinamas serveris

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

Foninės paslaugos detalės: [docs/background-service.md](../docs/background-service.md).

### Pokalbis greitam testavimui

`apfel --chat` yra nedidelis REPL promptams ar MCP serveriams išbandyti. Grafinės pokalbių programos ieškokite [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C išjungia sesiją. Kontekstas apkarpomas automatiškai ([docs/context-strategies.md](../docs/context-strategies.md)).

Apribojimai, kuriuos verta žinoti prieš rašant skriptus (konteksto langas pagal Mac, guardrails, jokių embeddings): [Apribojimai](../README.md#limitations).

## Demonstracijos

Tikri shell skriptai, apgaubiantys `apfel`: `cmd` (anglų kalba į shell komandą), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Jie įtraukti į vykdomąjį failą - repozitorijos klonuoti nereikia. Išsaugokite juos ten, iš kur įdiegėte apfel (homebrew-core, tap arba šaltinis):

```bash
apfel demos ./apfel-demos
```

Tai įrašo kiekvieną demonstraciją (vykdomą) ir `README.md` į `./apfel-demos`. Tada paleiskite jas iš ten:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Po `brew upgrade apfel` paleiskite `apfel demos` iš naujo, kad atnaujintumėte. Šaltiniai: [`demo/`](../demo/). Žingsnis po žingsnio aprašymai ir `cmd` shell funkcija, kurią galima nukopijuoti į `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP įrankių palaikymas

Prijunkite [Model Context Protocol](https://modelcontextprotocol.io/) serverius per `--mcp`. apfel randa įrankius, juos iškviečia ir grąžina rezultatą.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Naudokite `-q`, kad paslėptumėte informaciją apie įrankius.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Kartu pateikiamas skaičiuotuvas [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Nuotoliniai MCP serveriai** (Streamable HTTP, MCP specifikacija 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Saugumas:** vietoj `--mcp-token` (ps aux) naudokite `APFEL_MCP_TOKEN`. apfel atsisako siųsti bearer žetonus per nešifruotą `http://`.

## apfel-run: pasirenkamas konfigūracijos sluoksnis

Pats apfel neturi konfigūracijos failo - vėliavėlės ir aplinkos kintamieji, kaip ir bet kuris UNIX įrankis. Jei norite TOML konfigūracijos (daug MCP, profiliai, komandų konfigūracijos git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) yra MIT licencijos apvalkalas, kuris ją prideda kaip tiesioginį pakaitalą per `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Suderinamumas su OpenAI API

**Base URL:** `http://localhost:11434/v1`

| Funkcija | Būsena | Pastabos |
|----------|--------|----------|
| `POST /v1/chat/completions` | Palaikoma | Su srautiniu perdavimu ir be jo |
| `POST /v1/responses` | Palaikoma | OpenAI Responses API: įvestis kaip string/žinutė, `instructions`, srautinis perdavimas (kanoninė įvykių seka), `text.format` (įskaitant `json_schema`), funkciniai įrankiai (be srauto). Būsenos funkcijos (`previous_response_id`, `store: true`, `background`, `reasoning`, talpinami įrankiai) grąžina sąžiningą 501 |
| `POST /v1/responses/input_tokens` | Palaikoma | Išankstinis žetonų skaičiavimas (`client.responses.input_tokens.count(...)`): tikslus skaičius iš Apple tokenizatoriaus, be generavimo; žemiau macOS 26.4 grąžina 501, o ne įvertį. Žr. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Palaikoma | Grąžina `apple-foundationmodel` (bendrasis, numatytasis) ir `apple-foundationmodel-content-tagging` (žymės, ne rišlus tekstas). Žr. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Palaikoma | Modelio prieinamumas, konteksto langas, kalbos, pranešamos modelio galimybės (`capabilities`, `capabilities_reported`), aptarnaujantis modelio variantas (`variant`, pvz., AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Tik derinimui | Reikia `--debug` |
| Įrankių iškvietimas | Palaikoma | Iškvietimas rašomas valdomu generavimu (`--tool-calling guided`, numatytasis) arba kaip JSON, kurį išanalizuoja serveris (`--tool-calling text`). Žr. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Palaikoma | Įterpimas į sistemos promptą; markdown tvoros iš išvesties pašalinamos |
| `response_format: json_schema` | Palaikoma | Garantuota schemą atitinkanti išvestis per FoundationModels `DynamicGenerationSchema`; veikia su `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Palaikoma | Susiejama su `GenerationOptions`. `top_p` yra nucleus sampling; `temperature` žemiau 0.001 (įskaitant 0) susiejama su greedy (deterministiniu) mėginiu. Praleidus `max_tokens`, naudojamas likęs konteksto langas (tiesioginio OpenAI pakaitalo semantika) - žr. [Numatytasis atsakymo limitas](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Palaikoma | SSE; galutinis `usage` fragmentas tik su `stream_options: {"include_usage": true}` (pagal OpenAI specifikaciją) |
| `usage` | Palaikoma | Tikri tokenizatoriaus skaičiai macOS 26.4+ (žemiau - įvertis simboliai/4). macOS 27: paties vykdymo aplinkos apskaita su Apple pokalbio šablono rėmeliu (apie 46 papildomi `prompt_tokens` vienos eilutės prompte); macOS 26: apfel skaičiuoja žinutės tekstą. Detalės [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Palaikoma | `stop`, `tool_calls`, `length` |
| Konteksto strategijos | Palaikoma | Plėtinių laukai `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Palaikoma | Įjunkite per `--cors` |
| `POST /v1/completions` | 501 | Senesnis teksto užbaigimas nepalaikomas |
| `POST /v1/embeddings` | 501 | Embeddings įrenginyje nepasiekiami |
| `stop` | Palaikoma | String arba iki 4 string; tik paprastas tekstas (400, jei veikia įrankiai arba `json_object`/`json_schema`). Taikoma išvesties pusėje, vienodai su srautu ir be jo. Žr. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Atmetama aiškiai. `n=1` ir `logprobs=false` priimami kaip nieko nedarantys |
| Multimodalumas (vaizdai) | Palaikoma macOS 27 | `image_url` dalys kaip base64 data URL natyviai perduodamos įrenginyje veikiančiam modeliui (20 MB base64 riba, ilgesnė kraštinė sumažinama iki 4096 px). Nuotolinės `http(s)` nuorodos ir failų keliai visada duoda 400 - apfel niekada nesiunčia vaizdų ir neskaito failų HTTP kliento vardu. macOS 26: 400 su aiškia klaida. Žr. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` antraštė | Palaikoma | Privaloma, kai nustatytas `--token`. Žr. [docs/server-security.md](../docs/server-security.md) |

Pilna API specifikacija: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Numatytasis atsakymo limitas (`max_tokens`)

Kai `max_tokens` praleistas, **CLI ir su OpenAI suderinamas serveris elgiasi vienodai**: reikšmė perduodama kaip `nil`, o modelis naudoja visą konteksto lange likusią vietą. Tai tiesioginio OpenAI pakaitalo semantika - jokios savavališkos atsarginės konstantos.

Įrenginio konteksto lange telpa įvestis *ir* išvestis kartu: **4096 žetonai macOS 26 ir M1/M2 Mac kompiuteriuose, 8192 žetonai macOS 27 su M3 ar naujesniu lustu ir 12 GB+**. apfel tikrąjį dydį nuskaito vykdymo metu per `SystemLanguageModel.contextSize` - savo patikrinkite per `apfel --model-info`. Jei generavimas pasiekia ribą, atsakymas tvarkingai baigiasi su `finish_reason: "length"` ir grąžinamas dalinis turinys (serveris: HTTP 200; CLI: exit 0 su stderr įspėjimu arba exit 8 su `--require-complete` - žr. [docs/cli-reference.md](../docs/cli-reference.md)). Nurodykite `max_tokens` aiškiai, kai norite griežtesnio delsos biudžeto arba žinomos ribos savo klientui.

### Pavyzdžiai

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

### Reikšmės pasirinkimas

| Naudojimo atvejis                      | `max_tokens`  |
|----------------------------------------|---------------|
| Vieno žodžio atsakymas / klasifikacija | 16 - 32       |
| Vienos eilutės nurodymas               | 64 - 128      |
| Trumpa pastraipa                       | 256 - 512     |
| Ilga pastraipa / struktūrizuotas JSON  | 1024 - 2048   |
| Tiek, kiek leidžia konteksto langas    | praleiskite   |

Laikykite `input_tokens + max_tokens` su patogia atsarga žemiau konteksto lango (4096 žetonai macOS 26 ir M1/M2 Mac kompiuteriuose, 8192 macOS 27 su M3 ar naujesniu lustu ir 12 GB+ (Apple AFM 3 Core Advanced modelis)). Jei pats promptas viršija langą, generavimas negali prasidėti ir užklausa nepavyksta su `[context overflow]` (HTTP 400 / CLI exit 4). Validatorius atmeta neteigiamas reikšmes (`max_tokens <= 0`).

### Atitiktis su CLI

CLI ir serveris laikosi vienos taisyklės: praleista = naudoti likusį langą. Nėra konstantos, kuri galėtų išsiderinti. Pakeiskite per `--max-tokens N` arba `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Atlaidūs guardrails serveriui

`apfel --serve --permissive` priverčia serverį naudoti Apple `.permissiveContentTransformations` guardrails **kiekvienai užklausai**, kurią apdoroja procesas. Ta pati vėliavėlė, ta pati semantika kaip CLI `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Pakeitimo atskirai kiekvienai užklausai nėra - sprendžia serverio operatorius visam procesui.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Apribojimai

| Apribojimas | Detalės |
|-------------|---------|
| Konteksto langas | **4096 žetonai macOS 26 ir M1/M2 Mac kompiuteriuose, 8192 žetonai macOS 27 su M3 ar naujesniu lustu ir 12 GB+** (įvestis + išvestis kartu). Tai ne užkoduota konstanta - apfel nuskaito `SystemLanguageModel.contextSize` vykdymo metu; `apfel --model-info` parodo dabartinę reikšmę |
| Platforma | macOS 26+, tik Apple Silicon |
| Modelis | Vienas įrenginyje veikiantis modelis (~3 mlrd. parametrų), teikiamas kaip `apple-foundationmodel` (bendrasis) ir `apple-foundationmodel-content-tagging` (Apple turinio žymėjimo adapteris; be įrankių) |
| Guardrails | Apple saugumo sistema gali blokuoti nekenksmingus promptus. `--permissive` sumažina klaidingų aliarmų ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Greitis | Įrenginyje, ne debesies mastu - keletas sekundžių vienam atsakymui |
| Jokių embeddings | Įrenginyje nepasiekiama |
| Regėjimas | Vaizdo įvestis pasiekia modelį tik macOS 27 (serveris: data URL; CLI: `-f photo.jpg` ir per konvejerį perduodami vaizdai, greta OCR teksto). macOS 26 vaizdai yra tik tekstas per OCR/klasifikaciją. 3B modelio scenų aprašymai grubūs - OCR lieka patikimu kanalu spausdintam tekstui skaityti |
| Mokymo duomenys / žinių riba | Apple nepaskelbė tikslios įrenginyje veikiančio modelio žinių ribos datos. Paspaustas ją įvardyti, modelis **kiekvieną kartą susigalvoja kitą datą** (pvz., "October 2023", "April 2023"). Visus modelio pasisakymus apie savo mokymą laikykite nepatikimais. |
| Nėra dabartinės datos ar realaus laiko suvokimo | Modelis nežino šiandienos datos ir neturi prieigos prie tinklo ar laikrodžio. Paklaustas, arba atsisakys, arba susigalvos datą. Kai skaičiavimas priklauso nuo datos, įterpkite dabartinę datą per sistemos promptą (žr. apėjimo būdą žemiau). |

**Apėjimo būdas promptams, priklausantiems nuo datos** - įterpkite dabartinę datą kaip sistemos žinutę:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Pastaba: net su įterpta data 3B modelis vis tiek gali haliucinuoti (ypač paklaustas tiesiogiai apie savo mokymo ribą). Įterpimas padeda generatyviniams promptams, kurie datą *naudoja*; jis nenugali modelio savęs aprašymo refleksyvumo.

Foninė informacija: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Nuorodų dokumentacija

Vadovai, kaip naudoti apfel iš [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - žr. [docs/guides/index.md](../docs/guides/index.md). Išbandyta empiriškai; paleidžiamas įrodymas [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - diegimas, trikčių šalinimas ir Apple Intelligence nustatymas
- [docs/cli-reference.md](../docs/cli-reference.md) - kiekviena vėliavėlė, išėjimo kodas ir aplinkos kintamasis
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ir per konvejerį perduodamų PDF / vaizdų / teksto išgavimas (OCR + vaizdo supratimas)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ir launchd naudojimas
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - išsami `/v1/*` palaikymo matrica
- [docs/server-security.md](../docs/server-security.md) - origin patikros, CORS, žetonai ir `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - pokalbio apkarpymo strategijos
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - vietinis ir nuotolinis MCP naudojimas
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - išsamus įrankių iškvietimo elgesys
- [docs/integrations.md](../docs/integrations.md) - trečiųjų šalių įrankių integracijos (opencode ir kt.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - vietinė peržiūra su apfel + antruoju redagavimo/taikymo modeliu VS Code
- [docs/demos.md](../docs/demos.md) - ilgesni shell demonstracijų aprašymai
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ tikrų promptų su neredaguota išvestimi
- [docs/swift-library.md](../docs/swift-library.md) - `ApfelCore` Swift paketas kūrėjams
- [docs/coreai-impact.md](../docs/coreai-impact.md) - kodėl apfel veikia su FoundationModels, o ne su naujuoju Apple Core AI (Core ML įpėdiniu)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel palyginimas su paties Apple `fm` CLI (macOS 27), funkcija po funkcijos su išmatuotais skaičiais

## Architektūra

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 su griežtu lygiagretumu. Trys tikslai: `ApfelCore` (gryna logika, tinkama vienetiniams testams, taip pat prieinama kaip Swift Package produktas - nuoroda aukščiau Nuorodų dokumentacijoje), `apfel` (CLI + serveris) ir `apfel-tests` (gryna Swift vykdyklė, be XCTest).

## Kompiliavimas ir testai

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

`.version` yra vienintelis tiesos šaltinis. Versijas didina tik `make release`. Vietiniai buildai versijos nekeičia.

## apfel medis

Projektai, sukurti ant apfel. Kiekvienas turi savo repozitoriją ir Homebrew formulę.

| Projektas | Ką daro | Diegimas |
|-----------|---------|----------|
| [**apfel**](https://apfel.franzai.com) | Šaknis. Įrenginyje veikiantis FoundationModels CLI + su OpenAI suderinamas serveris. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS pokalbių klientas: markdown srautinis perdavimas, kalbos įvestis/išvestis, vaizdų analizė per Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Meniu juostos DI veiksmai iškarpinei: apibendrinti, išversti, perrašyti. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Momentinis DI langas: paspauskite klavišą, paklauskite, gaukite atsakymą, uždarykite. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formulių užrašinė - įrenginyje veikiantis DI kaip langelio funkcija tekste. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Žetonų biudžetui optimizuoti MCP mažam įrenginio langui: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI derinimo inspektorius: užklausų laiko juosta, MCP protokolo peržiūra, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX apvalkalas, pridedantis nuolatinį MCP registrą + TOML konfigūraciją virš `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Įrenginyje veikiantis turinio žymėjimo CLI: perduokite tekstą konvejeriu, gaukite žymas/temas/emocijas. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift paketas ekosistemos įrankiams: aptikti, paleisti ir gauti srautą iš vietinio `apfel --serve`. | Swift Package |

## Bendruomenės projektai

Sukūrėte ką nors ant apfel? Atidarykite issue ir projektą galima pridėti čia.

| Projektas | Ką daro | Nuorodos |
|-----------|---------|----------|
| **apfelclaw**, autorius [@julianYaman](https://github.com/julianYaman) | Vietinis DI agentas, skaitantis failus, kalendorių, paštą ir Mac būseną per tik skaitymo įrankius | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, autorius [@bhaskarvilles](https://github.com/bhaskarvilles) | Naršyklės pokalbių sąsaja, kalbanti su `apfel --serve` per su OpenAI suderinamą API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, autorius [@lucaspwo](https://github.com/lucaspwo) | Claude Code apvalkalas, kuris per nedidelį Anthropic-OpenAI tarpinį serverį pakeičia vidinę sistemą vietiniu apfel | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, autorius [@hasit](https://github.com/hasit) | Programų tvarkyklė vietinėms shell programoms, sukurtoms aplink apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, autorius [@eggsy](https://github.com/eggsy) | Raycast komandų juostos plėtinys: klausimai, vertimas, failų ir katalogų paaiškinimai, pokalbių istorija, savi sistemos promptai. Įrenginyje per apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Prisidėjimas

Issues ir PR laukiami bet kurioje `Arthur-Ficial/apfel*` repozitorijoje.

**#agentswelcome** - DI agentų PR yra gerai. Perskaitykite repozitorijos `CLAUDE.md`, paleiskite testus, nurodykite įrankį `Co-Authored-By` trailer. Ta pati kartelė kaip žmonėms: švarus kodas, praeinantys testai, sąžiningi apribojimai. Agentams draugiškiausias įėjimo taškas: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([prisidėjimo taisyklės](https://apfel-mcp.franzai.com/#contribute)).

## Licencija

[MIT](../LICENSE)
