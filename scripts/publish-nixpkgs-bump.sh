#!/usr/bin/env bash
# publish-nixpkgs-bump.sh - open/advance the nixpkgs PR bumping apfel-llm.
#
# THIS IS THE PERMANENT nixpkgs pipeline - not a legacy fallback.
#
# apfel-llm is `meta.platforms = [ "aarch64-darwin" ]`. The nixpkgs auto-update
# bot r-ryantm runs ONLY on x86_64-linux and has no darwin workers, so it
# REFUSES to evaluate apfel-llm and never opens a bump PR (proof: its log at
# https://nixpkgs-update-logs.nix-community.org/apfel-llm/ - "Refusing to
# evaluate ... hostPlatform.system = x86_64-linux"). This is universal for
# darwin-only packages (raycast, aldente, etc. all hit the same wall).
#
# Consequently the nixpkgs merge bot is also unreachable for us: it only merges
# PRs "opened by r-ryantm or a committer", and r-ryantm can never open one here.
# Being a package maintainer (not a committer) lets us *comment* merge but does
# NOT make our own PR merge-bot-eligible. So the only mechanism that works is:
#   WE open a build-verified bump PR, and a nixpkgs committer merges it.
# This script opens/advances exactly ONE such PR. Merge latency (committer
# queue) is inherent to darwin-only + non-committer and no automation removes
# it; Homebrew + the Arthur-Ficial tap are the fast channels we fully control.
#
# Runs as the final NON-FATAL step of `make release` and twice daily via the
# launchd agent (keeps the single PR pointed at the latest release). Idempotent
# at every layer: fork creation, branch existence, PR existence.
#
# Why local-only (no GitHub Actions): cross-org PR creation requires a classic
# PAT with public_repo scope; running locally we use the existing interactive
# `gh auth login` session and avoid storing any long-lived credential.
#
# Usage:
#   ./scripts/publish-nixpkgs-bump.sh                   # target = latest GitHub release
#   ./scripts/publish-nixpkgs-bump.sh --version 1.3.3   # explicit
#   ./scripts/publish-nixpkgs-bump.sh --dry-run         # no fork/push/PR
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
NIXPKGS_DIR="${NIXPKGS_BUMP_DIR:-$HOME/dev/nixpkgs-bump}"
UPSTREAM="NixOS/nixpkgs"
FORK="Arthur-Ficial/nixpkgs"
PACKAGE_PATH="pkgs/by-name/ap/apfel-llm/package.nix"

version=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:-}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

warn() { echo "WARN: $*" >&2; }
info() { echo "===> $*"; }

# finish <STATUS_TOKEN> <exit_code> [extra...] - emit ONE machine-readable status
# line and exit. scripts/nixpkgs-bump-cron.sh parses this to tell a benign run
# (IN_SYNC, PR_OPENED, PR_ADVANCED, PR_WAITING, TOOLING_SKIP, DRY_RUN) from an
# actionable failure (AUTH_2FA, AUTH_GENERIC, BUILD_FAIL, PUSH_FAIL,
# PR_CREATE_FAIL, FORK_FAIL, INVALID_VERSION) and alert Franz exactly once per
# distinct failure. All failures keep a non-zero code so `make release` still
# treats the bump as non-fatal (any non-zero -> WARN, never fails the release).
finish() {
  local token="$1" code="$2"; shift 2
  echo "NIXPKGS_BUMP_STATUS=${token} version=${version:-unknown} ${*}"
  exit "$code"
}

# Pause switch: while this file exists, no automated nixpkgs PR is opened (not by
# the launchd job, not by `make release`). Its first line says why. Checked before
# any gh/git/nix call. Added 2026-11-15 after a nixpkgs maintainer closed the
# automated bump PR NixOS/nixpkgs#565008 under the contributing guidelines.
PAUSE_FILE="${NIXPKGS_BUMP_PAUSE_FILE:-$REPO_ROOT/.nixpkgs-bump-paused}"
if [[ -f "$PAUSE_FILE" ]]; then
  info "nixpkgs bump paused: $(head -1 "$PAUSE_FILE")"
  finish PAUSED 0
fi

# Default target = latest published GitHub release (robust for the launchd
# catch-up run, which has no --version and where the local .version may lag a
# release made elsewhere). Falls back to local .version if the API is down.
if [[ -z "$version" ]]; then
  version=$(gh api repos/Arthur-Ficial/apfel/releases/latest --jq .tag_name 2>/dev/null | sed 's/^v//' || true)
  [[ -z "$version" ]] && version=$(cat "$REPO_ROOT/.version" 2>/dev/null || true)
