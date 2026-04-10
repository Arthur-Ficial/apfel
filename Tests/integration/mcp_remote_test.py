"""
apfel Integration Tests -- Remote MCP server (Streamable HTTP transport)

Tests: tool auto-execution, correct results, bearer auth, auth failure,
startup error cases, SSE streaming, and mixed local+remote MCP.

Run: python3 -m pytest Tests/integration/mcp_remote_test.py -v
Requires: pip install pytest httpx
Requires: swift build -c release (BINARY = .build/release/apfel)
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
STDIO_MCP_SERVER = ROOT / "mcp" / "calculator" / "server.py"

MODEL = "apple-foundationmodel"
TIMEOUT = 90


# ============================================================================
# Helpers
# ============================================================================


def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def wait_for_http(url, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if httpx.get(url, timeout=1).status_code == 200:
                return True
        except httpx.HTTPError:
            pass
        time.sleep(0.25)
    return False


@contextlib.contextmanager
def _popen(*cmd, **kwargs):
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


def _wait_for_port(port, timeout=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        with socket.socket() as s:
            s.settimeout(0.5)
            if s.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(0.2)
    return False


# ============================================================================
# Fixtures: HTTP MCP server (no auth) + apfel
# ============================================================================


@pytest.fixture(scope="module")
def http_mcp_port():
    """Start the HTTP calculator MCP server (no auth) on a random port."""
    if not BINARY.exists():
        pytest.skip(f"apfel binary not found at {BINARY}")
    if not HTTP_MCP_SERVER.exists():
        pytest.skip(f"HTTP MCP server not found at {HTTP_MCP_SERVER}")
    port = find_free_port()
    with _popen(
        sys.executable,
        str(HTTP_MCP_SERVER),
        "--port",
        str(port),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not _wait_for_port(port):
            pytest.skip("HTTP MCP server did not start in time")
        yield port


@pytest.fixture(scope="module")
def apfel_remote_mcp_url(http_mcp_port):
    """apfel --serve pointed at HTTP MCP (no auth)."""
    apfel_port = find_free_port()
    mcp_url = f"http://127.0.0.1:{http_mcp_port}/mcp"
    with _popen(
        str(BINARY),
        "--serve",
        "--port",
        str(apfel_port),
        "--mcp",
        mcp_url,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not wait_for_http(
            f"http://127.0.0.1:{apfel_port}/health", timeout=20
        ):
            pytest.skip("apfel with remote MCP did not become healthy")
        yield f"http://127.0.0.1:{apfel_port}/v1"


@pytest.fixture(scope="module")
def remote_multiply_response(apfel_remote_mcp_url):
    resp = httpx.post(
        f"{apfel_remote_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use the multiply tool to compute 247 times 83. Reply with just the number.",
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
    resp = httpx.post(
        f"{apfel_remote_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use the add tool to add 100 and 200. Reply with just the number.",
                }
            ],
            "seed": 42,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, f"HTTP {resp.status_code}: {resp.text}"
    return resp.json()


# ============================================================================
# Fixtures: auth-required MCP server
# ============================================================================


@pytest.fixture(scope="module")
def auth_mcp_port():
    """HTTP MCP server requiring Bearer token 'test-secret'."""
    if not HTTP_MCP_SERVER.exists():
        pytest.skip(f"HTTP MCP server not found at {HTTP_MCP_SERVER}")
    port = find_free_port()
    with _popen(
        sys.executable,
        str(HTTP_MCP_SERVER),
        "--port",
        str(port),
        "--token",
        "test-secret",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not _wait_for_port(port):
            pytest.skip("Auth MCP server did not start in time")
        yield port


@pytest.fixture(scope="module")
def apfel_auth_mcp_url(auth_mcp_port):
    """apfel --serve with auth-required MCP and correct token."""
    apfel_port = find_free_port()
    mcp_url = f"http://127.0.0.1:{auth_mcp_port}/mcp"
    with _popen(
        str(BINARY),
        "--serve",
        "--port",
        str(apfel_port),
        "--mcp",
        mcp_url,
        "--mcp-token",
        "test-secret",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not wait_for_http(
            f"http://127.0.0.1:{apfel_port}/health", timeout=20
        ):
            pytest.skip("apfel with auth MCP did not become healthy")
        yield f"http://127.0.0.1:{apfel_port}/v1"


# ============================================================================
# Fixtures: mixed local stdio + remote HTTP MCP
# ============================================================================


@pytest.fixture(scope="module")
def apfel_mixed_mcp_url(http_mcp_port):
    """apfel --serve with both local stdio calculator and remote HTTP calculator."""
    if not STDIO_MCP_SERVER.exists():
        pytest.skip(f"Stdio MCP server not found at {STDIO_MCP_SERVER}")
    apfel_port = find_free_port()
    mcp_url = f"http://127.0.0.1:{http_mcp_port}/mcp"
    with _popen(
        str(BINARY),
        "--serve",
        "--port",
        str(apfel_port),
        "--mcp",
        str(STDIO_MCP_SERVER),
        "--mcp",
        mcp_url,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ):
        if not wait_for_http(
            f"http://127.0.0.1:{apfel_port}/health", timeout=25
        ):
            pytest.skip("apfel with mixed MCP did not become healthy")
        yield f"http://127.0.0.1:{apfel_port}/v1"


# ============================================================================
# Tests: health checks
# ============================================================================


def test_remote_mcp_apfel_healthy(apfel_remote_mcp_url):
    base = apfel_remote_mcp_url.rsplit("/v1", 1)[0]
    resp = httpx.get(f"{base}/health", timeout=10)
    assert resp.status_code == 200
    assert resp.json()["model_available"] is True


def test_remote_mcp_models_endpoint(apfel_remote_mcp_url):
    resp = httpx.get(f"{apfel_remote_mcp_url}/models", timeout=10)
    assert resp.status_code == 200


# ============================================================================
# Tests: core tool auto-execution
# ============================================================================


def test_remote_mcp_multiply_finish_reason(remote_multiply_response):
    """finish_reason must be 'stop' - proves apfel ran the remote tool, not leaked it."""
    choice = remote_multiply_response["choices"][0]
    assert choice["finish_reason"] == "stop", (
        f"Got '{choice['finish_reason']}' - tool may not have executed"
    )
    content = choice["message"]["content"] or ""
    assert '"tool_calls"' not in content, "Response leaked raw tool_calls JSON"


def test_remote_mcp_multiply_correct_result(remote_multiply_response):
    """247 * 83 = 20501 must appear in the response."""
    content = remote_multiply_response["choices"][0]["message"]["content"]
    assert "20501" in content or "20,501" in content, (
        f"Expected '20501' in: {content}"
    )


def test_remote_mcp_add_finish_reason(remote_add_response):
    choice = remote_add_response["choices"][0]
    assert choice["finish_reason"] == "stop", f"Got '{choice['finish_reason']}'"
    content = choice["message"]["content"] or ""
    assert '"tool_calls"' not in content


def test_remote_mcp_add_correct_result(remote_add_response):
    """100 + 200 = 300."""
    content = remote_add_response["choices"][0]["message"]["content"]
    assert "300" in content, f"Expected '300' in: {content}"


# ============================================================================
# Tests: response structure
# ============================================================================


def test_remote_mcp_response_has_id(remote_multiply_response):
    assert remote_multiply_response.get("id"), "Response missing 'id'"


def test_remote_mcp_response_has_usage(remote_multiply_response):
    usage = remote_multiply_response.get("usage", {})
    assert usage.get("total_tokens", 0) > 0, f"Missing or zero usage: {usage}"


# ============================================================================
# Tests: streaming (SSE) with remote MCP
# ============================================================================


def test_remote_mcp_streaming_tool_auto_execute(apfel_remote_mcp_url):
    """Streaming SSE chat completions also auto-execute remote MCP tools."""
    chunks = []
    finish_reasons = []
    with httpx.stream(
        "POST",
        f"{apfel_remote_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use the multiply tool to compute 247 times 83. Reply with just the number.",
                }
            ],
            "stream": True,
        },
        timeout=TIMEOUT,
    ) as resp:
        assert resp.status_code == 200, f"HTTP {resp.status_code}: {resp.text[:200]}"
        for line in resp.iter_lines():
            if line.startswith("data: ") and line != "data: [DONE]":
                try:
                    data = json.loads(line[6:])
                    choices = data.get("choices") or []
                    if choices:
                        fr = choices[0].get("finish_reason")
                        if fr:
                            finish_reasons.append(fr)
                        delta = choices[0].get("delta", {}).get("content", "")
                        if delta:
                            chunks.append(delta)
                except (json.JSONDecodeError, KeyError, IndexError):
                    pass
    content = "".join(chunks)
    assert content, "No content in streaming response"
    assert "20501" in content or "20,501" in content, (
        f"Expected '20501' (247*83) in streamed response: {content}"
    )


# ============================================================================
# Tests: bearer token authentication (correct token)
# ============================================================================


def test_auth_mcp_apfel_healthy(apfel_auth_mcp_url):
    """apfel starts successfully with auth-required remote MCP + correct token."""
    base = apfel_auth_mcp_url.rsplit("/v1", 1)[0]
    resp = httpx.get(f"{base}/health", timeout=10)
    assert resp.status_code == 200
    assert resp.json()["model_available"] is True


def test_auth_mcp_tool_executes_correctly(apfel_auth_mcp_url):
    """With correct bearer token, remote MCP tool executes: 6 * 7 = 42."""
    resp = httpx.post(
        f"{apfel_auth_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use the multiply tool to compute 6 times 7. Just the number.",
                }
            ],
            "seed": 42,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200
    content = resp.json()["choices"][0]["message"]["content"]
    assert "42" in content, f"Expected '42' in: {content}"


# ============================================================================
# Tests: startup failure cases (subprocess.run, no long-running server needed)
# ============================================================================


def test_wrong_token_causes_startup_failure(auth_mcp_port):
    """apfel must exit non-zero at startup if bearer token is wrong (server returns 401)."""
    mcp_url = f"http://127.0.0.1:{auth_mcp_port}/mcp"
    result = subprocess.run(
        [
            str(BINARY),
            "--serve",
            "--port",
            str(find_free_port()),
            "--mcp",
            mcp_url,
            "--mcp-token",
            "wrong-token",
        ],
        capture_output=True,
        timeout=15,
    )
    assert result.returncode != 0, (
        f"Expected non-zero exit for wrong token\nstderr: {result.stderr}"
    )
    stderr = result.stderr.decode("utf-8", errors="replace")
    assert any(x in stderr for x in ["401", "failed", "HTTP", "MCP", "error"]), (
        f"Expected error indicator in stderr: {stderr[:500]}"
    )


def test_missing_token_against_auth_required_server_fails(auth_mcp_port):
    """apfel must exit non-zero if MCP server requires a token and none is provided."""
    mcp_url = f"http://127.0.0.1:{auth_mcp_port}/mcp"
    result = subprocess.run(
        [
            str(BINARY),
            "--serve",
            "--port",
            str(find_free_port()),
            "--mcp",
            mcp_url,
        ],
        capture_output=True,
        timeout=15,
    )
    assert result.returncode != 0, (
        f"Expected non-zero exit for missing token\nstderr: {result.stderr}"
    )


def test_http_with_bearer_token_is_refused():
    """apfel must refuse non-loopback http:// + --mcp-token (token would be sent in plaintext)."""
    # 192.0.2.1 is TEST-NET (RFC 5737) - non-routable, non-loopback, guaranteed to be refused.
    # The security check fires before any network call, so this exits immediately.
    result = subprocess.run(
        [
            str(BINARY),
            "--serve",
            "--port",
            str(find_free_port()),
            "--mcp",
            "http://192.0.2.1:8080/mcp",
            "--mcp-token",
            "mytoken",
        ],
        capture_output=True,
        timeout=10,
    )
    assert result.returncode != 0, (
        "Expected non-zero exit for http:// + --mcp-token"
    )
    stderr = result.stderr.decode("utf-8", errors="replace")
    assert any(
        x in stderr
        for x in ["plaintext", "http://", "https://", "credentials", "token"]
    ), f"Expected security message in stderr: {stderr[:500]}"


