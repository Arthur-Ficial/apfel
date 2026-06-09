#!/usr/bin/env bash
# Publish a release of apfel — runs locally with full test qualification.
#
# GitHub-hosted runners lack Apple Intelligence, so releases must run
# on a Mac with Apple Intelligence enabled. This script does everything
# the GitHub Actions workflow would do, but locally.
#
# Usage:
#   ./scripts/publish-release.sh patch    # 1.0.0 -> 1.0.1
#   ./scripts/publish-release.sh minor    # 1.0.x -> 1.1.0
#   ./scripts/publish-release.sh major    # 1.x.y -> 2.0.0
set -euo pipefail

TYPE="${1:-patch}"

step() { echo ""; echo "========================================"; echo "  $1"; echo "========================================"; }
fail() { echo "FATAL: $1"; exit 1; }

# --- Preflight ---
step "Preflight checks"

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || fail "not on main (on '$branch')"

git fetch origin main --quiet
local_sha=$(git rev-parse HEAD)
remote_sha=$(git rev-parse origin/main)
[ "$local_sha" = "$remote_sha" ] || fail "local differs from origin/main - pull or push first"

if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "uncommitted changes - commit or stash first"
fi

echo "PASS: on main, clean, up to date"

# --- Bump version + build ---
step "Bump version ($TYPE) and build"

case "$TYPE" in
    patch) make release-patch ;;
    minor) make release-minor ;;
    major) make release-major ;;
    *) fail "unknown type: $TYPE (use patch, minor, or major)" ;;
esac

version=$(cat .version)
echo "Version: $version"

# --- Unit tests ---
step "Unit tests"
swift run apfel-tests

# --- Integration tests (ALL 7 suites, full qualification) ---
step "Integration tests (full qualification)"

pkill -f "apfel --serve" 2>/dev/null || true
sleep 1

SERVER_PID=""
MCP_SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    [ -n "$MCP_SERVER_PID" ] && kill "$MCP_SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

.build/release/apfel --serve --port 11434 2>/dev/null &
SERVER_PID=$!
.build/release/apfel --serve --port 11435 --mcp mcp/calculator/server.py 2>/dev/null &
MCP_SERVER_PID=$!

READY=0
for i in $(seq 1 15); do
    if curl -sf http://localhost:11434/health >/dev/null 2>&1 && \
       curl -sf http://localhost:11435/health >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
done
[ "$READY" -eq 1 ] || fail "servers did not start within 15s"

# Run ALL integration test files — directory discovery, not explicit lists.
# This ensures new test files are never silently excluded from release qualification.
python3 -m pytest Tests/integration/ -v --tb=short

# Stop servers
kill "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
SERVER_PID=""
MCP_SERVER_PID=""
trap - EXIT

# --- Commit + tag + push ---
step "Commit and tag v$version"

git add .version README.md Sources/BuildInfo.swift
git commit -m "release v$version"
git tag -a "v$version" -m "v$version"
git push origin HEAD:main
git push origin "v$version"

# --- Package + publish GitHub Release ---
step "Publish GitHub Release"

asset=$(make package-release-asset | tail -1)
sha256=$(shasum -a 256 "$asset" | awk '{print $1}')
echo "Asset: $asset"
echo "SHA256: $sha256"

prev_tag=$(git tag --sort=-v:refname | grep -v "v$version" | head -1)
notes="## What's Changed"$'\n\n'
if [ -n "$prev_tag" ]; then
    notes+=$(git log --oneline "$prev_tag"..HEAD~1 -- | sed 's/^/- /')
fi
notes+=$'\n\n'"---"$'\n'
notes+="Install: \`brew install apfel\`"$'\n'
notes+="Upgrade: \`brew upgrade apfel\`"

if gh release view "v$version" --repo Arthur-Ficial/apfel >/dev/null 2>&1; then
    gh release upload "v$version" "$asset" --clobber --repo Arthur-Ficial/apfel
else
    gh release create "v$version" "$asset" \
        --title "v$version" \
        --notes "$notes" \
        --repo Arthur-Ficial/apfel
fi

# --- Update Homebrew tap ---
step "Update Homebrew tap"

TAP_DIR=$(mktemp -d)
git clone "https://x-access-token:$(gh auth token)@github.com/Arthur-Ficial/homebrew-tap.git" "$TAP_DIR" --quiet

make update-homebrew-formula \
    HOMEBREW_FORMULA_OUTPUT="$TAP_DIR/Formula/apfel.rb" \
    HOMEBREW_FORMULA_SHA256="$sha256"

cd "$TAP_DIR"
git config user.name "Arthur Ficial"
git config user.email "arti.ficial@fullstackoptimization.com"
if ! git diff --quiet -- Formula/apfel.rb; then
    git add Formula/apfel.rb
    git commit -m "apfel v$version"
    git push origin main
    echo "Tap updated to v$version"
else
    echo "Tap formula already up to date"
fi
cd -
rm -rf "$TAP_DIR"

# --- Done ---
step "Release v$version complete"
echo ""
echo "  GitHub Release: https://github.com/Arthur-Ficial/apfel/releases/tag/v$version"
echo "  Homebrew tap:   updated"
echo "  homebrew-core:  autobump will pick this up within ~24h"
echo ""
echo "  Verify: ./scripts/post-release-verify.sh $version"
