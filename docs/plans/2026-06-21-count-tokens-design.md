# Design: `apfel --count-tokens`

**Status:** Draft — pending maintainer review via GitHub issue  
**Author:** Contributor design session (super-brainstorm)  
**Date:** 2026-06-21

## Summary

Add `apfel --count-tokens`, a zero-inference CLI mode that reports how many tokens a prompt would consume before calling the on-device model. This addresses the project's central constraint — the 4096-token context window — which users hit frequently when attaching files (`-f`) or MCP tool schemas (`--mcp`).

## Problem

Users discover context overflow only at inference time (`[context overflow]`, exit 4) or via chat-only `--context-status`. Shell scripters, integration authors (opencode, Zed, custom agents), and MCP users need a pipe-friendly preflight that answers: **"Will this fit?"**

## Success Criteria

- `apfel --count-tokens "prompt"` prints token count to stdout (plain or `-o json`)
- Supports the same input resolution as normal prompt mode: positional prompt, stdin pipe, `-f` / `--system-file`, `-s` / `--system`
- With `--mcp`, includes MCP tool-definition token cost in the breakdown (spawns MCP servers, same as inference)
- Exit 0 by default (informational); `--strict` exits 4 when `total > budget`
- Budget uses `--context-output-reserve` (default 512, same as inference via `ContextConfig.outputReserve`); `--max-tokens` does **not** affect preflight budget math
- When Apple Intelligence / model is unavailable, continues with chars/4 fallback and `"approximate": true` in JSON (requires availability-gate exemption — see Architecture)
- Documented in `docs/cli-reference.md`; cross-linked from `docs/tool-calling-guide.md`
- TDD: unit tests in ApfelCore + CLIArgumentsTests; integration coverage in `cli_e2e_test.py`

## Out of Scope

- Multi-turn chat history counting
- HTTP server endpoint (`/v1/...`)
- Embeddings, vision, or multi-model support
- Changing inference or context-trimming behavior

## Architecture

### Components

| Layer | Change |
|-------|--------|
| **ApfelCore** | New pure type `TokenBudgetReport` + aggregator for per-component sums and `fits` computation |
| **CLI parsing** | New `Mode.countTokens` + `--count-tokens` / `--strict` flags in `CLIArguments.swift`; reject conflicts with `--serve`, `--chat`, `--stream`, `--benchmark`; extend file storage to retain `(path, content)` pairs for JSON breakdown |
| **main.swift** | Add `.countTokens` to availability-gate exemption (alongside `.modelInfo`, `.serve`, `.update`) so preflight runs when model is unavailable; add `acceptsStdinInput: true` for countTokens mode |
| **CLI execution** | New `countTokens()` in `CLI.swift`; reuses existing prompt/system/file resolution |
| **MCP path** | When `--mcp` passed: init `MCPManager`, call `ContextManager.makeSession()` (same as `singlePrompt`), use returned `inputEntries` for accurate tool-schema counting |
| **No-MCP path** | Build entries via `makeSession` + `makePromptEntry`; count with `TokenCounter.shared.count(entries:)` |
| **Output** | Plain: human-readable summary; `-o json`: structured breakdown |

### Key Files

- `Sources/Core/TokenBudgetReport.swift` (new, pure ApfelCore)
- `Sources/CLI/CLIArguments.swift` (add `Mode.countTokens`, `fileAttachments: [(path: String, content: String)]`, `--strict`)
- `Sources/CLI.swift`
- `Sources/main.swift`
- `Tests/apfelTests/TokenBudgetTests.swift` (new)
- `Tests/apfelTests/CLIArgumentsTests.swift`
- `Tests/integration/cli_e2e_test.py`
- `docs/cli-reference.md`
- `docs/tool-calling-guide.md`

### Reused Infrastructure