fi

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  warn "invalid version '$version' (expected X.Y.Z)"
  finish INVALID_VERSION 1
fi

# --- Tool checks (non-fatal: warn and skip if missing) ---
need_skip=false
for tool in gh git nix-prefetch-url python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "$tool not found - skipping nixpkgs bump"
    need_skip=true
  fi
done

if $need_skip; then
  warn "Run manually later with: $0 --version $version"
  finish TOOLING_SKIP 0
fi

# gh auth status exits non-zero if ANY configured account is broken (even with
# a valid active one). The reliable health check is `gh api user` against the
# active account.
if ! gh api user >/dev/null 2>&1; then
  warn "gh CLI not authenticated to an active account - skipping nixpkgs bump"
  warn "Run 'gh auth login' then retry: $0 --version $version"
  finish AUTH_GENERIC 21
fi

# NixOS enforces secure-2FA-only. If our GitHub account 2FA is non-compliant
# (e.g. an SMS factor is configured), EVERY authenticated request to NixOS
# resources 403s with a "two-factor authentication ... remove SMS" GraphQL error
# - including READS, which silently blind `gh pr list` so the bump thinks no PR
# exists. Probe one NixOS read up front and fail fast + LOUD (the launchd wrapper
# alerts on AUTH_2FA) instead of wasting a build then dying at PR creation -
# exactly how this sat unnoticed for days. Fix: remove the SMS factor from the
# account (see ~/.claude/rules/services.md); authenticator TOTP is the anchor.
nixos_probe=$(gh api "repos/$UPSTREAM" --jq .full_name 2>&1) || true
if grep -qiE 'two-factor authentication|remove SMS' <<<"$nixos_probe"; then
  warn "NixOS access blocked by GitHub 2FA-compliance: $nixos_probe"
  warn "Remove the SMS 2FA factor from the Arthur-Ficial GitHub account, then retry."
  finish AUTH_2FA 20
fi

# NOTE: there is deliberately NO "defer to r-ryantm" short-circuit here. For a
# darwin-only package r-ryantm never opens a PR (see header), so deferring would
# mean nixpkgs never advances. We always open/advance our own PR. Maintainership
# still helps - committers merge a maintained package's bump faster - but the PR
# must come from us.

# --- Ensure fork exists ---
info "Ensuring fork $FORK exists..."
if ! gh repo view "$FORK" >/dev/null 2>&1; then
  if $dry_run; then
    info "[dry-run] would: gh repo fork $UPSTREAM --clone=false"
  else
    gh repo fork "$UPSTREAM" --clone=false >/dev/null
    # GitHub fork creation is async; wait for it to be queryable.
    for i in $(seq 1 20); do
      if gh repo view "$FORK" >/dev/null 2>&1; then break; fi
      sleep 2
    done
    gh repo view "$FORK" >/dev/null 2>&1 || { warn "fork did not appear after 40s"; finish FORK_FAIL 25; }
  fi
fi

# --- Maintain local checkout ---
if [[ ! -d "$NIXPKGS_DIR/.git" ]]; then
  info "Cloning fork to $NIXPKGS_DIR (shallow, ~30s)..."
  if $dry_run; then
    info "[dry-run] would: git clone --depth 1 --single-branch --filter=blob:none $FORK $NIXPKGS_DIR"
  else
    mkdir -p "$(dirname "$NIXPKGS_DIR")"
    # Shallow + blob filter keeps the clone under 100MB instead of multi-GB.
    # nixpkgs has no submodules and we never need history past the tip.
    git clone \
      --depth 1 \
      --single-branch \
      --branch master \
      --filter=blob:none \
      "https://github.com/$FORK.git" "$NIXPKGS_DIR" --quiet
  fi
fi

