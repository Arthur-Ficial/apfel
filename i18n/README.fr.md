<!-- i18n-source: 456189202748709f4afd193b0fb6c49c6fd36c3c -->

> Traduit du [README anglais](../README.md). La version anglaise fait foi.

# apfel

### L'IA gratuite déjà présente sur votre Mac.

[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26 Tahoe+](https://img.shields.io/badge/macOS-26%20Tahoe%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE)
[![100% On-Device](https://img.shields.io/badge/inference-100%25%20on--device-green)](https://developer.apple.com/documentation/foundationmodels)
[![Website](https://img.shields.io/badge/web-apfel.franzai.com-16A34A)](https://apfel.franzai.com)
[![#agentswelcome](https://img.shields.io/badge/%23agentswelcome-PRs%20welcome-0066cc?style=for-the-badge&labelColor=0d1117&logo=probot&logoColor=white)](../README.md#contributing)

Les Mac Apple Silicon embarquent un LLM intégré via [Apple FoundationModels](https://developer.apple.com/documentation/foundationmodels). `apfel` l'expose comme outil UNIX et comme serveur local compatible OpenAI. 100 % sur l'appareil. Pas de clés d'API, pas de cloud.

| Mode | Commande | Ce que vous obtenez |
|------|---------|--------------|
| Outil UNIX | `apfel "prompt"` / `echo "text" \| apfel` | Réponses adaptées aux pipes, pièces jointes, sortie JSON, codes de sortie |
| Serveur compatible OpenAI | `apfel --serve` | Backend local `http://localhost:11434/v1` prêt à l'emploi pour les SDK OpenAI |

`apfel --chat` - REPL interactif.

[![Vidéo de démo d'apfel dans le terminal : vraies commandes, vraies réponses sur l'appareil (82 secondes)](../screenshots/demo-video.jpg)](https://apfel.franzai.com/fr/a/apfel-ai-tutorial/#video)

L'appel d'outils fonctionne dans tous les contextes.

![apfel CLI](../screenshots/cli.png)

## Prérequis et installation

macOS 26 Tahoe+, Apple Silicon (M1+), [Apple Intelligence activé](https://support.apple.com/en-us/121115). Sur macOS 27, les Mac avec une puce M3 ou plus récente et 12 Go+ exécutent le modèle embarqué plus grand d'Apple avec une fenêtre de 8192 tokens ; les Mac M1/M2 et tous les Mac sous macOS 26 disposent de 4096. `apfel --model-info` affiche la vôtre.

```bash
brew install apfel
```

Mise à jour :

```bash
brew upgrade apfel
```

Compiler depuis les sources (Command Line Tools avec le SDK macOS 27 / Swift 6.3, sans Xcode ; le binaire fonctionne sur macOS 26 et 27) :

```bash
git clone https://github.com/Arthur-Ficial/apfel.git && cd apfel && make install
```

Tap le jour même, Mint, mise, dépannage : [docs/install.md](../docs/install.md).

**Languages:** [English](../README.md) | [العربية](README.ar.md) | [Беларуская](README.be.md) | [Български](README.bg.md) | [বাংলা](README.bn.md) | [Bosanski](README.bs.md) | [Català](README.ca.md) | [Čeština](README.cs.md) | [Dansk](README.da.md) | [Deutsch](README.de.md) | [Ελληνικά](README.el.md) | [Español](README.es.md) | [Eesti](README.et.md) | [فارسی](README.fa.md) | [Suomi](README.fi.md) | **Français** | [ગુજરાતી](README.gu.md) | [हिन्दी](README.hi.md) | [Hrvatski](README.hr.md) | [Magyar](README.hu.md) | [Italiano](README.it.md) | [日本語](README.ja.md) | [ಕನ್ನಡ](README.kn.md) | [한국어](README.ko.md) | [Lietuvių](README.lt.md) | [Latviešu](README.lv.md) | [Македонски](README.mk.md) | [മലയാളം](README.ml.md) | [मराठी](README.mr.md) | [Norsk bokmål](README.nb.md) | [Nederlands](README.nl.md) | [Polski](README.pl.md) | [Português](README.pt.md) | [Română](README.ro.md) | [Русский](README.ru.md) | [Slovenčina](README.sk.md) | [Slovenščina](README.sl.md) | [Shqip](README.sq.md) | [Srpski](README.sr.md) | [Svenska](README.sv.md) | [தமிழ்](README.ta.md) | [తెలుగు](README.te.md) | [Türkçe](README.tr.md) | [Українська](README.uk.md) | [اردو](README.ur.md) | [简体中文](README.zh-hans.md) | [繁體中文](README.zh-hant.md)

## Démarrage rapide

### Outil UNIX

Mettez entre apostrophes les prompts contenant `!` (expansion de l'historique zsh/bash) : `apfel 'Hello, Mac!'`.

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

### Serveur compatible OpenAI

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

Détails du service en arrière-plan : [docs/background-service.md](../docs/background-service.md).

### Chat pour tests rapides

`apfel --chat` est un petit REPL pour tester des prompts ou des serveurs MCP. Pour une application de chat avec interface graphique, voir [apfel-chat](https://github.com/Arthur-Ficial/apfel-chat).

```bash
apfel --chat
apfel --chat -s "You are a helpful coding assistant"
apfel --chat --mcp ./mcp/calculator/server.py      # chat with MCP tools
apfel --chat --debug                                # debug output to stderr
```

Ctrl-C quitte. Le contexte est réduit automatiquement ([docs/context-strategies.md](../docs/context-strategies.md)).

Les contraintes à connaître avant d'écrire des scripts (fenêtre de contexte selon le Mac, garde-fous, pas d'embeddings) : [Limitations](../README.md#limitations).

## Démos

De vrais scripts shell qui enveloppent `apfel` : `cmd` (anglais vers commande shell), `oneliner`, `mac-narrator`, `wtd`, `explain`, `naming`, `port`, `gitsum`. Ils sont intégrés dans le binaire - pas besoin de cloner le dépôt. Écrivez-les où vous voulez, quelle que soit la source d'installation d'apfel (homebrew-core, le tap ou les sources) :

```bash
apfel demos ./apfel-demos
```

Cela écrit chaque démo (exécutable) ainsi qu'un `README.md` dans `./apfel-demos`. Lancez-les ensuite depuis ce dossier :

```bash
./apfel-demos/cmd "find all .log files modified today"
# $ find . -name "*.log" -type f -mtime -1

./apfel-demos/cmd -x "show disk usage sorted by size"   # -x = execute after confirm
./apfel-demos/cmd -c "list open ports"                   # -c = copy to clipboard
```

Relancez `apfel demos` après `brew upgrade apfel` pour actualiser. Sources : [`demo/`](../demo/). Pas-à-pas et une fonction shell `cmd` à copier-coller dans votre `.zshrc` : [docs/demos.md](../docs/demos.md).

## Prise en charge des outils MCP

Attachez des serveurs [Model Context Protocol](https://modelcontextprotocol.io/) avec `--mcp`. apfel les découvre, les invoque et renvoie le résultat.

```bash
apfel --mcp ./mcp/calculator/server.py "What is 15 times 27?"
```

```
mcp: ./mcp/calculator/server.py - add, subtract, multiply, divide, sqrt, power, round_number    ← stderr
tool: multiply({"a": 15, "b": 27}) = 405                                          ← stderr
15 times 27 is 405.                                                                ← stdout
```

Utilisez `-q` pour masquer les infos sur les outils.

```bash
apfel --mcp ./server_a.py --mcp ./server_b.py "Use both tools"
apfel --serve --mcp ./mcp/calculator/server.py
apfel --chat --mcp ./mcp/calculator/server.py
```

Livré avec une calculatrice dans [`mcp/calculator/`](../mcp/calculator/) ([docs/mcp-calculator.md](../docs/mcp-calculator.md)).

**Serveurs MCP distants** (Streamable HTTP, spécification MCP 2025-03-26) :

```bash
apfel --mcp https://mcp.example.com/v1 "what tools do you have?"

# bearer token - prefer env var (flag is visible in ps aux)
APFEL_MCP_TOKEN=mytoken apfel --mcp https://mcp.example.com/v1 "..."

# mixed local + remote
apfel --mcp /path/to/local.py --mcp https://remote.example.com/v1 "..."
```

> **Sécurité :** préférez `APFEL_MCP_TOKEN` à `--mcp-token` (ps aux). apfel refuse les bearer tokens sur `http://` en clair.

## apfel-run : couche de configuration optionnelle

apfel lui-même n'a pas de fichier de configuration - des flags et des variables d'environnement, comme tout outil UNIX. Si vous voulez une configuration TOML (plusieurs MCP, profils, configs d'équipe dans git), [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) est un wrapper MIT qui en ajoute une via un remplacement transparent par `execve`.

```bash
brew install Arthur-Ficial/tap/apfel-run
apfel-run config init                 # starter ~/.config/apfel/config.toml
alias apfel=apfel-run                 # optional, every apfel flag still works
```

## Compatibilité avec l'API OpenAI

**URL de base :** `http://localhost:11434/v1`

| Fonctionnalité | Statut | Notes |
|---------|--------|-------|
| `POST /v1/chat/completions` | Pris en charge | Streaming + non-streaming |
| `POST /v1/responses` | Pris en charge | API OpenAI Responses : entrée chaîne/message, `instructions`, streaming (séquence d'événements canonique), `text.format` (dont `json_schema`), function tools (non-streaming). Les fonctionnalités avec état (`previous_response_id`, `store: true`, `background`, `reasoning`, outils hébergés) renvoient des 501 explicites |
| `POST /v1/responses/input_tokens` | Pris en charge | Préévaluation des tokens (`client.responses.input_tokens.count(...)`) : décompte exact du tokenizer d'Apple, sans génération ; 501 en dessous de macOS 26.4 plutôt qu'une estimation. Voir [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#token-preflight-v1responsesinput_tokens) |
| `GET /v1/models` | Pris en charge | Renvoie `apple-foundationmodel` (général, par défaut) et `apple-foundationmodel-content-tagging` (étiquettes, pas de prose). Voir [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#content-tagging-model) |
| `GET /health` | Pris en charge | Disponibilité du modèle, fenêtre de contexte, langues, capacités déclarées du modèle (`capabilities`, `capabilities_reported`), la variante du modèle servi (`variant`, p. ex. AFM 3 Core) |
| `GET /v1/logs`, `/v1/logs/stats` | Debug uniquement | Nécessite `--debug` |
| Appel d'outils | Pris en charge | L'appel est rédigé par génération guidée (`--tool-calling guided`, par défaut) ou en JSON analysé par le serveur (`--tool-calling text`). Voir [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) |
| `response_format: json_object` | Pris en charge | Injection dans le prompt système ; blocs markdown retirés de la sortie |
| `response_format: json_schema` | Pris en charge | Sortie conforme au schéma garantie via `DynamicGenerationSchema` de FoundationModels ; fonctionne avec `stream: true` |
| `temperature`, `top_p`, `max_tokens`, `seed` | Pris en charge | Convertis en `GenerationOptions`. `top_p` est l'échantillonnage nucleus ; `temperature` inférieure à 0.001 (0 inclus) correspond au mode greedy (déterministe). Omettre `max_tokens` utilise le reste de la fenêtre de contexte (sémantique OpenAI) - voir [Plafond de réponse par défaut](../README.md#default-response-cap-max_tokens) |
| `stream: true` | Pris en charge | SSE ; chunk final d'usage uniquement avec `stream_options: {"include_usage": true}` (selon la spécification OpenAI) |
| `usage` | Pris en charge | Vrais décomptes du tokenizer sur macOS 26.4+ (estimation caractères/4 en dessous). macOS 27 : le décompte propre du runtime, cadrage du chat template d'Apple inclus (environ 46 `prompt_tokens` de plus pour un prompt d'une ligne) ; macOS 26 : apfel compte le texte des messages. Détails dans [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| `finish_reason` | Pris en charge | `stop`, `tool_calls`, `length` |
| Stratégies de contexte | Pris en charge | Champs d'extension `x_context_strategy`, `x_context_max_turns`, `x_context_output_reserve` |
| CORS | Pris en charge | S'active avec `--cors` |
| `POST /v1/completions` | 501 | Complétions de texte héritées non prises en charge |
| `POST /v1/embeddings` | 501 | Embeddings non disponibles sur l'appareil |
| `stop` | Pris en charge | Chaîne ou jusqu'à 4 chaînes ; texte brut uniquement (400 si des outils sont dans le périmètre ou avec `json_object`/`json_schema`). Appliqué côté sortie, identique en streaming et non-streaming. Voir [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md#stop-sequences) |
| `logprobs=true`, `n>1`, `presence_penalty`, `frequency_penalty` | 400 | Rejetés explicitement. `n=1` et `logprobs=false` sont acceptés sans effet |
| Multimodal (images) | Pris en charge sur macOS 27 | Les parties `image_url` sous forme de data URLs base64 vont nativement au modèle embarqué (plafond de 20 Mo en base64, plus grand côté réduit à 4096 px). Les URLs `http(s)` distantes et les chemins de fichiers donnent toujours 400 - apfel ne télécharge jamais d'images et ne lit jamais de fichiers pour un client HTTP. Sur macOS 26 : 400 avec une erreur claire. Voir [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) |
| En-tête `Authorization` | Pris en charge | Requis lorsque `--token` est défini. Voir [docs/server-security.md](../docs/server-security.md) |

Spécification complète de l'API : [openai/openai-openapi](https://github.com/openai/openai-openapi).

## Plafond de réponse par défaut (`max_tokens`)

Quand `max_tokens` est omis, **la CLI et le serveur compatible OpenAI se comportent de façon identique** : la valeur est transmise comme `nil` et le modèle utilise tout l'espace restant dans la fenêtre de contexte. C'est la sémantique OpenAI classique - pas de constante de repli arbitraire.

La fenêtre de contexte embarquée contient l'entrée *et* la sortie combinées : **4096 tokens sur macOS 26 et sur les Mac M1/M2, 8192 tokens sur macOS 27 avec une puce M3 ou plus récente et 12 Go+**. apfel lit la taille réelle à l'exécution via `SystemLanguageModel.contextSize` - vérifiez la vôtre avec `apfel --model-info`. Si la génération atteint le plafond, la réponse se termine proprement avec `finish_reason: "length"` et le contenu partiel est renvoyé (serveur : HTTP 200 ; CLI : exit 0 avec un avertissement sur stderr, ou exit 8 avec `--require-complete` - voir [docs/cli-reference.md](../docs/cli-reference.md)). Passez `max_tokens` explicitement si vous voulez un budget de latence plus serré ou un plafond connu côté client.

### Exemples

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

### Choisir une valeur

| Cas d'usage                            | `max_tokens`  |
|----------------------------------------|---------------|
| Réponse d'un mot / classification      | 16 - 32       |
| Instruction d'une ligne                | 64 - 128      |
| Paragraphe court                       | 256 - 512     |
| Long paragraphe / JSON structuré       | 1024 - 2048   |
| Autant que la fenêtre de contexte le permet | l'omettre |

Gardez `input_tokens + max_tokens` nettement en dessous de la fenêtre de contexte (4096 tokens sur macOS 26 et sur les Mac M1/M2, 8192 sur macOS 27 avec une puce M3 ou plus récente et 12 Go+ (modèle AFM 3 Core Advanced d'Apple)). Si le prompt lui-même dépasse la fenêtre, la génération ne peut pas démarrer et la requête échoue avec `[context overflow]` (HTTP 400 / CLI exit 4). Le validateur rejette les valeurs non positives (`max_tokens <= 0`).

### Parité avec la CLI

La CLI et le serveur partagent une seule règle : omis = utiliser la fenêtre restante. Aucune constante qui dérive. Remplacez avec `--max-tokens N` ou `APFEL_MAX_TOKENS=N`.

```bash
apfel "Reply SKIP."                    # uses remaining window
apfel --max-tokens 64 "Reply SKIP."    # explicit cap
APFEL_MAX_TOKENS=2048 apfel "..."      # via env var
```

### Garde-fous permissifs pour le serveur

`apfel --serve --permissive` fait utiliser au serveur les garde-fous `.permissiveContentTransformations` d'Apple pour **chaque requête** traitée par le processus. Même flag, même sémantique que le `--permissive` de la CLI ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)). Il n'y a pas de surcharge par requête - c'est l'opérateur du serveur qui décide pour tout le processus.

```bash
apfel --serve --permissive             # every request uses permissive guardrails
```

## Limitations

| Contrainte | Détail |
|------------|--------|
| Fenêtre de contexte | **4096 tokens sur macOS 26 et sur les Mac M1/M2, 8192 tokens sur macOS 27 avec une puce M3 ou plus récente et 12 Go+** (entrée + sortie combinées). Pas une constante codée en dur - apfel lit `SystemLanguageModel.contextSize` à l'exécution ; `apfel --model-info` affiche la valeur réelle |
| Plateforme | macOS 26+, Apple Silicon uniquement |
| Modèle | Un seul modèle sur l'appareil (~3 Md de paramètres), servi sous les noms `apple-foundationmodel` (général) et `apple-foundationmodel-content-tagging` (l'adaptateur d'étiquetage de contenu d'Apple ; sans outils) |
| Garde-fous | Le système de sécurité d'Apple peut bloquer des prompts anodins. `--permissive` réduit les faux positifs ([docs/PERMISSIVE.md](../docs/PERMISSIVE.md)) |
| Vitesse | Sur l'appareil, pas à l'échelle du cloud - quelques secondes par réponse |
| Pas d'embeddings | Non disponibles sur l'appareil |
| Vision | L'image n'atteint le modèle que sur macOS 27 (serveur : data URLs ; CLI : `-f photo.jpg` et images via pipe, en plus du texte OCR). Sur macOS 26, les images passent uniquement en texte via OCR/classification. Les descriptions de scènes du modèle 3B sont grossières - l'OCR reste le canal fiable pour lire du texte imprimé |
| Données d'entraînement / date limite des connaissances | Apple n'a pas publié de date limite précise pour le modèle embarqué. Poussé à en donner une, le modèle **affabule une date différente à chaque échantillon** (p. ex. "October 2023", "April 2023"). Considérez comme peu fiable tout ce que le modèle dit de son propre entraînement. |
| Pas de date actuelle ni de conscience du temps réel | Le modèle ne connaît pas la date du jour et n'a aucun accès réseau/horloge. Si on la lui demande, il refuse ou invente une date. Injectez la date actuelle via le prompt système quand un calcul en dépend (voir la solution ci-dessous). |

**Solution pour les prompts dépendant de la date** - injectez la date actuelle comme message système :

```bash
apfel -s "Today is $(date '+%B %d, %Y')." "Write a one-line release note dated today."
```

```bash
apfel --chat -s "Today is $(date '+%B %d, %Y'). You are a helpful assistant."
```

Remarque : même avec une date injectée, le modèle 3B peut encore halluciner (surtout si on l'interroge directement sur sa date limite d'entraînement). L'injection aide les prompts génératifs qui *utilisent* la date ; elle ne supprime pas le réflexe du modèle à parler de lui-même.

Contexte : [#158](https://github.com/Arthur-Ficial/apfel/issues/158).

## Documentation de référence

Guides pour utiliser apfel depuis [Python](../docs/guides/python.md), [Node.js](../docs/guides/nodejs.md), [Ruby](../docs/guides/ruby.md), [PHP](../docs/guides/php.md), [Bash/curl](../docs/guides/bash-curl.md), [Zsh](../docs/guides/zsh.md), [AppleScript](../docs/guides/applescript.md), [Swift](../docs/guides/swift-scripting.md), [Perl](../docs/guides/perl.md), [AWK](../docs/guides/awk.md) - voir [docs/guides/index.md](../docs/guides/index.md). Testés empiriquement ; preuve exécutable sur [apfel-guides-lab](https://github.com/Arthur-Ficial/apfel-guides-lab).

- [docs/install.md](../docs/install.md) - installation, dépannage et configuration d'Apple Intelligence
- [docs/cli-reference.md](../docs/cli-reference.md) - chaque flag, code de sortie et variable d'environnement
- [docs/file-extraction.md](../docs/file-extraction.md) - extraction `-f` et via pipe de PDF / images / texte (OCR + compréhension d'image)
- [docs/background-service.md](../docs/background-service.md) - utilisation de `brew services` et launchd
- [docs/openai-api-compatibility.md](../docs/openai-api-compatibility.md) - matrice de prise en charge de `/v1/*` en détail
- [docs/server-security.md](../docs/server-security.md) - vérifications d'origine, CORS, tokens et `--footgun`
- [docs/context-strategies.md](../docs/context-strategies.md) - stratégies de réduction du contexte en chat
- [docs/mcp-calculator.md](../docs/mcp-calculator.md) - usage MCP local et distant
- [docs/tool-calling-guide.md](../docs/tool-calling-guide.md) - comportement détaillé de l'appel d'outils
- [docs/integrations.md](../docs/integrations.md) - intégrations d'outils tiers (opencode, etc.)
- [docs/local-setup-with-vs-code.md](../docs/local-setup-with-vs-code.md) - revue locale avec apfel + un second modèle d'édition/application dans VS Code
- [docs/demos.md](../docs/demos.md) - pas-à-pas plus longs des démos shell
- [docs/EXAMPLES.md](../docs/EXAMPLES.md) - plus de 50 vrais prompts avec leur sortie non retouchée
- [docs/swift-library.md](../docs/swift-library.md) - Swift Package `ApfelCore` pour les développeurs en aval
- [docs/coreai-impact.md](../docs/coreai-impact.md) - pourquoi apfel repose sur FoundationModels et non sur le nouveau Core AI d'Apple (le successeur de Core ML)
- [docs/apfel-vs-fm.md](../docs/apfel-vs-fm.md) - apfel comparé à la CLI `fm` d'Apple (macOS 27), fonctionnalité par fonctionnalité avec des chiffres mesurés

## Architecture

```text
CLI (single/stream/chat) ──┐
                           ├─→ FoundationModels.SystemLanguageModel
HTTP Server (/v1/*) ───────┘   (100% on-device, zero network)
                                ContextManager → Transcript API
                                SchemaConverter → native ToolDefinitions
                                TokenCounter → real token counts (SDK 26.4)
```

Concurrence stricte de Swift 6.3. Trois cibles : `ApfelCore` (logique pure, testable unitairement, aussi disponible comme produit Swift Package - lié sous Documentation de référence ci-dessus), `apfel` (CLI + serveur) et `apfel-tests` (runner en pur Swift, sans XCTest).

## Compilation et tests

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

`.version` est l'unique source de vérité. Seul `make release` incrémente les versions. Les compilations locales ne changent pas la version.

## L'arbre apfel

Projets construits sur apfel. Chacun est publié dans son propre dépôt + formule Homebrew.

| Projet | Ce qu'il fait | Installation |
|---------|--------------|---------|
| [**apfel**](https://apfel.franzai.com) | La racine. CLI FoundationModels sur l'appareil + serveur compatible OpenAI. | `brew install apfel` |
| [**apfel-chat**](https://apfel-chat.franzai.com) | Client de chat macOS : markdown en streaming, E/S vocale, analyse d'images avec Apple Vision. | `brew install Arthur-Ficial/tap/apfel-chat` |
| [**apfel-clip**](https://apfel-clip.franzai.com) | Actions IA dans la barre des menus sur le presse-papiers : résumer, traduire, réécrire. | `brew install Arthur-Ficial/tap/apfel-clip` |
| [**apfel-quick**](https://apfel-quick.franzai.com) | Surcouche IA instantanée : appuyez sur une touche, demandez, obtenez la réponse, fermez. | `brew install Arthur-Ficial/tap/apfel-quick` |
| [**apfelpad**](https://apfelpad.franzai.com) | Bloc-notes à formules - l'IA sur l'appareil comme fonction de cellule en ligne. | `brew install Arthur-Ficial/tap/apfelpad` |
| [**apfel-mcp**](https://apfel-mcp.franzai.com) | MCP optimisés en budget de tokens pour la petite fenêtre embarquée : `url-fetch`, `ddg-search`, `search-and-fetch`. | `brew install Arthur-Ficial/tap/apfel-mcp` |
| [**apfel-gui**](https://github.com/Arthur-Ficial/apfel-gui) | Inspecteur de debug SwiftUI : chronologie des requêtes, visualiseur du protocole MCP, TTS/STT. | `brew install Arthur-Ficial/tap/apfel-gui` |
| [**apfel-run**](https://github.com/Arthur-Ficial/apfel-run) | Wrapper UNIX ajoutant un registre MCP persistant + une config TOML au-dessus d'`apfel`. | `brew install Arthur-Ficial/tap/apfel-run` |
| [**apfel-tag**](https://github.com/Arthur-Ficial/apfel-tag) | CLI d'étiquetage de contenu sur l'appareil : envoyez du texte par pipe, obtenez tags/sujets/émotions. | `brew install Arthur-Ficial/tap/apfel-tag` |
| [**apfel-server-kit**](https://github.com/Arthur-Ficial/apfel-server-kit) | Swift Package pour les outils de l'écosystème : découvrir, lancer et consommer en streaming un `apfel --serve` local. | Swift Package |

## Projets de la communauté

Vous avez construit quelque chose avec apfel ? Ouvrez une issue et il pourra être ajouté ici.

| Projet | Ce qu'il fait | Liens |
|---------|-------------|-------|
| **apfelclaw** par [@julianYaman](https://github.com/julianYaman) | Agent IA local qui lit fichiers, calendrier, courrier et état du Mac via des outils en lecture seule | [github](https://github.com/julianyaman/apfelclaw) - [site](https://apfelclaw.yamanlabs.com/) |
| **fruit-chat** par [@bhaskarvilles](https://github.com/bhaskarvilles) | Interface de chat dans le navigateur qui dialogue avec `apfel --serve` via l'API compatible OpenAI | [github](https://github.com/bhaskarvilles/fruit-chat) |
| **local-claude** par [@lucaspwo](https://github.com/lucaspwo) | Wrapper de Claude Code qui utilise apfel comme backend local via un petit proxy Anthropic-OpenAI | [github](https://github.com/lucaspwo/local-claude) |
| **apfeller** par [@hasit](https://github.com/hasit) | Gestionnaire d'applications pour des apps shell locales construites autour d'apfel | [github](https://github.com/hasit/apfeller) - [site](https://hasit.github.io/apfeller/) - [catalog](https://hasit.github.io/apfeller/catalog/) |
| **apfel-for-raycast** par [@eggsy](https://github.com/eggsy) | Extension Raycast : poser des questions, traduire, expliquer fichiers et dossiers, historique des conversations, prompts système personnalisés. Sur l'appareil via la CLI apfel. | [store](https://www.raycast.com/eggsy/apfel) - [github](https://github.com/raycast/extensions/tree/main/extensions/apfel) |

## Contribuer

Issues et PRs bienvenues sur tout dépôt `Arthur-Ficial/apfel*`.

**#agentswelcome** - les PRs d'agents IA sont les bienvenues. Lisez le `CLAUDE.md` du dépôt, lancez les tests, mentionnez l'outil dans un trailer `Co-Authored-By`. Même exigence que pour les humains : code propre, tests qui passent, limites honnêtes. Point d'entrée le plus accueillant pour les agents : [apfel-mcp](https://github.com/Arthur-Ficial/apfel-mcp) ([règles de contribution](https://apfel-mcp.franzai.com/#contribute)).

## Licence

[MIT](../LICENSE)
