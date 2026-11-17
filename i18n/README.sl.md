<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> Prevedeno iz [angleškega README](../README.md). Angleška različica je merodajna.

# apfel

### Brezplačna umetna inteligenca, ki je že na vašem Macu.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Računalniki Mac z Apple Silicon imajo vgrajen LLM prek [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` ga izpostavi kot orodje UNIX in lokalni strežnik, združljiv z OpenAI. 100 % na napravi. Brez API ključev, brez oblaka.

| Način | Ukaz | Kaj dobite |
|------|---------|--------------|
| Orodje UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Odgovori, primerni za cevovode (pipe), priloge datotek, izpis JSON, izhodne kode |
| Strežnik, združljiv z OpenAI | `apfel --serve` | Lokalno zaledje `http://localhost:11434/v1` kot neposredna zamenjava za OpenAI SDK-je |

`apfel --chat` - interaktivni REPL.

[![Predstavitveni video apfel v terminalu: prave ukazne vrstice, pravi odgovori na napravi (82 sekund)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/sl/a/apfel-ai-tutorial/#video)

Klicanje orodij deluje v vseh kontekstih.

![apfel CLI](../screenshots/cli.png)

## Zahteve in namestitev

macOS 26 Tahoe+, Apple Silicon (M1+), [vklopljen Apple Intelligence](https://support.apple.com/en-us/121115). Na macOS 27 računalniki Mac s čipom M3 ali novejšim in 12 GB+ poganjajo Applov večji model na napravi z oknom 8192 tokenov; računalniki Mac z M1/M2 in vsi Maci z macOS 26 imajo 4096. `apfel --model-info` pokaže vašo vrednost.

```bash
brew install apfel
```

Posodobitev:

```bash
brew upgrade apfel
```

Gradnja iz izvorne kode (Command Line Tools z macOS 27 SDK / Swift 6.3, brez Xcode; binarna datoteka teče na macOS 26 in 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, odpravljanje težav: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | **Slovenščina** | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Hitri začetek

### Orodje UNIX

Pozive z `!` damo v enojne narekovaje (razširitev zgodovine v zsh/bash): `apfel 'Hello, Mac!'`.

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

### Strežnik, združljiv z OpenAI

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

Podrobnosti o storitvi v ozadju: [docs/background-service.md](../docs/background-service.md).

### Klepet za hitro preizkušanje

`apfel --chat` je majhen REPL za preizkušanje pozivov ali strežnikov MCP. Za klepetalno aplikacijo z grafičnim vmesnikom glejte [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C zapre program. Kontekst se samodejno krajša ([docs/context-strategies.md](../docs/context-strategies.md)).

Omejitve, ki jih je dobro poznati, preden pišete skripte (okno konteksta glede na Mac, zaščitne ograje, brez embeddings): [Omejitve](../README.md#limitations).

## Demo skripte

Prave lupinske skripte, ki ovijajo `apfel`: `cmd` (angleščina v ukaz lupine), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Vgrajene so v binarno datoteko - kloniranje repozitorija ni potrebno. Izpišite jih tja, od koder ste namestili apfel (homebrew-core, tap ali izvorna koda):

```bash
apfel demos ./apfel-demos
```

To zapiše vse demo skripte (izvršljive) in `README.md` v `./apfel-demos`. Nato jih zaženite od tam:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Po `brew upgrade apfel` ponovno zaženite `apfel demos`, da se osvežijo. Izvorna koda: [`demo/`](../demo/). Podrobni primeri in shell funkcija `cmd` za kopiranje v vaš `.zshrc`: [docs/demos.md](../docs/demos.md).

## Podpora za orodja MCP

Strežnike [Model Context Protocol](https://modelcontextprotocol.io/) priključite z `--mcp`. apfel jih odkrije, pokliče in vrne rezultat.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Z `-q` skrijete informacije o orodjih.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Vključen je kalkulator v [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Oddaljeni strežniki MCP** (Streamable HTTP, specifikacija MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Varnost:** raje uporabite `APFEL_MCP_TOKEN` kot `--mcp-token` (viden v ps aux). apfel zavrne bearer žetone prek nešifriranega `http://`.

## apfel-run: izbirna konfiguracijska plast

apfel sam nima konfiguracijske datoteke - zastavice + okoljske spremenljivke, kot vsako orodje UNIX. Če želite konfiguracijo TOML (veliko MCP-jev, profili, ekipne konfiguracije v gitu), je [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) ovojnica z licenco MIT, ki jo doda prek neposredne zamenjave z `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Združljivost z OpenAI API

**Osnovni URL:** `http://localhost:11434/v1`

| Funkcija | Stanje | Opombe |
|---------|--------|-------|
| `POST /v1/chat/completions` | Podprto | Pretočno + nepretočno |
| `POST /v1/responses` | Podprto | OpenAI Responses API: vnos kot niz/sporočilo, `instructions`, pretakanje (kanonično zaporedje dogodkov), `text.format` (vklj. `json_schema`), funkcijska orodja (nepretočno). Funkcije s stanjem (`previous_response_id`, `store: true`, `background`, `reasoning`, gostovana orodja) vrnejo pošten 501 |
| `POST /v1/responses/input_tokens` | Podprto | Predhodni izračun tokenov (`client.responses.input_tokens.count(...)`): natančno štetje z Applovim tokenizatorjem, brez generiranja; 501 pod macOS 26.4 namesto ocene. Glejte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Podprto | Vrne `apple-foundationmodel` (splošni, privzeti) in `apple-foundationmodel-content-tagging` (oznake, ne proza). Glejte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Podprto | Razpoložljivost modela, okno konteksta, jeziki, sporočene zmožnosti modela (`capabilities`, `capabilities_reported`), različica modela, ki streže (`variant`, npr. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Samo za razhroščevanje | Zahteva `--debug` |
| Klicanje orodij | Podprto | Klic se zapiše z vodenim generiranjem (`--tool-calling guided`, privzeto) ali kot JSON, ki ga razčleni strežnik (`--tool-calling text`). Glejte [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Podprto | Vstavljanje v sistemski poziv; markdown ograje se iz izpisa odstranijo |
| `response_format: json_schema` | Podprto | Zagotovljen izpis, skladen s shemo, prek FoundationModels `DynamicGenerationSchema`; deluje s `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Podprto | Preslikano v `GenerationOptions`. `top_p` je nucleus sampling; `temperature` pod 0.001 (vključno z 0) se preslika v greedy (deterministično). Če `max_tokens` izpustite, se uporabi preostalo okno konteksta (semantika kot pri OpenAI) - glejte [Privzeta omejitev odgovora](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Podprto | SSE; končni usage chunk samo ob `stream_options: {"include_usage": true}` (po specifikaciji OpenAI) |
| `usage` | Podprto | Pravo štetje tokenizatorja na macOS 26.4+ (pod tem ocena chars/4). macOS 27: lastno štetje izvajalnega okolja vklj. z Applovim okvirjem chat predloge (približno 46 dodatnih `prompt_tokens` pri enovrstičnem pozivu); macOS 26: apfel šteje besedilo sporočila. Podrobnosti v [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Podprto | `stop`, `tool_calls`, `length` |
| Strategije konteksta | Podprto | Razširitvena polja `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Podprto | Vklopite z `--cors` |
| `POST /v1/completions` | 501 | Starejši tekstovni completions niso podprti |
| `POST /v1/embeddings` | 501 | Embeddings na napravi niso na voljo |
| `stop` | Podprto | Niz ali do 4 nizi; samo navadno besedilo (400, če so v igri orodja ali `json_object`/`json_schema`). Uporabljeno na strani izpisa, enako pri pretočnem in nepretočnem načinu. Glejte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Izrecno zavrnjeno. `n=1` in `logprobs=false` se sprejmeta kot brez učinka |
| Večmodalnost (slike) | Podprto na macOS 27 | Deli `image_url` kot base64 data URL gredo izvorno v model na napravi (omejitev 20 MB base64, najdaljša stranica pomanjšana na 4096 px). Oddaljeni `http(s)` URL-ji in poti do datotek so vedno 400 - apfel nikoli ne prenaša slik in nikoli ne bere datotek za HTTP odjemalca. Na macOS 26: 400 z jasno napako. Glejte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Glava `Authorization` | Podprto | Obvezna, ko je nastavljen `--token`. Glejte [docs/server-security.md](../docs/server-security.md) |

Celotna specifikacija API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Privzeta omejitev odgovora (`max_tokens`)

Ko je `max_tokens` izpuščen, se **CLI in strežnik, združljiv z OpenAI, obnašata enako**: vrednost se posreduje kot `nil` in model uporabi ves prostor, ki je še ostal v oknu konteksta. To je semantika kot pri OpenAI - brez poljubne nadomestne konstante.

Okno konteksta na napravi vsebuje vhod *in* izhod skupaj: **4096 tokenov na macOS 26 in na računalnikih Mac z M1/M2, 8192 tokenov na macOS 27 s čipom M3 ali novejšim in 12 GB+**. apfel dejansko velikost prebere med izvajanjem prek `SystemLanguageModel.contextSize` - svojo preverite z `apfel --model-info`. Če generiranje zadene zgornjo mejo, se odgovor čisto konča z `finish_reason: "length"` in vrne se delna vsebina (strežnik: HTTP 200; CLI: izhod 0 z opozorilom na stderr ali izhod 8 z `--require-complete` - glejte [docs/cli-reference.md](../docs/cli-reference.md)). `max_tokens` podajte izrecno, kadar želite strožji proračun zakasnitve ali znano omejitev za svojega odjemalca.

### Primeri

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

### Izbira vrednosti

| Primer uporabe                         | `max_tokens`  |
|----------------------------------------|---------------|
| Odgovor z eno besedo / klasifikacija   | 16 - 32       |
| Navodilo v eni vrstici                 | 64 - 128      |
| Kratek odstavek                        | 256 - 512     |
| Dolg odstavek / strukturiran JSON      | 1024 - 2048   |
| Kolikor dopušča okno konteksta         | izpustite     |

`input_tokens + max_tokens` naj ostane udobno pod oknom konteksta (4096 tokenov na macOS 26 in na računalnikih Mac z M1/M2, 8192 na macOS 27 s čipom M3 ali novejšim in 12 GB+ (Applov model AFM 3 Core Advanced)). Če sam poziv presega okno, se generiranje ne more začeti in zahteva spodleti z `[context overflow]` (HTTP 400 / izhod CLI 4). Validator zavrne nepozitivne vrednosti (`max_tokens <= 0`).

### Enakovrednost CLI

CLI in strežnik delita eno pravilo: izpuščeno = uporabi preostalo okno. Brez konstante, ki bi se razhajala. Preglasite z `--max-tokens N` ali `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive zaščitne ograje za strežnik

`apfel --serve --permissive` povzroči, da strežnik za **vsako zahtevo**, ki jo proces obdela, uporablja Applove zaščitne ograje `.permissiveContentTransformations`. Ista zastavica, ista semantika kot `--permissive` v CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Preglasitve na zahtevo ni - odloča upravljavec strežnika za ves proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Omejitve

| Omejitev | Podrobnosti |
|------------|--------|
| Okno konteksta | **4096 tokenov na macOS 26 in na računalnikih Mac z M1/M2, 8192 tokenov na macOS 27 s čipom M3 ali novejšim in 12 GB+** (vhod + izhod skupaj). Ni trdo zakodirana konstanta - apfel med izvajanjem prebere `SystemLanguageModel.contextSize`; `apfel --model-info` izpiše trenutno vrednost |
| Platforma | Samo macOS 26+, Apple Silicon |
| Model | En model na napravi (~3B parametrov), na voljo kot `apple-foundationmodel` (splošni) in `apple-foundationmodel-content-tagging` (Applov adapter za označevanje vsebine; brez orodij) |
| Zaščitne ograje | Applov varnostni sistem lahko blokira neškodljive pozive. `--permissive` zmanjša lažne pozitivne zadetke ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Hitrost | Na napravi, ne v obsegu oblaka - nekaj sekund na odgovor |
| Brez embeddings | Na napravi niso na voljo |
| Vid | Slikovni vhod doseže model samo na macOS 27 (strežnik: data URL-ji; CLI: `-f photo.jpg` in slike prek pipe, poleg OCR besedila). Na macOS 26 so slike samo besedilo prek OCR/klasifikacije. Opisi prizorov modela s 3B so grobi - OCR ostaja zanesljiv kanal za branje tiskanega besedila |
| Učni podatki / datum zaključka znanja | Apple ni objavil natančnega datuma za model na napravi. Ko ga silite, da ga navede, model **pri vsakem vzorcu izmisli drug datum** (npr. "oktober 2023", "april 2023"). Vse izjave modela o lastnem učenju obravnavajte kot nezanesljive. |
| Brez trenutnega datuma in zavedanja realnega časa | Model ne pozna današnjega datuma in nima dostopa do omrežja ali ure. Če ga vprašate, bo bodisi zavrnil bodisi izmislil datum. Trenutni datum vstavite prek sistemskega poziva, kadar je od njega odvisen izračun (glejte obvod spodaj). |

**Obvod za pozive, odvisne od datuma** - trenutni datum vstavite kot sistemsko sporočilo:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Opomba: tudi z vstavljenim datumom lahko model s 3B še vedno halucinira (zlasti, če ga neposredno vprašate o lastnem datumu zaključka učenja). Vstavljanje pomaga generativnim pozivom, ki datum *uporabljajo*; ne preglasi refleksa modela, da poroča o samem sebi.

Ozadje: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referenčna dokumentacija

Vodniki za uporabo apfel iz [Pythona](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Rubyja](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScripta](../docs/guides/applescript.md), [Swifta](../docs/guides/swift-scripting.md), [Perla](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - glejte [docs/guides/index.md](../docs/guides/index.md). Empirično preizkušeno; zagonljiv dokaz na [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - namestitev, odpravljanje težav in nastavitev Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - vsaka zastavica, izhodna koda in okoljska spremenljivka
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` in izvlek PDF / slik / besedila prek pipe (OCR + razumevanje slik)
- [docs/background-service.md](../docs/background-service.md) - uporaba `brew services` in launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - podrobna matrika podpore `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - preverjanje izvora, CORS, žetoni in `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategije krajšanja v klepetu
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - uporaba lokalnega in oddaljenega MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - podrobno obnašanje klicanja orodij
- [docs/integrations.md](../docs/integrations.md) - integracije z orodji tretjih strani (opencode itd.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokalni pregled z apfel + drugim modelom za urejanje/uporabo v VS Code
- [docs/demos.md](../docs/demos.md) - daljši primeri shell demo skript
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ resničnih pozivov z neurejenim izpisom
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` za razvijalce, ki gradijo na njem
- [docs/coreai-impact.md](../docs/coreai-impact.md) - zakaj apfel teče na FoundationModels in ne na Applovem novem Core AI (naslednik Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - primerjava apfel z Applovim lastnim CLI `fm` (macOS 27), funkcijo za funkcijo z izmerjenimi številkami

## Arhitektura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strogi concurrency. Trije cilji: `ApfelCore` (čista logika, primerna za enotne teste, na voljo tudi kot Swift Package - povezan pod Referenčna dokumentacija zgoraj), `apfel` (CLI + strežnik) in `apfel-tests` (čisti Swift runner, brez XCTest).

## Gradnja in testiranje

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

`.version` je edini vir resnice. Različice povečuje samo `make release`. Lokalne gradnje različice ne spreminjajo.

## Drevo apfel

Projekti, zgrajeni na apfel. Vsak prihaja kot lasten repozitorij + Homebrew formula.

| Projekt | Kaj dela | Namestitev |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Koren. CLI za FoundationModels na napravi + strežnik, združljiv z OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Klepetalni odjemalec za macOS: pretočni markdown, govorni vhod/izhod, analiza slik z Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | AI dejanja v menijski vrstici na odložišču: povzemanje, prevajanje, prepisovanje. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Takojšnji AI prekrivni vmesnik: pritisnete tipko, vprašate, dobite odgovor, zaprete. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Beležnica s formulami - AI na napravi kot vrstična funkcija celice. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP-ji, optimizirani za proračun tokenov v majhnem oknu na napravi: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI inšpektor za razhroščevanje: časovnica zahtev, pregledovalnik protokola MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Ovojnica UNIX, ki nad `apfel` doda trajni register MCP + konfiguracijo TOML. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI za označevanje vsebine na napravi: vnesete besedilo, dobite oznake/teme/čustva. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift paket za orodja ekosistema: odkrivanje, zagon in pretakanje iz lokalnega `apfel --serve`. | Swift Package |

## Projekti skupnosti

Ste zgradili kaj na osnovi apfel? Odprite issue in lahko bo dodano sem.

| Projekt | Kaj dela | Povezave |
|---------|-------------|-------|
| **apfelclaw** avtorja [@julianYaman](https://github.com/julianYaman) | Lokalni AI agent, ki bere datoteke, koledar, pošto in stanje Maca prek orodij samo za branje | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** avtorja [@bhaskarvilles](https://github.com/bhaskarvilles) | Spletni klepetalni vmesnik, ki prek API-ja, združljivega z OpenAI, govori z `apfel --serve` | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** avtorja [@lucaspwo](https://github.com/lucaspwo) | Ovojnica za Claude Code, ki prek majhnega posrednika Anthropic-OpenAI vstavi apfel kot lokalno zaledje | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** avtorja [@hasit](https://github.com/hasit) | Upravljalnik aplikacij za lokalne lupinske aplikacije, zgrajene okoli apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** avtorja [@eggsy](https://github.com/eggsy) | Razširitev ukazne vrstice Raycast: vprašajte, prevajajte, razlagajte datoteke in mape, zgodovina pogovorov, lastni sistemski pozivi. Na napravi prek apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Prispevanje

Issue-ji in PR-ji so dobrodošli v vsakem repozitoriju `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR-ji AI agentov so v redu. Preberite `CLAUDE.md` repozitorija, zaženite teste, v trailerju `Co-Authored-By` navedite orodje. Enaka merila kot za ljudi: čista koda, uspešni testi, poštene omejitve. Za agente najprimernejša vstopna točka: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([pravila za prispevke](https://apfel-mcp.franzai.com/#contribute)).

## Licenca

[MIT](../LICENSE)