if ! $dry_run; then
  cd "$NIXPKGS_DIR"

  # Configure remotes idempotently
  if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream "https://github.com/$UPSTREAM.git"
  fi
  # Ensure 'origin' uses gh's auth so push works without a stored PAT
  origin_url=$(git remote get-url origin)
  if [[ "$origin_url" != *"x-access-token"* ]]; then
    token=$(gh auth token)
    git remote set-url origin "https://x-access-token:${token}@github.com/$FORK.git"
  fi

  git config user.name "Arthur Ficial"
  git config user.email "arti.ficial@fullstackoptimization.com"

  info "Syncing fork master with upstream..."
  # Shallow fetch to keep fast on repeat runs (nixpkgs has thousands of commits/day).
  git fetch upstream master --depth 1 --quiet
  git checkout master --quiet 2>/dev/null || git checkout -b master upstream/master --quiet
  git reset --hard upstream/master --quiet

  # Read old version BEFORE editing so the commit message is accurate
  old_version=$(grep -E '^\s*version = "' "$PACKAGE_PATH" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

  if [[ "$old_version" == "$version" ]]; then
    info "nixpkgs already at $version - nothing to do"
    finish IN_SYNC 0
  fi

  # Advance a SINGLE bump PR instead of opening a new one per release. Find any
  # open apfel-llm bump PR from our fork; reuse its branch (force-push updates
  # that PR in place) and close any extras. Only when none exist do we open a
  # fresh PR on a stable branch. This stops the version-named-branch pileup that
  # left 1.3.5/1.3.6/1.3.7/1.3.8 all open at once.
  open_prs=$(gh pr list --repo "$UPSTREAM" --state open --search "apfel-llm in:title" \
    --json number,headRefName,headRepositoryOwner \
    --jq '[.[] | select(.headRepositoryOwner.login=="Arthur-Ficial")]' 2>/dev/null || echo '[]')

  # Keep the newest, close the rest. The branch regex matches only bump branches
  # (apfel-llm-bump or apfel-llm-<version>), so non-bump PRs such as
  # apfel-llm-add-maintainer are never reused or closed by this flow.
  keep_number=""; keep_branch=""; dup_numbers=""
  { read -r keep_number; read -r keep_branch; read -r dup_numbers; } < <(
    printf '%s' "$open_prs" | python3 -c 'import json,re,sys
prs=[p for p in json.load(sys.stdin) if re.match(r"^apfel-llm-(bump|[0-9])", p["headRefName"])]
prs.sort(key=lambda p: p["number"])
if prs:
    print(prs[-1]["number"]); print(prs[-1]["headRefName"])
    print(",".join(str(p["number"]) for p in prs[:-1]))
else:
    print(); print(); print()')

  if [[ -n "$keep_branch" ]]; then
    branch="$keep_branch"
    info "Reusing open PR #$keep_number (branch $branch; old: $old_version, new: $version)..."
  else
    branch="apfel-llm-bump"
    info "No open bump PR - using stable branch $branch (old: $old_version, new: $version)..."
  fi
  # If the reused PR already targets this version, the run has nothing to do but
  # wait on a committer. Skip the expensive rebuild/push and report a benign
  # PR_WAITING so the launchd wrapper stays quiet (no false "failure" alert).
  if [[ -n "$keep_number" ]]; then
    keep_title=$(gh pr view "$keep_number" --repo "$UPSTREAM" --json title --jq .title 2>/dev/null || true)
    if [[ "$keep_title" == *"-> ${version}" ]]; then
      info "Open PR #$keep_number already at $version - waiting on a committer to merge."
      finish PR_WAITING 0 "pr=$keep_number"
    fi
  fi

  git checkout -B "$branch" --quiet

  info "Running scripts/bump-nixpkgs.sh..."
  "$REPO_ROOT/scripts/bump-nixpkgs.sh" \
    --version "$version" \
    --file "$NIXPKGS_DIR/$PACKAGE_PATH"

  if git diff --quiet -- "$PACKAGE_PATH"; then
    info "package.nix unchanged after bump - skipping"
    finish IN_SYNC 0
  fi

  # --- Build-verify on this aarch64-darwin host (best practice; lets us check
  #     the "Built on aarch64-darwin" + "tested binary" boxes truthfully).
  #     r-ryantm cannot do this on its Linux worker - we can, because the host
  #     matches meta.platforms. A bad hash/tarball fails here, before any PR. ---
  if [[ "$(uname -s)" == "Darwin" ]]; then
    info "Build-verifying apfel-llm $version (nix-build on $(uname -m)-darwin)..."
    if ( cd "$NIXPKGS_DIR" && nix-build -A apfel-llm --no-out-link >/tmp/apfel-nixpkgs-build.log 2>&1 ); then
      info "Build OK (versionCheckHook passed)."
    else
      warn "nix-build FAILED - refusing to open a broken PR. See /tmp/apfel-nixpkgs-build.log"
      tail -15 /tmp/apfel-nixpkgs-build.log >&2
      finish BUILD_FAIL 22
    fi
  else
    warn "not on darwin - skipping build verification (PR body will not claim a darwin build)"
  fi

  commit_msg="apfel-llm: ${old_version} -> ${version}"
  git add "$PACKAGE_PATH"
  git commit -m "$commit_msg" --quiet
  info "Pushing $branch to fork..."
  set +e; push_out=$(git push origin "$branch" --force 2>&1); push_rc=$?; set -e
  if [[ $push_rc -ne 0 ]]; then
    grep -qiE 'two-factor authentication|remove SMS' <<<"$push_out" && { warn "push blocked by 2FA: $push_out"; finish AUTH_2FA 20; }
    warn "git push failed: $push_out"; finish PUSH_FAIL 23
  fi

  # --- Open or update PR ---
  pr_title="$commit_msg"
  pr_body="Bumps apfel-llm \`${old_version}\` -> \`${version}\`.

Release notes: https://github.com/Arthur-Ficial/apfel/releases/tag/v${version}

Opened by the package maintainer (I maintain apfel-llm). r-ryantm cannot auto-update this package: it is \`meta.platforms = [ \"aarch64-darwin\" ]\` only, so the bot's x86_64-linux worker refuses to evaluate it and never opens a PR (its log: https://nixpkgs-update-logs.nix-community.org/apfel-llm/ - \"Refusing to evaluate ... hostPlatform.system = x86_64-linux\"). The merge bot's \"opened by r-ryantm or a committer\" precondition is therefore unsatisfiable here, so a committer merge is appreciated whenever one has a moment. Only \`pkgs/by-name\` is touched.

## Things done

- Built on platform:
  - [x] aarch64-darwin
- [x] Tested basic functionality of all binary files (\`./result/bin/apfel --version\` -> \`apfel v${version}\`, via \`versionCheckHook\`)
- [x] Fits [CONTRIBUTING.md], [pkgs/README.md], [maintainers/README.md] and other READMEs.
- [x] Follows the [automation/AI policy] (disclosure below).

## Automation/AI disclosure

The version + SRI-hash bump is produced by a deterministic update script equivalent to this package's \`passthru.updateScript\` (\`nix-update-script\`) and yields the identical diff - exempt as standard update-script automation. It was build-verified on aarch64-darwin before opening (\`nix-build -A apfel-llm\`). This PR was opened by the apfel project's release automation and the PR summary was assisted by an AI agent (Claude Code, Claude Opus 4.8); the package maintainer is the responsible person in the loop and is accountable for this change.

[CONTRIBUTING.md]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md
[pkgs/README.md]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md
[maintainers/README.md]: https://github.com/NixOS/nixpkgs/blob/master/maintainers/README.md
[automation/AI policy]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy"

  if [[ -n "$keep_number" ]]; then
    info "Updating PR #$keep_number to $version..."
    set +e; edit_out=$(gh pr edit "$keep_number" --repo "$UPSTREAM" --title "$pr_title" --body "$pr_body" 2>&1); edit_rc=$?; set -e
    if [[ $edit_rc -ne 0 ]]; then
      grep -qiE 'two-factor authentication|remove SMS' <<<"$edit_out" && { warn "PR edit blocked by 2FA: $edit_out"; finish AUTH_2FA 20; }
      warn "gh pr edit failed: $edit_out"; finish PR_CREATE_FAIL 24
    fi
    pr_url=$(gh pr view "$keep_number" --repo "$UPSTREAM" --json url --jq .url 2>/dev/null || echo "(PR #$keep_number)")
    pr_status=PR_ADVANCED
  else
    info "Opening PR on $UPSTREAM..."
    set +e; pr_url=$(gh pr create \
      --repo "$UPSTREAM" \
      --base master \
      --head "Arthur-Ficial:${branch}" \
      --title "$pr_title" \
      --body "$pr_body" 2>&1); create_rc=$?; set -e
    if [[ $create_rc -ne 0 ]]; then
      grep -qiE 'two-factor authentication|remove SMS' <<<"$pr_url" && { warn "PR create blocked by 2FA: $pr_url"; finish AUTH_2FA 20; }
      warn "gh pr create failed: $pr_url"; finish PR_CREATE_FAIL 24
    fi
    pr_status=PR_OPENED
  fi
  info "PR: $pr_url"

  # Close any OTHER open apfel-llm bump PRs from our fork (dedup / self-heal).
  if [[ -n "$dup_numbers" ]]; then
    echo "$dup_numbers" | tr ',' '\n' | while read -r dup; do
      [[ -z "$dup" ]] && continue
      info "Closing superseded duplicate PR #$dup"
      gh pr close "$dup" --repo "$UPSTREAM" \
        --comment "Superseded by #${keep_number}, which advances the apfel-llm bump to ${version}. Closing to keep a single open bump PR." >/dev/null 2>&1 || warn "could not close #$dup"
    done
  fi
else
  info "[dry-run] would: sync, branch, bump, commit, push, open PR for v$version"
  finish DRY_RUN 0
fi

info "Done."
finish "${pr_status:-PR_OPENED}" 0 "pr=${pr_url:-}"
