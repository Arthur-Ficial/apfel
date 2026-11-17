<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Переклад [англійського README](../README.md). Англійська версія є головною.

# apfel

### Безкоштовний ШІ, який уже є на вашому Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac на Apple Silicon постачаються зі вбудованою LLM через [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` відкриває її як UNIX-інструмент і локальний OpenAI-сумісний сервер. 100% на пристрої. Без API-ключів, без хмари.

| Режим | Команда | Що ви отримуєте |
|------|---------|--------------|
| UNIX-інструмент | `apfel "prompt"` / `echo "text" \| apfel` | Відповіді, зручні для pipe, вкладення файлів, JSON-вивід, коди завершення |
| OpenAI-сумісний сервер | `apfel --serve` | Локальний бекенд `http://localhost:11434/v1`, що безшовно замінює хмару для OpenAI SDK |

`apfel --chat` - інтерактивний REPL.

[![Демовідео apfel у терміналі: справжні команди, справжні відповіді на пристрої (82 секунди)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/uk/a/apfel-ai-tutorial/#video)

Виклик інструментів працює в усіх контекстах.

![apfel CLI](../screenshots/cli.png)

## Вимоги та встановлення

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence увімкнено](https://support.apple.com/en-us/121115). На macOS 27 Mac з чипом M3 або новішим і 12 GB+ пам'яті запускають більшу модель Apple на пристрої з вікном у 8192 токени; Mac на M1/M2 і будь-який Mac на macOS 26 мають 4096. `apfel --model-info` покаже ваше значення.

```bash
brew install apfel
```

Оновлення:

```bash
brew upgrade apfel
```

Збирання з вихідного коду (Command Line Tools з macOS 27 SDK / Swift 6.3, без Xcode; бінарний файл працює на macOS 26 і 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, усунення несправностей: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | **Українська** | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Швидкий старт

### UNIX-інструмент

Беріть prompt зі знаком `!` в одинарні лапки (розкриття історії в zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-сумісний сервер

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

Подробиці про фонову службу: [docs/background-service.md](../docs/background-service.md).

### Чат для швидкого тестування

`apfel --chat` - невеликий REPL для тестування prompt-ів або MCP-серверів. Для чат-застосунку з GUI дивіться [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C завершує роботу. Контекст обрізається автоматично ([docs/context-strategies.md](../docs/context-strategies.md)).

Обмеження, про які варто знати, перш ніж писати скрипти (контекстне вікно залежно від Mac, guardrails, відсутність embeddings): [Обмеження](../README.md#limitations).

## Демо

Справжні shell-скрипти, що обгортають `apfel`: `cmd` (англійська в команду shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Вони вбудовані в бінарний файл - клонувати репозиторій не потрібно. Запишіть їх туди, звідки ви встановили apfel (homebrew-core, tap або вихідний код):

```bash
apfel demos ./apfel-demos
```

Це запише всі демо (виконувані) разом із `README.md` у `./apfel-demos`. Потім запускайте їх звідти:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Повторно запустіть `apfel demos` після `brew upgrade apfel`, щоб оновити їх. Джерела: [`demo/`](../demo/). Покрокові розбори та shell-функція `cmd` для копіювання у ваш `.zshrc`: [docs/demos.md](../docs/demos.md).

## Підтримка MCP-інструментів

Підключайте сервери [Model Context Protocol](https://modelcontextprotocol.io/) через `--mcp`. apfel знаходить, викликає й повертає результат.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Використовуйте `-q`, щоб приховати інформацію про інструменти.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

У комплекті є калькулятор у [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Віддалені MCP-сервери** (Streamable HTTP, специфікація MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Безпека:** віддавайте перевагу `APFEL_MCP_TOKEN` замість `--mcp-token` (видно в ps aux). apfel відмовляється передавати bearer-токени через незашифрований `http://`.

## apfel-run: необов'язковий шар конфігурації

Сам apfel не має файлу конфігурації - лише прапорці та змінні середовища, як і належить UNIX-інструменту. Якщо вам потрібна конфігурація TOML (багато MCP, профілі, командні конфігурації в git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) - це обгортка з ліцензією MIT, що додає її через drop-in `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Сумісність з OpenAI API

**Базова URL-адреса:** `http://localhost:11434/v1`

| Можливість | Статус | Примітки |
|---------|--------|-------|
| `POST /v1/chat/completions` | Підтримується | Streaming і без streaming |
| `POST /v1/responses` | Підтримується | OpenAI Responses API: рядок/повідомлення на вході, `instructions`, streaming (канонічна послідовність подій), `text.format` (зокрема `json_schema`), function tools (без streaming). Функції зі станом (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) повертають чесні 501 |
| `POST /v1/responses/input_tokens` | Підтримується | Попередня перевірка токенів (`client.responses.input_tokens.count(...)`): точний підрахунок токенізатором Apple, без генерації; 501 на macOS нижче 26.4 замість оцінки. Дивіться [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Підтримується | Повертає `apple-foundationmodel` (загальна, за замовчуванням) і `apple-foundationmodel-content-tagging` (мітки, не зв'язний текст). Дивіться [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Підтримується | Доступність моделі, контекстне вікно, мови, заявлені можливості моделі (`capabilities`, `capabilities_reported`), варіант моделі, що обслуговує запити (`variant`, напр. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Лише для налагодження | Потрібен `--debug` |
| Виклик інструментів | Підтримується | Виклик формується через керовану генерацію (`--tool-calling guided`, за замовчуванням) або як JSON, який розбирає сервер (`--tool-calling text`). Дивіться [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Підтримується | Ін'єкція в системний prompt; markdown-блоки видаляються з виводу |
| `response_format: json_schema` | Підтримується | Гарантований вивід, що відповідає схемі, через FoundationModels `DynamicGenerationSchema`; працює з `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Підтримується | Відображаються на `GenerationOptions`. `top_p` - це nucleus sampling; `temperature` нижче 0.001 (включно з 0) відповідає greedy (детермінований режим). Якщо `max_tokens` не вказано, використовується решта контекстного вікна (семантика OpenAI) - дивіться [Типовий ліміт відповіді](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Підтримується | SSE; завершальний чанк usage лише за `stream_options: {"include_usage": true}` (за специфікацією OpenAI) |
| `usage` | Підтримується | Справжні підрахунки токенізатора на macOS 26.4+ (нижче - оцінка chars/4). macOS 27: власний облік середовища виконання, включно з обрамленням chat-template від Apple (приблизно на 46 більше `prompt_tokens` для однорядкового prompt); macOS 26: apfel рахує текст повідомлень. Подробиці в [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Підтримується | `stop`, `tool_calls`, `length` |
| Стратегії контексту | Підтримується | Додаткові поля `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Підтримується | Вмикається через `--cors` |
| `POST /v1/completions` | 501 | Застарілі текстові completions не підтримуються |
| `POST /v1/embeddings` | 501 | Embeddings недоступні на пристрої |
| `stop` | Підтримується | Рядок або до 4 рядків; лише простий текст (400 за наявності інструментів у контексті або `json_object`/`json_schema`). Застосовується на стороні виводу, однаково зі streaming і без. Дивіться [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Відхиляються явно. `n=1` і `logprobs=false` приймаються як no-op |
| Мультимодальність (зображення) | Підтримується на macOS 27 | Частини `image_url` як base64 data URL передаються моделі на пристрої нативно (ліміт 20 MB base64, довша сторона зменшується до 4096 px). Віддалені `http(s)` URL і шляхи до файлів завжди дають 400 - apfel ніколи не завантажує зображення і ніколи не читає файли для HTTP-клієнта. На macOS 26: 400 з чітким повідомленням про помилку. Дивіться [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Заголовок `Authorization` | Підтримується | Обов'язковий, якщо задано `--token`. Дивіться [docs/server-security.md](../docs/server-security.md) |

Повна специфікація API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Типовий ліміт відповіді (`max_tokens`)

Коли `max_tokens` не вказано, **CLI і OpenAI-сумісний сервер поводяться однаково**: значення передається далі як `nil`, і модель використовує все, що лишилося в контекстному вікні. Це семантика OpenAI "drop-in" - без довільної запасної константи.

Контекстне вікно на пристрої вміщує і вхід, *і* вихід разом: **4096 токенів на macOS 26 і на Mac з M1/M2, 8192 токени на macOS 27 з чипом M3 або новішим і 12 GB+**. apfel читає реальний розмір під час виконання через `SystemLanguageModel.contextSize` - перевірте своє значення командою `apfel --model-info`. Якщо генерація впирається в межу, відповідь чисто завершується з `finish_reason: "length"` і повертається частковий вміст (сервер: HTTP 200; CLI: код 0 із попередженням у stderr, або код 8 з `--require-complete` - дивіться [docs/cli-reference.md](../docs/cli-reference.md)). Вказуйте `max_tokens` явно, коли потрібен жорсткіший бюджет затримки або відомий ліміт для вашого клієнта.

### Приклади

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

### Вибір значення

| Сценарій                               | `max_tokens`  |
|----------------------------------------|---------------|
| Відповідь одним словом / класифікація  | 16 - 32       |
| Інструкція в один рядок                | 64 - 128      |
| Короткий абзац                         | 256 - 512     |
| Довгий абзац / структурований JSON     | 1024 - 2048   |
| Скільки дозволяє контекстне вікно      | не вказувати  |

Тримайте `input_tokens + max_tokens` з запасом нижче контекстного вікна (4096 токенів на macOS 26 і на Mac з M1/M2, 8192 на macOS 27 з чипом M3 або новішим і 12 GB+ (модель Apple AFM 3 Core Advanced)). Якщо сам prompt перевищує вікно, генерація не може початися, і запит завершується помилкою `[context overflow]` (HTTP 400 / CLI exit 4). Валідатор відхиляє недодатні значення (`max_tokens <= 0`).

### Паритет з CLI

CLI і сервер мають одне правило: не вказано = використати решту вікна. Жодної константи, що могла б розійтися. Перевизначити можна через `--max-tokens N` або `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Permissive guardrails для сервера

`apfel --serve --permissive` змушує сервер використовувати guardrails Apple `.permissiveContentTransformations` для **кожного запиту**, який обробляє процес. Той самий прапорець і та сама семантика, що й у `--permissive` для CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Перевизначення для окремого запиту немає - рішення для всього процесу ухвалює оператор сервера.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Обмеження

| Обмеження | Деталі |
|------------|--------|
| Контекстне вікно | **4096 токенів на macOS 26 і на Mac з M1/M2, 8192 токени на macOS 27 з чипом M3 або новішим і 12 GB+** (вхід + вихід разом). Не жорстко закодована константа - apfel читає `SystemLanguageModel.contextSize` під час виконання; `apfel --model-info` виводить актуальне значення |
| Платформа | macOS 26+, лише Apple Silicon |
| Модель | Одна модель на пристрої (~3B параметрів), доступна як `apple-foundationmodel` (загальна) і `apple-foundationmodel-content-tagging` (адаптер Apple для тегування контенту; без інструментів) |
| Guardrails | Система безпеки Apple може блокувати нешкідливі prompt-и. `--permissive` зменшує хибні спрацювання ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Швидкість | На пристрої, а не в масштабі хмари - кілька секунд на відповідь |
| Без embeddings | Недоступні на пристрої |
| Зір | Зображення доходять до моделі лише на macOS 27 (сервер: data URL; CLI: `-f photo.jpg` і зображення через pipe, на додачу до тексту з OCR). На macOS 26 зображення обробляються лише як текст через OCR/класифікацію. Описи сцен від моделі на 3B грубі - для читання друкованого тексту надійним каналом лишається OCR |
| Навчальні дані / межа знань | Apple не опублікувала точної межі знань для моделі на пристрої. Якщо наполягати на назві дати, модель **вигадує нову дату в кожній вибірці** (наприклад, "October 2023", "April 2023"). Вважайте будь-які власні заяви моделі про її навчання недостовірними. |
| Немає поточної дати та відчуття реального часу | Модель не знає сьогоднішньої дати й не має доступу до мережі чи годинника. На запитання вона або відмовить, або вигадає дату. Передавайте поточну дату через системний prompt, коли від неї залежать обчислення (див. обхідний шлях нижче). |

**Обхідний шлях для prompt-ів, що залежать від дати** - передайте поточну дату як системне повідомлення:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Примітка: навіть із переданою датою модель на 3B усе одно може галюцинувати (особливо коли її прямо питають про межу її навчання). Передача дати допомагає генеративним prompt-ам, які *використовують* дату; вона не скасовує рефлекс моделі розповідати про себе.

Передісторія: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Довідкова документація

Посібники з використання apfel із [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - дивіться [docs/guides/index.md](../docs/guides/index.md). Перевірено емпірично; працюючий доказ у [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - встановлення, усунення несправностей і налаштування Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - кожен прапорець, код завершення та змінна середовища
- [docs/file-extraction.md](../docs/file-extraction.md) - вилучення вмісту PDF / зображень / тексту через `-f` і pipe (OCR + розуміння зображень)
- [docs/background-service.md](../docs/background-service.md) - використання `brew services` і launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - детальна матриця підтримки `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - перевірки origin, CORS, токени та `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - стратегії обрізання чату
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - використання локальних і віддалених MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - докладна поведінка виклику інструментів
- [docs/integrations.md](../docs/integrations.md) - інтеграції зі сторонніми інструментами (opencode тощо)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - локальне рев'ю з apfel і другою моделлю для редагування/застосування у VS Code
- [docs/demos.md](../docs/demos.md) - довші покрокові розбори shell-демо
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - понад 50 справжніх prompt-ів із нередагованим виводом
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` для downstream-розробників
- [docs/coreai-impact.md](../docs/coreai-impact.md) - чому apfel працює на FoundationModels, а не на новому Core AI від Apple (наступнику Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - порівняння apfel із власним CLI `fm` від Apple (macOS 27), можливість за можливістю, з виміряними числами

## Архітектура

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. Три цілі: `ApfelCore` (чиста логіка, придатна для модульних тестів, також доступна як продукт Swift Package - посилання в розділі "Довідкова документація" вище), `apfel` (CLI + сервер) і `apfel-tests` (раннер на чистому Swift, без XCTest).

## Збирання та тести

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

`.version` - єдине джерело істини. Версії піднімає лише `make release`. Локальні збірки версію не змінюють.

## Дерево apfel

Проєкти, побудовані на apfel. Кожен постачається як окремий репозиторій + формула Homebrew.

| Проєкт | Що робить | Встановлення |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Корінь. CLI на FoundationModels на пристрої + OpenAI-сумісний сервер. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Чат-клієнт для macOS: streaming markdown, голосовий ввід/вивід, аналіз зображень через Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ШІ-дії в рядку меню для буфера обміну: підсумувати, перекласти, переписати. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Миттєвий ШІ-оверлей: натисніть клавішу, запитайте, отримайте відповідь, закрийте. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Блокнот із формулами - ШІ на пристрої як вбудована функція клітинки. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP, оптимізовані за бюджетом токенів для малого вікна на пристрої: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Налагоджувальний інспектор на SwiftUI: часова шкала запитів, переглядач протоколу MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-обгортка, що додає постійний реєстр MCP + конфігурацію TOML поверх `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI для тегування вмісту на пристрої: подайте текст на вхід, отримайте теги/теми/емоції. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-пакет для інструментів екосистеми: виявлення, запуск і streaming з локального `apfel --serve`. | Swift Package |

## Проєкти спільноти

Створили щось на основі apfel? Відкрийте issue, і це можна додати сюди.

| Проєкт | Що робить | Посилання |
|---------|-------------|-------|
| **apfelclaw** від [@julianYaman](https://github.com/julianYaman) | Локальний ШІ-агент, що читає файли, календар, пошту та стан Mac через інструменти лише для читання | [github](https://github.com/julianyaman/apfelclaw) - [сайт](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** від [@bhaskarvilles](https://github.com/bhaskarvilles) | Браузерний чат-інтерфейс, що спілкується з `apfel --serve` через OpenAI-сумісний API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** від [@lucaspwo](https://github.com/lucaspwo) | Обгортка Claude Code, що підставляє apfel як локальний бекенд через невеликий проксі Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** від [@hasit](https://github.com/hasit) | Менеджер застосунків для локальних shell-застосунків на основі apfel | [github](https://github.com/hasit/apfeller) - [сайт](https://hasit.github.io/apfeller/) - [каталог](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** від [@eggsy](https://github.com/eggsy) | Розширення для командного рядка Raycast: питати, перекладати, пояснювати файли й каталоги, історія розмов, власні системні prompt-и. На пристрої через apfel CLI. | [магазин](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Внесок

Issue і PR вітаються в будь-якому репозиторії `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR від ШІ-агентів прийнятні. Прочитайте `CLAUDE.md` репозиторію, запустіть тести, вкажіть інструмент у trailer `Co-Authored-By`. Та сама планка, що й для людей: чистий код, тести проходять, чесні обмеження. Найзручніша для агентів точка входу: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([правила внеску](https://apfel-mcp.franzai.com/#contribute)).

## Ліцензія

[MIT](../LICENSE)
