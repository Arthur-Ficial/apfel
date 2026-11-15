<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Пераклад [англійскага README](../README.md). Англійская версія з'яўляецца асноўнай.

# apfel

### Бясплатны ШІ, які ўжо ёсць на вашым Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Mac на Apple Silicon пастаўляюцца са ўбудаванай LLM праз [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` адкрывае яе як UNIX-утыліту і як лакальны OpenAI-сумяшчальны сервер. 100% на прыладзе. Без API-ключоў, без воблака.

| Рэжым | Каманда | Што вы атрымліваеце |
|------|---------|--------------|
| UNIX-утыліта | `apfel "prompt"` / `echo "text" \| apfel` | Адказы, зручныя для канвеераў, далучэнне файлаў, вывад у JSON, коды вяртання |
| OpenAI-сумяшчальны сервер | `apfel --serve` | Гатовая замена: лакальны бэкенд `http://localhost:11434/v1` для OpenAI SDK |

`apfel --chat` - інтэрактыўны REPL.

[![Дэмаадэа apfel у тэрмінале: сапраўдныя каманды, сапраўдныя адказы на прыладзе (84 секунды)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/be/a/apfel-ai-tutorial/#video)

Выклік інструментаў (tool calling) працуе ва ўсіх кантэкстах.

![apfel CLI](../screenshots/cli.png)

## Патрабаванні і ўстаноўка

macOS 26 Tahoe+, Apple Silicon (M1+), [уключаны Apple Intelligence](https://support.apple.com/en-us/121115). На macOS 27 Mac з чыпам M3 або навейшым і 12 GB+ памяці выкарыстоўваюць большую ўбудаваную мадэль Apple з акном у 8192 токены; Mac на M1/M2 і кожны Mac на macOS 26 маюць 4096. `apfel --model-info` пакажа ваша значэнне.

```bash
brew install apfel
```

Абнаўленне:

```bash
brew upgrade apfel
```

Зборка з зыходнікаў (Command Line Tools з SDK macOS 27 / Swift 6.3, без Xcode; бінарны файл працуе на macOS 26 і 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, аператыўны tap, Mint, mise, вырашэнне праблем: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | **Беларуская** | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Хуткі пачатак

### UNIX-утыліта

Промпты з `!` бярыце ў адзінарныя двукоссі (пашырэнне гісторыі ў zsh/bash): `apfel 'Hello, Mac!'`.

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

### OpenAI-сумяшчальны сервер

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

Падрабязнасці пра фонавую службу: [docs/background-service.md](../docs/background-service.md).

### Чат для хуткай праверкі

`apfel --chat` - невялікі REPL для праверкі промптаў або MCP-сервераў. Графічная чат-праграма: [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C завяршае працу. Кантэкст абрэзаецца аўтаматычна ([docs/context-strategies.md](../docs/context-strategies.md)).

Абмежаванні, якія варта ведаць, перш чым пісаць скрыпты (акно кантэксту для кожнага Mac, абарончыя механізмы, адсутнасць эмбедынгаў): [Абмежаванні](../README.md#limitations).

## Дэма

Сапраўдныя shell-скрыпты вакол `apfel`: `cmd` (англійская ў shell-каманду), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Яны ўбудаваны ў бінарны файл - клананне рэпазіторыя не патрэбна. Запішыце іх туды, адкуль вы ўсталявалі apfel (homebrew-core, tap або зыходнікі):

```bash
apfel demos ./apfel-demos
```

Каманда запісвае ўсе дэма (выканальныя) і `README.md` у `./apfel-demos`. Потым запускайце іх адтуль:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Запускайце `apfel demos` нанова пасля `brew upgrade apfel`, каб абнавіць іх. Зыходнікі: [`demo/`](../demo/). Падрабязныя разборы і shell-функцыя `cmd` для ўстаўкі ў `.zshrc`: [docs/demos.md](../docs/demos.md).

## Падтрымка інструментаў MCP

Падключайце серверы [Model Context Protocol](https://modelcontextprotocol.io/) праз `--mcp`. apfel знаходзіць інструменты, выклікае іх і вяртае вынік.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Выкарыстоўвайце `-q`, каб схаваць інфармацыю пра інструменты.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

У камплекце ідзе калькулятар у [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Выдаленыя MCP-серверы** (Streamable HTTP, спецыфікацыя MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Бяспека:** выкарыстоўвайце `APFEL_MCP_TOKEN`, а не `--mcp-token` (бачны ў ps aux). apfel адмаўляецца перадаваць bearer-токены па адкрытым `http://`.

## apfel-run: неабавязковы пласт канфігурацыі

У самога apfel няма файла канфігурацыі - толькі сцягі і зменныя асяроддзя, як у любой UNIX-утыліты. Калі вам патрэбны TOML-канфіг (шмат MCP, профілі, камандныя канфігі ў git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) - абгортка пад ліцэнзіяй MIT, якая дадае яго як drop-in праз `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Сумяшчальнасць з OpenAI API

**Базавы URL:** `http://localhost:11434/v1`

| Функцыя | Статус | Заўвагі |
|---------|--------|-------|
| `POST /v1/chat/completions` | Падтрымліваецца | Струменевы і нестружнявы рэжымы |
| `POST /v1/responses` | Падтрымліваецца | OpenAI Responses API: радок/паведамленне на ўваходзе, `instructions`, струменевы рэжым (кананічная паслядоўнасць падзей), `text.format` (уключна з `json_schema`), function tools (нестружнявы рэжым). Функцыі са станам (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) сумленна вяртаюць 501 |
| `POST /v1/responses/input_tokens` | Падтрымліваецца | Папярэдні падлік токенаў (`client.responses.input_tokens.count(...)`): дакладная колькасць ад токенізатара Apple, без генерацыі; на версіях ніжэй за macOS 26.4 вяртае 501 замест ацэнкі. Гл. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Падтрымліваецца | Вяртае `apple-foundationmodel` |
| `GET /health` | Падтрымліваецца | Даступнасць мадэлі, акно кантэксту, мовы, заяўленыя магчымасці мадэлі (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Толькі адладка | Патрабуецца `--debug` |
| Выклік інструментаў | Падтрымліваецца | Натыўны `ToolDefinition` + выяўленне JSON. Гл. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Падтрымліваецца | Падстаноўка ў сістэмны промпт; markdown-агароджы выдаляюцца з вываду |
| `response_format: json_schema` | Падтрымліваецца | Гарантавана адпаведны схеме вывад праз FoundationModels `DynamicGenerationSchema`; працуе са `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Падтрымліваецца | Перадаюцца ў `GenerationOptions`. `top_p` - nucleus sampling; `temperature` ніжэй за 0.001 (уключна з 0) адпавядае прагнаму выбару (дэтэрмінавана). Калі `max_tokens` не пазначаны, выкарыстоўваецца астатняе акно кантэксту (семантыка OpenAI) - гл. [Абмежаванне адказу па змаўчанні](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Падтрымліваецца | SSE; фінальны чанк з usage толькі пры `stream_options: {"include_usage": true}` (паводле спецыфікацыі OpenAI) |
| `usage` | Падтрымліваецца | Рэальныя лічыльнікі токенізатара на macOS 26.4+ (на больш ранніх - ацэнка сімвалы/4). macOS 27: уласны ўлік асяроддзя выканання, уключна з абрамленнем чат-шаблона Apple (каля 46 лішніх `prompt_tokens` на аднарадковы промпт); macOS 26: apfel лічыць тэкст паведамленняў. Падрабязнасці ў [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Падтрымліваецца | `stop`, `tool_calls`, `length` |
| Стратэгіі кантэксту | Падтрымліваецца | Дадатковыя палі `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Падтрымліваецца | Уключаецца сцягам `--cors` |
| `POST /v1/completions` | 501 | Састарэлыя тэкставыя completions не падтрымліваюцца |
| `POST /v1/embeddings` | 501 | Эмбедынгі недаступныя на прыладзе |
| `stop` | Падтрымліваецца | Радок або да 4 радкоў; толькі звычайны тэкст (400, калі ў вобласці бачнасці ёсць інструменты або `json_object`/`json_schema`). Прымяняецца з боку вываду, аднолькава ў струменевым і нестружневым рэжымах. Гл. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Відавочна адхіляюцца. `n=1` і `logprobs=false` прымаюцца як пустыя аперацыі |
| Мультымадальнасць (відарысы) | Падтрымліваецца на macOS 27 | Часткі `image_url` у выглядзе base64 data URL перадаюцца наўпрост мадэлі на прыладзе (ліміт 20 MB base64, доўгі бок памяншаецца да 4096 px). Выдаленыя `http(s)` URL і шляхі да файлаў заўсёды даюць 400 - apfel ніколі не спампоўвае відарысы і не чытае файлы для HTTP-кліента. На macOS 26: 400 з зразумелай памылкай. Гл. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Загаловак `Authorization` | Падтрымліваецца | Абавязковы, калі зададзены `--token`. Гл. [docs/server-security.md](../docs/server-security.md) |

Поўная спецыфікацыя API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Абмежаванне адказу па змаўчанні (`max_tokens`)

Калі `max_tokens` не пазначаны, **CLI і OpenAI-сумяшчальны сервер паводзяць сябе аднолькава**: значэнне перадаецца як `nil`, і мадэль выкарыстоўвае ўсё месца, што засталося ў акне кантэксту. Гэта семантыка OpenAI "як ёсць" - ніякай адвольнай канстанты па змаўчанні.

Акно кантэксту на прыладзе змяшчае ўваход *і* выхад разам: **4096 токенаў на macOS 26 і на Mac з M1/M2, 8192 токены на macOS 27 з чыпам M3 або навейшым і 12 GB+**. apfel чытае рэальны памер падчас працы праз `SystemLanguageModel.contextSize` - праверце свой праз `apfel --model-info`. Калі генерацыя ўпіраецца ў мяжу, адказ карэктна завяршаецца з `finish_reason: "length"`, а частковы тэкст вяртаецца (сервер: HTTP 200; CLI: выхад з кодам 0 і папярэджаннем у stderr, або код 8 з `--require-complete` - гл. [docs/cli-reference.md](../docs/cli-reference.md)). Пазначайце `max_tokens` яўна, калі вам патрэбен больш жорсткі бюджэт затрымкі або вядомая мяжа для вашага кліента.

### Прыклады

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

### Як абраць значэнне

| Сцэнарый                               | `max_tokens`  |
|----------------------------------------|---------------|
| Адказ з аднаго слова / класіфікацыя    | 16 - 32       |
| Інструкцыя ў адзін радок               | 64 - 128      |
| Кароткі абзац                          | 256 - 512     |
| Доўгі абзац / структураваны JSON       | 1024 - 2048   |
| Столькі, колькі дазваляе акно кантэксту | не пазначаць  |

Трымайце `input_tokens + max_tokens` з запасам ніжэй за акно кантэксту (4096 токенаў на macOS 26 і на Mac з M1/M2, 8192 на macOS 27 з чыпам M3 або навейшым і 12 GB+ (мадэль Apple AFM 3 Core Advanced)). Калі сам промпт перавышае акно, генерацыя не можа пачацца, і запыт завяршаецца памылкай `[context overflow]` (HTTP 400 / выхад CLI з кодам 4). Валідатар адхіляе недадатныя значэнні (`max_tokens <= 0`).

### Парытэт з CLI

CLI і сервер падпарадкоўваюцца аднаму правілу: не пазначана = выкарыстоўваць астатняе акно. Ніякай канстанты, якая магла б разысціся. Перавызначэнне: `--max-tokens N` або `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Мяккія абарончыя механізмы для сервера

`apfel --serve --permissive` прымушае сервер выкарыстоўваць абарончыя механізмы Apple `.permissiveContentTransformations` для **кожнага запыту**, які апрацоўвае працэс. Той самы сцяг і тая самая семантыка, што ў `--permissive` у CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Перавызначэння для асобнага запыту няма - рашэнне прымае аператар сервера для ўсяго працэсу.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Абмежаванні

| Абмежаванне | Падрабязнасці |
|------------|--------|
| Акно кантэксту | **4096 токенаў на macOS 26 і на Mac з M1/M2, 8192 токены на macOS 27 з чыпам M3 або навейшым і 12 GB+** (уваход і выхад разам). Не жорстка зададзеная канстанта - apfel чытае `SystemLanguageModel.contextSize` падчас працы; `apfel --model-info` выводзіць актуальнае значэнне |
| Платформа | macOS 26+, толькі Apple Silicon |
| Мадэль | Адна мадэль (`apple-foundationmodel`, ~3B параметраў на прыладзе), не наладжваецца |
| Абарончыя механізмы | Сістэма бяспекі Apple можа блакаваць бяскрыўдныя промпты. `--permissive` памяншае колькасць ілжывых спрацоўванняў ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Хуткасць | На прыладзе, не ў маштабе воблака - некалькі секунд на адказ |
| Няма эмбедынгаў | Недаступныя на прыладзе |
| Зрок | Відарысы даходзяць да мадэлі толькі на macOS 27 (сервер: data URL; CLI: `-f photo.jpg` і відарысы з канвеера, у дадатак да тэксту OCR). На macOS 26 відарысы перадаюцца толькі як тэкст праз OCR/класіфікацыю. Апісанні сцэн у мадэлі на 3B грубыя - для чытання друкаванага тэксту надзейным каналам застаецца OCR |
| Навучальныя даныя / дата адсячэння ведаў | Apple не апублікавала дакладную дату адсячэння для мадэлі на прыладзе. Калі настойваць, мадэль **выдумляе новую дату ў кожнай выбарцы** (напрыклад, "October 2023", "April 2023"). Лічыце любыя заявы мадэлі пра ўласнае навучанне ненадзейнымі. |
| Няма бягучай даты і дасведчанасці пра рэальны час | Мадэль не ведае сённяшняй даты і не мае доступу да сеткі або гадзінніка. На пытанне пра дату яна або адмовіцца, або прыдумае яе. Перадавайце бягучую дату праз сістэмны промпт, калі ад яе залежаць вылічэнні (гл. абыходны прыём ніжэй). |

**Абыходны прыём для промптаў, якія залежаць ад даты** - перадайце бягучую дату сістэмным паведамленнем:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Заўвага: нават з перададзенай датай мадэль на 3B можа галюцынаваць (асабліва калі спытаць яе наўпрост пра дату адсячэння навучання). Перадача даты дапамагае генератыўным промптам, якія *выкарыстоўваюць* дату; яна не адмяняе рэфлекс мадэлі распавядаць пра сябе.

Перадгісторыя: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Даведачная дакументацыя

Кіраўніцтвы па выкарыстанні apfel з [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - гл. [docs/guides/index.md](../docs/guides/index.md). Правералася на практыцы; доказ, які можна запусціць: [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - устаноўка, вырашэнне праблем і налада Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - кожны сцяг, код вяртання і зменная асяроддзя
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` і здабыванне тэксту з PDF / відарысаў / тэксту праз канвеер (OCR + разуменне відарысаў)
- [docs/background-service.md](../docs/background-service.md) - выкарыстанне `brew services` і launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - падрабязная матрыца падтрымкі `/v1/*`
- [docs/server-security.md](../docs/server-security.md) - праверкі origin, CORS, токены і `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - стратэгіі абрэзкі чата
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - выкарыстанне лакальнага і выдаленага MCP
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - падрабязныя паводзіны выкліку інструментаў
- [docs/integrations.md](../docs/integrations.md) - інтэграцыі са староннімі інструментамі (opencode і інш.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - лакальнае рэвю з apfel + другой мадэллю рэдагавання/прымянення правак у VS Code
- [docs/demos.md](../docs/demos.md) - больш падрабязныя разборы shell-дэма
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - больш за 50 рэальных промптаў з нерэдагаваным вывадам
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` для старонніх распрацоўшчыкаў
- [docs/coreai-impact.md](../docs/coreai-impact.md) - чаму apfel працуе на FoundationModels, а не на новым Core AI ад Apple (пераемніку Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - параўнанне apfel з уласнай утылітай Apple `fm` (macOS 27) па функцыях, з вымеранымі лічбамі

## Архітэктура

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Строгая канкурэнтнасць Swift 6.3. Тры таргеты: `ApfelCore` (чыстая логіка, тэструецца модульна, таксама даступная як прадукт Swift Package - спасылка ў раздзеле "Даведачная дакументацыя" вышэй), `apfel` (CLI + сервер) і `apfel-tests` (чысты Swift-раннер, без XCTest).

## Зборка і тэсты

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

`.version` - адзіная крыніца ісціны. Версіі павышае толькі `make release`. Лакальныя зборкі версію не змяняюць.

## Дрэва apfel

Праекты, пабудаваныя на apfel. Кожны пастаўляецца як асобны рэпазіторый + формула Homebrew.

| Праект | Што робіць | Устаноўка |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | Корань. CLI на FoundationModels на прыладзе + OpenAI-сумяшчальны сервер. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Чат-кліент для macOS: струменевы markdown, галасавы ўвод і вывад, аналіз відарысаў праз Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Дзеянні ШІ ў радку меню над буферам абмену: кароткі змест, пераклад, перапісванне. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Імгненны аверлей са ШІ: націснулі клавішу, спыталі, атрымалі адказ, закрылі. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Блакнот з формуламі - ШІ на прыладзе як убудаваная функцыя ячэйкі. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP, аптымізаваныя па бюджэце токенаў для маленькага акна на прыладзе: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Адладачны інспектар на SwiftUI: храналогія запытаў, праглядальнік пратаколу MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX-абгортка, якая дадае пастаянны рэестр MCP + TOML-канфіг паверх `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI для тэгавання кантэнту на прыладзе: падайце тэкст на ўваход, атрымайце тэгі/тэмы/эмоцыі. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift-пакет для інструментаў экасістэмы: выяўленне, запуск і струменевае чытанне з лакальнага `apfel --serve`. | Swift Package |

## Праекты супольнасці

Пабудавалі нешта на аснове apfel? Адкрыйце issue, і праект можна дадаць сюды.

| Праект | Што робіць | Спасылкі |
|---------|-------------|-------|
| **apfelclaw** ад [@julianYaman](https://github.com/julianYaman) | Лакальны ШІ-агент, які чытае файлы, каляндар, пошту і стан Mac праз інструменты толькі для чытання | [github](https://github.com/julianyaman/apfelclaw) - [сайт](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** ад [@bhaskarvilles](https://github.com/bhaskarvilles) | Браўзерны чат-інтэрфейс, які працуе з `apfel --serve` праз OpenAI-сумяшчальны API | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** ад [@lucaspwo](https://github.com/lucaspwo) | Абгортка вакол Claude Code, якая падмяняе бэкенд на лакальны apfel праз невялікі проксі Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** ад [@hasit](https://github.com/hasit) | Менеджар праграм для лакальных shell-праграм на аснове apfel | [github](https://github.com/hasit/apfeller) - [сайт](https://hasit.github.io/apfeller/) - [каталог](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** ад [@eggsy](https://github.com/eggsy) | Пашырэнне каманднага радка Raycast: пытанні, пераклад, тлумачэнне файлаў і каталогаў, гісторыя размоў, уласныя сістэмныя промпты. На прыладзе праз apfel CLI. | [крама](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Удзел у праекце

Issues і PR вітаюцца ў любым рэпазіторыі `Arthur-Ficial/apfel*`.

**#agentswelcome** - PR ад ШІ-агентаў вітаюцца. Прачытайце `CLAUDE.md` рэпазіторыя, запусціце тэсты, пазначце інструмент у трэйлеры `Co-Authored-By`. Планка тая ж, што і для людзей: чысты код, тэсты, што праходзяць, сумленныя абмежаванні. Самая зручная для агентаў кропка ўваходу: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([правілы ўдзелу](https://apfel-mcp.franzai.com/#contribute)).

## Ліцэнзія

[MIT](../LICENSE)
