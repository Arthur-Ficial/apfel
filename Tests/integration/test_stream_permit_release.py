"""
apfel Integration Tests - Concurrency permit release on early-failing
streaming requests (#213).

Before the fix, every "stream": true request that failed before the SSE
body was built (validation failure, json_schema failure, context-build
failure) leaked one concurrency permit and one active_requests count
forever. --max-concurrent (default 5) such requests were a remote
unauthenticated DoS: all later requests queued to the 30s timeout.

Model-free: every request here fails with 400 before touching the model.

Requires: apfel --serve running on localhost:11434 (conftest fixtures).
Run: python3 -m pytest Tests/integration/test_stream_permit_release.py -v
"""

import httpx
import pytest

# NOT `model`: every request here fails validation and returns 400 before a
# LanguageModelSession is constructed, so these run fine on a GitHub runner
# without Apple Intelligence. The old `model` marker kept the #213 permit-leak
# regression out of the per-PR gate entirely -- exactly the kind of regression
# that gate exists to catch (#434).
#
# `serial` because the assertions read /health's *global* active_requests
# counter on the shared server: any other suite with a request in flight makes
# it non-zero. This must not run in the parallel phase.
pytestmark = pytest.mark.serial


BASE_URL = "http://localhost:11434"

# The shared server on 11434 runs with the default --max-concurrent (5).
# Sending exactly that many early-failing streaming requests exhausted
# every permit before the fix, so a leak of any size trips the assertions.
DEFAULT_MAX_CONCURRENT = 5


def _active_requests():
    resp = httpx.get(f"{BASE_URL}/health", timeout=5)
    assert resp.status_code == 200
    return resp.json()["active_requests"]


def _post_chat(payload):
    return httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        json=payload,
        timeout=10,
    )


def test_validation_failing_streaming_requests_release_permits():
    """Empty messages + stream:true -> 400, and no permit/counter leak."""
    for _ in range(DEFAULT_MAX_CONCURRENT):
        resp = _post_chat(
            {"model": "apple-foundationmodel", "stream": True, "messages": []}
        )
        assert resp.status_code == 400
    assert _active_requests() == 0


def test_json_schema_failing_streaming_requests_release_permits():
    """Missing json_schema.schema + stream:true -> 400, and no leak."""
    for _ in range(DEFAULT_MAX_CONCURRENT):
        resp = _post_chat(
            {
                "model": "apple-foundationmodel",
                "stream": True,
                "messages": [{"role": "user", "content": "hi"}],
                "response_format": {"type": "json_schema", "json_schema": {"name": "x"}},
            }
        )
        assert resp.status_code == 400
    assert _active_requests() == 0


def test_server_still_answers_after_early_failing_streams():
    """After a burst of early-failing streams, a new request must acquire a
    permit instantly (an immediate 400 for a bad request - not a 429 or a
    hang after queueing for a permit)."""
    for _ in range(DEFAULT_MAX_CONCURRENT):
        _post_chat(
            {"model": "apple-foundationmodel", "stream": True, "messages": []}
        )
    resp = _post_chat(
        {"model": "apple-foundationmodel", "stream": False, "messages": []}
    )
    assert resp.status_code == 400
    assert _active_requests() == 0
