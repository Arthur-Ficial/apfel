"""
apfel Integration Tests - Security (Origin Check & Token Auth)

Validates localhost CSRF protection and token authentication.
Requires: pip install pytest httpx
Requires: apfel --serve running on localhost:11434 (default config)
Additional flag-specific tests launch their own release-binary server instances.

Run: python3 -m pytest Tests/integration/security_test.py -v
"""

import contextlib
import os
import pathlib
import re
import socket
import subprocess
import tempfile
import time

import pytest
import httpx

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://localhost:11434"


def clean_env(extra_env=None):
    """Remove server env vars so each test controls its own configuration."""
    env = os.environ.copy()
    for key in ["APFEL_HOST", "APFEL_PORT", "APFEL_TOKEN"]:
        env.pop(key, None)
    if extra_env:
        env.update(extra_env)
    return env


def find_free_port():
    """Reserve an ephemeral localhost port for a spawned server."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for_server(base_url, timeout=20, expected_statuses=(200,)):
    """Poll /health until the spawned server is reachable."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            resp = httpx.get(f"{base_url}/health", timeout=1)
            if resp.status_code in expected_statuses:
                return
        except httpx.HTTPError:
            pass
        time.sleep(0.2)
    raise TimeoutError(f"Timed out waiting for server at {base_url}")


def read_log(log_path):
    return pathlib.Path(log_path).read_text(encoding="utf-8")


@contextlib.contextmanager
def running_server(*extra_args, env=None, port=None, bind_host="127.0.0.1", ready_statuses=(200,)):
    """Launch a dedicated release-binary server for non-default flag tests."""
    port = port or find_free_port()
    with tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8") as log_file:
        proc = subprocess.Popen(
            [
                str(BINARY),
                "--serve",
                "--host",
                bind_host,
                "--port",
                str(port),
                *extra_args,
            ],
            stdout=log_file,
            stderr=log_file,
            text=True,
            env=clean_env(env),
        )
        base_url = f"http://127.0.0.1:{port}"
        try:
            wait_for_server(base_url, expected_statuses=ready_statuses)
            log_file.flush()
            yield base_url, log_file.name
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
            log_file.flush()


@pytest.fixture(scope="module", autouse=True)
def ensure_default_server():
    """Use an existing default server or launch one for this test module."""
    try:
        resp = httpx.get(f"{BASE_URL}/health", timeout=1)
        if resp.status_code == 200:
            yield
            return
    except httpx.HTTPError:
        pass

    with running_server(port=11434):
        yield


# MARK: - Origin Check (default: localhost only)

def test_no_origin_header_allowed():
    """Request with no Origin header should pass (backward compat for curl/SDKs)."""
    resp = httpx.get(f"{BASE_URL}/health", timeout=10)
    assert resp.status_code == 200


def test_localhost_origin_allowed():
    """Request with http://localhost Origin should pass."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://localhost:3000"},
        timeout=10
    )
    assert resp.status_code == 200


def test_127_origin_allowed():
    """Request with http://127.0.0.1 Origin should pass."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://127.0.0.1:5173"},
        timeout=10
    )
    assert resp.status_code == 200


def test_ipv6_localhost_origin_allowed():
    """Request with http://[::1] Origin should pass."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://[::1]:8080"},
        timeout=10
    )
    assert resp.status_code == 200


def test_foreign_origin_rejected():
    """Request with non-localhost Origin should be rejected with 403."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://evil.com"},
        timeout=10
    )
    assert resp.status_code == 403
    data = resp.json()
    assert "error" in data
    assert "origin" in data["error"]["message"].lower() or "Origin" in data["error"]["message"]


def test_subdomain_attack_rejected():
    """http://localhost.evil.com must NOT match http://localhost."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://localhost.evil.com"},
        timeout=10
    )
    assert resp.status_code == 403


def test_foreign_origin_rejected_on_models():
    """Origin check applies to /v1/models too."""
    resp = httpx.get(
        f"{BASE_URL}/v1/models",
        headers={"Origin": "http://evil.com"},
        timeout=10
    )
    assert resp.status_code == 403


def test_foreign_origin_rejected_on_chat():
    """Origin check applies to /v1/chat/completions."""
    resp = httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        json={"model": "apple-foundationmodel", "messages": [{"role": "user", "content": "hi"}]},
        headers={"Origin": "http://evil.com"},
        timeout=60
    )
    assert resp.status_code == 403


def test_foreign_origin_rejected_on_logs():
    """Origin check applies to /v1/logs."""
    with running_server("--debug") as (base_url, _):
        resp = httpx.get(
            f"{base_url}/v1/logs",
            headers={"Origin": "http://evil.com"},
            timeout=10
        )
        assert resp.status_code == 403


def test_foreign_origin_rejected_on_stats():
    """Origin check applies to /v1/logs/stats."""
    with running_server("--debug") as (base_url, _):
        resp = httpx.get(
            f"{base_url}/v1/logs/stats",
            headers={"Origin": "http://evil.com"},
            timeout=10
        )
        assert resp.status_code == 403


# MARK: - CORS Headers (not enabled by default)

def test_no_cors_headers_by_default():
    """Without --cors, no Access-Control-Allow-Origin header."""
    resp = httpx.get(f"{BASE_URL}/health", timeout=10)
    assert "access-control-allow-origin" not in resp.headers


def test_options_no_cors_headers_by_default():
    """Without --cors, OPTIONS preflight returns no CORS headers."""
    resp = httpx.options(f"{BASE_URL}/v1/chat/completions", timeout=10)
    assert resp.status_code == 204
    assert "access-control-allow-origin" not in resp.headers


# MARK: - Error format

def test_origin_error_is_openai_format():
    """Origin rejection returns OpenAI-compatible error JSON."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Origin": "http://evil.com"},
        timeout=10
    )
    data = resp.json()
    assert "error" in data
    assert "message" in data["error"]
    assert "type" in data["error"]
    assert data["error"]["type"] == "forbidden"


