<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Μετάφραση του [αγγλικού README](../README.md). Η αγγλική έκδοση είναι η επίσημη.

# apfel

### Η δωρεάν AI που ήδη υπάρχει στο Mac σας.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Τα Mac με Apple Silicon διαθέτουν ενσωματωμένο LLM μέσω του [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). Το `apfel` το εκθέτει ως εργαλείο UNIX και ως τοπικό διακομιστή συμβατό με OpenAI. 100% στη συσκευή. Χωρίς κλειδιά API, χωρίς cloud.

| Λειτουργία | Εντολή | Τι παίρνετε |
|------|---------|--------------|
| Εργαλείο UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Απαντήσεις φιλικές προς το pipe, συνημμένα αρχεία, έξοδος JSON, κωδικοί εξόδου |
| Διακομιστής συμβατός με OpenAI | `apfel --serve` | Τοπικό backend `http://localhost:11434/v1` έτοιμο για άμεση αντικατάσταση στα OpenAI SDK |

`apfel --chat` - διαδραστικό REPL.

[![Βίντεο επίδειξης του apfel στο τερματικό: πραγματικές εντολές, πραγματικές απαντήσεις στη συσκευή (84 δευτερόλεπτα)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/el/a/apfel-ai-tutorial/#video)

Η κλήση εργαλείων λειτουργεί σε όλα τα περιβάλλοντα.

![apfel CLI](../screenshots/cli.png)

## Απαιτήσεις και εγκατάσταση

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ενεργοποιημένο](https://support.apple.com/en-us/121115). Στο macOS 27, τα Mac με τσιπ M3 ή νεότερο και 12 GB+ μνήμη εκτελούν το μεγαλύτερο μοντέλο της Apple στη συσκευή με παράθυρο 8192 tokens· τα Mac M1/M2 και κάθε Mac με macOS 26 έχουν 4096. Το `apfel --model-info` δείχνει τη δική σας τιμή.

```bash
brew install apfel
```

Ενημέρωση:

```bash
brew upgrade apfel
```

Μεταγλώττιση από τον πηγαίο κώδικα (Command Line Tools με το macOS 27 SDK / Swift 6.3, χωρίς Xcode· το εκτελέσιμο τρέχει σε macOS 26 και 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, same-day tap, Mint, mise, αντιμετώπιση προβλημάτων: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | **Ελληνικά** | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Γρήγορη εκκίνηση

### Εργαλείο UNIX

Βάζετε σε μονά εισαγωγικά τα prompts που περιέχουν `!` (επέκταση ιστορικού zsh/bash): `apfel 'Hello, Mac!'`.

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

### Διακομιστής συμβατός με OpenAI

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

Λεπτομέρειες για την υπηρεσία παρασκηνίου: [docs/background-service.md](../docs/background-service.md).

### Chat για γρήγορες δοκιμές

Το `apfel --chat` είναι ένα μικρό REPL για δοκιμή prompts ή διακομιστών MCP. Για εφαρμογή chat με GUI, δείτε το [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Το Ctrl-C τερματίζει. Το context περικόπτεται αυτόματα ([docs/context-strategies.md](../docs/context-strategies.md)).

Περιορισμοί που αξίζει να γνωρίζετε πριν γράψετε scripts (παράθυρο context ανά Mac, guardrails, χωρίς embeddings): [Περιορισμοί](../README.md#limitations).

## Demos

Πραγματικά shell scripts που τυλίγουν το `apfel`: `cmd` (αγγλικά σε εντολή shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Είναι ενσωματωμένα στο εκτελέσιμο - χωρίς clone του repo. Γράψτε τα όπου θέλετε, από όποιο κανάλι εγκαταστήσατε το apfel (homebrew-core, το tap ή τον πηγαίο κώδικα):

```bash
apfel demos ./apfel-demos
```

Αυτό γράφει κάθε demo (εκτελέσιμο) μαζί με ένα `README.md` στο `./apfel-demos`. Έπειτα τρέξτε τα από εκεί:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Ξανατρέξτε το `apfel demos` μετά από `brew upgrade apfel` για ανανέωση. Πηγές: [`demo/`](../demo/). Αναλυτικοί οδηγοί και μια συνάρτηση shell `cmd` για αντιγραφή στο `.zshrc` σας: [docs/demos.md](../docs/demos.md).

## Υποστήριξη εργαλείων MCP

Συνδέστε διακομιστές [Model Context Protocol](https://modelcontextprotocol.io/) με το `--mcp`. Το apfel ανακαλύπτει, καλεί και επιστρέφει.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Χρησιμοποιήστε `-q` για να κρύψετε τις πληροφορίες των εργαλείων.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Περιλαμβάνεται μια αριθμομηχανή στο [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Απομακρυσμένοι διακομιστές MCP** (Streamable HTTP, προδιαγραφή MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Ασφάλεια:** προτιμήστε το `APFEL_MCP_TOKEN` αντί του `--mcp-token` (φαίνεται στο ps aux). Το apfel αρνείται bearer tokens μέσω απλού `http://`.

## apfel-run: προαιρετικό επίπεδο ρυθμίσεων

Το ίδιο το apfel δεν έχει αρχείο ρυθμίσεων - μόνο flags και μεταβλητές περιβάλλοντος, όπως κάθε εργαλείο UNIX. Αν θέλετε ρυθμίσεις TOML (πολλά MCP, προφίλ, ρυθμίσεις ομάδας στο git), το [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) είναι ένα wrapper με άδεια MIT που τις προσθέτει μέσω αντικατάστασης με `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Συμβατότητα με το OpenAI API

**Βασική διεύθυνση URL:** `http://localhost:11434/v1`

| Λειτουργία | Κατάσταση | Σημειώσεις |
|---------|--------|-------|
| `POST /v1/chat/completions` | Υποστηρίζεται | Με streaming και χωρίς |
| `POST /v1/responses` | Υποστηρίζεται | OpenAI Responses API: είσοδος string/μηνύματος, `instructions`, streaming (κανονική ακολουθία συμβάντων), `text.format` (συμπεριλαμβανομένου του `json_schema`), function tools (χωρίς streaming). Τα stateful χαρακτηριστικά (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) επιστρέφουν ειλικρινή 501 |
| `POST /v1/responses/input_tokens` | Υποστηρίζεται | Προέλεγχος tokens (`client.responses.input_tokens.count(...)`): ακριβής μέτρηση από τον tokenizer της Apple, χωρίς παραγωγή· 501 κάτω από macOS 26.4 αντί για εκτίμηση. Δείτε [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Υποστηρίζεται | Επιστρέφει `apple-foundationmodel` |
| `GET /health` | Υποστηρίζεται | Διαθεσιμότητα μοντέλου, παράθυρο context, γλώσσες, δηλωμένες δυνατότητες του μοντέλου (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Μόνο για debug | Απαιτεί `--debug` |
| Κλήση εργαλείων | Υποστηρίζεται | Native `ToolDefinition` + ανίχνευση JSON. Δείτε [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Υποστηρίζεται | Έγχυση στο system prompt· τα markdown fences αφαιρούνται από την έξοδο |
| `response_format: json_schema` | Υποστηρίζεται | Εγγυημένη έξοδος σύμφωνη με το schema μέσω του FoundationModels `DynamicGenerationSchema`· λειτουργεί με `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Υποστηρίζεται | Αντιστοιχίζονται στο `GenerationOptions`. Το `top_p` είναι nucleus sampling· το `temperature` κάτω από 0.001 (το 0 περιλαμβάνεται) αντιστοιχεί σε greedy (ντετερμινιστικό). Αν παραλειφθεί το `max_tokens`, χρησιμοποιείται το υπόλοιπο παράθυρο context (σημασιολογία OpenAI για άμεση αντικατάσταση) - δείτε [Προεπιλεγμένο όριο απάντησης](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Υποστηρίζεται | SSE· το τελικό chunk usage μόνο όταν `stream_options: {"include_usage": true}` (σύμφωνα με την προδιαγραφή OpenAI) |
| `usage` | Υποστηρίζεται | Πραγματικές μετρήσεις tokenizer σε macOS 26.4+ (κάτω από αυτό, εκτίμηση chars/4). macOS 27: η δική του λογιστική του runtime, συμπεριλαμβανομένου του πλαισίου chat-template της Apple (περίπου 46 επιπλέον `prompt_tokens` σε prompt μίας γραμμής)· macOS 26: το apfel μετράει το κείμενο των μηνυμάτων. Λεπτομέρειες στο [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Υποστηρίζεται | `stop`, `tool_calls`, `length` |
| Στρατηγικές context | Υποστηρίζεται | Πεδία επέκτασης `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Υποστηρίζεται | Ενεργοποιείται με `--cors` |
| `POST /v1/completions` | 501 | Τα legacy text completions δεν υποστηρίζονται |
| `POST /v1/embeddings` | 501 | Τα embeddings δεν είναι διαθέσιμα στη συσκευή |
| `stop` | Υποστηρίζεται | String ή έως 4 strings· μόνο απλό κείμενο (400 όταν υπάρχουν εργαλεία στο πεδίο ή `json_object`/`json_schema`). Εφαρμόζεται στην πλευρά της εξόδου, ίδια με και χωρίς streaming. Δείτε [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Απορρίπτονται ρητά. Τα `n=1` και `logprobs=false` γίνονται δεκτά ως no-op |
| Πολυτροπικότητα (εικόνες) | Υποστηρίζεται σε macOS 27 | Τα μέρη `image_url` ως base64 data URLs πηγαίνουν στο μοντέλο στη συσκευή εγγενώς (όριο 20 MB base64, η μεγαλύτερη πλευρά μειώνεται στα 4096 px). Τα απομακρυσμένα `http(s)` URLs και οι διαδρομές αρχείων δίνουν πάντα 400 - το apfel δεν κατεβάζει ποτέ εικόνες και δεν διαβάζει ποτέ αρχεία για έναν HTTP client. Σε macOS 26: 400 με σαφές μήνυμα σφάλματος. Δείτε [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Κεφαλίδα `Authorization` | Υποστηρίζεται | Απαιτείται όταν έχει οριστεί το `--token`. Δείτε [docs/server-security.md](../docs/server-security.md) |

Πλήρης προδιαγραφή API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Προεπιλεγμένο όριο απάντησης (`max_tokens`)

Όταν παραλείπεται το `max_tokens`, **το CLI και ο διακομιστής συμβατός με OpenAI συμπεριφέρονται πανομοιότυπα**: η τιμή περνά ως `nil` και το μοντέλο χρησιμοποιεί όσο χώρο απομένει στο παράθυρο context. Αυτή είναι σημασιολογία OpenAI για άμεση αντικατάσταση - χωρίς αυθαίρετη σταθερά εφεδρείας.

Το παράθυρο context στη συσκευή χωράει είσοδο *και* έξοδο μαζί: **4096 tokens σε macOS 26 και σε Mac M1/M2, 8192 tokens σε macOS 27 με τσιπ M3 ή νεότερο και 12 GB+**. Το apfel διαβάζει το πραγματικό μέγεθος κατά το runtime μέσω του `SystemLanguageModel.contextSize` - ελέγξτε το δικό σας με `apfel --model-info`. Αν η παραγωγή φτάσει στο όριο, η απάντηση τελειώνει καθαρά με `finish_reason: "length"` και επιστρέφεται το μερικό περιεχόμενο (διακομιστής: HTTP 200· CLI: έξοδος 0 με προειδοποίηση στο stderr, ή έξοδος 8 με `--require-complete` - δείτε [docs/cli-reference.md](../docs/cli-reference.md)). Ορίστε ρητά το `max_tokens` όταν θέλετε στενότερο προϋπολογισμό καθυστέρησης ή γνωστό όριο για τον client σας.

### Παραδείγματα

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

### Επιλογή τιμής

| Περίπτωση χρήσης                       | `max_tokens`  |
|----------------------------------------|---------------|
| Απάντηση μίας λέξης / ταξινόμηση       | 16 - 32       |
| Οδηγία μίας γραμμής                    | 64 - 128      |
| Σύντομη παράγραφος                     | 256 - 512     |
| Μεγάλη παράγραφος / δομημένο JSON      | 1024 - 2048   |
| Όσο επιτρέπει το παράθυρο context      | παραλείψτε το |

Κρατήστε το `input_tokens + max_tokens` άνετα κάτω από το παράθυρο context (4096 tokens σε macOS 26 και σε Mac M1/M2, 8192 σε macOS 27 με τσιπ M3 ή νεότερο και 12 GB+ (το μοντέλο AFM 3 Core Advanced της Apple)). Αν το ίδιο το prompt υπερβαίνει το παράθυρο, η παραγωγή δεν μπορεί να ξεκινήσει και το αίτημα αποτυγχάνει με `[context overflow]` (HTTP 400 / CLI exit 4). Ο validator απορρίπτει μη θετικές τιμές (`max_tokens <= 0`).

### Ισοδυναμία με το CLI

Το CLI και ο διακομιστής μοιράζονται έναν κανόνα: παράλειψη = χρήση του υπολοίπου παραθύρου. Καμία σταθερά που να αποκλίνει. Παρακάμψτε με `--max-tokens N` ή `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails για τον διακομιστή

Το `apfel --serve --permissive` κάνει τον διακομιστή να χρησιμοποιεί τα guardrails `.permissiveContentTransformations` της Apple για **κάθε αίτημα** που χειρίζεται η διεργασία. Ίδιο flag, ίδια σημασιολογία με το `--permissive` του CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Δεν υπάρχει παράκαμψη ανά αίτημα - αποφασίζει ο διαχειριστής του διακομιστή για ολόκληρη τη διεργασία.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Περιορισμοί

| Περιορισμός | Λεπτομέρειες |
|------------|--------|
| Παράθυρο context | **4096 tokens σε macOS 26 και σε Mac M1/M2, 8192 tokens σε macOS 27 με τσιπ M3 ή νεότερο και 12 GB+** (είσοδος + έξοδος μαζί). Δεν είναι σκληροκωδικοποιημένη σταθερά - το apfel διαβάζει το `SystemLanguageModel.contextSize` κατά το runtime· το `apfel --model-info` εμφανίζει την τρέχουσα τιμή |
| Πλατφόρμα | macOS 26+, μόνο Apple Silicon |
| Μοντέλο | Ένα μοντέλο (`apple-foundationmodel`, ~3B παράμετροι στη συσκευή), μη ρυθμιζόμενο |
| Guardrails | Το σύστημα ασφαλείας της Apple μπορεί να μπλοκάρει αθώα prompts. Το `--permissive` μειώνει τα ψευδώς θετικά ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Ταχύτητα | Στη συσκευή, όχι κλίμακας cloud - μερικά δευτερόλεπτα ανά απάντηση |
| Χωρίς embeddings | Δεν είναι διαθέσιμα στη συσκευή |
| Όραση | Η είσοδος εικόνας φτάνει στο μοντέλο μόνο σε macOS 27 (διακομιστής: data URLs· CLI: `-f photo.jpg` και εικόνες μέσω pipe, επιπλέον του κειμένου OCR). Σε macOS 26 οι εικόνες είναι μόνο κείμενο μέσω OCR/ταξινόμησης. Οι περιγραφές σκηνών του μοντέλου 3B είναι πρόχειρες - το OCR παραμένει το αξιόπιστο κανάλι για ανάγνωση εκτυπωμένου κειμένου |
| Δεδομένα εκπαίδευσης / όριο γνώσης | Η Apple δεν έχει δημοσιεύσει ακριβές όριο για το μοντέλο στη συσκευή. Όταν πιεστεί να δώσει ένα, το μοντέλο **επινοεί διαφορετική ημερομηνία σε κάθε δείγμα** (π.χ. "October 2023", "April 2023"). Θεωρήστε αναξιόπιστες όλες τις αναφορές του μοντέλου για τη δική του εκπαίδευση. |
| Χωρίς τρέχουσα ημερομηνία ή επίγνωση πραγματικού χρόνου | Το μοντέλο δεν γνωρίζει τη σημερινή ημερομηνία και δεν έχει πρόσβαση σε δίκτυο/ρολόι. Αν ρωτηθεί, είτε θα αρνηθεί είτε θα επινοήσει ημερομηνία. Εισάγετε την τρέχουσα ημερομηνία μέσω system prompt όταν οι υπολογισμοί εξαρτώνται από αυτήν (δείτε την παράκαμψη παρακάτω). |

**Παράκαμψη για prompts που εξαρτώνται από ημερομηνία** - εισάγετε την τρέχουσα ημερομηνία ως system message:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Σημείωση: ακόμη και με εισαγόμενη ημερομηνία το μοντέλο 3B μπορεί να παραισθάνεται (ειδικά όταν ρωτιέται απευθείας για το όριο της εκπαίδευσής του). Η εισαγωγή βοηθά τα παραγωγικά prompts που *χρησιμοποιούν* την ημερομηνία· δεν υπερισχύει του αντανακλαστικού του μοντέλου να μιλά για τον εαυτό του.

Υπόβαθρο: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Τεκμηρίωση αναφοράς

Οδηγοί για χρήση του apfel από [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - δείτε [docs/guides/index.md](../docs/guides/index.md). Δοκιμασμένοι εμπειρικά· εκτελέσιμη απόδειξη στο [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - εγκατάσταση, αντιμετώπιση προβλημάτων και ρύθμιση του Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - κάθε flag, κωδικός εξόδου και μεταβλητή περιβάλλοντος
- [docs/file-extraction.md](../docs/file-extraction.md) - εξαγωγή περιεχομένου PDF / εικόνας / κειμένου με `-f` και pipe (OCR + κατανόηση εικόνας)
- [docs/background-service.md](../docs/background-service.md) - χρήση του `brew services` και του launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - αναλυτικός πίνακας υποστήριξης `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - έλεγχοι origin, CORS, tokens και `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - στρατηγικές περικοπής του chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - χρήση τοπικού και απομακρυσμένου MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - αναλυτική συμπεριφορά της κλήσης εργαλείων
- [docs/integrations.md](../docs/integrations.md) - ενσωματώσεις με εργαλεία τρίτων (opencode κ.ά.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - τοπική αναθεώρηση με apfel + δεύτερο μοντέλο επεξεργασίας/εφαρμογής στο VS Code
- [docs/demos.md](../docs/demos.md) - μεγαλύτεροι οδηγοί για τα shell demos
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ πραγματικά prompts με ανέπαφη έξοδο
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` για downstream προγραμματιστές
- [docs/coreai-impact.md](../docs/coreai-impact.md) - γιατί το apfel τρέχει σε FoundationModels και όχι στο νέο Core AI της Apple (διάδοχο του Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - το apfel σε σύγκριση με το δικό της CLI `fm` της Apple (macOS 27), χαρακτηριστικό προς χαρακτηριστικό με μετρημένα στοιχεία

## Αρχιτεκτονική

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Τρεις στόχοι: `ApfelCore` (καθαρή λογική, ελέγξιμη με unit tests, διαθέσιμη και ως προϊόν Swift Package - σύνδεσμος στην Τεκμηρίωση αναφοράς παραπάνω), `apfel` (CLI + διακομιστής) και `apfel-tests` (runner σε καθαρή Swift, χωρίς XCTest).

## Μεταγλώττιση και δοκιμές

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

Το `.version` είναι η μοναδική πηγή αλήθειας. Μόνο το `make release` αυξάνει εκδόσεις. Οι τοπικές μεταγλωττίσεις δεν αλλάζουν την έκδοση.

## Το δέντρο του apfel

Έργα χτισμένα πάνω στο apfel. Το καθένα διατίθεται ως δικό του repo + formula Homebrew.

| Έργο | Τι κάνει | Εγκατάσταση |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Η ρίζα. CLI του FoundationModels στη συσκευή + διακομιστής συμβατός με OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Πελάτης chat για macOS: streaming markdown, είσοδος/έξοδος ομιλίας, ανάλυση εικόνων με Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Ενέργειες AI στη γραμμή μενού πάνω στο πρόχειρο: σύνοψη, μετάφραση, αναδιατύπωση. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Άμεσο overlay AI: πατήστε ένα πλήκτρο, ρωτήστε, πάρτε απάντηση, κλείστε. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Σημειωματάριο με τύπους - η AI στη συσκευή ως συνάρτηση κελιού. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP βελτιστοποιημένα για προϋπολογισμό tokens στο μικρό παράθυρο της συσκευής: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Επιθεωρητής debug σε SwiftUI: χρονολόγιο αιτημάτων, προβολέας πρωτοκόλλου MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX που προσθέτει μόνιμο μητρώο MCP + ρυθμίσεις TOML πάνω από το `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI επισήμανσης περιεχομένου στη συσκευή: δώστε κείμενο, πάρτε tags/θέματα/συναισθήματα. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift package για εργαλεία του οικοσυστήματος: εντοπισμός, εκκίνηση και streaming από ένα τοπικό `apfel --serve`. | Swift Package |

## Έργα της κοινότητας

Φτιάξατε κάτι πάνω στο apfel; Ανοίξτε ένα issue και μπορεί να προστεθεί εδώ.

| Έργο | Τι κάνει | Σύνδεσμοι |
|---------|-------------|-------|
| **apfelclaw** από τον [@julianYaman](https://github.com/julianYaman) | Τοπικός πράκτορας AI που διαβάζει αρχεία, ημερολόγιο, αλληλογραφία και κατάσταση του Mac μέσω εργαλείων μόνο ανάγνωσης | [github](https://github.com/julianyaman/apfelclaw) - [ιστότοπος](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** από τον [@bhaskarvilles](https://github.com/bhaskarvilles) | Διεπαφή chat στον περιηγητή που μιλά με το `apfel --serve` μέσω του API συμβατού με OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** από τον [@lucaspwo](https://github.com/lucaspwo) | Wrapper του Claude Code που βάζει το apfel ως τοπικό backend μέσω ενός μικρού proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** από τον [@hasit](https://github.com/hasit) | Διαχειριστής εφαρμογών για τοπικές εφαρμογές shell χτισμένες γύρω από το apfel | [github](https://github.com/hasit/apfeller) - [ιστότοπος](https://hasit.github.io/apfeller/) - [κατάλογος](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** από τον [@eggsy](https://github.com/eggsy) | Επέκταση για τη γραμμή εντολών του Raycast: ερωτήσεις, μετάφραση, επεξήγηση αρχείων και φακέλων, ιστορικό συνομιλιών, προσαρμοσμένα system prompts. Στη συσκευή μέσω του apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Συνεισφορά

Τα issues και τα PRs είναι ευπρόσδεκτα σε κάθε repo `Arthur-Ficial/apfel*`.

**#agentswelcome** - τα PRs από πράκτορες AI είναι ευπρόσδεκτα. Διαβάστε το `CLAUDE.md` του repo, τρέξτε τα tests, αναφέρετε το εργαλείο σε ένα trailer `Co-Authored-By`. Ίδιο επίπεδο με τους ανθρώπους: καθαρός κώδικας, tests που περνούν, ειλικρινείς περιορισμοί. Το πιο φιλικό σημείο εισόδου για πράκτορες: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([κανόνες συνεισφοράς](https://apfel-mcp.franzai.com/#contribute)).

## Άδεια

[MIT](../LICENSE)
