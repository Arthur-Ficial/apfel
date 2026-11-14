<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> 譯自[英文 README](../README.md)。以英文版為準。

# apfel

### 你的 Mac 上早已內建的免費 AI。

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac 透過 [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) 內建了一個大型語言模型。`apfel` 把它包裝成 UNIX 工具與本機的 OpenAI 相容伺服器。100% 在裝置端執行。不需要 API 金鑰,不需要雲端。

| 模式 | 指令 | 你能得到什麼 |
|------|---------|--------------|
| UNIX 工具 | `apfel "prompt"` / `echo "text" \| apfel` | 適合管線的回答、檔案附件、JSON 輸出、結束碼 |
| OpenAI 相容伺服器 | `apfel --serve` | 可直接替換的本機 `http://localhost:11434/v1` 後端,供 OpenAI SDK 使用 |

`apfel --chat` - 互動式 REPL。

所有情境下皆支援工具呼叫。

![apfel CLI](../screenshots/cli.png)

## 系統需求與安裝

macOS 26 Tahoe+,Apple Silicon(M1+),[已啟用 Apple Intelligence](https://support.apple.com/en-us/121115)。在 macOS 27 上,搭載 M3 或更新晶片且記憶體 12 GB 以上的 Mac 會執行 Apple 更大的裝置端模型,上下文視窗為 8192 個 token;M1/M2 Mac 以及所有執行 macOS 26 的 Mac 則為 4096。`apfel --model-info` 會顯示你的實際值。

```bash
brew install apfel
```

更新:

```bash
brew upgrade apfel
```

從原始碼建置(使用含 macOS 27 SDK / Swift 6.3 的命令列工具,不需要 Xcode;產生的執行檔可在 macOS 26 與 27 上執行):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix、當日更新的 tap、Mint、mise、疑難排解:[docs/install.md](../docs/install.md)。

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | **繁體中文**

## 快速開始

### UNIX 工具

含有 `!` 的 prompt 請用單引號括起來(zsh/bash 的歷史記錄展開):`apfel 'Hello, Mac!'`。

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

### OpenAI 相容伺服器

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

背景服務詳情:[docs/background-service.md](../docs/background-service.md)。

### 快速測試聊天

`apfel --chat` 是一個小型 REPL,用於測試 prompt 或 MCP 伺服器。如果需要圖形介面的聊天應用程式,請參閱 [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)。

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

按 Ctrl-C 結束。上下文會被自動裁剪([docs/context-strategies.md](../docs/context-strategies.md))。

在以它撰寫腳本之前,值得了解的限制(各 Mac 的上下文視窗、安全護欄、不支援 embeddings):[限制](../README.md#limitations)。

## 示範

包裝了 `apfel` 的真實 shell 腳本:`cmd`(英文轉 shell 指令)、`oneliner`、`mac-narrator`、`wtd`、`explain`、`naming`、`port`、`gitsum`。它們已內建在執行檔中,不需要複製儲存庫。把它們寫到你喜歡的位置即可,無論你是從 homebrew-core、tap 還是原始碼安裝的 apfel:

```bash
apfel demos ./apfel-demos
```

這會把每個示範(可執行檔)以及一個 `README.md` 寫入 `./apfel-demos`。然後從那裡執行它們:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

執行 `brew upgrade apfel` 之後,請重新執行 `apfel demos` 以更新。原始碼:[`demo/`](../demo/)。詳細逐步說明,以及可複製貼上到 `.zshrc` 的 `cmd` shell 函式:[docs/demos.md](../docs/demos.md)。

## MCP 工具支援

用 `--mcp` 掛載 [Model Context Protocol](https://modelcontextprotocol.io/) 伺服器。apfel 負責探索、呼叫並回傳結果。

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

使用 `-q` 可隱藏工具資訊。

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

內附一個計算機,位於 [`mcp/calculator/`](../mcp/calculator/)([docs/mcp-calculator.md](../docs/mcp-calculator.md))。

**遠端 MCP 伺服器**(Streamable HTTP,MCP 規格 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **安全提示:** 請優先使用 `APFEL_MCP_TOKEN` 而不是 `--mcp-token`(後者會出現在 ps aux 中)。apfel 拒絕透過明文 `http://` 傳送 bearer token。

## apfel-run:選用的設定層

apfel 本身沒有設定檔 - 和任何 UNIX 工具一樣,只用命令列參數與環境變數。如果你想要 TOML 設定(多個 MCP、設定檔、在 git 中管理團隊設定),可以使用 [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run),這是一個 MIT 授權的包裝工具,透過 `execve` 以即插即用的方式提供設定。

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API 相容性

**Base URL:** `http://localhost:11434/v1`

| 功能 | 狀態 | 說明 |
|---------|--------|-------|
| `POST /v1/chat/completions` | 支援 | 串流 + 非串流 |
| `POST /v1/responses` | 支援 | OpenAI Responses API:字串/訊息輸入、`instructions`、串流(標準事件序列)、`text.format`(包含 `json_schema`)、函式工具(非串流)。有狀態的功能(`previous_response_id`、`store: true`、`background`、`reasoning`、代管工具)會如實回傳 501 |
| `POST /v1/responses/input_tokens` | 支援 | Token 預檢(`client.responses.input_tokens.count(...)`):由 Apple 的分詞器給出精確計數,不進行生成;低於 macOS 26.4 時回傳 501,而不是給出估算值。參見 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | 支援 | 回傳 `apple-foundationmodel` |
| `GET /health` | 支援 | 模型可用性、上下文視窗、語言、回報的模型能力(`capabilities`、`capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | 僅限除錯 | 需要 `--debug` |
| 工具呼叫 | 支援 | 原生 `ToolDefinition` + JSON 偵測。參見 [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | 支援 | 透過注入 system prompt 實現;輸出中的 markdown 程式碼圍欄會被移除 |
| `response_format: json_schema` | 支援 | 透過 FoundationModels `DynamicGenerationSchema` 保證輸出符合 schema;可與 `stream: true` 搭配使用 |
| `temperature`, `top_p`, `max_tokens`, `seed` | 支援 | 對應到 `GenerationOptions`。`top_p` 為核採樣;`temperature` 低於 0.001(含 0)時對應為貪婪解碼(確定性)。省略 `max_tokens` 時使用剩餘的上下文視窗(與 OpenAI 的語意完全一致)- 參見[預設回應上限](../README.md#default-response-cap-max_tokens) |
| `stream: true` | 支援 | SSE;僅當設定 `stream_options: {"include_usage": true}` 時才傳送最後的 usage 資料區塊(遵循 OpenAI 規格) |
| `usage` | 支援 | 在 macOS 26.4+ 上為真實的分詞器計數(更低版本為 chars/4 估算)。macOS 27:使用執行階段自身的統計,包含 Apple 聊天範本的額外開銷(單行 prompt 的 `prompt_tokens` 約多 46);macOS 26:apfel 統計訊息文字。詳情見 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | 支援 | `stop`、`tool_calls`、`length` |
| 上下文策略 | 支援 | 擴充欄位 `x_context_strategy`、`x_context_max_turns`、`x_context_output_reserve` |
| CORS | 支援 | 使用 `--cors` 啟用 |
| `POST /v1/completions` | 501 | 不支援舊版文字補全 |
| `POST /v1/embeddings` | 501 | 裝置端不提供 embeddings |
| `stop` | 支援 | 字串或最多 4 個字串;僅限純文字(在有工具參與或使用 `json_object`/`json_schema` 時回傳 400)。在輸出端套用,串流與非串流行為一致。參見 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | 明確拒絕。`n=1` 與 `logprobs=false` 會被接受,但不起任何作用 |
| 多模態(影像) | macOS 27 上支援 | 以 base64 data URL 形式傳入的 `image_url` 部分會原生交給裝置端模型(base64 上限 20 MB,最長邊會縮小到 4096 px)。遠端 `http(s)` URL 與檔案路徑一律回傳 400 - apfel 絕不會擷取影像,也絕不會為 HTTP 用戶端讀取檔案。在 macOS 26 上:回傳 400 及明確的錯誤訊息。參見 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` 標頭 | 支援 | 設定 `--token` 後為必要。參見 [docs/server-security.md](../docs/server-security.md) |

完整 API 規格:[openai/openai-openapi](https://github.com/openai/openai-openapi)。

## 預設回應上限(`max_tokens`)

省略 `max_tokens` 時,**CLI 與 OpenAI 相容伺服器的行為完全一致**:該值以 `nil` 傳入,模型會使用上下文視窗中剩餘的全部空間。這與 OpenAI 的語意完全一致,沒有任意的備援常數。

裝置端上下文視窗同時容納輸入*與*輸出:**macOS 26 以及 M1/M2 Mac 上為 4096 個 token,搭載 M3 或更新晶片且記憶體 12 GB 以上、執行 macOS 27 的 Mac 上為 8192 個 token**。apfel 在執行階段透過 `SystemLanguageModel.contextSize` 讀取真實大小 - 用 `apfel --model-info` 查看你的實際值。如果生成觸及上限,回應會以 `finish_reason: "length"` 正常結束,並回傳已生成的部分內容(伺服器:HTTP 200;CLI:結束碼 0 並在 stderr 給出警告,使用 `--require-complete` 時結束碼為 8 - 參見 [docs/cli-reference.md](../docs/cli-reference.md))。如果你想要更嚴格的延遲預算,或為用戶端設定已知的上限,請明確傳入 `max_tokens`。

### 範例

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

### 如何選值

| 使用情境                               | `max_tokens`  |
|----------------------------------------|---------------|
| 單字 / 分類回覆                        | 16 - 32       |
| 一行指令                               | 64 - 128      |
| 短段落                                 | 256 - 512     |
| 長段落 / 結構化 JSON                   | 1024 - 2048   |
| 盡可能占滿上下文視窗                   | 省略          |

請讓 `input_tokens + max_tokens` 保持在上下文視窗以內並留有餘裕(macOS 26 以及 M1/M2 Mac 上為 4096 個 token,搭載 M3 或更新晶片且記憶體 12 GB 以上、執行 macOS 27 的 Mac 上為 8192(Apple 的 AFM 3 Core Advanced 模型))。如果 prompt 本身就超出視窗,生成將無法開始,請求會以 `[context overflow]` 失敗(HTTP 400 / CLI 結束碼 4)。驗證器會拒絕非正數值(`max_tokens <= 0`)。

### CLI 一致性

CLI 與伺服器遵循同一條規則:省略 = 使用剩餘視窗。沒有會漂移的常數。可用 `--max-tokens N` 或 `APFEL_MAX_TOKENS=N` 覆寫。

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### 伺服器的寬鬆安全護欄

`apfel --serve --permissive` 會讓伺服器對該程序處理的**每個請求**使用 Apple 的 `.permissiveContentTransformations` 安全護欄。旗標相同,語意也與 CLI 的 `--permissive` 相同([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))。不支援逐一請求覆寫 - 由伺服器管理者對整個程序做出決定。

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## 限制

| 限制項目 | 詳情 |
|------------|--------|
| 上下文視窗 | **macOS 26 以及 M1/M2 Mac 上為 4096 個 token,搭載 M3 或更新晶片且記憶體 12 GB 以上、執行 macOS 27 的 Mac 上為 8192 個 token**(輸入 + 輸出合計)。並非寫死的常數 - apfel 在執行階段讀取 `SystemLanguageModel.contextSize`;`apfel --model-info` 會印出目前的實際值 |
| 平台 | 僅限 macOS 26+ 與 Apple Silicon |
| 模型 | 只有一個模型(`apple-foundationmodel`,裝置端約 3B 參數),不可設定 |
| 安全護欄 | Apple 的安全系統可能會攔截無害的 prompt。`--permissive` 可減少誤判([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| 速度 | 在裝置端執行,不是雲端規模 - 每次回應需要幾秒鐘 |
| 無 embeddings | 裝置端不提供 |
| 視覺 | 影像輸入僅在 macOS 27 上才會送達模型(伺服器:data URL;CLI:`-f photo.jpg` 以及透過管線傳入的影像,在 OCR 文字之外附加)。在 macOS 26 上,影像僅以文字形式透過 OCR/分類處理。3B 模型對場景的描述較為粗略 - 要讀取印刷文字,OCR 仍是可靠的管道 |
| 訓練資料 / 知識截止日期 | Apple 沒有公布裝置端模型的確切截止日期。被追問時,模型**每次取樣都會虛構一個不同的日期**(例如「2023 年 10 月」、「2023 年 4 月」)。請把模型對自身訓練情況的所有自述都視為不可靠。 |
| 不知道目前日期,也沒有即時感知 | 模型不知道今天的日期,也無法存取網路或時鐘。被問到時,它要麼拒絕回答,要麼編造一個日期。當計算取決於目前日期時,請透過 system prompt 注入(見下方的因應做法)。 |

**依賴日期的 prompt 的因應做法** - 以 system 訊息的形式注入目前日期:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

注意:即使注入了日期,3B 模型仍可能產生幻覺(尤其是被直接問及自身訓練截止日期時)。注入日期對*使用*該日期的生成類 prompt 有幫助,但無法改變模型「自述」的反射習慣。

背景:[#158](https://github.com/Arthur-Ficial/apfel/issues/158)。

## 參考文件

從 [Python](../docs/guides/python.md)、[Node.js](../docs/guides/nodejs.md)、[Ruby](../docs/guides/ruby.md)、[PHP](../docs/guides/php.md)、[Bash/curl](../docs/guides/bash-curl.md)、[Zsh](../docs/guides/zsh.md)、[AppleScript](../docs/guides/applescript.md)、[Swift](../docs/guides/swift-scripting.md)、[Perl](../docs/guides/perl.md)、[AWK](../docs/guides/awk.md) 使用 apfel 的指南 - 參見 [docs/guides/index.md](../docs/guides/index.md)。均經過實測;可執行的驗證見 [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab)。

- [docs/install.md](../docs/install.md) - 安裝、疑難排解與 Apple Intelligence 設定
- [docs/cli-reference.md](../docs/cli-reference.md) - 所有旗標、結束碼與環境變數
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` 以及透過管線傳入的 PDF / 影像 / 文字擷取(OCR + 影像理解)
- [docs/background-service.md](../docs/background-service.md) - `brew services` 與 launchd 的用法
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` 支援矩陣詳解
- [docs/server-security.md](../docs/server-security.md) - 來源檢查、CORS、token 與 `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - 聊天裁剪策略
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - 本機與遠端 MCP 的用法
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - 工具呼叫行為詳解
- [docs/integrations.md](../docs/integrations.md) - 第三方工具整合(opencode 等)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - 在 VS Code 中使用 apfel + 另一個編輯/套用模型進行本機審查
- [docs/demos.md](../docs/demos.md) - shell 示範的更長篇逐步說明
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50 多個真實 prompt 及未經編輯的輸出
- [docs/swift-library.md](../docs/swift-library.md) - 供下游開發者使用的 `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - 為什麼 apfel 基於 FoundationModels 而不是 Apple 新的 Core AI(Core ML 的後繼者)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel 與 Apple 自家 `fm` CLI(macOS 27)的逐項功能比較及實測數據

## 架構

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 嚴格並行。三個 target:`ApfelCore`(純邏輯,可單元測試,也作為 Swift Package 產品提供 - 連結見上方「參考文件」)、`apfel`(CLI + 伺服器)以及 `apfel-tests`(純 Swift 執行器,不依賴 XCTest)。

## 建置與測試

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

`.version` 是唯一的事實來源。只有 `make release` 會提升版本號。本機建置不會改變版本。

## apfel 生態樹

基於 apfel 建構的專案。每個專案都有自己的儲存庫與 Homebrew formula。

| 專案 | 功能 | 安裝 |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | 根基。裝置端 FoundationModels CLI + OpenAI 相容伺服器。 | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS 聊天用戶端:串流 markdown、語音輸入輸出、Apple Vision 影像分析。 | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | 選單列中針對剪貼簿的 AI 動作:摘要、翻譯、改寫。 | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | 即時 AI 浮層:按下快速鍵,提問,得到答案,關閉。 | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | 公式記事本 - 裝置端 AI 作為內嵌儲存格函式。 | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | 針對小型裝置端視窗最佳化 token 預算的 MCP:`url-fetch`、`ddg-search`、`search-and-fetch`。 | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI 除錯檢視器:請求時間軸、MCP 協定檢視器、TTS/STT。 | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX 包裝工具,在 `apfel` 之上增加持久化的 MCP 登錄與 TOML 設定。 | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | 裝置端內容標註 CLI:透過管線輸入文字,輸出標籤/主題/情緒。 | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | 供生態工具使用的 Swift package:探索、啟動本機 `apfel --serve` 並從中取得串流輸出。 | Swift Package |

## 社群專案

基於 apfel 做出了東西?提交一個 issue,就可以把它加到這裡。

| 專案 | 功能 | 連結 |
|---------|-------------|-------|
| **apfelclaw**,作者 [@julianYaman](https://github.com/julianYaman) | 本機 AI 代理,透過唯讀工具讀取檔案、行事曆、郵件與 Mac 狀態 | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**,作者 [@bhaskarvilles](https://github.com/bhaskarvilles) | 以瀏覽器為基礎的聊天介面,透過 OpenAI 相容 API 與 `apfel --serve` 通訊 | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**,作者 [@lucaspwo](https://github.com/lucaspwo) | Claude Code 包裝工具,透過一個小型 Anthropic-OpenAI 代理把 apfel 換成本機後端 | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**,作者 [@hasit](https://github.com/hasit) | 圍繞 apfel 建構的本機 shell 應用程式的應用程式管理器 | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**,作者 [@eggsy](https://github.com/eggsy) | Raycast 指令列擴充功能:提問、翻譯、解釋檔案與目錄、對話歷史、自訂 system prompt。透過 apfel CLI 在裝置端執行。 | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## 參與貢獻

歡迎在任何 `Arthur-Ficial/apfel*` 儲存庫提交 issue 與 PR。

**#agentswelcome** - 歡迎 AI 代理提交 PR。請閱讀儲存庫中的 `CLAUDE.md`,執行測試,並在 `Co-Authored-By` trailer 中註明所用工具。標準與人類相同:程式碼整潔、測試通過、如實說明限制。對代理最友善的入口:[apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp)([貢獻規則](https://apfel-mcp.franzai.com/#contribute))。

## 授權條款

[MIT](../LICENSE)
