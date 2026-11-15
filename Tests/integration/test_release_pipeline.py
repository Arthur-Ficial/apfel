"""
apfel Integration Tests - release pipeline wiring (static, model-free).

These tests assert structural facts about the release scripts and CI so a
regression in the release plumbing is caught without cutting a real release.

Covered:
- #269: previous-tag selection must use a fixed-string, whole-line filter
  (`grep -Fxv`) so re-publishing vX.Y.Z when vX.Y.Z0+ exists does not filter
  those tags out of the release-notes commit range.
- #225: the divergent `workflow_dispatch` release path (publish-release.yml)
  must not exist - CLAUDE.md mandates local releases because GitHub-hosted
  runners lack Apple Intelligence, and the stale workflow could publish an
  unqualified release.
"""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
PUBLISH = ROOT / "scripts" / "publish-release.sh"


def test_prev_tag_uses_fixed_string_whole_line_filter():
    """#269: publish-release.sh must filter the current tag with grep -Fxv."""
    text = PUBLISH.read_text()
    assert 'grep -Fxv "v$version"' in text, (
        "publish-release.sh must select the previous tag with "
        "`grep -Fxv \"v$version\"` (fixed-string, whole-line) so re-publishing "
        "v1.6.1 does not also filter out v1.6.10+ (#269)"
    )
    # The unanchored substring form must be gone.
    assert 'grep -v "v$version"' not in text, (
        "publish-release.sh still uses the unanchored `grep -v \"v$version\"` "
        "which filters v1.6.10+ as substrings of v1.6.1 (#269)"
    )


def test_no_divergent_dispatch_release_workflow():
    """#225: the stale workflow_dispatch release path must be deleted."""
    stale = ROOT / ".github" / "workflows" / "publish-release.yml"
    assert not stale.exists(), (
        "'.github/workflows/publish-release.yml' is a divergent dispatch path "
        "that can publish an unqualified release (no server-readiness gate, no "
        "CHANGELOG stamp) on a runner without Apple "
        "Intelligence; CLAUDE.md mandates local releases only (#225)"
    )
