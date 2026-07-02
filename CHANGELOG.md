# Changelog

All notable changes to this project will be documented in this file.

The format is based on [https://keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [https://semver.org/](https://semver.org/).

## [Unreleased]

### Changed

- The tool-schema conversion cache (`SchemaConversionCache`) is now a bounded LRU: when full it evicts only the single least-recently-used entry instead of wiping all 64. Previously the 65th distinct tool set flushed the entire cache, so two alternating clients each with more than 32 distinct tool sets caused pathological full-cache churn. Backed by a new pure `LRUCache` in ApfelCore with unit coverage of eviction and the hot-entry-survives property (#247).

### Fixed

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
