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
# #392 - response_format json_schema rejected when server has --mcp
# ============================================================================

MCP_BASE_URL = "http://localhost:11435"


def _post_mcp(payload, headers=None, timeout=120):
    return httpx.post(
        f"{MCP_BASE_URL}/v1/chat/completions",
        json=payload,
        headers=headers or {},
        timeout=timeout,
    )


def test_json_schema_with_mcp_is_rejected():
    """json_schema + --mcp must return 400 naming response_format (#392)."""
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "answer",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"greeting": {"type": "string"}},
                    "required": ["greeting"],
                    "additionalProperties": False,
                },
            },
        },
    }
    resp = _post_mcp(payload)
    assert resp.status_code == 400, (resp.status_code, resp.text)
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "response_format" in err["message"].lower() or "json_schema" in err["message"].lower(), err
    assert err["param"] == "response_format", err


def test_json_schema_with_mcp_rejected_streaming():
    """The rejection fires for streaming requests too (#392)."""
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
        "stream": True,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "answer",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"greeting": {"type": "string"}},
                    "required": ["greeting"],
                    "additionalProperties": False,
                },
            },
        },
    }
    resp = _post_mcp(payload)
    assert resp.status_code == 400, (resp.status_code, resp.text)
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert err["param"] == "response_format", err


@pytest.mark.model
def test_json_object_with_mcp_still_accepted():
    """json_object mode must NOT be rejected when --mcp is active (#392)."""
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
        "response_format": {"type": "json_object"},
    }
    resp = _post_mcp(payload)
    assert resp.status_code != 400 or "json_schema" not in resp.text.lower(), \
        f"json_object should not be rejected: {resp.text}"


@pytest.mark.model
def test_no_response_format_with_mcp_still_accepted():
    """Requests without response_format must still work with --mcp (#392)."""
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
    }
    resp = _post_mcp(payload)
    assert resp.status_code != 400, f"No response_format should not be rejected: {resp.text}"


@pytest.mark.model
def test_json_schema_without_mcp_still_accepted():
    """json_schema on the plain (non-MCP) server must not be rejected (#392)."""
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "answer",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {"greeting": {"type": "string"}},
                    "required": ["greeting"],
                    "additionalProperties": False,
                },
            },
        },
    }
    resp = _post(payload)
    assert resp.status_code != 400 or "mcp" not in resp.text.lower(), \
        f"json_schema on non-MCP server should not mention MCP: {resp.text}"


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


@pytest.mark.model
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


@pytest.mark.model
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


# ============================================================================
# POST /v1/responses (#365) - model-free validation, honest 501s, error shape
# ============================================================================


def _responses(payload):
    return httpx.post(f"{BASE_URL}/v1/responses", json=payload, timeout=30)


def test_responses_invalid_json_returns_400():
    r = httpx.post(
        f"{BASE_URL}/v1/responses",
        content="{not json",
        headers={"Content-Type": "application/json"},
        timeout=30,
    )
    assert r.status_code == 400
    assert r.json()["error"]["type"] == "invalid_request_error"


def test_responses_unknown_model_returns_404_model_not_found():
    r = _responses({"model": "gpt-4o", "input": "hi"})
    assert r.status_code == 404
    err = r.json()["error"]
    assert err["code"] == "model_not_found"
    assert err["param"] == "model"


def test_responses_missing_input_returns_400():
    r = _responses({"model": "apple-foundationmodel"})
    assert r.status_code == 400
    assert "input" in r.json()["error"]["message"]


def test_responses_previous_response_id_returns_501_stateless():
    r = _responses({"model": "apple-foundationmodel", "input": "hi",
                    "previous_response_id": "resp_123"})
    assert r.status_code == 501
    assert "stateless" in r.json()["error"]["message"]


def test_responses_background_returns_501():
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "background": True})
    assert r.status_code == 501


def test_responses_store_true_returns_501():
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "store": True})
    assert r.status_code == 501
    assert "stateless" in r.json()["error"]["message"]


def test_responses_reasoning_returns_501():
    r = _responses({"model": "apple-foundationmodel", "input": "hi",
                    "reasoning": {"effort": "low"}})
    assert r.status_code == 501


def test_responses_hosted_tool_returns_501():
    r = _responses({"model": "apple-foundationmodel", "input": "hi",
                    "tools": [{"type": "web_search"}]})
    assert r.status_code == 501
    assert "web_search" in r.json()["error"]["message"]


