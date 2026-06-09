# Changelog

All notable changes to this project will be documented in this file.

The format is based on [https://keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [https://semver.org/](https://semver.org/).

## [Unreleased]

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
