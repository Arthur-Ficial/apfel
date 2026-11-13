# Stability and Compatibility

## What "1.0" means for apfel

apfel 1.0 is a stable release of the CLI interface, HTTP API, and configuration surface. It does NOT guarantee deterministic model output.

## What is stable (semver-protected)

These are covered by semantic versioning. Breaking changes require a major version bump.

- CLI flags, exit codes, and output formats (`--json`, `--quiet`, `--stream`)
- OpenAI-compatible API endpoints and response schemas (`/v1/chat/completions`, `/v1/models`, `/health`)
- MCP tool calling interface (`--mcp`)
- `brew services` integration
- Configuration via environment variables (`APFEL_TOKEN`, `APFEL_MCP`, `APFEL_SYSTEM_PROMPT`)
- Documented unsupported endpoints (501 responses for embeddings, legacy completions)
- The public `ApfelCore` Swift Package API

`ApfelEngine` is a **preview** product: it follows apfel's version numbers, but its API may change in a MINOR release until it has a shipped consumer. Pin an exact version if you depend on it. Changes are always called out in [CHANGELOG.md](CHANGELOG.md).

### CLI exit-code catalogue

Each code keeps its meaning for the life of the major version and is never reused for something else. New codes take the next free number. Source of truth: `Sources/CLI/ExitCodes.swift`; documented in `man apfel` (EXIT STATUS) and [docs/cli-reference.md](docs/cli-reference.md).

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error |
| 2 | Usage error |
| 3 | Guardrail blocked / refusal |
| 4 | Context overflow |
| 5 | Model unavailable |
| 6 | Rate limited / busy |
| 7 | `--code`: no code in the response |
| 8 | `--require-complete`: response ended with `finish_reason=length` |
| 130 | Interrupted (Ctrl-C at the chat prompt) |

The `finish_reason` key in the CLI `-o json` envelope is additive and stable: `"stop"` or `"length"`, omitted for `--schema` output. Exit 8 reports how generation ended, not whether the answer is correct.

## What is NOT stable (may change without version bump)

- **Model output quality and content.** Apple controls the on-device model. macOS updates may change generation behavior, guardrail sensitivity, supported languages, and context window size. apfel cannot control this.
- **Model availability.** Apple may change hardware requirements or Apple Intelligence eligibility criteria.
- **Performance characteristics.** Token generation speed depends on hardware, thermal state, and OS scheduling.
- **Debug output format.** The `--debug` flag's stderr output is for human inspection and may change freely.

## Versioning

apfel follows semantic versioning:

- **PATCH** (1.0.x): bug fixes, documentation, CI changes
- **MINOR** (1.x.0): new flags, new endpoints, new features (backward-compatible)
- **MAJOR** (x.0.0): removed flags, changed exit codes, breaking API changes

`ApfelCore` follows the same version numbers as apfel itself. There is no separate library version line.

### Enum evolution

Public `ApfelCore` enums are non-frozen: new cases may be added in MINOR releases (for example, a new validation-failure or error case). Do not switch over them exhaustively - always include a `default` branch. Removing or changing an existing case remains a MAJOR change. CI enforces exactly this split: the API-breakage gate fails on removals and signature changes but permits added enum cases.

### Fix-supporting API in patch releases

New public `ApfelCore` API whose sole purpose is to support a bug fix - for example, a pure type extracted so the fix's decision logic is unit-testable - MAY ship in a PATCH release; the fix motivates the version, not the surface. New API that adds user-facing capability (new features, flags, or endpoints) requires at least a MINOR release. Precedent: v1.7.1 shipped `TokenCountFallback` in support of the #315 fix. The CI API-breakage gate only flags removals and signature changes, so shipping additive API in a patch is a deliberate release decision, not an accident the gate would catch.

## Deprecation Policy

- Public `ApfelCore` APIs deprecate before removal.
- A deprecation lands in one released version with `@available(*, deprecated, ...)`.
- The deprecated API remains available through the next compatible release line.
- Removal happens only in a major release.
- Public-surface changes must be called out in [CHANGELOG.md](CHANGELOG.md).

Model output changes from macOS updates are NOT version bumps. See "What is NOT stable" above.

## Our commitment

- We will document known behavioral changes from macOS updates in release notes.
- We will never silently change CLI semantics or API response structure.
- When Apple changes break apfel functionality, we will ship a compatibility fix as a patch release within one week.
- `apfel --model-info` always reports current model state honestly.
- Unsupported features are clearly documented and return proper HTTP 501 responses.