def test_logs_endpoints_hidden_without_debug():
    """/v1/logs and /v1/logs/stats should not be exposed unless --debug is on."""
    with running_server() as (base_url, _):
        logs = httpx.get(f"{base_url}/v1/logs", timeout=10)
        stats = httpx.get(f"{base_url}/v1/logs/stats", timeout=10)
        assert logs.status_code == 404
        assert stats.status_code == 404


def test_logs_include_bodies_in_debug_mode():
    """--debug should explicitly opt into request/response body retention."""
    with running_server("--debug") as (base_url, _):
        resp = httpx.post(
            f"{base_url}/v1/chat/completions",
            content=b"{",
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        assert resp.status_code == 400

        logs = httpx.get(f"{base_url}/v1/logs?limit=1", timeout=10)
        assert logs.status_code == 200
        entry = logs.json()["data"][-1]
        assert entry["request_body"] == "{"
        assert entry["response_body"] is not None


def test_logs_limit_is_clamped_to_safe_positive_range():
    """Malformed negative limits should not crash the server."""
    with running_server("--debug") as (base_url, _):
        resp = httpx.get(f"{base_url}/v1/logs?limit=-5", timeout=10)
        assert resp.status_code == 200
        data = resp.json()
        assert "data" in data
        assert isinstance(data["data"], list)


# MARK: - Spawned server scenarios

def test_allowed_origins_adds_to_default_localhost_allowlist():
    """Custom allowed origins should be additive, not replace localhost defaults."""
    with running_server("--allowed-origins", "http://localhost:3000") as (base_url, _):
        localhost_resp = httpx.get(
            f"{base_url}/health",
            headers={"Origin": "http://localhost:3000"},
            timeout=10,
        )
        loopback_resp = httpx.get(
            f"{base_url}/health",
            headers={"Origin": "http://127.0.0.1:5173"},
            timeout=10,
        )
    assert localhost_resp.status_code == 200
    assert loopback_resp.status_code == 200


def test_explicit_token_not_echoed_in_startup_banner():
    """Configured secrets from --token must not be printed on startup."""
    secret = "super-secret-token"
    with running_server("--token", secret) as (_, log_path):
        banner = read_log(log_path)
    assert "token:    required" in banner
    assert secret not in banner


def test_env_token_not_echoed_in_startup_banner():
    """Configured secrets from APFEL_TOKEN must not be printed on startup."""
    secret = "env-secret-token"
    with running_server(env={"APFEL_TOKEN": secret}) as (_, log_path):
        banner = read_log(log_path)
    assert "token:    required" in banner
    assert secret not in banner


def test_token_auto_prints_generated_secret():
    """--token-auto should still surface the generated token for the operator."""
    with running_server("--token-auto") as (_, log_path):
        banner = read_log(log_path)
    assert "token:    required" in banner
    assert re.search(r"token: [0-9A-Fa-f-]{36}", banner)


def test_unauthorized_error_keeps_cors_for_allowed_origin():
    """Allowed browser origins must receive ACAO on 401 so auth failures are readable."""
    with running_server(
        "--cors",
        "--allowed-origins",
        "http://localhost:3000",
        "--token",
        "secret123",
    ) as (base_url, _):
        resp = httpx.get(
            f"{base_url}/v1/models",
            headers={"Origin": "http://localhost:3000"},
            timeout=10,
        )
    assert resp.status_code == 401
    assert resp.headers["access-control-allow-origin"] == "http://localhost:3000"
    assert resp.headers["vary"] == "Origin"
    assert resp.headers["www-authenticate"] == "Bearer"
    assert resp.json()["error"]["type"] == "authentication_error"


def test_health_requires_auth_on_non_loopback_token_protected_bind():
    """Network-exposed token-protected servers should not leak /health unauthenticated."""
    with running_server(
        "--token",
        "secret123",
        bind_host="0.0.0.0",
        ready_statuses=(401,),
    ) as (base_url, _):
        resp = httpx.get(f"{base_url}/health", timeout=10)
        authed = httpx.get(
            f"{base_url}/health",
            headers={"Authorization": "Bearer secret123"},
            timeout=10,
        )
    assert resp.status_code == 401
    assert resp.headers["www-authenticate"] == "Bearer"
    assert authed.status_code == 200


def test_public_health_keeps_non_loopback_health_open():
    """--public-health should preserve unauthenticated health checks when explicitly requested."""
    with running_server(
        "--token",
        "secret123",
        "--public-health",
        bind_host="0.0.0.0",
        ready_statuses=(200,),
    ) as (base_url, _):
        resp = httpx.get(f"{base_url}/health", timeout=10)
    assert resp.status_code == 200
