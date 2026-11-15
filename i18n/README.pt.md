<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Traduzido do [README em inglês](../README.md). A versão em inglês é a oficial.

# apfel

### A IA gratuita que já está no seu Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Os Macs com Apple Silicon trazem um LLM integrado por meio do [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). O `apfel` o expõe como uma ferramenta UNIX e como um servidor local compatível com a OpenAI. 100% no dispositivo. Sem chaves de API, sem nuvem.

| Modo | Comando | O que você recebe |
|------|---------|--------------|
| Ferramenta UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Respostas prontas para pipes, anexos de arquivos, saída JSON, códigos de saída |
| Servidor compatível com a OpenAI | `apfel --serve` | Backend local `http://localhost:11434/v1` pronto para uso com os SDKs da OpenAI |

`apfel --chat` - REPL interativo.

[![Vídeo de demonstração do apfel no terminal: comandos reais, respostas reais no dispositivo (84 segundos)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/pt/a/apfel-ai-tutorial/#video)

A chamada de ferramentas funciona em todos os contextos.

![apfel CLI](../screenshots/cli.png)

## Requisitos e instalação

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence ativado](https://support.apple.com/en-us/121115). No macOS 27, Macs com chip M3 ou mais recente e 12 GB+ executam o modelo maior da Apple no dispositivo, com uma janela de 8192 tokens; Macs M1/M2 e todos os Macs com macOS 26 têm 4096. `apfel --model-info` mostra o seu.

```bash
brew install apfel
```

Atualizar:

```bash
brew upgrade apfel
```

Compilar a partir do código-fonte (Command Line Tools com o SDK do macOS 27 / Swift 6.3, sem Xcode; o binário roda no macOS 26 e 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, tap do mesmo dia, Mint, mise, solução de problemas: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | **Português** | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Início rápido

### Ferramenta UNIX

Coloque entre aspas simples os prompts com `!` (expansão de histórico do zsh/bash): `apfel 'Hello, Mac!'`.

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

### Servidor compatível com a OpenAI

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

Detalhes do serviço em segundo plano: [docs/background-service.md](../docs/background-service.md).

### Chat para testes rápidos

`apfel --chat` é um pequeno REPL para testar prompts ou servidores MCP. Para um app de chat com interface gráfica, veja [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C sai. O contexto é reduzido automaticamente ([docs/context-strategies.md](../docs/context-strategies.md)).

Restrições que vale conhecer antes de escrever scripts (janela de contexto por Mac, guardrails, sem embeddings): [Limitações](../README.md#limitations).

## Demos

Scripts de shell reais que envolvem o `apfel`: `cmd` (inglês para comando de shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Eles vêm embutidos no binário - sem clonar o repositório. Grave-os onde quiser, não importa de onde você instalou o apfel (homebrew-core, o tap ou o código-fonte):

```bash
apfel demos ./apfel-demos
```

Isso grava cada demo (executável) mais um `README.md` em `./apfel-demos`. Depois, execute-as a partir de lá:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Execute `apfel demos` de novo depois de `brew upgrade apfel` para atualizar. Fontes: [`demo/`](../demo/). Passo a passo e uma função de shell `cmd` para copiar e colar no seu `.zshrc`: [docs/demos.md](../docs/demos.md).

## Suporte a ferramentas MCP

Anexe servidores [Model Context Protocol](https://modelcontextprotocol.io/) com `--mcp`. O apfel os descobre, invoca e devolve o resultado.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Use `-q` para ocultar as informações das ferramentas.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Inclui uma calculadora em [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Servidores MCP remotos** (Streamable HTTP, especificação MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Segurança:** prefira `APFEL_MCP_TOKEN` a `--mcp-token` (ps aux). O apfel recusa bearer tokens sobre `http://` em texto simples.

## apfel-run: camada de configuração opcional

O apfel em si não tem arquivo de configuração - flags + variáveis de ambiente, como qualquer ferramenta UNIX. Se você quer uma configuração TOML (vários MCPs, perfis, configs de equipe no git), o [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) é um wrapper MIT que adiciona uma por meio de um substituto direto via `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilidade com a API da OpenAI

**URL base:** `http://localhost:11434/v1`

| Recurso | Status | Notas |
|---------|--------|-------|
| `POST /v1/chat/completions` | Suportado | Streaming + non-streaming |
| `POST /v1/responses` | Suportado | API OpenAI Responses: entrada de string/mensagem, `instructions`, streaming (sequência de eventos canônica), `text.format` (incl. `json_schema`), function tools (non-streaming). Recursos com estado (`previous_response_id`, `store: true`, `background`, `reasoning`, ferramentas hospedadas) retornam 501 explícitos |
| `POST /v1/responses/input_tokens` | Suportado | Pré-checagem de tokens (`client.responses.input_tokens.count(...)`): contagem exata do tokenizador da Apple, sem geração; 501 abaixo do macOS 26.4 em vez de uma estimativa. Veja [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Suportado | Retorna `apple-foundationmodel` |
| `GET /health` | Suportado | Disponibilidade do modelo, janela de contexto, idiomas, capacidades informadas do modelo (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Somente debug | Requer `--debug` |
| Chamada de ferramentas | Suportado | `ToolDefinition` nativo + detecção de JSON. Veja [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Suportado | Injeção no prompt do sistema; blocos markdown removidos da saída |
| `response_format: json_schema` | Suportado | Saída conforme ao esquema garantida via `DynamicGenerationSchema` do FoundationModels; funciona com `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Suportado | Mapeados para `GenerationOptions`. `top_p` é amostragem nucleus; `temperature` abaixo de 0.001 (incluindo 0) equivale a greedy (determinístico). Omitir `max_tokens` usa o restante da janela de contexto (semântica OpenAI) - veja [Limite de resposta padrão](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Suportado | SSE; chunk final de uso somente com `stream_options: {"include_usage": true}` (conforme a especificação da OpenAI) |
| `usage` | Suportado | Contagens reais do tokenizador no macOS 26.4+ (estimativa caracteres/4 abaixo). macOS 27: a contabilidade própria do runtime, incluindo o enquadramento do chat template da Apple (cerca de 46 `prompt_tokens` extras em um prompt de uma linha); macOS 26: o apfel conta o texto das mensagens. Detalhes em [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Suportado | `stop`, `tool_calls`, `length` |
| Estratégias de contexto | Suportado | Campos de extensão `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Suportado | Ative com `--cors` |
| `POST /v1/completions` | 501 | Completions de texto legados não são suportados |
| `POST /v1/embeddings` | 501 | Embeddings não estão disponíveis no dispositivo |
| `stop` | Suportado | String ou até 4 strings; somente texto simples (400 com ferramentas no escopo ou com `json_object`/`json_schema`). Aplicado no lado da saída, idêntico em streaming e non-streaming. Veja [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rejeitados explicitamente. `n=1` e `logprobs=false` são aceitos sem efeito |
| Multimodal (imagens) | Suportado no macOS 27 | Partes `image_url` como data URLs base64 vão nativamente ao modelo no dispositivo (limite de 20 MB em base64, o lado maior é reduzido a 4096 px). URLs `http(s)` remotas e caminhos de arquivo sempre dão 400 - o apfel nunca baixa imagens e nunca lê arquivos para um cliente HTTP. No macOS 26: 400 com um erro claro. Veja [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Cabeçalho `Authorization` | Suportado | Obrigatório quando `--token` está definido. Veja [docs/server-security.md](../docs/server-security.md) |

Especificação completa da API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Limite de resposta padrão (`max_tokens`)

Quando `max_tokens` é omitido, **a CLI e o servidor compatível com a OpenAI se comportam de forma idêntica**: o valor segue como `nil` e o modelo usa o espaço que sobrar na janela de contexto. É a semântica da OpenAI como ela é - sem constante de reserva arbitrária.

A janela de contexto no dispositivo comporta entrada *e* saída combinadas: **4096 tokens no macOS 26 e em Macs M1/M2, 8192 tokens no macOS 27 com chip M3 ou mais recente e 12 GB+**. O apfel lê o tamanho real em tempo de execução via `SystemLanguageModel.contextSize` - confira o seu com `apfel --model-info`. Se a geração atingir o teto, a resposta termina de forma limpa com `finish_reason: "length"` e o conteúdo parcial é devolvido (servidor: HTTP 200; CLI: exit 0 com um aviso no stderr, ou exit 8 com `--require-complete` - veja [docs/cli-reference.md](../docs/cli-reference.md)). Passe `max_tokens` explicitamente quando quiser um orçamento de latência mais apertado ou um limite conhecido para o seu cliente.

### Exemplos

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

### Escolhendo um valor

| Caso de uso                            | `max_tokens`  |
|----------------------------------------|---------------|
| Resposta de uma palavra / classificação | 16 - 32      |
| Instrução de uma linha                 | 64 - 128      |
| Parágrafo curto                        | 256 - 512     |
| Parágrafo longo / JSON estruturado     | 1024 - 2048   |
| Tanto quanto a janela de contexto permitir | omita     |

Mantenha `input_tokens + max_tokens` bem abaixo da janela de contexto (4096 tokens no macOS 26 e em Macs M1/M2, 8192 no macOS 27 com chip M3 ou mais recente e 12 GB+ (modelo AFM 3 Core Advanced da Apple)). Se o próprio prompt exceder a janela, a geração não pode começar e a requisição falha com `[context overflow]` (HTTP 400 / CLI exit 4). O validador rejeita valores não positivos (`max_tokens <= 0`).

### Paridade com a CLI

A CLI e o servidor compartilham uma única regra: omitido = usar a janela restante. Nenhuma constante para divergir. Sobrescreva com `--max-tokens N` ou `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardrails permissivos para o servidor

`apfel --serve --permissive` faz o servidor usar os guardrails `.permissiveContentTransformations` da Apple para **toda requisição** que o processo atender. Mesma flag, mesma semântica do `--permissive` da CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Não há sobrescrita por requisição - quem opera o servidor decide para o processo inteiro.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitações

| Restrição | Detalhe |
|------------|--------|
| Janela de contexto | **4096 tokens no macOS 26 e em Macs M1/M2, 8192 tokens no macOS 27 com chip M3 ou mais recente e 12 GB+** (entrada + saída combinadas). Não é uma constante fixa no código - o apfel lê `SystemLanguageModel.contextSize` em tempo de execução; `apfel --model-info` imprime o valor real |
| Plataforma | macOS 26+, somente Apple Silicon |
| Modelo | Um único modelo (`apple-foundationmodel`, ~3 bilhões de parâmetros no dispositivo), não configurável |
| Guardrails | O sistema de segurança da Apple pode bloquear prompts inofensivos. `--permissive` reduz os falsos positivos ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Velocidade | No dispositivo, não em escala de nuvem - alguns segundos por resposta |
| Sem embeddings | Não disponíveis no dispositivo |
| Visão | A imagem só chega ao modelo no macOS 27 (servidor: data URLs; CLI: `-f photo.jpg` e imagens via pipe, além do texto OCR). No macOS 26 as imagens são somente texto via OCR/classificação. As descrições de cena do modelo 3B são grosseiras - o OCR continua sendo o canal confiável para ler texto impresso |
| Dados de treinamento / data de corte do conhecimento | A Apple não publicou uma data de corte precisa para o modelo no dispositivo. Quando pressionado a dizer uma, o modelo **confabula uma data diferente a cada amostra** (p. ex. "October 2023", "April 2023"). Trate como não confiável tudo o que o modelo disser sobre o próprio treinamento. |
| Sem data atual nem noção de tempo real | O modelo não sabe a data de hoje e não tem acesso a rede nem a relógio. Se perguntado, ele se recusa ou inventa uma data. Injete a data atual via prompt do sistema quando um cálculo depender dela (veja a solução abaixo). |

**Solução para prompts que dependem da data** - injete a data atual como mensagem do sistema:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Nota: mesmo com uma data injetada, o modelo 3B ainda pode alucinar (especialmente quando perguntado diretamente sobre a data de corte do próprio treinamento). A injeção ajuda os prompts generativos que *usam* a data; ela não anula o reflexo do modelo de falar sobre si mesmo.

Contexto: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentação de referência

Guias para usar o apfel a partir de [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - veja [docs/guides/index.md](../docs/guides/index.md). Testados empiricamente; prova executável em [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalação, solução de problemas e configuração do Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - cada flag, código de saída e variável de ambiente
- [docs/file-extraction.md](../docs/file-extraction.md) - extração `-f` e via pipe de PDF / imagem / texto (OCR + compreensão de imagem)
- [docs/background-service.md](../docs/background-service.md) - uso de `brew services` e launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matriz de suporte de `/v1/*` em detalhe
- [docs/server-security.md](../docs/server-security.md) - verificações de origem, CORS, tokens e `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - estratégias de redução de contexto no chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - uso de MCP local e remoto
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportamento detalhado da chamada de ferramentas
- [docs/integrations.md](../docs/integrations.md) - integrações com ferramentas de terceiros (opencode, etc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revisão local com apfel + um segundo modelo de edição/aplicação no VS Code
- [docs/demos.md](../docs/demos.md) - passo a passo mais longos das demos de shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - mais de 50 prompts reais com saída sem edição
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` para desenvolvedores que o usam como dependência
- [docs/coreai-impact.md](../docs/coreai-impact.md) - por que o apfel roda sobre o FoundationModels e não sobre o novo Core AI da Apple (o sucessor do Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel comparado com a CLI `fm` da própria Apple (macOS 27), recurso por recurso com números medidos

## Arquitetura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Concorrência estrita do Swift 6.3. Três targets: `ApfelCore` (lógica pura, testável por unidade, também disponível como produto de Swift Package - linkado em Documentação de referência acima), `apfel` (CLI + servidor) e `apfel-tests` (runner em Swift puro, sem XCTest).

## Build e testes

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

`.version` é a única fonte da verdade. Somente `make release` incrementa versões. Builds locais não alteram a versão.

## A árvore do apfel

Projetos construídos sobre o apfel. Cada um é publicado em seu próprio repositório + fórmula do Homebrew.

| Projeto | O que faz | Instalação |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | A raiz. CLI do FoundationModels no dispositivo + servidor compatível com a OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Cliente de chat para macOS: markdown em streaming, E/S de voz, análise de imagens com Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Ações de IA na barra de menus sobre a área de transferência: resumir, traduzir, reescrever. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Sobreposição de IA instantânea: aperte uma tecla, pergunte, receba a resposta, dispense. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bloco de notas com fórmulas - a IA no dispositivo como função de célula em linha. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCPs otimizados em orçamento de tokens para a pequena janela no dispositivo: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspetor de debug em SwiftUI: linha do tempo das requisições, visualizador do protocolo MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX que adiciona um registro MCP persistente + configuração TOML sobre o `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI de marcação de conteúdo no dispositivo: envie texto por pipe e receba tags/tópicos/emoções. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift Package para ferramentas do ecossistema: descobrir, iniciar e receber em streaming de um `apfel --serve` local. | Swift Package |

## Projetos da comunidade

Construiu algo sobre o apfel? Abra uma issue e ele poderá ser adicionado aqui.

| Projeto | O que faz | Links |
|---------|-------------|-------|
| **apfelclaw** por [@julianYaman](https://github.com/julianYaman) | Agente de IA local que lê arquivos, calendário, e-mail e o estado do Mac por meio de ferramentas somente leitura | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** por [@bhaskarvilles](https://github.com/bhaskarvilles) | Interface de chat no navegador que conversa com `apfel --serve` pela API compatível com a OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** por [@lucaspwo](https://github.com/lucaspwo) | Wrapper do Claude Code que usa o apfel como backend local por meio de um pequeno proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** por [@hasit](https://github.com/hasit) | Gerenciador de apps para aplicativos de shell locais construídos em torno do apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** por [@eggsy](https://github.com/eggsy) | Extensão do Raycast: perguntar, traduzir, explicar arquivos e diretórios, histórico de conversas, prompts de sistema personalizados. No dispositivo via CLI do apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuindo

Issues e PRs são bem-vindos em qualquer repositório `Arthur-Ficial/apfel*`.

**#agentswelcome** - PRs de agentes de IA são bem-vindos. Leia o `CLAUDE.md` do repositório, rode os testes, credite a ferramenta em um trailer `Co-Authored-By`. Mesmo critério aplicado a humanos: código limpo, testes passando, limites honestos. Ponto de entrada mais amigável a agentes: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([regras de contribuição](https://apfel-mcp.franzai.com/#contribute)).

## Licença

[MIT](../LICENSE)
