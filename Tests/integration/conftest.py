"""Shared fixtures for integration tests -- server lifecycle management."""
import os
import pathlib
import signal
import subprocess
import time

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def is_guardrail_refusal(text):
    """Detect the on-device model's in-band guardrail refusals.

    Handles ASCII and curly apostrophes (U+2019), leading whitespace,
    and common phrasings: "I'm sorry", "I can't", "Sorry, ...",
    "I cannot provide ...", "violates ... guidelines", etc.
    """
    lowered = text.strip().lower().replace("’", "'")
    if not lowered:
        return False
    starts = ("i'm sorry", "sorry,", "sorry ", "i apologize", "i cannot", "i can't")
    if any(lowered.startswith(s) for s in starts):
        return True
    has_sorry = "sorry" in lowered
    has_cannot = "cannot" in lowered or "can't" in lowered
    has_violates = "violates" in lowered or "guidelines" in lowered
    return (has_sorry and has_cannot) or (has_sorry and has_violates)


def post_with_seed_rotation(url, json_body, seeds=(42, 7, 123, 99), timeout=60):
    """POST with automatic seed rotation on guardrail refusals.

    Returns the response JSON for the first non-refused seed.
    Fails with pytest.fail if every seed is refused.
    """
    last_content = ""
    for seed in seeds:
        body = {**json_body, "seed": seed}
        resp = httpx.post(url, json=body, timeout=timeout)
        data = resp.json()
        content = (data.get("choices") or [{}])[0].get("message", {}).get("content") or ""
        if not is_guardrail_refusal(content):
            return data
        last_content = content
    pytest.fail(f"model guardrail-refused every seed; last: {last_content}")


BINARY = ROOT / ".build" / "release" / "apfel"
MCP_SERVER = ROOT / "mcp" / "calculator" / "server.py"
OPENAI_SPEC = pathlib.Path(__file__).parent / "openai_spec" / "openapi.yaml"


def pytest_sessionfinish(session, exitstatus):
    """Enforce the "never skip" rule during release qualification (#227).

    CLAUDE.md: "Never skip tests. A skipped test is a critical error." But
    pytest exits 0 when tests skip, and nothing checked the skip count - so a
    regression that prevents the server from starting (or any other broken-by-
    skip failure) turned the suite green-by-skip and let `make release` publish.

    When APFEL_REQUIRE_FULL=1 (exported by `make test`, release-preflight.sh, and
    publish-release.sh) any skipped test fails the whole session. In ordinary
    local/CI runs the variable is unset, so environment-gated skips still work.
    """
    if not os.environ.get("APFEL_REQUIRE_FULL"):
        return
    reporter = session.config.pluginmanager.get_plugin("terminalreporter")
    if reporter is None:
        return
    skipped = reporter.stats.get("skipped", [])
    if not skipped:
        return
    nodeids = sorted({rep.nodeid for rep in skipped})
    reporter.write_sep(
        "=", "APFEL_REQUIRE_FULL=1: skipped tests are forbidden", red=True
    )
    for nid in nodeids:
        reporter.write_line(f"  SKIPPED (forbidden under APFEL_REQUIRE_FULL): {nid}")
    session.exitstatus = 1


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
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
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
        # A server that will not start is a critical failure, never a skip (#227):
        # skipping here turned every server test green and let a startup-breaking
        # regression pass release qualification.
        pytest.fail("Could not start apfel server on port 11434")
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
        # See guard_server_11434: a non-starting server is a failure (#227).
        pytest.fail("Could not start apfel MCP server on port 11435")
        return

    yield

    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
