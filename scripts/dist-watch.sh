#!/usr/bin/env bash
# dist-watch.sh - check whether apfel's distribution channels are in sync.
#
# Used by .claude/routines/04-dist-channel-watch.md as the deterministic
# layer. The routine becomes "run this script, post the output as an issue
# if non-empty". Also runnable standalone for ad-hoc checks.
#
# Exit / output contract:
#   exit 0, no stdout         -> in sync, or all lag covered by in-flight PRs
#   exit 0, markdown on stdout -> real lag, body for `gh issue create`
#   exit 0, "STILL: ..." on stdout -> a dist-sync issue is already open and
#                                     state hasn't changed; routine should
#                                     comment instead of opening a duplicate
#   exit non-zero             -> hard failure (network, missing tools)
#
# The script never opens issues, never edits formulae, never pushes anything.
# Distribution-channel side effects are reserved for Franz running the bump
# tooling locally.

set -euo pipefail

REPO_OWNER="Arthur-Ficial"
REPO_NAME="apfel"
REPO="${REPO_OWNER}/${REPO_NAME}"
GRACE_HOURS="${DIST_WATCH_GRACE_HOURS:-48}"

err() { echo "dist-watch: $*" >&2; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "missing required tool: $1"
    exit 2
  fi
}

need gh
need curl
need jq

# --- Step 1: canonical version + published-at from the latest GitHub Release.

release_json=$(gh release view --repo "$REPO" --json tagName,publishedAt,isDraft,isPrerelease 2>/dev/null) || {
  err "could not fetch latest release"
  exit 2
}

is_draft=$(jq -r '.isDraft'      <<<"$release_json")
is_prerel=$(jq -r '.isPrerelease' <<<"$release_json")
if [[ "$is_draft" == "true" || "$is_prerel" == "true" ]]; then
  # Pre-releases and drafts are off-limits for the sync check.
  exit 0
fi

canonical=$(jq -r '.tagName | sub("^v"; "")' <<<"$release_json")
published_at=$(jq -r '.publishedAt'           <<<"$release_json")

# Cross-platform epoch parse (macOS uses -j -u -f, GNU uses -d).
if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$published_at" +%s >/dev/null 2>&1; then
  published_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$published_at" +%s)
else
  published_epoch=$(date -u -d "$published_at" +%s)
fi
now_epoch=$(date -u +%s)
hours_since=$(( (now_epoch - published_epoch) / 3600 ))

if (( hours_since < GRACE_HOURS )); then
  # Release too fresh - autobumps haven't had a chance.
  exit 0
fi

# --- Step 2: current versions in the two downstream channels.

hb_raw=$(curl -sf "https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/a/apfel.rb" || true)
if [[ -z "$hb_raw" ]]; then
  err "could not fetch homebrew-core formula"
  exit 2
fi
hb_version=$(printf '%s\n' "$hb_raw" \
  | grep -E '^\s*url\s+"https://github\.com/Arthur-Ficial/apfel/archive/refs/tags/v' \
  | head -1 \
  | sed -E 's|.*/tags/v([0-9]+\.[0-9]+\.[0-9]+)\.tar\.gz.*|\1|')

if ! [[ "$hb_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  err "could not parse homebrew version (got: '$hb_version')"
  exit 2
fi

# --- Step 3: in-flight upstream bump PRs. Any open PR whose title contains
# the canonical version counts as "in flight, not lagging".

inflight_for() {
  # $1 = upstream repo (e.g. Homebrew/homebrew-core), $2 = title fragment to search,
  # $3 = canonical version we need the title to contain
  gh search prs --repo "$1" --state open "$2 in:title" \
    --json title --jq "[.[] | select(.title | contains(\"$3\"))] | length" 2>/dev/null || echo 0
}

hb_inflight=$( inflight_for "Homebrew/homebrew-core" "apfel"     "$canonical")

# --- Step 4: decide which channels are lagging (mismatch + no in-flight cover).

lagging=()
if [[ "$hb_version" != "$canonical" && "$hb_inflight" == "0" ]]; then
  lagging+=("homebrew-core")
fi

if (( ${#lagging[@]} == 0 )); then
  # All channels either match or have an upstream bump PR in queue. Nothing
  # for Franz to act on.
  exit 0
fi

# --- Step 5: de-dup against an existing open dist-sync issue.

existing_issue=$(gh issue list --repo "$REPO" --state open \
  --search "dist-sync in:title" \
  --json number,title \
  --jq ".[] | select(.title | contains(\"v$canonical\")) | .number" \
  2>/dev/null | head -1)

if [[ -n "$existing_issue" ]]; then
  # Same canonical version already tracked; routine should comment, not file
  # a duplicate.
  echo "STILL: dist-sync issue #${existing_issue} is still open at v${canonical}; lagging: ${lagging[*]}"
  exit 0
fi

# --- Step 6: emit the issue body. Routine pipes this into `gh issue create`.

lagging_joined=$(IFS=, ; echo "${lagging[*]}")
cat <<MARKDOWN
Routine check this morning - looks like ${lagging_joined//,/ and } trailing v${canonical}.

## State

| Channel | Current | Expected | Lag |
|---|---|---|---|
| GitHub Releases | v${canonical} | - | - |
| homebrew-core | v${hb_version} | v${canonical} | ~${hours_since}h |

## Fixing it (for you, not me)

**Homebrew-core:** normally autobumps within ~24h. If it is stuck, manually:

\`\`\`bash
brew bump-formula-pr apfel \\
  --url=https://github.com/Arthur-Ficial/apfel/releases/download/v${canonical}/apfel-${canonical}-arm64-macos.tar.gz
\`\`\`

## What I did NOT do

No bump PRs, no pushes, no formula edits. Routines never touch distribution channels - that's yours.

Cheers, Arthur
cc @franzenzenhofer
MARKDOWN
