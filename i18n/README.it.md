<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Tradotto dal [README inglese](../README.md). La versione inglese è quella di riferimento.

# apfel

### L'IA gratuita già presente sul tuo Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

I Mac con Apple Silicon includono un LLM integrato tramite [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` lo espone come strumento UNIX e come server locale compatibile con OpenAI. 100% sul dispositivo. Nessuna chiave API, nessun cloud.

| Modalità | Comando | Cosa ottieni |
|------|---------|--------------|
| Strumento UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Risposte adatte alle pipe, allegati di file, output JSON, codici di uscita |
| Server compatibile con OpenAI | `apfel --serve` | Backend locale `http://localhost:11434/v1` pronto all'uso per gli SDK OpenAI |

`apfel --chat` - REPL interattivo.

[![Video demo di apfel nel terminale: comandi reali, risposte reali sul dispositivo (82 secondi)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/it/a/apfel-ai-tutorial/#video)

La chiamata di strumenti funziona in tutti i contesti.

![apfel CLI](../screenshots/cli.png)

## Requisiti e installazione

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence attivato](https://support.apple.com/en-us/121115). Su macOS 27, i Mac con chip M3 o più recente e 12 GB+ eseguono il modello sul dispositivo più grande di Apple con una finestra di 8192 token; i Mac M1/M2 e ogni Mac con macOS 26 hanno 4096. `apfel --model-info` mostra la tua.

```bash
brew install apfel
```

Aggiornare:

```bash
brew upgrade apfel
```

Compilare dai sorgenti (Command Line Tools con l'SDK di macOS 27 / Swift 6.3, senza Xcode; il binario funziona su macOS 26 e 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap del giorno stesso, Mint, mise, risoluzione dei problemi: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | **Italiano** | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Guida rapida

### Strumento UNIX

Metti tra apici singoli i prompt con `!` (espansione della cronologia di zsh/bash): `apfel 'Hello, Mac!'`.

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

### Server compatibile con OpenAI

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

Dettagli sul servizio in background: [docs/background-service.md](../docs/background-service.md).

### Chat per prove rapide

`apfel --chat` è un piccolo REPL per provare prompt o server MCP. Per un'app di chat con interfaccia grafica, vedi [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C esce. Il contesto viene ridotto automaticamente ([docs/context-strategies.md](../docs/context-strategies.md)).

Vincoli da conoscere prima di scrivere script (finestra di contesto per Mac, guardrail, niente embeddings): [Limitazioni](../README.md#limitations).

## Demo

Veri script di shell che avvolgono `apfel`: `cmd` (inglese in comando di shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Sono inclusi nel binario - nessun clone del repository. Scrivili dove vuoi, da qualunque fonte tu abbia installato apfel (homebrew-core, il tap o i sorgenti):

```bash
apfel demos ./apfel-demos
```

Questo scrive ogni demo (eseguibile) più un `README.md` in `./apfel-demos`. Poi eseguile da lì:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Riesegui `apfel demos` dopo `brew upgrade apfel` per aggiornare. Sorgenti: [`demo/`](../demo/). Guide passo passo e una funzione di shell `cmd` da copiare e incollare nel tuo `.zshrc`: [docs/demos.md](../docs/demos.md).

## Supporto per gli strumenti MCP

Collega server [Model Context Protocol](https://modelcontextprotocol.io/) con `--mcp`. apfel li scopre, li invoca e restituisce il risultato.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Usa `-q` per nascondere le informazioni sugli strumenti.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Include una calcolatrice in [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Server MCP remoti** (Streamable HTTP, specifica MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Sicurezza:** preferisci `APFEL_MCP_TOKEN` a `--mcp-token` (ps aux). apfel rifiuta i bearer token su `http://` in chiaro.

## apfel-run: livello di configurazione opzionale

apfel in sé non ha un file di configurazione - flag + variabili d'ambiente, come qualsiasi strumento UNIX. Se vuoi una configurazione TOML (molti MCP, profili, configurazioni di team in git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) è un wrapper MIT che ne aggiunge una tramite un sostituto diretto con `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilità con l'API OpenAI

**URL di base:** `http://localhost:11434/v1`

| Funzionalità | Stato | Note |
|---------|--------|-------|
| `POST /v1/chat/completions` | Supportato | Streaming + non-streaming |
| `POST /v1/responses` | Supportato | API OpenAI Responses: input stringa/messaggio, `instructions`, streaming (sequenza di eventi canonica), `text.format` (incl. `json_schema`), function tools (non-streaming). Le funzionalità con stato (`previous_response_id`, `store: true`, `background`, `reasoning`, strumenti ospitati) restituiscono 501 espliciti |
| `POST /v1/responses/input_tokens` | Supportato | Verifica preventiva dei token (`client.responses.input_tokens.count(...)`): conteggio esatto dal tokenizer di Apple, senza generazione; 501 sotto macOS 26.4 invece di una stima. Vedi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Supportato | Restituisce `apple-foundationmodel` (generale, il predefinito) e `apple-foundationmodel-content-tagging` (etichette, non prosa). Vedi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Supportato | Disponibilità del modello, finestra di contesto, lingue, capacità dichiarate del modello (`capabilities`, `capabilities_reported`), la variante del modello in servizio (`variant`, ad es. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Solo debug | Richiede `--debug` |
| Chiamata di strumenti | Supportato | La chiamata viene scritta con generazione guidata (`--tool-calling guided`, predefinito) o come JSON analizzato dal server (`--tool-calling text`). Vedi [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Supportato | Iniezione nel prompt di sistema; blocchi markdown rimossi dall'output |
| `response_format: json_schema` | Supportato | Output conforme allo schema garantito tramite `DynamicGenerationSchema` di FoundationModels; funziona con `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Supportato | Mappati su `GenerationOptions`. `top_p` è campionamento nucleus; `temperature` sotto 0.001 (0 incluso) corrisponde a greedy (deterministico). Omettere `max_tokens` usa la finestra di contesto rimasta (semantica OpenAI) - vedi [Limite di risposta predefinito](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Supportato | SSE; chunk finale di utilizzo solo con `stream_options: {"include_usage": true}` (secondo la specifica OpenAI) |
| `usage` | Supportato | Conteggi reali del tokenizer su macOS 26.4+ (stima caratteri/4 sotto). macOS 27: il conteggio proprio del runtime, incluso il framing del chat template di Apple (circa 46 `prompt_tokens` in più su un prompt di una riga); macOS 26: apfel conta il testo dei messaggi. Dettagli in [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Supportato | `stop`, `tool_calls`, `length` |
| Strategie di contesto | Supportato | Campi di estensione `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Supportato | Si attiva con `--cors` |
| `POST /v1/completions` | 501 | Completions di testo legacy non supportati |
| `POST /v1/embeddings` | 501 | Embeddings non disponibili sul dispositivo |
| `stop` | Supportato | Stringa o fino a 4 stringhe; solo testo semplice (400 con strumenti in ambito o con `json_object`/`json_schema`). Applicato lato output, identico in streaming e non-streaming. Vedi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rifiutati esplicitamente. `n=1` e `logprobs=false` sono accettati senza effetto |
| Multimodale (immagini) | Supportato su macOS 27 | Le parti `image_url` come data URL base64 arrivano nativamente al modello sul dispositivo (limite di 20 MB in base64, il lato più lungo ridotto a 4096 px). Gli URL `http(s)` remoti e i percorsi di file danno sempre 400 - apfel non scarica mai immagini e non legge mai file per un client HTTP. Su macOS 26: 400 con un errore chiaro. Vedi [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Header `Authorization` | Supportato | Obbligatorio quando `--token` è impostato. Vedi [docs/server-security.md](../docs/server-security.md) |

Specifica completa dell'API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Limite di risposta predefinito (`max_tokens`)

Quando `max_tokens` è omesso, **la CLI e il server compatibile con OpenAI si comportano in modo identico**: il valore passa come `nil` e il modello usa lo spazio rimasto nella finestra di contesto. È la semantica OpenAI classica - nessuna costante di ripiego arbitraria.

La finestra di contesto sul dispositivo contiene input *e* output combinati: **4096 token su macOS 26 e sui Mac M1/M2, 8192 token su macOS 27 con chip M3 o più recente e 12 GB+**. apfel legge la dimensione reale a runtime tramite `SystemLanguageModel.contextSize` - controlla la tua con `apfel --model-info`. Se la generazione raggiunge il limite, la risposta termina in modo pulito con `finish_reason: "length"` e il contenuto parziale viene restituito (server: HTTP 200; CLI: exit 0 con un avviso su stderr, oppure exit 8 con `--require-complete` - vedi [docs/cli-reference.md](../docs/cli-reference.md)). Passa `max_tokens` esplicitamente quando vuoi un budget di latenza più stretto o un limite noto per il tuo client.

### Esempi

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

### Scegliere un valore

| Caso d'uso                             | `max_tokens`  |
|----------------------------------------|---------------|
| Risposta di una parola / classificazione | 16 - 32     |
| Istruzione di una riga                 | 64 - 128      |
| Paragrafo breve                        | 256 - 512     |
| Paragrafo lungo / JSON strutturato     | 1024 - 2048   |
| Quanto consente la finestra di contesto | ometterlo    |

Mantieni `input_tokens + max_tokens` ampiamente sotto la finestra di contesto (4096 token su macOS 26 e sui Mac M1/M2, 8192 su macOS 27 con chip M3 o più recente e 12 GB+ (modello AFM 3 Core Advanced di Apple)). Se il prompt stesso supera la finestra, la generazione non può iniziare e la richiesta fallisce con `[context overflow]` (HTTP 400 / CLI exit 4). Il validatore rifiuta i valori non positivi (`max_tokens <= 0`).

### Parità con la CLI

CLI e server condividono un'unica regola: omesso = usare la finestra rimasta. Nessuna costante che possa divergere. Sostituiscilo con `--max-tokens N` o `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardrail permissivi per il server

`apfel --serve --permissive` fa usare al server i guardrail `.permissiveContentTransformations` di Apple per **ogni richiesta** gestita dal processo. Stesso flag, stessa semantica del `--permissive` della CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Non c'è alcuna sostituzione per singola richiesta - decide l'operatore del server per l'intero processo.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitazioni

| Vincolo | Dettaglio |
|------------|--------|
| Finestra di contesto | **4096 token su macOS 26 e sui Mac M1/M2, 8192 token su macOS 27 con chip M3 o più recente e 12 GB+** (input + output combinati). Non è una costante fissa nel codice - apfel legge `SystemLanguageModel.contextSize` a runtime; `apfel --model-info` stampa il valore reale |
| Piattaforma | macOS 26+, solo Apple Silicon |
| Modello | Un solo modello sul dispositivo (~3 miliardi di parametri), servito come `apple-foundationmodel` (generale) e `apple-foundationmodel-content-tagging` (l'adattatore di content tagging di Apple; senza strumenti) |
| Guardrail | Il sistema di sicurezza di Apple può bloccare prompt innocui. `--permissive` riduce i falsi positivi ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Velocità | Sul dispositivo, non su scala cloud - alcuni secondi per risposta |
| Niente embeddings | Non disponibili sul dispositivo |
| Visione | L'immagine raggiunge il modello solo su macOS 27 (server: data URL; CLI: `-f photo.jpg` e immagini via pipe, oltre al testo OCR). Su macOS 26 le immagini sono solo testo tramite OCR/classificazione. Le descrizioni di scena del modello 3B sono approssimative - l'OCR resta il canale affidabile per leggere il testo stampato |
| Dati di addestramento / data limite delle conoscenze | Apple non ha pubblicato una data limite precisa per il modello sul dispositivo. Se spinto a indicarne una, il modello **confabula una data diversa a ogni campione** (es. "October 2023", "April 2023"). Considera inaffidabile tutto ciò che il modello dice del proprio addestramento. |
| Nessuna data corrente né consapevolezza del tempo reale | Il modello non conosce la data di oggi e non ha accesso a rete né orologio. Se interrogato, rifiuta oppure inventa una data. Inietta la data corrente tramite il prompt di sistema quando un calcolo ne dipende (vedi la soluzione sotto). |

**Soluzione per i prompt che dipendono dalla data** - inietta la data corrente come messaggio di sistema:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Nota: anche con una data iniettata, il modello 3B può ancora allucinare (soprattutto se interrogato direttamente sulla propria data limite di addestramento). L'iniezione aiuta i prompt generativi che *usano* la data; non cancella il riflesso del modello di parlare di sé.

Contesto: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentazione di riferimento

Guide per usare apfel da [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - vedi [docs/guides/index.md](../docs/guides/index.md). Testate empiricamente; prova eseguibile su [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - installazione, risoluzione dei problemi e configurazione di Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - ogni flag, codice di uscita e variabile d'ambiente
- [docs/file-extraction.md](../docs/file-extraction.md) - estrazione `-f` e via pipe di PDF / immagini / testo (OCR + comprensione delle immagini)
- [docs/background-service.md](../docs/background-service.md) - uso di `brew services` e launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matrice di supporto di `/v1/*` in dettaglio
- [docs/server-security.md](../docs/server-security.md) - controlli dell'origine, CORS, token e `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - strategie di riduzione del contesto in chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - uso di MCP locale e remoto
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportamento dettagliato della chiamata di strumenti
- [docs/integrations.md](../docs/integrations.md) - integrazioni con strumenti di terze parti (opencode, ecc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revisione locale con apfel + un secondo modello di modifica/applicazione in VS Code
- [docs/demos.md](../docs/demos.md) - guide più lunghe alle demo di shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - oltre 50 prompt reali con output non modificato
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` per gli sviluppatori che lo usano come dipendenza
- [docs/coreai-impact.md](../docs/coreai-impact.md) - perché apfel gira su FoundationModels e non sul nuovo Core AI di Apple (il successore di Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel a confronto con la CLI `fm` di Apple (macOS 27), funzionalità per funzionalità con numeri misurati

## Architettura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Concorrenza rigorosa di Swift 6.3. Tre target: `ApfelCore` (logica pura, testabile a livello di unità, disponibile anche come prodotto Swift Package - collegato sotto Documentazione di riferimento qui sopra), `apfel` (CLI + server) e `apfel-tests` (runner in puro Swift, senza XCTest).

## Build e test

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

`.version` è l'unica fonte di verità. Solo `make release` incrementa le versioni. Le build locali non cambiano la versione.

## L'albero di apfel

Progetti costruiti su apfel. Ognuno è pubblicato nel proprio repository + formula Homebrew.

| Progetto | Cosa fa | Installazione |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | La radice. CLI FoundationModels sul dispositivo + server compatibile con OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Client di chat per macOS: markdown in streaming, I/O vocale, analisi di immagini con Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Azioni IA nella barra dei menu sugli appunti: riassumere, tradurre, riscrivere. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Overlay IA istantaneo: premi un tasto, chiedi, ricevi la risposta, chiudi. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Blocco note con formule - l'IA sul dispositivo come funzione di cella in linea. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP ottimizzati sul budget di token per la piccola finestra sul dispositivo: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Ispettore di debug in SwiftUI: timeline delle richieste, visualizzatore del protocollo MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX che aggiunge un registro MCP persistente + configurazione TOML sopra `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI di etichettatura dei contenuti sul dispositivo: invia testo via pipe e ottieni tag/argomenti/emozioni. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift Package per gli strumenti dell'ecosistema: scoprire, avviare e ricevere in streaming da un `apfel --serve` locale. | Swift Package |

## Progetti della community

Hai costruito qualcosa su apfel? Apri una issue e potrà essere aggiunto qui.

| Progetto | Cosa fa | Link |
|---------|-------------|-------|
| **apfelclaw** di [@julianYaman](https://github.com/julianYaman) | Agente IA locale che legge file, calendario, posta e stato del Mac tramite strumenti di sola lettura | [github](https://github.com/julianyaman/apfelclaw) - [sito](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** di [@bhaskarvilles](https://github.com/bhaskarvilles) | Interfaccia di chat nel browser che dialoga con `apfel --serve` tramite l'API compatibile con OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** di [@lucaspwo](https://github.com/lucaspwo) | Wrapper di Claude Code che usa apfel come backend locale tramite un piccolo proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** di [@hasit](https://github.com/hasit) | Gestore di app per applicazioni shell locali costruite attorno ad apfel | [github](https://github.com/hasit/apfeller) - [sito](https://hasit.github.io/apfeller/) - [catalogo](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** di [@eggsy](https://github.com/eggsy) | Estensione di Raycast: chiedere, tradurre, spiegare file e directory, cronologia delle conversazioni, prompt di sistema personalizzati. Sul dispositivo tramite la CLI di apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuire

Issue e PR sono benvenute su qualsiasi repository `Arthur-Ficial/apfel*`.

**#agentswelcome** - le PR di agenti IA vanno bene. Leggi il `CLAUDE.md` del repository, esegui i test, cita lo strumento in un trailer `Co-Authored-By`. Stesso standard richiesto agli umani: codice pulito, test che passano, limiti onesti. Punto di ingresso più adatto agli agenti: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([regole di contribuzione](https://apfel-mcp.franzai.com/#contribute)).

## Licenza

[MIT](../LICENSE)
