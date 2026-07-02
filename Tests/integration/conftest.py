"""Shared fixtures for integration tests -- server lifecycle management."""
import os
import pathlib
import signal
import subprocess
import time

import httpx
import pytest


def is_guardrail_refusal(text):
    """Detect the on-device model's guardrail refusals.

    The macOS 26.5.2 model refuses prompts more aggressively than earlier
    versions. Known refusal shapes include ASCII apostrophe ("I'm sorry"),
    curly apostrophe (U+2019), "I can't", "I cannot provide", "Sorry, ..."
    with no lead-in, and variants with leading whitespace (#323, #324).
    """
    if not text:
        return False
    normalized = text.strip().replace("’", "'").lower()
    starts = ("i'm sorry", "sorry,", "sorry ", "i can't", "i cannot")
    if not any(normalized.startswith(s) for s in starts):
        return False
    keywords = ("cannot", "can't", "violates", "unable to", "not able to",
                "programming rules", "guidelines")
    return any(k in normalized for k in keywords)

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
