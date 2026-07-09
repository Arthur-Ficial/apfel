"""Shared fixtures for integration tests -- server lifecycle management."""
import os
import pathlib
import signal
import subprocess
import time

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
MCP_SERVER = ROOT / "mcp" / "calculator" / "server.py"
OPENAI_SPEC = pathlib.Path(__file__).parent / "openai_spec" / "openapi.yaml"


_MODEL_AVAILABLE = None


def model_available():
    """True when Apple Intelligence is enabled for generation (cached)."""
    global _MODEL_AVAILABLE
    if _MODEL_AVAILABLE is None:
        r = subprocess.run(
            [str(BINARY), "--model-info"],
            capture_output=True, text=True, timeout=20,
        )
        _MODEL_AVAILABLE = r.returncode == 0 and "available:  yes" in r.stdout.lower()
    return _MODEL_AVAILABLE


def require_model():
    """Shared model gate for every suite (single source, was duplicated per file).

    Marker discipline (#266): on a deliberately model-free run (CI sets
    APFEL_MODELFREE_ONLY=1 and selects `-m "not model"`), a model test should
    never reach this point - if it does, its @pytest.mark.model decorator is
    missing and it leaked past the filter. Fail loudly instead of skipping so
    the forgotten marker turns CI red rather than passing green-by-skip.
    """
    if model_available():
        return
    if os.environ.get("APFEL_MODELFREE_ONLY"):
        pytest.fail(
            "model test ran in a model-free selection (-m 'not model'); it is "
            "missing @pytest.mark.model"
        )
    pytest.skip("Apple Intelligence is not enabled for generation tests.")


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


# ============================================================================
# Guardrail-refusal handling (#320, #323, #324)
#
# The on-device model's guardrails fire on arbitrary benign prompts along
# specific sampling trajectories (macOS 26.5.2 made seed 42 a deterministic
# refusal for several prompts). The refusal arrives IN-BAND: normal content,
# finish_reason "stop", HTTP 200 - detectable only by its text. Tests that
# pin a seed and assert on content must rotate seeds past refusals; the
# property under test is apfel's behavior, not one seed's guardrail luck.
# Detection stays test-side by design - do NOT add refusal-sniffing to
# Sources/ (honesty principle: apfel must not editorialize model output).
# ============================================================================

GUARDRAIL_SEEDS = (42, 7, 123)


def is_guardrail_refusal(text):
    """True when content is an in-band guardrail refusal, not a real answer.

    Matches the observed refusal shapes loosely (curly or ASCII apostrophe,
    with or without the "I'm sorry" lead-in) because exact phrasing shifts
    between model releases (#320, #323, #324)."""
    if not text:
        return False
    lowered = text.strip().replace("’", "'").lower()
    starters = (
        "i'm sorry", "i am sorry", "sorry,",
        "i cannot", "i can't", "i won't",
    )
    markers = (
        "violates our guidelines", "against my guidelines",
        "cannot comply", "can't comply", "cannot respond to your request",
        "violation of my programming", "promotes or supports harm",
        "cannot provide an answer", "cannot assist with",
    )
    return lowered.startswith(starters) or any(m in lowered for m in markers)


def post_chat_rotating_seeds(url, payload, timeout, seeds=GUARDRAIL_SEEDS, accept=None):
    """POST a non-streaming chat completion, rotating seeds past guardrail
    refusals. Returns the parsed JSON of the first usable response; fails the
    test loudly if every seed refuses (that would be a real problem to see).

    `accept`: optional predicate(data) for callers whose notion of "usable"
    is stricter than non-refusal (e.g. tool_calls must be present)."""
    last_content = None
    for seed in seeds:
        body = dict(payload)
        body["seed"] = seed
        resp = httpx.post(url, json=body, timeout=timeout)
        assert resp.status_code == 200, \
            f"HTTP {resp.status_code} (seed {seed}): {resp.text[:200]}"
        data = resp.json()
        last_content = data["choices"][0]["message"].get("content")
        if is_guardrail_refusal(last_content or ""):
            continue
        if accept is not None and not accept(data):
            continue
        return data
    pytest.fail(
        f"model gave no usable answer on any seed {seeds}; last content: {last_content!r}")


def run_cli_rotating_seeds(run_cli, args, timeout, seeds=GUARDRAIL_SEEDS):
    """CLI twin of post_chat_rotating_seeds: run `apfel <args> --seed <s>`,
    rotating seeds past guardrail blocks (exit 3) and in-band refusals.
    Returns the first usable CompletedProcess; fails loudly if every seed
    refuses. Adopt per test on observed flake - the first was
    test_mcp_json_output_is_clean, guardrail-blocked on "What is 5 plus 5?"
    during the #374 verification run."""
    result = None
    for seed in seeds:
        # --seed goes FIRST: flags after the positional prompt are swallowed
        # into the prompt text (#255), which would make the rotation a no-op.
        result = run_cli(["--seed", str(seed), *args], timeout=timeout)
        if result.returncode == 3:
            continue
        if result.returncode == 0 and is_guardrail_refusal(result.stdout):
            continue
        return result
    pytest.fail(
        f"CLI gave no usable answer on any seed {seeds}; last: "
        f"exit={result.returncode} stderr={result.stderr[:200]!r}")


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
