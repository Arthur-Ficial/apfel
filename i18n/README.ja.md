<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [英語版 README](../README.md) からの翻訳です。英語版が正本です。

# apfel

### あなたの Mac に最初から入っている、無料の AI。

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon 搭載の Mac には、[Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) による LLM が内蔵されています。`apfel` はそれを UNIX ツールとして、またローカルの OpenAI 互換サーバーとして公開します。100% オンデバイス。API キーもクラウドも不要です。

| モード | コマンド | 得られるもの |
|------|---------|--------------|
| UNIX ツール | `apfel "prompt"` / `echo "text" \| apfel` | パイプに向いた応答、ファイル添付、JSON 出力、終了コード |
| OpenAI 互換サーバー | `apfel --serve` | OpenAI SDK 向けにそのまま差し替えられるローカルの `http://localhost:11434/v1` バックエンド |

`apfel --chat` - 対話型 REPL。

[![apfel のターミナルデモ動画: 実際のコマンドと、デバイス上で生成された実際の回答 (84 秒)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ja/a/apfel-ai-tutorial/#video)

ツール呼び出しはすべてのコンテキストで動作します。

![apfel CLI](../screenshots/cli.png)

## 動作要件とインストール

macOS 26 Tahoe 以降、Apple Silicon (M1 以降)、[Apple Intelligence を有効化](https://support.apple.com/en-us/121115)。macOS 27 では、M3 以降のチップと 12 GB 以上のメモリを備えた Mac で、Apple のより大きなオンデバイスモデルが 8192 トークンのウィンドウで動作します。M1/M2 の Mac と macOS 26 のすべての Mac は 4096 です。`apfel --model-info` でお使いの環境の値を確認できます。

```bash
brew install apfel
```

アップデート:

```bash
brew upgrade apfel
```

ソースからビルド (macOS 27 SDK / Swift 6.3 を含む Command Line Tools、Xcode は不要。バイナリは macOS 26 と 27 で動作します):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

同日公開の tap、Mint、mise、トラブルシューティング: [docs/install.md](../docs/install.md)。

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | **日本語** | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## クイックスタート

### UNIX ツール

`!` を含むプロンプトはシングルクォートで囲んでください (zsh/bash の履歴展開のため): `apfel 'Hello, Mac!'`。

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

### OpenAI 互換サーバー

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

バックグラウンドサービスの詳細: [docs/background-service.md](../docs/background-service.md)。

### 動作確認用チャット

`apfel --chat` は、プロンプトや MCP サーバーを試すための小さな REPL です。GUI のチャットアプリには [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) を参照してください。

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C で終了します。コンテキストは自動的に切り詰められます ([docs/context-strategies.md](../docs/context-strategies.md))。

スクリプトから使う前に知っておくべき制約 (Mac ごとのコンテキストウィンドウ、ガードレール、埋め込み非対応): [制限事項](../README.md#limitations)。

## デモ

`apfel` をラップした実際のシェルスクリプト集: `cmd` (英語からシェルコマンドへ)、`oneliner`、`mac-narrator`、`wtd`、`explain`、`naming`、`port`、`gitsum`。これらはバイナリに同梱されているため、リポジトリのクローンは不要です。apfel をインストールした経路 (homebrew-core、tap、ソース) に関係なく、好きな場所に書き出せます:

```bash
apfel demos ./apfel-demos
```

これで、すべてのデモ (実行可能) と `README.md` が `./apfel-demos` に書き出されます。あとはそこから実行します:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

`brew upgrade apfel` のあとに `apfel demos` を再実行すると更新されます。ソース: [`demo/`](../demo/)。解説と、`.zshrc` にコピペで使える `cmd` シェル関数: [docs/demos.md](../docs/demos.md)。

## MCP ツール対応

`--mcp` で [Model Context Protocol](https://modelcontextprotocol.io/) サーバーを接続します。apfel がツールを検出し、呼び出し、結果を返します。

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

ツール情報を表示したくない場合は `-q` を使います。

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

電卓ツールが [`mcp/calculator/`](../mcp/calculator/) に同梱されています ([docs/mcp-calculator.md](../docs/mcp-calculator.md))。

**リモート MCP サーバー** (Streamable HTTP、MCP 仕様 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **セキュリティ:** `--mcp-token` (ps aux に見えてしまう) より `APFEL_MCP_TOKEN` を使ってください。apfel は平文の `http://` 経由の bearer token を拒否します。

## apfel-run: オプションの設定レイヤー

apfel 自体には設定ファイルがなく、他の UNIX ツールと同じくフラグと環境変数で動きます。TOML による設定 (多数の MCP、プロファイル、git で共有するチーム設定) が欲しい場合は、[**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) が使えます。`execve` で差し替えるだけで設定機能を追加する MIT ライセンスのラッパーです。

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API 互換性

**ベース URL:** `http://localhost:11434/v1`

| 機能 | 状態 | 備考 |
|---------|--------|-------|
| `POST /v1/chat/completions` | 対応 | ストリーミング・非ストリーミング |
| `POST /v1/responses` | 対応 | OpenAI Responses API: 文字列/メッセージ入力、`instructions`、ストリーミング (標準のイベントシーケンス)、`text.format` (`json_schema` を含む)、関数ツール (非ストリーミング)。ステートフルな機能 (`previous_response_id`、`store: true`、`background`、`reasoning`、ホスト型ツール) は正直に 501 を返します |
| `POST /v1/responses/input_tokens` | 対応 | トークンの事前確認 (`client.responses.input_tokens.count(...)`): Apple のトークナイザーによる正確な数で、生成は行いません。macOS 26.4 未満では推定値ではなく 501 を返します。[docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) を参照 |
| `GET /v1/models` | 対応 | `apple-foundationmodel` (汎用、デフォルト) と `apple-foundationmodel-content-tagging` (ラベル用、文章ではない) を返します。[docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) を参照 |
| `GET /health` | 対応 | モデルの利用可否、コンテキストウィンドウ、言語、報告されたモデル機能 (`capabilities`、`capabilities_reported`)、提供中のモデルバリアント (`variant`、例: AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | デバッグ専用 | `--debug` が必要 |
| ツール呼び出し | 対応 | 呼び出しはガイド付き生成 (`--tool-calling guided`、デフォルト) か、サーバーが解析する JSON (`--tool-calling text`) として書かれます。[docs/tool-calling-guide.md](../docs/tool-calling-guide.md) を参照 |
| `response_format: json_object` | 対応 | システムプロンプトへの注入。出力から markdown のフェンスを除去 |
| `response_format: json_schema` | 対応 | FoundationModels の `DynamicGenerationSchema` により、スキーマに適合する出力を保証。`stream: true` でも動作 |
| `temperature`, `top_p`, `max_tokens`, `seed` | 対応 | `GenerationOptions` にマップされます。`top_p` は nucleus サンプリング。0.001 未満 (0 を含む) の `temperature` は greedy (決定的) になります。`max_tokens` を省略すると残りのコンテキストウィンドウを使います (OpenAI と同じ、そのまま差し替え可能な動作)。[デフォルトのレスポンス上限](../README.md#default-response-cap-max_tokens) を参照 |
| `stream: true` | 対応 | SSE。最後の usage チャンクは `stream_options: {"include_usage": true}` のときのみ (OpenAI 仕様どおり) |
| `usage` | 対応 | macOS 26.4+ では実際のトークナイザーによる数 (それ未満は chars/4 の推定)。macOS 27: Apple のチャットテンプレートのフレーミングを含むランタイム自身の集計 (1 行のプロンプトで `prompt_tokens` が約 46 増えます)。macOS 26: apfel がメッセージ本文を数えます。詳細は [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | 対応 | `stop`、`tool_calls`、`length` |
| コンテキスト戦略 | 対応 | 拡張フィールド `x_context_strategy`、`x_context_max_turns`、`x_context_output_reserve` |
| CORS | 対応 | `--cors` で有効化 |
| `POST /v1/completions` | 501 | レガシーのテキスト補完は非対応 |
| `POST /v1/embeddings` | 501 | 埋め込みはオンデバイスでは利用できません |
| `stop` | 対応 | 文字列、または最大 4 つの文字列。プレーンテキストのみ (ツールが有効な場合や `json_object`/`json_schema` では 400)。出力側で適用され、ストリーミングと非ストリーミングで同一です。[docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) を参照 |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | 明示的に拒否されます。`n=1` と `logprobs=false` は何もせず受け付けます |
| マルチモーダル (画像) | macOS 27 で対応 | base64 データ URL の `image_url` パートがオンデバイスモデルにネイティブで渡されます (base64 は 20 MB まで、長辺は 4096 px に縮小)。リモートの `http(s)` URL とファイルパスは常に 400 です。apfel は画像を取得せず、HTTP クライアントのためにファイルを読むこともありません。macOS 26 では、明確なエラーとともに 400。[docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) を参照 |
| `Authorization` ヘッダー | 対応 | `--token` を設定した場合は必須。[docs/server-security.md](../docs/server-security.md) を参照 |

API 仕様の全体: [openai/openai-openapi](https://github.com/openai/openai-openapi)。

## デフォルトのレスポンス上限 (`max_tokens`)

`max_tokens` を省略した場合、**CLI と OpenAI 互換サーバーはまったく同じ動作**になります。値は `nil` のまま渡され、モデルはコンテキストウィンドウに残っている分をすべて使います。これは OpenAI と同じ、そのまま差し替え可能な動作で、任意のフォールバック定数はありません。

オンデバイスのコンテキストウィンドウは入力と出力の合計を保持します: **macOS 26 および M1/M2 の Mac では 4096 トークン、macOS 27 で M3 以降のチップと 12 GB 以上のメモリがある場合は 8192 トークン**。apfel は実行時に `SystemLanguageModel.contextSize` から実際のサイズを読み取ります。お使いの環境の値は `apfel --model-info` で確認できます。生成が上限に達した場合、レスポンスは `finish_reason: "length"` で正常に終了し、途中までの内容が返されます (サーバー: HTTP 200、CLI: 標準エラーへの警告付きで終了コード 0、`--require-complete` を付けると終了コード 8 - [docs/cli-reference.md](../docs/cli-reference.md) を参照)。レイテンシの予算を厳しくしたい場合や、クライアント側で上限を明確にしたい場合は、`max_tokens` を明示的に指定してください。

### 例

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

### 値の選び方

| ユースケース                               | `max_tokens`  |
|----------------------------------------|---------------|
| 単語 / 分類だけの返答     | 16 - 32       |
| 1 行の指示                   | 64 - 128      |
| 短い段落                        | 256 - 512     |
| 長い段落 / 構造化 JSON       | 1024 - 2048   |
| コンテキストウィンドウの許す限り長く   | 省略する       |

`input_tokens + max_tokens` は、コンテキストウィンドウ (macOS 26 および M1/M2 の Mac では 4096 トークン、macOS 27 で M3 以降のチップと 12 GB 以上のメモリがある場合は 8192 (Apple の AFM 3 Core Advanced モデル)) に十分収まるようにしてください。プロンプト自体がウィンドウを超えると生成を開始できず、リクエストは `[context overflow]` で失敗します (HTTP 400 / CLI 終了コード 4)。バリデーターは正でない値 (`max_tokens <= 0`) を拒否します。

### CLI との一致

CLI とサーバーのルールは同じです: 省略 = 残りのウィンドウを使う。ずれる原因になる定数はありません。`--max-tokens N` または `APFEL_MAX_TOKENS=N` で上書きできます。

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### サーバーのパーミッシブなガードレール

`apfel --serve --permissive` は、そのプロセスが処理する**すべてのリクエスト**で Apple の `.permissiveContentTransformations` ガードレールを使います。フラグも意味も CLI の `--permissive` と同じです ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))。リクエストごとの上書きはなく、プロセス全体についてサーバーの運用者が決めます。

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## 制限事項

| 制約 | 詳細 |
|------------|--------|
| コンテキストウィンドウ | **macOS 26 および M1/M2 の Mac では 4096 トークン、macOS 27 で M3 以降のチップと 12 GB 以上のメモリがある場合は 8192 トークン** (入力と出力の合計)。ハードコードされた定数ではありません。apfel は実行時に `SystemLanguageModel.contextSize` を読み取り、`apfel --model-info` が現在の値を表示します |
| プラットフォーム | macOS 26 以降、Apple Silicon のみ |
| モデル | オンデバイスモデルは 1 つ (約 3B パラメータ) で、`apple-foundationmodel` (汎用) と `apple-foundationmodel-content-tagging` (Apple のコンテンツタグ付けアダプター、ツールなし) として提供されます |
| ガードレール | Apple の安全性システムが無害なプロンプトをブロックすることがあります。`--permissive` で誤検知を減らせます ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| 速度 | オンデバイスでありクラウド規模ではないため、1 回の応答に数秒かかります |
| 埋め込みなし | オンデバイスでは利用できません |
| ビジョン | 画像入力がモデルに届くのは macOS 27 のみです (サーバー: データ URL、CLI: `-f photo.jpg` とパイプされた画像。OCR テキストに加えて渡されます)。macOS 26 では、画像は OCR/分類によるテキストとしてのみ扱われます。3B モデルによる情景の説明は大まかで、印字された文字を読むには OCR が引き続き確実な手段です |
| 学習データ / 知識のカットオフ | Apple はオンデバイスモデルの正確なカットオフを公表していません。名指しするよう迫ると、モデルは**サンプルごとに異なる日付をでっち上げます** (例: 「2023 年 10 月」「2023 年 4 月」)。モデルが自分の学習について述べることは、すべて信頼できないものとして扱ってください。 |
| 現在の日付やリアルタイムの認識がない | モデルは今日の日付を知らず、ネットワークや時計にもアクセスできません。尋ねると、拒否するか日付をでっち上げます。日付に依存する計算がある場合は、システムプロンプトで現在の日付を渡してください (下の回避策を参照)。 |

**日付に依存するプロンプトの回避策** - 現在の日付をシステムメッセージとして渡します:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

注意: 日付を渡しても、3B モデルは (特に自身の学習カットオフを直接尋ねられたとき) ハルシネーションを起こすことがあります。この方法が助けになるのは日付を*使う*生成系のプロンプトであり、モデルが自分について答えてしまう反射までは抑えられません。

背景: [#158](https://github.com/Arthur-Ficial/apfel/issues/158)。

## リファレンスドキュメント

[Python](../docs/guides/python.md)、[Node.js](../docs/guides/nodejs.md)、[Ruby](../docs/guides/ruby.md)、[PHP](../docs/guides/php.md)、[Bash/curl](../docs/guides/bash-curl.md)、[Zsh](../docs/guides/zsh.md)、[AppleScript](../docs/guides/applescript.md)、[Swift](../docs/guides/swift-scripting.md)、[Perl](../docs/guides/perl.md)、[AWK](../docs/guides/awk.md) から apfel を使うためのガイド - [docs/guides/index.md](../docs/guides/index.md) を参照。実測で検証済みで、実行可能な証拠は [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) にあります。

- [docs/install.md](../docs/install.md) - インストール、トラブルシューティング、Apple Intelligence のセットアップ
- [docs/cli-reference.md](../docs/cli-reference.md) - すべてのフラグ、終了コード、環境変数
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` とパイプされた PDF / 画像 / テキストの抽出 (OCR + 画像理解)
- [docs/background-service.md](../docs/background-service.md) - `brew services` と launchd の使い方
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` 対応表の詳細
- [docs/server-security.md](../docs/server-security.md) - オリジンチェック、CORS、トークン、`--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - チャットの切り詰め戦略
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - ローカルとリモートの MCP の使い方
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ツール呼び出しの動作の詳細
- [docs/integrations.md](../docs/integrations.md) - サードパーティツールとの連携 (opencode など)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code で apfel と 2 つ目の編集/適用モデルを使うローカルレビュー
- [docs/demos.md](../docs/demos.md) - シェルデモのより長い解説
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 無編集の出力付きで 50 以上の実際のプロンプト
- [docs/swift-library.md](../docs/swift-library.md) - 下流の開発者向け `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel が Apple の新しい Core AI (Core ML の後継) ではなく FoundationModels で動く理由
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel と Apple 純正の `fm` CLI (macOS 27) を、実測値とともに機能ごとに比較

## アーキテクチャ

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 の strict concurrency。ターゲットは 3 つ: `ApfelCore` (純粋なロジックで、ユニットテスト可能。Swift Package のプロダクトとしても利用可能 - 上の「リファレンスドキュメント」からリンク)、`apfel` (CLI + サーバー)、`apfel-tests` (純粋な Swift のランナー、XCTest 不要)。

## ビルドとテスト

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

`.version` が唯一の信頼できる情報源です。バージョンを上げるのは `make release` だけで、ローカルビルドではバージョンは変わりません。

## apfel ツリー

apfel の上に作られたプロジェクトです。それぞれ独自のリポジトリと Homebrew formula で提供されます。

| プロジェクト | 内容 | インストール |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | 根っこ。オンデバイスの FoundationModels CLI + OpenAI 互換サーバー。 | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS 用チャットクライアント: ストリーミング markdown、音声入出力、Apple Vision による画像解析。 | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | クリップボードに対するメニューバーの AI アクション: 要約、翻訳、書き換え。 | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | 瞬時に呼び出せる AI オーバーレイ: キーを押して、質問し、答えを得て、閉じる。 | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | 数式ノートパッド - オンデバイス AI をセル内の関数として使えます。 | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | 小さなオンデバイスのウィンドウ向けにトークン予算を最適化した MCP: `url-fetch`、`ddg-search`、`search-and-fetch`。 | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI のデバッグインスペクター: リクエストのタイムライン、MCP プロトコルビューア、TTS/STT。 | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` の上に永続的な MCP レジストリと TOML 設定を加える UNIX ラッパー。 | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | オンデバイスのコンテンツタグ付け CLI: テキストをパイプで渡すと、タグ/トピック/感情が返ります。 | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | エコシステムツール向けの Swift パッケージ: ローカルの `apfel --serve` を検出し、起動し、ストリームを受け取ります。 | Swift Package |

## コミュニティプロジェクト

apfel の上に何か作りましたか? issue を立てていただければ、ここに追加できます。

| プロジェクト | 内容 | リンク |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | 読み取り専用ツールを通じて、ファイル、カレンダー、メール、Mac の状態を読み取るローカル AI エージェント | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI 互換 API で `apfel --serve` と通信するブラウザベースのチャット UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | 小さな Anthropic-OpenAI プロキシを介して apfel をローカルバックエンドとして差し替える Claude Code ラッパー | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel を軸にしたローカルのシェルアプリ用アプリマネージャー | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast コマンドバー拡張: 質問、翻訳、ファイルやディレクトリの解説、会話履歴、カスタムシステムプロンプト。apfel CLI 経由でオンデバイスで動作します。 | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## コントリビュート

`Arthur-Ficial/apfel*` のどのリポジトリでも、issue と PR を歓迎します。

**#agentswelcome** - AI エージェントによる PR も歓迎です。リポジトリの `CLAUDE.md` を読み、テストを実行し、`Co-Authored-By` トレーラーでツールを明記してください。基準は人間と同じです: きれいなコード、通るテスト、正直な制限事項の明記。エージェントにとって最も入りやすいのは [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) です ([コントリビューションのルール](https://apfel-mcp.franzai.com/#contribute))。

## ライセンス

[MIT](../LICENSE)
