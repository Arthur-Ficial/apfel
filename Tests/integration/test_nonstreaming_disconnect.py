"""
apfel Integration Tests - Non-streaming client disconnect permit release (#542).

Before the fix, a client that timed out or disconnected during a non-streaming
/v1/chat/completions or /v1/responses request did not stop generation: the
handler awaited collectStream to the end and held its semaphore permit. Clients
that retried on timeout stacked up; after --max-concurrent of them everyone
got 429.

Model-dependent: the test needs a prompt that triggers a generation long enough
to disconnect mid-flight.

Requires: apfel --serve running on localhost:11434 (conftest fixtures).
Run: python3 -m pytest Tests/integration/test_nonstreaming_disconnect.py -v
"""

import socket
import time

import httpx
import pytest

from conftest import require_model

pytestmark = pytest.mark.model

BASE_URL = "http://localhost:11434"


def _active_requests():
    resp = httpx.get(f"{BASE_URL}/health", timeout=5)
    assert resp.status_code == 200
    return resp.json()["active_requests"]


def _raw_post_then_disconnect(path, payload_bytes, wait_before_close=0.5):
    """Open a TCP socket, send a valid HTTP POST, wait briefly, then close
    the connection without reading the response - simulating a client timeout."""
    sock = socket.create_connection(("127.0.0.1", 11434), timeout=5)
    try:
        body = payload_bytes
        headers = (
            f"POST {path} HTTP/1.1\r\n"
            f"Host: 127.0.0.1:11434\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(body)}\r\n"
            f"Connection: close\r\n"
            f"\r\n"
        ).encode()
        sock.sendall(headers + body)
        time.sleep(wait_before_close)
    finally:
        sock.close()


def test_nonstreaming_disconnect_releases_permit_chat():
    """Kill the client mid-generation on /v1/chat/completions (non-streaming).
    The permit must return to the pool within a few seconds."""
    require_model()

    assert _active_requests() == 0, "dirty state: active_requests != 0 before test"

    payload = (
        b'{"model":"apple-foundationmodel","stream":false,'
        b'"messages":[{"role":"user","content":"Write a long detailed essay about the history of computing from 1940 to 2020. Cover every decade in detail."}]}'
    )
    _raw_post_then_disconnect("/v1/chat/completions", payload, wait_before_close=0.8)

    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if _active_requests() == 0:
            return
        time.sleep(0.5)

    assert _active_requests() == 0, (
        "active_requests did not return to 0 within 15s after client disconnect - "
        "permit leak (#542)"
    )


def test_nonstreaming_disconnect_releases_permit_responses():
    """Same test against /v1/responses."""
    require_model()

    assert _active_requests() == 0, "dirty state: active_requests != 0 before test"

    payload = (
        b'{"model":"apple-foundationmodel","stream":false,'
        b'"input":"Write a long detailed essay about the history of computing from 1940 to 2020. Cover every decade in detail."}'
    )
    _raw_post_then_disconnect("/v1/responses", payload, wait_before_close=0.8)

    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if _active_requests() == 0:
            return
        time.sleep(0.5)

    assert _active_requests() == 0, (
        "active_requests did not return to 0 within 15s after client disconnect - "
        "permit leak (#542)"
    )


def test_server_still_answers_after_disconnect():
    """After abandoned requests, a normal request must succeed (no 429)."""
    require_model()

    payload = (
        b'{"model":"apple-foundationmodel","stream":false,'
        b'"messages":[{"role":"user","content":"Write a very long essay about every planet in the solar system in extreme detail."}]}'
    )
    for _ in range(3):
        _raw_post_then_disconnect("/v1/chat/completions", payload, wait_before_close=0.5)

    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if _active_requests() == 0:
            break
        time.sleep(0.5)

    resp = httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        json={
            "model": "apple-foundationmodel",
            "stream": False,
            "messages": [{"role": "user", "content": "Say hello."}],
        },
        timeout=60,
    )
    assert resp.status_code == 200, (
        f"expected 200 after abandoned requests, got {resp.status_code} - "
        "permits may still be leaked (#542)"
    )
