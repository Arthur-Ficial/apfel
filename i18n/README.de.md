<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Übersetzt aus dem [englischen README](../README.md). Die englische Version ist maßgeblich.

# apfel

### Die kostenlose KI, die schon auf deinem Mac steckt.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Macs mit Apple Silicon bringen ein integriertes LLM über [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) mit. `apfel` stellt es als UNIX-Tool und als lokalen OpenAI-kompatiblen Server bereit. 100% on-device. Keine API-Schlüssel, keine Cloud.

| Modus | Befehl | Was du bekommst |
|------|---------|--------------|
| UNIX-Tool | `apfel "prompt"` / `echo "text" \| apfel` | Pipe-freundliche Antworten, Dateianhänge, JSON-Ausgabe, Exit-Codes |
| OpenAI-kompatibler Server | `apfel --serve` | Lokales Drop-in-Backend unter `http://localhost:11434/v1` für OpenAI-SDKs |

`apfel --chat` - interaktive REPL.

Tool Calling funktioniert in allen Kontexten.

![apfel CLI](../screenshots/cli.png)

## Voraussetzungen & Installation

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence aktiviert](https://support.apple.com/en-us/121115). Unter macOS 27 nutzen Macs mit M3 oder neuerem Chip und 12 GB+ Apples größeres On-Device-Modell mit einem Fenster von 8192 Tokens; M1/M2-Macs und jeder Mac unter macOS 26 haben 4096. `apfel --model-info` zeigt deinen Wert.

```bash
brew install apfel
```

Aktualisieren:

```bash
brew upgrade apfel
```

Aus dem Quellcode bauen (Command Line Tools mit dem macOS 27 SDK / Swift 6.3, kein Xcode; die Binary läuft unter macOS 26 und 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, Same-Day-Tap, Mint, mise, Fehlerbehebung: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | **Deutsch** | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Schnellstart

### UNIX-Tool

Prompts mit `!` in einfache Anführungszeichen setzen (History-Expansion in zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-kompatibler Server

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

Details zum Hintergrunddienst: [docs/background-service.md](../docs/background-service.md).

### Chat zum schnellen Testen

`apfel --chat` ist eine kleine REPL zum Testen von Prompts oder MCP-Servern. Für eine Chat-App mit GUI siehe [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Strg-C beendet. Der Kontext wird automatisch gekürzt ([docs/context-strategies.md](../docs/context-strategies.md)).

Einschränkungen, die du kennen solltest, bevor du dagegen skriptest (Kontextfenster je Mac, Guardrails, keine Embeddings): [Einschränkungen](../README.md#limitations).

## Demos

Echte Shell-Skripte, die `apfel` umhüllen: `cmd` (Englisch zu Shell-Befehl), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Sie sind in der Binary enthalten - kein Klonen des Repos nötig. Schreibe sie dorthin, woher du apfel installiert hast (homebrew-core, der Tap oder der Quellcode):

```bash
apfel demos ./apfel-demos
```

Das schreibt jede Demo (ausführbar) plus eine `README.md` nach `./apfel-demos`. Danach führst du sie von dort aus:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Führe `apfel demos` nach `brew upgrade apfel` erneut aus, um sie zu aktualisieren. Quellen: [`demo/`](../demo/). Walkthroughs und eine `cmd`-Shell-Funktion zum Kopieren für deine `.zshrc`: [docs/demos.md](../docs/demos.md).

## MCP-Tool-Unterstützung

Binde [Model Context Protocol](https://modelcontextprotocol.io/)-Server mit `--mcp` ein. apfel entdeckt, ruft auf und liefert zurück.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Mit `-q` werden die Tool-Infos unterdrückt.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Enthält einen Taschenrechner unter [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Remote-MCP-Server** (Streamable HTTP, MCP-Spezifikation 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Sicherheit:** Bevorzuge `APFEL_MCP_TOKEN` gegenüber `--mcp-token` (ps aux). apfel lehnt Bearer-Tokens über unverschlüsseltes `http://` ab.

## apfel-run: optionale Konfigurationsschicht

apfel selbst hat keine Konfigurationsdatei - Flags + Umgebungsvariablen, wie jedes UNIX-Tool. Wenn du eine TOML-Konfiguration möchtest (viele MCPs, Profile, Team-Konfigurationen in Git), ist [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) ein MIT-lizenzierter Wrapper, der sie per `execve`-Drop-in ergänzt.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI-API-Kompatibilität

**Base-URL:** `http://localhost:11434/v1`

| Funktion | Status | Hinweise |
|---------|--------|-------|
| `POST /v1/chat/completions` | Unterstützt | Streaming + nicht-streaming |
| `POST /v1/responses` | Unterstützt | OpenAI Responses API: String-/Message-Eingabe, `instructions`, Streaming (kanonische Event-Sequenz), `text.format` (inkl. `json_schema`), Function Tools (nicht-streaming). Zustandsbehaftete Funktionen (`previous_response_id`, `store: true`, `background`, `reasoning`, gehostete Tools) liefern ehrliche 501er |
| `POST /v1/responses/input_tokens` | Unterstützt | Token-Preflight (`client.responses.input_tokens.count(...)`): exakte Zählung mit Apples Tokenizer, ohne Generierung; 501 unter macOS 26.4 statt einer Schätzung. Siehe [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Unterstützt | Liefert `apple-foundationmodel` |
| `GET /health` | Unterstützt | Modellverfügbarkeit, Kontextfenster, Sprachen, gemeldete Modellfähigkeiten (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Nur Debug | Erfordert `--debug` |
| Tool Calling | Unterstützt | Natives `ToolDefinition` + JSON-Erkennung. Siehe [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Unterstützt | Injektion über den System-Prompt; Markdown-Fences werden aus der Ausgabe entfernt |
| `response_format: json_schema` | Unterstützt | Garantiert schemakonforme Ausgabe über FoundationModels `DynamicGenerationSchema`; funktioniert mit `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Unterstützt | Auf `GenerationOptions` abgebildet. `top_p` ist Nucleus Sampling; `temperature` unter 0.001 (0 eingeschlossen) wird auf Greedy (deterministisch) abgebildet. Wird `max_tokens` weggelassen, gilt das verbleibende Kontextfenster (Drop-in-OpenAI-Semantik) - siehe [Standardlimit für Antworten](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Unterstützt | SSE; abschließender Usage-Chunk nur bei `stream_options: {"include_usage": true}` (gemäß OpenAI-Spezifikation) |
| `usage` | Unterstützt | Echte Tokenizer-Zählung ab macOS 26.4 (darunter Schätzung Zeichen/4). macOS 27: die eigene Zählung der Runtime inkl. Apples Chat-Template-Rahmen (etwa 46 zusätzliche `prompt_tokens` bei einem einzeiligen Prompt); macOS 26: apfel zählt den Nachrichtentext. Details in [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Unterstützt | `stop`, `tool_calls`, `length` |
| Kontextstrategien | Unterstützt | Erweiterungsfelder `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Unterstützt | Mit `--cors` aktivieren |
| `POST /v1/completions` | 501 | Legacy-Textvervollständigungen nicht unterstützt |
| `POST /v1/embeddings` | 501 | Embeddings sind on-device nicht verfügbar |
| `stop` | Unterstützt | String oder bis zu 4 Strings; nur Klartext (400 bei Tools im Scope oder `json_object`/`json_schema`). Wird ausgabeseitig angewendet, identisch für Streaming und Nicht-Streaming. Siehe [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Werden ausdrücklich abgelehnt. `n=1` und `logprobs=false` werden als No-ops akzeptiert |
| Multimodal (Bilder) | Unterstützt unter macOS 27 | `image_url`-Teile als Base64-Data-URLs gehen nativ an das On-Device-Modell (Limit 20 MB Base64, längste Seite auf 4096 px verkleinert). Entfernte `http(s)`-URLs und Dateipfade sind immer 400 - apfel lädt nie Bilder und liest nie Dateien für einen HTTP-Client. Unter macOS 26: 400 mit klarer Fehlermeldung. Siehe [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization`-Header | Unterstützt | Erforderlich, wenn `--token` gesetzt ist. Siehe [docs/server-security.md](../docs/server-security.md) |

Vollständige API-Spezifikation: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Standardlimit für Antworten (`max_tokens`)

Wird `max_tokens` weggelassen, **verhalten sich CLI und OpenAI-kompatibler Server identisch**: Der Wert wird als `nil` durchgereicht, und das Modell nutzt den Platz, der im Kontextfenster noch übrig ist. Das ist Drop-in-OpenAI-Semantik - keine willkürliche Ersatzkonstante.

Das On-Device-Kontextfenster fasst Eingabe *und* Ausgabe zusammen: **4096 Tokens unter macOS 26 und auf M1/M2-Macs, 8192 Tokens unter macOS 27 mit M3 oder neuerem Chip und 12 GB+**. apfel liest die tatsächliche Größe zur Laufzeit über `SystemLanguageModel.contextSize` - prüfe deine mit `apfel --model-info`. Stößt die Generierung an die Grenze, endet die Antwort sauber mit `finish_reason: "length"`, und der Teilinhalt wird zurückgegeben (Server: HTTP 200; CLI: Exit 0 mit einer Warnung auf stderr, oder Exit 8 mit `--require-complete` - siehe [docs/cli-reference.md](../docs/cli-reference.md)). Gib `max_tokens` explizit an, wenn du ein engeres Latenzbudget oder ein bekanntes Limit für deinen Client willst.

### Beispiele

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

### Einen Wert wählen

| Anwendungsfall                         | `max_tokens`  |
|----------------------------------------|---------------|
| Einwort- / Klassifikationsantwort      | 16 - 32       |
| Einzeilige Anweisung                   | 64 - 128      |
| Kurzer Absatz                          | 256 - 512     |
| Langer Absatz / strukturiertes JSON    | 1024 - 2048   |
| So lang, wie das Kontextfenster erlaubt | weglassen    |

Halte `input_tokens + max_tokens` deutlich unter dem Kontextfenster (4096 Tokens unter macOS 26 und auf M1/M2-Macs, 8192 unter macOS 27 mit M3 oder neuerem Chip und 12 GB+ (Apples Modell AFM 3 Core Advanced)). Überschreitet der Prompt selbst das Fenster, kann die Generierung nicht starten, und die Anfrage schlägt mit `[context overflow]` fehl (HTTP 400 / CLI-Exit 4). Der Validator lehnt nicht-positive Werte ab (`max_tokens <= 0`).

### CLI-Parität

CLI und Server teilen sich eine Regel: weggelassen = verbleibendes Fenster nutzen. Keine Konstante, die auseinanderdriften kann. Überschreibe mit `--max-tokens N` oder `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive Guardrails für den Server

`apfel --serve --permissive` lässt den Server Apples `.permissiveContentTransformations`-Guardrails für **jede Anfrage** verwenden, die der Prozess bearbeitet. Gleiches Flag, gleiche Semantik wie `--permissive` der CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Es gibt keine Überschreibung pro Anfrage - der Server-Betreiber entscheidet für den ganzen Prozess.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Einschränkungen

| Einschränkung | Detail |
|------------|--------|
| Kontextfenster | **4096 Tokens unter macOS 26 und auf M1/M2-Macs, 8192 Tokens unter macOS 27 mit M3 oder neuerem Chip und 12 GB+** (Eingabe + Ausgabe zusammen). Keine fest einprogrammierte Konstante - apfel liest `SystemLanguageModel.contextSize` zur Laufzeit; `apfel --model-info` gibt den aktuellen Wert aus |
| Plattform | macOS 26+, nur Apple Silicon |
| Modell | Ein Modell (`apple-foundationmodel`, ~3B Parameter on-device), nicht konfigurierbar |
| Guardrails | Apples Sicherheitssystem kann harmlose Prompts blockieren. `--permissive` verringert Fehlalarme ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Geschwindigkeit | On-device, nicht Cloud-Skala - einige Sekunden pro Antwort |
| Keine Embeddings | On-device nicht verfügbar |
| Vision | Bildeingabe erreicht das Modell nur unter macOS 27 (Server: Data-URLs; CLI: `-f photo.jpg` und per Pipe übergebene Bilder, zusätzlich zum OCR-Text). Unter macOS 26 sind Bilder nur Text über OCR/Klassifikation. Die Szenenbeschreibungen des 3B-Modells sind grob - OCR bleibt der verlässliche Kanal zum Lesen von Schrift |
| Trainingsdaten / Wissensstand | Apple hat keinen genauen Stichtag für das On-Device-Modell veröffentlicht. Wird es gedrängt, einen zu nennen, **erfindet das Modell bei jedem Versuch ein anderes Datum** (z. B. "Oktober 2023", "April 2023"). Betrachte alle Selbstauskünfte des Modells über sein Training als unzuverlässig. |
| Kein aktuelles Datum und kein Echtzeitbewusstsein | Das Modell kennt das heutige Datum nicht und hat weder Netzwerk- noch Uhrzugriff. Gefragt, verweigert es entweder die Antwort oder erfindet ein Datum. Gib das aktuelle Datum per System-Prompt vor, wenn eine Berechnung davon abhängt (siehe Workaround unten). |

**Workaround für datumsabhängige Prompts** - das aktuelle Datum als System-Nachricht einspeisen:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Hinweis: Auch mit eingespeistem Datum kann das 3B-Modell noch halluzinieren (besonders, wenn man es direkt nach seinem eigenen Trainings-Stichtag fragt). Die Injektion hilft bei generativen Prompts, die das Datum *verwenden*; den Reflex der Selbstauskunft überschreibt sie nicht.

Hintergrund: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referenzdokumentation

Anleitungen, um apfel aus [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) zu nutzen - siehe [docs/guides/index.md](../docs/guides/index.md). Empirisch getestet; lauffähiger Beleg unter [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - Installation, Fehlerbehebung und Einrichtung von Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - jedes Flag, jeder Exit-Code und jede Umgebungsvariable
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` und per Pipe übergebene PDF-/Bild-/Text-Extraktion (OCR + Bildverständnis)
- [docs/background-service.md](../docs/background-service.md) - Nutzung von `brew services` und launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - Support-Matrix für `/v1/*` im Detail
- [docs/server-security.md](../docs/server-security.md) - Origin-Prüfungen, CORS, Tokens und `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - Strategien zum Kürzen im Chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - lokale und entfernte MCP-Nutzung
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - detailliertes Tool-Calling-Verhalten
- [docs/integrations.md](../docs/integrations.md) - Integrationen mit Drittanbieter-Tools (opencode usw.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - lokales Review mit apfel + einem zweiten Edit-/Apply-Modell in VS Code
- [docs/demos.md](../docs/demos.md) - ausführlichere Walkthroughs der Shell-Demos
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ echte Prompts mit unbearbeiteter Ausgabe
- [docs/swift-library.md](../docs/swift-library.md) - Swift-Package `ApfelCore` für nachgelagerte Entwickler
- [docs/coreai-impact.md](../docs/coreai-impact.md) - warum apfel auf FoundationModels läuft und nicht auf Apples neuem Core AI (dem Nachfolger von Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel im Vergleich zu Apples eigener `fm`-CLI (macOS 27), Funktion für Funktion mit gemessenen Zahlen

## Architektur

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 Strict Concurrency. Drei Targets: `ApfelCore` (reine Logik, unit-testbar, auch als Swift-Package-Produkt verfügbar - oben unter Referenzdokumentation verlinkt), `apfel` (CLI + Server) und `apfel-tests` (reiner Swift-Runner, kein XCTest).

## Build & Test

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

`.version` ist die einzige Quelle der Wahrheit. Nur `make release` erhöht Versionen. Lokale Builds ändern die Version nicht.

## Der apfel-Baum

Projekte, die auf apfel aufbauen. Jedes erscheint als eigenes Repo + Homebrew-Formel.

| Projekt | Was es macht | Installation |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Die Wurzel. On-Device-FoundationModels-CLI + OpenAI-kompatibler Server. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS-Chat-Client: Streaming-Markdown, Sprach-Ein-/Ausgabe, Bildanalyse mit Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | KI-Aktionen für die Zwischenablage in der Menüleiste: zusammenfassen, übersetzen, umschreiben. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Sofortiges KI-Overlay: Taste drücken, fragen, Antwort, schließen. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formel-Notizblock - On-Device-KI als Inline-Zellfunktion. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Auf Token-Budget optimierte MCPs für das kleine On-Device-Fenster: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI-Debug-Inspektor: Request-Zeitleiste, MCP-Protokoll-Viewer, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-Wrapper, der `apfel` um eine persistente MCP-Registry + TOML-Konfiguration erweitert. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | On-Device-CLI für Content-Tagging: Text per Pipe rein, Tags/Themen/Emotionen raus. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-Package für Ökosystem-Tools: einen lokalen `apfel --serve` entdecken, starten und davon streamen. | Swift Package |

## Community-Projekte

Etwas auf Basis von apfel gebaut? Eröffne ein Issue, dann kann es hier ergänzt werden.

| Projekt | Was es macht | Links |
|---------|-------------|-------|
| **apfelclaw** von [@julianYaman](https://github.com/julianYaman) | Lokaler KI-Agent, der Dateien, Kalender, Mail und Mac-Status über schreibgeschützte Tools liest | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** von [@bhaskarvilles](https://github.com/bhaskarvilles) | Browserbasierte Chat-Oberfläche, die über die OpenAI-kompatible API mit `apfel --serve` spricht | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** von [@lucaspwo](https://github.com/lucaspwo) | Claude-Code-Wrapper, der apfel über einen kleinen Anthropic-OpenAI-Proxy als lokales Backend einsetzt | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** von [@hasit](https://github.com/hasit) | App-Manager für lokale Shell-Apps rund um apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** von [@eggsy](https://github.com/eggsy) | Erweiterung für die Raycast-Befehlsleiste: fragen, übersetzen, Dateien und Verzeichnisse erklären, Konversationsverlauf, eigene System-Prompts. On-device über die apfel-CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Mitwirken

Issues und PRs sind in jedem `Arthur-Ficial/apfel*`-Repo willkommen.

**#agentswelcome** - PRs von KI-Agenten sind in Ordnung. Lies die `CLAUDE.md` des Repos, führe die Tests aus, nenne das Tool in einem `Co-Authored-By`-Trailer. Gleicher Maßstab wie bei Menschen: sauberer Code, bestehende Tests, ehrliche Grenzen. Agentenfreundlichster Einstieg: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([Regeln für Beiträge](https://apfel-mcp.franzai.com/#contribute)).

## Lizenz

[MIT](../LICENSE)
