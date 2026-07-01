"""
apfel Integration Tests - Server request-validation and error-protocol wire format.

Covers the audit fixes for request validation and OpenAI error-protocol parity.
These validation paths run BEFORE the on-device model is touched, so they are
model-free and run in CI as well as locally.

Requires: apfel --serve running on localhost:11434
Run: python3 -m pytest Tests/integration/server_validation_test.py -v
"""

import httpx
import pytest

BASE_URL = "http://localhost:11434"
MODEL = "apple-foundationmodel"
LOCAL_ORIGIN = "http://localhost:5173"


def _post(payload, headers=None, timeout=15):
    return httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        json=payload,
        headers=headers or {},
        timeout=timeout,
    )


def _assert_openai_error(resp, expected_type=None):
    """Every error body must be {"error": {message, type, param, code}} with
    param and code always present (explicit null when absent) - #236."""
    body = resp.json()
    assert "error" in body, f"missing error object: {body}"
    err = body["error"]
    assert "message" in err and isinstance(err["message"], str)
    assert "type" in err and isinstance(err["type"], str)
    # param and code keys must be present even when null (OpenAI parity, #236)
    assert "param" in err, f"error object missing 'param' key: {err}"
    assert "code" in err, f"error object missing 'code' key: {err}"
    if expected_type is not None:
        assert err["type"] == expected_type, err
    return err


# ============================================================================
# #234 - oversized request body
# ============================================================================

def test_oversized_body_returns_413_with_error_object():
    """A body over 1 MiB returns 413 with an OpenAI error object, not a bare 413."""
    big = "x" * (1024 * 1024 + 1024)  # > 1 MiB
    payload = {"model": MODEL, "messages": [{"role": "user", "content": big}]}
    resp = _post(payload)
    assert resp.status_code == 413, resp.status_code
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "MiB" in err["message"] or "limit" in err["message"].lower()


def test_oversized_body_includes_cors_header_for_allowed_origin():
    """The 413 must carry CORS headers so browser clients can read it (#234)."""
    big = "x" * (1024 * 1024 + 1024)
    payload = {"model": MODEL, "messages": [{"role": "user", "content": big}]}
    resp = _post(payload, headers={"Origin": LOCAL_ORIGIN})
    assert resp.status_code == 413
    # Allowed localhost origin is echoed back (origin check is on by default).
    assert resp.headers.get("access-control-allow-origin") == LOCAL_ORIGIN, dict(resp.headers)
