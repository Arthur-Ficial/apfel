<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Превод на [английския README](../README.md). Английската версия е меродавна.

# apfel

### Безплатният ИИ, който вече е на вашия Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac компютрите с Apple Silicon идват с вграден LLM чрез [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` го предоставя като UNIX инструмент и като локален OpenAI-съвместим сървър. 100% на устройството. Без API ключове, без облак.

| Режим | Команда | Какво получавате |
|------|---------|--------------|
| UNIX инструмент | `apfel "prompt"` / `echo "text" \| apfel` | Отговори, удобни за конвейери, прикачване на файлове, JSON изход, изходни кодове |
| OpenAI-съвместим сървър | `apfel --serve` | Готов заместител: локален бекенд `http://localhost:11434/v1` за OpenAI SDK |

`apfel --chat` - интерактивен REPL.

[![Демо видео на apfel в терминала: истински команди, истински отговори на устройството (84 секунди)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/bg/a/apfel-ai-tutorial/#video)

Извикването на инструменти (tool calling) работи във всички контексти.

![apfel CLI](../screenshots/cli.png)

## Изисквания и инсталиране

macOS 26 Tahoe+, Apple Silicon (M1+), [включен Apple Intelligence](https://support.apple.com/en-us/121115). На macOS 27 Mac с чип M3 или по-нов и 12 GB+ памет работят с по-големия вграден модел на Apple с прозорец от 8192 токена; Mac с M1/M2 и всеки Mac с macOS 26 имат 4096. `apfel --model-info` показва вашата стойност.

```bash
brew install apfel
```

Обновяване:

```bash
brew upgrade apfel
```

Компилиране от сорс кода (Command Line Tools със SDK на macOS 27 / Swift 6.3, без Xcode; бинарният файл работи на macOS 26 и 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, оперативен tap, Mint, mise, отстраняване на проблеми: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | **Български** | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Бърз старт

### UNIX инструмент

Промптовете с `!` слагайте в единични кавички (разширяване на историята в zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-съвместим сървър

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

Подробности за фоновата услуга: [docs/background-service.md](../docs/background-service.md).

### Чат за бързо тестване

`apfel --chat` е малък REPL за тестване на промптове или MCP сървъри. За графично чат приложение вижте [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C излиза. Контекстът се изрязва автоматично ([docs/context-strategies.md](../docs/context-strategies.md)).

Ограничения, които е добре да знаете, преди да пишете скриптове (контекстен прозорец за всеки Mac, предпазни механизми, липса на ембединги): [Ограничения](../README.md#limitations).

## Демота

Истински shell скриптове около `apfel`: `cmd` (английски към shell команда), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Те са вградени в бинарния файл - не е нужно да клонирате репозиторито. Запишете ги там, откъдето сте инсталирали apfel (homebrew-core, tap или сорс код):

```bash
apfel demos ./apfel-demos
```

Командата записва всички демота (изпълними) и `README.md` в `./apfel-demos`. След това ги стартирайте оттам:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Стартирайте `apfel demos` отново след `brew upgrade apfel`, за да ги обновите. Сорс код: [`demo/`](../demo/). Подробни разбори и shell функция `cmd` за поставяне в `.zshrc`: [docs/demos.md](../docs/demos.md).

## Поддръжка на MCP инструменти

Свързвайте сървъри на [Model Context Protocol](https://modelcontextprotocol.io/) с `--mcp`. apfel открива инструментите, извиква ги и връща резултата.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Използвайте `-q`, за да скриете информацията за инструментите.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Включен е калкулатор в [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Отдалечени MCP сървъри** (Streamable HTTP, MCP спецификация 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Сигурност:** предпочитайте `APFEL_MCP_TOKEN` пред `--mcp-token` (вижда се в ps aux). apfel отказва да изпраща bearer токени през обикновен `http://`.

## apfel-run: незадължителен слой за конфигурация

Самият apfel няма конфигурационен файл - само флагове и променливи на средата, като всеки UNIX инструмент. Ако искате TOML конфигурация (много MCP, профили, екипни конфигурации в git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) е обвивка под лиценз MIT, която я добавя като drop-in чрез `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Съвместимост с OpenAI API

**Базов URL:** `http://localhost:11434/v1`

| Функция | Статус | Бележки |
|---------|--------|-------|
| `POST /v1/chat/completions` | Поддържа се | Поточен и непоточен режим |
| `POST /v1/responses` | Поддържа се | OpenAI Responses API: низ/съобщение като вход, `instructions`, поточен режим (каноничната последователност от събития), `text.format` (включително `json_schema`), function tools (непоточен режим). Функциите със състояние (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) честно връщат 501 |
| `POST /v1/responses/input_tokens` | Поддържа се | Предварително преброяване на токени (`client.responses.input_tokens.count(...)`): точен брой от токенизатора на Apple, без генериране; под macOS 26.4 връща 501 вместо приблизителна оценка. Вижте [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Поддържа се | Връща `apple-foundationmodel` |
| `GET /health` | Поддържа се | Наличност на модела, контекстен прозорец, езици, обявени възможности на модела (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Само за отстраняване на грешки | Изисква `--debug` |
| Извикване на инструменти | Поддържа се | Нативен `ToolDefinition` + откриване на JSON. Вижте [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Поддържа се | Вмъкване в системния промпт; markdown оградите се премахват от изхода |
| `response_format: json_schema` | Поддържа се | Гарантирано съответстващ на схемата изход чрез FoundationModels `DynamicGenerationSchema`; работи със `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Поддържа се | Предават се към `GenerationOptions`. `top_p` е nucleus sampling; `temperature` под 0.001 (включително 0) съответства на greedy избор (детерминирано). Ако `max_tokens` е пропуснат, се използва оставащият контекстен прозорец (семантика на OpenAI) - вижте [Ограничение на отговора по подразбиране](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Поддържа се | SSE; финален чънк с usage само при `stream_options: {"include_usage": true}` (според спецификацията на OpenAI) |
| `usage` | Поддържа се | Реални броячи на токенизатора на macOS 26.4+ (по-ниските версии - оценка символи/4). macOS 27: собственото отчитане на средата за изпълнение, включително обрамчването на чат шаблона на Apple (около 46 допълнителни `prompt_tokens` за еднореден промпт); macOS 26: apfel брои текста на съобщенията. Подробности в [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Поддържа се | `stop`, `tool_calls`, `length` |
| Стратегии за контекст | Поддържа се | Допълнителни полета `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Поддържа се | Включва се с `--cors` |
| `POST /v1/completions` | 501 | Остарелите текстови completions не се поддържат |
| `POST /v1/embeddings` | 501 | Ембедингите не са налични на устройството |
| `stop` | Поддържа се | Низ или до 4 низа; само обикновен текст (400, ако в обхвата има инструменти или `json_object`/`json_schema`). Прилага се от страната на изхода, еднакво в поточен и непоточен режим. Вижте [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Отхвърлят се изрично. `n=1` и `logprobs=false` се приемат като празни операции |
| Мултимодалност (изображения) | Поддържа се на macOS 27 | Частите `image_url` като base64 data URL отиват директно към модела на устройството (лимит 20 MB base64, по-дългата страна се свива до 4096 px). Отдалечени `http(s)` URL и пътища до файлове винаги дават 400 - apfel никога не изтегля изображения и не чете файлове за HTTP клиент. На macOS 26: 400 с ясна грешка. Вижте [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Хедър `Authorization` | Поддържа се | Задължителен, когато е зададен `--token`. Вижте [docs/server-security.md](../docs/server-security.md) |

Пълна API спецификация: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Ограничение на отговора по подразбиране (`max_tokens`)

Когато `max_tokens` е пропуснат, **CLI и OpenAI-съвместимият сървър се държат еднакво**: стойността се предава като `nil` и моделът използва цялото място, останало в контекстния прозорец. Това е семантиката на OpenAI "както си е" - без произволна константа по подразбиране.

Контекстният прозорец на устройството побира вход *и* изход заедно: **4096 токена на macOS 26 и на Mac с M1/M2, 8192 токена на macOS 27 с чип M3 или по-нов и 12 GB+**. apfel чете реалния размер по време на изпълнение чрез `SystemLanguageModel.contextSize` - проверете вашия с `apfel --model-info`. Ако генерирането опре до тавана, отговорът завършва чисто с `finish_reason: "length"` и се връща частичното съдържание (сървър: HTTP 200; CLI: изход с код 0 и предупреждение в stderr, или код 8 с `--require-complete` - вижте [docs/cli-reference.md](../docs/cli-reference.md)). Задавайте `max_tokens` изрично, когато искате по-строг бюджет за латентност или известен лимит за вашия клиент.

### Примери

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

### Избор на стойност

| Случай на употреба                     | `max_tokens`  |
|----------------------------------------|---------------|
| Отговор от една дума / класификация    | 16 - 32       |
| Инструкция от един ред                 | 64 - 128      |
| Кратък параграф                        | 256 - 512     |
| Дълъг параграф / структуриран JSON     | 1024 - 2048   |
| Колкото позволява контекстният прозорец | пропуснете го |

Дръжте `input_tokens + max_tokens` с резерв под контекстния прозорец (4096 токена на macOS 26 и на Mac с M1/M2, 8192 на macOS 27 с чип M3 или по-нов и 12 GB+ (моделът AFM 3 Core Advanced на Apple)). Ако самият промпт надвишава прозореца, генерирането не може да започне и заявката завършва с грешка `[context overflow]` (HTTP 400 / изход на CLI с код 4). Валидаторът отхвърля неположителни стойности (`max_tokens <= 0`).

### Паритет с CLI

CLI и сървърът следват едно правило: пропуснато = използва се оставащият прозорец. Няма константа, която да се разминава. Презаписване с `--max-tokens N` или `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Меки предпазни механизми за сървъра

`apfel --serve --permissive` кара сървъра да използва предпазните механизми `.permissiveContentTransformations` на Apple за **всяка заявка**, която процесът обработва. Същият флаг и същата семантика като `--permissive` в CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Няма презаписване за отделна заявка - решението е на оператора на сървъра за целия процес.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ограничения

| Ограничение | Подробности |
|------------|--------|
| Контекстен прозорец | **4096 токена на macOS 26 и на Mac с M1/M2, 8192 токена на macOS 27 с чип M3 или по-нов и 12 GB+** (вход и изход заедно). Не е твърдо зададена константа - apfel чете `SystemLanguageModel.contextSize` по време на изпълнение; `apfel --model-info` извежда актуалната стойност |
| Платформа | macOS 26+, само Apple Silicon |
| Модел | Един модел (`apple-foundationmodel`, ~3B параметъра на устройството), не се конфигурира |
| Предпазни механизми | Системата за безопасност на Apple може да блокира безобидни промптове. `--permissive` намалява фалшивите задействания ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Скорост | На устройството, не в облачен мащаб - няколко секунди за отговор |
| Няма ембединги | Не са налични на устройството |
| Зрение | Изображенията достигат до модела само на macOS 27 (сървър: data URL; CLI: `-f photo.jpg` и изображения през конвейер, освен OCR текста). На macOS 26 изображенията се предават само като текст чрез OCR/класификация. Описанията на сцени от модела с 3B са груби - за четене на печатен текст OCR остава надеждният канал |
| Обучителни данни / дата на отсичане на знанията | Apple не е публикувала точна дата на отсичане за модела на устройството. Когато го притиснат да назове такава, моделът **измисля различна дата при всяка проба** (напр. "October 2023", "April 2023"). Смятайте всички твърдения на модела за собственото му обучение за ненадеждни. |
| Няма текуща дата и усещане за реално време | Моделът не знае днешната дата и няма достъп до мрежа или часовник. При запитване или ще откаже, или ще измисли дата. Подавайте текущата дата през системния промпт, когато изчисленията зависят от нея (вижте заобиколното решение по-долу). |

**Заобиколно решение за промптове, зависещи от датата** - подайте текущата дата като системно съобщение:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Забележка: дори с подадена дата моделът с 3B може да халюцинира (особено ако го попитате директно за датата на отсичане на обучението му). Подаването на датата помага при генеративни промптове, които *използват* датата; то не отменя рефлекса на модела да разказва за себе си.

Контекст: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Справочна документация

Ръководства за използване на apfel от [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - вижте [docs/guides/index.md](../docs/guides/index.md). Тествано емпирично; изпълним пример: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - инсталиране, отстраняване на проблеми и настройка на Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - всеки флаг, изходен код и променлива на средата
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` и извличане на PDF / изображения / текст през конвейер (OCR + разбиране на изображения)
- [docs/background-service.md](../docs/background-service.md) - използване на `brew services` и launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - подробна матрица на поддръжката на `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - проверки на origin, CORS, токени и `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - стратегии за изрязване на чата
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - използване на локален и отдалечен MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - подробно поведение при извикване на инструменти
- [docs/integrations.md](../docs/integrations.md) - интеграции с инструменти на трети страни (opencode и др.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - локално ревю с apfel + втори модел за редактиране/прилагане в VS Code
- [docs/demos.md](../docs/demos.md) - по-подробни разбори на shell демотата
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - над 50 реални промпта с нередактиран изход
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` за разработчици надолу по веригата
- [docs/coreai-impact.md](../docs/coreai-impact.md) - защо apfel работи върху FoundationModels, а не върху новия Core AI на Apple (наследника на Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel в сравнение с вградения инструмент на Apple `fm` (macOS 27), функция по функция с измерени числа

## Архитектура

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Строга конкурентност на Swift 6.3. Три таргета: `ApfelCore` (чиста логика, тества се с unit тестове, достъпна и като продукт Swift Package - връзка в "Справочна документация" по-горе), `apfel` (CLI + сървър) и `apfel-tests` (чист Swift тестов изпълнител, без XCTest).

## Компилиране и тестове

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

`.version` е единственият източник на истина. Само `make release` вдига версиите. Локалните компилации не променят версията.

## Дървото на apfel

Проекти, изградени върху apfel. Всеки се доставя като отделно репозитори + формула за Homebrew.

| Проект | Какво прави | Инсталиране |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Коренът. CLI върху FoundationModels на устройството + OpenAI-съвместим сървър. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Чат клиент за macOS: поточен markdown, гласов вход и изход, анализ на изображения с Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ИИ действия в лентата с менюта върху клипборда: обобщаване, превод, пренаписване. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Мигновен ИИ оверлей: натискате клавиш, питате, получавате отговор, затваряте. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Бележник с формули - ИИ на устройството като вградена функция в клетка. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP, оптимизирани по бюджет от токени за малкия прозорец на устройството: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Инспектор за отстраняване на грешки в SwiftUI: времева линия на заявките, преглед на MCP протокола, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX обвивка, която добавя постоянен MCP регистър + TOML конфигурация върху `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI за тагване на съдържание на устройството: подавате текст, получавате тагове/теми/емоции. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift пакет за инструментите от екосистемата: откриване, стартиране и поточно четене от локален `apfel --serve`. | Swift Package |

## Проекти на общността

Създадохте нещо върху apfel? Отворете issue и проектът може да бъде добавен тук.

| Проект | Какво прави | Връзки |
|---------|-------------|-------|
| **apfelclaw** от [@julianYaman](https://github.com/julianYaman) | Локален ИИ агент, който чете файлове, календар, поща и състоянието на Mac чрез инструменти само за четене | [github](https://github.com/julianyaman/apfelclaw) - [сайт](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** от [@bhaskarvilles](https://github.com/bhaskarvilles) | Чат интерфейс в браузъра, който работи с `apfel --serve` през OpenAI-съвместимия API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** от [@lucaspwo](https://github.com/lucaspwo) | Обвивка около Claude Code, която подменя бекенда с локален apfel чрез малък Anthropic-OpenAI прокси | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** от [@hasit](https://github.com/hasit) | Мениджър на приложения за локални shell приложения, изградени около apfel | [github](https://github.com/hasit/apfeller) - [сайт](https://hasit.github.io/apfeller/) - [каталог](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** от [@eggsy](https://github.com/eggsy) | Разширение за командната лента на Raycast: въпроси, превод, обяснение на файлове и директории, история на разговорите, собствени системни промптове. На устройството чрез apfel CLI. | [магазин](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Принос

Issues и PR са добре дошли във всяко репозитори `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR от ИИ агенти са приемливи. Прочетете `CLAUDE.md` на репозиторито, пуснете тестовете, посочете инструмента в trailer `Co-Authored-By`. Същата летва като за хората: чист код, преминаващи тестове, честни ограничения. Най-удобната за агенти входна точка: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([правила за принос](https://apfel-mcp.franzai.com/#contribute)).

## Лиценз

[MIT](../LICENSE)
