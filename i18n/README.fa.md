<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> ترجمه از [README انگلیسی](../README.md). نسخه انگلیسی مرجع اصلی است.

# apfel

### هوش مصنوعی رایگان، از قبل روی مک شما.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

مک‌های دارای تراشه Apple Silicon یک LLM داخلی را از طریق [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) همراه خود دارند. `apfel` آن را به شکل یک ابزار UNIX و یک سرور محلی سازگار با OpenAI در اختیار شما می‌گذارد. 100% روی خود دستگاه. بدون کلید API، بدون ابر.

| حالت | دستور | آنچه به دست می‌آورید |
|------|---------|--------------|
| ابزار UNIX | `apfel "prompt"` / `echo "text" \| apfel` | پاسخ‌های سازگار با pipe، پیوست فایل، خروجی JSON، کدهای خروج |
| سرور سازگار با OpenAI | `apfel --serve` | جایگزین مستقیم و محلی `http://localhost:11434/v1` برای SDKهای OpenAI |

`apfel --chat` - REPL تعاملی.

فراخوانی ابزار (tool calling) در همه حالت‌ها کار می‌کند.

![apfel CLI](../screenshots/cli.png)

## پیش‌نیازها و نصب

macOS 26 Tahoe یا بالاتر، Apple Silicon (M1 به بعد)، [Apple Intelligence فعال](https://support.apple.com/en-us/121115). روی macOS 27، مک‌هایی با تراشه M3 یا جدیدتر و حداقل 12 GB حافظه، مدل بزرگ‌تر آن Apple را روی دستگاه با پنجره 8192 توکنی اجرا می‌کنند؛ مک‌های M1/M2 و هر مکی با macOS 26 پنجره 4096 توکنی دارند. دستور `apfel --model-info` مقدار مک شما را نشان می‌دهد.

```bash
brew install apfel
```

به‌روزرسانی:

```bash
brew upgrade apfel
```

ساخت از روی سورس (Command Line Tools همراه SDK مربوط به macOS 27 / Swift 6.3، بدون Xcode؛ فایل اجرایی روی macOS 26 و 27 کار می‌کند):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix، tap همان‌روزه، Mint، mise و عیب‌یابی: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | **فارسی** | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## شروع سریع

### ابزار UNIX

prompt‌هایی را که `!` دارند داخل کوتیشن تکی بگذارید (گسترش تاریخچه در zsh/bash): `apfel 'Hello, Mac!'`.

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

### سرور سازگار با OpenAI

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

جزئیات سرویس پس‌زمینه: [docs/background-service.md](../docs/background-service.md).

### چت برای آزمایش سریع

`apfel --chat` یک REPL کوچک برای آزمایش prompt‌ها یا سرورهای MCP است. برای یک برنامه چت گرافیکی، [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) را ببینید.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

با Ctrl-C خارج می‌شوید. زمینه (context) به‌طور خودکار کوتاه می‌شود ([docs/context-strategies.md](../docs/context-strategies.md)).

محدودیت‌هایی که پیش از اسکریپت‌نویسی روی آن باید بدانید (پنجره context در هر مک، guardrailها، نبود embeddings): [محدودیت‌ها](../README.md#limitations).

## نمونه‌ها

اسکریپت‌های شل واقعی که `apfel` را در بر می‌گیرند: `cmd` (تبدیل انگلیسی به دستور شل)، `oneliner`، `mac-narrator`، `wtd`، `explain`، `naming`، `port`، `gitsum`. آن‌ها داخل فایل اجرایی گنجانده شده‌اند و نیازی به clone کردن مخزن نیست. آن‌ها را از هر کانالی که apfel را نصب کرده‌اید (homebrew-core، tap یا سورس) بیرون بنویسید:

```bash
apfel demos ./apfel-demos
```

این دستور همه نمونه‌ها (اجرایی) به‌علاوه یک `README.md` را در `./apfel-demos` می‌نویسد. سپس از همان‌جا اجرایشان کنید:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

پس از `brew upgrade apfel` دوباره `apfel demos` را اجرا کنید تا به‌روز شوند. سورس‌ها: [`demo/`](../demo/). راهنمای گام‌به‌گام و یک تابع شل `cmd` آماده کپی برای `.zshrc` شما: [docs/demos.md](../docs/demos.md).

## پشتیبانی از ابزارهای MCP

سرورهای [Model Context Protocol](https://modelcontextprotocol.io/) را با `--mcp` متصل کنید. apfel ابزارها را کشف می‌کند، فراخوانی می‌کند و نتیجه را برمی‌گرداند.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

برای پنهان کردن اطلاعات ابزار از `-q` استفاده کنید.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

یک ماشین‌حساب همراه برنامه ارائه می‌شود: [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**سرورهای MCP راه دور** (Streamable HTTP، مشخصات MCP نسخه 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **امنیت:** `APFEL_MCP_TOKEN` را به `--mcp-token` ترجیح دهید (در ps aux دیده می‌شود). apfel از ارسال bearer token روی `http://` ساده خودداری می‌کند.

## apfel-run: لایه پیکربندی اختیاری

خود apfel فایل پیکربندی ندارد؛ فقط flag و متغیر محیطی، مثل هر ابزار UNIX دیگر. اگر پیکربندی TOML می‌خواهید (چندین MCP، پروفایل، پیکربندی تیمی در git)، [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) یک wrapper با مجوز MIT است که آن را از طریق جایگزینی مستقیم با `execve` اضافه می‌کند.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## سازگاری با API ‏OpenAI

**Base URL:** `http://localhost:11434/v1`

| ویژگی | وضعیت | توضیحات |
|---------|--------|-------|
| `POST /v1/chat/completions` | پشتیبانی می‌شود | streaming و غیر streaming |
| `POST /v1/responses` | پشتیبانی می‌شود | OpenAI Responses API: ورودی رشته/پیام، `instructions`، streaming (توالی رویداد استاندارد)، `text.format` (از جمله `json_schema`)، ابزارهای تابعی (غیر streaming). ویژگی‌های stateful ‏(`previous_response_id`، `store: true`، `background`، `reasoning`، ابزارهای hosted) پاسخ صادقانه 501 برمی‌گردانند |
| `POST /v1/responses/input_tokens` | پشتیبانی می‌شود | پیش‌بررسی توکن (`client.responses.input_tokens.count(...)`): شمارش دقیق با tokenizer اپل، بدون تولید متن؛ زیر macOS 26.4 به‌جای تخمین، 501 برمی‌گرداند. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) را ببینید |
| `GET /v1/models` | پشتیبانی می‌شود | `apple-foundationmodel` را برمی‌گرداند |
| `GET /health` | پشتیبانی می‌شود | دسترس‌پذیری مدل، پنجره context، زبان‌ها، قابلیت‌های گزارش‌شده مدل (`capabilities`، `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | فقط اشکال‌زدایی | به `--debug` نیاز دارد |
| فراخوانی ابزار | پشتیبانی می‌شود | `ToolDefinition` بومی + تشخیص JSON. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) را ببینید |
| `response_format: json_object` | پشتیبانی می‌شود | تزریق در system prompt؛ حصارهای markdown از خروجی حذف می‌شوند |
| `response_format: json_schema` | پشتیبانی می‌شود | خروجی تضمین‌شده منطبق بر schema از طریق `DynamicGenerationSchema` در FoundationModels؛ با `stream: true` کار می‌کند |
| `temperature`, `top_p`, `max_tokens`, `seed` | پشتیبانی می‌شود | به `GenerationOptions` نگاشت می‌شوند. `top_p` نمونه‌برداری nucleus است؛ `temperature` کمتر از 0.001 (از جمله 0) به greedy (قطعی) نگاشت می‌شود. با حذف `max_tokens` از باقی‌مانده پنجره context استفاده می‌شود (معنای جایگزین مستقیم OpenAI) - [سقف پیش‌فرض پاسخ](../README.md#default-response-cap-max_tokens) را ببینید |
| `stream: true` | پشتیبانی می‌شود | SSE؛ تکه نهایی usage فقط وقتی `stream_options: {"include_usage": true}` باشد (طبق مشخصات OpenAI) |
| `usage` | پشتیبانی می‌شود | شمارش واقعی tokenizer روی macOS 26.4 و بالاتر (زیر آن تخمین chars/4). macOS 27: حسابداری خود runtime شامل قالب‌بندی chat-template اپل (حدود 46 `prompt_tokens` اضافه برای یک prompt تک‌خطی)؛ macOS 26: apfel متن پیام را می‌شمارد. جزئیات در [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | پشتیبانی می‌شود | `stop`، `tool_calls`، `length` |
| راهبردهای context | پشتیبانی می‌شود | فیلدهای افزونه `x_context_strategy`، `x_context_max_turns`، `x_context_output_reserve` |
| CORS | پشتیبانی می‌شود | با `--cors` فعال کنید |
| `POST /v1/completions` | 501 | تکمیل متن قدیمی (legacy) پشتیبانی نمی‌شود |
| `POST /v1/embeddings` | 501 | embeddings روی دستگاه در دسترس نیست |
| `stop` | پشتیبانی می‌شود | یک رشته یا حداکثر 4 رشته؛ فقط متن ساده (400 وقتی ابزارها در دامنه باشند یا با `json_object`/`json_schema`). در سمت خروجی اعمال می‌شود، یکسان در streaming و غیر streaming. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) را ببینید |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | صریحاً رد می‌شوند. `n=1` و `logprobs=false` به‌عنوان بدون اثر پذیرفته می‌شوند |
| چندوجهی (تصاویر) | روی macOS 27 پشتیبانی می‌شود | بخش‌های `image_url` به شکل data URL با base64 مستقیماً به مدل روی دستگاه می‌رسند (سقف 20 MB برای base64، ضلع بلندتر تا 4096 px کوچک می‌شود). URLهای راه دور `http(s)` و مسیرهای فایل همیشه 400 می‌گیرند - apfel هرگز تصویر دریافت نمی‌کند و هرگز برای یک کلاینت HTTP فایل نمی‌خواند. روی macOS 26: خطای 400 با پیام روشن. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) را ببینید |
| هدر `Authorization` | پشتیبانی می‌شود | با تنظیم `--token` الزامی است. [docs/server-security.md](../docs/server-security.md) را ببینید |

مشخصات کامل API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## سقف پیش‌فرض پاسخ (`max_tokens`)

وقتی `max_tokens` حذف شود، **CLI و سرور سازگار با OpenAI رفتار یکسانی دارند**: مقدار به شکل `nil` عبور می‌کند و مدل از هر مقدار جای باقی‌مانده در پنجره context استفاده می‌کند. این همان معنای جایگزین مستقیم OpenAI است - بدون مقدار ثابت دلخواه.

پنجره context روی دستگاه، ورودی *و* خروجی را با هم در خود جای می‌دهد: **4096 توکن روی macOS 26 و روی مک‌های M1/M2، و 8192 توکن روی macOS 27 با تراشه M3 یا جدیدتر و حداقل 12 GB**. apfel اندازه واقعی را در زمان اجرا از `SystemLanguageModel.contextSize` می‌خواند - مقدار مک خود را با `apfel --model-info` بررسی کنید. اگر تولید متن به سقف برسد، پاسخ به‌صورت تمیز با `finish_reason: "length"` پایان می‌یابد و محتوای ناقص برگردانده می‌شود (سرور: HTTP 200؛ CLI: خروج 0 با هشدار در stderr، یا خروج 8 با `--require-complete` - [docs/cli-reference.md](../docs/cli-reference.md) را ببینید). اگر بودجه تأخیر محدودتری می‌خواهید یا سقف مشخصی برای کلاینت خود لازم دارید، `max_tokens` را صریحاً بدهید.

### مثال‌ها

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

### انتخاب مقدار

| کاربرد                                 | `max_tokens`  |
|----------------------------------------|---------------|
| پاسخ تک‌کلمه‌ای / دسته‌بندی             | 16 - 32       |
| دستور یک‌خطی                           | 64 - 128      |
| پاراگراف کوتاه                         | 256 - 512     |
| پاراگراف بلند / JSON ساختاریافته        | 1024 - 2048   |
| تا هر اندازه که پنجره context اجازه دهد | حذفش کنید     |

`input_tokens + max_tokens` را با فاصله مطمئن زیر پنجره context نگه دارید (4096 توکن روی macOS 26 و روی مک‌های M1/M2، و 8192 روی macOS 27 با تراشه M3 یا جدیدتر و حداقل 12 GB (مدل AFM 3 Core Advanced اپل)). اگر خود prompt از پنجره بزرگ‌تر باشد، تولید متن شروع نمی‌شود و درخواست با `[context overflow]` شکست می‌خورد (HTTP 400 / خروج 4 در CLI). اعتبارسنج مقادیر غیرمثبت (`max_tokens <= 0`) را رد می‌کند.

### هم‌ارزی با CLI

CLI و سرور یک قاعده مشترک دارند: حذف‌شده = استفاده از باقی‌مانده پنجره. هیچ مقدار ثابتی برای انحراف وجود ندارد. با `--max-tokens N` یا `APFEL_MAX_TOKENS=N` بازنویسی کنید.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### guardrailهای آزادتر برای سرور

`apfel --serve --permissive` باعث می‌شود سرور برای **هر درخواستی** که پردازش می‌کند از guardrailهای `.permissiveContentTransformations` اپل استفاده کند. همان flag، همان معنا مثل `--permissive` در CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). بازنویسی برای هر درخواست وجود ندارد - مسئول سرور برای کل فرایند تصمیم می‌گیرد.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## محدودیت‌ها

| محدودیت | جزئیات |
|------------|--------|
| پنجره context | **4096 توکن روی macOS 26 و روی مک‌های M1/M2، 8192 توکن روی macOS 27 با تراشه M3 یا جدیدتر و حداقل 12 GB** (ورودی + خروجی با هم). مقدار ثابت درون کد نیست - apfel در زمان اجرا `SystemLanguageModel.contextSize` را می‌خواند؛ `apfel --model-info` مقدار زنده را چاپ می‌کند |
| پلتفرم | macOS 26 به بعد، فقط Apple Silicon |
| مدل | یک مدل (`apple-foundationmodel`، حدود 3B پارامتر روی دستگاه)، قابل پیکربندی نیست |
| Guardrailها | سامانه ایمنی اپل ممکن است prompt‌های بی‌ضرر را مسدود کند. `--permissive` موارد مثبت کاذب را کم می‌کند ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| سرعت | روی دستگاه، نه در مقیاس ابر - چند ثانیه برای هر پاسخ |
| بدون embeddings | روی دستگاه در دسترس نیست |
| بینایی | ورودی تصویر فقط روی macOS 27 به مدل می‌رسد (سرور: data URLها؛ CLI: `-f photo.jpg` و تصاویر pipe‌شده، علاوه بر متن OCR). روی macOS 26 تصاویر فقط به شکل متنی از طریق OCR/دسته‌بندی در دسترس‌اند. توصیف صحنه توسط مدل 3B تقریبی است - برای خواندن متن چاپی، OCR کانال قابل اتکا می‌ماند |
| داده‌های آموزشی / تاریخ قطع دانش | اپل تاریخ دقیق قطع دانش مدل روی دستگاه را منتشر نکرده است. وقتی مدل را برای گفتن آن تحت فشار بگذارید، **در هر نمونه تاریخ متفاوتی می‌سازد** (مثلاً «October 2023»، «April 2023»). همه خوداظهاری‌های مدل درباره آموزش خودش را غیرقابل اعتماد بدانید. |
| بدون تاریخ جاری یا آگاهی لحظه‌ای | مدل تاریخ امروز را نمی‌داند و به شبکه/ساعت دسترسی ندارد. اگر بپرسید، یا امتناع می‌کند یا تاریخی می‌سازد. وقتی محاسبه به تاریخ وابسته است، تاریخ جاری را با system prompt تزریق کنید (راه‌حل را در ادامه ببینید). |

**راه‌حل برای prompt‌های وابسته به تاریخ** - تاریخ جاری را به‌عنوان پیام سیستمی تزریق کنید:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

توجه: حتی با تاریخ تزریق‌شده، مدل 3B همچنان می‌تواند توهم بزند (به‌ویژه وقتی مستقیم درباره تاریخ قطع آموزش خودش پرسیده شود). تزریق به prompt‌های تولیدی که از تاریخ *استفاده می‌کنند* کمک می‌کند؛ بازتاب خوداظهاری مدل را از بین نمی‌برد.

پیشینه: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## مستندات مرجع

راهنمای استفاده از apfel با [Python](../docs/guides/python.md)، [Node.js](../docs/guides/nodejs.md)، [Ruby](../docs/guides/ruby.md)، [PHP](../docs/guides/php.md)، [Bash/curl](../docs/guides/bash-curl.md)، [Zsh](../docs/guides/zsh.md)، [AppleScript](../docs/guides/applescript.md)، [Swift](../docs/guides/swift-scripting.md)، [Perl](../docs/guides/perl.md)، [AWK](../docs/guides/awk.md) - [docs/guides/index.md](../docs/guides/index.md) را ببینید. به‌صورت تجربی آزمایش شده؛ اثبات قابل اجرا در [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - نصب، عیب‌یابی و راه‌اندازی Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - همه flagها، کدهای خروج و متغیرهای محیطی
- [docs/file-extraction.md](../docs/file-extraction.md) - استخراج PDF / تصویر / متن با `-f` و pipe (OCR + درک تصویر)
- [docs/background-service.md](../docs/background-service.md) - استفاده از `brew services` و launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - ماتریس پشتیبانی `/v1/*` به‌طور مفصل
- [docs/server-security.md](../docs/server-security.md) - بررسی origin، CORS، توکن‌ها و `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - راهبردهای کوتاه‌سازی چت
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - استفاده از MCP محلی و راه دور
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - رفتار تفصیلی فراخوانی ابزار
- [docs/integrations.md](../docs/integrations.md) - یکپارچگی با ابزارهای شخص ثالث (opencode و غیره)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - بازبینی محلی با apfel + یک مدل دوم ویرایش/اعمال در VS Code
- [docs/demos.md](../docs/demos.md) - راهنمای مفصل‌تر نمونه‌های شل
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - بیش از 50 prompt واقعی با خروجی ویرایش‌نشده
- [docs/swift-library.md](../docs/swift-library.md) - بسته Swift به نام `ApfelCore` برای توسعه‌دهندگان پایین‌دستی
- [docs/coreai-impact.md](../docs/coreai-impact.md) - چرا apfel روی FoundationModels اجرا می‌شود و نه روی Core AI جدید اپل (جانشین Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - مقایسه apfel با CLI خود اپل یعنی `fm` (macOS 27)، ویژگی به ویژگی با اعداد اندازه‌گیری‌شده

## معماری

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

همروندی سخت‌گیرانه Swift 6.3. سه target: ‏`ApfelCore` (منطق خالص، قابل تست واحد، به‌عنوان محصول Swift Package نیز در دسترس - در بخش مستندات مرجع بالا لینک شده)، `apfel` (CLI + سرور) و `apfel-tests` (اجراکننده خالص Swift، بدون XCTest).

## ساخت و آزمایش

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

`.version` تنها منبع حقیقت است. فقط `make release` نسخه‌ها را بالا می‌برد. ساخت‌های محلی نسخه را تغییر نمی‌دهند.

## درخت apfel

پروژه‌هایی که روی apfel ساخته شده‌اند. هر کدام مخزن و formula مخصوص Homebrew خودش را دارد.

| پروژه | کاربرد | نصب |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | ریشه. CLI مبتنی بر FoundationModels روی دستگاه + سرور سازگار با OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | کلاینت چت macOS: markdown با streaming، ورودی/خروجی گفتار، تحلیل تصویر با Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | اقدامات هوش مصنوعی در نوار منو روی کلیپ‌بورد: خلاصه‌سازی، ترجمه، بازنویسی. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | پنجره فوری هوش مصنوعی: کلیدی را بزنید، بپرسید، پاسخ بگیرید، ببندید. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | دفترچه یادداشت فرمول‌محور - هوش مصنوعی روی دستگاه به‌عنوان تابع درون‌خطی سلول. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCPهای بهینه‌شده برای بودجه توکن در پنجره کوچک روی دستگاه: `url-fetch`، `ddg-search`، `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | بازرس اشکال‌زدایی SwiftUI: خط زمانی درخواست‌ها، نمایشگر پروتکل MCP، TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | wrapper UNIX که یک رجیستری MCP پایدار + پیکربندی TOML را روی `apfel` اضافه می‌کند. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI برچسب‌گذاری محتوا روی دستگاه: متن را pipe کنید، برچسب/موضوع/احساس دریافت کنید. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | بسته Swift برای ابزارهای اکوسیستم: کشف، اجرا و streaming از یک `apfel --serve` محلی. | Swift Package |

## پروژه‌های جامعه

چیزی روی apfel ساخته‌اید؟ یک issue باز کنید تا اینجا اضافه شود.

| پروژه | کاربرد | پیوندها |
|---------|-------------|-------|
| **apfelclaw** از [@julianYaman](https://github.com/julianYaman) | عامل هوش مصنوعی محلی که با ابزارهای فقط‌خواندنی، فایل‌ها، تقویم، ایمیل و وضعیت مک را می‌خواند | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** از [@bhaskarvilles](https://github.com/bhaskarvilles) | رابط چت مرورگرمحور که از طریق API سازگار با OpenAI با `apfel --serve` صحبت می‌کند | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** از [@lucaspwo](https://github.com/lucaspwo) | wrapper برای Claude Code که با یک پراکسی کوچک Anthropic-OpenAI، apfel را به‌عنوان بک‌اند محلی جایگزین می‌کند | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** از [@hasit](https://github.com/hasit) | مدیر برنامه برای اپ‌های شل محلی ساخته‌شده حول apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** از [@eggsy](https://github.com/eggsy) | افزونه نوار فرمان Raycast: پرسش، ترجمه، توضیح فایل‌ها و پوشه‌ها، تاریخچه گفتگو، system promptهای سفارشی. روی دستگاه از طریق apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## مشارکت

Issue و PR روی هر مخزن `Arthur-Ficial/apfel*` پذیرفته می‌شود.

**#agentswelcome** - PRهای عامل‌های هوش مصنوعی مشکلی ندارند. فایل `CLAUDE.md` مخزن را بخوانید، تست‌ها را اجرا کنید و ابزار را در یک trailer به نام `Co-Authored-By` ذکر کنید. معیار همان انسان‌هاست: کد تمیز، تست‌های موفق، محدودیت‌های صادقانه. مناسب‌ترین نقطه شروع برای عامل‌ها: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([قوانین مشارکت](https://apfel-mcp.franzai.com/#contribute)).

## مجوز

[MIT](../LICENSE)
