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


# MARK: - Host header validation (DNS-rebinding defense, #230)

def test_foreign_host_header_rejected():
    """A foreign Host header (rebinding attacker domain) is rejected (#230)."""
    resp = httpx.get(
        f"{BASE_URL}/v1/models",
        headers={"Host": "attacker.com"},
        timeout=10,
    )
    assert resp.status_code == 403
    assert "Host" in resp.json()["error"]["message"]


def test_foreign_host_header_rejected_on_health():
    """Rebinding must not reach /health either (#230)."""
    resp = httpx.get(
        f"{BASE_URL}/health",
        headers={"Host": "attacker.com"},
        timeout=10,
    )
    assert resp.status_code == 403


def test_localhost_host_header_allowed():
    """The normal localhost Host header (with port) is accepted (#230)."""
    resp = httpx.get(
        f"{BASE_URL}/v1/models",
        headers={"Host": "localhost:11434"},
        timeout=10,
    )
    assert resp.status_code == 200


def test_127_host_header_allowed():
    """127.0.0.1 Host header is accepted (#230)."""
    resp = httpx.get(
        f"{BASE_URL}/v1/models",
        headers={"Host": "127.0.0.1:11434"},
        timeout=10,
    )
    assert resp.status_code == 200


def test_default_host_header_allowed():
    """The default (httpx-set) Host header must pass - standing suite stays green."""
    resp = httpx.get(f"{BASE_URL}/v1/models", timeout=10)
    assert resp.status_code == 200


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


def test_no_origin_check_shows_loud_warning_without_cors():
    """--no-origin-check alone must fire the loud multi-line warning (#232)."""
    with running_server("--no-origin-check") as (_, log_path):
        banner = read_log(log_path)
    assert "WARNING" in banner
    assert "Any website can access this server" in banner


def test_footgun_still_shows_loud_warning():
    """--footgun (no origin check + CORS) keeps the loud warning (#232 regression)."""
    with running_server("--footgun") as (_, log_path):
        banner = read_log(log_path)
    assert "WARNING" in banner
    assert "footgun" in banner
    assert "Any website can access this server" in banner


def test_default_server_has_no_origin_warning():
    """Default (origin check on) must NOT print the loud warning (#232)."""
    with running_server() as (_, log_path):
        banner = read_log(log_path)
    assert "Any website can access this server" not in banner


def test_non_loopback_bind_without_token_warns_loudly():
    """0.0.0.0 with no token must fire a loud red banner pointing at --token (#228)."""
    with running_server(bind_host="0.0.0.0") as (_, log_path):
        banner = read_log(log_path)
    assert "WARNING" in banner
    assert "NO token" in banner
    assert "--token" in banner
    assert "docs/server-security.md" in banner


def test_non_loopback_bind_with_token_has_no_exposure_warning():
    """0.0.0.0 WITH a token must not print the exposed-without-token warning (#228)."""
    with running_server(
        "--token", "secret123", bind_host="0.0.0.0", ready_statuses=(401,)
    ) as (_, log_path):
        banner = read_log(log_path)
    assert "NO token" not in banner


def test_loopback_bind_without_token_has_no_exposure_warning():
    """Default loopback bind without a token must not print the #228 warning."""
    with running_server() as (_, log_path):
        banner = read_log(log_path)
    assert "NO token" not in banner


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


# MARK: - CORS Allow-Headers (issue #40)

def test_footgun_preflight_allows_openai_sdk_headers():
    """--footgun preflight must allow x-stainless-* headers sent by the OpenAI SDK."""
    with running_server("--footgun") as (base_url, _):
        resp = httpx.options(
            f"{base_url}/v1/chat/completions",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type, Authorization, x-stainless-os, x-stainless-lang, x-stainless-arch, x-stainless-runtime",
            },
            timeout=10,
        )
    assert resp.status_code == 204
    allowed = resp.headers.get("access-control-allow-headers", "")
    # Either wildcard or the echoed request headers must include x-stainless-*
    if allowed == "*":
        pass  # wildcard allows everything
    else:
        assert "x-stainless-os" in allowed.lower()
        assert "x-stainless-lang" in allowed.lower()
        assert "x-stainless-arch" in allowed.lower()
        assert "x-stainless-runtime" in allowed.lower()


