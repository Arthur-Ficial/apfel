"""
apfel Integration Tests - Makefile hygiene.

BuildInfo.swift hygiene:
The `build` target must NOT depend on `generate-build-info` so that routine
local dev commands (`make build`, `make install`, `make test`) do not leave
Sources/BuildInfo.swift dirty with unrelated commit/date churn.

Only the release targets (`release-patch`, `release-minor`, `release-major`)
should regenerate build metadata.

Build-system hygiene (#194):
SwiftPM 6.4 changed the default --build-system from `native` to `swiftbuild`,
which fails under CLT-only environments. All `swift build` and `swift run`
invocations in the Makefile must include `--build-system native`.
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


def test_swift_build_calls_use_native_build_system():
    """Every swift build invocation must include --build-system native (#194).

    SwiftPM 6.4 changed the default from `native` to `swiftbuild`, which
    fails under CLT-only environments. Pinning `native` keeps `make install`
    working without Xcode.
    """
    text = _makefile_text()
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip("\t @-")
        if stripped.startswith("swift build"):
            assert "--build-system native" in line, (
                f"Makefile:{i}: `swift build` without `--build-system native` "
                "breaks CLT-only environments on SwiftPM 6.4+. "
                f"Line: {line.strip()}"
            )


def test_swift_run_calls_use_native_build_system():
    """Every swift run invocation must include --build-system native (#194)."""
    text = _makefile_text()
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip("\t @-")
        if stripped.startswith("swift run"):
            assert "--build-system native" in line, (
                f"Makefile:{i}: `swift run` without `--build-system native` "
                "breaks CLT-only environments on SwiftPM 6.4+. "
                f"Line: {line.strip()}"
            )
