<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> [영문 README](../README.md)를 번역한 문서입니다. 영문 버전이 기준입니다.

# apfel

### 이미 당신의 Mac에 들어 있는 무료 AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac에는 [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels)로 제공되는 LLM이 내장되어 있습니다. `apfel`은 이를 UNIX 도구와 로컬 OpenAI 호환 서버로 노출합니다. 100% 온디바이스. API 키도, 클라우드도 필요 없습니다.

| 모드 | 명령 | 제공하는 것 |
|------|---------|--------------|
| UNIX 도구 | `apfel "prompt"` / `echo "text" \| apfel` | 파이프에 적합한 응답, 파일 첨부, JSON 출력, 종료 코드 |
| OpenAI 호환 서버 | `apfel --serve` | OpenAI SDK용으로 그대로 바꿔 쓸 수 있는 로컬 `http://localhost:11434/v1` 백엔드 |

`apfel --chat` - 대화형 REPL.

[![apfel 터미널 데모 영상: 실제 명령어, 기기에서 나온 실제 답변 (82초)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/ko/a/apfel-ai-tutorial/#video)

도구 호출은 모든 컨텍스트에서 동작합니다.

![apfel CLI](../screenshots/cli.png)

## 요구 사항 및 설치

macOS 26 Tahoe 이상, Apple Silicon (M1 이상), [Apple Intelligence 활성화](https://support.apple.com/en-us/121115). macOS 27에서는 M3 이상 칩과 12 GB 이상 메모리를 갖춘 Mac이 Apple의 더 큰 온디바이스 모델을 8192 토큰 윈도우로 실행합니다. M1/M2 Mac과 macOS 26의 모든 Mac은 4096입니다. `apfel --model-info`로 내 환경의 값을 확인할 수 있습니다.

```bash
brew install apfel
```

업데이트:

```bash
brew upgrade apfel
```

소스에서 빌드 (macOS 27 SDK / Swift 6.3이 포함된 Command Line Tools, Xcode 불필요. 바이너리는 macOS 26과 27에서 실행됩니다):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

당일 반영 tap, Mint, mise, 문제 해결: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | **한국어** | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## 빠른 시작

### UNIX 도구

`!`가 들어간 프롬프트는 작은따옴표로 감싸세요 (zsh/bash 히스토리 확장 때문): `apfel 'Hello, Mac!'`.

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

### OpenAI 호환 서버

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

백그라운드 서비스 상세: [docs/background-service.md](../docs/background-service.md).

### 빠른 테스트용 채팅

`apfel --chat`은 프롬프트나 MCP 서버를 시험해 보기 위한 작은 REPL입니다. GUI 채팅 앱은 [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)을 참고하세요.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C로 종료합니다. 컨텍스트는 자동으로 잘려 나갑니다 ([docs/context-strategies.md](../docs/context-strategies.md)).

스크립트에서 사용하기 전에 알아 둘 제약 (Mac별 컨텍스트 윈도우, 가드레일, 임베딩 미지원): [제한 사항](../README.md#limitations).

## 데모

`apfel`을 감싼 실제 셸 스크립트 모음: `cmd` (영어를 셸 명령으로), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. 바이너리에 번들되어 있어 저장소를 클론할 필요가 없습니다. apfel을 설치한 경로 (homebrew-core, tap, 소스)와 관계없이 원하는 위치에 내려받을 수 있습니다:

```bash
apfel demos ./apfel-demos
```

그러면 모든 데모 (실행 가능)와 `README.md`가 `./apfel-demos`에 만들어집니다. 이제 그곳에서 실행하면 됩니다:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

`brew upgrade apfel` 후에 `apfel demos`를 다시 실행하면 갱신됩니다. 소스: [`demo/`](../demo/). 상세 설명과 `.zshrc`에 복사해 쓸 수 있는 `cmd` 셸 함수: [docs/demos.md](../docs/demos.md).

## MCP 도구 지원

`--mcp`로 [Model Context Protocol](https://modelcontextprotocol.io/) 서버를 연결합니다. apfel이 도구를 찾아 호출하고 결과를 돌려줍니다.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

도구 정보를 숨기려면 `-q`를 사용하세요.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

계산기가 [`mcp/calculator/`](../mcp/calculator/)에 포함되어 있습니다 ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**원격 MCP 서버** (Streamable HTTP, MCP 사양 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **보안:** `--mcp-token` (ps aux에 노출됨)보다 `APFEL_MCP_TOKEN`을 사용하세요. apfel은 평문 `http://`로 보내는 bearer token을 거부합니다.

## apfel-run: 선택적 설정 계층

apfel 자체에는 설정 파일이 없습니다. 다른 UNIX 도구처럼 플래그와 환경 변수로 동작합니다. TOML 설정 (여러 MCP, 프로필, git으로 공유하는 팀 설정)이 필요하다면 [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run)을 쓰세요. `execve`로 그대로 바꿔 끼우는 방식으로 설정 기능을 더해 주는 MIT 라이선스 래퍼입니다.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API 호환성

**기본 URL:** `http://localhost:11434/v1`

| 기능 | 상태 | 비고 |
|---------|--------|-------|
| `POST /v1/chat/completions` | 지원 | 스트리밍 + 비스트리밍 |
| `POST /v1/responses` | 지원 | OpenAI Responses API: 문자열/메시지 입력, `instructions`, 스트리밍 (표준 이벤트 순서), `text.format` (`json_schema` 포함), 함수 도구 (비스트리밍). 상태 유지 기능 (`previous_response_id`, `store: true`, `background`, `reasoning`, 호스팅 도구)은 솔직하게 501을 반환합니다 |
| `POST /v1/responses/input_tokens` | 지원 | 토큰 사전 점검 (`client.responses.input_tokens.count(...)`): Apple 토크나이저의 정확한 개수이며 생성은 하지 않습니다. macOS 26.4 미만에서는 추정값 대신 501을 반환합니다. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) 참고 |
| `GET /v1/models` | 지원 | `apple-foundationmodel` (범용, 기본값)과 `apple-foundationmodel-content-tagging` (레이블용, 문장 아님)를 반환합니다. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) 참고 |
| `GET /health` | 지원 | 모델 사용 가능 여부, 컨텍스트 윈도우, 언어, 보고된 모델 기능 (`capabilities`, `capabilities_reported`), 서비스 중인 모델 변형 (`variant`, 예: AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | 디버그 전용 | `--debug` 필요 |
| 도구 호출 | 지원 | 호출은 가이드 생성 (`--tool-calling guided`, 기본값) 또는 서버가 파싱하는 JSON (`--tool-calling text`)으로 작성됩니다. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) 참고 |
| `response_format: json_object` | 지원 | 시스템 프롬프트 주입, 출력에서 markdown 펜스 제거 |
| `response_format: json_schema` | 지원 | FoundationModels `DynamicGenerationSchema`를 통해 스키마에 맞는 출력을 보장하며, `stream: true`에서도 동작 |
| `temperature`, `top_p`, `max_tokens`, `seed` | 지원 | `GenerationOptions`에 매핑됩니다. `top_p`는 nucleus 샘플링이며, 0.001 미만 (0 포함)의 `temperature`는 greedy (결정적)로 매핑됩니다. `max_tokens`를 생략하면 남은 컨텍스트 윈도우를 사용합니다 (OpenAI와 동일한 드롭인 방식). [기본 응답 상한](../README.md#default-response-cap-max_tokens) 참고 |
| `stream: true` | 지원 | SSE. 마지막 usage 청크는 `stream_options: {"include_usage": true}`일 때만 전송 (OpenAI 사양대로) |
| `usage` | 지원 | macOS 26.4+에서는 실제 토크나이저 개수 (그 미만은 chars/4 추정). macOS 27: Apple 채팅 템플릿 프레이밍을 포함한 런타임 자체 집계 (한 줄 프롬프트에서 `prompt_tokens`가 약 46 늘어남). macOS 26: apfel이 메시지 텍스트를 셉니다. 자세한 내용은 [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | 지원 | `stop`, `tool_calls`, `length` |
| 컨텍스트 전략 | 지원 | 확장 필드 `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | 지원 | `--cors`로 활성화 |
| `POST /v1/completions` | 501 | 레거시 텍스트 완성은 지원하지 않음 |
| `POST /v1/embeddings` | 501 | 임베딩은 온디바이스에서 사용할 수 없음 |
| `stop` | 지원 | 문자열 또는 최대 4개의 문자열. 일반 텍스트에만 해당 (도구가 범위에 있거나 `json_object`/`json_schema`이면 400). 출력 쪽에서 적용되며 스트리밍과 비스트리밍이 동일합니다. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) 참고 |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | 명시적으로 거부됩니다. `n=1`과 `logprobs=false`는 아무 동작 없이 허용됩니다 |
| 멀티모달 (이미지) | macOS 27에서 지원 | base64 데이터 URL 형태의 `image_url` 파트가 온디바이스 모델에 네이티브로 전달됩니다 (base64 20 MB 상한, 긴 변은 4096 px로 축소). 원격 `http(s)` URL과 파일 경로는 항상 400입니다. apfel은 이미지를 가져오지 않으며 HTTP 클라이언트를 위해 파일을 읽지도 않습니다. macOS 26에서는 명확한 오류와 함께 400. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) 참고 |
| `Authorization` 헤더 | 지원 | `--token`을 설정하면 필수. [docs/server-security.md](../docs/server-security.md) 참고 |

전체 API 사양: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## 기본 응답 상한 (`max_tokens`)

`max_tokens`를 생략하면 **CLI와 OpenAI 호환 서버가 똑같이 동작합니다**. 값은 `nil`로 전달되고, 모델은 컨텍스트 윈도우에 남은 공간을 모두 사용합니다. OpenAI와 동일한 드롭인 방식이며, 임의의 대체 상수는 없습니다.

온디바이스 컨텍스트 윈도우는 입력과 출력을 합쳐서 담습니다: **macOS 26과 M1/M2 Mac에서는 4096 토큰, M3 이상 칩과 12 GB 이상 메모리를 갖춘 macOS 27에서는 8192 토큰**. apfel은 런타임에 `SystemLanguageModel.contextSize`로 실제 크기를 읽습니다. 내 환경의 값은 `apfel --model-info`로 확인하세요. 생성이 한도에 닿으면 응답은 `finish_reason: "length"`로 깔끔하게 끝나며 일부 내용이 반환됩니다 (서버: HTTP 200, CLI: 종료 코드 0과 stderr 경고, `--require-complete`를 쓰면 종료 코드 8 - [docs/cli-reference.md](../docs/cli-reference.md) 참고). 지연 시간 예산을 더 빡빡하게 잡거나 클라이언트에 알려진 상한이 필요하면 `max_tokens`를 명시적으로 지정하세요.

### 예시

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

### 값 고르기

| 사용 사례                               | `max_tokens`  |
|----------------------------------------|---------------|
| 한 단어 / 분류 응답     | 16 - 32       |
| 한 줄 지시                   | 64 - 128      |
| 짧은 문단                        | 256 - 512     |
| 긴 문단 / 구조화된 JSON       | 1024 - 2048   |
| 컨텍스트 윈도우가 허용하는 만큼 길게   | 생략       |

`input_tokens + max_tokens`는 컨텍스트 윈도우 (macOS 26과 M1/M2 Mac에서는 4096 토큰, M3 이상 칩과 12 GB 이상 메모리를 갖춘 macOS 27에서는 8192 (Apple의 AFM 3 Core Advanced 모델))보다 여유 있게 작게 유지하세요. 프롬프트 자체가 윈도우를 넘으면 생성을 시작할 수 없고 요청은 `[context overflow]`로 실패합니다 (HTTP 400 / CLI 종료 코드 4). 검증기는 양수가 아닌 값 (`max_tokens <= 0`)을 거부합니다.

### CLI와의 일치

CLI와 서버는 하나의 규칙을 공유합니다: 생략하면 남은 윈도우를 사용합니다. 어긋날 상수가 없습니다. `--max-tokens N` 또는 `APFEL_MAX_TOKENS=N`으로 덮어쓸 수 있습니다.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### 서버의 permissive 가드레일

`apfel --serve --permissive`는 프로세스가 처리하는 **모든 요청**에 Apple의 `.permissiveContentTransformations` 가드레일을 사용하게 합니다. 플래그와 의미는 CLI의 `--permissive`와 같습니다 ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). 요청별 재정의는 없으며, 프로세스 전체에 대해 서버 운영자가 결정합니다.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## 제한 사항

| 제약 | 상세 |
|------------|--------|
| 컨텍스트 윈도우 | **macOS 26과 M1/M2 Mac에서는 4096 토큰, M3 이상 칩과 12 GB 이상 메모리를 갖춘 macOS 27에서는 8192 토큰** (입력 + 출력 합계). 하드코딩된 상수가 아닙니다. apfel은 런타임에 `SystemLanguageModel.contextSize`를 읽으며, `apfel --model-info`가 현재 값을 출력합니다 |
| 플랫폼 | macOS 26 이상, Apple Silicon 전용 |
| 모델 | 온디바이스 모델 하나 (약 3B 파라미터)를 `apple-foundationmodel` (범용)와 `apple-foundationmodel-content-tagging` (Apple의 콘텐츠 태깅 어댑터, 도구 없음)로 제공합니다 |
| 가드레일 | Apple의 안전 시스템이 무해한 프롬프트를 막을 수 있습니다. `--permissive`로 오탐을 줄일 수 있습니다 ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| 속도 | 온디바이스이며 클라우드 규모가 아니므로 응답당 몇 초가 걸립니다 |
| 임베딩 없음 | 온디바이스에서 사용할 수 없음 |
| 비전 | 이미지 입력은 macOS 27에서만 모델에 전달됩니다 (서버: 데이터 URL, CLI: `-f photo.jpg`와 파이프로 넘긴 이미지이며 OCR 텍스트에 더해짐). macOS 26에서는 이미지가 OCR/분류를 통한 텍스트로만 처리됩니다. 3B 모델의 장면 설명은 대략적이며, 인쇄된 글자를 읽을 때는 OCR이 여전히 믿을 만한 방법입니다 |
| 학습 데이터 / 지식 기준 시점 | Apple은 온디바이스 모델의 정확한 기준 시점을 공개하지 않았습니다. 밀어붙여 물으면 모델은 **샘플마다 다른 날짜를 지어냅니다** (예: "2023년 10월", "2023년 4월"). 모델이 자신의 학습에 대해 말하는 내용은 모두 신뢰할 수 없다고 보세요. |
| 현재 날짜와 실시간 인식 없음 | 모델은 오늘 날짜를 모르며 네트워크나 시계에 접근할 수 없습니다. 물으면 거부하거나 날짜를 지어냅니다. 계산이 날짜에 좌우된다면 시스템 프롬프트로 현재 날짜를 넣어 주세요 (아래 우회 방법 참고). |

**날짜에 의존하는 프롬프트의 우회 방법** - 현재 날짜를 시스템 메시지로 넣습니다:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

참고: 날짜를 넣어도 3B 모델은 여전히 환각을 일으킬 수 있습니다 (특히 자신의 학습 기준 시점을 직접 물을 때). 날짜를 *사용하는* 생성형 프롬프트에는 도움이 되지만, 모델이 자신에 대해 답하려는 반사적 습관까지 막지는 못합니다.

배경: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## 참고 문서

[Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md)에서 apfel을 사용하는 가이드 - [docs/guides/index.md](../docs/guides/index.md) 참고. 실제로 검증했으며, 실행 가능한 증거는 [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab)에 있습니다.

- [docs/install.md](../docs/install.md) - 설치, 문제 해결, Apple Intelligence 설정
- [docs/cli-reference.md](../docs/cli-reference.md) - 모든 플래그, 종료 코드, 환경 변수
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` 및 파이프로 넘긴 PDF / 이미지 / 텍스트 추출 (OCR + 이미지 이해)
- [docs/background-service.md](../docs/background-service.md) - `brew services`와 launchd 사용법
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` 지원 현황 상세
- [docs/server-security.md](../docs/server-security.md) - origin 검사, CORS, 토큰, `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - 채팅 컨텍스트 잘라내기 전략
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - 로컬 및 원격 MCP 사용법
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - 도구 호출 동작 상세
- [docs/integrations.md](../docs/integrations.md) - 서드파티 도구 연동 (opencode 등)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code에서 apfel과 두 번째 편집/적용 모델로 하는 로컬 리뷰
- [docs/demos.md](../docs/demos.md) - 셸 데모의 더 긴 설명
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - 편집하지 않은 출력이 붙은 50개 이상의 실제 프롬프트
- [docs/swift-library.md](../docs/swift-library.md) - 하위 개발자를 위한 `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel이 Apple의 새로운 Core AI (Core ML의 후속)가 아니라 FoundationModels 위에서 동작하는 이유
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel과 Apple 자체 `fm` CLI (macOS 27)를 실측 수치와 함께 기능별로 비교

## 아키텍처

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency. 타깃은 세 개입니다: `ApfelCore` (순수 로직, 단위 테스트 가능, Swift Package 제품으로도 제공 - 위 참고 문서에서 링크), `apfel` (CLI + 서버), `apfel-tests` (순수 Swift 러너, XCTest 불필요).

## 빌드 및 테스트

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

`.version`이 유일한 기준입니다. 버전은 `make release`만 올리며, 로컬 빌드는 버전을 바꾸지 않습니다.

## apfel 트리

apfel 위에 만들어진 프로젝트들입니다. 각각 자체 저장소와 Homebrew formula로 배포됩니다.

| 프로젝트 | 하는 일 | 설치 |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | 뿌리. 온디바이스 FoundationModels CLI + OpenAI 호환 서버. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS 채팅 클라이언트: 스트리밍 markdown, 음성 입출력, Apple Vision 이미지 분석. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | 클립보드에 대한 메뉴 막대 AI 동작: 요약, 번역, 다시 쓰기. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | 즉시 뜨는 AI 오버레이: 키를 누르고, 묻고, 답을 받고, 닫기. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | 수식 메모장 - 온디바이스 AI를 셀 안의 함수로 사용. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | 작은 온디바이스 윈도우를 위해 토큰 예산을 최적화한 MCP: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI 디버그 인스펙터: 요청 타임라인, MCP 프로토콜 뷰어, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` 위에 영속적인 MCP 레지스트리와 TOML 설정을 더하는 UNIX 래퍼. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | 온디바이스 콘텐츠 태깅 CLI: 텍스트를 파이프로 넣으면 태그/주제/감정이 나옵니다. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | 에코시스템 도구용 Swift 패키지: 로컬 `apfel --serve`를 찾고, 띄우고, 스트림을 받습니다. | Swift Package |

## 커뮤니티 프로젝트

apfel 위에 무언가를 만드셨나요? 이슈를 열어 주시면 여기에 추가할 수 있습니다.

| 프로젝트 | 하는 일 | 링크 |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | 읽기 전용 도구로 파일, 캘린더, 메일, Mac 상태를 읽는 로컬 AI 에이전트 | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI 호환 API로 `apfel --serve`와 통신하는 브라우저 기반 채팅 UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | 작은 Anthropic-OpenAI 프록시를 통해 apfel을 로컬 백엔드로 바꿔 끼우는 Claude Code 래퍼 | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel 기반으로 만든 로컬 셸 앱을 위한 앱 매니저 | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast 명령 막대 확장: 질문, 번역, 파일 및 디렉터리 설명, 대화 기록, 사용자 지정 시스템 프롬프트. apfel CLI를 통해 온디바이스로 동작합니다. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## 기여하기

모든 `Arthur-Ficial/apfel*` 저장소에서 이슈와 PR을 환영합니다.

**#agentswelcome** - AI 에이전트의 PR도 괜찮습니다. 저장소의 `CLAUDE.md`를 읽고, 테스트를 실행하고, `Co-Authored-By` 트레일러에 사용한 도구를 밝혀 주세요. 기준은 사람과 같습니다: 깔끔한 코드, 통과하는 테스트, 솔직한 한계 표기. 에이전트에게 가장 시작하기 좋은 곳은 [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp)입니다 ([기여 규칙](https://apfel-mcp.franzai.com/#contribute)).

## 라이선스

[MIT](../LICENSE)
