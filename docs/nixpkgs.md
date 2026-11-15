# nixpkgs distribution

apfel ships on [nixpkgs](https://github.com/NixOS/nixpkgs) under the attribute `apfel-llm`. This page covers the install, the name choice, and how new versions land upstream.

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

**PAUSED since 2026-11-15.** A nixpkgs maintainer closed the automated bump PR [NixOS/nixpkgs#565008](https://github.com/NixOS/nixpkgs/pull/565008) under the contributing guidelines (automated development, see [NixOS/nixpkgs#581542](https://github.com/NixOS/nixpkgs/issues/581542)). While the file `.nixpkgs-bump-paused` exists, `scripts/publish-nixpkgs-bump.sh` ends as `NIXPKGS_BUMP_STATUS=PAUSED` before any GitHub call, so neither `make release` nor the launchd job opens a PR; the launchd job `com.arthurficial.apfel-nixpkgs-bump` is also disabled on Arthur Mac (`launchctl enable gui/$(id -u)/com.arthurficial.apfel-nixpkgs-bump` to undo). Delete the file only after this is resolved with the nixpkgs maintainers.

**The pipeline: `make release` opens a build-verified bump PR on `NixOS/nixpkgs`; a nixpkgs committer merges it.** There is no zero-touch auto-merge for apfel-llm, and that is a hard architectural limit, not a gap we can close. Here is why, because it dictates everything else.

### Why r-ryantm and the merge bot cannot help (the darwin-only wall)

apfel-llm is `meta.platforms = [ "aarch64-darwin" ]`. The official nixpkgs update bot [`r-ryantm`](https://github.com/nix-community/nixpkgs-update) runs **only on `x86_64-linux`** and has no darwin workers, so it **refuses to evaluate** the package and **never opens a bump PR**. This is provable from the bot's own log for apfel-llm at [nixpkgs-update-logs.nix-community.org/apfel-llm](https://nixpkgs-update-logs.nix-community.org/apfel-llm/):

```
error: Refusing to evaluate package 'apfel-llm-1.5.5' because it is not
available on the requested hostPlatform:
  hostPlatform.system = "x86_64-linux"
  package.meta.platforms = [ "aarch64-darwin" ]
```

This is universal for darwin-only packages - raycast, aldente, and friends hit the exact same wall and get zero r-ryantm PRs. `passthru.updateScript` does not change it (the script runs, then the build-verify step fails on Linux).

Because r-ryantm never opens a PR, the [nixpkgs merge bot](https://github.com/NixOS/nixpkgs/blob/master/ci/README.md#nixpkgs-merge-bot) is also out of reach: it only merges PRs **"opened by r-ryantm or a committer"**. Being the package *maintainer* (not a *committer*) lets us *comment* the merge command, but it does **not** make a PR we open ourselves merge-bot-eligible. So the only mechanism that works is to open our own PR and wait for a committer to merge it.

> We were briefly listed in a "maintainer era = fully zero-touch via r-ryantm" plan ([#524394](https://github.com/NixOS/nixpkgs/pull/524394) added us as maintainer). That plan was wrong for a darwin-only package: r-ryantm can never fire, so a `scripts/nixpkgs-automerge.sh` that waited for an r-ryantm PR (and closed our own PRs in the meantime) just deadlocked nixpkgs at 1.0.5. That script has been deleted; the self-opened PR below is the permanent pipeline, not a legacy fallback.

### The pipeline (self-opened, build-verified PR)

1. **`make release`** runs `scripts/publish-nixpkgs-bump.sh` after the GitHub Release and Homebrew tap are updated. It forks `NixOS/nixpkgs` to `Arthur-Ficial/nixpkgs` (one-time), syncs from upstream master, edits `pkgs/by-name/ap/apfel-llm/package.nix`, **build-verifies the result with `nix-build -A apfel-llm` on this aarch64-darwin host** (r-ryantm cannot do this; we can, because the host matches `meta.platforms`), pushes, and opens/advances one PR on `NixOS/nixpkgs`. Idempotent at every layer (fork, branch, PR) and **non-fatal**: a bump failure does not fail the release. A failed `nix-build` aborts before any PR is opened, so we never submit a broken hash.
2. It runs **twice daily via launchd** (`~/Library/LaunchAgents/com.arthurficial.apfel-nixpkgs-bump.plist`, logs at `~/Library/Logs/apfel-nixpkgs-bump.log`) as a catch-up, keeping the single open PR pointed at the latest GitHub release even if a release run skipped the bump. The launchd job runs it through `scripts/nixpkgs-bump-cron.sh`, which classifies the outcome and emails Franz once per distinct failure - so a silent break (see "Recognizing the 2FA-compliance failure" below) can never again sit unnoticed.
3. The PR follows nixpkgs best practice: `apfel-llm: <old> -> <new>` commit/title, touches only `pkgs/by-name`, fills the **Things done** checklist with the real aarch64-darwin build, and carries an **automation/AI disclosure** per [CONTRIBUTING.md](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy). The bump commit carries **no `Assisted-by:` trailer** - a deterministic version+hash bump is exempt as standard update-script automation (the same exemption r-ryantm's own commits rely on).
4. A **nixpkgs committer merges it** when they get to it. We can only reduce friction (clean PR, green CI, maintained package); we cannot remove the wait.

### One advancing PR, not one per release

Each run reuses the existing open apfel-llm bump PR (it force-pushes the same branch, which updates that PR in place) and closes any stragglers, so there is always **exactly one** open bump PR pointing at the latest version. Earlier the branch name embedded the version (`apfel-llm-${VERSION}`), so every release opened a fresh PR and they piled up unmerged (1.3.5 / 1.3.6 / 1.3.7 / 1.3.8 were all open at once). The dedup is scoped to bump branches (`apfel-llm-bump` and `apfel-llm-<version>`); non-bump PRs such as `apfel-llm-add-maintainer` are never touched.

### Why nixpkgs lags

In the normal case the bump automation is not the bottleneck - it opens a correct, build-verified PR on every release. The lag is then **merge latency**: only nixpkgs committers can merge, and a maintainer-opened bump for a darwin-only package cannot use the merge bot (the "opened by r-ryantm or a committer" rule), so it sits in the committer queue for days to weeks. Being a maintainer helps a committer merge it faster but does not remove the wait, and no automation can - it is inherent to darwin-only + non-committer. Treat nixpkgs as the slower channel: Homebrew (`brew install apfel`, autobumped) and the [Arthur-Ficial tap](https://github.com/Arthur-Ficial/homebrew-tap) (pushed synchronously by `make release`) are the fast paths we fully control.

But "automation is not the bottleneck" only holds while the automation can actually reach GitHub. There is a second, nastier failure mode that once stranded nixpkgs at 1.0.5 for days while apfel shipped 1.6.0.

### Recognizing the 2FA-compliance failure

The NixOS org enforces secure-2FA-only. If the Arthur-Ficial GitHub account has an **SMS** 2FA factor configured, GitHub returns a 403 on **every** authenticated NixOS request - not just `gh pr create`, but **reads too** (`gh api repos/NixOS/nixpkgs`, and `gh pr list` silently returns empty). The bump then build-verifies fine, fails at PR creation, and - because the read is also blocked - even concludes no PR exists. The launchd job had no alerting, so it failed twice a day, silently, for days. Log signature:

```
GraphQL: `NixOS` requires everyone in the organization to enable two-factor
authentication ... Please remove SMS if configured as it is not considered secure.
```

**Fix:** remove the SMS factor (GitHub Settings -> Password and authentication -> SMS/Text message -> Disable). Authenticator-app TOTP stays the compliant anchor; recovery codes live in `pass show github/recovery-codes`. Details in `~/.claude/rules/services.md`.

This is now caught automatically: `scripts/publish-nixpkgs-bump.sh` probes one NixOS read up front and exits `AUTH_2FA`, and the launchd wrapper `scripts/nixpkgs-bump-cron.sh` emails Franz once per distinct failure instead of failing silently.

### Why the bump runs locally, not in GitHub Actions

We tried a release-triggered GitHub Actions workflow (`.github/workflows/bump-nixpkgs.yml`, ripped out in commit 77dd322) and it didn't work cleanly: opening a PR on `NixOS/nixpkgs` requires a classic PAT with `public_repo` scope, fine-grained tokens cannot do cross-org `createPullRequest`, and pushing to the fork's `.github/workflows/` requires extra `workflow` scope. That's a long-lived secret + scope expansion we didn't want.

`make release` already runs locally (GitHub-hosted runners lack Apple Intelligence). Locally we have an interactive `gh auth login` session for the Arthur-Ficial account with full cross-org PR scope. No stored credential, no workflow-scope hack - just call `gh` from the script.

## Running the bump on its own

```bash
./scripts/publish-nixpkgs-bump.sh                   # target = latest GitHub release
./scripts/publish-nixpkgs-bump.sh --version 1.3.3   # explicit (catch-up bumps)
./scripts/publish-nixpkgs-bump.sh --dry-run         # no fork/push/PR
```

Prerequisites: `nix` (for `nix-prefetch-url` and the `nix-build` verification), `gh` CLI logged into Arthur-Ficial, `python3`, `git`. The script verifies these and skips with a warning if anything is missing - it never blocks the release.

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