def test_unreachable_mcp_url_fails_gracefully():
    """apfel must exit non-zero (not hang) when remote MCP URL is unreachable."""
    result = subprocess.run(
        [
            str(BINARY),
            "--serve",
            "--port",
            str(find_free_port()),
            "--mcp",
            "http://127.0.0.1:19996/mcp",
        ],
        capture_output=True,
        timeout=20,
    )
    assert result.returncode != 0, (
        "Expected non-zero exit for unreachable MCP server"
    )


# ============================================================================
# Tests: mixed local stdio + remote HTTP MCP
# ============================================================================


def test_mixed_mcp_apfel_healthy(apfel_mixed_mcp_url):
    """apfel starts with both local stdio and remote HTTP MCP servers."""
    base = apfel_mixed_mcp_url.rsplit("/v1", 1)[0]
    resp = httpx.get(f"{base}/health", timeout=10)
    assert resp.status_code == 200
    assert resp.json()["model_available"] is True


def test_mixed_mcp_tool_executes(apfel_mixed_mcp_url):
    """With mixed local+remote MCP, a tool call executes successfully."""
    resp = httpx.post(
        f"{apfel_mixed_mcp_url}/chat/completions",
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": "Use the multiply tool to compute 12 times 12. Just the number.",
                }
            ],
            "seed": 42,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert "144" in content, f"Expected '144' (12*12) in: {content}"
