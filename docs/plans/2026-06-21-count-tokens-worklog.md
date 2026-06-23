# Work log: apfel --count-tokens

**Branch:** feat/count-tokens
**Design spec:** docs/plans/2026-06-21-count-tokens-design.md
**Status:** ready-for-pr

## Progress checklist
- [x] Wave 0: branch + baseline tests
- [x] Wave 1: TokenBudgetReport (ApfelCore)
- [x] Wave 2: CLI parsing
- [x] Wave 3: execution wiring
- [x] Wave 4: user-facing docs
- [x] Wave 5: integration tests
- [ ] Verification + PR (unit tests green; push/PR pending fork)

## Session log (append newest first)

### 2026-06-22 — Implementation complete
**Done:**
- `TokenBudgetReport` + `TokenBudgetTests` (ApfelCore)
- `Mode.countTokens`, `--strict`, `fileAttachments` in CLIArguments
- `countTokens()` in CLI.swift; main.swift dispatch + availability exemption
- `TokenCounter` fast chars/4 path when model unavailable
- Approximate path skips `LanguageModelSession` when AI unavailable
- Docs: cli-reference, tool-calling-guide, README, man/apfel.1.in
- Integration tests: help, JSON shape, strict exit

**Tests run:**
- `swift run apfel-tests` → pass (687 tests)
- `swift build -c release` → pass
- `make generate-man-page` → pass
- Release smoke test on Mac with Apple Intelligence: first `tokenCount` call can be slow (model load)

**Decisions / deviations from spec:**
- `TokenCounter.count` / `count(entries:)` return chars/4 immediately when `!isAvailable` (avoids hang without AI)
- Approximate mode totals merged prompt + system only (MCP delta skipped when unavailable)

**Blockers / next up:**
- Fork upstream and open PR

## Files touched (running list)
| File | Status | Notes |
|------|--------|-------|
| Sources/Core/TokenBudgetReport.swift | done | new |
| Tests/apfelTests/TokenBudgetTests.swift | done | new |
| Sources/CLI/CLIArguments.swift | done | Mode, strict, fileAttachments |
| Sources/CLI.swift | done | countTokens + help |
| Sources/main.swift | done | dispatch, pipedContent |
| Sources/Models.swift | done | TokenBudgetJSONResponse |
| Sources/TokenCounter.swift | done | unavailable fast path |
| Tests/apfelTests/CLIArgumentsTests.swift | done | |
| Tests/apfelTests/main.swift | done | |
| Tests/integration/cli_e2e_test.py | done | 3 tests |
| docs/cli-reference.md | done | |
| docs/tool-calling-guide.md | done | |
| README.md | done | one example |
| man/apfel.1.in | done | |
| docs/plans/* | done | spec + worklog |

## PR readiness
- [x] All waves complete
- [x] Unit tests green (687)
- [ ] Integration tests (pytest not installed locally; CI will run model-free subset)
- [x] Docs updated
- [x] Work log reflects final state
