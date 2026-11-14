<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Käännös [englanninkielisestä README:stä](../README.md). Englanninkielinen versio on ensisijainen.

# apfel

### Ilmainen tekoäly, joka on jo Macissasi.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon -Maceissa on sisäänrakennettu LLM [Apple FoundationModelsin](https://developer.apple.com/documentation/foundationmodels) kautta. `apfel` tarjoaa sen UNIX-työkaluna ja paikallisena OpenAI-yhteensopivana palvelimena. 100 % laitteella. Ei API-avaimia, ei pilveä.

| Tila | Komento | Mitä saat |
|------|---------|--------------|
| UNIX-työkalu | `apfel "prompt"` / `echo "text" \| apfel` | Putkiin sopivat vastaukset, tiedostoliitteet, JSON-tuloste, paluukoodit |
| OpenAI-yhteensopiva palvelin | `apfel --serve` | Paikallinen `http://localhost:11434/v1`-taustajärjestelmä, joka korvaa suoraan OpenAI SDK:iden kohteen |

`apfel --chat` - interaktiivinen REPL.

Työkalukutsut toimivat kaikissa yhteyksissä.

![apfel CLI](../screenshots/cli.png)

## Vaatimukset ja asennus

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence käytössä](https://support.apple.com/en-us/121115). macOS 27:ssä Macit, joissa on M3 tai uudempi siru ja vähintään 12 GB, ajavat Applen isompaa laitteella toimivaa mallia 8192 tokenin ikkunalla; M1/M2-Macien ja kaikkien macOS 26 -Macien ikkuna on 4096. `apfel --model-info` näyttää omasi.

```bash
brew install apfel
```

Päivitys:

```bash
brew upgrade apfel
```

Käännä lähdekoodista (Command Line Tools ja macOS 27 SDK / Swift 6.3, ei Xcodea; binääri toimii macOS 26:ssa ja 27:ssä):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, same-day tap, Mint, mise, vianmääritys: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | **Suomi** | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Pikaopas

### UNIX-työkalu

Laita `!`-merkkiä sisältävät promptit yksinkertaisiin lainausmerkkeihin (zsh/bash-historian laajennus): `apfel 'Hello, Mac!'`.

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

### OpenAI-yhteensopiva palvelin

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

Taustapalvelun tiedot: [docs/background-service.md](../docs/background-service.md).

### Pikatestauksen chat

`apfel --chat` on pieni REPL promptien tai MCP-palvelimien testaamiseen. Graafisen käyttöliittymän chat-sovellusta varten katso [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C lopettaa. Konteksti typistetään automaattisesti ([docs/context-strategies.md](../docs/context-strategies.md)).

Rajoitukset, jotka kannattaa tietää ennen kuin skriptaat sitä vasten (kontekstiikkuna Maciä kohden, guardrailit, ei embeddingejä): [Rajoitukset](../README.md#limitations).

## Demot

Oikeita shell-skriptejä, jotka kutsuvat `apfel`ia: `cmd` (englanti shell-komennoksi), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Ne on sisällytetty binääriin - repon kloonaus ei tarvita. Kirjoita ne mihin tahansa sieltä, mistä asensit apfelin (homebrew-core, tap tai lähdekoodi):

```bash
apfel demos ./apfel-demos
```

Tämä kirjoittaa kaikki demot (suoritettavina) sekä `README.md`-tiedoston kansioon `./apfel-demos`. Aja ne sitten sieltä:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Aja `apfel demos` uudelleen `brew upgrade apfel` -komennon jälkeen päivittääksesi ne. Lähdekoodi: [`demo/`](../demo/). Läpikäynnit ja `.zshrc`-tiedostoosi kopioitava `cmd`-shell-funktio: [docs/demos.md](../docs/demos.md).

## MCP-työkalutuki

Liitä [Model Context Protocol](https://modelcontextprotocol.io/) -palvelimia valitsimella `--mcp`. apfel löytää, kutsuu ja palauttaa.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Käytä `-q`:ta työkalutietojen piilottamiseen.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Mukana tulee laskin hakemistossa [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Etä-MCP-palvelimet** (Streamable HTTP, MCP-määrittely 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Tietoturva:** käytä mieluummin `APFEL_MCP_TOKEN`ia kuin `--mcp-token`ia (ps aux). apfel kieltäytyy lähettämästä bearer-tokeneita salaamattoman `http://`-yhteyden yli.

## apfel-run: valinnainen konfiguraatiokerros

apfelilla itsellään ei ole konfiguraatiotiedostoa - liput + ympäristömuuttujat, kuten missä tahansa UNIX-työkalussa. Jos haluat TOML-konfiguraation (monta MCP:tä, profiileja, tiimin konfiguraatiot gitissä), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) on MIT-lisensoitu kääre, joka lisää sen `execve`-korvikkeena.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API -yhteensopivuus

**Perus-URL:** `http://localhost:11434/v1`

| Ominaisuus | Tila | Huomautuksia |
|---------|--------|-------|
| `POST /v1/chat/completions` | Tuettu | Streaming + ilman streamingia |
| `POST /v1/responses` | Tuettu | OpenAI Responses API: merkkijono-/viestisyöte, `instructions`, streaming (kanoninen tapahtumajärjestys), `text.format` (mukaan lukien `json_schema`), funktiotyökalut (ilman streamingia). Tilalliset ominaisuudet (`previous_response_id`, `store: true`, `background`, `reasoning`, isännöidyt työkalut) palauttavat rehelliset 501-vastaukset |
| `POST /v1/responses/input_tokens` | Tuettu | Tokenien ennakkotarkistus (`client.responses.input_tokens.count(...)`): tarkka lukumäärä Applen tokenisoijalta, ei generointia; 501 macOS 26.4:ää vanhemmilla arvion sijaan. Katso [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Tuettu | Palauttaa `apple-foundationmodel` |
| `GET /health` | Tuettu | Mallin saatavuus, kontekstiikkuna, kielet, ilmoitetut mallin ominaisuudet (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Vain debug | Vaatii `--debug` |
| Työkalukutsut | Tuettu | Natiivi `ToolDefinition` + JSON-tunnistus. Katso [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Tuettu | Järjestelmäpromptin injektio; markdown-aidat poistetaan tulosteesta |
| `response_format: json_schema` | Tuettu | Skeemaa takuulla noudattava tuloste FoundationModelsin `DynamicGenerationSchema`n kautta; toimii `stream: true` kanssa |
| `temperature`, `top_p`, `max_tokens`, `seed` | Tuettu | Yhdistetty `GenerationOptions`iin. `top_p` on nucleus sampling; `temperature` alle 0.001 (0 mukaan lukien) vastaa greedy-tilaa (deterministinen). Jos `max_tokens` jätetään pois, käytetään kontekstiikkunan jäljellä oleva osa (OpenAI-semantiikka drop-in-korvikkeena) - katso [Oletusvastausraja](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Tuettu | SSE; viimeinen usage-chunk vain kun `stream_options: {"include_usage": true}` (OpenAI-määrittelyn mukaan) |
| `usage` | Tuettu | Todelliset tokenisoijan luvut macOS 26.4+:ssa (merkit/4-arvio sitä vanhemmilla). macOS 27: ajonaikainen oma laskenta mukaan lukien Applen chat-mallin kehystys (noin 46 ylimääräistä `prompt_tokens` yksirivisellä promptilla); macOS 26: apfel laskee viestitekstin. Lisätietoja [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Tuettu | `stop`, `tool_calls`, `length` |
| Kontekstistrategiat | Tuettu | Laajennuskentät `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Tuettu | Otetaan käyttöön valitsimella `--cors` |
| `POST /v1/completions` | 501 | Vanhoja tekstitäydennyksiä ei tueta |
| `POST /v1/embeddings` | 501 | Embeddingejä ei ole saatavilla laitteella |
| `stop` | Tuettu | Merkkijono tai enintään 4 merkkijonoa; vain pelkkä teksti (400, jos työkalut ovat käytössä tai `json_object`/`json_schema`). Sovelletaan tulostepuolella, samoin streamingissa ja ilman. Katso [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Hylätään nimenomaisesti. `n=1` ja `logprobs=false` hyväksytään tyhjinä operaatioina |
| Multimodaalisuus (kuvat) | Tuettu macOS 27:ssä | `image_url`-osat base64-data-URL-osoitteina menevät natiivisti laitteella olevalle mallille (20 MB base64-raja, pisin sivu skaalataan 4096 px:iin). Etä-`http(s)`-URL-osoitteet ja tiedostopolut palauttavat aina 400 - apfel ei koskaan hae kuvia eikä lue tiedostoja HTTP-asiakkaan puolesta. macOS 26:ssa: 400 ja selkeä virheilmoitus. Katso [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization`-otsake | Tuettu | Vaaditaan, kun `--token` on asetettu. Katso [docs/server-security.md](../docs/server-security.md) |

Täysi API-määrittely: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Oletusvastausraja (`max_tokens`)

Kun `max_tokens` jätetään pois, **CLI ja OpenAI-yhteensopiva palvelin toimivat identtisesti**: arvo välitetään `nil`-arvona ja malli käyttää sen, mitä kontekstiikkunassa on jäljellä. Tämä on OpenAI-semantiikkaa drop-in-korvikkeena - ei mielivaltaista varavakiota.

Laitteella toimivan kontekstiikkunan sisään mahtuvat syöte *ja* tuloste yhteensä: **4096 tokenia macOS 26:ssa ja M1/M2-Maceissa, 8192 tokenia macOS 27:ssä M3- tai uudemmalla sirulla ja vähintään 12 GB**. apfel lukee todellisen koon ajon aikana `SystemLanguageModel.contextSize`n kautta - tarkista omasi komennolla `apfel --model-info`. Jos generointi osuu kattoon, vastaus päättyy siististi arvoon `finish_reason: "length"` ja osittainen sisältö palautetaan (palvelin: HTTP 200; CLI: exit 0 ja stderr-varoitus, tai exit 8 valitsimella `--require-complete` - katso [docs/cli-reference.md](../docs/cli-reference.md)). Anna `max_tokens` nimenomaisesti, kun haluat tiukemman viivebudjetin tai tunnetun ylärajan asiakasohjelmallesi.

### Esimerkkejä

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

### Arvon valinta

| Käyttötapaus                           | `max_tokens`  |
|----------------------------------------|---------------|
| Yhden sanan vastaus / luokittelu       | 16 - 32       |
| Yhden rivin ohje                       | 64 - 128      |
| Lyhyt kappale                          | 256 - 512     |
| Pitkä kappale / rakenteinen JSON       | 1024 - 2048   |
| Niin pitkä kuin kontekstiikkuna sallii | jätä pois     |

Pidä `input_tokens + max_tokens` reilusti kontekstiikkunan alapuolella (4096 tokenia macOS 26:ssa ja M1/M2-Maceissa, 8192 macOS 27:ssä M3- tai uudemmalla sirulla ja vähintään 12 GB (Applen AFM 3 Core Advanced -malli)). Jos itse prompti ylittää ikkunan, generointia ei voi aloittaa ja pyyntö epäonnistuu virheeseen `[context overflow]` (HTTP 400 / CLI exit 4). Validaattori hylkää ei-positiiviset arvot (`max_tokens <= 0`).

### CLI-vastaavuus

CLI ja palvelin noudattavat samaa sääntöä: pois jätetty = käytä jäljellä oleva ikkuna. Ei vakiota, joka voisi ajautua erilleen. Ohita valitsimella `--max-tokens N` tai `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Sallivat guardrailit palvelimelle

`apfel --serve --permissive` saa palvelimen käyttämään Applen `.permissiveContentTransformations`-guardraileja **jokaiseen pyyntöön**, jonka prosessi käsittelee. Sama lippu, samat semantiikat kuin CLI:n `--permissive` ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Pyyntökohtaista ohitusta ei ole - palvelimen ylläpitäjä päättää koko prosessin puolesta.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Rajoitukset

| Rajoite | Yksityiskohdat |
|------------|--------|
| Kontekstiikkuna | **4096 tokenia macOS 26:ssa ja M1/M2-Maceissa, 8192 tokenia macOS 27:ssä M3- tai uudemmalla sirulla ja vähintään 12 GB** (syöte + tuloste yhteensä). Ei kovakoodattu vakio - apfel lukee `SystemLanguageModel.contextSize`n ajon aikana; `apfel --model-info` tulostaa todellisen arvon |
| Alusta | macOS 26+, vain Apple Silicon |
| Malli | Yksi malli (`apple-foundationmodel`, ~3B parametria laitteella), ei konfiguroitavissa |
| Guardrailit | Applen turvajärjestelmä voi estää harmittomia prompteja. `--permissive` vähentää vääriä positiivisia ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Nopeus | Laitteella, ei pilviskaalassa - muutama sekunti vastausta kohden |
| Ei embeddingejä | Ei saatavilla laitteella |
| Vision | Kuvasyöte tavoittaa mallin vain macOS 27:ssä (palvelin: data-URL:t; CLI: `-f photo.jpg` ja putkitetut kuvat, OCR-tekstin lisäksi). macOS 26:ssa kuvat ovat vain tekstiä OCR:n/luokittelun kautta. 3B-mallin kohtauskuvaukset ovat karkeita - OCR on edelleen luotettava kanava painetun tekstin lukemiseen |
| Koulutusdata / tietojen katkaisupäivä | Apple ei ole julkaissut tarkkaa katkaisupäivää laitteella olevalle mallille. Kun mallia painostetaan nimeämään sellainen, se **keksii eri päivämäärän jokaisella kerralla** (esim. "October 2023", "April 2023"). Pidä kaikkia mallin omia väitteitä omasta koulutuksestaan epäluotettavina. |
| Ei nykyistä päivämäärää eikä reaaliaikaista tietoisuutta | Malli ei tiedä tämän päivän päivämäärää eikä sillä ole verkko- tai kellopääsyä. Jos kysyt, se joko kieltäytyy tai keksii päivämäärän. Syötä nykyinen päivämäärä järjestelmäpromptissa, kun laskenta riippuu siitä (katso kiertotapa alla). |

**Kiertotapa päivämääräriippuvaisiin prompteihin** - syötä nykyinen päivämäärä järjestelmäviestinä:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Huomio: vaikka päivämäärä syötettäisiin, 3B-malli voi silti hallusinoida (varsinkin kun sitä kysytään suoraan oman koulutuksensa katkaisupäivästä). Syöttö auttaa generatiivisissa prompteissa, jotka *käyttävät* päivämäärää; se ei ohita mallin refleksiä vastata itsestään.

Tausta: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Viitedokumentaatio

Oppaat apfelin käyttöön kielillä ja työkaluilla [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - katso [docs/guides/index.md](../docs/guides/index.md). Empiirisesti testattu; ajettava todiste osoitteessa [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - asennus, vianmääritys ja Apple Intelligencen käyttöönotto
- [docs/cli-reference.md](../docs/cli-reference.md) - kaikki liput, paluukoodit ja ympäristömuuttujat
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ja putkitettu PDF- / kuva- / tekstipoiminta (OCR + kuvan ymmärtäminen)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ja launchd-käyttö
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*`-tukimatriisi perusteellisesti
- [docs/server-security.md](../docs/server-security.md) - origin-tarkistukset, CORS, tokenit ja `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - chatin typistysstrategiat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - paikallinen ja etä-MCP-käyttö
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - työkalukutsujen yksityiskohtainen toiminta
- [docs/integrations.md](../docs/integrations.md) - kolmannen osapuolen työkaluintegraatiot (opencode jne.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - paikallinen katselmointi apfelilla + toisella edit/apply-mallilla VS Codessa
- [docs/demos.md](../docs/demos.md) - shell-demojen pidemmät läpikäynnit
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - yli 50 oikeaa promptia muokkaamattomine tulosteineen
- [docs/swift-library.md](../docs/swift-library.md) - Swift-paketti `ApfelCore` jatkokehittäjille
- [docs/coreai-impact.md](../docs/coreai-impact.md) - miksi apfel toimii FoundationModelsin päällä eikä Applen uuden Core AI:n (Core ML:n seuraaja)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel verrattuna Applen omaan `fm` CLI:hin (macOS 27), ominaisuus ominaisuudelta mitatuin luvuin

## Arkkitehtuuri

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Kolme targetia: `ApfelCore` (puhdas logiikka, yksikkötestattava, saatavilla myös Swift Package -tuotteena - linkitetty yllä kohdassa Viitedokumentaatio), `apfel` (CLI + palvelin) ja `apfel-tests` (puhdas Swift-ajuri, ei XCTestiä).

## Käännös ja testit

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

`.version` on ainoa totuuden lähde. Vain `make release` nostaa versioita. Paikalliset käännökset eivät muuta versiota.

## apfel-puu

Apfelin päälle rakennetut projektit. Jokainen julkaistaan omana repona + Homebrew-formulana.

| Projekti | Mitä se tekee | Asennus |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Juuri. Laitteella toimiva FoundationModels-CLI + OpenAI-yhteensopiva palvelin. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS-chat-asiakas: streaming-markdown, puhe sisään/ulos, kuva-analyysi Apple Visionilla. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Valikkopalkin tekoälytoiminnot leikepöydälle: tiivistä, käännä, muotoile uudelleen. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Välitön tekoälyn pikaikkuna: paina näppäintä, kysy, saat vastauksen, sulje. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Kaavamuistio - laitteella toimiva tekoäly rivinsisäisenä solufunktiona. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Tokenibudjetille optimoidut MCP:t pientä laitteella olevaa ikkunaa varten: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI-debug-tarkastaja: pyyntöjen aikajana, MCP-protokollakatselin, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-kääre, joka lisää pysyvän MCP-rekisterin + TOML-konfiguraation `apfel`in päälle. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Laitteella toimiva sisällön tunnisteiden CLI: syötä tekstiä putkeen, saat tunnisteet/aiheet/tunteet. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-paketti ekosysteemityökaluille: löydä, käynnistä ja striimaa paikallisesta `apfel --serve`-palvelimesta. | Swift Package |

## Yhteisön projektit

Rakensitko jotain apfelin päälle? Avaa issue, niin se voidaan lisätä tähän.

| Projekti | Mitä se tekee | Linkit |
|---------|-------------|-------|
| **apfelclaw**, tekijä [@julianYaman](https://github.com/julianYaman) | Paikallinen tekoälyagentti, joka lukee tiedostoja, kalenteria, sähköpostia ja Macin tilaa vain luku -työkalujen kautta | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, tekijä [@bhaskarvilles](https://github.com/bhaskarvilles) | Selainpohjainen chat-käyttöliittymä, joka puhuu `apfel --serve`lle OpenAI-yhteensopivan API:n yli | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, tekijä [@lucaspwo](https://github.com/lucaspwo) | Claude Code -kääre, joka vaihtaa apfelin paikalliseksi taustajärjestelmäksi pienen Anthropic-OpenAI-välityspalvelimen kautta | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, tekijä [@hasit](https://github.com/hasit) | Sovellushallinta apfelin ympärille rakennetuille paikallisille shell-sovelluksille | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, tekijä [@eggsy](https://github.com/eggsy) | Raycastin komentopalkin laajennus: kysy, käännä, selitä tiedostoja ja hakemistoja, keskusteluhistoria, omat järjestelmäpromptit. Laitteella apfel CLI:n kautta. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Osallistuminen

Issuet ja PR:t ovat tervetulleita kaikkiin `Arthur-Ficial/apfel*`-repoihin.

**#agentswelcome** - tekoälyagenttien PR:t ovat sallittuja. Lue repon `CLAUDE.md`, aja testit ja mainitse työkalu `Co-Authored-By`-trailerissa. Sama vaatimustaso kuin ihmisillä: siisti koodi, läpäisevät testit, rehelliset rajoitukset. Agenttiystävällisin aloituspaikka: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([osallistumissäännöt](https://apfel-mcp.franzai.com/#contribute)).

## Lisenssi

[MIT](../LICENSE)
