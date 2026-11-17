<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Prevedeno s [engleskog README-a](../README.md). Engleska verzija je mjerodavna.

# apfel

### Besplatna umjetna inteligencija koja je već na tvom Macu.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macovi s Apple Siliconom dolaze s ugrađenim LLM-om putem [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` ga izlaže kao UNIX alat i lokalni poslužitelj kompatibilan s OpenAI-jem. 100 % na uređaju. Bez API ključeva, bez oblaka.

| Način | Naredba | Što dobivate |
|------|---------|--------------|
| UNIX alat | `apfel "prompt"` / `echo "text" \| apfel` | Odgovori prikladni za pipe, privitci datoteka, JSON izlaz, izlazni kodovi |
| Poslužitelj kompatibilan s OpenAI-jem | `apfel --serve` | Lokalni backend `http://localhost:11434/v1` kao izravna zamjena za OpenAI SDK-ove |

`apfel --chat` - interaktivni REPL.

[![Demo video apfela u terminalu: stvarne naredbe, stvarni odgovori na uređaju (82 sekunde)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/hr/a/apfel-ai-tutorial/#video)

Pozivanje alata radi u svim kontekstima.

![apfel CLI](../screenshots/cli.png)

## Zahtjevi i instalacija

macOS 26 Tahoe+, Apple Silicon (M1+), [uključen Apple Intelligence](https://support.apple.com/en-us/121115). Na macOS-u 27 Macovi s čipom M3 ili novijim i 12 GB+ pokreću Appleov veći model na uređaju s prozorom od 8192 tokena; Macovi s M1/M2 i svaki Mac s macOS-om 26 imaju 4096. `apfel --model-info` prikazuje vašu vrijednost.

```bash
brew install apfel
```

Ažuriranje:

```bash
brew upgrade apfel
```

Izgradnja iz izvornog koda (Command Line Tools s macOS 27 SDK-om / Swift 6.3, bez Xcodea; binarna datoteka radi na macOS-u 26 i 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, rješavanje problema: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | **Hrvatski** | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Brzi početak

### UNIX alat

Promptove s `!` stavljajte u jednostruke navodnike (proširenje povijesti u zsh/bash): `apfel 'Hello, Mac!'`.

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

### Poslužitelj kompatibilan s OpenAI-jem

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

Detalji o pozadinskoj usluzi: [docs/background-service.md](../docs/background-service.md).

### Chat za brzo testiranje

`apfel --chat` je mali REPL za testiranje promptova ili MCP poslužitelja. Za chat aplikaciju s grafičkim sučeljem pogledajte [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C izlazi iz programa. Kontekst se automatski skraćuje ([docs/context-strategies.md](../docs/context-strategies.md)).

Ograničenja koja vrijedi znati prije pisanja skripti (kontekstni prozor po Macu, zaštitne ograde, bez embeddinga): [Ograničenja](../README.md#limitations).

## Demo skripte

Prave shell skripte koje omotavaju `apfel`: `cmd` (engleski u shell naredbu), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Ugrađene su u binarnu datoteku - kloniranje repozitorija nije potrebno. Zapišite ih bilo gdje odakle ste instalirali apfel (homebrew-core, tap ili izvorni kod):

```bash
apfel demos ./apfel-demos
```

To zapisuje sve demo skripte (izvršne) plus `README.md` u `./apfel-demos`. Zatim ih pokrećite odande:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Nakon `brew upgrade apfel` ponovno pokrenite `apfel demos` za osvježavanje. Izvori: [`demo/`](../demo/). Detaljniji primjeri i shell funkcija `cmd` za kopiranje u vaš `.zshrc`: [docs/demos.md](../docs/demos.md).

## Podrška za MCP alate

Spojite [Model Context Protocol](https://modelcontextprotocol.io/) poslužitelje s `--mcp`. apfel ih otkriva, poziva i vraća rezultat.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Koristite `-q` za skrivanje informacija o alatima.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Isporučuje se s kalkulatorom u [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Udaljeni MCP poslužitelji** (Streamable HTTP, MCP specifikacija 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Sigurnost:** radije koristite `APFEL_MCP_TOKEN` nego `--mcp-token` (vidljivo u ps aux). apfel odbija bearer tokene preko nešifriranog `http://`.

## apfel-run: neobavezni konfiguracijski sloj

apfel sam nema konfiguracijsku datoteku - zastavice + varijable okoline, kao svaki UNIX alat. Ako želite TOML konfiguraciju (mnogo MCP-ova, profili, timske konfiguracije u gitu), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) je MIT omotač koji je dodaje kao izravnu zamjenu putem `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Kompatibilnost s OpenAI API-jem

**Osnovni URL:** `http://localhost:11434/v1`

| Značajka | Status | Napomene |
|---------|--------|-------|
| `POST /v1/chat/completions` | Podržano | Streaming + bez streaminga |
| `POST /v1/responses` | Podržano | OpenAI Responses API: ulaz kao string/poruka, `instructions`, streaming (kanonski slijed događaja), `text.format` (uklj. `json_schema`), funkcijski alati (bez streaminga). Značajke sa stanjem (`previous_response_id`, `store: true`, `background`, `reasoning`, hostirani alati) vraćaju iskren 501 |
| `POST /v1/responses/input_tokens` | Podržano | Preflight tokena (`client.responses.input_tokens.count(...)`): točan broj iz Appleova tokenizatora, bez generiranja; 501 ispod macOS-a 26.4 umjesto procjene. Pogledajte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Podržano | Vraća `apple-foundationmodel` (opći, zadani) i `apple-foundationmodel-content-tagging` (oznake, ne prozni tekst). Pogledajte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Podržano | Dostupnost modela, kontekstni prozor, jezici, prijavljene mogućnosti modela (`capabilities`, `capabilities_reported`), varijanta modela koja poslužuje zahtjeve (`variant`, npr. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Samo za debug | Zahtijeva `--debug` |
| Pozivanje alata | Podržano | Poziv se piše putem vođenog generiranja (`--tool-calling guided`, zadano) ili kao JSON koji poslužitelj parsira (`--tool-calling text`). Pogledajte [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Podržano | Ubacivanje u sistemski prompt; markdown ograde se uklanjaju iz izlaza |
| `response_format: json_schema` | Podržano | Zajamčen izlaz sukladan shemi putem FoundationModels `DynamicGenerationSchema`; radi sa `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Podržano | Mapirano na `GenerationOptions`. `top_p` je nucleus sampling; `temperature` ispod 0.001 (uključujući 0) mapira se na greedy (deterministički). Izostavljanje `max_tokens` koristi preostali kontekstni prozor (izravna OpenAI semantika) - pogledajte [Zadano ograničenje odgovora](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Podržano | SSE; završni usage chunk samo uz `stream_options: {"include_usage": true}` (prema OpenAI specifikaciji) |
| `usage` | Podržano | Stvarni brojevi tokenizatora na macOS-u 26.4+ (ispod toga procjena chars/4). macOS 27: vlastito računanje runtimea uklj. Appleov okvir chat predloška (oko 46 dodatnih `prompt_tokens` za jednoredni prompt); macOS 26: apfel broji tekst poruke. Detalji u [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Podržano | `stop`, `tool_calls`, `length` |
| Strategije konteksta | Podržano | Proširena polja `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Podržano | Uključite s `--cors` |
| `POST /v1/completions` | 501 | Naslijeđeni tekstualni completions nisu podržani |
| `POST /v1/embeddings` | 501 | Embeddings nisu dostupni na uređaju |
| `stop` | Podržano | String ili do 4 stringa; samo običan tekst (400 ako su u igri alati ili `json_object`/`json_schema`). Primjenjuje se na strani izlaza, jednako uz streaming i bez njega. Pogledajte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Izričito odbijeno. `n=1` i `logprobs=false` prihvaćaju se kao no-op |
| Multimodalnost (slike) | Podržano na macOS-u 27 | Dijelovi `image_url` kao base64 data URL-ovi idu izvorno u model na uređaju (ograničenje 20 MB base64, najdulja stranica smanjena na 4096 px). Udaljeni `http(s)` URL-ovi i putanje datoteka uvijek su 400 - apfel nikada ne dohvaća slike i nikada ne čita datoteke za HTTP klijenta. Na macOS-u 26: 400 s jasnom greškom. Pogledajte [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Zaglavlje `Authorization` | Podržano | Obavezno kada je postavljen `--token`. Pogledajte [docs/server-security.md](../docs/server-security.md) |

Puna API specifikacija: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Zadano ograničenje odgovora (`max_tokens`)

Kada je `max_tokens` izostavljen, **CLI i poslužitelj kompatibilan s OpenAI-jem ponašaju se identično**: vrijednost se prosljeđuje kao `nil` i model koristi sav prostor preostao u kontekstnom prozoru. To je izravna OpenAI semantika - bez proizvoljne zamjenske konstante.

Kontekstni prozor na uređaju drži ulaz *i* izlaz zajedno: **4096 tokena na macOS-u 26 i na Macovima s M1/M2, 8192 tokena na macOS-u 27 s čipom M3 ili novijim i 12 GB+**. apfel stvarnu veličinu čita u runtimeu putem `SystemLanguageModel.contextSize` - provjerite svoju s `apfel --model-info`. Ako generiranje udari u gornju granicu, odgovor se čisto završava s `finish_reason: "length"` i vraća se djelomičan sadržaj (poslužitelj: HTTP 200; CLI: izlaz 0 s upozorenjem na stderr, ili izlaz 8 uz `--require-complete` - pogledajte [docs/cli-reference.md](../docs/cli-reference.md)). Zadajte `max_tokens` izričito kada želite stroži proračun latencije ili poznato ograničenje za svog klijenta.

### Primjeri

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

### Odabir vrijednosti

| Slučaj uporabe                         | `max_tokens`  |
|----------------------------------------|---------------|
| Odgovor od jedne riječi / klasifikacija | 16 - 32      |
| Jednoredna uputa                       | 64 - 128      |
| Kratak odlomak                         | 256 - 512     |
| Dugačak odlomak / strukturirani JSON   | 1024 - 2048   |
| Koliko god kontekstni prozor dopušta   | izostavite    |

Držite `input_tokens + max_tokens` udobno ispod kontekstnog prozora (4096 tokena na macOS-u 26 i na Macovima s M1/M2, 8192 na macOS-u 27 s čipom M3 ili novijim i 12 GB+ (Appleov model AFM 3 Core Advanced)). Ako sam prompt premašuje prozor, generiranje ne može započeti i zahtjev ne uspijeva s `[context overflow]` (HTTP 400 / CLI izlaz 4). Validator odbija nepozitivne vrijednosti (`max_tokens <= 0`).

### CLI paritet

CLI i poslužitelj dijele jedno pravilo: izostavljeno = koristi preostali prozor. Nema konstante koja bi se razilazila. Nadjačajte s `--max-tokens N` ili `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive zaštitne ograde za poslužitelj

`apfel --serve --permissive` tjera poslužitelj da za **svaki zahtjev** koji proces obradi koristi Appleove zaštitne ograde `.permissiveContentTransformations`. Ista zastavica, ista semantika kao `--permissive` u CLI-ju ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Nema nadjačavanja po zahtjevu - operater poslužitelja odlučuje za cijeli proces.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ograničenja

| Ograničenje | Detalji |
|------------|--------|
| Kontekstni prozor | **4096 tokena na macOS-u 26 i na Macovima s M1/M2, 8192 tokena na macOS-u 27 s čipom M3 ili novijim i 12 GB+** (ulaz + izlaz zajedno). Nije tvrdo kodirana konstanta - apfel u runtimeu čita `SystemLanguageModel.contextSize`; `apfel --model-info` ispisuje trenutnu vrijednost |
| Platforma | Samo macOS 26+, Apple Silicon |
| Model | Jedan model na uređaju (~3B parametara), dostupan kao `apple-foundationmodel` (opći) i `apple-foundationmodel-content-tagging` (Appleov adapter za označavanje sadržaja; bez alata) |
| Zaštitne ograde | Appleov sigurnosni sustav može blokirati bezazlene promptove. `--permissive` smanjuje lažne pozitive ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Brzina | Na uređaju, ne u razmjeru oblaka - nekoliko sekundi po odgovoru |
| Bez embeddinga | Nisu dostupni na uređaju |
| Vizija | Ulaz slike dolazi do modela samo na macOS-u 27 (poslužitelj: data URL-ovi; CLI: `-f photo.jpg` i slike preko pipea, povrh OCR teksta). Na macOS-u 26 slike su samo tekst putem OCR-a/klasifikacije. Opisi scena modela od 3B su grubi - OCR ostaje pouzdan kanal za čitanje tiskanog teksta |
| Podaci za treniranje / granica znanja | Apple nije objavio točan datum za model na uređaju. Kad ga se prisili da ga navede, model **pri svakom uzorku izmisli drugi datum** (npr. "listopad 2023.", "travanj 2023."). Sve izjave modela o vlastitom treniranju smatrajte nepouzdanima. |
| Nema trenutnog datuma ni svijesti o stvarnom vremenu | Model ne zna današnji datum i nema pristup mreži ni satu. Ako ga upitate, ili će odbiti ili će izmisliti datum. Trenutni datum ubacite putem sistemskog prompta kada račun ovisi o njemu (pogledajte zaobilazno rješenje u nastavku). |

**Zaobilazno rješenje za promptove ovisne o datumu** - ubacite trenutni datum kao sistemsku poruku:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Napomena: čak i s ubačenim datumom model od 3B i dalje može halucinirati (osobito kad ga se izravno pita o vlastitoj granici treniranja). Ubacivanje pomaže generativnim promptovima koji datum *koriste*; ne nadjačava refleks modela da izvještava o sebi.

Pozadina: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referentna dokumentacija

Vodiči za korištenje apfela iz [Pythona](../docs/guides/python.md), [Node.js-a](../docs/guides/nodejs.md), [Rubyja](../docs/guides/ruby.md), [PHP-a](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScripta](../docs/guides/applescript.md), [Swifta](../docs/guides/swift-scripting.md), [Perla](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - pogledajte [docs/guides/index.md](../docs/guides/index.md). Empirijski testirano; pokretljiv dokaz na [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalacija, rješavanje problema i postavljanje Apple Intelligencea
- [docs/cli-reference.md](../docs/cli-reference.md) - svaka zastavica, izlazni kod i varijabla okoline
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` i izvlačenje PDF-a / slika / teksta preko pipea (OCR + razumijevanje slika)
- [docs/background-service.md](../docs/background-service.md) - korištenje `brew services` i launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - detaljna matrica podrške za `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - provjere podrijetla, CORS, tokeni i `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategije skraćivanja u chatu
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - korištenje lokalnog i udaljenog MCP-a
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - detaljno ponašanje pozivanja alata
- [docs/integrations.md](../docs/integrations.md) - integracije s alatima trećih strana (opencode itd.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokalni pregled s apfelom + drugim modelom za uređivanje/primjenu u VS Codeu
- [docs/demos.md](../docs/demos.md) - dulji primjeri shell demo skripti
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ stvarnih promptova s neuređenim izlazom
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` za razvojne programere koji grade na njemu
- [docs/coreai-impact.md](../docs/coreai-impact.md) - zašto apfel radi na FoundationModels, a ne na Appleovom novom Core AI-ju (nasljednik Core MLa)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - usporedba apfela s Appleovim vlastitim CLI-jem `fm` (macOS 27), značajku po značajku s izmjerenim brojevima

## Arhitektura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strogi concurrency. Tri targeta: `ApfelCore` (čista logika, prikladna za unit testove, dostupna i kao Swift Package - poveznica pod Referentna dokumentacija gore), `apfel` (CLI + poslužitelj) i `apfel-tests` (čisti Swift runner, bez XCTesta).

## Izgradnja i testiranje

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

`.version` je jedini izvor istine. Verzije diže samo `make release`. Lokalne izgradnje ne mijenjaju verziju.

## Stablo apfela

Projekti izgrađeni na apfelu. Svaki dolazi kao zaseban repozitorij + Homebrew formula.

| Projekt | Što radi | Instalacija |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Korijen. CLI za FoundationModels na uređaju + poslužitelj kompatibilan s OpenAI-jem. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Chat klijent za macOS: streaming markdown, govorni ulaz/izlaz, analiza slika pomoću Apple Visiona. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | AI radnje u traci izbornika nad međuspremnikom: sažimanje, prevođenje, prepisivanje. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Trenutačni AI overlay: pritisnete tipku, pitate, dobijete odgovor, odbacite. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bilježnica s formulama - AI na uređaju kao funkcija ćelije u retku. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP-ovi optimizirani za proračun tokena u malom prozoru na uređaju: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspektor: vremenska crta zahtjeva, pregledavač MCP protokola, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX omotač koji povrh `apfel` dodaje trajni MCP registar + TOML konfiguraciju. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI za označavanje sadržaja na uređaju: pošaljete tekst, dobijete oznake/teme/emocije. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift paket za alate ekosustava: otkrivanje, pokretanje i streaming iz lokalnog `apfel --serve`. | Swift Package |

## Projekti zajednice

Izgradili ste nešto na temelju apfela? Otvorite issue i može se dodati ovdje.

| Projekt | Što radi | Poveznice |
|---------|-------------|-------|
| **apfelclaw** autora [@julianYaman](https://github.com/julianYaman) | Lokalni AI agent koji čita datoteke, kalendar, poštu i stanje Maca putem alata samo za čitanje | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** autora [@bhaskarvilles](https://github.com/bhaskarvilles) | Chat sučelje u pregledniku koje s `apfel --serve` razgovara preko API-ja kompatibilnog s OpenAI-jem | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** autora [@lucaspwo](https://github.com/lucaspwo) | Omotač za Claude Code koji putem malog Anthropic-OpenAI proxyja ubacuje apfel kao lokalni backend | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** autora [@hasit](https://github.com/hasit) | Upravitelj aplikacija za lokalne shell aplikacije izgrađene oko apfela | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** autora [@eggsy](https://github.com/eggsy) | Proširenje za naredbenu traku Raycast: pitanja, prevođenje, objašnjavanje datoteka i direktorija, povijest razgovora, vlastiti sistemski promptovi. Na uređaju putem apfel CLI-ja. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Doprinos

Issuei i PR-ovi dobrodošli su u svakom repozitoriju `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR-ovi AI agenata su u redu. Pročitajte `CLAUDE.md` repozitorija, pokrenite testove, navedite alat u `Co-Authored-By` traileru. Ista mjerila kao za ljude: čist kod, prolazni testovi, iskrena ograničenja. Ulazna točka najprikladnija za agente: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([pravila doprinosa](https://apfel-mcp.franzai.com/#contribute)).

## Licenca

[MIT](../LICENSE)
