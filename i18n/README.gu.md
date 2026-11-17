<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> [અંગ્રેજી README](../README.md) પરથી અનુવાદિત. અંગ્રેજી આવૃત્તિ જ અધિકૃત છે.

# apfel

### તમારા Mac પર પહેલેથી હાજર મફત AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac માં [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) દ્વારા બિલ્ટ-ઇન LLM આવે છે. `apfel` તેને UNIX ટૂલ તરીકે અને લોકલ OpenAI-સુસંગત સર્વર તરીકે ઉપલબ્ધ કરાવે છે. 100% ઓન-ડિવાઇસ. કોઈ API કી નહીં, કોઈ ક્લાઉડ નહીં.

| મોડ | કમાન્ડ | તમને શું મળે છે |
|------|---------|--------------|
| UNIX ટૂલ | `apfel "prompt"` / `echo "text" \| apfel` | પાઇપ-ફ્રેન્ડલી જવાબો, ફાઇલ એટેચમેન્ટ, JSON આઉટપુટ, એક્ઝિટ કોડ |
| OpenAI-સુસંગત સર્વર | `apfel --serve` | OpenAI SDK માટે લોકલ `http://localhost:11434/v1` બેકએન્ડ, સીધો બદલી શકાય તેવો |

`apfel --chat` - ઇન્ટરેક્ટિવ REPL.

