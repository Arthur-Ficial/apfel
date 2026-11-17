<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> Препод од [англискиот README](../README.md). Англиската верзија е меродавна.

# apfel

### Бесплатната вештачка интелигенција што веќе е на вашиот Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac компјутерите со Apple Silicon доаѓаат со вграден LLM преку [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` го прикажува како UNIX алатка и како локален OpenAI-компатибилен сервер. 100% на уредот. Без API клучеви, без облак.

| Режим | Команда | Што добивате |
|------|---------|--------------|
| UNIX алатка | `apfel "prompt"` / `echo "text" \| apfel` | Одговори погодни за pipe, прикачување датотеки, JSON излез, излезни кодови |
| OpenAI-компатибилен сервер | `apfel --serve` | Готова замена: локален бекенд `http://localhost:11434/v1` за OpenAI SDK |

`apfel --chat` - интерактивен REPL.

[![Демо видео за apfel во терминал: вистински команди, вистински одговори на уредот (82 секунди)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/mk/a/apfel-ai-tutorial/#video)

Повикувањето алатки (tool calling) работи во сите контексти.

![apfel CLI](../screenshots/cli.png)

## Барања и инсталација

macOS 26 Tahoe+, Apple Silicon (M1+), [вклучен Apple Intelligence](https://support.apple.com/en-us/121115). На macOS 27, Mac со чип M3 или понов и 12 GB+ меморија го користат поголемиот вграден модел на Apple со прозорец од 8192 токени; Mac со M1/M2 и секој Mac со macOS 26 имаат 4096. `apfel --model-info` ја прикажува вашата вредност.

```bash
brew install apfel
```

Ажурирање:

```bash
brew upgrade apfel
```

Градење од изворниот код (Command Line Tools со SDK на macOS 27 / Swift 6.3, без Xcode; бинарната датотека работи на macOS 26 и 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap за истиот ден, Mint, mise, решавање проблеми: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | **Македонски** | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Брз почеток

### UNIX алатка

Промптите со `!` ставајте ги во единечни наводници (проширување на историјата во zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-компатибилен сервер

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

Детали за услугата во позадина: [docs/background-service.md](../docs/background-service.md).

### Чат за брзо тестирање

`apfel --chat` е мал REPL за тестирање промптови или MCP сервери. За графичка чат апликација, видете [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C излегува. Контекстот се скратува автоматски ([docs/context-strategies.md](../docs/context-strategies.md)).

Ограничувања што вреди да ги знаете пред да пишувате скрипти (контекстен прозорец по Mac, заштитни механизми, нема ембединзи): [Ограничувања](../README.md#limitations).

## Демоа

Вистински shell скрипти околу `apfel`: `cmd` (англиски во shell команда), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Вградени се во бинарната датотека - не е потребно клонирање на репозиториумот. Запишете ги таму каде што сте го инсталирале apfel (homebrew-core, tap или изворен код):

```bash
apfel demos ./apfel-demos
```

Командата ги запишува сите демоа (извршни) и `README.md` во `./apfel-demos`. Потоа стартувајте ги оттаму:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Повторно стартувајте `apfel demos` по `brew upgrade apfel` за да ги освежите. Изворен код: [`demo/`](../demo/). Подетални водичи и shell функција `cmd` за копирање во `.zshrc`: [docs/demos.md](../docs/demos.md).

## Поддршка за MCP алатки

Приклучете сервери на [Model Context Protocol](https://modelcontextprotocol.io/) со `--mcp`. apfel ги открива алатките, ги повикува и го враќа резултатот.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Користете `-q` за да ги скриете информациите за алатките.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Се испорачува со калкулатор во [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Далечински MCP сервери** (Streamable HTTP, MCP спецификација 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Безбедност:** претпочитајте `APFEL_MCP_TOKEN` наместо `--mcp-token` (се гледа во ps aux). apfel одбива да праќа bearer токени преку обичен `http://`.

## apfel-run: изборен слој за конфигурација

Самиот apfel нема конфигурациска датотека - само знамиња и променливи на околината, како секоја UNIX алатка. Ако сакате TOML конфигурација (многу MCP, профили, тимски конфигурации во git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) е обвивка под лиценца MIT што ја додава како drop-in преку `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Компатибилност со OpenAI API

**Основен URL:** `http://localhost:11434/v1`

| Функција | Статус | Забелешки |
|---------|--------|-------|
| `POST /v1/chat/completions` | Поддржано | Стриминг и без стриминг |
| `POST /v1/responses` | Поддржано | OpenAI Responses API: низа/порака како влез, `instructions`, стриминг (канонска низа настани), `text.format` (вклучувајќи `json_schema`), function tools (без стриминг). Функциите со состојба (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) искрено враќаат 501 |
| `POST /v1/responses/input_tokens` | Поддржано | Претходно броење токени (`client.responses.input_tokens.count(...)`): точен број од токенизаторот на Apple, без генерирање; под macOS 26.4 враќа 501 наместо проценка. Видете [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Поддржано | Враќа `apple-foundationmodel` (општ, стандарден) и `apple-foundationmodel-content-tagging` (ознаки, не слободен текст). Видете [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Поддржано | Достапност на моделот, контекстен прозорец, јазици, пријавени можности на моделот (`capabilities`, `capabilities_reported`), варијантата на моделот што опслужува (`variant`, на пр. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Само за дебагирање | Бара `--debug` |
| Повикување алатки | Поддржано | Повикот се пишува со водено генерирање (`--tool-calling guided`, стандардно) или како JSON што серверот го парсира (`--tool-calling text`). Видете [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Поддржано | Вметнување во системскиот промпт; markdown оградите се отстрануваат од излезот |
| `response_format: json_schema` | Поддржано | Загарантиран излез што одговара на шемата преку FoundationModels `DynamicGenerationSchema`; работи со `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Поддржано | Се пренесуваат на `GenerationOptions`. `top_p` е nucleus sampling; `temperature` под 0.001 (вклучувајќи 0) одговара на greedy избор (детерминистички). Ако `max_tokens` е испуштен, се користи преостанатиот контекстен прозорец (семантика на OpenAI) - видете [Ограничување на одговорот по default](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Поддржано | SSE; завршен чанк со usage само при `stream_options: {"include_usage": true}` (според спецификацијата на OpenAI) |
| `usage` | Поддржано | Вистински броеви од токенизаторот на macOS 26.4+ (под тоа - проценка знаци/4). macOS 27: сопствено сметководство на runtime-от, вклучувајќи го обрамувањето на чат шаблонот на Apple (околу 46 дополнителни `prompt_tokens` за еднолиниски промпт); macOS 26: apfel го брои текстот на пораките. Детали во [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Поддржано | `stop`, `tool_calls`, `length` |
| Стратегии за контекст | Поддржано | Дополнителни полиња `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Поддржано | Се вклучува со `--cors` |
| `POST /v1/completions` | 501 | Застарените текстуални completions не се поддржани |
| `POST /v1/embeddings` | 501 | Ембединзите не се достапни на уредот |
| `stop` | Поддржано | Низа или до 4 низи; само обичен текст (400 ако има алатки во опсег или `json_object`/`json_schema`). Се применува на страната на излезот, идентично при стриминг и без стриминг. Видете [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Експлицитно се одбиваат. `n=1` и `logprobs=false` се прифаќаат како празни операции |
| Мултимодално (слики) | Поддржано на macOS 27 | Деловите `image_url` како base64 data URL одат директно до моделот на уредот (лимит од 20 MB base64, подолгата страна се намалува до 4096 px). Далечински `http(s)` URL и патеки до датотеки секогаш даваат 400 - apfel никогаш не презема слики и не чита датотеки за HTTP клиент. На macOS 26: 400 со јасна грешка. Видете [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Заглавие `Authorization` | Поддржано | Задолжително кога е поставен `--token`. Видете [docs/server-security.md](../docs/server-security.md) |

Целосна API спецификација: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Стандардно ограничување на одговорот (`max_tokens`)

Кога `max_tokens` е испуштен, **CLI и OpenAI-компатибилниот сервер се однесуваат идентично**: вредноста се пренесува како `nil` и моделот го користи целиот простор што останал во контекстниот прозорец. Ова е семантика на OpenAI "како што е" - без произволна резервна константа.

Контекстниот прозорец на уредот собира влез *и* излез заедно: **4096 токени на macOS 26 и на Mac со M1/M2, 8192 токени на macOS 27 со чип M3 или понов и 12 GB+**. apfel ја чита вистинската големина за време на работа преку `SystemLanguageModel.contextSize` - проверете ја вашата со `apfel --model-info`. Ако генерирањето стигне до границата, одговорот завршува чисто со `finish_reason: "length"` и се враќа делумната содржина (сервер: HTTP 200; CLI: излез со код 0 и предупредување на stderr, или код 8 со `--require-complete` - видете [docs/cli-reference.md](../docs/cli-reference.md)). Поставете `max_tokens` експлицитно кога сакате построг буџет за латентност или позната граница за вашиот клиент.

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

### Избор на вредност

| Случај на употреба                     | `max_tokens`  |
|----------------------------------------|---------------|
| Одговор од еден збор / класификација   | 16 - 32       |
| Инструкција од една линија             | 64 - 128      |
| Краток параграф                        | 256 - 512     |
| Долг параграф / структуриран JSON      | 1024 - 2048   |
| Колку што дозволува контекстниот прозорец | испуштете го |

Држете го `input_tokens + max_tokens` удобно под контекстниот прозорец (4096 токени на macOS 26 и на Mac со M1/M2, 8192 на macOS 27 со чип M3 или понов и 12 GB+ (моделот AFM 3 Core Advanced на Apple)). Ако самиот промпт го надминува прозорецот, генерирањето не може да започне и барањето завршува со грешка `[context overflow]` (HTTP 400 / излез на CLI со код 4). Валидаторот ги одбива непозитивните вредности (`max_tokens <= 0`).

### Паритет со CLI

CLI и серверот имаат едно правило: испуштено = користи го преостанатиот прозорец. Нема константа што може да се раздвои. Заменете со `--max-tokens N` или `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Попустливи заштитни механизми за серверот

`apfel --serve --permissive` го тера серверот да ги користи заштитните механизми `.permissiveContentTransformations` на Apple за **секое барање** што го обработува процесот. Исто знаме, иста семантика како `--permissive` во CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Нема замена по барање - одлуката ја носи операторот на серверот за целиот процес.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Ограничувања

| Ограничување | Детали |
|------------|--------|
| Контекстен прозорец | **4096 токени на macOS 26 и на Mac со M1/M2, 8192 токени на macOS 27 со чип M3 или понов и 12 GB+** (влез и излез заедно). Не е цврсто зададена константа - apfel го чита `SystemLanguageModel.contextSize` за време на работа; `apfel --model-info` ја печати тековната вредност |
| Платформа | macOS 26+, само Apple Silicon |
| Модел | Еден модел на уредот (~3B параметри), достапен како `apple-foundationmodel` (општ) и `apple-foundationmodel-content-tagging` (адаптерот на Apple за означување содржина; без алатки) |
| Заштитни механизми | Безбедносниот систем на Apple може да блокира безопасни промптови. `--permissive` ги намалува лажните активирања ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Брзина | На уредот, не во облачна размера - неколку секунди по одговор |
| Нема ембединзи | Не се достапни на уредот |
| Вид | Сликите стигнуваат до моделот само на macOS 27 (сервер: data URL; CLI: `-f photo.jpg` и слики преку pipe, покрај OCR текстот). На macOS 26 сликите се само текст преку OCR/класификација. Описите на сцени од моделот со 3B се груби - OCR останува доверливиот канал за читање печатен текст |
| Податоци за обука / граница на знаење | Apple не објавила точна граница за моделот на уредот. Кога ќе се притисне да именува една, моделот **измислува различен датум при секоја проба** (на пр. "October 2023", "April 2023"). Сметајте ги сите изјави на моделот за сопствената обука за недоверливи. |
| Нема тековен датум и свесност за реално време | Моделот не го знае денешниот датум и нема пристап до мрежа или часовник. Ако го прашате, или ќе одбие или ќе измисли датум. Вметнете го тековниот датум преку системскиот промпт кога пресметките зависат од него (видете го заобиколувањето подолу). |

**Заобиколување за промптови што зависат од датум** - вметнете го тековниот датум како системска порака:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Забелешка: дури и со вметнат датум моделот со 3B сè уште може да халуцинира (особено кога се прашува директно за границата на неговата обука). Вметнувањето помага кај генеративни промптови што го *користат* датумот; не го поништува рефлексот на моделот да зборува за себе.

Позадина: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Референтна документација

Водичи за користење на apfel од [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - видете [docs/guides/index.md](../docs/guides/index.md). Емпириски тестирано; извршлив доказ: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - инсталација, решавање проблеми и поставување на Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - секое знаме, излезен код и променлива на околината
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` и извлекување од PDF / слика / текст преку pipe (OCR + разбирање слики)
- [docs/background-service.md](../docs/background-service.md) - користење на `brew services` и launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - длабинска матрица на поддршка за `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - проверки на origin, CORS, токени и `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - стратегии за скратување на чатот
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - користење на локален и далечински MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - детално однесување при повикување алатки
- [docs/integrations.md](../docs/integrations.md) - интеграции со алатки од трети страни (opencode итн.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - локален преглед со apfel + втор модел за уредување/примена во VS Code
- [docs/demos.md](../docs/demos.md) - подолги водичи за shell демоата
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50+ вистински промптови со неуреден излез
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` за програмери надолу по синџирот
- [docs/coreai-impact.md](../docs/coreai-impact.md) - зошто apfel работи на FoundationModels, а не на новиот Core AI на Apple (наследникот на Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel споредено со сопствената алатка на Apple `fm` (macOS 27), функција по функција со измерени бројки

## Архитектура

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Строга истовременост на Swift 6.3. Три таргети: `ApfelCore` (чиста логика, може да се тестира со unit тестови, достапна и како Swift Package производ - врска под Референтна документација погоре), `apfel` (CLI + сервер) и `apfel-tests` (чист Swift извршувач, без XCTest).

## Градење и тестови

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

`.version` е единствениот извор на вистина. Само `make release` ги зголемува верзиите. Локалните градења не ја менуваат верзијата.

## Дрвото на apfel

Проекти изградени врз apfel. Секој се испорачува како посебен репозиториум + Homebrew формула.

| Проект | Што прави | Инсталација |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Коренот. CLI врз FoundationModels на уредот + OpenAI-компатибилен сервер. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Чат клиент за macOS: стриминг markdown, говорен влез и излез, анализа на слики со Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | ИИ дејства во лентата со менија врз клипбордот: сумирање, превод, препишување. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Моментален ИИ оверлеј: притиснете копче, прашајте, добијте одговор, затворете. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Тетратка со формули - ИИ на уредот како вградена функција во ќелија. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP оптимизирани по буџет на токени за малиот прозорец на уредот: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI инспектор за дебагирање: временска линија на барања, преглед на MCP протоколот, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX обвивка што додава постојан MCP регистар + TOML конфигурација врз `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI за означување содржина на уредот: внесете текст, добијте ознаки/теми/емоции. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift пакет за алатките од екосистемот: откривање, стартување и стриминг од локален `apfel --serve`. | Swift Package |

## Проекти на заедницата

Изградивте нешто врз apfel? Отворете issue и проектот може да се додаде овде.

| Проект | Што прави | Врски |
|---------|-------------|-------|
| **apfelclaw** од [@julianYaman](https://github.com/julianYaman) | Локален ИИ агент што чита датотеки, календар, пошта и состојба на Mac преку алатки само за читање | [github](https://github.com/julianyaman/apfelclaw) - [сајт](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** од [@bhaskarvilles](https://github.com/bhaskarvilles) | Чат интерфејс во прелистувач што комуницира со `apfel --serve` преку OpenAI-компатибилниот API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** од [@lucaspwo](https://github.com/lucaspwo) | Обвивка за Claude Code што го заменува бекендот со локален apfel преку мал Anthropic-OpenAI прокси | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** од [@hasit](https://github.com/hasit) | Менаџер на апликации за локални shell апликации изградени околу apfel | [github](https://github.com/hasit/apfeller) - [сајт](https://hasit.github.io/apfeller/) - [каталог](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** од [@eggsy](https://github.com/eggsy) | Проширување за командната лента на Raycast: прашања, превод, објаснување датотеки и директориуми, историја на разговори, сопствени системски промптови. На уредот преку apfel CLI. | [продавница](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Придонесување

Issues и PR се добредојдени во секој репозиториум `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR од ИИ агенти се во ред. Прочитајте го `CLAUDE.md` на репозиториумот, стартувајте ги тестовите, наведете ја алатката во trailer `Co-Authored-By`. Иста мерка како за луѓето: чист код, поминати тестови, искрени ограничувања. Најпогодна влезна точка за агенти: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([правила за придонес](https://apfel-mcp.franzai.com/#contribute)).

## Лиценца

[MIT](../LICENSE)
