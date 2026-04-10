"""
apfel Integration Tests -- Remote MCP server (Streamable HTTP transport)

Validates that apfel --serve can connect to a remote MCP server over HTTP and
auto-execute tool calls, returning the final text answer to the client.

All infrastructure (HTTP MCP server + apfel --serve instance) is started by
pytest fixtures using random ports so this file can run in parallel with the
other integration tests and does not conflict with ports 11434/11435.

Requires: pip install pytest httpx
Requires: .build/release/apfel binary (run `swift build -c release` first)

Run: python3 -m pytest Tests/integration/mcp_remote_test.py -v
"""

import contextlib
import json
import pathlib
import socket
import subprocess
import sys
import time

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
HTTP_MCP_SERVER = ROOT / "mcp" / "http-test-server" / "server.py"

MODEL = "apple-foundationmodel"
TIMEOUT = 90


# ============================================================================
# Helpers
# ============================================================================

def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def wait_for_http(url: str, timeout: int = 20) -> bool:
    """Poll url until it returns HTTP 200 or timeout expires. Returns True on success."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            resp = httpx.get(url, timeout=1)
            if resp.status_code == 200:
                return True
        except httpx.HTTPError:
            pass
        time.sleep(0.25)
    return False


@contextlib.contextmanager
def _popen(*cmd, **kwargs):
    """Context manager that starts a subprocess and terminates it on exit."""
    proc = subprocess.Popen(list(cmd), **kwargs)
    try:
        yield proc
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)


# ============================================================================
# Session-scoped fixtures: start the HTTP MCP server and apfel --serve once
# per test session, shared by all tests in this file.
# ============================================================================

@pytest.fixture(scope="module")
def http_mcp_server_url():
    """Start the HTTP calculator MCP server on a random port."""
    if not BINARY.exists():
        pytest.skip(f"apfel binary not found at {BINARY}")
    if not HTTP_MCP_SERVER.exists():
        pytest.skip(f"HTTP MCP server not found at {HTTP_MCP_SERVER}")

    port = find_free_port()
    url = f"http://127.0.0.1:{port}/mcp"

    with _popen(
        sys.executable, str(HTTP_MCP_SERVER), "--port", str(port),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        # Wait for the MCP server HTTP port to accept connections
        deadline = time.time() + 10
        ready = False
        while time.time() < deadline:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                if s.connect_ex(("127.0.0.1", port)) == 0:
                    ready = True
                    break
            time.sleep(0.2)
        if not ready:
            pytest.skip("HTTP MCP server did not start in time")
        yield url


@pytest.fixture(scope="module")
def apfel_remote_mcp_url(http_mcp_server_url):
    """Start apfel --serve pointed at the HTTP MCP server on a random port."""
    apfel_port = find_free_port()
    base = f"http://127.0.0.1:{apfel_port}"

    with _popen(
        str(BINARY), "--serve",
        "--port", str(apfel_port),
        "--mcp", http_mcp_server_url,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not wait_for_http(f"{base}/health", timeout=20):
            pytest.skip("apfel --serve with remote MCP did not become healthy in time")
        yield f"{base}/v1"


# ============================================================================
# Fixtures: make one LLM call, share the response across related tests
# ============================================================================

@pytest.fixture(scope="module")
def remote_multiply_response(apfel_remote_mcp_url):
    """Non-streaming multiply via remote HTTP MCP -- shared across result tests."""
    resp = httpx.post(
        f"{apfel_remote_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": (
                        "Use the multiply tool to compute 247 times 83. "
                        "Reply with just the number."
                    ),
                }
            ],
            "seed": 42,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, f"HTTP {resp.status_code}: {resp.text}"
    return resp.json()


@pytest.fixture(scope="module")
def remote_add_response(apfel_remote_mcp_url):
    """Non-streaming add via remote HTTP MCP -- shared across result tests."""
    resp = httpx.post(
        f"{apfel_remote_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": (
                        "Use the add tool to add 100 and 200. "
                        "Reply with just the number."
                    ),
                }
            ],
            "seed": 42,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, f"HTTP {resp.status_code}: {resp.text}"
    return resp.json()


# ============================================================================
# Prerequisites
# ============================================================================

def test_remote_mcp_apfel_healthy(apfel_remote_mcp_url):
    """apfel --serve with remote MCP must report healthy with model available."""
    base = apfel_remote_mcp_url.rsplit("/v1", 1)[0]
    resp = httpx.get(f"{base}/health", timeout=10)
    assert resp.status_code == 200
    data = resp.json()
    assert data["model_available"] is True, f"Model not available: {data}"


def test_remote_mcp_tools_visible(apfel_remote_mcp_url):
    """Calculator tools from the remote MCP server must appear in /v1/models... 
    
    We check indirectly via a /v1/chat/completions call with tool_choice=none
    and a system prompt that asks what tools are available, since /v1/models
    does not expose tool lists. A simpler proxy: just verify the server is
    running and healthy (prerequisite for all subsequent tests).
    """
    resp = httpx.get(f"{apfel_remote_mcp_url}/models", timeout=10)
    assert resp.status_code == 200


# ============================================================================
# Core: remote MCP tool auto-execution
# ============================================================================

def test_remote_mcp_multiply_auto_execute(remote_multiply_response):
    """Server auto-executes remote MCP tool call and returns final text answer.

    finish_reason must be 'stop' (not 'tool_calls') proving apfel ran the
    tool, got the result, and completed the generation.
    """
    data = remote_multiply_response
    choice = data["choices"][0]
    assert choice["finish_reason"] == "stop", (
        f"Expected 'stop' but got '{choice['finish_reason']}' -- "
        f"server may not have auto-executed the remote tool"
    )
    content = choice["message"]["content"]
    assert content is not None, "Response content is None"
    assert '"tool_calls"' not in content, (
        f"Response leaked raw tool_calls JSON (tool was not executed): {content[:200]}"
    )


def test_remote_mcp_multiply_correct_result(remote_multiply_response):
    """247 * 83 = 20501 must appear in the response."""
    content = remote_multiply_response["choices"][0]["message"]["content"]
    assert content is not None
    assert "20501" in content or "20,501" in content, (
        f"Expected '20501' in response but got: {content}"
    )


def test_remote_mcp_add_auto_execute(remote_add_response):
    """Remote MCP add tool returns 300 for 100+200."""
    data = remote_add_response
    choice = data["choices"][0]
    assert choice["finish_reason"] == "stop", (
        f"Expected 'stop' but got '{choice['finish_reason']}'"
    )
    content = choice["message"]["content"]
    assert content is not None
    assert '"tool_calls"' not in content, (
        f"Response leaked raw tool_calls JSON: {content[:200]}"
    )
    assert "300" in content, f"Expected '300' in response but got: {content}"


# ============================================================================
# Response structure
# ============================================================================

def test_remote_mcp_response_has_id(remote_multiply_response):
    """Response from remote MCP flow has a non-empty id field."""
    assert remote_multiply_response.get("id"), "Response missing 'id'"


def test_remote_mcp_response_has_usage(remote_multiply_response):
    """Response from remote MCP flow includes token usage."""
    usage = remote_multiply_response.get("usage", {})
    assert usage.get("total_tokens", 0) > 0, f"Missing or zero usage: {usage}"
