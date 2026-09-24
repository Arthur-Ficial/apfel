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
swift run --build-system native apfel-tests

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
# APFEL_REQUIRE_FULL=1: any skipped test fails the release (#227) - a skip means a
# feature shipped unverified (the exact green-by-skip hole this closes).
# Two phases (#374): the model-free/parallel-safe partition first (cheap gates
# fail before any model time is spent; parallel when pytest-xdist is present),
# then the serial model phase. The marker expressions are complements: every
# test runs exactly once, all against the stamped release binary.
XDIST_ARGS=""
if python3 -c "import xdist" 2>/dev/null; then
    XDIST_ARGS="-n auto --dist loadfile"
fi
APFEL_REQUIRE_FULL=1 python3 -m pytest Tests/integration/ -m "not model and not serial" $XDIST_ARGS -v --tb=short
APFEL_REQUIRE_FULL=1 python3 -m pytest Tests/integration/ -m "model or serial" -v --tb=short

# Stop servers
kill "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" "$MCP_SERVER_PID" 2>/dev/null || true
SERVER_PID=""
MCP_SERVER_PID=""
trap - EXIT

# --- Sign the binary (#226) ---
# Signing and notarization run BEFORE the release commit/tag is pushed: they
# only need the built binary, and a signing/notarization failure must abort
# with zero published side effects (no stranded tag, no double version bump).
# Sign with the Developer ID identity under a hardened runtime BEFORE packaging
# so the tarred binary is the signed one. Signing lives here (not in
# package-release-asset) so plain `make build`/dev packaging never touches the
# keychain. On the release path signing is mandatory - a real release must not
# ship an ad-hoc binary.
step "Sign release binary"
security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)" \
    || fail "no 'Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)' signing identity found - cannot publish a signed release (#226)"
codesign --force --timestamp --options runtime \
    --sign "Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)" \
    ".build/release/apfel" \
    || fail "codesign failed - refusing to publish (#226)"
codesign --verify --strict ".build/release/apfel" || fail "codesign verification failed (#226)"

# --- Notarization hard gate (#226) ---
# Refuse to publish an ad-hoc-signed binary, and notarize the signed binary so
# Gatekeeper accepts non-brew downloads. A bare CLI binary cannot be stapled
# (stapler needs a bundle/dmg/pkg), so we notarize the submission and ship
# without a stapled ticket - Gatekeeper verifies notarization online.
sig=$(codesign -dvv ".build/release/apfel" 2>&1 || true)
echo "$sig" | grep -q "TeamIdentifier=7D2YX5DQ6M" || \
    fail "release binary is not Developer ID signed (need TeamIdentifier 7D2YX5DQ6M) - refusing to publish an ad-hoc release (#226)"
echo "$sig" | grep -q "flags=.*runtime" || \
    fail "release binary is not signed with the hardened runtime - notarization will reject it (#226)"

notarize_dir=$(mktemp -d)
mkdir -p "$notarize_dir/payload"
cp ".build/release/apfel" "$notarize_dir/payload/apfel"
COPYFILE_DISABLE=1 ditto -c -k "$notarize_dir/payload" "$notarize_dir/apfel-notarize.zip"
# Credentials: prefer explicit App Store Connect creds (works non-interactively,
# e.g. when the notarytool keychain profile lives in a locked keychain), else
# fall back to the documented "notarytool" keychain profile (see
# ~/dev/apple-dev-id/README.md). team-id defaults to Franz's team.
if [ -n "${APFEL_NOTARY_APPLE_ID:-}" ] && [ -n "${APFEL_NOTARY_PASSWORD:-}" ]; then
    xcrun notarytool submit "$notarize_dir/apfel-notarize.zip" \
        --apple-id "$APFEL_NOTARY_APPLE_ID" \
        --team-id "${APFEL_NOTARY_TEAM_ID:-7D2YX5DQ6M}" \
        --password "$APFEL_NOTARY_PASSWORD" --wait \
        || { rm -rf "$notarize_dir"; fail "notarization failed - refusing to publish (#226)."; }
else
    NOTARY_PROFILE="${APFEL_NOTARY_PROFILE:-notarytool}"
    xcrun notarytool submit "$notarize_dir/apfel-notarize.zip" \
        --keychain-profile "$NOTARY_PROFILE" --wait \
        || { rm -rf "$notarize_dir"; fail "notarization failed - refusing to publish (#226). Ensure the '$NOTARY_PROFILE' keychain profile exists (xcrun notarytool store-credentials) and its keychain is unlocked, or set APFEL_NOTARY_APPLE_ID / APFEL_NOTARY_PASSWORD."; }
fi
rm -rf "$notarize_dir"

# --- Commit + tag + push ---
step "Commit and tag v$version"

# Stamp the accumulated [Unreleased] entries as this version so CHANGELOG.md
# stays current with every release (#201). Idempotent.
bash scripts/stamp-changelog.sh "$version"

# Re-stamp the docs/EXAMPLES.md header with the version being released (#332).
# The doc is regenerated from the *installed* binary before the bump, so its
# stamp is otherwise permanently one version behind the tag that ships it.
# Outputs are unaffected by a version bump, so only the header line changes;
# the macOS/chip/date parts of the stamp are preserved. Idempotent.
sed -i '' -E "1,10s/^> apfel v[0-9]+\.[0-9]+\.[0-9]+ \|/> apfel v$version |/" docs/EXAMPLES.md

git add .version README.md Sources/BuildInfo.swift CHANGELOG.md docs/EXAMPLES.md
git commit -m "release v$version"
git tag -a "v$version" -m "v$version"
git push origin HEAD:main
git push origin "v$version"

# --- Package + publish GitHub Release ---
step "Publish GitHub Release"

asset=$(make package-release-asset | tail -1)

# Checksum sidecar, published as a second release asset so a swapped tarball is
# detectable independently of the Homebrew formula (#226).
shasum -a 256 "$asset" > "$asset.sha256"
sha256=$(awk '{print $1}' "$asset.sha256")
echo "Asset: $asset"
echo "SHA256: $sha256"
echo "Checksum asset: $asset.sha256"

prev_tag=$(git tag --sort=-v:refname | grep -Fxv "v$version" | head -1)
notes="## What's Changed"$'\n\n'
if [ -n "$prev_tag" ]; then
    notes+=$(git log --oneline "$prev_tag"..HEAD~1 -- | sed 's/^/- /')
fi
notes+=$'\n\n'"---"$'\n'
notes+="Install: \`brew install apfel\`"$'\n'
notes+="Upgrade: \`brew upgrade apfel\`"

if gh release view "v$version" --repo Arthur-Ficial/apfel >/dev/null 2>&1; then
    gh release upload "v$version" "$asset" "$asset.sha256" --clobber --repo Arthur-Ficial/apfel
else
    gh release create "v$version" "$asset" "$asset.sha256" \
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

# --- Bump nixpkgs (non-fatal) ---
# Runs locally so we can use the active gh CLI session for cross-org PR creation.
# A failure here does NOT fail the release - the GitHub Release + tap are already done.
step "Bump nixpkgs (non-fatal)"
set +e
./scripts/publish-nixpkgs-bump.sh --version "$version"
bump_rc=$?
set -e
if [ "$bump_rc" -ne 0 ]; then
    echo "WARN: nixpkgs bump failed (rc=$bump_rc). Release is still good."
    echo "      Run manually: ./scripts/publish-nixpkgs-bump.sh --version $version"
fi

# --- Done ---
step "Release v$version complete"
echo ""
echo "  GitHub Release: https://github.com/Arthur-Ficial/apfel/releases/tag/v$version"
echo "  Homebrew tap:   updated"
echo "  homebrew-core:  autobump will pick this up within ~24h"
echo "  nixpkgs:        PR opened (or warning above)"
echo ""
echo "  Verify: ./scripts/post-release-verify.sh $version"
