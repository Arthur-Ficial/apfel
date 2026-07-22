# Changelog

All notable changes to this project will be documented in this file.

The format is based on [https://keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [https://semver.org/](https://semver.org/).

## [Unreleased]

### Fixed

- `/health` and `/v1/models` no longer report `context_window: 0` on macOS 27 cold start (#192). On macOS 27 the SDK's `model.contextSize` returns 0 during initialization (observed for 80+ seconds); the server previously cached this at startup and locked in 0 for the process lifetime. `TokenCounter.contextSize` now uses a high-water mark that never regresses to 0 once a positive value is observed, with a floor of 4096 (the known minimum for any Apple Intelligence model). Both `/health` and `/v1/models` read per-request instead of using a startup cache. This also fixes the generation deadlock where `inputBudget` returned -512, rejecting all requests before the model could warm up.

### Changed

- Integration tests run in two marker-partitioned phases (#374): the model-free, parallel-safe partition first (`-m "not model and not serial"`, parallelized with pytest-xdist one-worker-per-file when installed), then the serial on-device-model phase (`-m "model or serial"`). Every test still runs exactly once and `APFEL_REQUIRE_FULL=1` still forbids skips; cheap doc-drift gates now fail in seconds instead of after ~10 minutes of model tests. `make preflight` is light by default (build + unit + model-free phase, ~1.5 min warm; `FULL=1` restores the full qualification) because `make release` runs the complete suite against the stamped release binary anyway - one full model pass per release instead of two. Marker hygiene enforced by the new `test_marker_discipline.py` source-scan suite (runs on CI): whole-suite `pytestmark` declarations for the generation-driven files (incl. the previously unmarked `test_chat.py`), a single shared `require_model()` in `conftest.py`, and a new `serial` marker for suites that mutate machine-global state (`test_brew_service.py`). Benchmark medians default to 3 runs (`APFEL_BENCH_RUNS=5` to restore the #264-era count).

## [1.8.3] - 2026-07-09

### Added

- `--code`: print only the code. Crops the response to the content of its first fenced code block (fence markers and surrounding prose removed); when the model returns no fence at all, the whole response passes through as the code, and a response that is exactly one inline code span is unwrapped. A steering directive is appended to the system prompt (composes with `-s`); extraction is deterministic regardless of model compliance. `apfel --code "python calculator" > calc.py` and `apfel --code "battery one-liner" | pbcopy` now work without a hand-rolled fence stripper. Composes with `-f`, `--messages`, piped stdin, and `-o json` (envelope gains an advisory `language` key); rejects `--stream`, `--chat`, and `--schema` with a usage error. New exit code 7: the model returned an empty response. Empirically validated against a 20-prompt battery across bash, git, awk, sed, curl, ffmpeg, python, swift, node, sql, jq, and German-language asks (#373).

## [1.8.2] - 2026-07-09

### Fixed

- `-f file` (and a positional prompt or piped content) is now honored in `--chat` instead of being silently dropped. The extracted content is folded into the session instructions so the model already has it in context on the first turn, and chat prints a one-line `context:` notice on startup. Previously `apfel -f code.swift --chat` read/OCR'd the file at parse time and then threw it away (#370).

### Changed

- Modes that neither read a one-shot prompt nor run per-request generation - `--serve`, `--benchmark`, `--model-info`, `--update` - now reject a positional prompt, `-f/--file` content, `-s/--system`, or any generation/context tuning flag (`--temperature`, `--top-p`, `--max-tokens`, `--seed`, `--context-strategy`, `--context-max-turns`, `--context-output-reserve`) with a usage error (exit 2) instead of parsing and silently ignoring it. `--context-status` is likewise rejected outside `--chat`. `--serve` still consumes `--permissive`, `--retry*`, `--mcp`, and the server flags. Found by an audit of the same silent-drop class as #370.

## [1.8.1] - 2026-07-09

### Fixed

- A model-emitted tool call whose arguments are a quoted string with unescaped inner quotes (e.g. `"arguments": "{"value1": 1234, "value2": 5678}"`) is no longer dropped when the argument object is actually recoverable. `salvageUnparseableToolCall` now runs a string-aware balanced-brace scan (`extractFirstBalancedObject`) over the raw arguments text and, when it finds a single balanced `{ ... }` that parses as valid JSON, substitutes it so the tool call executes; when no unambiguous object is extractable the raw text is kept so validation still fails loud, preserving #241's "never guess" principle. Follow-up to #358 (#367).

### Changed

- CI now blocks any pull request that changes production source (`Sources/**`, excluding the generated `BuildInfo.swift`) without a `CHANGELOG.md [Unreleased]` entry, via the `changelog-gate` job and `scripts/check-changelog.sh`. This moves the empty-`[Unreleased]` enforcement from release time (`stamp-changelog.sh`, #263) to merge time, so a code fix can no longer merge changelog-less and stall the next release - the root cause of the v1.8.1 delay (#369).

## [1.8.0] - 2026-07-03

### Changed

- The CLI now prewarms the on-device model concurrently with input I/O (`LanguageModelSession.prewarm`, the mechanism the server has used since #169): single/stream invocations overlap the model cold-start with the piped-stdin read, and `--chat` warms while the user types the first message. No flags, no output changes - pure latency. `--serve` (own prewarm), `--count-tokens` (never calls the model), and `--benchmark` (would skew cold-start measurements) are excluded (#364).

### Added

- `POST /v1/responses`: the OpenAI Responses API, served as a translation layer over the same on-device pipeline as chat completions. Supported: string and message-list `input` (incl. `input_text` parts and the `developer` role), `instructions`, `temperature`/`top_p`/`max_output_tokens`/`metadata` echo, `text.format` `json_object` and `json_schema` (guided generation), non-streaming function tools returned as `function_call` output items, and streaming with the canonical named-event sequence (`response.created` through `response.completed`, `sequence_number` on every event) - verified end-to-end against the official `openai` Python SDK's `client.responses.create()`, streaming and non-streaming. Honest 501s, never silent downgrades, for what a stateless on-device server cannot do: `previous_response_id`, `store: true`, `background`, `reasoning`, `include`, hosted tools, `function_call_output` items, and tools/json_schema combined with `stream: true`. Every response reports `"store": false` (#365).
- `--messages <file|->`: one-shot multi-turn on the UNIX tool surface. Pass an OpenAI-style conversation (a bare JSON message array or an object with a `messages` key, from a file or piped stdin via `-`) and apfel prints the next assistant message - multi-turn agents in pure shell with `jq`, no server process, no TUI. Reuses the server's transcript building (`ContextManager.makeSession`) so CLI and server multi-turn semantics cannot drift, including the last-message-must-be-user-or-tool rule and context-strategy trimming. Composes with `--stream` and `--schema`; positional prompts, `-f`, and `--chat` combinations are usage errors (exit 2) (#363).
- `--schema <file>`: guaranteed structured output on the UNIX tool surface. The single-shot CLI now accepts a JSON Schema file and constrains generation with FoundationModels guided generation (the same `DynamicGenerationSchema` path the server's `response_format: json_schema` uses since #167), so stdout is always one schema-valid JSON object - no fence stripping, no invalid-JSON retries, jq-ready. Malformed or unsupported schemas fail at argument-parse time with exit 2; `--chat`, `--stream`, `--count-tokens`, and MCP combinations are rejected as usage errors; `-o json` wraps the object as a string in the standard envelope (#361).

## [1.7.2] - 2026-07-02

### Fixed

- A model-emitted tool call whose JSON is unparseable (e.g. a literal `<escaped_json_string>` placeholder with unescaped nested quotes, live-reproduced on the macOS 26.5.2 model at seed 7) no longer leaks the raw `{"tool_calls": ...}` protocol text to the client as `message.content`. `detectToolCall` now salvages the function name from such an attempt and keeps the raw (still invalid) arguments, so the existing invalid-arguments recovery (#241) feeds a tool error back to the model instead. `stripToolCallJSON` moved into ApfelCore (`ToolCallHandler`) with unit coverage, including the strip-to-end fallback for never-balancing garbage (#358).
- The bundled MCP calculator no longer string-concatenates non-numeric arguments: `add({"a":"999","b":"1"})` returned `9991` as a successful tool result (published verbatim in docs/EXAMPLES.md) and `add({"a":"abc","b":"1"})` returned `"abc1"`. Operands are now coerced to numbers and non-numeric input returns an `isError` tool result. Covered by a new model-free direct JSON-RPC suite wired into CI (#322).
- `--benchmark`'s `token_counter_available` field now reports tokenizer availability instead of model generation availability. On macOS 26.0-26.3 with Apple Intelligence enabled it said `true` while every count in the report was chars/4 - the pre-#315 misclassification surviving on this surface. This also gives `isTokenCountingAvailable` its one real caller again (dead code since #315 rewired the CLI) (#325, #328).
- `--count-tokens --mcp` on macOS older than 26.4 no longer counts MCP tool schemas as 0. The skip-session gate keyed on "any fallback" but only a genuinely unavailable model makes session construction unsafe; under `osTooOld` entries are now built normally and counted via the chars/4 fallback, which prices tool definitions - so `--strict` can no longer false-pass while the real request overflows (#326).
- `--count-tokens` can no longer report `"approximate": false` for numbers that were actually chars/4. If `tokenCount(for:)` throws at runtime, or availability flips after the pre-flight check, the counter records the fallback and the report folds it in, with a distinct stderr warning naming the runtime failure (#327).
- `/health`'s `supported_languages` no longer contains duplicates. The SDK reports locale variants (`en_US`, `en_GB`, `en_AU`...) whose language codes all collapse to the same bare code; the list is now deduplicated preserving SDK order (was: `en` x3, `es` x3, `zh` x3, `fr` x2, `pt` x2 in 23 entries) (#329).
- The `contextOverflow` client-facing message no longer hardcodes "4096-token": the window size is dynamic everywhere else (`TokenCounter.contextSize`) and the pinned number would become a lie the day the OS reports a different window (#330).
- docs/EXAMPLES.md's Table of Contents now includes section 14 (File Extraction): the generator script's hardcoded TOC had drifted from the sections it emits, so every regeneration reproduced a TOC contradicting the body. A model-free CI test now asserts TOC-vs-body consistency (#331).
- The release workflow re-stamps the docs/EXAMPLES.md header with the version being released. The doc is regenerated from the installed binary before the bump, so its stamp was permanently one version behind the tag shipping it (#332).
- Documentation truthfulness sweep: CLAUDE.md's stale "53 prompts" claim dropped (the suite runs 60), the README keeps exactly one Swift-library link per the structure rule, the man page and docs/cli-reference.md now document the `--count-tokens` chars/4 fallback and the JSON `approximate` field, stale "as tested" labels across docs/tool-calling-guide.md, docs/PERMISSIVE.md, and all ten docs/guides footers were refreshed with honest provenance, and STABILITY.md now defines the patch-release policy for fix-supporting public API (the v1.7.1 `TokenCountFallback` precedent) (#333, #334, #335, #336, #338).
- Test hardening against the macOS 26.5.2 model's aggressive in-band guardrail refusals: a shared conftest helper (broadened refusal matcher + seed rotation) now protects every seed-pinned content assertion across the MCP and OpenAI-client suites - one fixture was already receiving refusal text at its pinned seed and passing by luck. The two MCP-timeout tests now follow the `require_model()` marker discipline, and the multibyte-backspace guarantee is proven end-to-end against the persisted line-editor buffer via `APFEL_HISTFILE` (#323, #324, #337, #339).

## [1.7.1] - 2026-07-02

### Fixed

- The `--count-tokens` chars/4 fallback warning now names the actual reason instead of always blaming Apple Intelligence. On a Mac running macOS older than 26.4 the `tokenCount(for:)` API does not exist at runtime even though generation works fine, so the old message ("Apple Intelligence unavailable") was false and misleading - it made real doc output look like a broken machine. The reason decision is a pure, unit-tested `TokenCountFallback` in ApfelCore: `osTooOld` (names the required 26.4 and the actual OS version) wins over `modelUnavailable`. Covered by unit tests and a model-free cli_e2e test that asserts the warning against the host OS version (#315).

## [1.7.0] - 2026-07-02

### Added

- On-device file extraction for `-f`/`--file` (and piped files) via the public [lesbar](https://github.com/Arthur-Ficial/lesbar) package: `apfel -f report.pdf "summarize"` now reads PDFs (PDFKit text, Vision OCR fallback for scans) and images (Vision OCR text plus a short scene description) entirely on device, no network. Many image formats are supported (PNG, JPEG, HEIC, TIFF, GIF, BMP, WebP and more) alongside plain text and PDF. Piped files (`cat report.pdf | apfel "summarize"`) route through the same extractor with format sniffing. Documented in [docs/file-extraction.md](docs/file-extraction.md) (#211).
- Shell completions via a new `apfel completions <shell>` subcommand (`bash`, `zsh`, `fish`) that prints a completion script to stdout, plus the three generated scripts committed under `completions/` for packagers. The completion flag table is derived from the parser's own `CLIArguments.knownFlags` (single source of truth, unit-enforced to match exactly), so a new flag cannot ship without its completion. Completions cover every flag, the five `--context-strategy` values, `plain`/`json` for `-o`, file completion for `-f`/`--file`/`--mcp`/`--system-file`, and the `completions` subcommand's own shell names. The Homebrew tap formula installs them to the standard per-shell directories, and the release tarball now ships `completions/`. Covered by generator unit tests (name-set equality, per-shell markers, strategy/file coverage) and cli_e2e tests including a committed-file-vs-binary drift guard (#259).
- Opt-in persistent `--chat` history via the `APFEL_HISTFILE` environment variable. Off by default (the honest, secure default): when unset, chat line-editing history stays in memory only and nothing is written to disk. When set to a path, prior history is loaded at startup (up-arrow reaches earlier sessions) and the file is rewritten on exit, bounded to the most recent 500 entries and chmod 0600 (it contains your prompts). A leading `~` is expanded. macOS libedit exposes `read_history`/`write_history`/`history_truncate_file` but not GNU readline's `append_history`, so the merged in-memory list is written and then truncated to stay bounded. The opt-in path decision is a pure, unit-tested `ChatHistory.filePath(env:)` in ApfelCLI; persistence is verified end-to-end via a PTY test (#259).

### Changed

- Release tarballs now ship a Developer ID signed, notarized `apfel` binary and a checksum asset. The binary is signed with the "Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)" identity under a hardened runtime and the submission is notarized by Apple, so downloads outside Homebrew are no longer Gatekeeper-quarantined. It is intentionally not stapled - a bare CLI binary in a tarball cannot carry a stapled ticket, so Gatekeeper verifies notarization online. Each release also publishes `apfel-<version>-arm64-macos.tar.gz.sha256` as a second asset; `scripts/post-release-verify.sh` cross-checks the tarball digest against it and the Homebrew tap formula and confirms the TeamIdentifier. `make release` hard-fails if signing or notarization fails; local `make build`/`make package-release-asset` on a machine without the identity still produce an ad-hoc binary (#226).
- JSON output now ends with a single trailing newline. `apfel -o json ...`, `apfel --count-tokens -o json ...`, and `apfel --benchmark -o json` previously printed the final JSON object with no terminating newline (last byte `}`), which made `while read` loops and `wc -l` awkward. This reverses the earlier GH-9 no-trailing-newline behavior; JSONL chat lines already ended with a newline and are unchanged (no double newline). Covered by a model-free cli_e2e test on `--count-tokens -o json` and an updated single-prompt JSON test (#259).
- STABILITY.md now documents enum evolution for the ApfelCore library: public enums are non-frozen and may gain new cases in minor releases (always switch with a `default` branch); removals and signature changes remain major. The CI API-breakage gate enforces exactly this split instead of failing on every added case.
- The tool-schema conversion cache (`SchemaConversionCache`) is now a bounded LRU: when full it evicts only the single least-recently-used entry instead of wiping all 64. Previously the 65th distinct tool set flushed the entire cache, so two alternating clients each with more than 32 distinct tool sets caused pathological full-cache churn. Backed by a new pure `LRUCache` in ApfelCore with unit coverage of eviction and the hot-entry-survives property (#247).

### Fixed

- A chat-completions request with a negative `seed` no longer crashes the entire server process. `seed: -1` trapped the `UInt64` conversion in the request handler - a remote, unauthenticated denial of service on the default loopback bind (one malformed curl killed `apfel --serve`). The validator now rejects negative seeds with HTTP 400 before the conversion is reached (#212).
- Documentation test-count and release-step claims are back in sync with reality. `CLAUDE.md` (Current Status, Build & Test, the CI section, and the release-step list) and `docs/release.md` had drifted: they cited 687 unit / 301 integration (now 890 unit / 393 integration), an arithmetically impossible CI subtotal, and release steps that omitted the CHANGELOG stamp and the whole nixpkgs bump step. Counts were recomputed from `swift run apfel-tests` and a full `make test`, the CI numbers were derived from `ci.yml` plus `-m "not model"` collect counts (890 unit + 127 model-free integration), and the release-step lists now describe `publish-release.sh` faithfully (CHANGELOG stamp, signing, notarization, sha256 sidecar, nixpkgs bump) (#270).
- The `--help` ENVIRONMENT section now lists `APFEL_MCP_TOKEN` (the bearer token for remote MCP servers) and describes `APFEL_MCP` as comma-separated with colon accepted for local paths, matching the parser (commas are canonical because a colon would split remote URLs like `https://host:8080`) and the man page. Previously the token was only mentioned in the `--mcp-token` flag description and `--help` called `APFEL_MCP` colon-separated, contradicting both the parser and the man page. A new section-scoped man-page test asserts the ENVIRONMENT lists in `--help` and the man page contain the same variables (#257).
- The relative link to the CLI reference in `docs/tool-calling-guide.md` no longer 404s on GitHub. The target was written as `docs/cli-reference.md`, but since the file already lives in `docs/`, it resolved to `docs/docs/cli-reference.md`; it now points at `cli-reference.md`. A scripted sweep of the whole `docs/` tree confirmed this was the only self-referencing `docs/` link (#267).
- `apfel --update` no longer hardcodes `/opt/homebrew/bin/{brew,apfel}`, which broke on non-default Homebrew prefixes (Intel `/usr/local`, a custom `~/homebrew`, etc.): `detectInstallMethod` correctly returned `.homebrew`, but the update shelled out to a nonexistent `/opt/homebrew/bin/brew` ("Could not check for updates.") and the post-upgrade version echo ran the wrong/absent binary (printing "Updated to " with an empty version). The brew prefix is now derived from the resolved binary path (the component before `/Cellar/` or `/opt/apfel/`) via a pure `homebrewPrefix(fromBinaryPath:)` in ApfelCLI with unit coverage, with a `PATH` lookup of `brew`/`apfel` as fallback; the post-upgrade echo uses the same derived prefix (#260).
- Chat line editing of non-ASCII input is now character-wise instead of byte-wise. apfel never called `setlocale`, so it ran in the `"C"` locale regardless of `LANG=...UTF-8`, and libedit's multibyte handling (`mbrtowc`/`ct_encode`) keys off `LC_CTYPE` - editing a line with `ü`/`é`/emoji (backspace, arrow-left, Ctrl-W) operated on single bytes, so one backspace over `é` left a dangling `0xC3` byte and misdrew the line. `setlocale(LC_CTYPE, "")` now runs once at startup in main.swift before any `ChatLineEditor` is constructed. Verified via a PTY: one backspace erases the whole 2-byte character (#256).
- Ctrl-C at the interactive chat prompt now restores the terminal before exiting. The SIGINT handler `_exit(130)`s straight out of libedit, so its `rl_deprep_terminal`/atexit cleanup never runs and the tty was left in raw/no-echo mode - fine under zsh (which repairs its own tty) but broken for `sh`, script wrappers, and expect-style harnesses. The handler now captures the cooked termios before libedit switches to raw mode and restores it via `tcsetattr` (async-signal-safe) inside the handler. Exit code 130 (interrupted) is now documented in the man page EXIT STATUS and `--help` EXIT CODES. Verified via a PTY: ICANON/ECHO restored and exit 130 (#251).
- A context-rotation failure during a `--chat` session now exits nonzero instead of 0. Previously, if `truncateTranscript` threw (e.g. `--context-strategy strict` with history over budget throwing `contextOverflow`), the loop broke, "Goodbye." printed, and the process exited 0 - so a wrapper script saw success despite the session dying, while single-prompt mode mapped the same error to exit 4. The rotation failure is now captured and rethrown after the loop so main.swift's top-level handler maps it via `exitCode(for:)` (exit 4 for context overflow). A plain `throw` inside the turn body would have been swallowed by the per-turn model-error catch, so the error is threaded out explicitly (#252).
- Usage text on usage-error exits (exit 2) now goes to stderr instead of stdout, so a failed invocation no longer pollutes a downstream pipe with ~5 KB of help text. `printUsage(to:)` takes a destination: `--help`/`.help` keeps usage on stdout with exit 0, while the no-args-at-a-terminal error path writes to stderr. Color for the stderr variant is gated on stderr's TTY-ness (#250).
- ANSI color for stderr-destined output now keys off stderr's own TTY-ness instead of stdout's. Previously `styled()` gated colorization on `isatty(STDOUT_FILENO)` for every write, so `apfel --bogus-flag 2>err.log` in a terminal wrote raw escape codes into the log (and, conversely, `apfel ... | cat` with stderr on a TTY printed uncolored errors). A new `styledErr()` keys off `isatty(STDERR_FILENO)`, and all unconditional-stderr sites (error messages, debug logs, the tool log, the `--serve` startup banner, MCP/parse warnings) route through it. The gating decision is a pure `ColorPolicy.shouldColorize` in ApfelCLI with unit coverage (#249).
- An empty `NO_COLOR=` (empty string) no longer disables color. Per https://no-color.org and apfel's own man page, only a non-empty `NO_COLOR` value disables ANSI color; an empty value (e.g. from `env -i NO_COLOR=` or a CI template) is now treated as absence. The env check moved to a pure `ColorPolicy.noColorFromEnv` in ApfelCLI with unit coverage (#258).
- The no-args pipe path (`echo "prompt" | apfel`) now honors every `APFEL_*` environment variable and applies the model-availability gate. Previously a fast path ran before `CLIArguments.parse()` was ever called, so `APFEL_SYSTEM_PROMPT`, `APFEL_TEMPERATURE`, `APFEL_MAX_TOKENS`, `APFEL_MCP`, `APFEL_DEBUG`, and the `APFEL_CONTEXT_*` vars were silently dropped and an unavailable model surfaced as a classified runtime error instead of the documented exit 5. The fast path is gone; the bare pipe flows through the normal parse/dispatch path, still streaming by default to preserve its output behavior. The only remaining no-args special case is "no args and stdin is a TTY -> usage + exit 2" (#222).
- Flag-like tokens placed after the prompt (`apfel summarize this --output json`) now emit a stderr warning explaining that they are treated as prompt text and pointing at flag placement / `--`. Behavior is unchanged (still non-breaking: the whole tail is the prompt verbatim), but the previously-silent swallowing of a valid flag into the prompt is now surfaced. Detection uses the parser's own `knownFlags` table (single source of truth, no second hardcoded list) so only real flag spellings trigger it; a genuinely textual dash token like `-2` does not (#255).
- Invalid `APFEL_*` environment values now print a stderr warning instead of being silently dropped to the default while the equivalent flag hard-errors. `APFEL_PORT=99999` (out of range), `APFEL_TEMPERATURE=abc` (non-numeric/negative), `APFEL_CONTEXT_STRATEGY=newest_first` (typo), `APFEL_MAX_TOKENS`, `APFEL_MCP_TIMEOUT`, `APFEL_CONTEXT_MAX_TURNS`, and `APFEL_CONTEXT_OUTPUT_RESERVE` each emit a line like `apfel: ignoring APFEL_PORT=99999 (not in 1-65535)`. Warnings are collected on the parsed struct by the pure `parse()` (unit-testable) and printed by the executable unless `--quiet`. A set-but-empty var is still treated as absence, not a misconfiguration (#254).
- `apfel --retry N` no longer silently swallows a numeric first prompt word. The optional `--retry` count is genuinely ambiguous with a numeric prompt, so the next token is now consumed as the count only when it is a positive integer *and* at least one more token follows it: `apfel --retry 7` keeps "7" as the prompt with the default count, while `apfel --retry 3 "prompt"` still consumes 3 as the count (backward compatible). A new `--retry=N` spelling sets the count unambiguously. The ambiguity is documented in `--help` and the man page (#253).
- `apfel demos --help` / `apfel demos -h` now prints usage and exits 0 instead of immediately writing the nine bundled demo files into the current directory. The `demos` subcommand branch previously returned as soon as it saw the `demos` token, so every flag after it (`-h`, `-q`, `-o json`, unknown flags) was silently discarded. It now scans the tokens after `demos`: `-h`/`--help` shows help, the first non-dash token is the target directory, and any other dash token is a hard `unknown option` error (exit 2) instead of being ignored (#248).
- The server now validates the `Host` header as a DNS-rebinding defense when origin checking is enabled and the bind host is loopback. Same-origin GET requests carry no Origin header, so origin checking alone could not stop a rebound attacker domain (`attacker.com` re-resolved to `127.0.0.1`) from reading `/health` and `/v1/models`. Requests whose Host is not a loopback name (`localhost`/`127.0.0.1`/`[::1]`, with or without a port) or the configured bind host are now rejected with 403. Legitimate localhost clients (which send Host with the port) and health checks are unaffected; a deliberately network-exposed bind (`0.0.0.0`) is exempt since its Host values cannot be enumerated. The host-allowlist logic is a new pure `ServerSecurity.isAllowedHostHeader` in ApfelCore with unit coverage (#230).
- Local (stdio) MCP subprocesses now run with a scrubbed environment instead of inheriting apfel's entire environment. Previously `MCPConnection` spawned the child without setting `Process.environment`, so a third-party `--mcp ./tool.py` script inherited `APFEL_TOKEN`, `APFEL_MCP_TOKEN`, and any cloud/API keys in the shell. The child now gets an explicit allowlist (PATH/HOME/TMPDIR/LANG, plus `LC_*`, `PYTHON*`, and `VIRTUAL_ENV` for python3/FastMCP/venv servers); every `APFEL_*` var and any var whose name contains TOKEN/KEY/SECRET is excluded. The allowlist logic is a new pure `ServerSecurity.scrubbedMCPEnvironment` in ApfelCore with unit coverage; documented in docs/server-security.md (#229).
- Binding the server to a non-loopback address (`--host 0.0.0.0`, `APFEL_HOST=0.0.0.0`, or any LAN address) with no token now prints a loud red startup warning as prominent as the footgun warning, pointing at `--token`/`--token-auto` and docs/server-security.md. Previously it started silently with zero authentication - every host on the network could hit `/v1/chat/completions` with no credentials. The server still binds (no breaking behavior change); it just warns loudly. The host-classification and warning-gate logic is a new pure `ServerSecurity` in ApfelCore with unit coverage (#228).
- The prominent multi-line red startup warning now fires whenever origin validation is disabled, not only when CORS is also enabled. Previously `--no-origin-check` alone (CORS off) turned off origin validation but showed only the muted `origin: disabled (all origins allowed)` status line; the loud "Any website can access this server and read responses!" warning was gated behind `--footgun` (no origin check AND CORS). The warning headline now distinguishes footgun mode from plain origin-check-disabled (#232).
- The server bearer token is now compared in constant time. Previously `OriginValidator.isValidToken` used Swift `String ==`, which short-circuits on the first differing byte, so comparison time correlated with the shared prefix length - a timing side channel on the token. Comparison now XOR-accumulates over the UTF-8 bytes with the length difference folded into the accumulator (no early return on length mismatch), via a new pure `OriginValidator.constantTimeEquals` in ApfelCore with unit coverage (#231).
- The server-side MCP auto-execute path now runs the same bounded re-detection loop as the CLI path (`maxReprompts = 3`) plus `stripToolCallJSON` on cap exhaustion, instead of executing exactly one round and returning the follow-up content verbatim. If the model answered the tool-result follow-up with another `{"tool_calls": ...}` (common in tool chains), the HTTP client previously received raw tool-call JSON as `message.content` with `finish_reason: "stop"`. Chained tool calls are now executed and re-prompted, and any trailing tool-call JSON is stripped so it never leaks. The per-result truncation was extracted to a shared helper reused across rounds (#240).
- Large MCP tool results are now token-budget-truncated (head+tail, with an explicit `[tool output truncated: N of M tokens shown]` marker) before the follow-up prompt. A result bigger than the 4096-token window previously killed the CLI request with "Input exceeds the 4096-token context window" after the tool already ran, and in `--serve` mode the context trimmer dropped the oversized tool message whole while still instructing the model to "answer based on the tool result above" - a confident hallucination. The budget is the input window (context size minus a 512-token output reserve) minus the prompt overhead. The truncation math lives in a new pure `ToolOutputTruncator` in ApfelCore with unit coverage; token counting is wired at both the CLI and server call sites, and the server path keeps the tool message present (truncated) instead of dropping it (#221).
- An MCP tool result with `isError: true` (e.g. `divide(1, 0)` returning "division by zero") is now fed back to the model as an error result so it can see the failure and recover, instead of aborting the request with HTTP 500 (`--serve`) or a runtime error (CLI). Per the MCP spec, execution errors "should be reported inside the result object ... so the LLM can see it and act". `callTool`/`execute` now return the `ToolCallResult` (text + isError) instead of throwing on isError; `detectAndExecuteMCPTools` records it like the existing `toolNotFound`/`invalidArguments` branches. Only transport/protocol failures (timeout, dead pipe, JSON-RPC error) still surface as 500 (#220).
- Tool-name collisions across multiple `--mcp` servers no longer silently shadow earlier servers. When two servers expose a tool with the same name, apfel now prints a loud stderr warning naming the tool and both servers and keeps the first registration (first registration wins - predictable routing, no rename surprises); the shadowed duplicate is dropped from `allTools()` instead of being injected into the 4096-token prompt a second time. Previously the last-registered server won with no warning and both identical schemas were sent to the model. The dedup/collision logic is a new pure `MCPToolRegistry` in ApfelCore with unit coverage (#239).
- A model-emitted tool call that omits (or blanks) the `"id"` field is no longer dropped and leaked to the user as raw `{"tool_calls":...}` JSON. The parser now synthesizes a `call_<8 hex chars>` id when one is missing or empty, consistent with the lenient parsing that already tolerates unclosed brackets, preambles, and string-vs-object `function` shapes. The on-device 3B model routinely deviates from the exact prompt format, and omitting the id was the one deviation that still hard-failed (no tool executed, protocol JSON printed verbatim) (#244).
- Concurrent tool calls on one local MCP connection in `--serve` mode no longer race on the child's stdio: the full send+receive exchange (and standalone notification writes) is now serialized per connection with a dedicated lock. Previously two simultaneous requests could interleave stdin writes (corrupting arguments larger than PIPE_BUF) and consume each other's stdout lines, delivering swapped or dropped tool results (#218).
- MCP JSON-RPC responses are now correlated by `id`: the stdio reader loops under one shared deadline until the response matching the request id arrives, skipping server notifications (e.g. the `notifications/message` log lines FastMCP's `ctx.info()` emits), skipping responses to other ids, and answering server `ping` requests. Previously the next stdout line - whatever it was - was parsed as the response, so a single server log line failed the call with "Missing content" and left the real response buffered, desyncing every subsequent call on the connection permanently (#217).
- MCP `tools/call` results with multiple text content blocks no longer lose everything after block 0 - all `type: "text"` blocks are now joined with newlines. Spec-legal results that previously failed the whole request with "Missing content" now parse: an empty `content` array is a valid empty result, a result whose content has no text blocks (e.g. an image block from a side-effect tool) falls back to serializing `structuredContent` (2025-06-18 spec, the `protocolVersion` apfel advertises) or an empty result. Only a response with neither `content` nor `structuredContent` is rejected (#242).
- Malformed model-emitted tool-call arguments (e.g. truncated JSON) are no longer silently replaced with `{}` before hitting the MCP server - a tool with all-optional parameters "succeeded" with defaults and produced a confidently wrong answer with no trace. The call sites now validate the arguments first and throw a typed `MCPError.invalidArguments`, which is fed back to the model as a retryable tool-error result in the tool log (#241).
- MCP servers are now shut down before the process exits, instead of via a fire-and-forget `defer { Task { await mcpManager?.shutdown() } }` that frequently never ran - async main returned and the process exited before the unstructured Task was scheduled, so children only died on stdin EOF (a server ignoring EOF was orphaned) and on explicit `exit()` paths after MCP init (no-prompt exit 2, `--count-tokens --strict` overflow exit 4, classified-error exits) the defer never ran at all. Shutdown is now an awaited call on every exit path and on normal completion: local children get `terminate()` + a bounded `waitUntilExit()` (SIGKILL escalation after a grace period) and remote connections get their session `DELETE` awaited (#246).
- A timed-out MCP connection is now deregistered instead of staying permanently registered but dead. Previously, when a tool call timed out, the connection was terminated but never removed from the routing tables, so the model kept being offered the dead tool via `allTools()` and every later call routed to the dead connection (a permanently broken tool with no recovery, and - before the sibling SIGPIPE fix - a process crash). apfel now removes the connection's tools from the routing map on timeout and reaps its child (SIGTERM, then SIGKILL after a bounded grace period, then a blocking wait so no zombie is left behind) (#216).
- A crashed MCP server no longer kills the whole apfel process. Previously, if an MCP server exited between calls, the next tool call wrote to a pipe whose read end was closed, raising SIGPIPE (fatal by default, exit 141) and, in `--serve` mode, taking down the entire HTTP server - a remote/third-party MCP server could therefore crash the local process. apfel now ignores SIGPIPE process-wide and guards the stdin write with a `process.isRunning` check plus the throwing `write(contentsOf:)` (the legacy non-throwing `FileHandle.write(_:)` raised an uncatchable ObjC exception on EPIPE), mapping the failure to a recoverable `MCPError.processError` so the tool call returns a structured `500` and the server stays up (#215).
- A `response_format: json_schema` property typed `{"type":"number"}` can now produce fractional values (e.g. `{"price": 9.99}`, `{"temperature": 0.7}`). The schema IR previously conflated JSON Schema `integer` and `number` into one case that mapped to `Int`, so fractional outputs were silently unreachable under schema-guided structured output. The IR now has distinct `.integer` (-> `Int`) and `.number` (-> `Double`) cases (#243).
- JSON Schema nodes using the common nullable-optional pattern - `anyOf`/`oneOf` `[X, {"type":"null"}]` (any order) or a two-element `"type":["string","null"]` array - now parse as `X` with optional semantics, instead of silently degrading to an empty (unconstrained) object schema. Every `Optional[...]` field in a Pydantic/zod-generated MCP tool schema emits this pattern, so previously the model was told such tools took `{}` and emitted argument-less calls. Any other union (`allOf`, multi-type unions, type arrays without exactly one `null`) now throws the parser's unsupported error, so tool conversion engages the existing text-injection fallback and a `response_format: json_schema` request gets an honest `400` instead of a `200` with unconstrained generation (#219).
- `stream: true` with client-supplied `tools` no longer leaks the raw tool-call JSON to the client as `delta.content`. While tools are in play the streaming path holds back content that is still a plausible tool-call prefix and flushes it as content only once it diverges, so plain text answers still stream token-by-token while tool calls are buffered. On detection the `tool_calls` delta is emitted in its own chunk (`finish_reason: null`) followed by a SEPARATE empty-delta chunk carrying `finish_reason: "tool_calls"` (OpenAI parity), instead of the previous single chunk that bundled both. The plausible-prefix decision lives in the new `StreamingToolCallGate` (ApfelCore) with unit coverage (#224).
- `stream: true` with `response_format: {"type": "json_object"}` now delivers valid JSON: the streaming path buffers the response and emits a single fence-stripped content delta (mirroring the structured-output stream), so the concatenated deltas parse directly. Previously the first delta was a ` ```json ` fence and the joined stream was invalid JSON even though the non-streaming path was already correct (#223).
- Streaming responses with `stream_options.include_usage: true` now send an explicit `"usage": null` on every non-final chunk (matching OpenAI), instead of omitting the key; the single final chunk still carries the real usage stats. Without the opt-in no `usage` key is emitted at all (#238).
- An invalid `tool_choice` (an unrecognized string like `"banana"` or an undecodable object) now returns `400 invalid_request_error` instead of being silently coerced to `auto`. `ToolChoice` decodes such values to a new `.invalid` case that the validator rejects (#238).
- An unknown `x_context_strategy` value (e.g. `sliding-window` typo'd as `sliding_window`) now returns `400 invalid_request_error` listing the valid values, instead of silently falling back to `newest-first` while the caller believes their strategy is active. The sibling `x_context_max_turns`/`x_context_output_reserve` params were already strictly validated (#237).
- The OpenAI error object now always includes `param` and `code` (explicit `null` when absent), so router/proxy front-ends that branch on `error.code` see the key. An unknown `model` now returns `404` with `code: "model_not_found"` and `param: "model"` (OpenAI parity) instead of `400` with the keys omitted (#236).
- `top_p` outside `[0, 1]` and `temperature` above `2` now return `400 invalid_request_error` instead of passing through to FoundationModels and surfacing as an opaque `500`. The existing `temperature < 0` check is unchanged; OpenAI caps `temperature` at 2 and requires `top_p` in `[0, 1]` (#235).
- A `/v1/chat/completions` request body over 1 MiB now returns `413` with an OpenAI error object, CORS headers, and a request-log entry, instead of a bare `413` with `Content-Length: 0` (no error object, unreadable by browser clients, unlogged). The over-limit `collect` error is caught inside the handler and returned as a normal response so the CORS middleware and request logger both run (#234).
- Empty or null `content` in the last (non-tool) user message of a `/v1/chat/completions` request now returns `400 invalid_request_error` ("The last message must have non-empty 'content'") instead of `500 server_error`. A missing prompt is a client-input problem, not a server fault (#233).
- Streaming requests that fail before the SSE body is built (validation failure, bad `json_schema`, context-build failure) no longer leak a concurrency permit and an `active_requests` count. Previously `--max-concurrent` (default 5) malformed `"stream": true` requests permanently exhausted server capacity - a remote unauthenticated DoS. Cleanup is now keyed on an explicit `ownsCleanup` trace flag set only by live SSE stream responses, instead of on the requested `stream` value (#213).
- A request that waits the full 30s for a concurrency permit no longer crashes the whole server with SIGABRT ("freed pointer was not the last allocation"); it now gets the intended 429. The semaphore timeout task no longer uses the clock-based `Task.sleep(for:)` (which aborted the task allocator on resume under the server executor) and is now stored on the actor and cancelled by `signal()` when a permit is handed over. `AsyncSemaphore` moved into `ApfelCore` for unit-test coverage (#214).

## [1.6.1] - 2026-06-23

### Added

- `apfel --count-tokens` - zero-inference token-budget preflight. Reports how many tokens a prompt would consume before calling the on-device model, broken down by prompt/system/file/MCP component against the context budget. Accepts the same inputs as prompt mode (stdin, `-f`, `-s`, `--system-file`, `--mcp`), supports `-o json` for a machine-readable breakdown, and `--strict` (exit 4 when over budget). Runs even when Apple Intelligence is unavailable via a chars/4 fallback (`approximate: true`) (#207).

### Fixed

- Tap formula no longer prints Homebrew 6's `depends_on :macos` with `depends_on macos:` runtime deprecation on every `brew` operation. The macOS version floor moved into an `on_macos` block (as Homebrew's deprecation message prescribes) while the bare top-level `depends_on :macos` - the only hard Linux block for the prebuilt-binary tap - is preserved (#206).
- `message_text_content` benchmark no longer flakes the release preflight. It is a single-pass correctness refactor with no reliably measurable speedup, so the performance test now validates its output rather than asserting a wall-clock speedup ratio it cannot stably deliver.

## [1.6.0] - 2026-06-14

### Added

- `apfel demos [dir]` writes the bundled demo scripts (cmd, explain, oneliner, wtd, naming, port, gitsum, mac-narrator) to a directory. The demos are embedded in the binary, so it behaves identically on homebrew-core, the tap, and source builds (#204).

### Changed

- CHANGELOG.md is now backfilled through every release and kept current automatically by the release workflow (#201).

### Fixed

- Tap formula keeps its macOS-only guard: silence the `Homebrew/OSDependsOn` style warning without dropping `depends_on :macos`, which is the only hard Linux block for the prebuilt-binary tap (#203).

## [1.5.5] - 2026-06-09

### Fixed

- Handle function-name string tool calls (#200).

## [1.5.4] - 2026-06-09

### Changed

- Zero-touch nixpkgs distribution via r-ryantm + merge bot.

## [1.5.3] - 2026-06-09

### Fixed

- Strict context strategy no longer duplicates the final prompt.
- Support the standard `--` end-of-options separator.
- Blank line in MCP reader leftover no longer stalls into a timeout.

## [1.5.2] - 2026-06-08

### Fixed

- Repair unclosed bracket in model tool call JSON (#187).

## [1.5.1] - 2026-06-01

### Removed

- Removed the `apfel tag` subcommand - feature creep, moved to sister tool [https://github.com/Arthur-Ficial/apfel-tag](https://github.com/Arthur-Ficial/apfel-tag).

## [1.5.0] - 2026-06-01

### Added

- `APFEL_DEBUG` env var enables debug logging (#164).

### Changed

- Bump hummingbird to 2.25.0 (#162).

## [1.4.0] - 2026-06-01

### Added

- Native `response_format` json_schema via DynamicGenerationSchema (#167).
- Honor `top_p` (nucleus sampling) and make `temperature:0` deterministic via `.greedy` (#168).
- Model prewarm at startup, `/health` reports "prewarmed" (#169).

### Fixed

- Bound summary tokens and verify assembled transcript fits budget (#175).
- Count pre-refusal streamed content in `completion_tokens` (#179).
- Print streamed output once across retries (#182).
- String-aware brace scan + bounded CLI re-detection (#178).
- Fallback token counter counts tool definitions and tool-call args (#176).
- Unknown `GenerationError` case classifies to `.unknown`, not a locale keyword guess (#181).
- `SchemaParser` throws on non-dictionary property schema instead of silently dropping it (#180).
- Env vars and `--retry` enforce the same validation as their flags (#177).
- `JSONFenceStripper.strip` returns trimmed content when no fence present (#183).

## [1.3.8] - 2026-05-21

### Added

- `--context-status` flag to show context fill after each turn (#157).

## [1.3.7] - 2026-05-20

### Added

- Ship `demo/` scripts as `apfel-<name>` companion commands in Homebrew (#155).

## [1.3.6] - 2026-05-20

### Added

- Detect MacPorts install on `--update` (#151).

### Changed

- Bump hummingbird dependency.

## [1.3.5] - 2026-05-18

### Fixed

- Warn when piped stdin is empty (#152).

## [1.3.4] - 2026-05-14

### Added

- Auto-bump nixpkgs as final step of `make release`.
- Zed agent panel integration guide.

### Fixed

- Use text-only tool instructions to prevent native interception (#144).

### Changed

- Bump swift-docc-plugin from 1.4.6 to 1.5.0.
- Bump hummingbird dependency.

## [1.3.3] - 2026-04-27

### Fixed

- Graceful `finish_reason=length`; drop arbitrary 1024 default (#136).

## [1.3.2] - 2026-04-26

### Fixed

- CLI/server parity for `max_tokens` default and `--serve --permissive` (#130).

## [1.3.1] - 2026-04-26

### Fixed

- Apply default `max_tokens` when client omits the field (#128).

## [1.3.0] - 2026-04-25

### Fixed

- Return 200 OK + `content_filter` for on-device refusals instead of 500 (#118).

## [1.2.2] - 2026-04-24

### Fixed

- Cache static model metadata at startup to avoid `/health` cold-start timeout and mid-flight SDK crash (#125).

## [1.2.1] - 2026-04-24

### Added

- TDD coverage for `ApfelError.refusal` + extract `exitCode` mapping into ApfelCLI (#124).

## [1.2.0] - 2026-04-24

### Added

- Preserve refusal explanation via `ApfelError.refusal(String)` (#120).

## [1.1.2] - 2026-04-24

### Changed

- Extract FoundationModels `GenerationError` classification into typed enum (#117).

## [1.1.1] - 2026-04-22

### Changed

- Reframe golden goal in README, trim Swift library content to a single link per CLAUDE.md structure rule.

## [1.1.0] - 2026-04-22

### Added

- `ApfelCore` exposed as a public Swift Package library product (#114, #105).
- Downstream-consumer smoke coverage for importing `ApfelCore` from another package.
- DocC catalog, examples, and package metadata for `ApfelCore`.

### Fixed

- Stop regenerating `BuildInfo.swift` on every local build (#108).

### Changed

- Replace the unsafe global debug flag with `ApfelDebugConfiguration`.
- Serialize same-reader `BufferedLineReader` access so the type is safely `Sendable`.
- Narrow package-only streaming and prompt-processing helpers out of the public semver surface.

## [1.0.5] - 2026-04-16

### Added

- `apfel(1)` man page with drift-prevention (#103).

## [1.0.4] - 2026-04-15

### Added

- Scripting-language guides for Python, Node.js, Ruby, PHP, Bash, Zsh, AppleScript, Swift, Perl, and AWK.

### Fixed

- Gate streaming usage chunk on `stream_options.include_usage`.
- Strip markdown fence from `json_object` output.

## [1.0.3] - 2026-04-15

### Changed

- Extract pure modules from `Handlers.swift`; add unit tests (#98).

## [1.0.2] - 2026-04-14

### Added

- PR auto-review routine with hard guardrails (#89).
- Automate nixpkgs version bumps (#86).

### Fixed

- `make install` creates missing `PREFIX/bin`, build cache stable (#84, #83).

### Changed

- Extract pure `SchemaIR` + `SchemaParser` from `SchemaConverter` (#94).

## [1.0.1] - 2026-04-12

### Added

- `make test` - single command for all tests.

### Fixed

- Read piped stdin in `--stream` mode (#82).
- Harden release process and `make install` PATH handling.

## [1.0.0] - 2026-04-12

First stable release. CLI flags, exit codes, API endpoints, and response schemas are now semver-protected (see [STABILITY.md](STABILITY.md)).

### Added

- Stable release contract under semantic versioning.
- Full release qualification gate (362 unit + 157 integration tests).
- Security policy ([SECURITY.md](SECURITY.md)).
- `brew install apfel` via homebrew-core.

---

For pre-1.0 release history, see [https://github.com/Arthur-Ficial/apfel/releases](https://github.com/Arthur-Ficial/apfel/releases).
