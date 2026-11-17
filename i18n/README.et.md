<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Tõlgitud [ingliskeelsest README-st](../README.md). Ingliskeelne versioon on määrav.

# apfel

### Tasuta tehisintellekt, mis on juba sinu Macis.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Macidel on sisseehitatud LLM [Apple FoundationModelsi](https://developer.apple.com/documentation/foundationmodels) kaudu. `apfel` teeb selle kättesaadavaks UNIX-tööriista ja kohaliku OpenAI-ühilduva serverina. 100 % seadmes. Ei mingeid API-võtmeid, ei mingit pilve.

| Režiim | Käsk | Mida saad |
|------|---------|--------------|
| UNIX-tööriist | `apfel "prompt"` / `echo "text" \| apfel` | Torudega sobivad vastused, failimanused, JSON-väljund, väljumiskoodid |
| OpenAI-ühilduv server | `apfel --serve` | Kohalik `http://localhost:11434/v1` taustasüsteem, mis asendab otse OpenAI SDK-de sihtkoha |

`apfel --chat` - interaktiivne REPL.

[![apfeli terminali demovideo: päris käsud, päris vastused otse seadmes (84 sekundit)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/et/a/apfel-ai-tutorial/#video)

Tööriistakutsed töötavad igas kontekstis.

![apfel CLI](../screenshots/cli.png)

## Nõuded ja paigaldus

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence lubatud](https://support.apple.com/en-us/121115). macOS 27-l töötavad M3 või uuema kiibi ja vähemalt 12 GB-ga Macid Apple'i suuremat seadmesisest mudelit 8192-tokenilise aknaga; M1/M2 Macidel ja kõigil macOS 26 Macidel on 4096. `apfel --model-info` näitab sinu oma.

```bash
brew install apfel
```

Uuendamine:

```bash
brew upgrade apfel
```

Ehitamine lähtekoodist (Command Line Tools koos macOS 27 SDK / Swift 6.3-ga, ilma Xcodeta; binaar töötab macOS 26 ja 27 peal):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, veaotsing: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | **Eesti** | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Kiirstart

### UNIX-tööriist

Pane `!` sisaldavad promptid ühekordsetesse jutumärkidesse (zsh/bashi ajaloo laiendamine): `apfel 'Hello, Mac!'`.

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

### OpenAI-ühilduv server

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

Taustateenuse üksikasjad: [docs/background-service.md](../docs/background-service.md).

### Kiire testimise chat

`apfel --chat` on väike REPL promptide või MCP-serverite testimiseks. Graafilise liidesega chati rakenduse jaoks vaata [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C väljub. Kontekst kärbitakse automaatselt ([docs/context-strategies.md](../docs/context-strategies.md)).

Piirangud, mida tasub teada enne selle vastu skriptimist (kontekstiaken Maci kohta, guardrailid, embeddinguid pole): [Piirangud](../README.md#limitations).

## Demod

Päris shelli skriptid, mis ümbritsevad `apfel`it: `cmd` (inglise keel shelli käsuks), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Need on binaari sisse ehitatud - repo kloonimist pole vaja. Kirjuta need välja sinna, kust apfeli paigaldasid (homebrew-core, tap või lähtekood):

```bash
apfel demos ./apfel-demos
```

See kirjutab kõik demod (käivitatavatena) ning `README.md` kausta `./apfel-demos`. Seejärel käivita need sealt:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Käivita `apfel demos` pärast `brew upgrade apfel` uuesti, et need värskendada. Lähtekood: [`demo/`](../demo/). Läbimängud ja sinu `.zshrc` jaoks kopeeritav `cmd` shelli funktsioon: [docs/demos.md](../docs/demos.md).

## MCP tööriistade tugi

Ühenda [Model Context Protocol](https://modelcontextprotocol.io/) servereid lülitiga `--mcp`. apfel avastab, kutsub ja tagastab.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Tööriistainfo peitmiseks kasuta `-q`.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Kaasas on kalkulaator kaustas [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Kaug-MCP serverid** (Streamable HTTP, MCP spetsifikatsioon 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Turvalisus:** eelista `APFEL_MCP_TOKEN` lülile `--mcp-token` (ps aux). apfel keeldub saatmast bearer-tokeneid krüpteerimata `http://` kaudu.

## apfel-run: valikuline konfiguratsioonikiht

apfelil endal pole konfiguratsioonifaili - lülid + keskkonnamuutujad, nagu igal UNIX-tööriistal. Kui soovid TOML-konfiguratsiooni (palju MCP-sid, profiilid, meeskonna konfiguratsioonid gitis), on [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) MIT-litsentsiga ümbris, mis lisab selle `execve` asendajana.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API ühilduvus

**Baas-URL:** `http://localhost:11434/v1`

| Funktsioon | Olek | Märkused |
|---------|--------|-------|
| `POST /v1/chat/completions` | Toetatud | Streaming + ilma streamingita |
| `POST /v1/responses` | Toetatud | OpenAI Responses API: stringi-/sõnumisisend, `instructions`, streaming (kanooniline sündmuste jada), `text.format` (sh `json_schema`), funktsioonitööriistad (ilma streamingita). Olekupõhised funktsioonid (`previous_response_id`, `store: true`, `background`, `reasoning`, hostitud tööriistad) tagastavad ausa 501 |
| `POST /v1/responses/input_tokens` | Toetatud | Tokenite eelkontroll (`client.responses.input_tokens.count(...)`): täpne arv Apple'i tokeniseerijalt, genereerimist ei toimu; 501 macOS 26.4-st vanemal hinnangu asemel. Vaata [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Toetatud | Tagastab `apple-foundationmodel` (üldine, vaikimisi) ja `apple-foundationmodel-content-tagging` (sildid, mitte proosa). Vaata [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Toetatud | Mudeli saadavus, kontekstiaken, keeled, teatatud mudeli võimekused (`capabilities`, `capabilities_reported`), teenindav mudelivariant (`variant`, nt AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Ainult silumine | Nõuab `--debug` |
| Tööriistakutsed | Toetatud | Kutse kirjutatakse juhitud genereerimisega (`--tool-calling guided`, vaikimisi) või JSON-ina, mille server parsib (`--tool-calling text`). Vaata [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Toetatud | Süsteemiprompti süst; markdown-aiad eemaldatakse väljundist |
| `response_format: json_schema` | Toetatud | Garanteeritult skeemile vastav väljund FoundationModelsi `DynamicGenerationSchema` kaudu; töötab koos `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Toetatud | Seotud `GenerationOptions`iga. `top_p` on nucleus sampling; `temperature` alla 0.001 (0 kaasa arvatud) vastab greedy-režiimile (deterministlik). `max_tokens` väljajätmisel kasutatakse kontekstiakna ülejäänud osa (OpenAI semantika drop-in-asendajana) - vaata [Vaikimisi vastuse piir](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Toetatud | SSE; viimane usage-chunk ainult siis, kui `stream_options: {"include_usage": true}` (OpenAI spetsifikatsiooni järgi) |
| `usage` | Toetatud | Päris tokeniseerija arvud macOS 26.4+ peal (sellest vanemal märgid/4 hinnang). macOS 27: käitusaja enda arvestus sh Apple'i chat-malli raamistus (umbes 46 lisa-`prompt_tokens` üherealise prompti puhul); macOS 26: apfel loeb sõnumi teksti. Üksikasjad: [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Toetatud | `stop`, `tool_calls`, `length` |
| Konteksti strateegiad | Toetatud | Laiendusväljad `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Toetatud | Lülita sisse lülitiga `--cors` |
| `POST /v1/completions` | 501 | Vanu tekstitäiendusi ei toetata |
| `POST /v1/embeddings` | 501 | Embeddingud pole seadmes saadaval |
| `stop` | Toetatud | Üks string või kuni 4 stringi; ainult lihttekst (400, kui tööriistad on kasutuses või `json_object`/`json_schema`). Rakendatakse väljundi poolel, identselt streamingus ja ilma. Vaata [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Lükatakse selgesõnaliselt tagasi. `n=1` ja `logprobs=false` aktsepteeritakse tühioperatsioonidena |
| Multimodaalsus (pildid) | Toetatud macOS 27-l | `image_url` osad base64 data-URL-idena lähevad natiivselt seadmesisesele mudelile (20 MB base64 piir, pikim külg skaleeritakse alla 4096 px-ni). Kaug-`http(s)` URL-id ja failiteed on alati 400 - apfel ei too kunagi pilte ega loe HTTP-kliendi jaoks faile. macOS 26-l: 400 koos selge veateatega. Vaata [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` päis | Toetatud | Nõutav, kui `--token` on seatud. Vaata [docs/server-security.md](../docs/server-security.md) |

Täielik API spetsifikatsioon: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Vaikimisi vastuse piir (`max_tokens`)

Kui `max_tokens` on välja jäetud, **käituvad CLI ja OpenAI-ühilduv server identselt**: väärtus liigub edasi kui `nil` ja mudel kasutab kogu kontekstiaknas allesjäänud ruumi. See on OpenAI semantika drop-in-asendajana - mingit suvalist varakonstanti pole.

Seadmesisene kontekstiaken mahutab sisendi *ja* väljundi kokku: **4096 tokenit macOS 26-l ja M1/M2 Macidel, 8192 tokenit macOS 27-l M3 või uuema kiibi ja vähemalt 12 GB-ga**. apfel loeb tegeliku suuruse käitusajal `SystemLanguageModel.contextSize` kaudu - kontrolli oma oma käsuga `apfel --model-info`. Kui genereerimine jõuab lakke, lõpeb vastus puhtalt väärtusega `finish_reason: "length"` ja osaline sisu tagastatakse (server: HTTP 200; CLI: exit 0 ja stderr-hoiatus või exit 8 lülitiga `--require-complete` - vaata [docs/cli-reference.md](../docs/cli-reference.md)). Anna `max_tokens` selgesõnaliselt, kui soovid rangemat latentsuse eelarvet või teadaolevat piiri oma kliendile.

### Näited

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

### Väärtuse valimine

| Kasutusjuht                            | `max_tokens`  |
|----------------------------------------|---------------|
| Ühesõnaline vastus / klassifitseerimine | 16 - 32      |
| Ühe rea juhis                          | 64 - 128      |
| Lühike lõik                            | 256 - 512     |
| Pikk lõik / struktureeritud JSON       | 1024 - 2048   |
| Nii pikalt, kui kontekstiaken lubab    | jäta välja    |

Hoia `input_tokens + max_tokens` mugavalt kontekstiakna all (4096 tokenit macOS 26-l ja M1/M2 Macidel, 8192 macOS 27-l M3 või uuema kiibi ja vähemalt 12 GB-ga (Apple'i AFM 3 Core Advanced mudel)). Kui prompt ise ületab akna, ei saa genereerimine alata ja päring ebaõnnestub veaga `[context overflow]` (HTTP 400 / CLI exit 4). Validaator lükkab tagasi mittepositiivsed väärtused (`max_tokens <= 0`).

### CLI vastavus

CLI ja server jagavad ühte reeglit: väljajäetud = kasuta allesjäänud akent. Pole konstanti, mis saaks triivida. Alista lülitiga `--max-tokens N` või `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Lubavad guardrailid serverile

`apfel --serve --permissive` paneb serveri kasutama Apple'i `.permissiveContentTransformations` guardraile **igale päringule**, mida protsess käsitleb. Sama lüliti, samad semantikad nagu CLI `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Päringupõhist alistamist pole - serveri haldaja otsustab kogu protsessi eest.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Piirangud

| Piirang | Üksikasjad |
|------------|--------|
| Kontekstiaken | **4096 tokenit macOS 26-l ja M1/M2 Macidel, 8192 tokenit macOS 27-l M3 või uuema kiibi ja vähemalt 12 GB-ga** (sisend + väljund kokku). Pole kõvakodeeritud konstant - apfel loeb `SystemLanguageModel.contextSize` käitusajal; `apfel --model-info` prindib tegeliku väärtuse |
| Platvorm | macOS 26+, ainult Apple Silicon |
| Mudel | Üks seadmesisene mudel (~3B parameetrit), pakutud kui `apple-foundationmodel` (üldine) ja `apple-foundationmodel-content-tagging` (Apple'i sisu sildistamise adapter; tööriistadeta) |
| Guardrailid | Apple'i turvasüsteem võib blokeerida kahjutuid prompte. `--permissive` vähendab valepositiivseid ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Kiirus | Seadmes, mitte pilvemastaabis - paar sekundit vastuse kohta |
| Embeddinguid pole | Pole seadmes saadaval |
| Vision | Pildisisend jõuab mudelini ainult macOS 27-l (server: data-URL-id; CLI: `-f photo.jpg` ja torutatud pildid, lisaks OCR-tekstile). macOS 26-l on pildid ainult tekstina OCR-i/klassifitseerimise kaudu. 3B mudeli stseenikirjeldused on jämedad - OCR jääb usaldusväärseks kanaliks trükitud teksti lugemiseks |
| Treeningandmed / teadmiste piirdaatum | Apple pole seadmesisese mudeli täpset piirdaatumit avaldanud. Kui mudelit sundida üht nimetama, **mõtleb ta igal korral välja erineva kuupäeva** (nt "October 2023", "April 2023"). Käsitle kõiki mudeli enda väiteid oma treenimise kohta ebausaldusväärsetena. |
| Praegust kuupäeva ega reaalajateadlikkust pole | Mudel ei tea tänast kuupäeva ning tal pole võrgu- ega kellajaligipääsu. Küsimise korral ta kas keeldub või mõtleb kuupäeva välja. Anna praegune kuupäev ette süsteemipromptis, kui arvutus sellest sõltub (vaata allolevat lahendust). |

**Lahendus kuupäevast sõltuvatele promptidele** - anna praegune kuupäev ette süsteemisõnumina:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Märkus: isegi etteantud kuupäevaga võib 3B mudel siiski hallutsineerida (eriti kui küsida otse tema enda treeningu piirdaatumi kohta). Etteandmine aitab generatiivseid prompte, mis kuupäeva *kasutavad*; see ei alista mudeli refleksi vastata enda kohta.

Taust: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Viidete dokumentatsioon

Juhendid apfeli kasutamiseks keeltest ja tööriistadest [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - vaata [docs/guides/index.md](../docs/guides/index.md). Empiiriliselt testitud; käivitatav tõestus aadressil [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - paigaldus, veaotsing ja Apple Intelligence'i seadistus
- [docs/cli-reference.md](../docs/cli-reference.md) - kõik lülitid, väljumiskoodid ja keskkonnamuutujad
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ja torutatud PDF- / pildi- / tekstiväljavõte (OCR + pildi mõistmine)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ja launchd kasutus
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` toetusmaatriks põhjalikult
- [docs/server-security.md](../docs/server-security.md) - origin-kontrollid, CORS, tokenid ja `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - chati kärpimisstrateegiad
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - kohalik ja kaug-MCP kasutus
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - tööriistakutsete üksikasjalik käitumine
- [docs/integrations.md](../docs/integrations.md) - kolmandate osapoolte tööriistade integratsioonid (opencode jne)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - kohalik ülevaatus apfeli + teise edit/apply mudeliga VS Codes
- [docs/demos.md](../docs/demos.md) - shelli demode pikemad läbimängud
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - üle 50 päris prompti muutmata väljundiga
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` allavoolu arendajatele
- [docs/coreai-impact.md](../docs/coreai-impact.md) - miks apfel töötab FoundationModelsil, mitte Apple'i uuel Core AI-l (Core ML-i järeltulija)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel võrrelduna Apple'i enda `fm` CLI-ga (macOS 27), funktsioon funktsiooni haaval mõõdetud arvudega

## Arhitektuur

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Kolm targetit: `ApfelCore` (puhas loogika, ühikutestitav, saadaval ka Swift Package tootena - lingitud ülalpool jaotises Viidete dokumentatsioon), `apfel` (CLI + server) ja `apfel-tests` (puhas Swift-jooksutaja, ilma XCTestita).

## Ehitus ja testid

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

`.version` on ainus tõeallikas. Ainult `make release` tõstab versioone. Kohalikud ehitused versiooni ei muuda.

## apfeli puu

Apfelile ehitatud projektid. Igaüks tarnitakse oma repo + Homebrew valemina.

| Projekt | Mida see teeb | Paigaldus |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Juur. Seadmesisene FoundationModels CLI + OpenAI-ühilduv server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS chati klient: streaming-markdown, kõne sisend/väljund, piltide analüüs Apple Visioniga. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Menüüribas olevad tehisintellekti toimingud lõikelauale: kokkuvõte, tõlge, ümberkirjutus. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Kohene tehisintellekti ülekate: vajuta klahvi, küsi, saa vastus, sulge. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Valemimärkmik - seadmesisene tehisintellekt reasisese lahtrifunktsioonina. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokeni-eelarvele optimeeritud MCP-d väikese seadmesisese akna jaoks: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI silumisinspektor: päringute ajajoon, MCP protokolli vaatur, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-ümbris, mis lisab `apfel`ile püsiva MCP registri + TOML-konfiguratsiooni. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Seadmesisene sisu märgendamise CLI: torusta tekst sisse, saa väljund siltidena/teemadena/emotsioonidena. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-pakett ökosüsteemi tööriistadele: leia, käivita ja voogesita kohalikust `apfel --serve`-st. | Swift Package |

## Kogukonna projektid

Ehitasid apfelile midagi peale? Ava issue ja see võidakse siia lisada.

| Projekt | Mida see teeb | Lingid |
|---------|-------------|-------|
| **apfelclaw**, autor [@julianYaman](https://github.com/julianYaman) | Kohalik tehisintellekti agent, mis loeb faile, kalendrit, e-posti ja Maci olekut kirjutuskaitstud tööriistade kaudu | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, autor [@bhaskarvilles](https://github.com/bhaskarvilles) | Brauseripõhine chati liides, mis räägib `apfel --serve`-iga OpenAI-ühilduva API kaudu | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, autor [@lucaspwo](https://github.com/lucaspwo) | Claude Code ümbris, mis vahetab apfeli kohaliku taustasüsteemina sisse väikese Anthropic-OpenAI puhverserveri kaudu | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, autor [@hasit](https://github.com/hasit) | Rakenduste haldur apfeli ümber ehitatud kohalikele shelli rakendustele | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, autor [@eggsy](https://github.com/eggsy) | Raycasti käsuriba laiendus: küsi, tõlgi, selgita faile ja kaustu, vestlusajalugu, kohandatud süsteemipromptid. Seadmes apfel CLI kaudu. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Panustamine

Issue'd ja PR-id on teretulnud igas `Arthur-Ficial/apfel*` repos.

**#agentswelcome** - tehisintellekti agentide PR-id sobivad. Loe repo `CLAUDE.md`, käivita testid, maini tööriista `Co-Authored-By` trailer'is. Sama lati nagu inimestel: puhas kood, läbivad testid, ausad piirangud. Agentide jaoks sõbralikuim sisenemispunkt: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([panustamisreeglid](https://apfel-mcp.franzai.com/#contribute)).

## Litsents

[MIT](../LICENSE)