[![apfel ટર્મિનલ ડેમો વિડિયો: સાચા કમાન્ડ, ડિવાઇસ પર સાચા જવાબ (82 સેકન્ડ)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/gu/a/apfel-ai-tutorial/#video)

ટૂલ કૉલિંગ બધા સંદર્ભોમાં કામ કરે છે.

![apfel CLI](../screenshots/cli.png)

## જરૂરિયાતો અને ઇન્સ્ટૉલ

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ચાલુ કરેલું](https://support.apple.com/en-us/121115). macOS 27 પર, M3 કે નવી ચિપ અને 12 GB+ વાળા Mac Appleનું મોટું ઓન-ડિવાઇસ મૉડલ 8192-ટોકન વિન્ડો સાથે ચલાવે છે; M1/M2 Mac અને macOS 26 પરના દરેક Macમાં 4096 હોય છે. `apfel --model-info` તમારું દર્શાવે છે.

```bash
brew install apfel
```

અપડેટ:

```bash
brew upgrade apfel
```

સોર્સમાંથી બિલ્ડ કરો (macOS 27 SDK / Swift 6.3 સાથે Command Line Tools, Xcode નહીં; બાઇનરી macOS 26 અને 27 પર ચાલે છે):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, ટ્રબલશૂટિંગ: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | **ગુજરાતી** | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## ઝડપી શરૂઆત

### UNIX ટૂલ

`!` વાળા prompt ને સિંગલ ક્વોટમાં લખો (zsh/bash હિસ્ટરી એક્સપેન્શન): `apfel 'Hello, Mac!'`.

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

### OpenAI-સુસંગત સર્વર

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

બેકગ્રાઉન્ડ સર્વિસની વિગતો: [docs/background-service.md](../docs/background-service.md).

### ઝડપી ટેસ્ટિંગ ચેટ

`apfel --chat` એ prompt અથવા MCP સર્વર ટેસ્ટ કરવા માટેનું નાનું REPL છે. GUI ચેટ ઍપ માટે [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) જુઓ.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C થી બહાર નીકળાય છે. કોન્ટેક્સ્ટ આપમેળે ટ્રિમ થાય છે ([docs/context-strategies.md](../docs/context-strategies.md)).

તેની સામે સ્ક્રિપ્ટ લખતા પહેલાં જાણવા જેવી મર્યાદાઓ (દરેક Mac મુજબ કોન્ટેક્સ્ટ વિન્ડો, ગાર્ડરેલ, કોઈ એમ્બેડિંગ નહીં): [મર્યાદાઓ](../README.md#limitations).

## ડેમો

`apfel` ને વીંટાળતી વાસ્તવિક શેલ સ્ક્રિપ્ટો: `cmd` (અંગ્રેજીથી શેલ કમાન્ડ), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. તે બાઇનરીમાં જ સામેલ છે - રેપો ક્લોન કરવાની જરૂર નથી. તમે apfel જ્યાંથી ઇન્સ્ટૉલ કર્યું હોય (homebrew-core, tap, અથવા સોર્સ) ત્યાંથી તેમને ઇચ્છિત જગ્યાએ લખો:

```bash
apfel demos ./apfel-demos
```

તે દરેક ડેમો (એક્ઝિક્યુટેબલ) અને એક `README.md` ને `./apfel-demos` માં લખે છે. પછી ત્યાંથી ચલાવો:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

તાજું કરવા માટે `brew upgrade apfel` પછી ફરી `apfel demos` ચલાવો. સોર્સ: [`demo/`](../demo/). વૉકથ્રૂ અને તમારા `.zshrc` માટે કૉપી-પેસ્ટ `cmd` શેલ ફંક્શન: [docs/demos.md](../docs/demos.md).

## MCP ટૂલ સપોર્ટ

`--mcp` વડે [Model Context Protocol](https://modelcontextprotocol.io/) સર્વર જોડો. apfel શોધે છે, ચલાવે છે અને પરિણામ પાછું આપે છે.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

ટૂલની માહિતી છુપાવવા `-q` વાપરો.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

[`mcp/calculator/`](../mcp/calculator/) માં એક કેલ્ક્યુલેટર સાથે આવે છે ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**રિમોટ MCP સર્વર** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **સુરક્ષા:** `--mcp-token` (ps aux) કરતાં `APFEL_MCP_TOKEN` પસંદ કરો. apfel સાદા `http://` પર bearer token મોકલવાનો ઇનકાર કરે છે.

## apfel-run: વૈકલ્પિક કન્ફિગ લેયર

apfel માં પોતે કોઈ કન્ફિગ ફાઇલ નથી - ફ્લેગ + env વેરિએબલ, કોઈપણ UNIX ટૂલની જેમ. જો તમને TOML કન્ફિગ જોઈએ (ઘણા MCP, પ્રોફાઇલ, git માં ટીમ કન્ફિગ), તો [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) એક MIT રેપર છે જે `execve` ડ્રોપ-ઇન દ્વારા તે ઉમેરે છે.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API સુસંગતતા

**બેઝ URL:** `http://localhost:11434/v1`

| સુવિધા | સ્થિતિ | નોંધ |
|---------|--------|-------|
| `POST /v1/chat/completions` | સપોર્ટેડ | સ્ટ્રીમિંગ + નૉન-સ્ટ્રીમિંગ |
| `POST /v1/responses` | સપોર્ટેડ | OpenAI Responses API: string/message ઇનપુટ, `instructions`, સ્ટ્રીમિંગ (canonical event sequence), `text.format` (`json_schema` સહિત), ફંક્શન ટૂલ (નૉન-સ્ટ્રીમિંગ). સ્ટેટફુલ સુવિધાઓ (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) પ્રામાણિક 501 આપે છે |
| `POST /v1/responses/input_tokens` | સપોર્ટેડ | ટોકન પ્રીફ્લાઇટ (`client.responses.input_tokens.count(...)`): Appleના ટોકનાઇઝર પરથી ચોક્કસ ગણતરી, કોઈ જનરેશન નહીં; macOS 26.4 થી નીચે અંદાજને બદલે 501. જુઓ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | સપોર્ટેડ | `apple-foundationmodel` (સામાન્ય, ડિફૉલ્ટ) અને `apple-foundationmodel-content-tagging` (લેબલ, ગદ્ય નહીં) પાછાં આપે છે. જુઓ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | સપોર્ટેડ | મૉડલની ઉપલબ્ધતા, કોન્ટેક્સ્ટ વિન્ડો, ભાષાઓ, જાણ કરાયેલી મૉડલ ક્ષમતાઓ (`capabilities`, `capabilities_reported`), સર્વ કરતું મૉડલ વેરિઅન્ટ (`variant`, દા.ત. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | ફક્ત ડીબગ | `--debug` જરૂરી |
| ટૂલ કૉલિંગ | સપોર્ટેડ | કૉલ ગાઇડેડ જનરેશન દ્વારા (`--tool-calling guided`, ડિફૉલ્ટ) અથવા સર્વર પાર્સ કરે તેવા JSON તરીકે (`--tool-calling text`) લખાય છે. જુઓ [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | સપોર્ટેડ | સિસ્ટમ-પ્રોમ્પ્ટ ઇન્જેક્શન; આઉટપુટમાંથી markdown ફેન્સ દૂર કરાય છે |
| `response_format: json_schema` | સપોર્ટેડ | FoundationModels `DynamicGenerationSchema` દ્વારા સ્કીમાને અનુરૂપ આઉટપુટની ખાતરી; `stream: true` સાથે કામ કરે છે |
| `temperature`, `top_p`, `max_tokens`, `seed` | સપોર્ટેડ | `GenerationOptions` સાથે મેપ કરાય છે. `top_p` એ nucleus sampling છે; 0.001 થી નીચેનું `temperature` (0 સહિત) greedy (નિર્ધારિત) માં મેપ થાય છે. `max_tokens` છોડી દેવાથી બાકીની કોન્ટેક્સ્ટ વિન્ડો વપરાય છે (OpenAI જેવી જ સિમેન્ટિક્સ) - જુઓ [ડિફૉલ્ટ રિસ્પોન્સ મર્યાદા](../README.md#default-response-cap-max_tokens) |
| `stream: true` | સપોર્ટેડ | SSE; અંતિમ usage chunk ફક્ત `stream_options: {"include_usage": true}` હોય ત્યારે (OpenAI spec મુજબ) |
| `usage` | સપોર્ટેડ | macOS 26.4+ પર વાસ્તવિક ટોકનાઇઝર ગણતરી (તેનાથી નીચે chars/4 અંદાજ). macOS 27: રનટાઇમનું પોતાનું હિસાબ, Appleના chat-template framing સહિત (એક લીટીના prompt પર લગભગ 46 વધારાના `prompt_tokens`); macOS 26: apfel મેસેજ ટેક્સ્ટ ગણે છે. વિગતો [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) માં |
| `finish_reason` | સપોર્ટેડ | `stop`, `tool_calls`, `length` |
| કોન્ટેક્સ્ટ સ્ટ્રેટેજી | સપોર્ટેડ | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` એક્સટેન્શન ફીલ્ડ |
| CORS | સપોર્ટેડ | `--cors` થી ચાલુ કરો |
| `POST /v1/completions` | 501 | લેગસી ટેક્સ્ટ કમ્પ્લીશન સપોર્ટેડ નથી |
| `POST /v1/embeddings` | 501 | ઓન-ડિવાઇસ એમ્બેડિંગ ઉપલબ્ધ નથી |
| `stop` | સપોર્ટેડ | એક string અથવા 4 સુધી strings; ફક્ત સાદો ટેક્સ્ટ (ટૂલ સ્કોપમાં હોય કે `json_object`/`json_schema` હોય તો 400). આઉટપુટ બાજુએ લાગુ થાય છે, સ્ટ્રીમિંગ અને નૉન-સ્ટ્રીમિંગમાં સરખું. જુઓ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | સ્પષ્ટપણે નકારાય છે. `n=1` અને `logprobs=false` કંઈ ન કરતા રૂપે સ્વીકારાય છે |
| મલ્ટિ-મોડલ (ઇમેજ) | macOS 27 પર સપોર્ટેડ | base64 data URL તરીકે `image_url` ભાગો સીધા ઓન-ડિવાઇસ મૉડલને જાય છે (20 MB base64 મર્યાદા, સૌથી લાંબી બાજુ 4096 px સુધી ઘટાડાય છે). રિમોટ `http(s)` URL અને ફાઇલ પાથ હંમેશા 400 - apfel ક્યારેય ઇમેજ ફેચ કરતું નથી અને HTTP ક્લાયન્ટ માટે ક્યારેય ફાઇલ વાંચતું નથી. macOS 26 પર: સ્પષ્ટ ભૂલ સાથે 400. જુઓ [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` હેડર | સપોર્ટેડ | `--token` સેટ હોય ત્યારે જરૂરી. જુઓ [docs/server-security.md](../docs/server-security.md) |

સંપૂર્ણ API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## ડિફૉલ્ટ રિસ્પોન્સ મર્યાદા (`max_tokens`)

`max_tokens` છોડી દેવાય ત્યારે **CLI અને OpenAI-સુસંગત સર્વર સરખું વર્તે છે**: વેલ્યુ `nil` તરીકે આગળ જાય છે અને મૉડલ કોન્ટેક્સ્ટ વિન્ડોમાં બાકી રહેલી જગ્યા વાપરે છે. આ OpenAI જેવી જ સિમેન્ટિક્સ છે - કોઈ મનસ્વી ફૉલબેક કૉન્સ્ટન્ટ નહીં.

ઓન-ડિવાઇસ કોન્ટેક્સ્ટ વિન્ડોમાં ઇનપુટ *અને* આઉટપુટ બંને સાથે સમાય છે: **macOS 26 પર અને M1/M2 Mac પર 4096 ટોકન, M3 કે નવી ચિપ અને 12 GB+ સાથે macOS 27 પર 8192 ટોકન**. apfel વાસ્તવિક કદ રનટાઇમ પર `SystemLanguageModel.contextSize` દ્વારા વાંચે છે - તમારું `apfel --model-info` થી તપાસો. જો જનરેશન મર્યાદાને અડે, તો રિસ્પોન્સ `finish_reason: "length"` સાથે સ્વચ્છ રીતે પૂરો થાય છે અને અધૂરું કન્ટેન્ટ પાછું અપાય છે (સર્વર: HTTP 200; CLI: stderr ચેતવણી સાથે exit 0, અથવા `--require-complete` સાથે exit 8 - જુઓ [docs/cli-reference.md](../docs/cli-reference.md)). વધુ કડક લેટન્સી બજેટ અથવા તમારા ક્લાયન્ટ માટે જાણીતી મર્યાદા જોઈએ ત્યારે `max_tokens` સ્પષ્ટપણે આપો.

### ઉદાહરણો

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

### વેલ્યુ પસંદ કરવી

| ઉપયોગ | `max_tokens`  |
|----------------------------------------|---------------|
| એક શબ્દ / વર્ગીકરણ જવાબ     | 16 - 32       |
| એક લીટીની સૂચના                    | 64 - 128      |
| ટૂંકો પરિચ્છેદ                        | 256 - 512     |
| લાંબો પરિચ્છેદ / સ્ટ્રક્ચર્ડ JSON       | 1024 - 2048   |
| કોન્ટેક્સ્ટ વિન્ડો જેટલું ચાલે તેટલું લાંબું   | છોડી દો       |

`input_tokens + max_tokens` ને કોન્ટેક્સ્ટ વિન્ડોથી આરામથી નીચે રાખો (macOS 26 પર અને M1/M2 Mac પર 4096 ટોકન, M3 કે નવી ચિપ અને 12 GB+ સાથે macOS 27 પર 8192 (Appleનું AFM 3 Core Advanced મૉડલ)). જો prompt પોતે જ વિન્ડોથી વધી જાય, તો જનરેશન શરૂ થઈ શકતું નથી અને રિક્વેસ્ટ `[context overflow]` સાથે નિષ્ફળ જાય છે (HTTP 400 / CLI exit 4). વેલિડેટર બિન-ધન વેલ્યુ (`max_tokens <= 0`) નકારે છે.

### CLI સમાનતા

CLI અને સર્વર એક જ નિયમ વાપરે છે: છોડી દીધું = બાકીની વિન્ડો વાપરો. બદલાઈ જાય તેવો કોઈ કૉન્સ્ટન્ટ નથી. `--max-tokens N` અથવા `APFEL_MAX_TOKENS=N` થી બદલો.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### સર્વર માટે permissive ગાર્ડરેલ

`apfel --serve --permissive` સર્વરને પ્રોસેસ સંભાળતી **દરેક રિક્વેસ્ટ** માટે Appleના `.permissiveContentTransformations` ગાર્ડરેલ વાપરાવે છે. CLIના `--permissive` જેવો જ ફ્લેગ, એવી જ સિમેન્ટિક્સ ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). રિક્વેસ્ટ દીઠ ઓવરરાઇડ નથી - આખી પ્રોસેસ માટે સર્વર ઓપરેટર નક્કી કરે છે.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## મર્યાદાઓ

| મર્યાદા | વિગત |
|------------|--------|
| કોન્ટેક્સ્ટ વિન્ડો | **macOS 26 પર અને M1/M2 Mac પર 4096 ટોકન, M3 કે નવી ચિપ અને 12 GB+ સાથે macOS 27 પર 8192 ટોકન** (ઇનપુટ + આઉટપુટ ભેગા). હાર્ડકોડેડ કૉન્સ્ટન્ટ નથી - apfel રનટાઇમ પર `SystemLanguageModel.contextSize` વાંચે છે; `apfel --model-info` વર્તમાન વેલ્યુ છાપે છે |
| પ્લૅટફૉર્મ | macOS 26+, ફક્ત Apple Silicon |
| મૉડલ | એક જ ઓન-ડિવાઇસ મૉડલ (~3B પેરામીટર), `apple-foundationmodel` (સામાન્ય) અને `apple-foundationmodel-content-tagging` (Appleનું કન્ટેન્ટ-ટૅગિંગ ઍડેપ્ટર; ટૂલ નહીં) તરીકે ઉપલબ્ધ |
| ગાર્ડરેલ | Appleની સુરક્ષા સિસ્ટમ નિર્દોષ prompt પણ અટકાવી શકે છે. `--permissive` ખોટા પોઝિટિવ ઘટાડે છે ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| ઝડપ | ઓન-ડિવાઇસ, ક્લાઉડ-સ્કેલ નહીં - દરેક જવાબ માટે થોડી સેકન્ડ |
| કોઈ એમ્બેડિંગ નહીં | ઓન-ડિવાઇસ ઉપલબ્ધ નથી |
| વિઝન | ઇમેજ ઇનપુટ મૉડલ સુધી ફક્ત macOS 27 પર પહોંચે છે (સર્વર: data URL; CLI: `-f photo.jpg` અને પાઇપ કરેલી ઇમેજ, OCR ટેક્સ્ટ ઉપરાંત). macOS 26 પર ઇમેજ OCR/વર્ગીકરણ દ્વારા ફક્ત ટેક્સ્ટ રૂપે. 3B મૉડલનાં દૃશ્ય વર્ણનો સ્થૂળ છે - છાપેલું વાંચવા માટે OCR જ ભરોસાપાત્ર માર્ગ રહે છે |
| ટ્રેનિંગ ડેટા / નૉલેજ કટઓફ | Appleએ ઓન-ડિવાઇસ મૉડલ માટે ચોક્કસ કટઓફ પ્રકાશિત કર્યો નથી. નામ આપવા દબાણ કરો ત્યારે મૉડલ **દરેક સૅમ્પલમાં અલગ તારીખ ઘડી કાઢે છે** (દા.ત. "October 2023", "April 2023"). મૉડલના પોતાની ટ્રેનિંગ વિશેના બધા દાવા અવિશ્વસનીય ગણો. |
| વર્તમાન તારીખ કે રિયલ-ટાઇમની જાણ નથી | મૉડલને આજની તારીખ ખબર નથી અને નેટવર્ક/ઘડિયાળ સુધી પહોંચ નથી. પૂછો તો તે કાં ના પાડશે કાં તારીખ ઘડી કાઢશે. ગણતરી તારીખ પર આધારિત હોય ત્યારે વર્તમાન તારીખ system prompt દ્વારા આપો (નીચેનો ઉપાય જુઓ). |

**તારીખ-આધારિત prompt માટે ઉપાય** - વર્તમાન તારીખ system મેસેજ તરીકે આપો:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

નોંધ: તારીખ આપી હોવા છતાં 3B મૉડલ હજી ભ્રમ ઊભો કરી શકે છે (ખાસ કરીને પોતાના ટ્રેનિંગ કટઓફ વિશે સીધું પૂછો ત્યારે). આ ઇન્જેક્શન તારીખનો *ઉપયોગ કરતા* જનરેટિવ prompt માં મદદ કરે છે; તે મૉડલની પોતાના વિશે બોલવાની ટેવને બદલતું નથી.

પૃષ્ઠભૂમિ: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## રેફરન્સ ડૉક્સ

apfel ને [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) માંથી વાપરવાની માર્ગદર્શિકાઓ - જુઓ [docs/guides/index.md](../docs/guides/index.md). પ્રયોગથી ચકાસેલ; ચલાવી શકાય તેવો પુરાવો [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) પર.

- [docs/install.md](../docs/install.md) - ઇન્સ્ટૉલ, ટ્રબલશૂટિંગ અને Apple Intelligence સેટઅપ
- [docs/cli-reference.md](../docs/cli-reference.md) - દરેક ફ્લેગ, એક્ઝિટ કોડ અને એન્વાયર્નમેન્ટ વેરિએબલ
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` અને પાઇપ કરેલ PDF / ઇમેજ / ટેક્સ્ટ એક્સ્ટ્રેક્શન (OCR + ઇમેજ સમજ)
- [docs/background-service.md](../docs/background-service.md) - `brew services` અને launchd ઉપયોગ
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` સપોર્ટ મેટ્રિક્સ ઊંડાણમાં
- [docs/server-security.md](../docs/server-security.md) - origin ચેક, CORS, ટોકન અને `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - ચેટ ટ્રિમિંગ સ્ટ્રેટેજી
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - લોકલ અને રિમોટ MCP ઉપયોગ
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ટૂલ-કૉલિંગ વર્તનની વિગતવાર સમજ
- [docs/integrations.md](../docs/integrations.md) - થર્ડ-પાર્ટી ટૂલ ઇન્ટિગ્રેશન (opencode, વગેરે)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code માં apfel + બીજા edit/apply મૉડલ સાથે લોકલ રિવ્યૂ
- [docs/demos.md](../docs/demos.md) - શેલ ડેમોના લાંબા વૉકથ્રૂ
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - અસંપાદિત આઉટપુટ સાથે 50+ વાસ્તવિક prompt
- [docs/swift-library.md](../docs/swift-library.md) - ડાઉનસ્ટ્રીમ ડેવલપર માટે `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel શા માટે FoundationModels પર ચાલે છે, Appleના નવા Core AI (Core MLના અનુગામી) પર નહીં
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel ની Appleના પોતાના `fm` CLI (macOS 27) સાથે સરખામણી, સુવિધા દર સુવિધા, માપેલા આંકડા સાથે

## આર્કિટેક્ચર

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 સ્ટ્રિક્ટ કન્કરન્સી. ત્રણ ટાર્ગેટ: `ApfelCore` (શુદ્ધ લૉજિક, યુનિટ-ટેસ્ટેબલ, Swift Package પ્રોડક્ટ તરીકે પણ ઉપલબ્ધ - ઉપર રેફરન્સ ડૉક્સમાં લિંક), `apfel` (CLI + સર્વર), અને `apfel-tests` (શુદ્ધ Swift રનર, XCTest નહીં).

## બિલ્ડ અને ટેસ્ટ

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

`.version` એ એકમાત્ર સત્ય-સ્રોત છે. ફક્ત `make release` વર્ઝન વધારે છે. લોકલ બિલ્ડ વર્ઝન બદલતા નથી.

## apfel વૃક્ષ

apfel પર બનેલા પ્રોજેક્ટ. દરેક પોતાના રેપો + Homebrew ફૉર્મ્યુલા તરીકે આવે છે.

| પ્રોજેક્ટ | તે શું કરે છે | ઇન્સ્ટૉલ |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | મૂળ. ઓન-ડિવાઇસ FoundationModels CLI + OpenAI-સુસંગત સર્વર. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS ચેટ ક્લાયન્ટ: સ્ટ્રીમિંગ markdown, સ્પીચ I/O, Apple Vision ઇમેજ વિશ્લેષણ. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ક્લિપબોર્ડ પર મેનૂ-બાર AI ક્રિયાઓ: સારાંશ, અનુવાદ, પુનર્લેખન. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | ત્વરિત AI ઓવરલે: કી દબાવો, પૂછો, જવાબ મેળવો, બંધ કરો. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | ફૉર્મ્યુલા નોટપેડ - ઓન-ડિવાઇસ AI ઇનલાઇન સેલ ફંક્શન તરીકે. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | નાની ઓન-ડિવાઇસ વિન્ડો માટે ટોકન-બજેટ ઑપ્ટિમાઇઝ્ડ MCP: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI ડીબગ ઇન્સ્પેક્ટર: રિક્વેસ્ટ ટાઇમલાઇન, MCP પ્રોટોકોલ વ્યૂઅર, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` ઉપર સતત MCP રજિસ્ટ્રી + TOML કન્ફિગ ઉમેરતું UNIX રેપર. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | ઓન-ડિવાઇસ કન્ટેન્ટ ટૅગિંગ CLI: ટેક્સ્ટ પાઇપ કરો, ટૅગ/વિષય/ભાવનાઓ મેળવો. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ઇકોસિસ્ટમ ટૂલ માટે Swift package: લોકલ `apfel --serve` શોધો, શરૂ કરો અને તેમાંથી સ્ટ્રીમ કરો. | Swift Package |

## કમ્યુનિટી પ્રોજેક્ટ

apfel ઉપર કંઈક બનાવ્યું છે? એક issue ખોલો અને તે અહીં ઉમેરી શકાય.

| પ્રોજેક્ટ | તે શું કરે છે | લિંક |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | ફાઇલ, કૅલેન્ડર, મેઇલ અને Mac સ્ટેટસ read-only ટૂલથી વાંચતો લોકલ AI એજન્ટ | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-સુસંગત API દ્વારા `apfel --serve` સાથે વાત કરતું બ્રાઉઝર-આધારિત ચેટ UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | નાના Anthropic-OpenAI પ્રૉક્સી દ્વારા apfel ને લોકલ બેકએન્ડ તરીકે બદલતું Claude Code રેપર | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel આસપાસ બનેલી લોકલ શેલ ઍપ માટે ઍપ મેનેજર | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast કમાન્ડ બાર એક્સટેન્શન: પૂછો, અનુવાદ કરો, ફાઇલો અને ડિરેક્ટરી સમજાવો, વાતચીત ઇતિહાસ, કસ્ટમ system prompt. apfel CLI દ્વારા ઓન-ડિવાઇસ. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## યોગદાન

કોઈપણ `Arthur-Ficial/apfel*` રેપો પર issue અને PR આવકાર્ય છે.

**#agentswelcome** - AI એજન્ટના PR ચાલે છે. રેપોની `CLAUDE.md` વાંચો, ટેસ્ટ ચલાવો, `Co-Authored-By` ટ્રેલરમાં ટૂલને શ્રેય આપો. માણસો જેટલું જ ધોરણ: સ્વચ્છ કોડ, પાસ થતા ટેસ્ટ, પ્રામાણિક મર્યાદાઓ. સૌથી એજન્ટ-ફ્રેન્ડલી પ્રવેશબિંદુ: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([યોગદાનના નિયમો](https://apfel-mcp.franzai.com/#contribute)).

## લાઇસન્સ

[MIT](../LICENSE)
