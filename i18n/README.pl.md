<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Przetłumaczono z [angielskiego README](../README.md). Obowiązującą wersją jest angielska.

# apfel

### Darmowe AI, które już jest na Twoim Macu.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Maki z Apple Silicon mają wbudowany LLM dostępny przez [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` udostępnia go jako narzędzie UNIX oraz lokalny serwer zgodny z OpenAI. W 100% na urządzeniu. Bez kluczy API, bez chmury.

| Tryb | Polecenie | Co dostajesz |
|------|-----------|--------------|
| Narzędzie UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Odpowiedzi przyjazne potokom, załączniki plików, wyjście JSON, kody wyjścia |
| Serwer zgodny z OpenAI | `apfel --serve` | Lokalny backend `http://localhost:11434/v1` jako zamiennik dla SDK OpenAI |

`apfel --chat` - interaktywny REPL.

[![Film demonstracyjny apfel w terminalu: prawdziwe polecenia, prawdziwe odpowiedzi na urządzeniu (82 sekundy)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/pl/a/apfel-ai-tutorial/#video)

Wywoływanie narzędzi działa w każdym kontekście.

![apfel CLI](../screenshots/cli.png)

## Wymagania i instalacja

macOS 26 Tahoe+, Apple Silicon (M1+), [włączone Apple Intelligence](https://support.apple.com/en-us/121115). Na macOS 27 Maki z układem M3 lub nowszym i 12 GB+ pamięci uruchamiają większy model Apple na urządzeniu z oknem 8192 tokenów; Maki M1/M2 oraz każdy Mac z macOS 26 mają 4096. `apfel --model-info` pokaże Twoją wartość.

```bash
brew install apfel
```

Aktualizacja:

```bash
brew upgrade apfel
```

Budowanie ze źródeł (Command Line Tools z SDK macOS 27 / Swift 6.3, bez Xcode; binarka działa na macOS 26 i 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap z poprawkami tego samego dnia, Mint, mise, rozwiązywanie problemów: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | **Polski** | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Szybki start

### Narzędzie UNIX

Prompty zawierające `!` ujmuj w apostrofy (rozwijanie historii w zsh/bash): `apfel 'Hello, Mac!'`.

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

### Serwer zgodny z OpenAI

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

Szczegóły usługi w tle: [docs/background-service.md](../docs/background-service.md).

### Czat do szybkich testów

`apfel --chat` to mały REPL do testowania promptów lub serwerów MCP. Aplikację czatu z interfejsem graficznym znajdziesz w [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C kończy sesję. Kontekst jest przycinany automatycznie ([docs/context-strategies.md](../docs/context-strategies.md)).

Ograniczenia, które warto znać, zanim zaczniesz pisać skrypty (okno kontekstu zależne od Maca, guardrails, brak embeddingów): [Ograniczenia](../README.md#limitations).

## Dema

Prawdziwe skrypty powłoki opakowujące `apfel`: `cmd` (angielski na polecenie powłoki), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Są wbudowane w binarkę - bez klonowania repozytorium. Zapisz je tam, skąd zainstalowano apfel (homebrew-core, tap lub źródła):

```bash
apfel demos ./apfel-demos
```

To zapisuje każde demo (jako plik wykonywalny) oraz `README.md` w `./apfel-demos`. Następnie uruchamiaj je stamtąd:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Uruchom ponownie `apfel demos` po `brew upgrade apfel`, aby odświeżyć. Źródła: [`demo/`](../demo/). Omówienia krok po kroku i funkcja powłoki `cmd` do wklejenia w `.zshrc`: [docs/demos.md](../docs/demos.md).

## Obsługa narzędzi MCP

Podłączaj serwery [Model Context Protocol](https://modelcontextprotocol.io/) przez `--mcp`. apfel wykrywa narzędzia, wywołuje je i zwraca wynik.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Użyj `-q`, aby ukryć informacje o narzędziach.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

W zestawie jest kalkulator w [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Zdalne serwery MCP** (Streamable HTTP, specyfikacja MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Bezpieczeństwo:** używaj `APFEL_MCP_TOKEN` zamiast `--mcp-token` (ps aux). apfel odmawia wysyłania tokenów bearer przez nieszyfrowane `http://`.

## apfel-run: opcjonalna warstwa konfiguracji

Sam apfel nie ma pliku konfiguracyjnego - flagi i zmienne środowiskowe, jak w każdym narzędziu UNIX. Jeśli chcesz konfigurację w TOML (wiele MCP, profile, konfiguracje zespołowe w git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) to nakładka na licencji MIT, która dodaje ją jako zamiennik przez `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Zgodność z API OpenAI

**Base URL:** `http://localhost:11434/v1`

| Funkcja | Status | Uwagi |
|---------|--------|-------|
| `POST /v1/chat/completions` | Obsługiwane | Streaming i bez streamingu |
| `POST /v1/responses` | Obsługiwane | OpenAI Responses API: wejście jako string/wiadomość, `instructions`, streaming (kanoniczna sekwencja zdarzeń), `text.format` (w tym `json_schema`), narzędzia funkcyjne (bez streamingu). Funkcje stanowe (`previous_response_id`, `store: true`, `background`, `reasoning`, narzędzia hostowane) zwracają uczciwe 501 |
| `POST /v1/responses/input_tokens` | Obsługiwane | Wstępne liczenie tokenów (`client.responses.input_tokens.count(...)`): dokładna liczba z tokenizera Apple, bez generowania; poniżej macOS 26.4 zwraca 501 zamiast szacunku. Zobacz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Obsługiwane | Zwraca `apple-foundationmodel` (ogólny, domyślny) i `apple-foundationmodel-content-tagging` (etykiety, nie proza). Zobacz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Obsługiwane | Dostępność modelu, okno kontekstu, języki, zgłaszane możliwości modelu (`capabilities`, `capabilities_reported`), wariant obsługującego modelu (`variant`, np. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Tylko debug | Wymaga `--debug` |
| Wywoływanie narzędzi | Obsługiwane | Wywołanie jest zapisywane przez generowanie sterowane (`--tool-calling guided`, domyślnie) lub jako JSON parsowany przez serwer (`--tool-calling text`). Zobacz [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Obsługiwane | Wstrzyknięcie do promptu systemowego; ogrodzenia markdown są usuwane z wyniku |
| `response_format: json_schema` | Obsługiwane | Gwarantowany wynik zgodny ze schematem przez FoundationModels `DynamicGenerationSchema`; działa ze `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Obsługiwane | Mapowane na `GenerationOptions`. `top_p` to nucleus sampling; `temperature` poniżej 0.001 (w tym 0) oznacza zachłanne (deterministyczne) próbkowanie. Pominięcie `max_tokens` używa pozostałego okna kontekstu (semantyka zamiennika OpenAI) - zobacz [Domyślny limit odpowiedzi](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Obsługiwane | SSE; końcowy fragment z `usage` tylko przy `stream_options: {"include_usage": true}` (zgodnie ze specyfikacją OpenAI) |
| `usage` | Obsługiwane | Rzeczywiste liczby z tokenizera na macOS 26.4+ (poniżej: szacunek znaki/4). macOS 27: własne rozliczanie środowiska uruchomieniowego wraz z ramowaniem szablonu czatu Apple (około 46 dodatkowych `prompt_tokens` przy jednowierszowym prompcie); macOS 26: apfel liczy tekst wiadomości. Szczegóły w [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Obsługiwane | `stop`, `tool_calls`, `length` |
| Strategie kontekstu | Obsługiwane | Pola rozszerzeń `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Obsługiwane | Włącz przez `--cors` |
| `POST /v1/completions` | 501 | Starsze uzupełnianie tekstu nie jest obsługiwane |
| `POST /v1/embeddings` | 501 | Embeddingi nie są dostępne na urządzeniu |
| `stop` | Obsługiwane | String lub do 4 stringów; tylko zwykły tekst (400 gdy w grze są narzędzia lub `json_object`/`json_schema`). Stosowane po stronie wyjścia, identycznie w streamingu i bez. Zobacz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Jawnie odrzucane. `n=1` i `logprobs=false` są akceptowane jako brak operacji |
| Multimodalność (obrazy) | Obsługiwane na macOS 27 | Części `image_url` jako dane base64 data URL trafiają natywnie do modelu na urządzeniu (limit 20 MB base64, dłuższy bok skalowany w dół do 4096 px). Zdalne adresy `http(s)` i ścieżki plików zawsze dają 400 - apfel nigdy nie pobiera obrazów ani nie czyta plików na prośbę klienta HTTP. Na macOS 26: 400 z czytelnym błędem. Zobacz [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Nagłówek `Authorization` | Obsługiwane | Wymagany, gdy ustawiono `--token`. Zobacz [docs/server-security.md](../docs/server-security.md) |

Pełna specyfikacja API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Domyślny limit odpowiedzi (`max_tokens`)

Gdy `max_tokens` jest pominięte, **CLI i serwer zgodny z OpenAI zachowują się identycznie**: wartość przechodzi dalej jako `nil`, a model wykorzystuje całe pozostałe miejsce w oknie kontekstu. To semantyka zamiennika OpenAI - bez dowolnej stałej zastępczej.

Okno kontekstu na urządzeniu mieści wejście *i* wyjście łącznie: **4096 tokenów na macOS 26 i na Makach M1/M2, 8192 tokeny na macOS 27 z układem M3 lub nowszym i 12 GB+**. apfel odczytuje rzeczywisty rozmiar w czasie działania przez `SystemLanguageModel.contextSize` - sprawdź swój przez `apfel --model-info`. Jeśli generowanie dojdzie do limitu, odpowiedź kończy się czysto z `finish_reason: "length"`, a częściowa treść jest zwracana (serwer: HTTP 200; CLI: exit 0 z ostrzeżeniem na stderr albo exit 8 z `--require-complete` - zobacz [docs/cli-reference.md](../docs/cli-reference.md)). Podaj `max_tokens` jawnie, gdy chcesz mieć ciaśniejszy budżet opóźnienia lub znany limit dla klienta.

### Przykłady

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

### Wybór wartości

| Zastosowanie                           | `max_tokens`  |
|----------------------------------------|---------------|
| Odpowiedź jednowyrazowa / klasyfikacja | 16 - 32       |
| Jednowierszowa instrukcja              | 64 - 128      |
| Krótki akapit                          | 256 - 512     |
| Długi akapit / ustrukturyzowany JSON   | 1024 - 2048   |
| Tyle, ile pozwala okno kontekstu       | pomiń         |

Utrzymuj `input_tokens + max_tokens` z wyraźnym zapasem poniżej okna kontekstu (4096 tokenów na macOS 26 i na Makach M1/M2, 8192 na macOS 27 z układem M3 lub nowszym i 12 GB+ (model AFM 3 Core Advanced od Apple)). Jeśli sam prompt przekracza okno, generowanie nie może się rozpocząć, a żądanie kończy się błędem `[context overflow]` (HTTP 400 / CLI exit 4). Walidator odrzuca wartości niedodatnie (`max_tokens <= 0`).

### Zgodność z CLI

CLI i serwer stosują jedną zasadę: pominięte = użyj pozostałego okna. Żadna stała nie ulega rozjazdowi. Nadpisz przez `--max-tokens N` lub `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permisywne guardrails dla serwera

`apfel --serve --permissive` sprawia, że serwer używa guardrails Apple `.permissiveContentTransformations` dla **każdego żądania** obsługiwanego przez proces. Ta sama flaga, ta sama semantyka co `--permissive` w CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Nie ma nadpisania per żądanie - decyduje operator serwera dla całego procesu.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ograniczenia

| Ograniczenie | Szczegóły |
|--------------|-----------|
| Okno kontekstu | **4096 tokenów na macOS 26 i na Makach M1/M2, 8192 tokeny na macOS 27 z układem M3 lub nowszym i 12 GB+** (wejście + wyjście łącznie). Nie jest to stała wpisana na sztywno - apfel odczytuje `SystemLanguageModel.contextSize` w czasie działania; `apfel --model-info` wypisuje aktualną wartość |
| Platforma | macOS 26+, tylko Apple Silicon |
| Model | Jeden model na urządzeniu (ok. 3 mld parametrów), udostępniany jako `apple-foundationmodel` (ogólny) i `apple-foundationmodel-content-tagging` (adapter Apple do tagowania treści; bez narzędzi) |
| Guardrails | System bezpieczeństwa Apple może blokować niewinne prompty. `--permissive` zmniejsza liczbę fałszywych alarmów ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Szybkość | Na urządzeniu, nie w skali chmury - kilka sekund na odpowiedź |
| Brak embeddingów | Niedostępne na urządzeniu |
| Wizja | Obraz trafia do modelu tylko na macOS 27 (serwer: data URL; CLI: `-f photo.jpg` i obrazy przekazane potokiem, obok tekstu z OCR). Na macOS 26 obrazy są tylko tekstem przez OCR/klasyfikację. Opisy scen modelu 3B są zgrubne - OCR pozostaje niezawodnym kanałem do czytania druku |
| Dane treningowe / data graniczna wiedzy | Apple nie podało dokładnej daty granicznej modelu na urządzeniu. Zapytany o nią model **zmyśla za każdym razem inną datę** (np. "October 2023", "April 2023"). Traktuj wszystkie wypowiedzi modelu o własnym treningu jako niewiarygodne. |
| Brak aktualnej daty i świadomości czasu rzeczywistego | Model nie zna dzisiejszej daty i nie ma dostępu do sieci ani zegara. Zapytany, odmówi albo wymyśli datę. Gdy obliczenia zależą od daty, wstrzyknij bieżącą datę w prompcie systemowym (zobacz obejście poniżej). |

**Obejście dla promptów zależnych od daty** - wstrzyknij bieżącą datę jako wiadomość systemową:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Uwaga: nawet z wstrzykniętą datą model 3B nadal może halucynować (zwłaszcza zapytany wprost o własną datę graniczną treningu). Wstrzyknięcie pomaga w promptach generatywnych, które *używają* daty; nie przełamuje odruchu model self-report.

Tło: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Dokumentacja

Przewodniki po używaniu apfel z [Pythona](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - zobacz [docs/guides/index.md](../docs/guides/index.md). Przetestowane empirycznie; działający dowód w [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalacja, rozwiązywanie problemów i konfiguracja Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - każda flaga, kod wyjścia i zmienna środowiskowa
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` i ekstrakcja PDF / obrazów / tekstu przekazanych potokiem (OCR + rozumienie obrazu)
- [docs/background-service.md](../docs/background-service.md) - użycie `brew services` i launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - szczegółowa macierz obsługi `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - kontrole origin, CORS, tokeny i `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategie przycinania czatu
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokalne i zdalne użycie MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - szczegółowe zachowanie wywoływania narzędzi
- [docs/integrations.md](../docs/integrations.md) - integracje z narzędziami firm trzecich (opencode itd.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokalny przegląd z apfel + drugim modelem edycji/stosowania w VS Code
- [docs/demos.md](../docs/demos.md) - dłuższe omówienia dem powłoki
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - ponad 50 prawdziwych promptów z nieedytowanym wynikiem
- [docs/swift-library.md](../docs/swift-library.md) - pakiet Swift `ApfelCore` dla deweloperów
- [docs/coreai-impact.md](../docs/coreai-impact.md) - dlaczego apfel działa na FoundationModels, a nie na nowym Core AI od Apple (następcy Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel w porównaniu z własnym CLI `fm` od Apple (macOS 27), funkcja po funkcji, z zmierzonymi liczbami

## Architektura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 ze ścisłą współbieżnością. Trzy targety: `ApfelCore` (czysta logika, testowalna jednostkowo, dostępna także jako produkt Swift Package - link w Dokumentacji powyżej), `apfel` (CLI + serwer) i `apfel-tests` (czysty runner Swift, bez XCTest).

## Budowanie i testy

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

`.version` jest jedynym źródłem prawdy. Tylko `make release` podnosi wersje. Lokalne buildy nie zmieniają wersji.

## Drzewo apfel

Projekty zbudowane na apfel. Każdy ma własne repozytorium i formułę Homebrew.

| Projekt | Co robi | Instalacja |
|---------|---------|------------|
| [**apfel**](https://apfel.franzai.com) | Korzeń. CLI FoundationModels na urządzeniu + serwer zgodny z OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Klient czatu dla macOS: streaming markdown, mowa wejście/wyjście, analiza obrazów przez Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Akcje AI w pasku menu na schowku: streszczanie, tłumaczenie, przepisywanie. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Natychmiastowa nakładka AI: naciśnij klawisz, zapytaj, odpowiedź, zamknij. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Notatnik z formułami - AI na urządzeniu jako funkcja komórki w tekście. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP zoptymalizowane pod budżet tokenów małego okna na urządzeniu: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspektor debugowania w SwiftUI: oś czasu żądań, podgląd protokołu MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Nakładka UNIX dodająca trwały rejestr MCP + konfigurację TOML nad `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI do tagowania treści na urządzeniu: wrzuć tekst potokiem, dostaniesz tagi/tematy/emocje. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Pakiet Swift dla narzędzi ekosystemu: wykrywaj, uruchamiaj i strumieniuj z lokalnego `apfel --serve`. | Swift Package |

## Projekty społeczności

Zbudowałeś coś na bazie apfel? Otwórz issue, a projekt może zostać tu dodany.

| Projekt | Co robi | Linki |
|---------|---------|-------|
| **apfelclaw** autorstwa [@julianYaman](https://github.com/julianYaman) | Lokalny agent AI czytający pliki, kalendarz, pocztę i stan Maca przez narzędzia tylko do odczytu | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** autorstwa [@bhaskarvilles](https://github.com/bhaskarvilles) | Przeglądarkowy interfejs czatu rozmawiający z `apfel --serve` przez API zgodne z OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** autorstwa [@lucaspwo](https://github.com/lucaspwo) | Nakładka na Claude Code, która podmienia backend na lokalny apfel przez mały proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** autorstwa [@hasit](https://github.com/hasit) | Menedżer aplikacji dla lokalnych aplikacji powłoki zbudowanych wokół apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** autorstwa [@eggsy](https://github.com/eggsy) | Rozszerzenie paska poleceń Raycast: pytaj, tłumacz, wyjaśniaj pliki i katalogi, historia rozmów, własne prompty systemowe. Na urządzeniu przez apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Współtworzenie

Issues i PR-y mile widziane w każdym repozytorium `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR-y od agentów AI są w porządku. Przeczytaj `CLAUDE.md` repozytorium, uruchom testy, wskaż narzędzie w trailerze `Co-Authored-By`. Ta sama poprzeczka co dla ludzi: czysty kod, przechodzące testy, uczciwe ograniczenia. Najbardziej przyjazny agentom punkt startowy: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([zasady współtworzenia](https://apfel-mcp.franzai.com/#contribute)).

## Licencja

[MIT](../LICENSE)
