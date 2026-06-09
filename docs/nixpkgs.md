# nixpkgs distribution (discontinued)

> **The nixpkgs distribution channel was cancelled on 2026-06-09** per the deadline in [Arthur-Ficial/apfel#161](https://github.com/Arthur-Ficial/apfel/issues/161). The bootstrap conditions (maintainer PR merged, `@NixOS/nixpkgs-maintainers` membership, self-merge proven) were not met in time. Supported channels are **Homebrew core** (`brew install apfel`) and the **Arthur-Ficial tap** (`brew install Arthur-Ficial/tap/apfel`). The `nixpkgs#apfel-llm` package remains in nixpkgs as community-maintained; apfel no longer opens bump PRs or actively tracks it.

---

The historical documentation below is preserved for reference. It describes the setup as it existed before cancellation.

# nixpkgs distribution (historical)

apfel shipped on [nixpkgs](https://github.com/NixOS/nixpkgs) under the attribute `apfel-llm`. This page covers the install, the name choice, and how new versions landed upstream.

## Install (end users)

```bash
nix profile install nixpkgs#apfel-llm
```

Runtime requirements are the same as Homebrew: macOS 26 Tahoe or later, Apple Silicon, Apple Intelligence enabled, Siri language matching device language.

The binary on your `$PATH` is still `apfel` - only the install-time attribute is `apfel-llm`.

## Why `apfel-llm` and not `apfel`

nixpkgs already has an unrelated package at [`pkgs/by-name/ap/apfel`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ap/apfel/package.nix): the [scarrazza/apfel](https://github.com/scarrazza/apfel) particle-physics PDF Evolution Library (GPL3, maintained by `veprbl`). The name was taken years before apfel existed in its AI form, so nixpkgs convention requires disambiguation.

The disambiguator that landed upstream is `apfel-llm` (via [NixOS/nixpkgs#508084](https://github.com/NixOS/nixpkgs/pull/508084)). The binary on `$PATH` is still `apfel` either way - only the install attribute differs.

## Why a pre-built binary derivation

apfel links against Apple's [`FoundationModels`](https://developer.apple.com/documentation/foundationmodels) framework, which requires the macOS 26 SDK and Apple Silicon at build time. The nixpkgs darwin stdenv does not currently ship those prerequisites, so building from source inside a Nix sandbox is not reliably supported today.

The derivation installs the same signed release tarball that Homebrew consumes (`apfel-${version}-arm64-macos.tar.gz` attached to each GitHub Release), and declares `sourceProvenance = [ binaryNativeCode ]` to be honest about that.

If nixpkgs' darwin stdenv later gains macOS 26 SDK support, we switch to a source build in a follow-up PR.

## How new versions land

`make release` opens (or advances) a single nixpkgs PR automatically as its final step. r-ryantm and community contributors are the safety net.

In order:

1. **`make release`** runs `scripts/publish-nixpkgs-bump.sh` after the GitHub Release and Homebrew tap are updated. The script forks `NixOS/nixpkgs` to `Arthur-Ficial/nixpkgs` (one-time), syncs from upstream master, edits `pkgs/by-name/ap/apfel-llm/package.nix`, pushes, and opens a PR on `NixOS/nixpkgs`. Idempotent at every layer (fork, branch, PR), and **non-fatal**: a bump failure does not fail the release.
2. **[`r-ryantm`](https://github.com/ryantm/nixpkgs-update)** - the official nixpkgs update bot. Scans weekly via `passthru.updateScript = nix-update-script { }`. Picks up anything our local script missed (e.g. release on a machine without `gh` logged in). Latency: ~7 days.
3. **Community contributors** - anyone with a nixpkgs checkout can bump the version + hash if both above are slow.

### One advancing PR, not one per release

Each run reuses the existing open apfel-llm bump PR (it force-pushes the same branch, which updates that PR in place) and closes any stragglers, so there is always **exactly one** open bump PR pointing at the latest version. Earlier the branch name embedded the version (`apfel-llm-${VERSION}`), so every release opened a fresh PR and they piled up unmerged (1.3.5 / 1.3.6 / 1.3.7 / 1.3.8 were all open at once). The dedup is scoped to bump branches (`apfel-llm-bump` and `apfel-llm-<version>`); non-bump PRs such as `apfel-llm-add-maintainer` are never touched.

### Why nixpkgs lags, and how to merge faster

The bump automation is not the bottleneck - it opens a correct PR on every release. The lag is **merge latency**: only nixpkgs committers can merge, and a version bump for an unmaintained, darwin-only package sits in the general queue for days to weeks.

The fix is to be a listed maintainer of the package and self-merge via the merge bot:

1. `meta.maintainers` lists `arthurficial` (added in [NixOS/nixpkgs#524394](https://github.com/NixOS/nixpkgs/pull/524394)). A listed maintainer gets CC'd on r-ryantm bumps and gives committers a reason to prioritise.
2. Once a member of the `@NixOS/nixpkgs-maintainers` GitHub team, comment **`@NixOS/nixpkgs-merge-bot merge`** on any apfel-llm bump PR. The bot merges `pkgs/by-name/*` PRs for a maintainer of all touched packages once CI is green - no waiting for a random committer. See [nixpkgs ci/README.md](https://github.com/NixOS/nixpkgs/blob/master/ci/README.md#nixpkgs-merge-bot).

This only works when the PR touches **only** `pkgs/by-name/ap/apfel-llm/package.nix` (which our bump PRs do). Treat nixpkgs as the slower channel regardless: Homebrew (`brew install apfel`, autobumped) and the [Arthur-Ficial tap](https://github.com/Arthur-Ficial/homebrew-tap) (pushed synchronously by `make release`) are the fast paths we fully control.

### Why the bump runs locally, not in GitHub Actions

We tried a release-triggered GitHub Actions workflow (`.github/workflows/bump-nixpkgs.yml`, ripped out in commit 77dd322) and it didn't work cleanly: opening a PR on `NixOS/nixpkgs` requires a classic PAT with `public_repo` scope, fine-grained tokens cannot do cross-org `createPullRequest`, and pushing to the fork's `.github/workflows/` requires extra `workflow` scope. That's a long-lived secret + scope expansion we didn't want.

`make release` already runs locally (GitHub-hosted runners lack Apple Intelligence). Locally we have an interactive `gh auth login` session for the Arthur-Ficial account with full cross-org PR scope. No stored credential, no workflow-scope hack - just call `gh` from the script.

## Running the bump on its own

```bash
./scripts/publish-nixpkgs-bump.sh                   # uses .version
./scripts/publish-nixpkgs-bump.sh --version 1.3.3   # explicit (catch-up bumps)
./scripts/publish-nixpkgs-bump.sh --dry-run         # no fork/push/PR
```

Prerequisites: `nix` (for `nix-prefetch-url`), `gh` CLI logged into Arthur-Ficial, `python3`, `git`. The script verifies these and skips with a warning if anything is missing - it never blocks the release.

The fork `Arthur-Ficial/nixpkgs` is created on first run via `gh repo fork`. The local checkout lives at `~/dev/nixpkgs-bump` (override with `NIXPKGS_BUMP_DIR`).

## Manual self-bump (recovery, if the script breaks)

On any machine with `nix` and `git`:

```bash
git clone --depth 1 https://github.com/NixOS/nixpkgs.git /tmp/nixpkgs-bump
cd /tmp/nixpkgs-bump

# Fork NixOS/nixpkgs to your account first via the GitHub UI, then:
git remote add fork git@github.com:YOUR_USER/nixpkgs.git

VERSION="X.Y.Z"   # e.g. 1.3.4
URL="https://github.com/Arthur-Ficial/apfel/releases/download/v${VERSION}/apfel-${VERSION}-arm64-macos.tar.gz"
HASH=$(nix-prefetch-url --type sha256 "$URL" | xargs nix-hash --to-sri --type sha256)

git checkout -b "apfel-llm-${VERSION}"
sed -i.bak -E "s/version = \"[^\"]+\"/version = \"${VERSION}\"/; s|hash = \"sha256-[^\"]+\"|hash = \"${HASH}\"|" \
  pkgs/by-name/ap/apfel-llm/package.nix
rm pkgs/by-name/ap/apfel-llm/package.nix.bak

git add pkgs/by-name/ap/apfel-llm/package.nix
git commit -m "apfel-llm: ${VERSION}"
git push fork "apfel-llm-${VERSION}"

gh pr create --repo NixOS/nixpkgs \
  --head "YOUR_USER:apfel-llm-${VERSION}" \
  --base master \
  --title "apfel-llm: ${VERSION}" \
  --body "Routine version bump."
```

## Testing the package locally

```bash
git clone --depth 1 https://github.com/NixOS/nixpkgs.git /tmp/nixpkgs-test
cd /tmp/nixpkgs-test
nix-build -A apfel-llm --no-out-link

ls /nix/store/*-apfel-llm-*/bin/apfel
```

Run it: `/nix/store/...-apfel-llm-.../bin/apfel --version`.

## Tracking

- Package source: <https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ap/apfel-llm/package.nix>
- nixpkgs PRs: <https://github.com/NixOS/nixpkgs/pulls?q=is%3Apr+apfel-llm>
- r-ryantm PRs for apfel-llm: <https://github.com/NixOS/nixpkgs/pulls/r-ryantm?q=apfel-llm>