def test_responses_tools_with_stream_returns_501():
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "stream": True,
                    "tools": [{"type": "function", "name": "add"}]})
    assert r.status_code == 501


def test_responses_out_of_range_temperature_returns_400():
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "temperature": 3})
    assert r.status_code == 400
    assert "temperature" in r.json()["error"]["message"]


def test_responses_error_object_has_null_param_and_code():
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "background": True})
    err = r.json()["error"]
    assert "param" in err and err["param"] is None
    assert "code" in err and err["code"] is None


def test_responses_unknown_truncation_is_400():
    """Unknown truncation value must be rejected with a 400 naming the parameter (#391)."""
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "truncation": "none"})
    assert r.status_code == 400
    err = r.json()["error"]
    assert "truncation" in err["message"]
    assert "none" in err["message"]


def test_responses_truncation_auto_accepted():
    """truncation: auto is the default trimming behaviour and must not be rejected (#391)."""
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "truncation": "auto"})
    # auto is valid - should not be a 400 (it reaches the model, so may be 200 or 500
    # depending on whether Apple Intelligence is available, but never 400).
    assert r.status_code != 400


def test_responses_truncation_disabled_accepted():
    """truncation: disabled is valid and must not be rejected as unknown (#391)."""
    r = _responses({"model": "apple-foundationmodel", "input": "hi", "truncation": "disabled"})
    # disabled is valid - should not be a 400.
    assert r.status_code != 400


# ============================================================================
# #480 - tool_choice scope is validated before generation
# ============================================================================

