"""
Tests for the APFEL_REQUIRE_FULL=1 skip-as-failure gate (#227).

These run pytest as a subprocess with a trivial skip-only test file to verify
that the conftest.py hooks correctly fail the session when tests are skipped.
No apfel binary or Apple Intelligence needed - pure infrastructure tests.

The tests create a temporary conftest.py (mirroring the real one's hook) and
a temporary test file in /tmp, so they are fully self-contained and do not
trigger the integration directory's autouse server fixtures.
"""

import os
import pathlib
import subprocess
import sys
import textwrap

import pytest

_HOOK_CODE = textwrap.dedent("""\
    import os
    import pytest

    def pytest_sessionfinish(session, exitstatus):
        if os.environ.get("APFEL_REQUIRE_FULL") != "1":
            return
        reporter = session.config.pluginmanager.get_plugin("terminalreporter")
        if not reporter:
            return
        skipped = reporter.stats.get("skipped", [])
        if not skipped:
            return
        session.exitstatus = 1

    def pytest_terminal_summary(terminalreporter, exitstatus, config):
        if os.environ.get("APFEL_REQUIRE_FULL") != "1":
            return
        skipped = terminalreporter.stats.get("skipped", [])
        if not skipped:
            return
        terminalreporter.section("APFEL_REQUIRE_FULL: skipped tests are failures")
        for report in skipped:
            terminalreporter.line(f"  SKIPPED: {report.nodeid}")
        terminalreporter.line(
            f"\\n{len(skipped)} test(s) skipped. "
            "Release qualification requires 0 skips."
        )
""")

SCRATCH_DIR = pathlib.Path("/tmp/apfel-require-full-test")


def _run_pytest(test_code, *, require_full):
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)
    conftest = SCRATCH_DIR / "conftest.py"
    test_file = SCRATCH_DIR / "test_gate.py"
    conftest.write_text(_HOOK_CODE)
    test_file.write_text(textwrap.dedent(test_code))
    env = os.environ.copy()
    if require_full:
        env["APFEL_REQUIRE_FULL"] = "1"
    else:
        env.pop("APFEL_REQUIRE_FULL", None)
    return subprocess.run(
        [sys.executable, "-m", "pytest", str(test_file), "-v", "--tb=short"],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(SCRATCH_DIR),
        timeout=30,
    )


class TestRequireFullGate:
    """APFEL_REQUIRE_FULL=1 makes skipped tests fail the session."""

    def test_skip_with_require_full_exits_nonzero(self):
        result = _run_pytest(
            """\
            import pytest
            def test_always_skip():
                pytest.skip("deliberately skipped for gate test")
            """,
            require_full=True,
        )
        assert result.returncode != 0
        assert "skipped tests are failures" in result.stdout.lower()

    def test_skip_without_require_full_exits_zero(self):
        result = _run_pytest(
            """\
            import pytest
            def test_always_skip():
                pytest.skip("deliberately skipped for gate test")
            """,
            require_full=False,
        )
        assert result.returncode == 0

    def test_pass_with_require_full_exits_zero(self):
        result = _run_pytest(
            """\
            def test_always_pass():
                assert True
            """,
            require_full=True,
        )
        assert result.returncode == 0

    def test_fixture_skip_with_require_full_exits_nonzero(self):
        result = _run_pytest(
            """\
            import pytest

            @pytest.fixture(scope="session", autouse=True)
            def broken_server():
                pytest.skip("server did not start")

            def test_needs_server():
                assert True

            def test_also_needs_server():
                assert True
            """,
            require_full=True,
        )
        assert result.returncode != 0
        assert "2 test(s) skipped" in result.stdout
