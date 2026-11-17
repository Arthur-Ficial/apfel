<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> Перевод [английского README](../README.md). Английская версия является основной.

# apfel

### Бесплатный ИИ, который уже есть на вашем Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac на Apple Silicon поставляются со встроенной LLM через [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` открывает её как UNIX-утилиту и как локальный OpenAI-совместимый сервер. 100% на устройстве. Без API-ключей, без облака.

| Режим | Команда | Что вы получаете |
|------|---------|--------------|
| UNIX-утилита | `apfel "prompt"` / `echo "text" \| apfel` | Ответы, удобные для конвейеров, вложение файлов, вывод в JSON, коды возврата |
| OpenAI-совместимый сервер | `apfel --serve` | Готовая замена: локальный бэкенд `http://localhost:11434/v1` для OpenAI SDK |

`apfel --chat` - интерактивный REPL.

[![Демовидео apfel в терминале: настоящие команды, настоящие ответы на устройстве (82 секунды)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ru/a/apfel-ai-tutorial/#video)

Вызов инструментов (tool calling) работает во всех контекстах.

![apfel CLI](../screenshots/cli.png)

## Требования и установка

macOS 26 Tahoe+, Apple Silicon (M1+), [включённый Apple Intelligence](https://support.apple.com/en-us/121115). На macOS 27 Mac с чипом M3 или новее и 12 GB+ памяти используют более крупную встроенную модель Apple с окном в 8192 токена; Mac на M1/M2 и любой Mac на macOS 26 имеют 4096. `apfel --model-info` покажет ваше значение.

```bash
brew install apfel
```

Обновление:

```bash
brew upgrade apfel
```

Сборка из исходников (Command Line Tools с SDK macOS 27 / Swift 6.3, без Xcode; бинарный файл работает на macOS 26 и 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Оперативный tap, Mint, mise, решение проблем: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | **Русский** | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Быстрый старт

### UNIX-утилита

Промпты с `!` заключайте в одинарные кавычки (раскрытие истории в zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-совместимый сервер

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

Подробности о фоновой службе: [docs/background-service.md](../docs/background-service.md).

### Чат для быстрой проверки

`apfel --chat` - небольшой REPL для проверки промптов или MCP-серверов. Графическое чат-приложение: [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C завершает работу. Контекст обрезается автоматически ([docs/context-strategies.md](../docs/context-strategies.md)).

Ограничения, которые стоит знать, прежде чем писать скрипты (окно контекста для каждого Mac, ограничители безопасности, отсутствие эмбеддингов): [Ограничения](../README.md#limitations).

## Демо

Настоящие shell-скрипты поверх `apfel`: `cmd` (английский в shell-команду), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Они встроены в бинарный файл - клонировать репозиторий не нужно. Запишите их туда, откуда вы установили apfel (homebrew-core, tap или исходники):

```bash
apfel demos ./apfel-demos
```

Команда записывает все демо (исполняемые) и `README.md` в `./apfel-demos`. Затем запускайте их оттуда:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Запускайте `apfel demos` заново после `brew upgrade apfel`, чтобы обновить их. Исходники: [`demo/`](../demo/). Подробные разборы и shell-функция `cmd` для вставки в `.zshrc`: [docs/demos.md](../docs/demos.md).

## Поддержка инструментов MCP

Подключайте серверы [Model Context Protocol](https://modelcontextprotocol.io/) через `--mcp`. apfel находит инструменты, вызывает их и возвращает результат.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Используйте `-q`, чтобы скрыть информацию об инструментах.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

В комплекте идёт калькулятор в [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Удалённые MCP-серверы** (Streamable HTTP, спецификация MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Безопасность:** используйте `APFEL_MCP_TOKEN`, а не `--mcp-token` (виден в ps aux). apfel отказывается передавать bearer-токены по открытому `http://`.

## apfel-run: необязательный слой конфигурации

У самого apfel нет файла конфигурации - только флаги и переменные окружения, как у любой UNIX-утилиты. Если вам нужен TOML-конфиг (много MCP, профили, командные конфиги в git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) - обёртка под лицензией MIT, которая добавляет его как drop-in через `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Совместимость с OpenAI API

**Базовый URL:** `http://localhost:11434/v1`

| Функция | Статус | Примечания |
|---------|--------|-------|
| `POST /v1/chat/completions` | Поддерживается | Потоковый и непотоковый режимы |
| `POST /v1/responses` | Поддерживается | OpenAI Responses API: строка/сообщение на входе, `instructions`, потоковый режим (каноническая последовательность событий), `text.format` (включая `json_schema`), function tools (непотоковый режим). Функции с состоянием (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) честно возвращают 501 |
| `POST /v1/responses/input_tokens` | Поддерживается | Предварительный подсчёт токенов (`client.responses.input_tokens.count(...)`): точное число от токенизатора Apple, без генерации; на версиях ниже macOS 26.4 возвращает 501 вместо оценки. См. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Поддерживается | Возвращает `apple-foundationmodel` (общая, по умолчанию) и `apple-foundationmodel-content-tagging` (метки, не связный текст). См. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Поддерживается | Доступность модели, окно контекста, языки, заявленные возможности модели (`capabilities`, `capabilities_reported`), вариант обслуживающей модели (`variant`, напр. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Только отладка | Требуется `--debug` |
| Вызов инструментов | Поддерживается | Вызов формируется через управляемую генерацию (`--tool-calling guided`, по умолчанию) или как JSON, который разбирает сервер (`--tool-calling text`). См. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Поддерживается | Подстановка в системный промпт; markdown-ограждения удаляются из вывода |
| `response_format: json_schema` | Поддерживается | Гарантированно соответствующий схеме вывод через FoundationModels `DynamicGenerationSchema`; работает со `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Поддерживается | Передаются в `GenerationOptions`. `top_p` - nucleus sampling; `temperature` ниже 0.001 (включая 0) соответствует жадному выбору (детерминированно). Если `max_tokens` не указан, используется оставшееся окно контекста (семантика OpenAI) - см. [Ограничение ответа по умолчанию](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Поддерживается | SSE; финальный чанк с usage только при `stream_options: {"include_usage": true}` (по спецификации OpenAI) |
| `usage` | Поддерживается | Реальные счётчики токенизатора на macOS 26.4+ (на более ранних - оценка символы/4). macOS 27: собственный учёт среды выполнения, включая обрамление чат-шаблона Apple (около 46 лишних `prompt_tokens` на однострочный промпт); macOS 26: apfel считает текст сообщений. Подробности в [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Поддерживается | `stop`, `tool_calls`, `length` |
| Стратегии контекста | Поддерживается | Дополнительные поля `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Поддерживается | Включается флагом `--cors` |
| `POST /v1/completions` | 501 | Устаревшие текстовые completions не поддерживаются |
| `POST /v1/embeddings` | 501 | Эмбеддинги недоступны на устройстве |
| `stop` | Поддерживается | Строка или до 4 строк; только обычный текст (400, если в области видимости есть инструменты или `json_object`/`json_schema`). Применяется на стороне вывода, одинаково в потоковом и непотоковом режимах. См. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Явно отклоняются. `n=1` и `logprobs=false` принимаются как пустые операции |
| Мультимодальность (изображения) | Поддерживается на macOS 27 | Части `image_url` в виде base64 data URL передаются напрямую модели на устройстве (лимит 20 MB base64, длинная сторона уменьшается до 4096 px). Удалённые `http(s)` URL и пути к файлам всегда дают 400 - apfel никогда не загружает изображения и не читает файлы для HTTP-клиента. На macOS 26: 400 с понятной ошибкой. См. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Заголовок `Authorization` | Поддерживается | Обязателен, если задан `--token`. См. [docs/server-security.md](../docs/server-security.md) |

Полная спецификация API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Ограничение ответа по умолчанию (`max_tokens`)

Когда `max_tokens` не указан, **CLI и OpenAI-совместимый сервер ведут себя одинаково**: значение передаётся как `nil`, и модель использует всё место, оставшееся в окне контекста. Это семантика OpenAI "как есть" - никакой произвольной константы по умолчанию.

Окно контекста на устройстве вмещает вход *и* выход вместе: **4096 токенов на macOS 26 и на Mac с M1/M2, 8192 токена на macOS 27 с чипом M3 или новее и 12 GB+**. apfel читает реальный размер во время работы через `SystemLanguageModel.contextSize` - проверьте свой через `apfel --model-info`. Если генерация упирается в предел, ответ корректно завершается с `finish_reason: "length"`, а частичный текст возвращается (сервер: HTTP 200; CLI: выход с кодом 0 и предупреждением в stderr, либо код 8 с `--require-complete` - см. [docs/cli-reference.md](../docs/cli-reference.md)). Указывайте `max_tokens` явно, если вам нужен более жёсткий бюджет задержки или известный предел для вашего клиента.

### Примеры

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

### Как выбрать значение

| Сценарий                               | `max_tokens`  |
|----------------------------------------|---------------|
| Ответ в одно слово / классификация     | 16 - 32       |
| Инструкция в одну строку               | 64 - 128      |
| Короткий абзац                         | 256 - 512     |
| Длинный абзац / структурированный JSON | 1024 - 2048   |
| Столько, сколько позволяет окно контекста | не указывать |

Держите `input_tokens + max_tokens` с запасом ниже окна контекста (4096 токенов на macOS 26 и на Mac с M1/M2, 8192 на macOS 27 с чипом M3 или новее и 12 GB+ (модель Apple AFM 3 Core Advanced)). Если сам промпт превышает окно, генерация не может начаться, и запрос завершается ошибкой `[context overflow]` (HTTP 400 / выход CLI с кодом 4). Валидатор отклоняет неположительные значения (`max_tokens <= 0`).

### Паритет с CLI

CLI и сервер подчиняются одному правилу: не указано = использовать оставшееся окно. Никакой константы, которая могла бы разойтись. Переопределение: `--max-tokens N` или `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Мягкие ограничители безопасности для сервера

`apfel --serve --permissive` заставляет сервер использовать ограничители Apple `.permissiveContentTransformations` для **каждого запроса**, который обрабатывает процесс. Тот же флаг и та же семантика, что у `--permissive` в CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Переопределения для отдельного запроса нет - решение принимает оператор сервера для всего процесса.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ограничения

| Ограничение | Подробности |
|------------|--------|
| Окно контекста | **4096 токенов на macOS 26 и на Mac с M1/M2, 8192 токена на macOS 27 с чипом M3 или новее и 12 GB+** (вход и выход вместе). Не жёстко заданная константа - apfel читает `SystemLanguageModel.contextSize` во время работы; `apfel --model-info` выводит актуальное значение |
| Платформа | macOS 26+, только Apple Silicon |
| Модель | Одна модель на устройстве (~3B параметров), доступная как `apple-foundationmodel` (общая) и `apple-foundationmodel-content-tagging` (адаптер Apple для тегирования контента; без инструментов) |
| Ограничители безопасности | Система безопасности Apple может блокировать безобидные промпты. `--permissive` снижает число ложных срабатываний ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Скорость | На устройстве, не в масштабе облака - несколько секунд на ответ |
| Нет эмбеддингов | Недоступны на устройстве |
| Зрение | Изображения доходят до модели только на macOS 27 (сервер: data URL; CLI: `-f photo.jpg` и изображения из конвейера, в дополнение к тексту OCR). На macOS 26 изображения передаются только как текст через OCR/классификацию. Описания сцен у модели на 3B грубые - для чтения печатного текста надёжным каналом остаётся OCR |
| Обучающие данные / дата отсечения знаний | Apple не публиковала точную дату отсечения для модели на устройстве. Если настаивать, модель **выдумывает новую дату в каждой выборке** (например, "October 2023", "April 2023"). Считайте любые заявления модели о собственном обучении ненадёжными. |
| Нет текущей даты и осведомлённости о реальном времени | Модель не знает сегодняшней даты и не имеет доступа к сети или часам. На вопрос о дате она либо откажется, либо придумает её. Передавайте текущую дату через системный промпт, если от неё зависят вычисления (см. обходной приём ниже). |

**Обходной приём для промптов, зависящих от даты** - передайте текущую дату системным сообщением:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Примечание: даже с переданной датой модель на 3B может галлюцинировать (особенно если спросить её напрямую о дате отсечения обучения). Передача даты помогает генеративным промптам, которые *используют* дату; она не отменяет рефлекс модели рассказывать о себе.

Предыстория: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Справочная документация

Руководства по использованию apfel из [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - см. [docs/guides/index.md](../docs/guides/index.md). Проверено на практике; запускаемое доказательство: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - установка, решение проблем и настройка Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - каждый флаг, код возврата и переменная окружения
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` и извлечение текста из PDF / изображений / текста через конвейер (OCR + понимание изображений)
- [docs/background-service.md](../docs/background-service.md) - использование `brew services` и launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - подробная матрица поддержки `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - проверки origin, CORS, токены и `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - стратегии обрезки чата
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - использование локального и удалённого MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - подробное поведение вызова инструментов
- [docs/integrations.md](../docs/integrations.md) - интеграции со сторонними инструментами (opencode и др.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - локальное ревью с apfel + второй моделью редактирования/применения правок в VS Code
- [docs/demos.md](../docs/demos.md) - более подробные разборы shell-демо
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - более 50 реальных промптов с неотредактированным выводом
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` для сторонних разработчиков
- [docs/coreai-impact.md](../docs/coreai-impact.md) - почему apfel работает на FoundationModels, а не на новом Core AI от Apple (преемнике Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - сравнение apfel с собственной утилитой Apple `fm` (macOS 27) по функциям, с измеренными числами

## Архитектура

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Строгая конкурентность Swift 6.3. Три таргета: `ApfelCore` (чистая логика, тестируется модульно, также доступна как продукт Swift Package - ссылка в разделе "Справочная документация" выше), `apfel` (CLI + сервер) и `apfel-tests` (чистый Swift-раннер, без XCTest).

## Сборка и тесты

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

`.version` - единственный источник истины. Версии повышает только `make release`. Локальные сборки версию не меняют.

## Дерево apfel

Проекты, построенные на apfel. Каждый поставляется как отдельный репозиторий + формула Homebrew.

| Проект | Что делает | Установка |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Корень. CLI на FoundationModels на устройстве + OpenAI-совместимый сервер. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Чат-клиент для macOS: потоковый markdown, голосовой ввод и вывод, анализ изображений через Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Действия ИИ в строке меню над буфером обмена: краткое содержание, перевод, переписывание. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Мгновенный оверлей с ИИ: нажали клавишу, спросили, получили ответ, закрыли. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Блокнот с формулами - ИИ на устройстве как встроенная функция ячейки. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP, оптимизированные по бюджету токенов для маленького окна на устройстве: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Отладочный инспектор на SwiftUI: временная шкала запросов, просмотр протокола MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-обёртка, добавляющая постоянный реестр MCP + TOML-конфиг поверх `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI для тегирования контента на устройстве: подайте текст на вход, получите теги/темы/эмоции. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-пакет для инструментов экосистемы: обнаружение, запуск и потоковое чтение из локального `apfel --serve`. | Swift Package |

## Проекты сообщества

Построили что-то на основе apfel? Откройте issue, и проект можно добавить сюда.

| Проект | Что делает | Ссылки |
|---------|-------------|-------|
| **apfelclaw** от [@julianYaman](https://github.com/julianYaman) | Локальный ИИ-агент, который читает файлы, календарь, почту и состояние Mac через инструменты только для чтения | [github](https://github.com/julianyaman/apfelclaw) - [сайт](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** от [@bhaskarvilles](https://github.com/bhaskarvilles) | Браузерный чат-интерфейс, работающий с `apfel --serve` через OpenAI-совместимый API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** от [@lucaspwo](https://github.com/lucaspwo) | Обёртка над Claude Code, подменяющая бэкенд на локальный apfel через небольшой прокси Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** от [@hasit](https://github.com/hasit) | Менеджер приложений для локальных shell-приложений на основе apfel | [github](https://github.com/hasit/apfeller) - [сайт](https://hasit.github.io/apfeller/) - [каталог](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** от [@eggsy](https://github.com/eggsy) | Расширение командной строки Raycast: вопросы, перевод, объяснение файлов и каталогов, история разговоров, собственные системные промпты. На устройстве через apfel CLI. | [магазин](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Участие в проекте

Issues и PR приветствуются в любом репозитории `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR от ИИ-агентов приветствуются. Прочитайте `CLAUDE.md` репозитория, запустите тесты, укажите инструмент в трейлере `Co-Authored-By`. Планка та же, что и для людей: чистый код, проходящие тесты, честные ограничения. Самая удобная для агентов точка входа: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([правила участия](https://apfel-mcp.franzai.com/#contribute)).

## Лицензия

[MIT](../LICENSE)
