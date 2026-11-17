<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> تمت الترجمة من [README الإنجليزي](../README.md). النسخة الإنجليزية هي المرجع المعتمد.

# apfel

### الذكاء الاصطناعي المجاني الموجود فعلاً على جهاز Mac الخاص بك.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

تأتي أجهزة Mac المزودة بشرائح Apple Silicon بنموذج لغوي كبير (LLM) مدمج عبر [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). يعرضه `apfel` كأداة UNIX وكخادم محلي متوافق مع OpenAI. تشغيل بنسبة 100% على الجهاز. بلا مفاتيح API وبلا سحابة.

| الوضع | الأمر | ما تحصل عليه |
|-------|-------|--------------|
| أداة UNIX | `apfel "prompt"` / `echo "text" \| apfel` | إجابات مناسبة للـ pipe، وإرفاق الملفات، ومخرجات JSON، ورموز الخروج |
| خادم متوافق مع OpenAI | `apfel --serve` | واجهة خلفية محلية `http://localhost:11434/v1` تحل مباشرة محل خدمة OpenAI في حِزم SDK |

`apfel --chat` - واجهة REPL تفاعلية.

[![فيديو عرض apfel في الطرفية: أوامر حقيقية وإجابات حقيقية على الجهاز (82 ثانية)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ar/a/apfel-ai-tutorial/#video)

استدعاء الأدوات (tool calling) يعمل في جميع السياقات.

![apfel CLI](../screenshots/cli.png)

## المتطلبات والتثبيت

macOS 26 Tahoe+، وApple Silicon (M1+)، و[تفعيل Apple Intelligence](https://support.apple.com/en-us/121115). على macOS 27، تشغّل أجهزة Mac ذات شريحة M3 أو أحدث وذاكرة 12 GB+ نموذج Apple الأكبر على الجهاز بنافذة من 8192 token؛ أما أجهزة M1/M2 وكل جهاز Mac يعمل بنظام macOS 26 فنافذتها 4096. يعرض لك `apfel --model-info` القيمة الخاصة بجهازك.

```bash
brew install apfel
```

التحديث:

```bash
brew upgrade apfel
```

البناء من المصدر (Command Line Tools مع SDK الخاص بـ macOS 27 / Swift 6.3، بدون Xcode؛ الملف التنفيذي يعمل على macOS 26 و27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

tap في اليوم نفسه، وMint، وmise، وحل المشكلات: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | **العربية** | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## البدء السريع

### أداة UNIX

ضع الـ prompts التي تحتوي على `!` بين علامتي اقتباس مفردتين (توسيع السجل في zsh/bash): `apfel 'Hello, Mac!'`.

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

### خادم متوافق مع OpenAI

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

تفاصيل الخدمة في الخلفية: [docs/background-service.md](../docs/background-service.md).

### دردشة للتجربة السريعة

`apfel --chat` هي واجهة REPL صغيرة لتجربة الـ prompts أو خوادم MCP. للحصول على تطبيق دردشة برسومية، راجع [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

يخرج Ctrl-C من الدردشة. يُقتطع السياق تلقائياً ([docs/context-strategies.md](../docs/context-strategies.md)).

قيود تستحق المعرفة قبل كتابة سكربتات تعتمد عليه (نافذة السياق حسب كل Mac، وguardrails، وعدم وجود embeddings): [القيود](../README.md#limitations).

## العروض التوضيحية

سكربتات shell حقيقية تغلّف `apfel`: ‏`cmd` (من الإنجليزية إلى أمر shell)، و`oneliner`، و`mac-narrator`، و`wtd`، و`explain`، و`naming`، و`port`، و`gitsum`. وهي مضمّنة داخل الملف التنفيذي، فلا حاجة إلى استنساخ المستودع. اكتبها في أي مكان، من حيث ثبّتّ apfel (homebrew-core أو الـ tap أو المصدر):

```bash
apfel demos ./apfel-demos
```

يكتب هذا كل العروض (قابلة للتنفيذ) إضافة إلى ملف `README.md` داخل `./apfel-demos`. ثم شغّلها من هناك:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

أعد تشغيل `apfel demos` بعد `brew upgrade apfel` للتحديث. المصادر: [`demo/`](../demo/). شروحات مفصلة ودالة shell باسم `cmd` للنسخ واللصق في ملف `.zshrc` الخاص بك: [docs/demos.md](../docs/demos.md).

## دعم أدوات MCP

اربط خوادم [Model Context Protocol](https://modelcontextprotocol.io/) باستخدام `--mcp`. يكتشف apfel الأدوات ويستدعيها ويعيد النتيجة.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

استخدم `-q` لإخفاء معلومات الأدوات.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

يأتي مع آلة حاسبة في [`mcp/calculator/`](../mcp/calculator/) ‏([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**خوادم MCP البعيدة** (Streamable HTTP، مواصفة MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **الأمان:** فضّل `APFEL_MCP_TOKEN` على `--mcp-token` (يظهر في ps aux). يرفض apfel إرسال bearer tokens عبر `http://` غير المشفّر.

## apfel-run: طبقة إعدادات اختيارية

لا يملك apfel نفسه ملف إعدادات، بل flags ومتغيرات بيئة كأي أداة UNIX. إذا أردت إعدادات TOML (عدة خوادم MCP، وملفات تعريف، وإعدادات فريق في git)، فإن [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) هو غلاف بترخيص MIT يضيفها كبديل مباشر عبر `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## التوافق مع OpenAI API

**الرابط الأساسي:** `http://localhost:11434/v1`

| الميزة | الحالة | ملاحظات |
|--------|--------|---------|
| `POST /v1/chat/completions` | مدعومة | مع streaming وبدونه |
| `POST /v1/responses` | مدعومة | واجهة OpenAI Responses API: مدخلات نصية/رسائل، و`instructions`، وstreaming (تسلسل الأحداث القياسي)، و`text.format` (بما فيه `json_schema`)، وأدوات الدوال (بدون streaming). الميزات ذات الحالة (`previous_response_id` و`store: true` و`background` و`reasoning` والأدوات المستضافة) تعيد 501 صريحة |
| `POST /v1/responses/input_tokens` | مدعومة | فحص مسبق للـ tokens ‏(`client.responses.input_tokens.count(...)`): عدّ دقيق من tokenizer الخاص بـ Apple، دون توليد؛ وتعيد 501 على إصدارات أقدم من macOS 26.4 بدل تقدير تقريبي. راجع [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | مدعومة | تعيد `apple-foundationmodel` (عام، الافتراضي) و`apple-foundationmodel-content-tagging` (تسميات، لا نصوص نثرية). راجع [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | مدعومة | توفر النموذج، ونافذة السياق، واللغات، وقدرات النموذج المُبلَّغ عنها (`capabilities` و`capabilities_reported`)، ومتغير النموذج المُشغَّل (`variant`، مثل AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | للتصحيح فقط | تتطلب `--debug` |
| Tool calling | مدعومة | يُكتب الاستدعاء عبر التوليد الموجَّه (`--tool-calling guided`، الافتراضي) أو بصيغة JSON يحللها الخادم (`--tool-calling text`). راجع [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | مدعومة | حقن في system prompt؛ تُزال أسوار markdown من المخرجات |
| `response_format: json_schema` | مدعومة | مخرجات مضمونة المطابقة للمخطط عبر `DynamicGenerationSchema` في FoundationModels؛ تعمل مع `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | مدعومة | تُربط بـ `GenerationOptions`. ‏`top_p` هو nucleus sampling؛ وقيمة `temperature` الأقل من 0.001 (ومنها 0) تُربط بالوضع greedy (حتمي). عند حذف `max_tokens` تُستخدم نافذة السياق المتبقية (دلالات OpenAI كبديل مباشر) - راجع [الحد الافتراضي للرد](../README.md#default-response-cap-max_tokens) |
| `stream: true` | مدعومة | SSE؛ ولا يصدر chunk الاستخدام الأخير إلا عند `stream_options: {"include_usage": true}` (وفق مواصفة OpenAI) |
| `usage` | مدعومة | أعداد حقيقية من tokenizer على macOS 26.4+ (وتقدير عدد الأحرف/4 على ما دونه). على macOS 27: حساب بيئة التشغيل نفسها شاملاً إطار chat-template من Apple (نحو 46 قيمة إضافية في `prompt_tokens` لـ prompt من سطر واحد)؛ على macOS 26: يعدّ apfel نص الرسائل. التفاصيل في [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | مدعومة | `stop` و`tool_calls` و`length` |
| استراتيجيات السياق | مدعومة | حقول الامتداد `x_context_strategy` و`x_context_max_turns` و`x_context_output_reserve` |
| CORS | مدعومة | يُفعَّل باستخدام `--cors` |
| `POST /v1/completions` | 501 | إكمالات النص القديمة غير مدعومة |
| `POST /v1/embeddings` | 501 | الـ embeddings غير متاحة على الجهاز |
| `stop` | مدعومة | سلسلة نصية أو حتى 4 سلاسل؛ نص عادي فقط (400 عند وجود أدوات في النطاق أو `json_object`/`json_schema`). تُطبَّق على جانب المخرجات، بنفس السلوك مع streaming وبدونه. راجع [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | تُرفض صراحة. تُقبل `n=1` و`logprobs=false` كعمليات بلا أثر |
| متعدد الوسائط (الصور) | مدعومة على macOS 27 | أجزاء `image_url` على هيئة data URL بترميز base64 تصل إلى النموذج على الجهاز أصلياً (حد 20 MB بعد base64، ويُصغَّر أطول ضلع إلى 4096 px). روابط `http(s)` البعيدة ومسارات الملفات ترجع دائماً 400 - لا يجلب apfel الصور أبداً ولا يقرأ ملفات لصالح عميل HTTP. على macOS 26: ‏400 مع رسالة خطأ واضحة. راجع [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| ترويسة `Authorization` | مدعومة | إلزامية عند ضبط `--token`. راجع [docs/server-security.md](../docs/server-security.md) |

مواصفة API الكاملة: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## الحد الافتراضي للرد (`max_tokens`)

عند حذف `max_tokens`، **يتصرف CLI والخادم المتوافق مع OpenAI بالطريقة نفسها تماماً**: تمر القيمة على أنها `nil` ويستخدم النموذج ما تبقى من نافذة السياق. هذه دلالات OpenAI كبديل مباشر - بلا ثابت احتياطي اعتباطي.

تتسع نافذة السياق على الجهاز للمدخلات *و*المخرجات معاً: **4096 token على macOS 26 وعلى أجهزة M1/M2، و8192 token على macOS 27 مع شريحة M3 أو أحدث وذاكرة 12 GB+**. يقرأ apfel الحجم الفعلي وقت التشغيل عبر `SystemLanguageModel.contextSize` - تحقق من قيمة جهازك بـ `apfel --model-info`. إذا اصطدم التوليد بالحد الأقصى، ينتهي الرد بسلاسة مع `finish_reason: "length"` ويُعاد المحتوى الجزئي (الخادم: HTTP 200؛ وCLI: خروج 0 مع تحذير في stderr، أو خروج 8 مع `--require-complete` - راجع [docs/cli-reference.md](../docs/cli-reference.md)). مرّر `max_tokens` صراحة عندما تريد ميزانية زمن استجابة أضيق أو حداً معروفاً لعميلك.

### أمثلة

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

### اختيار القيمة

| حالة الاستخدام                          | `max_tokens`  |
|-----------------------------------------|---------------|
| رد بكلمة واحدة / تصنيف                  | 16 - 32       |
| تعليمة من سطر واحد                      | 64 - 128      |
| فقرة قصيرة                              | 256 - 512     |
| فقرة طويلة / JSON منظم                  | 1024 - 2048   |
| بأطول ما تسمح به نافذة السياق           | احذفه         |

أبقِ `input_tokens + max_tokens` أقل من نافذة السياق بهامش مريح (4096 token على macOS 26 وعلى أجهزة M1/M2، و8192 على macOS 27 مع شريحة M3 أو أحدث وذاكرة 12 GB+ (نموذج AFM 3 Core Advanced من Apple)). إذا تجاوز الـ prompt نفسه النافذة، لا يمكن أن يبدأ التوليد ويفشل الطلب برسالة `[context overflow]` (‏HTTP 400 / خروج CLI برمز 4). يرفض المدقق القيم غير الموجبة (`max_tokens <= 0`).

### تطابق CLI

يتشارك CLI والخادم قاعدة واحدة: المحذوف = استخدم النافذة المتبقية. لا ثابت قد ينحرف. يمكن التجاوز باستخدام `--max-tokens N` أو `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### guardrails متساهلة للخادم

يجعل `apfel --serve --permissive` الخادم يستخدم guardrails من نوع `.permissiveContentTransformations` من Apple في **كل طلب** تعالجه العملية. الـ flag نفسه والدلالات نفسها كما في `--permissive` الخاص بـ CLI ‏([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). لا يوجد تجاوز لكل طلب على حدة - يقرر مشغّل الخادم للعملية كلها.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## القيود

| القيد | التفاصيل |
|-------|----------|
| نافذة السياق | **4096 token على macOS 26 وعلى أجهزة M1/M2، و8192 token على macOS 27 مع شريحة M3 أو أحدث وذاكرة 12 GB+** (المدخلات + المخرجات معاً). ليست ثابتاً مكتوباً في الشيفرة - يقرأ apfel القيمة `SystemLanguageModel.contextSize` وقت التشغيل؛ ويطبع `apfel --model-info` القيمة الحالية |
| المنصة | macOS 26+، وApple Silicon فقط |
| النموذج | نموذج واحد على الجهاز (نحو 3B معامل)، يُقدَّم باسم `apple-foundationmodel` (عام) و`apple-foundationmodel-content-tagging` (محوّل وسم المحتوى من Apple؛ بلا أدوات) |
| Guardrails | قد يحجب نظام الأمان من Apple prompts سليمة. يقلل `--permissive` الإيجابيات الكاذبة ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| السرعة | على الجهاز وليس بمقياس السحابة - بضع ثوانٍ لكل رد |
| لا embeddings | غير متاحة على الجهاز |
| الرؤية | لا تصل الصور إلى النموذج إلا على macOS 27 (الخادم: data URLs؛ وCLI: ‏`-f photo.jpg` والصور المرسلة عبر pipe، إضافة إلى نص OCR). على macOS 26 تُعالج الصور كنص فقط عبر OCR/التصنيف. أوصاف المشاهد من النموذج ذي 3B تقريبية - ويبقى OCR القناة الموثوقة لقراءة المطبوع |
| بيانات التدريب / تاريخ انتهاء المعرفة | لم تنشر Apple تاريخاً دقيقاً لانتهاء معرفة النموذج على الجهاز. وعند الضغط عليه ليذكر تاريخاً، **يختلق النموذج تاريخاً مختلفاً في كل مرة** (مثل "October 2023" أو "April 2023"). تعامل مع كل ما يذكره النموذج عن تدريبه بوصفه غير موثوق. |
| لا تاريخ حالي ولا إدراك للوقت الفعلي | لا يعرف النموذج تاريخ اليوم وليس لديه وصول إلى الشبكة أو الساعة. وإذا سُئل فسيرفض أو يخترع تاريخاً. أدرج التاريخ الحالي عبر system prompt عندما تعتمد العمليات الحسابية عليه (راجع الحل البديل أدناه). |

**حل بديل للـ prompts المعتمدة على التاريخ** - أدرج التاريخ الحالي كرسالة نظام:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

ملاحظة: حتى مع إدراج التاريخ قد يهلوس النموذج ذو 3B (خصوصاً عند سؤاله مباشرة عن تاريخ انتهاء تدريبه). يفيد الإدراج الـ prompts التوليدية التي *تستخدم* التاريخ؛ لكنه لا يلغي ميل النموذج إلى الإخبار عن نفسه.

الخلفية: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## وثائق مرجعية

أدلة لاستخدام apfel من [Python](../docs/guides/python.md)، و[Node.js](../docs/guides/nodejs.md)، و[Ruby](../docs/guides/ruby.md)، و[PHP](../docs/guides/php.md)، و[Bash/curl](../docs/guides/bash-curl.md)، و[Zsh](../docs/guides/zsh.md)، و[AppleScript](../docs/guides/applescript.md)، و[Swift](../docs/guides/swift-scripting.md)، و[Perl](../docs/guides/perl.md)، و[AWK](../docs/guides/awk.md) - راجع [docs/guides/index.md](../docs/guides/index.md). مُختبَرة تجريبياً؛ والدليل القابل للتشغيل في [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - التثبيت وحل المشكلات وإعداد Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - كل flag ورمز خروج ومتغير بيئة
- [docs/file-extraction.md](../docs/file-extraction.md) - استخراج PDF / الصور / النصوص عبر `-f` وعبر pipe ‏(OCR + فهم الصور)
- [docs/background-service.md](../docs/background-service.md) - استخدام `brew services` وlaunchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - مصفوفة دعم `/v1/*` بالتفصيل
- [docs/server-security.md](../docs/server-security.md) - فحوص الأصل وCORS والـ tokens و`--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - استراتيجيات اقتطاع الدردشة
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - استخدام MCP المحلي والبعيد
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - سلوك استدعاء الأدوات بالتفصيل
- [docs/integrations.md](../docs/integrations.md) - تكاملات أدوات الأطراف الثالثة (opencode وغيرها)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - مراجعة محلية باستخدام apfel + نموذج ثانٍ للتحرير/التطبيق في VS Code
- [docs/demos.md](../docs/demos.md) - شروحات أطول لعروض shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - أكثر من 50 prompt حقيقياً بمخرجات غير معدّلة
- [docs/swift-library.md](../docs/swift-library.md) - حزمة Swift ‏`ApfelCore` للمطورين الذين يبنون فوقها
- [docs/coreai-impact.md](../docs/coreai-impact.md) - لماذا يعمل apfel على FoundationModels وليس على Core AI الجديد من Apple (خليفة Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - مقارنة apfel مع أداة `fm` CLI من Apple (macOS 27)، ميزة بميزة مع أرقام مقيسة

## البنية

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

تزامن صارم في Swift 6.3. ثلاثة targets: ‏`ApfelCore` (منطق خالص، قابل للاختبار بوحدات الاختبار، ومتاح أيضاً كمنتج Swift Package - مرتبط أعلاه ضمن الوثائق المرجعية)، و`apfel` (‏CLI + الخادم)، و`apfel-tests` (مشغّل Swift خالص، بلا XCTest).

## البناء والاختبار

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

الملف `.version` هو المصدر الوحيد للحقيقة. لا يرفع الإصدارات إلا `make release`. البناءات المحلية لا تغيّر الإصدار.

## شجرة apfel

مشاريع مبنية على apfel. يأتي كل منها في مستودعه الخاص + صيغة Homebrew.

| المشروع | ماذا يفعل | التثبيت |
|---------|-----------|---------|
| [**apfel**](https://apfel.franzai.com) | الجذر. أداة FoundationModels CLI على الجهاز + خادم متوافق مع OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | عميل دردشة لـ macOS: markdown بـ streaming، ومدخلات/مخرجات صوتية، وتحليل صور عبر Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | إجراءات ذكاء اصطناعي من شريط القوائم على الحافظة: تلخيص وترجمة وإعادة صياغة. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | طبقة ذكاء اصطناعي فورية: اضغط مفتاحاً، واسأل، وتلقَّ الإجابة، ثم أغلقها. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | دفتر ملاحظات بالصيغ - ذكاء اصطناعي على الجهاز كدالة خلية مضمّنة. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | خوادم MCP محسّنة لميزانية الـ tokens في النافذة الصغيرة على الجهاز: `url-fetch` و`ddg-search` و`search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | مفتش تصحيح بواجهة SwiftUI: جدول زمني للطلبات، وعارض لبروتوكول MCP، وTTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | غلاف UNIX يضيف سجل MCP دائماً + إعدادات TOML فوق `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | أداة CLI لوسم المحتوى على الجهاز: مرّر النص عبر pipe واحصل على وسوم/مواضيع/مشاعر. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | حزمة Swift لأدوات المنظومة: اكتشاف `apfel --serve` محلي وتشغيله والتلقي منه بـ streaming. | Swift Package |

## مشاريع المجتمع

هل بنيت شيئاً فوق apfel؟ افتح issue وقد تُضاف هنا.

| المشروع | ماذا يفعل | الروابط |
|---------|-----------|---------|
| **apfelclaw** من [@julianYaman](https://github.com/julianYaman) | وكيل ذكاء اصطناعي محلي يقرأ الملفات والتقويم والبريد وحالة Mac عبر أدوات للقراءة فقط | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** من [@bhaskarvilles](https://github.com/bhaskarvilles) | واجهة دردشة في المتصفح تتحدث إلى `apfel --serve` عبر API المتوافقة مع OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** من [@lucaspwo](https://github.com/lucaspwo) | غلاف لـ Claude Code يستبدل apfel كواجهة خلفية محلية عبر وكيل Anthropic-OpenAI صغير | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** من [@hasit](https://github.com/hasit) | مدير تطبيقات لتطبيقات shell المحلية المبنية حول apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** من [@eggsy](https://github.com/eggsy) | امتداد لشريط أوامر Raycast: اسأل، وترجم، واشرح الملفات والمجلدات، وسجل المحادثات، وsystem prompts مخصصة. على الجهاز عبر apfel CLI. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## المساهمة

المساهمات عبر issues وPRs مرحّب بها في أي مستودع `Arthur-Ficial/apfel*`.

**#agentswelcome** - لا بأس بـ PRs وكلاء الذكاء الاصطناعي. اقرأ ملف `CLAUDE.md` في المستودع، وشغّل الاختبارات، وانسب الفضل للأداة في trailer من نوع `Co-Authored-By`. المعيار نفسه كما للبشر: شيفرة نظيفة، واختبارات ناجحة، وحدود صريحة. أنسب نقطة دخول للوكلاء: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([قواعد المساهمة](https://apfel-mcp.franzai.com/#contribute)).

## الترخيص

[MIT](../LICENSE)
