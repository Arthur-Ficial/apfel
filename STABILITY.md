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
