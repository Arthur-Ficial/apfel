"""
apfel Integration Tests - BuildInfo.swift hygiene.

The `build` target must NOT depend on `generate-build-info` so that routine
local dev commands (`make build`, `make install`, `make test`) do not leave
Sources/BuildInfo.swift dirty with unrelated commit/date churn.

Only the release targets (`release-patch`, `release-minor`, `release-major`)
should regenerate build metadata.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
MAKEFILE = ROOT / "Makefile"


def _makefile_text() -> str:
    return MAKEFILE.read_text()


def _target_deps(text: str, target: str) -> list[str]:
    """Return the dependency list for a Makefile target line like 'target: dep1 dep2'."""
    pattern = rf"^{re.escape(target)}\s*:(.*?)$"
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        return []
    return match.group(1).split()


def test_build_target_does_not_depend_on_generate_build_info():
    """make build must not regenerate BuildInfo.swift - that is release-only."""
    text = _makefile_text()
    deps = _target_deps(text, "build")
    assert "generate-build-info" not in deps, (
        "The 'build' target depends on 'generate-build-info', which causes "
        "Sources/BuildInfo.swift to be rewritten on every build. "
        "This dependency should only exist on release targets."
    )


def test_release_targets_still_depend_on_generate_build_info():
    """release-patch/minor/major must regenerate BuildInfo.swift."""
    text = _makefile_text()
    for target in ("release-patch", "release-minor", "release-major"):
        deps = _target_deps(text, target)
        assert "generate-build-info" in deps, (
            f"The '{target}' target must depend on 'generate-build-info' "
            "so release builds get fresh commit/date metadata."
        )
