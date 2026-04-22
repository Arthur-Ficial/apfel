# Release Process

## Overview

apfel uses semantic versioning. Releases are fully automated through the local `make release` workflow. Local builds (`make build`, `make install`) never change the version number.

## The release flow

```
make preflight              local qualification (git, build, tests, policy files)
       |
       v pass
make release [TYPE=]        run local release workflow
       |
       v on-device release machine
  bump .version
       |
  build release binary
       |
  unit tests
       |
  integration tests
       |
  commit + tag + push
       |
  package tarball + publish GitHub Release
       |
  update Homebrew tap formula
       |
       v
./scripts/post-release-verify.sh
```

## Before releasing

```bash
make preflight
```

The preflight script checks:
- Git working tree is clean
- On main branch, up to date with origin
- Release build succeeds
- Unit tests pass
- Integration tests pass
- SECURITY.md, STABILITY.md, LICENSE exist
- Binary version matches .version

Do not release if preflight fails.

Before cutting a release, review whether the branch changes the public `ApfelCore` Swift Package API.

- Additive `ApfelCore` API changes belong in [../CHANGELOG.md](../CHANGELOG.md) and require at least a minor bump.
- Deprecated or removed `ApfelCore` API changes belong in [../CHANGELOG.md](../CHANGELOG.md) and require the deprecation policy from [../STABILITY.md](../STABILITY.md) to be followed.
- Any removal or incompatible signature change to public `ApfelCore` API is a major release.

## Release commands

```bash
make release                    # patch bump (1.0.0 -> 1.0.1)
make release TYPE=minor         # minor bump (1.0.x -> 1.1.0)
make release TYPE=major         # major bump (1.x.y -> 2.0.0)
```

This runs locally via `scripts/publish-release.sh` (not on GitHub Actions - GitHub runners are Intel with no Apple Intelligence and cannot run the full test suite).

## What the release script does

1. Preflight checks (clean tree, on main, up to date with origin)
2. Bumps `.version` via `make release-patch` / `release-minor` / `release-major`
3. Builds the release binary
4. Runs all unit tests via `swift run apfel-tests`
5. Runs all integration tests discovered under `Tests/integration/` with real Apple Intelligence
6. Commits `.version`, `README.md`, `Sources/BuildInfo.swift`, tags, and pushes to main
7. Packages `apfel-<version>-arm64-macos.tar.gz`
8. Publishes GitHub Release with changelog and tarball
9. Updates the Homebrew tap formula (`Arthur-Ficial/homebrew-tap`)

Total time: ~5 minutes.

## After releasing

```bash
./scripts/post-release-verify.sh
```

Verifies: GitHub Release exists with tarball, git tag exists, .version matches, installed binary matches.

## Homebrew-core distribution

apfel is in [homebrew-core](https://github.com/Homebrew/homebrew-core). We do NOT maintain the formula directly.

```bash
brew install apfel
brew upgrade apfel
```

- Homebrew's autobump bot picks up new GitHub Releases automatically
- Emergency formula update: `brew bump-formula-pr apfel --url=<tarball-url> --sha256=<hash>`

The release workflow also updates the custom tap (`Arthur-Ficial/homebrew-tap`) as a secondary channel for apfel-family tools. The `HOMEBREW_TAP_PUSH_TOKEN` secret is required for tap updates.

## GitHub CI vs local testing

GitHub CI (`ci.yml`) runs on every push/PR as a safety net, but it is a **subset**:
- Unit tests that do not need Apple Intelligence
- Model-free integration checks such as flags, help, version, file handling, man-page drift, and ApfelCore packaging smoke tests

GitHub CI **cannot** run the full integration suite because GitHub-hosted `macos-26` runners are Intel Macs without Apple Intelligence. Full qualification runs locally on a Mac with Apple Intelligence via `make preflight` and `make release`. This local run is the real gate - no release ships without it.

## Distribution channels

Each release is published through three channels. All three pull the same signed tarball from the GitHub Release; nothing is rebuilt per-channel.

| Channel | How fresh | Mechanism |
|---------|-----------|-----------|
| [homebrew-core](https://github.com/Homebrew/homebrew-core/blob/master/Formula/a/apfel.rb) (`brew install apfel`) | Up to ~24h after release | Homebrew `autobump-PR` bot detects new GitHub Releases and opens a formula-bump PR. |
| [Arthur-Ficial/homebrew-tap](https://github.com/Arthur-Ficial/homebrew-tap) (`brew install Arthur-Ficial/tap/apfel`) | Synchronous with release | `scripts/publish-release.sh` pushes the new formula directly as part of `make release`. |
| [nixpkgs](https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/ap/apfel-ai) (`nix profile install nixpkgs#apfel-ai`) | Within ~5 min of release (Layer 2), or ~weekly (Layer 1) | Two layers: community [`r-ryantm`](https://github.com/ryantm/nixpkgs-update) bot (primary, ~weekly), plus our own [`bump-nixpkgs.yml`](.github/workflows/bump-nixpkgs.yml) workflow that opens a PR on every `release: published` event (fallback, minutes). See [nixpkgs.md](nixpkgs.md). |

All three channels are "owned" in the sense that we file PRs against them and respond to reviewer feedback - but merges into homebrew-core and nixpkgs are gated by their respective maintainer communities. The tap is the only channel where we merge directly.

## Versioning rules

apfel follows semver. See [STABILITY.md](../STABILITY.md) for the full stability policy.

- **PATCH** (1.0.x): bug fixes, documentation, CI improvements
- **MINOR** (1.x.0): new flags, new endpoints, backward-compatible features, additive public `ApfelCore` API
- **MAJOR** (x.0.0): removed flags, changed exit codes, breaking API changes, removed or incompatible public `ApfelCore` API

Model output changes from macOS updates are NOT version bumps.

## What triggers a release

- Bug fix merged -> patch
- New flag or endpoint merged -> minor
- Accumulation of small improvements -> patch
- Breaking change to CLI/API contract -> major (update STABILITY.md)

## What does NOT trigger a release

- Docs-only changes (commit to main, no release needed)
- CI/workflow changes (commit to main, no release needed)
- Test-only changes (commit to main, no release needed)

## What NOT to do

- Do not run `bump-patch`, `bump-minor`, `bump-major` directly
- Do not manually edit `.version`, `BuildInfo.swift`, or the README badge
- Do not create git tags manually
- Do not run `gh release create` manually
- Do not push to the Homebrew tap manually (the workflow handles it)
- Do not push to the nixpkgs fork manually (the `bump-nixpkgs.yml` workflow handles it)
- Do not run `make package-release-asset` outside the workflow
