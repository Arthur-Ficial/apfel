<!-- i18n-source: 218b563163b08550cb0adc62e957ce6a40e6e1ba -->

> Traducido del [README en inglés](../README.md). La versión en inglés es la que prevalece.

# apfel

### La IA gratuita que ya tienes en tu Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Los Mac con Apple Silicon incluyen un LLM integrado a través de [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` lo expone como herramienta UNIX y como servidor local compatible con OpenAI. 100 % en el dispositivo. Sin claves de API, sin nube.

| Modo | Comando | Qué obtienes |
|------|---------|--------------|
| Herramienta UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Respuestas aptas para pipes, archivos adjuntos, salida JSON, códigos de salida |
| Servidor compatible con OpenAI | `apfel --serve` | Backend local `http://localhost:11434/v1` listo para usar con los SDK de OpenAI |

`apfel --chat` - REPL interactivo.

La llamada a herramientas funciona en todos los contextos.

![apfel CLI](../screenshots/cli.png)

## Requisitos e instalación

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence activado](https://support.apple.com/en-us/121115). En macOS 27, los Mac con un chip M3 o más reciente y 12 GB+ ejecutan el modelo en el dispositivo más grande de Apple con una ventana de 8192 tokens; los Mac M1/M2 y todos los Mac con macOS 26 tienen 4096. `apfel --model-info` muestra la tuya.

```bash
brew install apfel
```

Actualizar:

```bash
brew upgrade apfel
```

Compilar desde el código fuente (Command Line Tools con el SDK de macOS 27 / Swift 6.3, sin Xcode; el binario funciona en macOS 26 y 27):

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Nix, tap del mismo día, Mint, mise, solución de problemas: [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | **Español** | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | [Français](README.fr.md) | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Inicio rápido

### Herramienta UNIX

Pon entre comillas simples los prompts con `!` (expansión del historial de zsh/bash): `apfel 'Hello, Mac!'`.

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

### Servidor compatible con OpenAI

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

Detalles del servicio en segundo plano: [docs/background-service.md](../docs/background-service.md).

### Chat para pruebas rápidas

`apfel --chat` es un pequeño REPL para probar prompts o servidores MCP. Para una app de chat con interfaz gráfica, consulta [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C sale. El contexto se recorta automáticamente ([docs/context-strategies.md](../docs/context-strategies.md)).

Restricciones que conviene conocer antes de escribir scripts (ventana de contexto según el Mac, guardarraíles, sin embeddings): [Limitaciones](../README.md#limitations).

## Demos

Scripts de shell reales que envuelven `apfel`: `cmd` (inglés a comando de shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Vienen incluidos en el binario - sin clonar el repositorio. Escríbelos donde quieras, sin importar de dónde instalaste apfel (homebrew-core, el tap o el código fuente):

```bash
apfel demos ./apfel-demos
```

Esto escribe cada demo (ejecutable) más un `README.md` en `./apfel-demos`. Luego ejecútalas desde ahí:

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Vuelve a ejecutar `apfel demos` después de `brew upgrade apfel` para actualizar. Fuentes: [`demo/`](../demo/). Recorridos y una función de shell `cmd` para copiar y pegar en tu `.zshrc`: [docs/demos.md](../docs/demos.md).

## Soporte de herramientas MCP

Conecta servidores [Model Context Protocol](https://modelcontextprotocol.io/) con `--mcp`. apfel los descubre, los invoca y devuelve el resultado.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Usa `-q` para ocultar la información de las herramientas.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Incluye una calculadora en [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Servidores MCP remotos** (Streamable HTTP, especificación MCP 2025-03-26):

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Seguridad:** prefiere `APFEL_MCP_TOKEN` a `--mcp-token` (ps aux). apfel rechaza los bearer tokens sobre `http://` en texto plano.

## apfel-run: capa de configuración opcional

apfel en sí no tiene archivo de configuración - flags + variables de entorno, como cualquier herramienta UNIX. Si quieres una configuración TOML (varios MCP, perfiles, configuraciones de equipo en git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) es un wrapper MIT que la añade mediante un reemplazo directo con `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilidad con la API de OpenAI

**URL base:** `http://localhost:11434/v1`

| Funcionalidad | Estado | Notas |
|---------|--------|-------|
| `POST /v1/chat/completions` | Compatible | Streaming + non-streaming |
| `POST /v1/responses` | Compatible | API OpenAI Responses: entrada de cadena/mensaje, `instructions`, streaming (secuencia de eventos canónica), `text.format` (incl. `json_schema`), function tools (non-streaming). Las funciones con estado (`previous_response_id`, `store: true`, `background`, `reasoning`, herramientas alojadas) devuelven 501 explícitos |
| `POST /v1/responses/input_tokens` | Compatible | Preevaluación de tokens (`client.responses.input_tokens.count(...)`): recuento exacto del tokenizador de Apple, sin generación; 501 por debajo de macOS 26.4 en lugar de una estimación. Ver [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Compatible | Devuelve `apple-foundationmodel` |
| `GET /health` | Compatible | Disponibilidad del modelo, ventana de contexto, idiomas, capacidades declaradas del modelo (`capabilities`, `capabilities_reported`) |
| `GET /v1/logs`, `/v1/logs/stats` | Solo debug | Requiere `--debug` |
| Llamada a herramientas | Compatible | `ToolDefinition` nativo + detección JSON. Ver [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Compatible | Inyección en el prompt del sistema; se eliminan los bloques markdown de la salida |
| `response_format: json_schema` | Compatible | Salida conforme al esquema garantizada mediante `DynamicGenerationSchema` de FoundationModels; funciona con `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Compatible | Se asignan a `GenerationOptions`. `top_p` es muestreo nucleus; `temperature` por debajo de 0.001 (incluido 0) equivale a greedy (determinista). Omitir `max_tokens` usa el resto de la ventana de contexto (semántica OpenAI) - ver [Límite de respuesta por defecto](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Compatible | SSE; el chunk final de uso solo con `stream_options: {"include_usage": true}` (según la especificación de OpenAI) |
| `usage` | Compatible | Recuentos reales del tokenizador en macOS 26.4+ (estimación caracteres/4 por debajo). macOS 27: la contabilidad propia del runtime, incluido el encuadre del chat template de Apple (unos 46 `prompt_tokens` extra en un prompt de una línea); macOS 26: apfel cuenta el texto de los mensajes. Detalles en [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Compatible | `stop`, `tool_calls`, `length` |
| Estrategias de contexto | Compatible | Campos de extensión `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Compatible | Se activa con `--cors` |
| `POST /v1/completions` | 501 | Completions de texto heredadas no compatibles |
| `POST /v1/embeddings` | 501 | Embeddings no disponibles en el dispositivo |
| `stop` | Compatible | Cadena o hasta 4 cadenas; solo texto plano (400 con herramientas en el ámbito o con `json_object`/`json_schema`). Se aplica en el lado de salida, idéntico en streaming y non-streaming. Ver [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rechazados explícitamente. `n=1` y `logprobs=false` se aceptan sin efecto |
| Multimodal (imágenes) | Compatible en macOS 27 | Las partes `image_url` como data URLs base64 llegan de forma nativa al modelo en el dispositivo (límite de 20 MB en base64, el lado más largo se reduce a 4096 px). Las URLs `http(s)` remotas y las rutas de archivo siempre dan 400 - apfel nunca descarga imágenes ni lee archivos para un cliente HTTP. En macOS 26: 400 con un error claro. Ver [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| Cabecera `Authorization` | Compatible | Obligatoria cuando se define `--token`. Ver [docs/server-security.md](../docs/server-security.md) |

Especificación completa de la API: [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Límite de respuesta por defecto (`max_tokens`)

Cuando se omite `max_tokens`, **la CLI y el servidor compatible con OpenAI se comportan igual**: el valor pasa como `nil` y el modelo usa el espacio que quede en la ventana de contexto. Es la semántica de OpenAI tal cual - sin constante de reserva arbitraria.

La ventana de contexto en el dispositivo contiene entrada *y* salida combinadas: **4096 tokens en macOS 26 y en los Mac M1/M2, 8192 tokens en macOS 27 con un chip M3 o más reciente y 12 GB+**. apfel lee el tamaño real en tiempo de ejecución mediante `SystemLanguageModel.contextSize` - comprueba el tuyo con `apfel --model-info`. Si la generación llega al límite, la respuesta termina limpiamente con `finish_reason: "length"` y se devuelve el contenido parcial (servidor: HTTP 200; CLI: exit 0 con un aviso en stderr, o exit 8 con `--require-complete` - ver [docs/cli-reference.md](../docs/cli-reference.md)). Pasa `max_tokens` de forma explícita cuando quieras un presupuesto de latencia más ajustado o un límite conocido para tu cliente.

### Ejemplos

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

### Elegir un valor

| Caso de uso                            | `max_tokens`  |
|----------------------------------------|---------------|
| Respuesta de una palabra / clasificación | 16 - 32     |
| Instrucción de una línea               | 64 - 128      |
| Párrafo corto                          | 256 - 512     |
| Párrafo largo / JSON estructurado      | 1024 - 2048   |
| Tanto como permita la ventana de contexto | omitirlo   |

Mantén `input_tokens + max_tokens` cómodamente por debajo de la ventana de contexto (4096 tokens en macOS 26 y en los Mac M1/M2, 8192 en macOS 27 con un chip M3 o más reciente y 12 GB+ (modelo AFM 3 Core Advanced de Apple)). Si el propio prompt supera la ventana, la generación no puede empezar y la solicitud falla con `[context overflow]` (HTTP 400 / CLI exit 4). El validador rechaza los valores no positivos (`max_tokens <= 0`).

### Paridad con la CLI

La CLI y el servidor comparten una sola regla: omitido = usar la ventana restante. Sin constantes que se desvíen. Sobrescribe con `--max-tokens N` o `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Guardarraíles permisivos para el servidor

`apfel --serve --permissive` hace que el servidor use los guardarraíles `.permissiveContentTransformations` de Apple para **cada solicitud** que procese el proceso. Mismo flag, misma semántica que el `--permissive` de la CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). No hay anulación por solicitud - el operador del servidor decide para todo el proceso.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitaciones

| Restricción | Detalle |
|------------|--------|
| Ventana de contexto | **4096 tokens en macOS 26 y en los Mac M1/M2, 8192 tokens en macOS 27 con un chip M3 o más reciente y 12 GB+** (entrada + salida combinadas). No es una constante fija en el código - apfel lee `SystemLanguageModel.contextSize` en tiempo de ejecución; `apfel --model-info` imprime el valor real |
| Plataforma | macOS 26+, solo Apple Silicon |
| Modelo | Un solo modelo (`apple-foundationmodel`, ~3 mil millones de parámetros en el dispositivo), no configurable |
| Guardarraíles | El sistema de seguridad de Apple puede bloquear prompts inocuos. `--permissive` reduce los falsos positivos ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Velocidad | En el dispositivo, no a escala de nube - unos segundos por respuesta |
| Sin embeddings | No disponibles en el dispositivo |
| Visión | La imagen solo llega al modelo en macOS 27 (servidor: data URLs; CLI: `-f photo.jpg` e imágenes por pipe, además del texto OCR). En macOS 26 las imágenes son solo texto mediante OCR/clasificación. Las descripciones de escenas del modelo 3B son toscas - el OCR sigue siendo el canal fiable para leer texto impreso |
| Datos de entrenamiento / fecha de corte del conocimiento | Apple no ha publicado una fecha de corte precisa para el modelo en el dispositivo. Si se le insiste en dar una, el modelo **confabula una fecha distinta en cada muestra** (p. ej. "October 2023", "April 2023"). Trata como poco fiable todo lo que el modelo diga sobre su propio entrenamiento. |
| Sin fecha actual ni conciencia del tiempo real | El modelo no conoce la fecha de hoy y no tiene acceso a red ni a reloj. Si se le pregunta, se negará o se inventará una fecha. Inyecta la fecha actual mediante el prompt del sistema cuando un cálculo dependa de ella (ver la solución abajo). |

**Solución para prompts que dependen de la fecha** - inyecta la fecha actual como mensaje del sistema:

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Nota: incluso con una fecha inyectada, el modelo 3B aún puede alucinar (sobre todo si se le pregunta directamente por su fecha de corte de entrenamiento). La inyección ayuda a los prompts generativos que *usan* la fecha; no anula el reflejo del modelo de hablar de sí mismo.

Contexto: [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentación de referencia

Guías para usar apfel desde [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - ver [docs/guides/index.md](../docs/guides/index.md). Probadas empíricamente; prueba ejecutable en [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - instalación, solución de problemas y configuración de Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - cada flag, código de salida y variable de entorno
- [docs/file-extraction.md](../docs/file-extraction.md) - extracción `-f` y por pipe de PDF / imagen / texto (OCR + comprensión de imágenes)
- [docs/background-service.md](../docs/background-service.md) - uso de `brew services` y launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matriz de compatibilidad de `/v1/*` en profundidad
- [docs/server-security.md](../docs/server-security.md) - comprobaciones de origen, CORS, tokens y `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - estrategias de recorte en el chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - uso de MCP local y remoto
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportamiento detallado de la llamada a herramientas
- [docs/integrations.md](../docs/integrations.md) - integraciones con herramientas de terceros (opencode, etc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revisión local con apfel + un segundo modelo de edición/aplicación en VS Code
- [docs/demos.md](../docs/demos.md) - recorridos más largos de las demos de shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - más de 50 prompts reales con salida sin editar
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` para desarrolladores que lo usen como dependencia
- [docs/coreai-impact.md](../docs/coreai-impact.md) - por qué apfel funciona sobre FoundationModels y no sobre el nuevo Core AI de Apple (el sucesor de Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel comparado con la CLI `fm` de Apple (macOS 27), función por función con cifras medidas

## Arquitectura

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Concurrencia estricta de Swift 6.3. Tres targets: `ApfelCore` (lógica pura, testeable por unidades, también disponible como producto de Swift Package - enlazado en Documentación de referencia arriba), `apfel` (CLI + servidor) y `apfel-tests` (runner en Swift puro, sin XCTest).

## Compilación y pruebas

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

`.version` es la única fuente de verdad. Solo `make release` incrementa las versiones. Las compilaciones locales no cambian la versión.

## El árbol de apfel

Proyectos construidos sobre apfel. Cada uno se publica en su propio repositorio + fórmula de Homebrew.

| Proyecto | Qué hace | Instalación |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | La raíz. CLI de FoundationModels en el dispositivo + servidor compatible con OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Cliente de chat para macOS: markdown en streaming, E/S de voz, análisis de imágenes con Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Acciones de IA en la barra de menús sobre el portapapeles: resumir, traducir, reescribir. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Superposición de IA instantánea: pulsa una tecla, pregunta, obtén la respuesta, cierra. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bloc de notas con fórmulas - la IA en el dispositivo como función de celda en línea. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP optimizados en presupuesto de tokens para la pequeña ventana del dispositivo: `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspector de debug en SwiftUI: línea de tiempo de solicitudes, visor del protocolo MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX que añade un registro MCP persistente + configuración TOML sobre `apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI de etiquetado de contenido en el dispositivo: envía texto por pipe y obtén etiquetas/temas/emociones. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift Package para herramientas del ecosistema: descubrir, lanzar y recibir en streaming desde un `apfel --serve` local. | Swift Package |

## Proyectos de la comunidad

¿Has construido algo sobre apfel? Abre una issue y se podrá añadir aquí.

| Proyecto | Qué hace | Enlaces |
|---------|-------------|-------|
| **apfelclaw** de [@julianYaman](https://github.com/julianYaman) | Agente de IA local que lee archivos, calendario, correo y estado del Mac mediante herramientas de solo lectura | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** de [@bhaskarvilles](https://github.com/bhaskarvilles) | Interfaz de chat en el navegador que se comunica con `apfel --serve` mediante la API compatible con OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** de [@lucaspwo](https://github.com/lucaspwo) | Wrapper de Claude Code que usa apfel como backend local mediante un pequeño proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** de [@hasit](https://github.com/hasit) | Gestor de aplicaciones para apps de shell locales construidas en torno a apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** de [@eggsy](https://github.com/eggsy) | Extensión de Raycast: preguntar, traducir, explicar archivos y directorios, historial de conversaciones, prompts de sistema personalizados. En el dispositivo mediante la CLI de apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuir

Issues y PRs son bienvenidos en cualquier repositorio `Arthur-Ficial/apfel*`.

**#agentswelcome** - los PRs de agentes de IA son bienvenidos. Lee el `CLAUDE.md` del repositorio, ejecuta las pruebas, da crédito a la herramienta en un trailer `Co-Authored-By`. Mismo listón que para las personas: código limpio, pruebas que pasan, límites honestos. Punto de entrada más amigable para agentes: [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([reglas de contribución](https://apfel-mcp.franzai.com/#contribute)).

## Licencia

[MIT](../LICENSE)
