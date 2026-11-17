<!-- i18n-source: e8eb4f6c529cf64d34734df80149c4cdbd7dd262 -->

> [İngilizce README](../README.md) dosyasından çevrilmiştir. Geçerli olan sürüm İngilizce sürümdür.

# apfel

### Mac'inizde zaten hazır duran ücretsiz yapay zeka.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Apple Silicon Mac'ler, [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels) aracılığıyla yerleşik bir LLM ile gelir. `apfel` bunu bir UNIX aracı ve yerel, OpenAI uyumlu bir sunucu olarak sunar. %100 cihaz üzerinde. API anahtarı yok, bulut yok.

| Mod | Komut | Ne elde edersiniz |
|-----|-------|-------------------|
| UNIX aracı | `apfel "prompt"` / `echo "text" \| apfel` | Pipe dostu yanıtlar, dosya ekleri, JSON çıktısı, çıkış kodları |
| OpenAI uyumlu sunucu | `apfel --serve` | OpenAI SDK'ları için doğrudan yerine geçen yerel `http://localhost:11434/v1` arka ucu |

`apfel --chat` - etkileşimli REPL.

[![apfel terminal demo videosu: gerçek komutlar, cihaz üzerinde gerçek yanıtlar (82 saniye)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/tr/a/apfel-ai-tutorial/#video)

Araç çağırma (tool calling) tüm bağlamlarda çalışır.

![apfel CLI](../screenshots/cli.png)

## Gereksinimler ve kurulum

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence etkin](https://support.apple.com/en-us/121115). macOS 27'de M3 veya daha yeni çipli ve 12 GB+ belleğe sahip Mac'ler, Apple'ın daha büyük cihaz üzeri modelini 8192 token'lık pencereyle çalıştırır; M1/M2 Mac'ler ve macOS 26 çalıştıran her Mac'te 4096'dır. `apfel --model-info` sizinkini gösterir.

```bash
brew install apfel
```

Güncelleme:

```bash
brew upgrade apfel
```

Kaynaktan derleme (macOS 27 SDK / Swift 6.3 ile Command Line Tools, Xcode yok; ikili dosya macOS 26 ve 27'de çalışır):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Aynı gün tap, Mint, mise, sorun giderme: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | **Türkçe** | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Hızlı başlangıç

### UNIX aracı

İçinde `!` bulunan prompt'ları tek tırnak içine alın (zsh/bash geçmiş genişletmesi): `apfel 'Hello, Mac!'`.

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

### OpenAI uyumlu sunucu

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

Arka plan hizmeti ayrıntıları: [docs/background-service.md](../docs/background-service.md).

### Hızlı deneme sohbeti

`apfel --chat`, prompt'ları veya MCP sunucularını denemek için küçük bir REPL'dir. Grafik arayüzlü bir sohbet uygulaması için [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat) projesine bakın.

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C ile çıkılır. Bağlam otomatik olarak kırpılır ([docs/context-strategies.md](../docs/context-strategies.md)).

Üzerine script yazmadan önce bilmeye değer kısıtlar (Mac'e göre bağlam penceresi, guardrails, embeddings yok): [Sınırlamalar](../README.md#limitations).

## Demolar

`apfel`'i saran gerçek shell script'leri: `cmd` (İngilizceden shell komutuna), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. İkili dosyanın içinde gömülü gelirler - depoyu klonlamanız gerekmez. apfel'i nereden kurduysanız (homebrew-core, tap veya kaynak) istediğiniz yere yazın:

```bash
apfel demos ./apfel-demos
```

Bu, tüm demoları (çalıştırılabilir) ve bir `README.md` dosyasını `./apfel-demos` içine yazar. Sonra buradan çalıştırın:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Yenilemek için `brew upgrade apfel` sonrasında `apfel demos` komutunu yeniden çalıştırın. Kaynaklar: [`demo/`](../demo/). Ayrıntılı anlatımlar ve `.zshrc` dosyanıza kopyalayıp yapıştırabileceğiniz bir `cmd` shell fonksiyonu: [docs/demos.md](../docs/demos.md).

## MCP araç desteği

[Model Context Protocol](https://modelcontextprotocol.io/) sunucularını `--mcp` ile bağlayın. apfel keşfeder, çağırır ve sonucu döndürür.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Araç bilgisini gizlemek için `-q` kullanın.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

[`mcp/calculator/`](../mcp/calculator/) içinde bir hesap makinesi ile birlikte gelir ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Uzak MCP sunucuları** (Streamable HTTP, MCP spesifikasyonu 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Güvenlik:** `--mcp-token` (ps aux'ta görünür) yerine `APFEL_MCP_TOKEN` tercih edin. apfel, düz metin `http://` üzerinden bearer token göndermeyi reddeder.

## apfel-run: isteğe bağlı yapılandırma katmanı

apfel'in kendisinin yapılandırma dosyası yoktur - her UNIX aracı gibi flag'ler + ortam değişkenleri kullanır. TOML yapılandırması istiyorsanız (çok sayıda MCP, profiller, git'te ekip yapılandırmaları), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) bunu `execve` ile doğrudan yerine geçen bir MIT sarmalayıcı olarak ekler.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## OpenAI API uyumluluğu

**Temel URL:** `http://localhost:11434/v1`

| Özellik | Durum | Notlar |
|---------|-------|--------|
| `POST /v1/chat/completions` | Destekleniyor | Streaming + streaming olmayan |
| `POST /v1/responses` | Destekleniyor | OpenAI Responses API: string/mesaj girdisi, `instructions`, streaming (kanonik olay dizisi), `text.format` (`json_schema` dahil), fonksiyon araçları (streaming olmayan). Durum bilgisi gerektiren özellikler (`previous_response_id`, `store: true`, `background`, `reasoning`, barındırılan araçlar) dürüst 501 döndürür |
| `POST /v1/responses/input_tokens` | Destekleniyor | Token ön denetimi (`client.responses.input_tokens.count(...)`): Apple'ın tokenizer'ından kesin sayım, üretim yok; macOS 26.4 altında tahmin yerine 501. Bkz. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Destekleniyor | `apple-foundationmodel` (genel, varsayılan) ve `apple-foundationmodel-content-tagging` (etiketler, düz metin değil) döndürür. Bkz. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Destekleniyor | Model kullanılabilirliği, bağlam penceresi, diller, bildirilen model yetenekleri (`capabilities`, `capabilities_reported`), hizmet veren model varyantı (`variant`, ör. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Yalnızca hata ayıklama | `--debug` gerektirir |
| Tool calling | Destekleniyor | Çağrı, güdümlü üretimle (`--tool-calling guided`, varsayılan) ya da sunucunun ayrıştırdığı JSON olarak (`--tool-calling text`) yazılır. Bkz. [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Destekleniyor | Sistem prompt'una enjeksiyon; markdown çitleri çıktıdan temizlenir |
| `response_format: json_schema` | Destekleniyor | FoundationModels `DynamicGenerationSchema` ile şemaya uygunluğu garanti çıktı; `stream: true` ile çalışır |
| `temperature`, `top_p`, `max_tokens`, `seed` | Destekleniyor | `GenerationOptions`'a eşlenir. `top_p` nucleus sampling'dir; 0.001'in altındaki `temperature` (0 dahil) greedy'ye (deterministik) eşlenir. `max_tokens` verilmezse kalan bağlam penceresi kullanılır (doğrudan yerine geçen OpenAI semantiği) - bkz. [Varsayılan yanıt sınırı](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Destekleniyor | SSE; son kullanım chunk'ı yalnızca `stream_options: {"include_usage": true}` olduğunda (OpenAI spesifikasyonuna göre) |
| `usage` | Destekleniyor | macOS 26.4+ üzerinde gerçek tokenizer sayımları (altında karakter/4 tahmini). macOS 27: Apple'ın chat-template çerçevesi dahil çalışma zamanının kendi hesabı (tek satırlık bir prompt'ta yaklaşık 46 ek `prompt_tokens`); macOS 26: apfel mesaj metnini sayar. Ayrıntılar [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) içinde |
| `finish_reason` | Destekleniyor | `stop`, `tool_calls`, `length` |
| Bağlam stratejileri | Destekleniyor | `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` uzantı alanları |
| CORS | Destekleniyor | `--cors` ile etkinleştirin |
| `POST /v1/completions` | 501 | Eski metin tamamlamaları desteklenmez |
| `POST /v1/embeddings` | 501 | Embeddings cihaz üzerinde mevcut değil |
| `stop` | Destekleniyor | Bir string veya en fazla 4 string; yalnızca düz metin (kapsamda araçlar veya `json_object`/`json_schema` varsa 400). Çıktı tarafında uygulanır, streaming ve streaming olmayan modda aynıdır. Bkz. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Açıkça reddedilir. `n=1` ve `logprobs=false` işlem yapmayan değerler olarak kabul edilir |
| Çok kipli (görseller) | macOS 27'de destekleniyor | Base64 data URL olarak `image_url` parçaları doğrudan cihaz üzeri modele gider (20 MB base64 sınırı, en uzun kenar 4096 px'e küçültülür). Uzak `http(s)` URL'leri ve dosya yolları her zaman 400 döndürür - apfel hiçbir zaman görsel indirmez ve bir HTTP istemcisi için dosya okumaz. macOS 26'da: açık bir hatayla 400. Bkz. [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `Authorization` başlığı | Destekleniyor | `--token` ayarlandığında zorunlu. Bkz. [docs/server-security.md](../docs/server-security.md) |

Tam API spesifikasyonu: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Varsayılan yanıt sınırı (`max_tokens`)

`max_tokens` verilmediğinde **CLI ve OpenAI uyumlu sunucu aynı davranır**: değer `nil` olarak iletilir ve model bağlam penceresinde kalan tüm alanı kullanır. Bu, doğrudan yerine geçen OpenAI semantiğidir - keyfi bir yedek sabit yok.

Cihaz üzerindeki bağlam penceresi girdi *ve* çıktıyı birlikte tutar: **macOS 26'da ve M1/M2 Mac'lerde 4096 token, M3 veya daha yeni çipli ve 12 GB+ belleğe sahip macOS 27'de 8192 token**. apfel gerçek boyutu çalışma zamanında `SystemLanguageModel.contextSize` ile okur - sizinkini `apfel --model-info` ile kontrol edin. Üretim sınıra çarparsa yanıt `finish_reason: "length"` ile düzgünce biter ve kısmi içerik döndürülür (sunucu: HTTP 200; CLI: stderr uyarısıyla çıkış 0, veya `--require-complete` ile çıkış 8 - bkz. [docs/cli-reference.md](../docs/cli-reference.md)). Daha sıkı bir gecikme bütçesi veya istemciniz için bilinen bir sınır istediğinizde `max_tokens` değerini açıkça verin.

### Örnekler

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

### Değer seçimi

| Kullanım senaryosu                     | `max_tokens`  |
|----------------------------------------|---------------|
| Tek kelimelik / sınıflandırma yanıtı   | 16 - 32       |
| Tek satırlık talimat                   | 64 - 128      |
| Kısa paragraf                          | 256 - 512     |
| Uzun paragraf / yapılandırılmış JSON   | 1024 - 2048   |
| Bağlam penceresinin izin verdiği kadar | boş bırakın   |

`input_tokens + max_tokens` toplamını bağlam penceresinin rahatça altında tutun (macOS 26'da ve M1/M2 Mac'lerde 4096 token, M3 veya daha yeni çipli ve 12 GB+ belleğe sahip macOS 27'de 8192 (Apple'ın AFM 3 Core Advanced modeli)). Prompt'un kendisi pencereyi aşarsa üretim başlayamaz ve istek `[context overflow]` ile başarısız olur (HTTP 400 / CLI çıkış 4). Doğrulayıcı pozitif olmayan değerleri reddeder (`max_tokens <= 0`).

### CLI ile eşitlik

CLI ve sunucu tek bir kuralı paylaşır: verilmedi = kalan pencereyi kullan. Zamanla kayacak bir sabit yok. `--max-tokens N` veya `APFEL_MAX_TOKENS=N` ile geçersiz kılın.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Sunucu için gevşek guardrails

`apfel --serve --permissive`, sunucunun işlemin ele aldığı **her istek** için Apple'ın `.permissiveContentTransformations` guardrails ayarını kullanmasını sağlar. CLI'nin `--permissive` flag'iyle aynı flag, aynı semantik ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). İstek başına geçersiz kılma yoktur - tüm işlem için sunucu operatörü karar verir.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Sınırlamalar

| Kısıt | Ayrıntı |
|-------|---------|
| Bağlam penceresi | **macOS 26'da ve M1/M2 Mac'lerde 4096 token, M3 veya daha yeni çipli ve 12 GB+ belleğe sahip macOS 27'de 8192 token** (girdi + çıktı birlikte). Koda gömülü bir sabit değildir - apfel `SystemLanguageModel.contextSize` değerini çalışma zamanında okur; `apfel --model-info` güncel değeri yazdırır |
| Platform | macOS 26+, yalnızca Apple Silicon |
| Model | Cihaz üzerinde tek model (~3B parametre), `apple-foundationmodel` (genel) ve `apple-foundationmodel-content-tagging` (Apple'ın içerik etiketleme adaptörü; araç yok) olarak sunulur |
| Guardrails | Apple'ın güvenlik sistemi zararsız prompt'ları engelleyebilir. `--permissive` yanlış pozitifleri azaltır ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Hız | Cihaz üzerinde, bulut ölçeğinde değil - yanıt başına birkaç saniye |
| Embeddings yok | Cihaz üzerinde mevcut değil |
| Görüntü | Görsel girdisi modele yalnızca macOS 27'de ulaşır (sunucu: data URL'ler; CLI: `-f photo.jpg` ve pipe ile gelen görseller, OCR metninin üstüne). macOS 26'da görseller OCR/sınıflandırma yoluyla yalnızca metindir. 3B modelin sahne açıklamaları kabadır - basılı metni okumak için güvenilir kanal OCR olmaya devam eder |
| Eğitim verisi / bilgi kesim tarihi | Apple, cihaz üzeri model için kesin bir kesim tarihi yayımlamadı. Bir tarih söylemesi için zorlandığında model **her örnekte farklı bir tarih uydurur** (ör. "October 2023", "April 2023"). Modelin kendi eğitimi hakkındaki tüm beyanlarını güvenilmez kabul edin. |
| Güncel tarih ve gerçek zamanlı farkındalık yok | Model bugünün tarihini bilmez, ağa veya saate erişimi yoktur. Sorulursa ya reddeder ya da bir tarih uydurur. Aritmetik tarihe bağlıysa güncel tarihi sistem prompt'uyla enjekte edin (aşağıdaki geçici çözüme bakın). |

**Tarihe bağlı prompt'lar için geçici çözüm** - güncel tarihi bir sistem mesajı olarak enjekte edin:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Not: tarih enjekte edilse bile 3B model yine de halüsinasyon görebilir (özellikle kendi eğitim kesim tarihi doğrudan sorulduğunda). Enjeksiyon, tarihi *kullanan* üretken prompt'lara yardımcı olur; modelin kendini rapor etme refleksini geçersiz kılmaz.

Arka plan: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Referans dokümanlar

apfel'i [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) ile kullanma rehberleri - bkz. [docs/guides/index.md](../docs/guides/index.md). Deneysel olarak test edilmiştir; çalıştırılabilir kanıt [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab) içinde.

- [docs/install.md](../docs/install.md) - kurulum, sorun giderme ve Apple Intelligence kurulumu
- [docs/cli-reference.md](../docs/cli-reference.md) - tüm flag'ler, çıkış kodları ve ortam değişkenleri
- [docs/file-extraction.md](../docs/file-extraction.md) - `-f` ve pipe ile PDF / görsel / metin çıkarımı (OCR + görsel anlama)
- [docs/background-service.md](../docs/background-service.md) - `brew services` ve launchd kullanımı
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - `/v1/*` destek matrisi ayrıntılı
- [docs/server-security.md](../docs/server-security.md) - origin denetimleri, CORS, token'lar ve `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - sohbet kırpma stratejileri
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - yerel ve uzak MCP kullanımı
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - ayrıntılı araç çağırma davranışı
- [docs/integrations.md](../docs/integrations.md) - üçüncü taraf araç entegrasyonları (opencode, vb.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - VS Code'da apfel + ikinci bir düzenleme/uygulama modeliyle yerel inceleme
- [docs/demos.md](../docs/demos.md) - shell demolarının daha uzun anlatımları
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - düzenlenmemiş çıktılı 50'den fazla gerçek prompt
- [docs/swift-library.md](../docs/swift-library.md) - alt akış geliştiriciler için `ApfelCore` Swift Package
- [docs/coreai-impact.md](../docs/coreai-impact.md) - apfel'in neden Apple'ın yeni Core AI'ı (Core ML'in halefi) yerine FoundationModels üzerinde çalıştığı
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel ile Apple'ın kendi `fm` CLI'sinin (macOS 27) özellik özellik, ölçülmüş sayılarla karşılaştırması

## Mimari

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Swift 6.3 katı eşzamanlılık. Üç hedef: `ApfelCore` (saf mantık, birim testlenebilir, ayrıca bir Swift Package ürünü olarak da mevcut - yukarıda Referans dokümanlar altında bağlantılı), `apfel` (CLI + sunucu) ve `apfel-tests` (saf Swift çalıştırıcı, XCTest yok).

## Derleme ve test

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

`.version` tek doğruluk kaynağıdır. Sürümleri yalnızca `make release` yükseltir. Yerel derlemeler sürümü değiştirmez.

## apfel ağacı

apfel üzerine kurulu projeler. Her biri kendi deposu + Homebrew formülüyle gelir.

| Proje | Ne yapar | Kurulum |
|-------|----------|---------|
| [**apfel**](https://apfel.franzai.com) | Kök. Cihaz üzerinde FoundationModels CLI + OpenAI uyumlu sunucu. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | macOS sohbet istemcisi: streaming markdown, sesli giriş/çıkış, Apple Vision ile görsel analizi. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Panodaki içerik üzerinde menü çubuğu yapay zeka eylemleri: özetle, çevir, yeniden yaz. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Anında yapay zeka katmanı: bir tuşa basın, sorun, yanıtı alın, kapatın. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Formüllü not defteri - cihaz üzeri yapay zeka, satır içi hücre fonksiyonu olarak. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | Küçük cihaz üzeri pencere için token bütçesine göre optimize edilmiş MCP'ler: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | SwiftUI hata ayıklama denetçisi: istek zaman çizelgesi, MCP protokol görüntüleyici, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | `apfel` üzerine kalıcı bir MCP kaydı + TOML yapılandırması ekleyen UNIX sarmalayıcı. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | Cihaz üzerinde içerik etiketleme CLI'si: metni pipe ile verin, etiketler/konular/duygular alın. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Ekosistem araçları için Swift paketi: yerel bir `apfel --serve` örneğini keşfedin, başlatın ve ondan stream alın. | Swift Package |

## Topluluk projeleri

apfel üzerine bir şey mi geliştirdiniz? Bir issue açın, buraya eklenebilir.

| Proje | Ne yapar | Bağlantılar |
|-------|----------|-------------|
| **apfelclaw**, geliştiren [@julianYaman](https://github.com/julianYaman) | Salt okunur araçlarla dosyaları, takvimi, postayı ve Mac durumunu okuyan yerel yapay zeka ajanı | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat**, geliştiren [@bhaskarvilles](https://github.com/bhaskarvilles) | OpenAI uyumlu API üzerinden `apfel --serve` ile konuşan tarayıcı tabanlı sohbet arayüzü | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude**, geliştiren [@lucaspwo](https://github.com/lucaspwo) | Küçük bir Anthropic-OpenAI proxy'si üzerinden apfel'i yerel arka uç olarak takan Claude Code sarmalayıcısı | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller**, geliştiren [@hasit](https://github.com/hasit) | apfel etrafında kurulmuş yerel shell uygulamaları için uygulama yöneticisi | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast**, geliştiren [@eggsy](https://github.com/eggsy) | Raycast komut çubuğu uzantısı: sor, çevir, dosya ve dizinleri açıkla, konuşma geçmişi, özel sistem prompt'ları. apfel CLI ile cihaz üzerinde. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Katkıda bulunma

Herhangi bir `Arthur-Ficial/apfel*` deposunda issue ve PR'lar memnuniyetle karşılanır.

**#agentswelcome** - Yapay zeka ajanlarının PR'ları kabul edilir. Deponun `CLAUDE.md` dosyasını okuyun, testleri çalıştırın, aracı bir `Co-Authored-By` trailer'ında belirtin. İnsanlarla aynı çıta: temiz kod, geçen testler, dürüst sınırlar. Ajanlar için en uygun giriş noktası: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([katkı kuralları](https://apfel-mcp.franzai.com/#contribute)).

## Lisans

[MIT](../LICENSE)