def test_footgun_preflight_allows_arbitrary_headers():
    """--footgun should allow ANY custom header in preflight, not just known ones."""
    with running_server("--footgun") as (base_url, _):
        resp = httpx.options(
            f"{base_url}/v1/chat/completions",
            headers={
                "Origin": "http://example.com",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Content-Type, X-Custom-Foo, X-My-Header",
            },
            timeout=10,
        )
    assert resp.status_code == 204
    allowed = resp.headers.get("access-control-allow-headers", "")
    if allowed == "*":
        pass  # wildcard allows everything
    else:
        assert "x-custom-foo" in allowed.lower()
        assert "x-my-header" in allowed.lower()


def test_cors_preflight_echoes_requested_headers():
    """--cors mode should echo back the Access-Control-Request-Headers value."""
    with running_server("--cors", "--no-origin-check") as (base_url, _):
        requested = "Content-Type, Authorization, x-stainless-os, x-stainless-lang"
        resp = httpx.options(
            f"{base_url}/v1/chat/completions",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": requested,
            },
            timeout=10,
        )
    assert resp.status_code == 204
    allowed = resp.headers.get("access-control-allow-headers", "")
    # In --cors mode (no --footgun), echo back the requested headers
    assert "x-stainless-os" in allowed.lower()
    assert "x-stainless-lang" in allowed.lower()


def test_deeply_nested_schema_is_rejected_not_fatal():
    """A 200-level nested JSON schema must return 400, not crash the server (#462)."""
    import json as _json

    depth = 200
    nest = '{"a":' * depth + '1' + '}' * depth

    # tools[].function.parameters
    tools_payload = _json.dumps({
        "model": "apple-foundationmodel",
        "messages": [{"role": "user", "content": "hi"}],
        "tools": [{"type": "function", "function": {"name": "t"}}],
    })
    # Inject the raw nested JSON into the parameters field.
    tools_payload = tools_payload.replace(
        '"name": "t"',
        f'"name": "t", "parameters": {nest}',
    )
    resp = httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        content=tools_payload.encode(),
        headers={"Content-Type": "application/json"},
        timeout=10,
    )
    assert resp.status_code == 400, f"expected 400, got {resp.status_code}"

    # response_format.json_schema.schema
    fmt_payload = _json.dumps({
        "model": "apple-foundationmodel",
        "messages": [{"role": "user", "content": "hi"}],
        "response_format": {"type": "json_schema", "json_schema": {"name": "s"}},
    })
    fmt_payload = fmt_payload.replace(
        '"name": "s"',
        f'"name": "s", "schema": {nest}',
    )
    resp = httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        content=fmt_payload.encode(),
        headers={"Content-Type": "application/json"},
        timeout=10,
    )
    assert resp.status_code == 400, f"expected 400 for response_format schema, got {resp.status_code}"

    # text.format.schema on /v1/responses
    responses_payload = _json.dumps({
        "model": "apple-foundationmodel",
        "input": "hi",
        "text": {"format": {"type": "json_schema", "name": "s"}},
    })
    responses_payload = responses_payload.replace(
        '"name": "s"',
        f'"name": "s", "schema": {nest}',
    )
    resp = httpx.post(
        f"{BASE_URL}/v1/responses",
        content=responses_payload.encode(),
        headers={"Content-Type": "application/json"},
        timeout=10,
    )
    assert resp.status_code == 400, f"expected 400 for /v1/responses schema, got {resp.status_code}"

    # Server must still be alive
    health = httpx.get(f"{BASE_URL}/health", timeout=5)
    assert health.status_code == 200, "server crashed after deeply nested payload"


def test_default_preflight_still_works_without_cors():
    """Without --cors flag, OPTIONS should return 204 but no CORS headers."""
    resp = httpx.options(
        f"{BASE_URL}/v1/chat/completions",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Content-Type, Authorization, x-stainless-os",
        },
        timeout=10,
    )
    assert resp.status_code == 204
    assert "access-control-allow-headers" not in resp.headers
