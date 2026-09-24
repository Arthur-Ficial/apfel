#!/usr/bin/env bash
# Pre-release qualification for apfel.
# Run this before `make release` to verify everything is green locally.
#
# Default is the LIGHT preflight (#374): build + unit tests + the parallel
# model-free integration phase (-m "not model and not serial") + policy
# checks - a fast go/no-go in ~3 min. The full model suite is NOT skipped:
# publish-release.sh runs every test against the stamped release binary, so
# each release still executes the complete suite exactly once.
#
# Pass --full (or make preflight FULL=1) to also run the serial model phase
# (-m "model or serial") here - the pre-#374 behavior, for qualifying without
# releasing.
#
# Usage: make preflight  OR  ./scripts/release-preflight.sh [--full]
set -euo pipefail

FULL=0
[ "${1:-}" = "--full" ] && FULL=1

PASS=0
FAIL=0
step() { echo ""; echo "=== $1 ==="; }
pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- 1. Working tree must be clean ---
step "Git status"
if git diff --quiet && git diff --cached --quiet; then
    pass "working tree clean"
else
    fail "uncommitted changes - commit or stash before releasing"
fi

# --- 2. On main branch ---
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]; then
    pass "on main branch"
else
    fail "on branch '$branch', expected 'main'"
fi

# --- 3. Up to date with origin ---
git fetch origin main --quiet
local_sha=$(git rev-parse HEAD)
remote_sha=$(git rev-parse origin/main)
if [ "$local_sha" = "$remote_sha" ]; then
    pass "up to date with origin/main"
else
    fail "local ($local_sha) differs from origin/main ($remote_sha) - pull or push first"
fi

# --- 4. Build succeeds (uses make so BuildInfo + man page regenerate) ---
step "Build"
if make build 2>&1 | tail -5; then
    pass "release build"
else
    fail "release build"
fi

# --- 4b. Man page exists and lints cleanly ---
step "Man page"
if [ -f .build/release/apfel.1 ]; then
    pass "man page generated"
else
    fail "man page missing at .build/release/apfel.1"
fi
if command -v mandoc >/dev/null 2>&1; then
    if mandoc -Tlint -W warning .build/release/apfel.1 >/tmp/mandoc.log 2>&1; then
        pass "mandoc -Tlint clean"
    else
        cat /tmp/mandoc.log
        fail "mandoc -Tlint warnings"
    fi
else
    echo "(skipping mandoc lint: mandoc not installed)"
fi

# --- 5. Unit tests ---
step "Unit tests"
if swift run --build-system native apfel-tests 2>&1; then
    pass "unit tests"
else
    fail "unit tests"
fi

# --- 6. Integration tests ---
step "Integration tests"

# Kill any leftover servers
pkill -f "apfel --serve" 2>/dev/null || true
sleep 1

# Check ports
for port in 11434 11435; do
    if lsof -iTCP:"$port" -sTCP:LISTEN -P -n 2>/dev/null | grep -q LISTEN; then
        fail "port $port in use - kill the process and retry"
    fi
done

# Start servers
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

# Wait for health
READY=0
for i in $(seq 1 15); do
    if curl -sf http://localhost:11434/health >/dev/null 2>&1 && \
       curl -sf http://localhost:11435/health >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    fail "servers did not start within 15s"
else
    # Directory discovery, not explicit lists - new test files are never
    # silently excluded. APFEL_REQUIRE_FULL=1: any skipped test fails the run
    # (#227). Two phases (#374): the cheap model-free/parallel-safe partition
    # first (so a doc-drift gate fails in seconds, not after 10 min of model
    # tests), then - only with --full - the serial model phase. The two marker
    # expressions are complements, so together they run every test exactly once.
    XDIST_ARGS=""
    if python3 -c "import xdist" 2>/dev/null; then
        XDIST_ARGS="-n auto --dist loadfile"
    fi
    if APFEL_REQUIRE_FULL=1 python3 -m pytest Tests/integration/ -m "not model and not serial" $XDIST_ARGS -v --tb=short -x 2>&1; then
        pass "integration tests (model-free phase)"
    else
        fail "integration tests (model-free phase)"
    fi
    if [ "$FULL" -eq 1 ]; then
        if APFEL_REQUIRE_FULL=1 python3 -m pytest Tests/integration/ -m "model or serial" -v --tb=short -x 2>&1; then
            pass "integration tests (model phase, --full)"
        else
            fail "integration tests (model phase, --full)"
        fi
    else
        echo "(light preflight: the model phase runs inside make release; use --full to run it here)"
    fi
fi

# --- 6b. CHANGELOG [Unreleased] discipline ---
# If there are commits since the last tag, the [Unreleased] section must have
# content - otherwise `make release` stamps a version under a blank heading
# (this happened for v1.6.1). Docs/test/CI-only commits are fine; the gate only
# fires when work has landed but nobody wrote a changelog entry. See #263.
step "CHANGELOG [Unreleased]"
last_tag=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -z "$last_tag" ]; then
    echo "(no version tags yet - skipping [Unreleased] content gate)"
elif [ "$(git rev-list "$last_tag"..HEAD --count)" -eq 0 ]; then
    pass "no commits since $last_tag - nothing to changelog"
else
    unreleased_content=$(awk '
      /^## \[Unreleased\]/ { insection = 1; next }
      insection && /^## / { exit }
      insection {
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /^### /) next
        print
      }
    ' CHANGELOG.md)
    if [ -n "$unreleased_content" ]; then
        pass "[Unreleased] has entries (commits since $last_tag)"
    else
        fail "$(git rev-list "$last_tag"..HEAD --count) commits since $last_tag but CHANGELOG.md [Unreleased] is empty - add an Added/Fixed/Changed entry (#263)"
    fi
fi

# --- 7. Required files exist ---
step "Policy files"
for f in SECURITY.md STABILITY.md LICENSE; do
    if [ -f "$f" ]; then
        pass "$f exists"
    else
        fail "$f missing"
    fi
done

# --- 8. Version sanity ---
step "Version check"
v=$(cat .version)
echo "Current version: $v"
binary_v=$(.build/release/apfel --version 2>&1 | head -1)
echo "Binary reports: $binary_v"
if echo "$binary_v" | grep -q "$v"; then
    pass "binary version matches .version"
else
    fail "binary version mismatch: .version=$v, binary=$binary_v"
fi

# --- Summary ---
step "Summary"
echo "$PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "RELEASE BLOCKED. Fix failures above before running make release."
    exit 1
else
    echo ""
    echo "ALL CHECKS PASSED. Safe to run:"
    echo "  make release                  # patch (x.y.z -> x.y.z+1)"
    echo "  make release TYPE=minor       # minor (x.y.z -> x.y+1.0)"
    echo "  make release TYPE=major       # major (x.y.z -> x+1.0.0)"
fi
