"""
Tests for the APFEL_REQUIRE_FULL skip-enforcement hook (#227).

Release qualification must never silently pass when tests are skipped.
The conftest.py pytest_sessionfinish hook enforces this when
APFEL_REQUIRE_FULL=1 is set. These tests verify the hook's behavior
by running pytest in a subprocess with controlled skip scenarios.
"""

import os
import subprocess
import sys
import textwrap
import tempfile

import pytest


CONFTEST_PATH = os.path.join(os.path.dirname(__file__), "conftest.py")

HOOK_SOURCE = textwrap.dedent("""\
    import os

    def pytest_sessionfinish(session, exitstatus):
        if os.environ.get("APFEL_REQUIRE_FULL") != "1":
            return
        reporter = session.config.pluginmanager.get_plugin("terminalreporter")
        if reporter is None:
            return
        skipped = len(reporter.stats.get("skipped", []))
        if skipped > 0:
            session.exitstatus = 1
""")

SKIP_TEST = textwrap.dedent("""\
    import pytest
    def test_intentional_skip():
        pytest.skip("controlled skip for enforcement test")
""")

PASS_TEST = textwrap.dedent("""\
    def test_passes():
        assert True
""")


def _run_pytest_in_tmpdir(conftest_src, test_src, env_override=None, timeout=30):
    """Run pytest in a temp dir with the given conftest and test source."""
    with tempfile.TemporaryDirectory() as tmpdir:
        with open(os.path.join(tmpdir, "conftest.py"), "w") as f:
            f.write(conftest_src)
        with open(os.path.join(tmpdir, "test_target.py"), "w") as f:
            f.write(test_src)

        env = os.environ.copy()
        env.pop("APFEL_REQUIRE_FULL", None)
        if env_override:
            env.update(env_override)

        result = subprocess.run(
            [
                sys.executable, "-m", "pytest",
                os.path.join(tmpdir, "test_target.py"),
                "-v", "--no-header",
                "-p", "no:cacheprovider",
                "--override-ini=addopts=",
                "--rootdir", tmpdir,
                "-c", os.devnull,
            ],
            capture_output=True,
            text=True,
            env=env,
            cwd=tmpdir,
            timeout=timeout,
        )
        return result


def test_conftest_has_sessionfinish_hook():
    """The real conftest.py must define pytest_sessionfinish for skip enforcement."""
    with open(CONFTEST_PATH) as f:
        source = f.read()
    assert "def pytest_sessionfinish" in source, (
        "conftest.py must define pytest_sessionfinish hook for skip enforcement"
    )
    assert "APFEL_REQUIRE_FULL" in source, (
        "pytest_sessionfinish must check APFEL_REQUIRE_FULL env var"
    )


def test_enforcement_fails_on_skip_with_env_set():
    """With APFEL_REQUIRE_FULL=1, a skipped test must cause nonzero exit."""
    result = _run_pytest_in_tmpdir(
        HOOK_SOURCE, SKIP_TEST, env_override={"APFEL_REQUIRE_FULL": "1"}
    )
    assert result.returncode != 0, (
        f"Expected nonzero exit when APFEL_REQUIRE_FULL=1 and a test skipped.\n"
        f"stdout:\n{result.stdout[-500:]}\nstderr:\n{result.stderr[-500:]}"
    )


def test_enforcement_allows_skip_without_env():
    """Without APFEL_REQUIRE_FULL, a skipped test exits 0 (default pytest)."""
    result = _run_pytest_in_tmpdir(HOOK_SOURCE, SKIP_TEST)
    assert result.returncode == 0, (
        f"Expected exit 0 without APFEL_REQUIRE_FULL.\n"
        f"stdout:\n{result.stdout[-500:]}\nstderr:\n{result.stderr[-500:]}"
    )


def test_enforcement_passes_when_no_skips():
    """With APFEL_REQUIRE_FULL=1 but no skips, exit must be 0."""
    result = _run_pytest_in_tmpdir(
        HOOK_SOURCE, PASS_TEST, env_override={"APFEL_REQUIRE_FULL": "1"}
    )
    assert result.returncode == 0, (
        f"Expected exit 0 with APFEL_REQUIRE_FULL=1 but no skips.\n"
        f"stdout:\n{result.stdout[-500:]}\nstderr:\n{result.stderr[-500:]}"
    )
