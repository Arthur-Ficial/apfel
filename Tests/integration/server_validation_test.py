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


# ============================================================================
# #235 - out-of-range sampling parameters
# ============================================================================

@pytest.mark.parametrize("top_p", [2.0, -0.5])
def test_out_of_range_top_p_returns_400(top_p):
    payload = {"model": MODEL, "messages": [{"role": "user", "content": "hi"}], "top_p": top_p}
    resp = _post(payload)
    assert resp.status_code == 400, (top_p, resp.status_code, resp.text)
    _assert_openai_error(resp, expected_type="invalid_request_error")


def test_temperature_above_two_returns_400():
    payload = {"model": MODEL, "messages": [{"role": "user", "content": "hi"}], "temperature": 5.0}
    resp = _post(payload)
    assert resp.status_code == 400, resp.text
    _assert_openai_error(resp, expected_type="invalid_request_error")


# ============================================================================
# #236 - error object param/code + unknown-model 404
# ============================================================================

def test_unknown_model_returns_404_model_not_found():
    payload = {"model": "gpt-4o", "messages": [{"role": "user", "content": "hi"}]}
    resp = _post(payload)
    assert resp.status_code == 404, resp.status_code
    err = _assert_openai_error(resp)
    assert err["code"] == "model_not_found", err
    assert err["param"] == "model", err


def test_error_object_always_has_null_param_and_code_when_absent():
    """A plain validation 400 must still include explicit null param/code (#236)."""
    payload = {"model": MODEL, "messages": []}  # empty messages -> 400
    resp = _post(payload)
    assert resp.status_code == 400
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert err["param"] is None, err
    assert err["code"] is None, err


# ============================================================================
# #237 - unknown x_context_strategy
# ============================================================================

def test_unknown_context_strategy_returns_400_listing_valid_values():
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "x_context_strategy": "sliding-window-typo",
    }
    resp = _post(payload)
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "newest-first" in err["message"], err


# ============================================================================
# #238b - invalid tool_choice rejected (not silently coerced to auto)
# ============================================================================

def test_invalid_tool_choice_string_returns_400():
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "tool_choice": "banana",
    }
    resp = _post(payload)
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "tool_choice" in err["message"], err


def test_undecodable_tool_choice_object_returns_400():
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "tool_choice": {"foo": "bar"},
    }
    resp = _post(payload)
    assert resp.status_code == 400, resp.text
    _assert_openai_error(resp, expected_type="invalid_request_error")


# ============================================================================
# #238a - stream_options.include_usage emits usage:null on non-final chunks
# (model-dependent: needs Apple Intelligence, run by the controller)
# ============================================================================

def _sse_chunks(text):
    import json
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("data:"):
            continue
        payload = line[len("data:"):].strip()
        if payload == "[DONE]":
            continue
        yield json.loads(payload)


def test_include_usage_emits_usage_null_on_non_final_chunks():
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hi in one word."}],
        "stream": True,
        "stream_options": {"include_usage": True},
        "max_tokens": 32,
    }
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions", json=payload, timeout=60) as r:
        assert r.status_code == 200
        body = r.read().decode()
    chunks = list(_sse_chunks(body))
    assert chunks, body
    # Exactly one final chunk carries the real usage stats (choices == []).
    usage_chunks = [c for c in chunks if c.get("usage")]
    assert len(usage_chunks) == 1, [c.get("usage") for c in chunks]
    assert usage_chunks[-1]["choices"] == []
    # Every other (non-final) chunk must carry an explicit usage: null key.
    non_final = [c for c in chunks if c is not usage_chunks[-1]]
    for c in non_final:
        assert "usage" in c, f"non-final chunk missing usage key: {c}"
        assert c["usage"] is None, f"non-final chunk usage not null: {c}"


def test_without_include_usage_no_usage_key_on_chunks():
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hi in one word."}],
        "stream": True,
        "max_tokens": 32,
    }
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions", json=payload, timeout=60) as r:
        assert r.status_code == 200
        body = r.read().decode()
    chunks = list(_sse_chunks(body))
    assert chunks, body
    # No opt-in -> no usage key anywhere (and no separate usage chunk).
    for c in chunks:
        assert "usage" not in c, f"chunk unexpectedly carries usage: {c}"