def test_tool_choice_required_without_tools_returns_400():
    """tool_choice 'required' with no tools in scope can never be satisfied - 400, not a 500 after generation."""
    resp = _post({
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "tool_choice": "required",
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert err["param"] == "tool_choice", err
    assert "required" in err["message"], err


def test_named_tool_choice_with_no_tools_in_scope_returns_400():
    """A named tool_choice with neither client tools nor MCP tools is rejected up front (#480)."""
    resp = _post({
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "tool_choice": {"type": "function", "function": {"name": "lookup_ticket"}},
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert err["param"] == "tool_choice", err
    assert "lookup_ticket" in err["message"], err


def test_named_tool_choice_not_in_tools_returns_400():
    """A named tool_choice must reference a function in the request's tools array (#480)."""
    resp = _post({
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "tools": [{"type": "function", "function": {"name": "get_weather", "description": "d"}}],
        "tool_choice": {"type": "function", "function": {"name": "lookup_ticket"}},
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "lookup_ticket" in err["message"] and "get_weather" in err["message"], err


def test_models_advertise_parallel_tool_calls():
    """parallel_tool_calls is decoded and enforced, so /v1/models must advertise it (#480)."""
    resp = httpx.get(f"{BASE_URL}/v1/models", timeout=10)
    assert resp.status_code == 200
    supported = resp.json()["data"][0]["supported_parameters"]
    assert "parallel_tool_calls" in supported, supported
    assert "tool_choice" in supported, supported


# ============================================================================
# #482 - tool calls and their results must pair up
# ============================================================================

def test_orphan_tool_result_returns_400_with_message_path():
    """A tool message that answers no tool call is rejected before generation, naming messages[i] (#482)."""
    resp = _post({
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "hi"},
            {"role": "tool", "tool_call_id": "call_9", "content": "42"},
        ],
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "messages[1]" in err["message"], err
    assert "call_9" in err["message"], err


def test_tool_call_missing_its_result_returns_400():
    """An assistant tool_calls message must be followed by a result for every call (#482)."""
    resp = _post({
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "add"},
            {"role": "assistant", "content": None, "tool_calls": [
                {"id": "c1", "type": "function", "function": {"name": "add", "arguments": "{}"}},
                {"id": "c2", "type": "function", "function": {"name": "add", "arguments": "{}"}},
            ]},
            {"role": "tool", "tool_call_id": "c1", "content": "3"},
            {"role": "user", "content": "and the other?"},
        ],
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "messages[1]" in err["message"] and "c2" in err["message"], err


@pytest.mark.model
def test_trailing_tool_exchange_larger_than_the_window_is_context_overflow():
    """The exchange that a trailing tool result belongs to is pinned; when it cannot
    fit the runtime-derived budget the request fails before generation instead of
    the exchange being silently trimmed away (#482)."""
    window = httpx.get(f"{BASE_URL}/health", timeout=10).json()["context_window"]
    huge = "x " * (window * 4)  # far beyond any window at ~1 token per 2 chars
    resp = _post({
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "fetch it"},
            {"role": "assistant", "content": None, "tool_calls": [
                {"id": "c1", "type": "function", "function": {"name": "fetch", "arguments": "{}"}},
            ]},
            {"role": "tool", "tool_call_id": "c1", "content": huge},
        ],
    }, timeout=60)
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="context_length_exceeded")


# ---------------------------------------------------------------------------
# #479 - JSON Schema references and constraints are honoured or rejected, never
# silently dropped. Every case here fails before the model is touched.
# ---------------------------------------------------------------------------

def _json_schema_request(schema, stream=False):
    return {
        "model": MODEL,
        "messages": [{"role": "user", "content": "extract"}],
        "stream": stream,
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "Thing", "schema": schema, "strict": True},
        },
    }


def test_json_schema_unsupported_keyword_returns_400_naming_keyword_and_path():
    """A validation keyword with no faithful mapping is an honest 400 that
    points at the node to fix, not a silently weakened contract (#479)."""
    schema = {
        "type": "object",
        "properties": {"price": {"type": "number", "multipleOf": 0.01}},
        "required": ["price"],
        "additionalProperties": False,
    }
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "multipleOf" in err["message"], err
    assert "#/properties/price" in err["message"], err


def test_json_schema_unsupported_keyword_with_stream_is_still_a_400():
    """The rejection happens before any SSE frame is written (#479)."""
    schema = {"type": "object", "properties": {"code": {"type": "string", "pattern": "^[A-Z]+$"}}}
    resp = _post(_json_schema_request(schema, stream=True))
    assert resp.status_code == 400, resp.text
    assert "text/event-stream" not in resp.headers.get("content-type", ""), resp.headers
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "pattern" in err["message"] and "#/properties/code" in err["message"], err


def test_json_schema_external_ref_returns_400_and_is_never_fetched():
    schema = {"type": "object", "properties": {"a": {"$ref": "https://example.invalid/a.json"}}}
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "https://example.invalid/a.json" in err["message"], err
    assert "local" in err["message"].lower(), err


def test_json_schema_unresolved_ref_returns_400():
    schema = {"type": "object", "$defs": {}, "properties": {"a": {"$ref": "#/$defs/Missing"}}}
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "#/$defs/Missing" in err["message"], err


def test_json_schema_recursive_ref_returns_400():
    schema = {
        "type": "object",
        "$defs": {"Node": {"type": "object", "properties": {"next": {"$ref": "#/$defs/Node"}}}},
        "properties": {"head": {"$ref": "#/$defs/Node"}},
    }
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "recursive" in err["message"].lower(), err


def test_json_schema_contradictory_bounds_return_400():
    schema = {"type": "object", "properties": {"n": {"type": "integer", "minimum": 5, "maximum": 1}}}
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "minimum" in err["message"] and "#/properties/n" in err["message"], err


def test_json_schema_required_undeclared_property_returns_400():
    schema = {"type": "object", "properties": {"a": {"type": "string"}}, "required": ["a", "ghost"]}
    resp = _post(_json_schema_request(schema))
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "ghost" in err["message"], err


def test_responses_json_schema_unsupported_keyword_returns_400():
    """The Responses surface uses the same compiler and the same rejection (#479)."""
    resp = _responses({
        "model": MODEL,
        "input": "extract",
        "text": {"format": {
            "type": "json_schema", "name": "Thing",
            "schema": {"type": "object", "properties": {"tags": {"type": "array", "items": {"type": "string"}, "uniqueItems": True}}},
        }},
    })
    assert resp.status_code == 400, resp.text
    err = _assert_openai_error(resp, expected_type="invalid_request_error")
    assert "uniqueItems" in err["message"] and "#/properties/tags" in err["message"], err


def test_tool_parameters_with_unsupported_keyword_are_not_a_400():
    """Tool schemas keep the documented fallback: an unconvertible tool is
    injected as text, not rejected, so a client with one exotic tool still
    works (docs/tool-calling-guide.md). Only the request shape is asserted
    here; the model is not needed to prove the request is accepted."""
    resp = _post({
        "model": MODEL,
        "messages": [{"role": "user", "content": "hi"}],
        "max_tokens": 1,
        "tools": [{"type": "function", "function": {"name": "f", "parameters": {
            "type": "object", "properties": {"x": {"type": "string", "pattern": "^a"}}}}}],
        "tool_choice": "none",
    }, timeout=120)
    assert resp.status_code != 400, resp.text
