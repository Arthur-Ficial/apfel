<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [انگریزی README](../README.md) سے ترجمہ شدہ۔ انگریزی ورژن ہی مستند ہے۔

# apfel

### آپ کے Mac پر پہلے سے موجود مفت AI۔

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon والے Mac میں [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) کے ذریعے ایک بلٹ اِن LLM آتا ہے۔ `apfel` اسے UNIX ٹول اور مقامی OpenAI-compatible سرور کے طور پر پیش کرتا ہے۔ 100% ڈیوائس پر۔ نہ API keys، نہ کلاؤڈ۔

| موڈ | کمانڈ | آپ کو کیا ملتا ہے |
|------|---------|--------------|
| UNIX ٹول | `apfel "prompt"` / `echo "text" \| apfel` | pipe کے موافق جوابات، فائل اٹیچمنٹ، JSON آؤٹ پٹ، exit codes |
| OpenAI-compatible سرور | `apfel --serve` | OpenAI SDKs کے لیے براہ راست متبادل مقامی `http://localhost:11434/v1` بیک اینڈ |

`apfel --chat` - انٹرایکٹو REPL۔

[![apfel ٹرمینل ڈیمو ویڈیو: اصلی کمانڈز، ڈیوائس پر اصلی جوابات (84 سیکنڈ)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ur/a/apfel-ai-tutorial/#video)

ٹول کالنگ ہر صورت میں کام کرتی ہے۔

![apfel CLI](../screenshots/cli.png)

## تقاضے اور انسٹالیشن

macOS 26 Tahoe یا نیا، Apple Silicon (M1 یا نیا)، [Apple Intelligence فعال](https://support.apple.com/en-us/121115)۔ macOS 27 پر M3 یا نئی چپ اور 12 GB+ والے Mac Apple کا بڑا آن-ڈیوائس ماڈل 8192 ٹوکن کی ونڈو کے ساتھ چلاتے ہیں؛ M1/M2 Mac اور macOS 26 پر ہر Mac میں 4096 ہوتی ہے۔ `apfel --model-info` آپ کے Mac کی قدر دکھاتا ہے۔

```bash
brew install apfel
```

اپ ڈیٹ:

```bash
brew upgrade apfel
```

سورس سے بنائیں (macOS 27 SDK / Swift 6.3 کے ساتھ Command Line Tools، Xcode کے بغیر؛ بائنری macOS 26 اور 27 پر چلتی ہے):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

same-day tap، Mint، mise، مسائل کا حل: [docs/install.md](../docs/install.md)۔

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | **اردو** | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## فوری آغاز

### UNIX ٹول

جن prompts میں `!` ہو انہیں سنگل کوٹس میں لکھیں (zsh/bash کی history expansion): `apfel 'Hello, Mac!'`۔

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

### OpenAI-compatible سرور

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

بیک گراؤنڈ سروس کی تفصیل: [docs/background-service.md](../docs/background-service.md)۔

### فوری ٹیسٹنگ چیٹ

`apfel --chat` ایک چھوٹا REPL ہے جو prompts یا MCP سرورز کو آزمانے کے لیے ہے۔ GUI چیٹ ایپ کے لیے [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) دیکھیں۔

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C سے باہر نکلیں۔ context خود بخود چھانٹا جاتا ہے ([docs/context-strategies.md](../docs/context-strategies.md))۔

اسکرپٹ لکھنے سے پہلے جاننے کے لائق پابندیاں (ہر Mac کی context ونڈو، guardrails، embeddings کا نہ ہونا): [حدود](../README.md#limitations)۔

## ڈیمو

حقیقی shell اسکرپٹس جو `apfel` کو لپیٹتی ہیں: `cmd` (انگریزی سے shell کمانڈ)، `oneliner`، `mac-narrator`، `wtd`، `explain`، `naming`، `port`، `gitsum`۔ یہ بائنری کے اندر شامل ہیں - ریپو clone کرنے کی ضرورت نہیں۔ جہاں سے آپ نے apfel انسٹال کیا (homebrew-core، tap، یا سورس) انہیں وہیں سے لکھ نکالیں:

```bash
apfel demos ./apfel-demos
```

یہ ہر ڈیمو (executable) اور ایک `README.md` کو `./apfel-demos` میں لکھ دیتا ہے۔ پھر انہیں وہیں سے چلائیں:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

`brew upgrade apfel` کے بعد تازہ کرنے کے لیے `apfel demos` دوبارہ چلائیں۔ سورسز: [`demo/`](../demo/)۔ تفصیلی walkthroughs اور آپ کی `.zshrc` کے لیے کاپی-پیسٹ `cmd` shell فنکشن: [docs/demos.md](../docs/demos.md)۔

## MCP ٹول سپورٹ

[Model Context Protocol](https://modelcontextprotocol.io/) سرورز کو `--mcp` کے ساتھ جوڑیں۔ apfel انہیں دریافت کرتا ہے، چلاتا ہے اور نتیجہ لوٹاتا ہے۔

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

ٹول کی معلومات چھپانے کے لیے `-q` استعمال کریں۔

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

ایک calculator ساتھ آتا ہے: [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md))۔

**ریموٹ MCP سرورز** (Streamable HTTP، MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **سیکیورٹی:** `--mcp-token` (ps aux میں نظر آتا ہے) کے بجائے `APFEL_MCP_TOKEN` کو ترجیح دیں۔ apfel سادہ `http://` پر bearer tokens بھیجنے سے انکار کرتا ہے۔

## apfel-run: اختیاری کنفیگ لیئر

خود apfel میں کوئی کنفیگ فائل نہیں - flags اور env vars، جیسے ہر UNIX ٹول میں۔ اگر آپ کو TOML کنفیگ چاہیے (کئی MCPs، پروفائلز، git میں ٹیم کنفیگ)، تو [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) ایک MIT wrapper ہے جو `execve` کے ذریعے براہ راست متبادل کے طور پر یہ سہولت جوڑتا ہے۔

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API مطابقت

**Base URL:** `http://localhost:11434/v1`

| خصوصیت | حالت | نوٹس |
|---------|--------|-------|
| `POST /v1/chat/completions` | سپورٹڈ | streaming + non-streaming |
| `POST /v1/responses` | سپورٹڈ | OpenAI Responses API: string/message ان پٹ، `instructions`، streaming (معیاری event ترتیب)، `text.format` (بشمول `json_schema`)، function tools (non-streaming)۔ stateful خصوصیات (`previous_response_id`، `store: true`، `background`، `reasoning`، hosted tools) ایماندارانہ 501 لوٹاتی ہیں |
| `POST /v1/responses/input_tokens` | سپورٹڈ | ٹوکن preflight (`client.responses.input_tokens.count(...)`): Apple کے tokenizer سے درست گنتی، بغیر generation کے؛ macOS 26.4 سے نیچے اندازے کے بجائے 501۔ دیکھیں [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | سپورٹڈ | `apple-foundationmodel` (عمومی، ڈیفالٹ) اور `apple-foundationmodel-content-tagging` (لیبلز، نثر نہیں) لوٹاتا ہے۔ دیکھیں [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | سپورٹڈ | ماڈل کی دستیابی، context ونڈو، زبانیں، رپورٹ شدہ ماڈل صلاحیتیں (`capabilities`، `capabilities_reported`)، سرو کرنے والا ماڈل ویریئنٹ (`variant`، مثلاً AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | صرف debug | `--debug` درکار ہے |
| ٹول کالنگ | سپورٹڈ | کال guided generation کے ذریعے (`--tool-calling guided`، ڈیفالٹ) یا ایسے JSON کی صورت میں لکھی جاتی ہے جسے سرور پارس کرتا ہے (`--tool-calling text`)۔ دیکھیں [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | سپورٹڈ | system-prompt injection؛ آؤٹ پٹ سے markdown fences ہٹا دیے جاتے ہیں |
| `response_format: json_schema` | سپورٹڈ | FoundationModels کے `DynamicGenerationSchema` کے ذریعے schema کے مطابق آؤٹ پٹ کی ضمانت؛ `stream: true` کے ساتھ کام کرتا ہے |
| `temperature`, `top_p`, `max_tokens`, `seed` | سپورٹڈ | `GenerationOptions` سے map ہوتے ہیں۔ `top_p` nucleus sampling ہے؛ 0.001 سے کم `temperature` (0 سمیت) greedy (deterministic) پر map ہوتا ہے۔ `max_tokens` چھوڑنے پر context ونڈو کا باقی حصہ استعمال ہوتا ہے (براہ راست متبادل OpenAI معنی) - دیکھیں [ڈیفالٹ response حد](../README.md#default-response-cap-max_tokens) |
| `stream: true` | سپورٹڈ | SSE؛ آخری usage chunk صرف تب جب `stream_options: {"include_usage": true}` ہو (OpenAI spec کے مطابق) |
| `usage` | سپورٹڈ | macOS 26.4+ پر اصلی tokenizer گنتی (اس سے نیچے chars/4 کا اندازہ)۔ macOS 27: runtime کا اپنا حساب بشمول Apple کی chat-template فریمنگ (ایک سطری prompt پر تقریباً 46 اضافی `prompt_tokens`)؛ macOS 26: apfel پیغام کے متن کو گنتا ہے۔ تفصیل [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) میں |
| `finish_reason` | سپورٹڈ | `stop`، `tool_calls`، `length` |
| Context حکمت عملیاں | سپورٹڈ | `x_context_strategy`، `x_context_max_turns`، `x_context_output_reserve` توسیعی فیلڈز |
| CORS | سپورٹڈ | `--cors` سے فعال کریں |
| `POST /v1/completions` | 501 | Legacy text completions سپورٹڈ نہیں |
| `POST /v1/embeddings` | 501 | Embeddings آن-ڈیوائس دستیاب نہیں |
| `stop` | سپورٹڈ | ایک string یا زیادہ سے زیادہ 4 strings؛ صرف سادہ متن (ٹولز شامل ہوں یا `json_object`/`json_schema` ہو تو 400)۔ آؤٹ پٹ کی جانب لاگو ہوتا ہے، streaming اور non-streaming میں یکساں۔ دیکھیں [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | واضح طور پر مسترد۔ `n=1` اور `logprobs=false` بے اثر کے طور پر قبول ہیں |
| Multi-modal (تصاویر) | macOS 27 پر سپورٹڈ | base64 data URLs کی شکل میں `image_url` حصے نیٹو طور پر آن-ڈیوائس ماڈل تک جاتے ہیں (20 MB base64 حد، لمبا رخ 4096 px تک چھوٹا کیا جاتا ہے)۔ ریموٹ `http(s)` URLs اور فائل پاتھ ہمیشہ 400 - apfel کبھی تصاویر fetch نہیں کرتا اور کسی HTTP کلائنٹ کے لیے کبھی فائلیں نہیں پڑھتا۔ macOS 26 پر: واضح غلطی کے ساتھ 400۔ دیکھیں [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` ہیڈر | سپورٹڈ | `--token` سیٹ ہو تو لازمی۔ دیکھیں [docs/server-security.md](../docs/server-security.md) |

مکمل API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi)۔

## ڈیفالٹ response حد (`max_tokens`)

جب `max_tokens` چھوڑا جائے تو **CLI اور OpenAI-compatible سرور ایک جیسا برتاؤ کرتے ہیں**: قدر `nil` کے طور پر گزرتی ہے اور ماڈل context ونڈو میں بچی ہوئی جگہ استعمال کرتا ہے۔ یہ براہ راست متبادل OpenAI معنی ہیں - کوئی من مانا fallback مستقل نہیں۔

آن-ڈیوائس context ونڈو ان پٹ *اور* آؤٹ پٹ دونوں کو ملا کر رکھتی ہے: **macOS 26 پر اور M1/M2 Mac پر 4096 ٹوکن، macOS 27 پر M3 یا نئی چپ اور 12 GB+ کے ساتھ 8192 ٹوکن**۔ apfel اصل سائز runtime پر `SystemLanguageModel.contextSize` سے پڑھتا ہے - اپنی قدر `apfel --model-info` سے دیکھیں۔ اگر generation حد سے ٹکرا جائے تو response صفائی سے `finish_reason: "length"` کے ساتھ ختم ہوتا ہے اور ادھورا مواد لوٹایا جاتا ہے (سرور: HTTP 200؛ CLI: exit 0 اور stderr میں انتباہ، یا `--require-complete` کے ساتھ exit 8 - دیکھیں [docs/cli-reference.md](../docs/cli-reference.md))۔ جب آپ کو تنگ latency بجٹ یا اپنے کلائنٹ کے لیے معلوم حد چاہیے تو `max_tokens` صریح طور پر دیں۔

### مثالیں

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

### قدر کا انتخاب

| استعمال                                | `max_tokens`  |
|----------------------------------------|---------------|
| ایک لفظ / classification جواب           | 16 - 32       |
| ایک سطری ہدایت                         | 64 - 128      |
| مختصر پیراگراف                         | 256 - 512     |
| لمبا پیراگراف / structured JSON         | 1024 - 2048   |
| جتنا context ونڈو اجازت دے              | چھوڑ دیں      |

`input_tokens + max_tokens` کو context ونڈو سے آرام سے نیچے رکھیں (macOS 26 پر اور M1/M2 Mac پر 4096 ٹوکن، macOS 27 پر M3 یا نئی چپ اور 12 GB+ کے ساتھ 8192 (Apple کا AFM 3 Core Advanced ماڈل))۔ اگر خود prompt ونڈو سے بڑا ہو تو generation شروع نہیں ہو سکتی اور درخواست `[context overflow]` کے ساتھ ناکام ہوتی ہے (HTTP 400 / CLI exit 4)۔ validator غیر مثبت قدریں (`max_tokens <= 0`) مسترد کرتا ہے۔

### CLI سے ہم آہنگی

CLI اور سرور ایک ہی اصول مشترک رکھتے ہیں: چھوڑا گیا = بچی ہوئی ونڈو استعمال کرو۔ کوئی مستقل نہیں جو الگ ہو جائے۔ `--max-tokens N` یا `APFEL_MAX_TOKENS=N` سے بدلیں۔

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### سرور کے لیے permissive guardrails

`apfel --serve --permissive` سرور کو اس عمل کی سنبھالی **ہر درخواست** کے لیے Apple کے `.permissiveContentTransformations` guardrails استعمال کرواتا ہے۔ وہی flag، وہی معنی جو CLI کے `--permissive` کے ہیں ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))۔ ہر درخواست کے لیے الگ override نہیں ہے - پورے عمل کا فیصلہ سرور چلانے والا کرتا ہے۔

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## حدود

| پابندی | تفصیل |
|------------|--------|
| Context ونڈو | **macOS 26 پر اور M1/M2 Mac پر 4096 ٹوکن، macOS 27 پر M3 یا نئی چپ اور 12 GB+ کے ساتھ 8192 ٹوکن** (ان پٹ + آؤٹ پٹ ملا کر)۔ کوڈ میں لکھا مستقل نہیں - apfel runtime پر `SystemLanguageModel.contextSize` پڑھتا ہے؛ `apfel --model-info` موجودہ قدر چھاپتا ہے |
| پلیٹ فارم | macOS 26+، صرف Apple Silicon |
| ماڈل | ایک آن-ڈیوائس ماڈل (تقریباً 3B پیرامیٹرز)، جو `apple-foundationmodel` (عمومی) اور `apple-foundationmodel-content-tagging` (Apple کا content-tagging اڈاپٹر؛ کوئی ٹول نہیں) کے طور پر دستیاب ہے |
| Guardrails | Apple کا حفاظتی نظام بے ضرر prompts کو بھی روک سکتا ہے۔ `--permissive` جھوٹے مثبت کم کرتا ہے ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| رفتار | آن-ڈیوائس، کلاؤڈ پیمانے کی نہیں - ہر جواب میں چند سیکنڈ |
| Embeddings نہیں | آن-ڈیوائس دستیاب نہیں |
| Vision | تصویری ان پٹ صرف macOS 27 پر ماڈل تک پہنچتا ہے (سرور: data URLs؛ CLI: `-f photo.jpg` اور pipe کی گئی تصاویر، OCR متن کے علاوہ)۔ macOS 26 پر تصاویر OCR/classification کے ذریعے صرف متن کی شکل میں ہوتی ہیں۔ 3B ماڈل کی منظر کی تفصیل موٹی موٹی ہوتی ہے - چھپے ہوئے متن کو پڑھنے کے لیے OCR ہی قابل اعتماد ذریعہ ہے |
| ٹریننگ ڈیٹا / علم کی حد | Apple نے آن-ڈیوائس ماڈل کی کوئی قطعی cutoff تاریخ شائع نہیں کی۔ جب ماڈل پر زور دیا جائے تو وہ **ہر نمونے میں مختلف تاریخ گھڑ لیتا ہے** (مثلاً "October 2023"، "April 2023")۔ ماڈل کی اپنی ٹریننگ کے بارے میں ہر خود بیانی کو ناقابل اعتماد سمجھیں۔ |
| موجودہ تاریخ یا real-time آگاہی نہیں | ماڈل کو آج کی تاریخ معلوم نہیں اور اس کے پاس نیٹ ورک/گھڑی تک رسائی نہیں۔ پوچھنے پر وہ یا تو انکار کرے گا یا تاریخ گھڑ لے گا۔ جب حساب تاریخ پر منحصر ہو تو موجودہ تاریخ system prompt کے ذریعے دیں (نیچے workaround دیکھیں)۔ |

**تاریخ پر منحصر prompts کے لیے workaround** - موجودہ تاریخ کو system پیغام کے طور پر شامل کریں:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

نوٹ: تاریخ شامل کرنے کے باوجود 3B ماڈل پھر بھی hallucinate کر سکتا ہے (خاص طور پر جب اس سے اپنی ٹریننگ cutoff کے بارے میں براہ راست پوچھا جائے)۔ یہ طریقہ ان تخلیقی prompts میں مدد دیتا ہے جو تاریخ *استعمال* کرتے ہیں؛ یہ ماڈل کی خود بیانی کی عادت کو ختم نہیں کرتا۔

پس منظر: [#158](https://github.com/Arthur-Ficial/apfel/issues/158)۔

## حوالہ جاتی دستاویزات

[Python](../docs/guides/python.md)، [Node.js](../docs/guides/nodejs.md)، [Ruby](../docs/guides/ruby.md)، [PHP](../docs/guides/php.md)، [Bash/curl](../docs/guides/bash-curl.md)، [Zsh](../docs/guides/zsh.md)، [AppleScript](../docs/guides/applescript.md)، [Swift](../docs/guides/swift-scripting.md)، [Perl](../docs/guides/perl.md)، [AWK](../docs/guides/awk.md) سے apfel استعمال کرنے کی گائیڈز - دیکھیں [docs/guides/index.md](../docs/guides/index.md)۔ تجربے سے جانچی گئی؛ چلنے والا ثبوت [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) میں۔

- [docs/install.md](../docs/install.md) - انسٹالیشن، مسائل کا حل، اور Apple Intelligence سیٹ اپ
- [docs/cli-reference.md](../docs/cli-reference.md) - ہر flag، exit code، اور ماحولیاتی متغیر
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` اور pipe کیے گئے PDF / تصویر / متن کا اخراج (OCR + تصویر کی تفہیم)
- [docs/background-service.md](../docs/background-service.md) - `brew services` اور launchd کا استعمال
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` سپورٹ میٹرکس تفصیل سے
- [docs/server-security.md](../docs/server-security.md) - origin چیکس، CORS، tokens، اور `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - چیٹ trimming حکمت عملیاں
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - مقامی اور ریموٹ MCP کا استعمال
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ٹول کالنگ کے رویے کی تفصیل
- [docs/integrations.md](../docs/integrations.md) - تھرڈ پارٹی ٹولز کے انضمام (opencode وغیرہ)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code میں apfel + دوسرے edit/apply ماڈل کے ساتھ مقامی review
- [docs/demos.md](../docs/demos.md) - shell ڈیموز کی تفصیلی walkthroughs
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ حقیقی prompts بغیر ترمیم شدہ آؤٹ پٹ کے ساتھ
- [docs/swift-library.md](../docs/swift-library.md) - ڈاؤن اسٹریم ڈویلپرز کے لیے `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel Apple کے نئے Core AI (Core ML کے جانشین) کے بجائے FoundationModels پر کیوں چلتا ہے
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel کا Apple کے اپنے `fm` CLI (macOS 27) سے موازنہ، خصوصیت بہ خصوصیت، ناپے گئے اعداد کے ساتھ

## آرکیٹیکچر

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency۔ تین targets: `ApfelCore` (خالص منطق، unit-test کے قابل، Swift Package پروڈکٹ کے طور پر بھی دستیاب - اوپر حوالہ جاتی دستاویزات میں لنک شدہ)، `apfel` (CLI + سرور)، اور `apfel-tests` (خالص Swift runner، XCTest کے بغیر)۔

## بلڈ اور ٹیسٹ

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

`.version` ہی واحد ماخذ ہے۔ صرف `make release` ورژن بڑھاتا ہے۔ مقامی builds ورژن نہیں بدلتیں۔

## apfel کا درخت

apfel پر بنے پروجیکٹس۔ ہر ایک اپنے ریپو اور Homebrew formula کے ساتھ آتا ہے۔

| پروجیکٹ | کیا کرتا ہے | انسٹال |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | جڑ۔ آن-ڈیوائس FoundationModels CLI + OpenAI-compatible سرور۔ | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS چیٹ کلائنٹ: streaming markdown، آواز کا ان پٹ/آؤٹ پٹ، Apple Vision سے تصویر کا تجزیہ۔ | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | کلپ بورڈ پر menu-bar AI عمل: خلاصہ، ترجمہ، دوبارہ تحریر۔ | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | فوری AI اوور لے: کلید دبائیں، پوچھیں، جواب لیں، بند کریں۔ | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | فارمولا نوٹ پیڈ - آن-ڈیوائس AI بطور inline سیل فنکشن۔ | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | چھوٹی آن-ڈیوائس ونڈو کے لیے ٹوکن بجٹ کے مطابق بنے MCPs: `url-fetch`، `ddg-search`، `search-and-fetch`۔ | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspector: درخواستوں کی ٹائم لائن، MCP پروٹوکول ویور، TTS/STT۔ | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX wrapper جو `apfel` کے اوپر مستقل MCP رجسٹری + TOML کنفیگ جوڑتا ہے۔ | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | آن-ڈیوائس مواد ٹیگنگ CLI: متن pipe کریں، tags/موضوعات/جذبات حاصل کریں۔ | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | ایکو سسٹم ٹولز کے لیے Swift package: مقامی `apfel --serve` کو دریافت کریں، چلائیں اور اس سے stream کریں۔ | Swift Package |

## کمیونٹی پروجیکٹس

apfel کے اوپر کچھ بنایا ہے؟ ایک issue کھولیں تو اسے یہاں شامل کیا جا سکتا ہے۔

| پروجیکٹ | کیا کرتا ہے | لنکس |
|---------|-------------|-------|
| **apfelclaw** از [@julianYaman](https://github.com/julianYaman) | مقامی AI ایجنٹ جو صرف پڑھنے والے ٹولز سے فائلیں، کیلنڈر، میل اور Mac کی حالت پڑھتا ہے | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** از [@bhaskarvilles](https://github.com/bhaskarvilles) | براؤزر پر مبنی چیٹ UI جو OpenAI-compatible API کے ذریعے `apfel --serve` سے بات کرتا ہے | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** از [@lucaspwo](https://github.com/lucaspwo) | Claude Code wrapper جو ایک چھوٹی Anthropic-OpenAI proxy کے ذریعے apfel کو مقامی بیک اینڈ کے طور پر لگاتا ہے | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** از [@hasit](https://github.com/hasit) | apfel کے گرد بنی مقامی shell ایپس کے لیے ایپ مینیجر | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** از [@eggsy](https://github.com/eggsy) | Raycast کمانڈ بار ایکسٹینشن: پوچھیں، ترجمہ کریں، فائلوں اور ڈائریکٹریوں کی وضاحت، گفتگو کی تاریخ، حسب ضرورت system prompts۔ apfel CLI کے ذریعے آن-ڈیوائس۔ | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## شراکت

کسی بھی `Arthur-Ficial/apfel*` ریپو پر issues اور PRs کا خیرمقدم ہے۔

**#agentswelcome** - AI ایجنٹس کے PRs ٹھیک ہیں۔ ریپو کی `CLAUDE.md` پڑھیں، ٹیسٹ چلائیں، اور ٹول کا نام `Co-Authored-By` trailer میں لکھیں۔ معیار انسانوں جیسا ہی ہے: صاف کوڈ، پاس ہوتے ٹیسٹ، ایماندارانہ حدود۔ ایجنٹس کے لیے سب سے موزوں آغاز: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([شراکت کے اصول](https://apfel-mcp.franzai.com/#contribute))۔

## لائسنس

[MIT](../LICENSE)