- `TokenCounter.shared.count(entries:)` — real token counts (SDK 26.4+) with chars/4 fallback
- `TokenCounter.shared.inputBudget(reservedForOutput:)` — budget math
- `sessionInputEntries()` / `ContextManager.makeSession()` — accurate MCP tool schema counting (#176)
- Existing CLI input resolution and `-o json` output patterns

## Data Flow

1. Parse args → validate no conflicting modes
2. Resolve prompt, system prompt, and file attachments (existing helpers)
3. Optionally init MCP and discover tools
4. Build `inputEntries` (ContextManager path if MCP, simple path otherwise)
5. Count total and per-component tokens
6. Compute `budget = contextSize - contextConfig.outputReserve` (from `--context-output-reserve`, default 512)
7. Emit output; exit 0 (or 4 with `--strict` if `total > budget`)

## Token Accounting

**Authoritative total:** `total = TokenCounter.count(entries: inputEntries)` on the fully assembled entries that would be sent to inference — same assembly path as `singlePrompt`.

**Components are non-overlapping slices** (for breakdown only; they must not double-count):

| Field | What it counts |
|-------|----------------|
| `prompt_tokens` | Positional prompt + stdin content (stdin has no path; rolls into prompt, not `file_tokens`) |
| `system_tokens` | System instructions text only (`-s` / `--system-file`) |
| `file_tokens[]` | Each `-f` / `--system-file` attachment individually, keyed by retained path |
| `mcp_tool_tokens` | Delta: `count(inputEntries with MCP) - count(inputEntries without MCP tools)` using identical prompt/system/files |

Component sums may not exactly equal `total` due to assembly join separators (`\n\n` between files and prompt in `main.swift`); **`total` is always authoritative** for `fits` / `--strict`.

## Output Format

### JSON (`-o json`)

```json
{
  "prompt_tokens": 42,
  "system_tokens": 128,
  "file_tokens": [{"path": "README.md", "tokens": 890}],
  "mcp_tool_tokens": 340,
  "total": 1400,
  "budget": 3584,
  "output_reserve": 512,
  "fits": true,
  "approximate": false,
  "context_size": 4096
}
```

Note: `total` reflects full assembled `inputEntries`; component fields are informational slices.

### Plain

One-line summary to stdout. Optional per-component breakdown on stderr when not `--quiet`.

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Invalid flag combination | Exit 2 (existing CLI parse error pattern) |
| MCP spawn / discovery failure | Exit 1 with clear error message |
| Model unavailable | Continue with chars/4 fallback; `approximate: true`; note on stderr |
| `--strict` and over budget | Exit 4 |

## Testing Strategy (TDD)

1. **Red:** `TokenBudgetTests` — aggregation math, budget with/without `--context-output-reserve`, `fits` logic, component-vs-total non-overlap (pure, no Apple Intelligence)
2. **Red:** `CLIArgumentsTests` — `--count-tokens` / `--strict` happy path + conflicts with `--serve`/`--chat`/`--stream`; file path retention
3. **Green:** Implement `TokenBudgetReport` + `countTokens()` wiring
4. **Integration:** `cli_e2e_test.py` model-free validation of flag presence and JSON shape
5. **Local (Apple Intelligence Mac):** real count with `-f README.md` and `--mcp mcp/calculator/server.py`
6. **Gate:** `swift run apfel-tests` (CI) + `make test` (full local qualification)

## Backwards Compatibility

Additive CLI flag only. No API breakage. No changes to HTTP server or existing flag behavior.

## Risks

- **Fallback accuracy:** chars/4 on unavailable model is approximate — mitigated by `approximate` field and stderr note
- **MCP startup cost:** counting with `--mcp` spawns servers — acceptable for preflight; document in cli-reference
- **Per-file breakdown:** requires counting files individually in addition to combined total — small extra TokenCounter calls

## Documentation

- `docs/cli-reference.md` — new flag section with examples
- `docs/tool-calling-guide.md` — "preflight your budget" cross-link
- README Quick Start (UNIX section) — one example: `apfel --count-tokens -f README.md "summarize"`

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Exit code default | Informational (exit 0) | Pipe-friendly, composable UNIX tool |
| Strict mode | Opt-in `--strict` → exit 4 | CI/scripts opt in explicitly |
| Output reserve | `--context-output-reserve` (default 512) | Matches inference (`ContextManager` uses `contextConfig.outputReserve`, not `--max-tokens`) |
| `--max-tokens` in preflight | Does not affect budget | max-tokens caps generation length, not input budget reservation |
| Model unavailable | Graceful fallback + gate exemption | Useful in CI/docs; `.countTokens` exempt from availability precheck in `main.swift` |
| Token total | Authoritative `inputEntries` count | Components are informational slices; avoid double-counting merged file content |
| Contribution workflow | GitHub issue first | Standard OSS etiquette for new features |

## GitHub Issue Draft

**Title:** `feat(cli): apfel --count-tokens for token budget preflight`

**Body:**

> Preflight token counting for shell scripters and MCP users hitting the 4096-token wall.
>
> - `--count-tokens` with same inputs as prompt mode (stdin, `-f`, `-s`, `--mcp`)
> - `-o json` breakdown; `--strict` exits 4 when over budget
> - Budget: `contextSize - --context-output-reserve` (default 512), matching inference
> - Runs when model unavailable (chars/4 fallback, `approximate: true`)
>
> Full spec: `docs/plans/2026-06-21-count-tokens-design.md`
