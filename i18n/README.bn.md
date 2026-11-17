<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [ইংরেজি README](../README.md) থেকে অনূদিত। ইংরেজি সংস্করণই প্রামাণিক।

# apfel

### আপনার Mac-এ আগে থেকেই থাকা বিনামূল্যের AI।

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac-এ [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels)-এর মাধ্যমে একটি বিল্ট-ইন LLM থাকে। `apfel` সেটিকে UNIX টুল এবং লোকাল OpenAI-compatible সার্ভার হিসেবে উপস্থাপন করে। 100% অন-ডিভাইস। কোনো API key নেই, ক্লাউড নেই।

| মোড | কমান্ড | কী পাবেন |
|------|---------|--------------|
| UNIX টুল | `apfel "prompt"` / `echo "text" \| apfel` | pipe-বান্ধব উত্তর, ফাইল সংযুক্তি, JSON আউটপুট, exit code |
| OpenAI-compatible সার্ভার | `apfel --serve` | OpenAI SDK-র জন্য সরাসরি বদলি হিসেবে লোকাল `http://localhost:11434/v1` ব্যাকএন্ড |

`apfel --chat` - ইন্টারেক্টিভ REPL।

[![apfel টার্মিনাল ডেমো ভিডিও: আসল কমান্ড, ডিভাইসে আসল উত্তর (84 সেকেন্ড)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/bn/a/apfel-ai-tutorial/#video)

Tool calling সব ক্ষেত্রেই কাজ করে।

![apfel CLI](../screenshots/cli.png)

## প্রয়োজনীয়তা ও ইনস্টল

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence চালু](https://support.apple.com/en-us/121115)। macOS 27-এ M3 বা নতুন চিপ এবং 12 GB+ মেমরির Mac Apple-এর বড় অন-ডিভাইস মডেল চালায়, 8192-টোকেনের উইন্ডো সহ; M1/M2 Mac এবং macOS 26-এর প্রতিটি Mac-এ থাকে 4096। `apfel --model-info` আপনার Mac-এর মান দেখায়।

```bash
brew install apfel
```

আপডেট:

```bash
brew upgrade apfel
```

সোর্স থেকে বিল্ড করুন (macOS 27 SDK / Swift 6.3 সহ Command Line Tools, Xcode ছাড়া; বাইনারি macOS 26 ও 27-এ চলে):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, সমস্যা সমাধান: [docs/install.md](../docs/install.md)।

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | **বাংলা** | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## দ্রুত শুরু

### UNIX টুল

যে prompt-এ `!` আছে সেটি single quote-এর মধ্যে লিখুন (zsh/bash history expansion): `apfel 'Hello, Mac!'`।

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

### OpenAI-compatible সার্ভার

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

ব্যাকগ্রাউন্ড সার্ভিসের বিস্তারিত: [docs/background-service.md](../docs/background-service.md)।

### দ্রুত টেস্টিংয়ের চ্যাট

`apfel --chat` হলো prompt বা MCP সার্ভার পরখ করার একটি ছোট REPL। GUI চ্যাট অ্যাপের জন্য [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) দেখুন।

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C দিয়ে বের হন। context নিজে থেকেই ছাঁটা হয় ([docs/context-strategies.md](../docs/context-strategies.md))।

স্ক্রিপ্ট লেখার আগে যে সীমাবদ্ধতাগুলো জানা দরকার (প্রতিটি Mac-এর context উইন্ডো, guardrail, embeddings না থাকা): [সীমাবদ্ধতা](../README.md#limitations)।

## ডেমো

আসল shell স্ক্রিপ্ট যা `apfel`-কে মুড়ে দেয়: `cmd` (ইংরেজি থেকে shell কমান্ড), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`। এগুলো বাইনারির ভেতরেই আছে - রেপো clone করতে হবে না। যেখান থেকে apfel ইনস্টল করেছেন (homebrew-core, tap বা সোর্স), সেখান থেকেই এগুলো লিখে বের করুন:

```bash
apfel demos ./apfel-demos
```

এটি প্রতিটি ডেমো (executable) এবং একটি `README.md` `./apfel-demos`-এ লিখে দেয়। তারপর সেখান থেকে চালান:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

হালনাগাদ করতে `brew upgrade apfel`-এর পরে আবার `apfel demos` চালান। সোর্স: [`demo/`](../demo/)। বিস্তারিত walkthrough এবং আপনার `.zshrc`-এর জন্য কপি-পেস্ট করার মতো `cmd` shell ফাংশন: [docs/demos.md](../docs/demos.md)।

## MCP টুল সাপোর্ট

`--mcp` দিয়ে [Model Context Protocol](https://modelcontextprotocol.io/) সার্ভার যুক্ত করুন। apfel সেগুলো খুঁজে বের করে, চালায় এবং ফলাফল ফেরত দেয়।

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

টুলের তথ্য লুকাতে `-q` ব্যবহার করুন।

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

সঙ্গে একটি calculator আসে: [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md))।

**রিমোট MCP সার্ভার** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **নিরাপত্তা:** `--mcp-token`-এর (ps aux-এ দেখা যায়) বদলে `APFEL_MCP_TOKEN` ব্যবহার করুন। apfel সাধারণ `http://`-এর ওপর bearer token পাঠাতে অস্বীকার করে।

## apfel-run: ঐচ্ছিক কনফিগ স্তর

apfel-এর নিজের কোনো কনফিগ ফাইল নেই - flag আর env var, যেকোনো UNIX টুলের মতো। যদি TOML কনফিগ চান (অনেক MCP, প্রোফাইল, git-এ টিমের কনফিগ), তাহলে [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) একটি MIT wrapper, যা `execve`-র মাধ্যমে সরাসরি বদলি হিসেবে সেটি যোগ করে।

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API সামঞ্জস্য

**Base URL:** `http://localhost:11434/v1`

| ফিচার | অবস্থা | মন্তব্য |
|---------|--------|-------|
| `POST /v1/chat/completions` | সমর্থিত | streaming + non-streaming |
| `POST /v1/responses` | সমর্থিত | OpenAI Responses API: string/message ইনপুট, `instructions`, streaming (আদর্শ event ক্রম), `text.format` (`json_schema` সহ), function tools (non-streaming)। stateful ফিচার (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) সৎভাবে 501 ফেরত দেয় |
| `POST /v1/responses/input_tokens` | সমর্থিত | টোকেন preflight (`client.responses.input_tokens.count(...)`): Apple-এর tokenizer থেকে নির্ভুল গণনা, generation ছাড়া; macOS 26.4-এর নিচে অনুমানের বদলে 501। দেখুন [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | সমর্থিত | `apple-foundationmodel` (সাধারণ, ডিফল্ট) এবং `apple-foundationmodel-content-tagging` (লেবেল, গদ্য নয়) ফেরত দেয়। দেখুন [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | সমর্থিত | মডেলের প্রাপ্যতা, context উইন্ডো, ভাষা, জানানো মডেল সক্ষমতা (`capabilities`, `capabilities_reported`), পরিবেশনকারী মডেল ভ্যারিয়েন্ট (`variant`, যেমন AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | শুধু debug | `--debug` লাগে |
| Tool calling | সমর্থিত | কলটি guided generation-এর মাধ্যমে (`--tool-calling guided`, ডিফল্ট) অথবা সার্ভার পার্স করে এমন JSON হিসেবে (`--tool-calling text`) লেখা হয়। দেখুন [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | সমর্থিত | system-prompt injection; আউটপুট থেকে markdown fence সরিয়ে ফেলা হয় |
| `response_format: json_schema` | সমর্থিত | FoundationModels-এর `DynamicGenerationSchema`-র মাধ্যমে schema-অনুগত আউটপুটের নিশ্চয়তা; `stream: true`-এর সঙ্গে কাজ করে |
| `temperature`, `top_p`, `max_tokens`, `seed` | সমর্থিত | `GenerationOptions`-এ map হয়। `top_p` হলো nucleus sampling; 0.001-এর কম `temperature` (0 সহ) greedy (নির্ণায়ক) হিসেবে map হয়। `max_tokens` বাদ দিলে context উইন্ডোর অবশিষ্টাংশ ব্যবহার হয় (সরাসরি বদলি OpenAI অর্থ) - দেখুন [ডিফল্ট response সীমা](../README.md#default-response-cap-max_tokens) |
| `stream: true` | সমর্থিত | SSE; শেষ usage chunk কেবল তখনই যখন `stream_options: {"include_usage": true}` থাকে (OpenAI spec অনুযায়ী) |
| `usage` | সমর্থিত | macOS 26.4+-এ আসল tokenizer গণনা (এর নিচে chars/4 অনুমান)। macOS 27: runtime-এর নিজস্ব হিসাব, Apple-এর chat-template ফ্রেমিং সহ (এক লাইনের prompt-এ প্রায় 46টি বাড়তি `prompt_tokens`); macOS 26: apfel বার্তার টেক্সট গোনে। বিস্তারিত [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md)-এ |
| `finish_reason` | সমর্থিত | `stop`, `tool_calls`, `length` |
| Context কৌশল | সমর্থিত | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` এক্সটেনশন ফিল্ড |
| CORS | সমর্থিত | `--cors` দিয়ে চালু করুন |
| `POST /v1/completions` | 501 | Legacy text completions সমর্থিত নয় |
| `POST /v1/embeddings` | 501 | Embeddings অন-ডিভাইসে নেই |
| `stop` | সমর্থিত | একটি string বা সর্বোচ্চ 4টি string; শুধু সাদা টেক্সট (tools থাকলে বা `json_object`/`json_schema` হলে 400)। আউটপুটের দিকে প্রয়োগ হয়, streaming ও non-streaming-এ একই। দেখুন [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | স্পষ্টভাবে প্রত্যাখ্যাত। `n=1` এবং `logprobs=false` কোনো প্রভাব ছাড়া গ্রহণ করা হয় |
| Multi-modal (ছবি) | macOS 27-এ সমর্থিত | base64 data URL হিসেবে `image_url` অংশ সরাসরি অন-ডিভাইস মডেলে যায় (20 MB base64 সীমা, দীর্ঘ দিক 4096 px-এ ছোট করা হয়)। রিমোট `http(s)` URL এবং ফাইল পাথ সবসময় 400 - apfel কখনো ছবি fetch করে না এবং কোনো HTTP ক্লায়েন্টের জন্য কখনো ফাইল পড়ে না। macOS 26-এ: স্পষ্ট ত্রুটি সহ 400। দেখুন [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` হেডার | সমর্থিত | `--token` সেট থাকলে বাধ্যতামূলক। দেখুন [docs/server-security.md](../docs/server-security.md) |

সম্পূর্ণ API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi)।

## ডিফল্ট response সীমা (`max_tokens`)

`max_tokens` বাদ দিলে **CLI এবং OpenAI-compatible সার্ভার একই আচরণ করে**: মানটি `nil` হিসেবে চলে যায় এবং মডেল context উইন্ডোতে যতটুকু জায়গা বাকি আছে ততটুকু ব্যবহার করে। এটি সরাসরি বদলি OpenAI অর্থ - কোনো খেয়ালখুশি fallback ধ্রুবক নেই।

অন-ডিভাইস context উইন্ডোতে ইনপুট *এবং* আউটপুট একসঙ্গে ধরে: **macOS 26-এ এবং M1/M2 Mac-এ 4096 টোকেন, macOS 27-এ M3 বা নতুন চিপ ও 12 GB+ সহ 8192 টোকেন**। apfel আসল আকার runtime-এ `SystemLanguageModel.contextSize` থেকে পড়ে - আপনারটি `apfel --model-info` দিয়ে দেখুন। generation সীমায় পৌঁছালে response পরিচ্ছন্নভাবে `finish_reason: "length"` দিয়ে শেষ হয় এবং আংশিক কনটেন্ট ফেরত দেওয়া হয় (সার্ভার: HTTP 200; CLI: exit 0 এবং stderr-এ সতর্কবার্তা, অথবা `--require-complete` দিলে exit 8 - দেখুন [docs/cli-reference.md](../docs/cli-reference.md))। কড়া latency বাজেট বা আপনার ক্লায়েন্টের জন্য জানা সীমা চাইলে `max_tokens` স্পষ্টভাবে দিন।

### উদাহরণ

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

### মান বেছে নেওয়া

| ব্যবহার                                | `max_tokens`  |
|----------------------------------------|---------------|
| এক শব্দ / classification উত্তর          | 16 - 32       |
| এক লাইনের নির্দেশ                      | 64 - 128      |
| ছোট অনুচ্ছেদ                           | 256 - 512     |
| দীর্ঘ অনুচ্ছেদ / structured JSON        | 1024 - 2048   |
| context উইন্ডো যতটা অনুমতি দেয়          | বাদ দিন        |

`input_tokens + max_tokens` context উইন্ডোর বেশ নিচে রাখুন (macOS 26-এ এবং M1/M2 Mac-এ 4096 টোকেন, macOS 27-এ M3 বা নতুন চিপ ও 12 GB+ সহ 8192 (Apple-এর AFM 3 Core Advanced মডেল))। prompt নিজেই উইন্ডো ছাড়িয়ে গেলে generation শুরু হতে পারে না এবং অনুরোধ `[context overflow]` দিয়ে ব্যর্থ হয় (HTTP 400 / CLI exit 4)। validator অ-ধনাত্মক মান (`max_tokens <= 0`) প্রত্যাখ্যান করে।

### CLI-র সঙ্গে সমতা

CLI ও সার্ভার একই নিয়ম মানে: বাদ দেওয়া = অবশিষ্ট উইন্ডো ব্যবহার করো। সরে যাওয়ার মতো কোনো ধ্রুবক নেই। `--max-tokens N` বা `APFEL_MAX_TOKENS=N` দিয়ে বদলান।

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### সার্ভারের জন্য permissive guardrail

`apfel --serve --permissive` সার্ভারকে সেই প্রসেসের সামলানো **প্রতিটি অনুরোধের** জন্য Apple-এর `.permissiveContentTransformations` guardrail ব্যবহার করায়। একই flag, CLI-র `--permissive`-এর মতো একই অর্থ ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))। অনুরোধ-ভিত্তিক কোনো override নেই - পুরো প্রসেসের সিদ্ধান্ত সার্ভার চালনাকারী নেন।

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## সীমাবদ্ধতা

| সীমাবদ্ধতা | বিবরণ |
|------------|--------|
| Context উইন্ডো | **macOS 26-এ এবং M1/M2 Mac-এ 4096 টোকেন, macOS 27-এ M3 বা নতুন চিপ ও 12 GB+ সহ 8192 টোকেন** (ইনপুট + আউটপুট মিলিয়ে)। কোডে বসানো ধ্রুবক নয় - apfel runtime-এ `SystemLanguageModel.contextSize` পড়ে; `apfel --model-info` বর্তমান মান ছাপে |
| প্ল্যাটফর্ম | macOS 26+, শুধু Apple Silicon |
| মডেল | একটি অন-ডিভাইস মডেল (প্রায় 3B প্যারামিটার), `apple-foundationmodel` (সাধারণ) এবং `apple-foundationmodel-content-tagging` (Apple-এর content-tagging অ্যাডাপ্টার; টুল নেই) নামে পরিবেশিত |
| Guardrail | Apple-এর নিরাপত্তা ব্যবস্থা নিরীহ prompt-ও আটকে দিতে পারে। `--permissive` ভুল শনাক্তকরণ কমায় ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| গতি | অন-ডিভাইস, ক্লাউড স্কেলের নয় - প্রতিটি উত্তরে কয়েক সেকেন্ড |
| Embeddings নেই | অন-ডিভাইসে নেই |
| Vision | ছবির ইনপুট শুধু macOS 27-এ মডেলে পৌঁছায় (সার্ভার: data URL; CLI: `-f photo.jpg` এবং pipe করা ছবি, OCR টেক্সটের পাশাপাশি)। macOS 26-এ ছবি OCR/classification-এর মাধ্যমে কেবল টেক্সট রূপে থাকে। 3B মডেলের দৃশ্য-বর্ণনা মোটামুটি - ছাপা লেখা পড়ার জন্য OCR-ই নির্ভরযোগ্য পথ |
| ট্রেনিং ডেটা / জ্ঞানের সীমা | Apple অন-ডিভাইস মডেলের নির্দিষ্ট cutoff তারিখ প্রকাশ করেনি। চাপ দিলে মডেল **প্রতিটি নমুনায় আলাদা তারিখ বানিয়ে বলে** (যেমন "October 2023", "April 2023")। মডেলের নিজের ট্রেনিং সম্পর্কে দেওয়া যেকোনো তথ্য অনির্ভরযোগ্য ধরুন। |
| বর্তমান তারিখ বা real-time সচেতনতা নেই | মডেল আজকের তারিখ জানে না এবং নেটওয়ার্ক/ঘড়িতে তার প্রবেশাধিকার নেই। জিজ্ঞেস করলে সে হয় অস্বীকার করবে, নয়তো তারিখ বানাবে। হিসাব তারিখের ওপর নির্ভর করলে system prompt দিয়ে বর্তমান তারিখ ঢুকিয়ে দিন (নিচের workaround দেখুন)। |

**তারিখ-নির্ভর prompt-এর জন্য workaround** - বর্তমান তারিখ system বার্তা হিসেবে ঢুকিয়ে দিন:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

লক্ষ্য করুন: তারিখ ঢোকানোর পরও 3B মডেল hallucinate করতে পারে (বিশেষ করে নিজের ট্রেনিং cutoff সম্পর্কে সরাসরি জিজ্ঞেস করলে)। এই কৌশল সেই generative prompt-এ সাহায্য করে যা তারিখ *ব্যবহার* করে; মডেলের নিজের সম্পর্কে বলার অভ্যাস এতে বদলায় না।

প্রেক্ষাপট: [#158](https://github.com/Arthur-Ficial/apfel/issues/158)।

## রেফারেন্স ডকুমেন্ট

[Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) থেকে apfel ব্যবহারের গাইড - দেখুন [docs/guides/index.md](../docs/guides/index.md)। হাতেকলমে পরীক্ষিত; চালানোর মতো প্রমাণ [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab)-এ।

- [docs/install.md](../docs/install.md) - ইনস্টল, সমস্যা সমাধান এবং Apple Intelligence সেটআপ
- [docs/cli-reference.md](../docs/cli-reference.md) - প্রতিটি flag, exit code এবং এনভায়রনমেন্ট ভেরিয়েবল
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` এবং pipe করা PDF / ছবি / টেক্সট থেকে তথ্য নিষ্কাশন (OCR + ছবি বোঝা)
- [docs/background-service.md](../docs/background-service.md) - `brew services` এবং launchd ব্যবহার
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` সাপোর্ট ম্যাট্রিক্স বিস্তারিত
- [docs/server-security.md](../docs/server-security.md) - origin যাচাই, CORS, token এবং `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - চ্যাট trimming কৌশল
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - লোকাল ও রিমোট MCP ব্যবহার
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - tool calling আচরণের বিস্তারিত
- [docs/integrations.md](../docs/integrations.md) - তৃতীয় পক্ষের টুলের সঙ্গে ইন্টিগ্রেশন (opencode ইত্যাদি)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code-এ apfel + দ্বিতীয় edit/apply মডেল দিয়ে লোকাল review
- [docs/demos.md](../docs/demos.md) - shell ডেমোর দীর্ঘ walkthrough
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - সম্পাদনাহীন আউটপুট সহ 50+ আসল prompt
- [docs/swift-library.md](../docs/swift-library.md) - ডাউনস্ট্রিম ডেভেলপারদের জন্য `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel কেন Apple-এর নতুন Core AI (Core ML-এর উত্তরসূরি) নয়, FoundationModels-এ চলে
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel-এর সঙ্গে Apple-এর নিজস্ব `fm` CLI (macOS 27)-এর তুলনা, ফিচার ধরে ধরে, মাপা সংখ্যা সহ

## আর্কিটেকচার

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency। তিনটি target: `ApfelCore` (বিশুদ্ধ লজিক, unit-test করা যায়, Swift Package প্রোডাক্ট হিসেবেও পাওয়া যায় - উপরে রেফারেন্স ডকুমেন্টে লিংক দেওয়া), `apfel` (CLI + সার্ভার), এবং `apfel-tests` (বিশুদ্ধ Swift runner, XCTest ছাড়া)।

## বিল্ড ও টেস্ট

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

`.version` হলো একমাত্র উৎস। শুধু `make release` সংস্করণ বাড়ায়। লোকাল build সংস্করণ বদলায় না।

## apfel-এর বৃক্ষ

apfel-এর ওপর গড়া প্রজেক্ট। প্রতিটি নিজের রেপো ও Homebrew formula নিয়ে আসে।

| প্রজেক্ট | কী করে | ইনস্টল |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | মূল। অন-ডিভাইস FoundationModels CLI + OpenAI-compatible সার্ভার। | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS চ্যাট ক্লায়েন্ট: streaming markdown, কণ্ঠস্বর ইনপুট/আউটপুট, Apple Vision দিয়ে ছবি বিশ্লেষণ। | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ক্লিপবোর্ডে menu-bar AI কাজ: সারসংক্ষেপ, অনুবাদ, পুনর্লিখন। | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | তাৎক্ষণিক AI ওভারলে: কী চাপুন, জিজ্ঞেস করুন, উত্তর পান, বন্ধ করুন। | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | সূত্র-ভিত্তিক নোটপ্যাড - অন-ডিভাইস AI ইনলাইন সেল ফাংশন হিসেবে। | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | ছোট অন-ডিভাইস উইন্ডোর জন্য টোকেন-বাজেট অনুযায়ী তৈরি MCP: `url-fetch`, `ddg-search`, `search-and-fetch`। | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspector: অনুরোধের টাইমলাইন, MCP প্রোটোকল ভিউয়ার, TTS/STT। | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX wrapper যা `apfel`-এর ওপরে স্থায়ী MCP রেজিস্ট্রি + TOML কনফিগ যোগ করে। | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | অন-ডিভাইস কনটেন্ট ট্যাগিং CLI: টেক্সট pipe করুন, tag/বিষয়/আবেগ পান। | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ইকোসিস্টেম টুলের জন্য Swift package: লোকাল `apfel --serve` খুঁজে বের করুন, চালু করুন এবং তা থেকে stream করুন। | Swift Package |

## কমিউনিটি প্রজেক্ট

apfel-এর ওপর কিছু বানিয়েছেন? একটি issue খুলুন, এখানে যোগ করা যেতে পারে।

| প্রজেক্ট | কী করে | লিংক |
|---------|-------------|-------|
| **apfelclaw**, [@julianYaman](https://github.com/julianYaman)-এর তৈরি | লোকাল AI এজেন্ট যা শুধু-পড়ার টুল দিয়ে ফাইল, ক্যালেন্ডার, মেল এবং Mac-এর অবস্থা পড়ে | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, [@bhaskarvilles](https://github.com/bhaskarvilles)-এর তৈরি | ব্রাউজার-ভিত্তিক চ্যাট UI যা OpenAI-compatible API দিয়ে `apfel --serve`-এর সঙ্গে কথা বলে | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, [@lucaspwo](https://github.com/lucaspwo)-এর তৈরি | Claude Code wrapper যা ছোট একটি Anthropic-OpenAI proxy-র মাধ্যমে apfel-কে লোকাল ব্যাকএন্ড হিসেবে বসায় | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, [@hasit](https://github.com/hasit)-এর তৈরি | apfel-কে ঘিরে তৈরি লোকাল shell অ্যাপের জন্য অ্যাপ ম্যানেজার | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, [@eggsy](https://github.com/eggsy)-এর তৈরি | Raycast কমান্ড বার এক্সটেনশন: জিজ্ঞেস করুন, অনুবাদ করুন, ফাইল ও ডিরেক্টরি ব্যাখ্যা, কথোপকথনের ইতিহাস, কাস্টম system prompt। apfel CLI-র মাধ্যমে অন-ডিভাইস। | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## অবদান

যেকোনো `Arthur-Ficial/apfel*` রেপোতে issue ও PR স্বাগত।

**#agentswelcome** - AI এজেন্টের PR চলবে। রেপোর `CLAUDE.md` পড়ুন, টেস্ট চালান, এবং `Co-Authored-By` trailer-এ টুলের নাম উল্লেখ করুন। মান মানুষের মতোই: পরিচ্ছন্ন কোড, পাস করা টেস্ট, সৎ সীমাবদ্ধতা। এজেন্টদের জন্য সবচেয়ে সহজ শুরু: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([অবদানের নিয়ম](https://apfel-mcp.franzai.com/#contribute))।

## লাইসেন্স

[MIT](../LICENSE)
