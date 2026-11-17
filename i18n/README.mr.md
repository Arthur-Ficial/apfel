<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [इंग्रजी README](../README.md) वरून भाषांतरित. इंग्रजी आवृत्तीच अधिकृत आहे.

# apfel

### तुमच्या Mac वर आधीपासूनच असलेला मोफत AI.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac मध्ये [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) द्वारे अंगभूत LLM येतो. `apfel` तो UNIX टूल म्हणून आणि स्थानिक OpenAI-सुसंगत सर्व्हर म्हणून उपलब्ध करून देतो. 100% ऑन-डिव्हाइस. API की नाहीत, क्लाउड नाही.

| मोड | कमांड | तुम्हाला काय मिळते |
|------|---------|--------------|
| UNIX टूल | `apfel "prompt"` / `echo "text" \| apfel` | पाइप-फ्रेंडली उत्तरे, फाइल अटॅचमेंट, JSON आउटपुट, एक्झिट कोड |
| OpenAI-सुसंगत सर्व्हर | `apfel --serve` | OpenAI SDK साठी स्थानिक `http://localhost:11434/v1` बॅकएंड, थेट बदलता येणारा |

`apfel --chat` - इंटरॅक्टिव्ह REPL.

[![apfel टर्मिनल डेमो व्हिडिओ: खऱ्या कमांड, डिव्हाइसवर खरी उत्तरे (84 सेकंद)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/mr/a/apfel-ai-tutorial/#video)

टूल कॉलिंग सर्व संदर्भांत काम करते.

![apfel CLI](../screenshots/cli.png)

## आवश्यकता आणि इन्स्टॉल

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence सुरू केलेले](https://support.apple.com/en-us/121115). macOS 27 वर, M3 किंवा नवीन चिप आणि 12 GB+ असलेले Mac Apple चे मोठे ऑन-डिव्हाइस मॉडेल 8192-टोकन विंडोसह चालवतात; M1/M2 Mac आणि macOS 26 वरील प्रत्येक Mac मध्ये 4096 असते. `apfel --model-info` तुमचे दाखवते.

```bash
brew install apfel
```

अपडेट:

```bash
brew upgrade apfel
```

सोर्समधून बिल्ड करा (macOS 27 SDK / Swift 6.3 सह Command Line Tools, Xcode नाही; बायनरी macOS 26 आणि 27 वर चालते):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, ट्रबलशूटिंग: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | **मराठी** | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## झटपट सुरुवात

### UNIX टूल

`!` असलेले prompt सिंगल कोटमध्ये लिहा (zsh/bash हिस्ट्री एक्स्पान्शन): `apfel 'Hello, Mac!'`.

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

### OpenAI-सुसंगत सर्व्हर

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

बॅकग्राउंड सर्व्हिसचा तपशील: [docs/background-service.md](../docs/background-service.md).

### झटपट टेस्टिंग चॅट

`apfel --chat` हा prompt किंवा MCP सर्व्हर तपासण्यासाठी एक छोटा REPL आहे. GUI चॅट ॲपसाठी [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) पहा.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C ने बाहेर पडता येते. कॉन्टेक्स्ट आपोआप ट्रिम होतो ([docs/context-strategies.md](../docs/context-strategies.md)).

त्यावर स्क्रिप्ट लिहिण्यापूर्वी माहीत असाव्यात अशा मर्यादा (प्रत्येक Mac नुसार कॉन्टेक्स्ट विंडो, गार्डरेल, एम्बेडिंग नाही): [मर्यादा](../README.md#limitations).

## डेमो

`apfel` भोवती गुंडाळलेल्या खऱ्या शेल स्क्रिप्ट: `cmd` (इंग्रजीतून शेल कमांड), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. त्या बायनरीतच समाविष्ट आहेत - रेपो क्लोन करण्याची गरज नाही. तुम्ही apfel जिथून इन्स्टॉल केले (homebrew-core, tap किंवा सोर्स) तिथून हव्या त्या ठिकाणी त्या लिहा:

```bash
apfel demos ./apfel-demos
```

हे प्रत्येक डेमो (एक्झिक्युटेबल) आणि एक `README.md` `./apfel-demos` मध्ये लिहिते. मग तिथून चालवा:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

ताजे करण्यासाठी `brew upgrade apfel` नंतर पुन्हा `apfel demos` चालवा. सोर्स: [`demo/`](../demo/). वॉकथ्रू आणि तुमच्या `.zshrc` साठी कॉपी-पेस्ट `cmd` शेल फंक्शन: [docs/demos.md](../docs/demos.md).

## MCP टूल सपोर्ट

`--mcp` ने [Model Context Protocol](https://modelcontextprotocol.io/) सर्व्हर जोडा. apfel शोधतो, चालवतो आणि निकाल परत देतो.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

टूलची माहिती लपवण्यासाठी `-q` वापरा.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

[`mcp/calculator/`](../mcp/calculator/) मध्ये एका कॅल्क्युलेटरसह येते ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**रिमोट MCP सर्व्हर** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **सुरक्षा:** `--mcp-token` (ps aux) ऐवजी `APFEL_MCP_TOKEN` वापरा. apfel साध्या `http://` वर bearer token पाठवण्यास नकार देतो.

## apfel-run: ऐच्छिक कॉन्फिग स्तर

apfel ला स्वतःची कॉन्फिग फाइल नाही - फ्लॅग + env व्हेरिएबल, कोणत्याही UNIX टूलप्रमाणे. तुम्हाला TOML कॉन्फिग हवे असल्यास (अनेक MCP, प्रोफाइल, git मधील टीम कॉन्फिग), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) हा एक MIT रॅपर आहे जो `execve` ड्रॉप-इनद्वारे ते जोडतो.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API सुसंगतता

**बेस URL:** `http://localhost:11434/v1`

| वैशिष्ट्य | स्थिती | टीप |
|---------|--------|-------|
| `POST /v1/chat/completions` | समर्थित | स्ट्रीमिंग + नॉन-स्ट्रीमिंग |
| `POST /v1/responses` | समर्थित | OpenAI Responses API: string/message इनपुट, `instructions`, स्ट्रीमिंग (canonical event sequence), `text.format` (`json_schema` सह), फंक्शन टूल (नॉन-स्ट्रीमिंग). स्टेटफुल वैशिष्ट्ये (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) प्रामाणिक 501 देतात |
| `POST /v1/responses/input_tokens` | समर्थित | टोकन प्रीफ्लाइट (`client.responses.input_tokens.count(...)`): Apple च्या टोकनायझरकडून अचूक मोजणी, जनरेशन नाही; macOS 26.4 पेक्षा खाली अंदाजाऐवजी 501. पहा [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | समर्थित | `apple-foundationmodel` (सामान्य, डीफॉल्ट) आणि `apple-foundationmodel-content-tagging` (लेबल, गद्य नव्हे) परत देते. पहा [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | समर्थित | मॉडेल उपलब्धता, कॉन्टेक्स्ट विंडो, भाषा, नोंदवलेल्या मॉडेल क्षमता (`capabilities`, `capabilities_reported`), सेवा देणारा मॉडेल व्हेरिएंट (`variant`, उदा. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | फक्त डीबग | `--debug` आवश्यक |
| टूल कॉलिंग | समर्थित | कॉल गाइडेड जनरेशनद्वारे (`--tool-calling guided`, डीफॉल्ट) किंवा सर्व्हर पार्स करतो अशा JSON स्वरूपात (`--tool-calling text`) लिहिला जातो. पहा [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | समर्थित | सिस्टम-प्रॉम्प्ट इंजेक्शन; आउटपुटमधून markdown फेन्स काढले जातात |
| `response_format: json_schema` | समर्थित | FoundationModels `DynamicGenerationSchema` द्वारे स्कीमाशी जुळणाऱ्या आउटपुटची हमी; `stream: true` सह चालते |
| `temperature`, `top_p`, `max_tokens`, `seed` | समर्थित | `GenerationOptions` शी मॅप केले जातात. `top_p` म्हणजे nucleus sampling; 0.001 पेक्षा कमी `temperature` (0 सह) greedy (निश्चित) शी मॅप होते. `max_tokens` वगळल्यास उरलेली कॉन्टेक्स्ट विंडो वापरली जाते (OpenAI प्रमाणेच सिमॅन्टिक्स) - पहा [डिफॉल्ट रिस्पॉन्स मर्यादा](../README.md#default-response-cap-max_tokens) |
| `stream: true` | समर्थित | SSE; शेवटचा usage chunk फक्त `stream_options: {"include_usage": true}` असल्यास (OpenAI spec नुसार) |
| `usage` | समर्थित | macOS 26.4+ वर खरी टोकनायझर मोजणी (त्याखाली chars/4 अंदाज). macOS 27: रनटाइमचा स्वतःचा हिशोब, Apple च्या chat-template framing सह (एका ओळीच्या prompt वर सुमारे 46 अतिरिक्त `prompt_tokens`); macOS 26: apfel मेसेज मजकूर मोजतो. तपशील [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) मध्ये |
| `finish_reason` | समर्थित | `stop`, `tool_calls`, `length` |
| कॉन्टेक्स्ट स्ट्रॅटेजी | समर्थित | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` एक्स्टेन्शन फील्ड |
| CORS | समर्थित | `--cors` ने सुरू करा |
| `POST /v1/completions` | 501 | लेगसी टेक्स्ट कंप्लीशन समर्थित नाही |
| `POST /v1/embeddings` | 501 | ऑन-डिव्हाइस एम्बेडिंग उपलब्ध नाही |
| `stop` | समर्थित | एक string किंवा 4 पर्यंत strings; फक्त साधा मजकूर (टूल स्कोपमध्ये असल्यास किंवा `json_object`/`json_schema` असल्यास 400). आउटपुट बाजूला लागू होते, स्ट्रीमिंग आणि नॉन-स्ट्रीमिंगमध्ये सारखेच. पहा [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | स्पष्टपणे नाकारले जातात. `n=1` आणि `logprobs=false` काहीही न करणारे म्हणून स्वीकारले जातात |
| मल्टि-मोडल (इमेज) | macOS 27 वर समर्थित | base64 data URL म्हणून `image_url` भाग थेट ऑन-डिव्हाइस मॉडेलकडे जातात (20 MB base64 मर्यादा, सर्वात लांब बाजू 4096 px पर्यंत कमी केली जाते). रिमोट `http(s)` URL आणि फाइल पाथ नेहमी 400 - apfel कधीही इमेज आणत नाही आणि HTTP क्लायंटसाठी कधीही फाइल वाचत नाही. macOS 26 वर: स्पष्ट त्रुटीसह 400. पहा [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` हेडर | समर्थित | `--token` सेट असताना आवश्यक. पहा [docs/server-security.md](../docs/server-security.md) |

संपूर्ण API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## डिफॉल्ट रिस्पॉन्स मर्यादा (`max_tokens`)

`max_tokens` वगळले असता **CLI आणि OpenAI-सुसंगत सर्व्हर सारखेच वागतात**: व्हॅल्यू `nil` म्हणून पुढे जाते आणि मॉडेल कॉन्टेक्स्ट विंडोमध्ये उरलेली जागा वापरते. ही OpenAI प्रमाणेच सिमॅन्टिक्स आहे - कोणताही मनमानी फॉलबॅक कॉन्स्टंट नाही.

ऑन-डिव्हाइस कॉन्टेक्स्ट विंडोमध्ये इनपुट *आणि* आउटपुट दोन्ही मिळून बसतात: **macOS 26 वर आणि M1/M2 Mac वर 4096 टोकन, M3 किंवा नवीन चिप आणि 12 GB+ सह macOS 27 वर 8192 टोकन**. apfel खरा आकार रनटाइमवर `SystemLanguageModel.contextSize` द्वारे वाचतो - तुमचा `apfel --model-info` ने तपासा. जनरेशन मर्यादेला भिडल्यास, रिस्पॉन्स `finish_reason: "length"` सह स्वच्छपणे संपतो आणि अपूर्ण मजकूर परत दिला जातो (सर्व्हर: HTTP 200; CLI: stderr इशाऱ्यासह exit 0, किंवा `--require-complete` सह exit 8 - पहा [docs/cli-reference.md](../docs/cli-reference.md)). अधिक कडक लेटन्सी बजेट किंवा तुमच्या क्लायंटसाठी ज्ञात मर्यादा हवी असल्यास `max_tokens` स्पष्टपणे द्या.

### उदाहरणे

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

### व्हॅल्यू निवडणे

| वापर                               | `max_tokens`  |
|----------------------------------------|---------------|
| एक शब्द / वर्गीकरण उत्तर     | 16 - 32       |
| एका ओळीची सूचना                    | 64 - 128      |
| छोटा परिच्छेद                        | 256 - 512     |
| मोठा परिच्छेद / स्ट्रक्चर्ड JSON       | 1024 - 2048   |
| कॉन्टेक्स्ट विंडो परवानगी देईल तितके लांब   | वगळा       |

`input_tokens + max_tokens` कॉन्टेक्स्ट विंडोच्या आरामात खाली ठेवा (macOS 26 वर आणि M1/M2 Mac वर 4096 टोकन, M3 किंवा नवीन चिप आणि 12 GB+ सह macOS 27 वर 8192 (Apple चे AFM 3 Core Advanced मॉडेल)). prompt स्वतःच विंडोपेक्षा मोठा असल्यास, जनरेशन सुरू होऊ शकत नाही आणि रिक्वेस्ट `[context overflow]` सह अयशस्वी होते (HTTP 400 / CLI exit 4). व्हॅलिडेटर धन नसलेल्या व्हॅल्यू (`max_tokens <= 0`) नाकारतो.

### CLI समानता

CLI आणि सर्व्हर एकच नियम वापरतात: वगळले = उरलेली विंडो वापरा. बदलत जाणारा कोणताही कॉन्स्टंट नाही. `--max-tokens N` किंवा `APFEL_MAX_TOKENS=N` ने बदला.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### सर्व्हरसाठी permissive गार्डरेल

`apfel --serve --permissive` सर्व्हरला प्रोसेस हाताळत असलेल्या **प्रत्येक रिक्वेस्ट** साठी Apple चे `.permissiveContentTransformations` गार्डरेल वापरायला लावते. CLI च्या `--permissive` सारखाच फ्लॅग, तीच सिमॅन्टिक्स ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). रिक्वेस्टनुसार ओव्हरराइड नाही - संपूर्ण प्रोसेससाठी सर्व्हर ऑपरेटर ठरवतो.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## मर्यादा

| मर्यादा | तपशील |
|------------|--------|
| कॉन्टेक्स्ट विंडो | **macOS 26 वर आणि M1/M2 Mac वर 4096 टोकन, M3 किंवा नवीन चिप आणि 12 GB+ सह macOS 27 वर 8192 टोकन** (इनपुट + आउटपुट मिळून). हार्डकोड केलेला कॉन्स्टंट नाही - apfel रनटाइमवर `SystemLanguageModel.contextSize` वाचतो; `apfel --model-info` सध्याची व्हॅल्यू छापतो |
| प्लॅटफॉर्म | macOS 26+, फक्त Apple Silicon |
| मॉडेल | एकच ऑन-डिव्हाइस मॉडेल (~3B पॅरामीटर), `apple-foundationmodel` (सामान्य) आणि `apple-foundationmodel-content-tagging` (Apple चा कंटेंट-टॅगिंग अ‍ॅडॉप्टर; टूल नाहीत) म्हणून उपलब्ध |
| गार्डरेल | Apple ची सुरक्षा प्रणाली निरुपद्रवी prompt देखील अडवू शकते. `--permissive` चुकीचे पॉझिटिव्ह कमी करते ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| वेग | ऑन-डिव्हाइस, क्लाउड-स्केल नाही - प्रत्येक उत्तरासाठी काही सेकंद |
| एम्बेडिंग नाही | ऑन-डिव्हाइस उपलब्ध नाही |
| व्हिजन | इमेज इनपुट मॉडेलपर्यंत फक्त macOS 27 वर पोहोचते (सर्व्हर: data URL; CLI: `-f photo.jpg` आणि पाइप केलेल्या इमेज, OCR मजकुराव्यतिरिक्त). macOS 26 वर इमेज OCR/वर्गीकरणाद्वारे फक्त मजकूर म्हणून. 3B मॉडेलची दृश्य वर्णने ढोबळ असतात - छापील वाचण्यासाठी OCR हाच भरवशाचा मार्ग राहतो |
| ट्रेनिंग डेटा / नॉलेज कटऑफ | Apple ने ऑन-डिव्हाइस मॉडेलसाठी नेमका कटऑफ प्रसिद्ध केलेला नाही. नाव सांगायला भाग पाडले की मॉडेल **प्रत्येक सॅम्पलमध्ये वेगळी तारीख रचते** (उदा. "October 2023", "April 2023"). मॉडेलने स्वतःच्या ट्रेनिंगबद्दल केलेले सर्व दावे अविश्वसनीय समजा. |
| सध्याची तारीख किंवा रिअल-टाइमची जाणीव नाही | मॉडेलला आजची तारीख माहीत नाही आणि नेटवर्क/घड्याळ उपलब्ध नाही. विचारल्यास ते एकतर नकार देईल किंवा तारीख रचेल. गणित तारखेवर अवलंबून असल्यास सध्याची तारीख system prompt द्वारे द्या (खालील उपाय पहा). |

**तारखेवर अवलंबून prompt साठी उपाय** - सध्याची तारीख system मेसेज म्हणून द्या:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

टीप: तारीख दिल्यानंतरही 3B मॉडेल भ्रम निर्माण करू शकते (विशेषतः स्वतःच्या ट्रेनिंग कटऑफबद्दल थेट विचारल्यास). हे इंजेक्शन तारखेचा *वापर करणाऱ्या* जनरेटिव्ह prompt ना मदत करते; मॉडेलची स्वतःबद्दल बोलण्याची सवय ते बदलत नाही.

पार्श्वभूमी: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## रेफरन्स डॉक्स

apfel [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) मधून वापरण्याचे मार्गदर्शक - पहा [docs/guides/index.md](../docs/guides/index.md). प्रत्यक्ष चाचणी केलेले; चालवता येणारा पुरावा [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) वर.

- [docs/install.md](../docs/install.md) - इन्स्टॉल, ट्रबलशूटिंग आणि Apple Intelligence सेटअप
- [docs/cli-reference.md](../docs/cli-reference.md) - प्रत्येक फ्लॅग, एक्झिट कोड आणि एन्व्हायर्नमेंट व्हेरिएबल
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` आणि पाइप केलेले PDF / इमेज / मजकूर एक्स्ट्रॅक्शन (OCR + इमेज समज)
- [docs/background-service.md](../docs/background-service.md) - `brew services` आणि launchd वापर
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` सपोर्ट मॅट्रिक्स सविस्तर
- [docs/server-security.md](../docs/server-security.md) - origin तपासणी, CORS, टोकन आणि `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - चॅट ट्रिमिंग स्ट्रॅटेजी
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - स्थानिक आणि रिमोट MCP वापर
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - टूल-कॉलिंग वर्तनाचे सविस्तर वर्णन
- [docs/integrations.md](../docs/integrations.md) - थर्ड-पार्टी टूल इंटिग्रेशन (opencode, इ.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code मध्ये apfel + दुसरे edit/apply मॉडेल वापरून स्थानिक रिव्ह्यू
- [docs/demos.md](../docs/demos.md) - शेल डेमोचे विस्तृत वॉकथ्रू
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - संपादन न केलेल्या आउटपुटसह 50+ खरे prompt
- [docs/swift-library.md](../docs/swift-library.md) - डाउनस्ट्रीम डेव्हलपरसाठी `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel FoundationModels वर का चालतो, Apple च्या नवीन Core AI (Core ML चा उत्तराधिकारी) वर का नाही
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel ची Apple च्या स्वतःच्या `fm` CLI (macOS 27) शी तुलना, वैशिष्ट्यानुसार, मोजलेल्या आकड्यांसह

## आर्किटेक्चर

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 स्ट्रिक्ट कॉन्करन्सी. तीन टार्गेट: `ApfelCore` (शुद्ध लॉजिक, युनिट-टेस्टेबल, Swift Package प्रॉडक्ट म्हणूनही उपलब्ध - वर रेफरन्स डॉक्समध्ये लिंक), `apfel` (CLI + सर्व्हर), आणि `apfel-tests` (शुद्ध Swift रनर, XCTest नाही).

## बिल्ड आणि टेस्ट

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

`.version` हा एकमेव सत्य-स्रोत आहे. फक्त `make release` आवृत्ती वाढवते. स्थानिक बिल्ड आवृत्ती बदलत नाहीत.

## apfel वृक्ष

apfel वर बनवलेले प्रोजेक्ट. प्रत्येक स्वतःच्या रेपो + Homebrew फॉर्म्युलासह येतो.

| प्रोजेक्ट | तो काय करतो | इन्स्टॉल |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | मूळ. ऑन-डिव्हाइस FoundationModels CLI + OpenAI-सुसंगत सर्व्हर. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS चॅट क्लायंट: स्ट्रीमिंग markdown, स्पीच I/O, Apple Vision इमेज विश्लेषण. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | क्लिपबोर्डवर मेनू-बार AI क्रिया: सारांश, भाषांतर, पुनर्लेखन. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | तात्काळ AI ओव्हरले: की दाबा, विचारा, उत्तर मिळवा, बंद करा. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | फॉर्म्युला नोटपॅड - ऑन-डिव्हाइस AI इनलाइन सेल फंक्शन म्हणून. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | छोट्या ऑन-डिव्हाइस विंडोसाठी टोकन-बजेट ऑप्टिमाइझ्ड MCP: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI डीबग इन्स्पेक्टर: रिक्वेस्ट टाइमलाइन, MCP प्रोटोकॉल व्ह्यूअर, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` वर कायमस्वरूपी MCP रजिस्ट्री + TOML कॉन्फिग जोडणारा UNIX रॅपर. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | ऑन-डिव्हाइस कन्टेंट टॅगिंग CLI: मजकूर पाइप करा, टॅग/विषय/भावना मिळवा. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | इकोसिस्टम टूलसाठी Swift package: स्थानिक `apfel --serve` शोधा, सुरू करा आणि त्यातून स्ट्रीम करा. | Swift Package |

## कम्युनिटी प्रोजेक्ट

apfel वर काही बनवले आहे? एक issue उघडा आणि ते इथे जोडता येईल.

| प्रोजेक्ट | तो काय करतो | लिंक |
|---------|-------------|-------|
| **apfelclaw** by [@julianYaman](https://github.com/julianYaman) | फाइल, कॅलेंडर, मेल आणि Mac स्टेटस read-only टूलने वाचणारा स्थानिक AI एजंट | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** by [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI-सुसंगत API द्वारे `apfel --serve` शी बोलणारे ब्राउझर-आधारित चॅट UI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** by [@lucaspwo](https://github.com/lucaspwo) | छोट्या Anthropic-OpenAI प्रॉक्सीद्वारे apfel ला स्थानिक बॅकएंड म्हणून बसवणारा Claude Code रॅपर | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** by [@hasit](https://github.com/hasit) | apfel भोवती बनवलेल्या स्थानिक शेल ॲप्ससाठी ॲप मॅनेजर | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** by [@eggsy](https://github.com/eggsy) | Raycast कमांड बार एक्स्टेन्शन: विचारा, भाषांतर करा, फाइल आणि डिरेक्टरी समजावून सांगा, संभाषण इतिहास, कस्टम system prompt. apfel CLI द्वारे ऑन-डिव्हाइस. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## योगदान

कोणत्याही `Arthur-Ficial/apfel*` रेपोवर issue आणि PR चे स्वागत आहे.

**#agentswelcome** - AI एजंटचे PR चालतात. रेपोची `CLAUDE.md` वाचा, टेस्ट चालवा, `Co-Authored-By` ट्रेलरमध्ये टूलला श्रेय द्या. माणसांइतकेच मानक: स्वच्छ कोड, पास होणाऱ्या टेस्ट, प्रामाणिक मर्यादा. सर्वात एजंट-फ्रेंडली प्रवेशबिंदू: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([योगदानाचे नियम](https://apfel-mcp.franzai.com/#contribute)).

## लायसन्स

[MIT](../LICENSE)
