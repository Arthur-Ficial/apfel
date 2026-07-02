"""Shared fixtures for integration tests -- server lifecycle management."""
import os
import pathlib
import signal
import subprocess
import time

import httpx
import pytest


# ---------------------------------------------------------------------------
# Skip-as-failure gate (#227)
# When APFEL_REQUIRE_FULL=1, any skipped test fails the session. This
# prevents silent green-by-skip during release qualification: if a server
# did not start or Apple Intelligence is missing, pytest must exit non-zero
# so `make test` / `make release` abort instead of publishing.
# ---------------------------------------------------------------------------


def pytest_sessionfinish(session, exitstatus):
    """Fail the session when tests were skipped under APFEL_REQUIRE_FULL=1."""
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
    """Print which tests were skipped when APFEL_REQUIRE_FULL=1."""
    if os.environ.get("APFEL_REQUIRE_FULL") != "1":
        return
    skipped = terminalreporter.stats.get("skipped", [])
    if not skipped:
        return
    terminalreporter.section("APFEL_REQUIRE_FULL: skipped tests are failures")
    for report in skipped:
        terminalreporter.line(f"  SKIPPED: {report.nodeid}")
    terminalreporter.line(
        f"\n{len(skipped)} test(s) skipped. "
        "Release qualification requires 0 skips."
    )

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
MCP_SERVER = ROOT / "mcp" / "calculator" / "server.py"
OPENAI_SPEC = pathlib.Path(__file__).parent / "openai_spec" / "openapi.yaml"


@pytest.fixture(scope="session")
def openai_spec():
    """Load the vendored OpenAI API spec for conformance tests.

    The spec is committed at Tests/integration/openai_spec/openapi.yaml
    so tests are hermetic (no network fetch). Refresh it by re-downloading
    from https://github.com/openai/openai-openapi.
    """
    if not OPENAI_SPEC.exists():
        pytest.skip(f"OpenAI spec not found at {OPENAI_SPEC}")
    from openapi_core import Config, OpenAPI
    # The official OpenAI spec has internal inconsistencies (e.g. logprobs
    # enum default is [] instead of a string). Skip spec-level validation
    # since we care about response-level validation, not fixing their YAML.
    return OpenAPI.from_file_path(
        str(OPENAI_SPEC),
        config=Config(spec_validator_cls=None),
    )


def _server_alive(url: str) -> bool:
    try:
        resp = httpx.get(f"{url}/health", timeout=2)
        return resp.status_code == 200
    except httpx.HTTPError:
        return False


def _start_server(port, extra_args=None):
    """Start an apfel server on the given port. Returns the Popen object."""
    cmd = [str(BINARY), "--serve", "--port", str(port)]
    if extra_args:
        cmd.extend(extra_args)
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        return None
    # Wait for server to be ready
    url = f"http://127.0.0.1:{port}"
    for _ in range(20):  # 10 seconds max
        if proc.poll() is not None:
            # Process exited early -- server failed to start
            break
        if _server_alive(url):
            return proc
        time.sleep(0.5)
    # Failed to start
    proc.kill()
    proc.wait()
    return None


@pytest.fixture(scope="session", autouse=True)
def guard_server_11434():
    """Start apfel server on port 11434 if not already running, skip if impossible."""
    if _server_alive("http://127.0.0.1:11434"):
        yield
        return

    proc = _start_server(11434)
    if proc is None:
        pytest.skip("Could not start apfel server on port 11434")
        return

    yield

    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    """Start apfel MCP server on port 11435 if not already running, skip if impossible."""
    if _server_alive("http://127.0.0.1:11435"):
        yield
        return

    proc = _start_server(11435, ["--mcp", str(MCP_SERVER)])
    if proc is None:
        pytest.skip("Could not start apfel MCP server on port 11435")
        return

    yield

    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
