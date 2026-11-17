<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [अंग्रेज़ी README](../README.md) से अनूदित। अंग्रेज़ी संस्करण ही प्रामाणिक है।

# apfel

### आपके Mac में पहले से मौजूद मुफ़्त AI।

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon वाले Mac [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) के ज़रिए एक बिल्ट-इन LLM के साथ आते हैं। `apfel` इसे UNIX टूल और लोकल OpenAI-compatible सर्वर के रूप में उपलब्ध कराता है। 100% ऑन-डिवाइस। न API keys, न क्लाउड।

| मोड | कमांड | आपको क्या मिलता है |
|------|---------|--------------|
| UNIX टूल | `apfel "prompt"` / `echo "text" \| apfel` | pipe के अनुकूल जवाब, फ़ाइल अटैचमेंट, JSON आउटपुट, exit codes |
| OpenAI-compatible सर्वर | `apfel --serve` | OpenAI SDKs के लिए सीधा लोकल `http://localhost:11434/v1` बैकएंड |

`apfel --chat` - इंटरैक्टिव REPL।

[![apfel टर्मिनल डेमो वीडियो: असली कमांड, डिवाइस पर असली जवाब (82 सेकंड)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/hi/a/apfel-ai-tutorial/#video)

Tool calling सभी मोड में काम करती है।

![apfel CLI](../screenshots/cli.png)

## आवश्यकताएँ और इंस्टॉल

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence चालू](https://support.apple.com/en-us/121115)। macOS 27 पर M3 या नई चिप और 12 GB+ वाले Mac Apple का बड़ा ऑन-डिवाइस मॉडल 8192-टोकन विंडो के साथ चलाते हैं; M1/M2 Mac और macOS 26 पर हर Mac में 4096 होती है। `apfel --model-info` आपके Mac की वैल्यू दिखाता है।

```bash
brew install apfel
```

अपडेट:

```bash
brew upgrade apfel
```

सोर्स से बनाएँ (macOS 27 SDK / Swift 6.3 वाले Command Line Tools, Xcode के बिना; बाइनरी macOS 26 और 27 पर चलती है):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Same-day tap, Mint, mise, समस्या-निवारण: [docs/install.md](../docs/install.md)।

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | **हिन्दी** | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## क्विक स्टार्ट

### UNIX टूल

जिन prompts में `!` हो, उन्हें सिंगल कोट्स में लिखें (zsh/bash history expansion): `apfel 'Hello, Mac!'`।

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

### OpenAI-compatible सर्वर

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

बैकग्राउंड सर्विस का विवरण: [docs/background-service.md](../docs/background-service.md)।

### त्वरित टेस्टिंग चैट

`apfel --chat` prompts या MCP सर्वर आज़माने के लिए एक छोटा REPL है। GUI चैट ऐप के लिए [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) देखें।

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C से बाहर निकलें। context अपने आप छाँटा जाता है ([docs/context-strategies.md](../docs/context-strategies.md))।

स्क्रिप्ट लिखने से पहले जानने लायक सीमाएँ (हर Mac की context विंडो, guardrails, embeddings का न होना): [सीमाएँ](../README.md#limitations)।

## डेमो

असली shell स्क्रिप्ट जो `apfel` को लपेटती हैं: `cmd` (अंग्रेज़ी से shell कमांड), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`। ये बाइनरी में ही शामिल हैं - रेपो clone करने की ज़रूरत नहीं। जहाँ से आपने apfel इंस्टॉल किया (homebrew-core, tap या सोर्स), उन्हें वहीं से लिख निकालें:

```bash
apfel demos ./apfel-demos
```

यह हर डेमो (executable) और एक `README.md` को `./apfel-demos` में लिख देता है। फिर उन्हें वहीं से चलाएँ:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

अपडेट के लिए `brew upgrade apfel` के बाद `apfel demos` दोबारा चलाएँ। सोर्स: [`demo/`](../demo/)। विस्तृत walkthroughs और आपकी `.zshrc` के लिए कॉपी-पेस्ट `cmd` shell फ़ंक्शन: [docs/demos.md](../docs/demos.md)।

## MCP टूल सपोर्ट

[Model Context Protocol](https://modelcontextprotocol.io/) सर्वर `--mcp` से जोड़ें। apfel उन्हें खोजता है, चलाता है और नतीजा लौटाता है।

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

टूल की जानकारी छिपाने के लिए `-q` इस्तेमाल करें।

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

साथ में एक calculator आता है: [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md))।

**रिमोट MCP सर्वर** (Streamable HTTP, MCP spec 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **सुरक्षा:** `--mcp-token` (ps aux में दिखता है) की जगह `APFEL_MCP_TOKEN` को चुनें। apfel सादे `http://` पर bearer tokens भेजने से मना करता है।

## apfel-run: वैकल्पिक कॉन्फ़िग लेयर

apfel में खुद कोई कॉन्फ़िग फ़ाइल नहीं है - flags और env vars, किसी भी UNIX टूल की तरह। अगर आपको TOML कॉन्फ़िग चाहिए (कई MCPs, प्रोफ़ाइल, git में टीम कॉन्फ़िग), तो [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) एक MIT wrapper है जो `execve` के ज़रिए सीधे बदलाव के रूप में यह सुविधा जोड़ता है।

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API संगतता

**Base URL:** `http://localhost:11434/v1`

| सुविधा | स्थिति | टिप्पणी |
|---------|--------|-------|
| `POST /v1/chat/completions` | समर्थित | streaming + non-streaming |
| `POST /v1/responses` | समर्थित | OpenAI Responses API: string/message इनपुट, `instructions`, streaming (मानक event क्रम), `text.format` (`json_schema` सहित), function tools (non-streaming)। stateful सुविधाएँ (`previous_response_id`, `store: true`, `background`, `reasoning`, hosted tools) ईमानदार 501 लौटाती हैं |
| `POST /v1/responses/input_tokens` | समर्थित | टोकन preflight (`client.responses.input_tokens.count(...)`): Apple के tokenizer से सटीक गिनती, बिना generation के; macOS 26.4 से नीचे अनुमान की जगह 501। देखें [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | समर्थित | `apple-foundationmodel` (सामान्य, डिफ़ॉल्ट) और `apple-foundationmodel-content-tagging` (लेबल, गद्य नहीं) लौटाता है। देखें [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | समर्थित | मॉडल की उपलब्धता, context विंडो, भाषाएँ, रिपोर्ट की गई मॉडल क्षमताएँ (`capabilities`, `capabilities_reported`), सेवा दे रहा मॉडल वैरिएंट (`variant`, जैसे AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | केवल debug | `--debug` ज़रूरी है |
| Tool calling | समर्थित | कॉल guided generation के ज़रिए (`--tool-calling guided`, डिफ़ॉल्ट) या ऐसे JSON के रूप में लिखी जाती है जिसे सर्वर पार्स करता है (`--tool-calling text`)। देखें [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | समर्थित | system-prompt injection; आउटपुट से markdown fences हटा दिए जाते हैं |
| `response_format: json_schema` | समर्थित | FoundationModels के `DynamicGenerationSchema` से schema के अनुरूप आउटपुट की गारंटी; `stream: true` के साथ काम करता है |
| `temperature`, `top_p`, `max_tokens`, `seed` | समर्थित | `GenerationOptions` से map होते हैं। `top_p` nucleus sampling है; 0.001 से कम `temperature` (0 सहित) greedy (deterministic) पर map होता है। `max_tokens` छोड़ने पर context विंडो का बचा हिस्सा इस्तेमाल होता है (सीधे बदलाव वाला OpenAI अर्थ) - देखें [डिफ़ॉल्ट response सीमा](../README.md#default-response-cap-max_tokens) |
| `stream: true` | समर्थित | SSE; अंतिम usage chunk केवल तब जब `stream_options: {"include_usage": true}` हो (OpenAI spec के अनुसार) |
| `usage` | समर्थित | macOS 26.4+ पर असली tokenizer गिनती (इससे नीचे chars/4 का अनुमान)। macOS 27: runtime का अपना हिसाब, Apple की chat-template फ़्रेमिंग सहित (एक-पंक्ति prompt पर लगभग 46 अतिरिक्त `prompt_tokens`); macOS 26: apfel संदेश का टेक्स्ट गिनता है। विवरण [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) में |
| `finish_reason` | समर्थित | `stop`, `tool_calls`, `length` |
| Context रणनीतियाँ | समर्थित | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` एक्सटेंशन फ़ील्ड |
| CORS | समर्थित | `--cors` से चालू करें |
| `POST /v1/completions` | 501 | Legacy text completions समर्थित नहीं |
| `POST /v1/embeddings` | 501 | Embeddings ऑन-डिवाइस उपलब्ध नहीं |
| `stop` | समर्थित | एक string या अधिकतम 4 strings; केवल सादा टेक्स्ट (tools दायरे में हों या `json_object`/`json_schema` हो तो 400)। आउटपुट की ओर लागू होता है, streaming और non-streaming में एक जैसा। देखें [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | साफ़ तौर पर अस्वीकृत। `n=1` और `logprobs=false` बिना असर वाले मानकर स्वीकार किए जाते हैं |
| Multi-modal (छवियाँ) | macOS 27 पर समर्थित | base64 data URLs के रूप में `image_url` हिस्से सीधे ऑन-डिवाइस मॉडल तक जाते हैं (20 MB base64 सीमा, लंबी भुजा 4096 px तक छोटी की जाती है)। रिमोट `http(s)` URLs और फ़ाइल पाथ हमेशा 400 - apfel कभी छवियाँ fetch नहीं करता और किसी HTTP क्लाइंट के लिए कभी फ़ाइलें नहीं पढ़ता। macOS 26 पर: स्पष्ट त्रुटि के साथ 400। देखें [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` हेडर | समर्थित | `--token` सेट होने पर ज़रूरी। देखें [docs/server-security.md](../docs/server-security.md) |

पूरा API spec: [openai/openai-openapi](https://github.com/openai/openai-openapi)।

## डिफ़ॉल्ट response सीमा (`max_tokens`)

जब `max_tokens` छोड़ा जाता है, तो **CLI और OpenAI-compatible सर्वर एक जैसा व्यवहार करते हैं**: वैल्यू `nil` के रूप में गुज़रती है और मॉडल context विंडो में बची जगह इस्तेमाल करता है। यह सीधे बदलाव वाला OpenAI अर्थ है - कोई मनमाना fallback स्थिरांक नहीं।

ऑन-डिवाइस context विंडो इनपुट *और* आउटपुट दोनों को मिलाकर रखती है: **macOS 26 पर और M1/M2 Mac पर 4096 टोकन, macOS 27 पर M3 या नई चिप और 12 GB+ के साथ 8192 टोकन**। apfel असली आकार runtime पर `SystemLanguageModel.contextSize` से पढ़ता है - अपनी वैल्यू `apfel --model-info` से देखें। अगर generation सीमा से टकरा जाए, तो response साफ़-सुथरे ढंग से `finish_reason: "length"` के साथ खत्म होता है और अधूरा कंटेंट लौटाया जाता है (सर्वर: HTTP 200; CLI: exit 0 और stderr में चेतावनी, या `--require-complete` के साथ exit 8 - देखें [docs/cli-reference.md](../docs/cli-reference.md))। जब आपको कड़ा latency बजट या अपने क्लाइंट के लिए तय सीमा चाहिए, तो `max_tokens` साफ़ तौर पर दें।

### उदाहरण

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

### वैल्यू चुनना

| उपयोग                                  | `max_tokens`  |
|----------------------------------------|---------------|
| एक शब्द / classification का जवाब        | 16 - 32       |
| एक पंक्ति का निर्देश                    | 64 - 128      |
| छोटा पैराग्राफ़                         | 256 - 512     |
| लंबा पैराग्राफ़ / structured JSON       | 1024 - 2048   |
| जितना context विंडो अनुमति दे           | छोड़ दें       |

`input_tokens + max_tokens` को context विंडो से आराम से नीचे रखें (macOS 26 पर और M1/M2 Mac पर 4096 टोकन, macOS 27 पर M3 या नई चिप और 12 GB+ के साथ 8192 (Apple का AFM 3 Core Advanced मॉडल))। अगर prompt खुद विंडो से बड़ा हो, तो generation शुरू नहीं हो सकता और अनुरोध `[context overflow]` के साथ विफल होता है (HTTP 400 / CLI exit 4)। validator गैर-धनात्मक वैल्यू (`max_tokens <= 0`) को अस्वीकार करता है।

### CLI से समानता

CLI और सर्वर एक ही नियम साझा करते हैं: छोड़ा गया = बची हुई विंडो इस्तेमाल करो। कोई स्थिरांक नहीं जो अलग हो जाए। `--max-tokens N` या `APFEL_MAX_TOKENS=N` से बदलें।

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### सर्वर के लिए permissive guardrails

`apfel --serve --permissive` सर्वर को उस प्रोसेस द्वारा संभाले गए **हर अनुरोध** के लिए Apple के `.permissiveContentTransformations` guardrails इस्तेमाल करवाता है। वही flag, वही अर्थ जो CLI के `--permissive` का है ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md))। हर अनुरोध के लिए अलग override नहीं है - पूरे प्रोसेस का फ़ैसला सर्वर चलाने वाला करता है।

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## सीमाएँ

| बाध्यता | विवरण |
|------------|--------|
| Context विंडो | **macOS 26 पर और M1/M2 Mac पर 4096 टोकन, macOS 27 पर M3 या नई चिप और 12 GB+ के साथ 8192 टोकन** (इनपुट + आउटपुट मिलाकर)। कोड में लिखा स्थिरांक नहीं - apfel runtime पर `SystemLanguageModel.contextSize` पढ़ता है; `apfel --model-info` मौजूदा वैल्यू छापता है |
| प्लेटफ़ॉर्म | macOS 26+, केवल Apple Silicon |
| मॉडल | एक ऑन-डिवाइस मॉडल (लगभग 3B पैरामीटर), `apple-foundationmodel` (सामान्य) और `apple-foundationmodel-content-tagging` (Apple का content-tagging एडैप्टर; कोई टूल नहीं) के रूप में उपलब्ध |
| Guardrails | Apple की सुरक्षा प्रणाली हानिरहित prompts को भी रोक सकती है। `--permissive` झूठे पॉज़िटिव घटाता है ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| गति | ऑन-डिवाइस, क्लाउड स्केल की नहीं - हर जवाब में कुछ सेकंड |
| Embeddings नहीं | ऑन-डिवाइस उपलब्ध नहीं |
| Vision | छवि इनपुट केवल macOS 27 पर मॉडल तक पहुँचता है (सर्वर: data URLs; CLI: `-f photo.jpg` और pipe की गई छवियाँ, OCR टेक्स्ट के अलावा)। macOS 26 पर छवियाँ OCR/classification के ज़रिए केवल टेक्स्ट रूप में होती हैं। 3B मॉडल के दृश्य-विवरण मोटे-मोटे होते हैं - छपा टेक्स्ट पढ़ने के लिए OCR ही भरोसेमंद रास्ता है |
| ट्रेनिंग डेटा / ज्ञान की सीमा | Apple ने ऑन-डिवाइस मॉडल की कोई सटीक cutoff तारीख प्रकाशित नहीं की है। दबाव डालने पर मॉडल **हर सैंपल में अलग तारीख गढ़ देता है** (जैसे "October 2023", "April 2023")। मॉडल के अपनी ट्रेनिंग के बारे में किए गए हर दावे को अविश्वसनीय मानें। |
| मौजूदा तारीख या real-time जानकारी नहीं | मॉडल को आज की तारीख नहीं पता और उसके पास नेटवर्क/घड़ी तक पहुँच नहीं है। पूछने पर वह या तो मना कर देगा या तारीख गढ़ देगा। जब गणना तारीख पर निर्भर हो, तो मौजूदा तारीख system prompt से दें (नीचे workaround देखें)। |

**तारीख पर निर्भर prompts के लिए workaround** - मौजूदा तारीख को system संदेश के रूप में जोड़ें:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

ध्यान दें: तारीख जोड़ने के बाद भी 3B मॉडल hallucinate कर सकता है (खासकर जब उससे सीधे उसकी अपनी ट्रेनिंग cutoff के बारे में पूछा जाए)। यह तरीका उन generative prompts में मदद करता है जो तारीख *इस्तेमाल* करते हैं; यह मॉडल की खुद के बारे में बताने की आदत को खत्म नहीं करता।

पृष्ठभूमि: [#158](https://github.com/Arthur-Ficial/apfel/issues/158)।

## संदर्भ दस्तावेज़

[Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) से apfel इस्तेमाल करने की गाइड - देखें [docs/guides/index.md](../docs/guides/index.md)। अनुभव से परखी गई; चलने योग्य प्रमाण [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) में।

- [docs/install.md](../docs/install.md) - इंस्टॉल, समस्या-निवारण और Apple Intelligence सेटअप
- [docs/cli-reference.md](../docs/cli-reference.md) - हर flag, exit code और एनवायरनमेंट वेरिएबल
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` और pipe किए गए PDF / छवि / टेक्स्ट का निष्कर्षण (OCR + छवि की समझ)
- [docs/background-service.md](../docs/background-service.md) - `brew services` और launchd का उपयोग
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` सपोर्ट मैट्रिक्स विस्तार से
- [docs/server-security.md](../docs/server-security.md) - origin जाँच, CORS, tokens और `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - चैट trimming रणनीतियाँ
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - लोकल और रिमोट MCP का उपयोग
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - tool calling के व्यवहार का विस्तृत विवरण
- [docs/integrations.md](../docs/integrations.md) - थर्ड-पार्टी टूल इंटीग्रेशन (opencode आदि)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code में apfel + दूसरे edit/apply मॉडल के साथ लोकल review
- [docs/demos.md](../docs/demos.md) - shell डेमो के लंबे walkthroughs
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - बिना संपादन वाले आउटपुट के साथ 50+ असली prompts
- [docs/swift-library.md](../docs/swift-library.md) - डाउनस्ट्रीम डेवलपर्स के लिए `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel Apple के नए Core AI (Core ML के उत्तराधिकारी) की जगह FoundationModels पर क्यों चलता है
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel की Apple के अपने `fm` CLI (macOS 27) से तुलना, फ़ीचर दर फ़ीचर, नापे गए आँकड़ों के साथ

## आर्किटेक्चर

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 strict concurrency। तीन targets: `ApfelCore` (शुद्ध लॉजिक, unit-test योग्य, Swift Package प्रोडक्ट के रूप में भी उपलब्ध - ऊपर संदर्भ दस्तावेज़ों में लिंक), `apfel` (CLI + सर्वर), और `apfel-tests` (शुद्ध Swift runner, XCTest के बिना)।

## बिल्ड और टेस्ट

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

`.version` ही एकमात्र स्रोत है। केवल `make release` वर्ज़न बढ़ाता है। लोकल builds वर्ज़न नहीं बदलतीं।

## apfel का वृक्ष

apfel पर बने प्रोजेक्ट। हर एक अपने रेपो और Homebrew formula के साथ आता है।

| प्रोजेक्ट | क्या करता है | इंस्टॉल |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | जड़। ऑन-डिवाइस FoundationModels CLI + OpenAI-compatible सर्वर। | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS चैट क्लाइंट: streaming markdown, आवाज़ का इनपुट/आउटपुट, Apple Vision से छवि विश्लेषण। | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | क्लिपबोर्ड पर menu-bar AI क्रियाएँ: सारांश, अनुवाद, पुनर्लेखन। | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | तुरंत AI ओवरले: कुंजी दबाएँ, पूछें, जवाब पाएँ, बंद करें। | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | फ़ॉर्मूला नोटपैड - ऑन-डिवाइस AI इनलाइन सेल फ़ंक्शन के रूप में। | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | छोटी ऑन-डिवाइस विंडो के लिए टोकन-बजट के अनुसार बने MCPs: `url-fetch`, `ddg-search`, `search-and-fetch`। | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI debug inspector: अनुरोधों की टाइमलाइन, MCP प्रोटोकॉल व्यूअर, TTS/STT। | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | UNIX wrapper जो `apfel` के ऊपर स्थायी MCP रजिस्ट्री + TOML कॉन्फ़िग जोड़ता है। | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | ऑन-डिवाइस कंटेंट टैगिंग CLI: टेक्स्ट pipe करें, tags/विषय/भावनाएँ पाएँ। | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | इकोसिस्टम टूल्स के लिए Swift package: लोकल `apfel --serve` को खोजें, चलाएँ और उससे stream करें। | Swift Package |

## कम्युनिटी प्रोजेक्ट

apfel के ऊपर कुछ बनाया है? एक issue खोलें, उसे यहाँ जोड़ा जा सकता है।

| प्रोजेक्ट | क्या करता है | लिंक |
|---------|-------------|-------|
| **apfelclaw** द्वारा [@julianYaman](https://github.com/julianYaman) | लोकल AI एजेंट जो केवल-पढ़ने वाले टूल्स से फ़ाइलें, कैलेंडर, मेल और Mac की स्थिति पढ़ता है | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** द्वारा [@bhaskarvilles](https://github.com/bhaskarvilles) | ब्राउज़र-आधारित चैट UI जो OpenAI-compatible API से `apfel --serve` से बात करता है | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** द्वारा [@lucaspwo](https://github.com/lucaspwo) | Claude Code wrapper जो एक छोटी Anthropic-OpenAI proxy के ज़रिए apfel को लोकल बैकएंड बनाता है | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** द्वारा [@hasit](https://github.com/hasit) | apfel के आसपास बने लोकल shell ऐप्स के लिए ऐप मैनेजर | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** द्वारा [@eggsy](https://github.com/eggsy) | Raycast कमांड बार एक्सटेंशन: पूछें, अनुवाद करें, फ़ाइलों और डायरेक्टरी की व्याख्या, बातचीत का इतिहास, कस्टम system prompts। apfel CLI से ऑन-डिवाइस। | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## योगदान

किसी भी `Arthur-Ficial/apfel*` रेपो पर issues और PRs का स्वागत है।

**#agentswelcome** - AI एजेंट के PRs ठीक हैं। रेपो की `CLAUDE.md` पढ़ें, टेस्ट चलाएँ, और टूल का नाम `Co-Authored-By` trailer में लिखें। मानक इंसानों जैसा ही है: साफ़ कोड, पास होते टेस्ट, ईमानदार सीमाएँ। एजेंट्स के लिए सबसे उपयुक्त शुरुआत: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([योगदान के नियम](https://apfel-mcp.franzai.com/#contribute))।

## लाइसेंस

[MIT](../LICENSE)
