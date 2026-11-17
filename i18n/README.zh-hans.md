<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> 译自[英文 README](../README.md)。以英文版为准。

# apfel

### 你的 Mac 上早已内置的免费 AI。

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac 通过 [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) 内置了一个大语言模型。`apfel` 把它封装成 UNIX 工具和本地的 OpenAI 兼容服务器。100% 在设备端运行。无需 API 密钥,无需云端。

| 模式 | 命令 | 你能得到什么 |
|------|---------|--------------|
| UNIX 工具 | `apfel "prompt"` / `echo "text" \| apfel` | 适合管道的回答、文件附件、JSON 输出、退出码 |
| OpenAI 兼容服务器 | `apfel --serve` | 可直接替换的本地 `http://localhost:11434/v1` 后端,供 OpenAI SDK 使用 |

`apfel --chat` - 交互式 REPL。

[![apfel 终端演示视频: 真实命令, 设备端真实回答 (82 秒)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/zh-hans/a/apfel-ai-tutorial/#video)

所有场景下均支持工具调用。

![apfel CLI](../screenshots/cli.png)

## 系统要求与安装

macOS 26 Tahoe+,Apple Silicon(M1+),[已启用 Apple Intelligence](https://support.apple.com/en-us/121115)。在 macOS 27 上,搭载 M3 或更新芯片且内存 12 GB 以上的 Mac 会运行 Apple 更大的设备端模型,上下文窗口为 8192 个 token;M1/M2 Mac 以及所有运行 macOS 26 的 Mac 为 4096。`apfel --model-info` 会显示你的实际值。

```bash
brew install apfel
```

更新:

```bash
brew upgrade apfel
```

从源码构建(使用带 macOS 27 SDK / Swift 6.3 的命令行工具,无需 Xcode;生成的二进制文件可在 macOS 26 和 27 上运行):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

当日更新的 tap、Mint、mise、故障排查:[docs/install.md](../docs/install.md)。

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | **简体中文** | [繁體中文](README.zh-hant.md)

## 快速开始

### UNIX 工具

含有 `!` 的 prompt 请用单引号括起来(zsh/bash 的历史记录展开):`apfel 'Hello, Mac!'`。

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

### OpenAI 兼容服务器

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

后台服务详情:[docs/background-service.md](../docs/background-service.md)。

### 快速测试聊天

`apfel --chat` 是一个小型 REPL,用于测试 prompt 或 MCP 服务器。如果需要图形界面的聊天应用,请参阅 [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)。

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

按 Ctrl-C 退出。上下文会被自动裁剪([docs/context-strategies.md](../docs/context-strategies.md))。

在基于它编写脚本之前,值得了解的限制(各 Mac 的上下文窗口、安全护栏、不支持 embeddings):[限制](../README.md#limitations)。

## 演示

封装了 `apfel` 的真实 shell 脚本:`cmd`(英语转 shell 命令)、`oneliner`、`mac-narrator`、`wtd`、`explain`、`naming`、`port`、`gitsum`。它们已内置在二进制文件中,无需克隆仓库。把它们写到你喜欢的位置即可,无论你是从 homebrew-core、tap 还是源码安装的 apfel:

```bash
apfel demos ./apfel-demos
```

这会把每个演示(可执行文件)以及一个 `README.md` 写入 `./apfel-demos`。然后从那里运行它们:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

执行 `brew upgrade apfel` 之后,请重新运行 `apfel demos` 以刷新。源码:[`demo/`](../demo/)。详细演练以及可复制粘贴到 `.zshrc` 的 `cmd` shell 函数:[docs/demos.md](../docs/demos.md)。

## MCP 工具支持

用 `--mcp` 挂载 [Model Context Protocol](https://modelcontextprotocol.io/) 服务器。apfel 负责发现、调用并返回结果。

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

使用 `-q` 可隐藏工具信息。

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

自带一个计算器,位于 [`mcp/calculator/`](../mcp/calculator/)([docs/mcp-calculator.md](../docs/mcp-calculator.md))。

**远程 MCP 服务器**(Streamable HTTP,MCP 规范 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **安全提示:** 请优先使用 `APFEL_MCP_TOKEN` 而不是 `--mcp-token`(后者会出现在 ps aux 中)。apfel 拒绝通过明文 `http://` 发送 bearer token。

## apfel-run:可选的配置层

apfel 本身没有配置文件 - 和任何 UNIX 工具一样,只用命令行参数和环境变量。如果你想要 TOML 配置(多个 MCP、配置档案、在 git 中管理团队配置),可以使用 [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run),这是一个 MIT 许可的封装工具,通过 `execve` 以即插即用的方式提供配置。

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API 兼容性

**Base URL:** `http://localhost:11434/v1`

| 功能 | 状态 | 说明 |
|---------|--------|-------|
| `POST /v1/chat/completions` | 支持 | 流式 + 非流式 |
| `POST /v1/responses` | 支持 | OpenAI Responses API:字符串/消息输入、`instructions`、流式(标准事件序列)、`text.format`(包括 `json_schema`)、函数工具(非流式)。有状态的功能(`previous_response_id`、`store: true`、`background`、`reasoning`、托管工具)会如实返回 501 |
| `POST /v1/responses/input_tokens` | 支持 | Token 预检(`client.responses.input_tokens.count(...)`):由 Apple 的分词器给出精确计数,不进行生成;低于 macOS 26.4 时返回 501,而不是给出估算值。参见 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | 支持 | 返回 `apple-foundationmodel`(通用,默认)和 `apple-foundationmodel-content-tagging`(标签,非散文)。参见 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | 支持 | 模型可用性、上下文窗口、语言、上报的模型能力(`capabilities`、`capabilities_reported`)、当前服务的模型变体(`variant`,例如 AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | 仅调试 | 需要 `--debug` |
| 工具调用 | 支持 | 调用通过引导式生成写出(`--tool-calling guided`,默认),或以服务器解析的 JSON 形式写出(`--tool-calling text`)。参见 [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | 支持 | 通过注入 system prompt 实现;输出中的 markdown 代码围栏会被去除 |
| `response_format: json_schema` | 支持 | 通过 FoundationModels `DynamicGenerationSchema` 保证输出符合 schema;可与 `stream: true` 配合使用 |
| `temperature`, `top_p`, `max_tokens`, `seed` | 支持 | 映射到 `GenerationOptions`。`top_p` 为核采样;`temperature` 低于 0.001(含 0)时映射为贪心解码(确定性)。省略 `max_tokens` 时使用剩余的上下文窗口(与 OpenAI 的语义完全一致)- 参见[默认响应上限](../README.md#default-response-cap-max_tokens) |
| `stream: true` | 支持 | SSE;仅当设置 `stream_options: {"include_usage": true}` 时才发送最后的 usage 数据块(遵循 OpenAI 规范) |
| `usage` | 支持 | 在 macOS 26.4+ 上为真实的分词器计数(更低版本为 chars/4 估算)。macOS 27:使用运行时自身的统计,包含 Apple 聊天模板的额外开销(单行 prompt 的 `prompt_tokens` 约多 46);macOS 26:apfel 统计消息文本。详情见 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | 支持 | `stop`、`tool_calls`、`length` |
| 上下文策略 | 支持 | 扩展字段 `x_context_strategy`、`x_context_max_turns`、`x_context_output_reserve` |
| CORS | 支持 | 使用 `--cors` 启用 |
| `POST /v1/completions` | 501 | 不支持旧版文本补全 |
| `POST /v1/embeddings` | 501 | 设备端不提供 embeddings |
| `stop` | 支持 | 字符串或最多 4 个字符串;仅限纯文本(在有工具参与或使用 `json_object`/`json_schema` 时返回 400)。在输出端应用,流式与非流式行为一致。参见 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | 明确拒绝。`n=1` 和 `logprobs=false` 会被接受,但不起任何作用 |
| 多模态(图像) | macOS 27 上支持 | 以 base64 data URL 形式传入的 `image_url` 部分会原生交给设备端模型(base64 上限 20 MB,最长边会缩小到 4096 px)。远程 `http(s)` URL 和文件路径一律返回 400 - apfel 绝不会抓取图像,也绝不会为 HTTP 客户端读取文件。在 macOS 26 上:返回 400 及明确的错误信息。参见 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` 请求头 | 支持 | 设置 `--token` 后为必需。参见 [docs/server-security.md](../docs/server-security.md) |

完整 API 规范:[openai/openai-openapi](https://github.com/openai/openai-openapi)。

## 默认响应上限(`max_tokens`)

省略 `max_tokens` 时,**CLI 与 OpenAI 兼容服务器的行为完全一致**:该值以 `nil` 传入,模型会使用上下文窗口中剩余的全部空间。这与 OpenAI 的语义完全一致,没有任意的回退常量。

设备端上下文窗口同时容纳输入*和*输出:**macOS 26 以及 M1/M2 Mac 上为 4096 个 token,搭载 M3 或更新芯片且内存 12 GB 以上、运行 macOS 27 的 Mac 上为 8192 个 token**。apfel 在运行时通过 `SystemLanguageModel.contextSize` 读取真实大小 - 用 `apfel --model-info` 查看你的实际值。如果生成触及上限,响应会以 `finish_reason: "length"` 正常结束,并返回已生成的部分内容(服务器:HTTP 200;CLI:退出码 0 并在 stderr 给出警告,使用 `--require-complete` 时退出码为 8 - 参见 [docs/cli-reference.md](../docs/cli-reference.md))。如果你想要更严格的延迟预算,或为客户端设定已知的上限,请显式传入 `max_tokens`。

### 示例

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

### 如何选值

| 使用场景                               | `max_tokens`  |
|----------------------------------------|---------------|
| 单词 / 分类回复                        | 16 - 32       |
| 一行指令                               | 64 - 128      |
| 短段落                                 | 256 - 512     |
| 长段落 / 结构化 JSON                   | 1024 - 2048   |
| 尽可能占满上下文窗口                   | 省略          |

请让 `input_tokens + max_tokens` 保持在上下文窗口以内并留有余量(macOS 26 以及 M1/M2 Mac 上为 4096 个 token,搭载 M3 或更新芯片且内存 12 GB 以上、运行 macOS 27 的 Mac 上为 8192(Apple 的 AFM 3 Core Advanced 模型))。如果 prompt 本身就超出窗口,生成将无法开始,请求会以 `[context overflow]` 失败(HTTP 400 / CLI 退出码 4)。校验器会拒绝非正数值(`max_tokens <= 0`)。

### CLI 一致性

CLI 与服务器遵循同一条规则:省略 = 使用剩余窗口。没有会漂移的常量。可用 `--max-tokens N` 或 `APFEL_MAX_TOKENS=N` 覆盖。

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### 服务器的宽松安全护栏

`apfel --serve --permissive` 会让服务器对该进程处理的**每个请求**使用 Apple 的 `.permissiveContentTransformations` 安全护栏。标志相同,语义也与 CLI 的 `--permissive` 相同([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))。不支持按请求覆盖 - 由服务器运维者对整个进程做出决定。

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## 限制

| 约束 | 详情 |
|------------|--------|
| 上下文窗口 | **macOS 26 以及 M1/M2 Mac 上为 4096 个 token,搭载 M3 或更新芯片且内存 12 GB 以上、运行 macOS 27 的 Mac 上为 8192 个 token**(输入 + 输出合计)。并非硬编码常量 - apfel 在运行时读取 `SystemLanguageModel.contextSize`;`apfel --model-info` 会打印当前的实际值 |
| 平台 | 仅限 macOS 26+ 和 Apple Silicon |
| 模型 | 一个设备端模型(约 3B 参数),以 `apple-foundationmodel`(通用)和 `apple-foundationmodel-content-tagging`(Apple 的内容标记适配器;不支持工具)两种身份提供 |
| 安全护栏 | Apple 的安全系统可能会拦截无害的 prompt。`--permissive` 可减少误报([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| 速度 | 在设备端运行,不是云端规模 - 每次响应需要几秒钟 |
| 无 embeddings | 设备端不提供 |
| 视觉 | 图像输入仅在 macOS 27 上才会到达模型(服务器:data URL;CLI:`-f photo.jpg` 以及通过管道传入的图像,在 OCR 文本之外附加)。在 macOS 26 上,图像仅以文本形式通过 OCR/分类处理。3B 模型对场景的描述较为粗略 - 要读取印刷文字,OCR 仍是可靠的渠道 |
| 训练数据 / 知识截止日期 | Apple 没有公布设备端模型的确切截止日期。被追问时,模型**每次采样都会虚构一个不同的日期**(例如"2023 年 10 月"、"2023 年 4 月")。请把模型对自身训练情况的所有自述都视为不可靠。 |
| 不知道当前日期,也没有实时感知 | 模型不知道今天的日期,也无法访问网络或时钟。被问到时,它要么拒绝回答,要么编造一个日期。当计算依赖当前日期时,请通过 system prompt 注入(见下方的变通办法)。 |

**依赖日期的 prompt 的变通办法** - 以 system 消息的形式注入当前日期:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

注意:即使注入了日期,3B 模型仍可能产生幻觉(尤其是被直接问及自身训练截止日期时)。注入日期对*使用*该日期的生成类 prompt 有帮助,但无法改变模型"自述"的反射习惯。

背景:[#158](https://github.com/Arthur-Ficial/apfel/issues/158)。

## 参考文档

从 [Python](../docs/guides/python.md)、[Node.js](../docs/guides/nodejs.md)、[Ruby](../docs/guides/ruby.md)、[PHP](../docs/guides/php.md)、[Bash/curl](../docs/guides/bash-curl.md)、[Zsh](../docs/guides/zsh.md)、[AppleScript](../docs/guides/applescript.md)、[Swift](../docs/guides/swift-scripting.md)、[Perl](../docs/guides/perl.md)、[AWK](../docs/guides/awk.md) 使用 apfel 的指南 - 参见 [docs/guides/index.md](../docs/guides/index.md)。均经过实测;可运行的验证见 [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab)。

- [docs/install.md](../docs/install.md) - 安装、故障排查和 Apple Intelligence 设置
- [docs/cli-reference.md](../docs/cli-reference.md) - 所有标志、退出码和环境变量
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` 以及通过管道传入的 PDF / 图像 / 文本提取(OCR + 图像理解)
- [docs/background-service.md](../docs/background-service.md) - `brew services` 和 launchd 的用法
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` 支持矩阵详解
- [docs/server-security.md](../docs/server-security.md) - 来源检查、CORS、token 和 `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - 聊天裁剪策略
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - 本地与远程 MCP 的用法
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - 工具调用行为详解
- [docs/integrations.md](../docs/integrations.md) - 第三方工具集成(opencode 等)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - 在 VS Code 中使用 apfel + 另一个编辑/应用模型进行本地审查
- [docs/demos.md](../docs/demos.md) - shell 演示的更长篇演练
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 50 多个真实 prompt 及未经编辑的输出
- [docs/swift-library.md](../docs/swift-library.md) - 面向下游开发者的 `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - 为什么 apfel 基于 FoundationModels 而不是 Apple 新的 Core AI(Core ML 的继任者)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel 与 Apple 自家 `fm` CLI(macOS 27)的逐项功能对比及实测数据

## 架构

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 严格并发。三个 target:`ApfelCore`(纯逻辑,可单元测试,也作为 Swift Package 产品提供 - 链接见上方"参考文档")、`apfel`(CLI + 服务器)以及 `apfel-tests`(纯 Swift 运行器,不依赖 XCTest)。

## 构建与测试

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

`.version` 是唯一的事实来源。只有 `make release` 会提升版本号。本地构建不会改变版本。

## apfel 生态树

基于 apfel 构建的项目。每个项目都有自己的仓库和 Homebrew formula。

| 项目 | 功能 | 安装 |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | 根基。设备端 FoundationModels CLI + OpenAI 兼容服务器。 | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS 聊天客户端:流式 markdown、语音输入输出、Apple Vision 图像分析。 | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | 菜单栏中针对剪贴板的 AI 操作:总结、翻译、改写。 | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | 即时 AI 浮层:按下快捷键,提问,得到答案,关闭。 | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | 公式记事本 - 设备端 AI 作为内联单元格函数。 | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | 针对小型设备端窗口优化 token 预算的 MCP:`url-fetch`、`ddg-search`、`search-and-fetch`。 | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI 调试检查器:请求时间线、MCP 协议查看器、TTS/STT。 | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX 封装工具,在 `apfel` 之上增加持久化的 MCP 注册表和 TOML 配置。 | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | 设备端内容标注 CLI:通过管道输入文本,输出标签/主题/情绪。 | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | 面向生态工具的 Swift package:发现、启动本地 `apfel --serve` 并从中获取流式输出。 | Swift Package |

## 社区项目

基于 apfel 做出了东西?提交一个 issue,就可以把它加到这里。

| 项目 | 功能 | 链接 |
|---------|-------------|-------|
| **apfelclaw**,作者 [@julianYaman](https://github.com/julianYaman) | 本地 AI 智能体,通过只读工具读取文件、日历、邮件和 Mac 状态 | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**,作者 [@bhaskarvilles](https://github.com/bhaskarvilles) | 基于浏览器的聊天界面,通过 OpenAI 兼容 API 与 `apfel --serve` 通信 | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**,作者 [@lucaspwo](https://github.com/lucaspwo) | Claude Code 封装工具,通过一个小型 Anthropic-OpenAI 代理把 apfel 换成本地后端 | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**,作者 [@hasit](https://github.com/hasit) | 围绕 apfel 构建的本地 shell 应用的应用管理器 | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**,作者 [@eggsy](https://github.com/eggsy) | Raycast 命令栏扩展:提问、翻译、解释文件和目录、对话历史、自定义 system prompt。通过 apfel CLI 在设备端运行。 | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## 参与贡献

欢迎在任何 `Arthur-Ficial/apfel*` 仓库提交 issue 和 PR。

**#agentswelcome** - 欢迎 AI 智能体提交 PR。请阅读仓库中的 `CLAUDE.md`,运行测试,并在 `Co-Authored-By` trailer 中注明所用工具。标准与人类相同:代码整洁、测试通过、如实说明限制。对智能体最友好的入口:[apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp)([贡献规则](https://apfel-mcp.franzai.com/#contribute))。

## 许可证

[MIT](../LICENSE)
