"""
apfel Integration Tests - POST /v1/responses/input_tokens (#485)

Token preflight for the OpenAI Responses API: count the exact prepared input
generation would hand to Apple's on-device model, without generating and
without executing tools.

Two kinds of test:
  - model-free (no marker): request contract, honest 4xx/5xx, auth, CORS and
    body limits - every request here is rejected before any tokenizer call.
  - @pytest.mark.model: real counts via Apple's tokenizer (needs Apple
    Intelligence). On macOS < 26.4 there is no tokenizer API, and these tests
    assert the endpoint's honest 501 instead of a number - never a chars/4
    estimate dressed up as exact.

Run: python3 -m pytest Tests/integration/test_input_tokens.py -v
"""

import contextlib
import os
import pathlib
import platform
import socket
import subprocess
import tempfile
import time

import httpx
import openai
import pytest

from conftest import require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://localhost:11434"
URL = f"{BASE_URL}/v1/responses/input_tokens"
MODEL = "apple-foundationmodel"
LOCAL_ORIGIN = "http://localhost:3000"
TIMEOUT = 120

_MAC = tuple(int(x) for x in (platform.mac_ver()[0].split(".") + ["0"])[:2])
# Apple's tokenizer API (SystemLanguageModel.tokenCount(for:)) arrived in 26.4.
TOKENIZER_AVAILABLE = _MAC >= (26, 4)
_BODY_CAP = (24 if _MAC[0] >= 27 else 1) * 1024 * 1024


def _count(payload, **kwargs):
    return httpx.post(URL, json=payload, timeout=TIMEOUT, **kwargs)


def _err(resp, status):
    assert resp.status_code == status, (resp.status_code, resp.text)
    err = resp.json()["error"]
    for key in ("message", "type", "param", "code"):
        assert key in err, err
    return err


# ============================================================================
# Model-free: request contract
# ============================================================================

def test_invalid_json_is_400():
    r = httpx.post(URL, content="{nope", headers={"Content-Type": "application/json"}, timeout=30)
    assert _err(r, 400)["type"] == "invalid_request_error"


def test_unknown_model_is_404_model_not_found():
    err = _err(_count({"model": "gpt-4o", "input": "hi"}), 404)
    assert err["code"] == "model_not_found"
    assert err["param"] == "model"


def test_missing_model_is_400():
    _err(_count({"input": "hi"}), 400)


def test_missing_input_is_400():
    assert "input" in _err(_count({"model": MODEL}), 400)["message"]


@pytest.mark.parametrize("key,value", [
    ("stream", False), ("temperature", 0.2), ("max_output_tokens", 64),
    ("top_p", 0.9), ("metadata", {"a": "b"}), ("store", False),
])
def test_generation_only_parameter_is_400_naming_it(key, value):
    err = _err(_count({"model": MODEL, "input": "hi", key: value}), 400)
    assert err["param"] == key
    assert "/v1/responses/input_tokens" in err["message"]


def test_conversation_is_501_stateless():
    err = _err(_count({"model": MODEL, "input": "hi", "conversation": "conv_123"}), 501)
    assert "stateless" in err["message"]


def test_previous_response_id_is_501_stateless():
    err = _err(_count({"model": MODEL, "input": "hi", "previous_response_id": "resp_1"}), 501)
    assert "stateless" in err["message"]


def test_reasoning_is_501():
    _err(_count({"model": MODEL, "input": "hi", "reasoning": {"effort": "low"}}), 501)


def test_image_input_is_501():
    payload = {"model": MODEL, "input": [{"role": "user", "content": [
        {"type": "input_text", "text": "what is this"},
        {"type": "input_image", "image_url": "data:image/png;base64,iVBORw0KGgo="},
    ]}]}
    assert "image" in _err(_count(payload), 501)["message"].lower()


def test_file_input_is_rejected():
    payload = {"model": MODEL, "input": [{"role": "user", "content": [
        {"type": "input_text", "text": "read"}, {"type": "input_file", "file_id": "file_1"},
    ]}]}
    r = _count(payload)
    assert r.status_code in (400, 501), r.text
    assert "input_file" in r.json()["error"]["message"]


def test_hosted_tool_is_501():
    err = _err(_count({"model": MODEL, "input": "hi", "tools": [{"type": "web_search"}]}), 501)
    assert "web_search" in err["message"]


def test_invalid_truncation_is_400():
    err = _err(_count({"model": MODEL, "input": "hi", "truncation": "middle"}), 400)
    assert err["param"] == "truncation"


def test_tool_choice_naming_unknown_tool_is_400():
    payload = {"model": MODEL, "input": "hi",
               "tools": [{"type": "function", "name": "add", "parameters": {"type": "object", "properties": {}}}],
               "tool_choice": {"type": "function", "name": "nope"}}
    _err(_count(payload), 400)


def test_get_is_not_routed():
    r = httpx.get(URL, timeout=30)
    assert r.status_code in (404, 405), r.status_code


def test_oversized_body_is_413_with_error_object():
    big = "x" * (_BODY_CAP + 1024)
    err = _err(_count({"model": MODEL, "input": big}), 413)
    assert err["type"] == "invalid_request_error"


# ============================================================================
# Model-free: security policy is the same as every other /v1 route
# ============================================================================

def test_foreign_origin_is_rejected():
    r = _count({"model": MODEL, "input": "hi"}, headers={"Origin": "https://evil.example"})
    assert r.status_code == 403


def test_preflight_options_returns_204():
    r = httpx.options(URL, headers={
        "Origin": LOCAL_ORIGIN, "Access-Control-Request-Method": "POST"}, timeout=30)
    assert r.status_code == 204


def _free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@contextlib.contextmanager
def _server(*args):
    port = _free_port()
    env = {k: v for k, v in os.environ.items() if k not in ("APFEL_HOST", "APFEL_PORT", "APFEL_TOKEN")}
    with tempfile.TemporaryFile() as log:
        proc = subprocess.Popen([str(BINARY), "--serve", "--port", str(port), *args],
                                stdout=log, stderr=log, env=env)
        base = f"http://127.0.0.1:{port}"
        try:
            deadline = time.time() + 20
            while time.time() < deadline:
                try:
                    httpx.get(f"{base}/health", timeout=1)
                    break
                except httpx.HTTPError:
                    time.sleep(0.2)
            yield base
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


def test_token_auth_is_enforced():
    with _server("--token", "sekrit", "--cors", "--allowed-origins", LOCAL_ORIGIN) as base:
        url = f"{base}/v1/responses/input_tokens"
        r = httpx.post(url, json={"model": "gpt-4o", "input": "hi"},
                       headers={"Origin": LOCAL_ORIGIN}, timeout=30)
        assert r.status_code == 401
        assert r.json()["error"]["type"] == "authentication_error"
        assert r.headers["access-control-allow-origin"] == LOCAL_ORIGIN
        # Authorized: reaches the handler (unknown model is a 404 before any count).
        ok = httpx.post(url, json={"model": "gpt-4o", "input": "hi"},
                        headers={"Authorization": "Bearer sekrit"}, timeout=30)
        assert ok.status_code == 404


# ============================================================================
# Model tests: real counts from Apple's tokenizer
# ============================================================================

client = openai.OpenAI(base_url=f"{BASE_URL}/v1", api_key="local-placeholder")


def _assert_unavailable(resp):
    """macOS < 26.4: an explicit error, never an approximate number."""
    err = _err(resp, 501)
    assert err["code"] == "token_counting_unavailable"
    assert "26.4" in err["message"]
    assert "input_tokens" not in resp.json()


def _count_ok(payload):
    """Count via raw HTTP. Returns the JSON body, or None after asserting the
    honest unavailable error on an OS without Apple's tokenizer API."""
    r = _count(payload)
    if not TOKENIZER_AVAILABLE:
        _assert_unavailable(r)
        return None
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["object"] == "response.input_tokens"
    assert isinstance(body["input_tokens"], int) and body["input_tokens"] > 0
    return body


def _sdk_count(**kwargs):
    """Count via the official openai-python method."""
    if not TOKENIZER_AVAILABLE:
        with pytest.raises(openai.APIStatusError) as exc:
            client.responses.input_tokens.count(model=MODEL, **kwargs)
        assert exc.value.status_code == 501
        return None
    report = client.responses.input_tokens.count(model=MODEL, **kwargs)
    assert report.object == "response.input_tokens"
    assert report.input_tokens > 0
    return report.input_tokens


def _generated_input_tokens(payload):
    """usage.input_tokens of a real /v1/responses generation for the same input."""
    r = httpx.post(f"{BASE_URL}/v1/responses", json={**payload, "max_output_tokens": 16}, timeout=TIMEOUT)
    assert r.status_code == 200, r.text
    return r.json()["usage"]["input_tokens"]


MULTI_TURN = [
    {"role": "user", "content": "My name is Ada and I keep bees."},
    {"role": "assistant", "content": "Nice to meet you, Ada. Bees are wonderful."},
    {"role": "user", "content": "What do I keep?"},
]
SCHEMA_FORMAT = {"format": {"type": "json_schema", "name": "city", "schema": {
    "type": "object", "properties": {"city": {"type": "string"}, "country": {"type": "string"}},
    "required": ["city", "country"]}}}
ADD_TOOL = {"type": "function", "name": "add", "description": "Add two numbers",
            "parameters": {"type": "object", "properties": {
                "a": {"type": "number"}, "b": {"type": "number"}}, "required": ["a", "b"]}}


@pytest.mark.model
def test_sdk_count_issue_example():
    """The exact snippet from #485 works against apfel."""
    require_model()
    _sdk_count(input="Summarize this local support ticket.")


@pytest.mark.model
def test_sdk_count_instructions_multi_turn_and_tools():
    require_model()
    plain = _sdk_count(input="Hello there")
    with_instr = _sdk_count(input="Hello there", instructions="Answer in one short sentence.")
    multi = _sdk_count(input=MULTI_TURN)
    with_tools = _sdk_count(input="Add 2 and 3.", tools=[ADD_TOOL])
    if TOKENIZER_AVAILABLE:
        assert plain and with_instr and multi and with_tools
        assert with_instr > plain
        assert multi > plain
        assert with_tools > (_sdk_count(input="Add 2 and 3.") or 0)


@pytest.mark.model
def test_count_is_deterministic():
    require_model()
    payload = {"model": MODEL, "input": MULTI_TURN, "instructions": "Be brief."}
    first = _count_ok(payload)
    second = _count_ok(payload)
    if first is not None:
        assert first == second


@pytest.mark.model
def test_x_apfel_report_describes_the_runtime_budget():
    require_model()
    body = _count_ok({"model": MODEL, "input": "hi"})
    if body is None:
        return
    window = httpx.get(f"{BASE_URL}/v1/models", timeout=30).json()["data"][0]["context_window"]
    ext = body["x_apfel"]
    assert ext["context_size"] == window
    assert ext["input_budget"] == ext["context_size"] - ext["output_reserve"]
    assert ext["input_tokens"] == body["input_tokens"]
    assert ext["untrimmed_input_tokens"] == body["input_tokens"]
    assert ext["fits"] is True
    assert ext["trimmed"] is False
    assert ext["removed_input_items"] == []
    assert ext["truncation"] == "auto"
    assert ext["tokenizer"] == "apple-foundationmodels"


@pytest.mark.model
@pytest.mark.parametrize("extra", [
    {"input": "Name one city in Austria."},
    {"input": "Name one city in Austria.", "instructions": "Answer with one word."},
    {"input": MULTI_TURN},
    {"input": "Name one city and its country.", "text": SCHEMA_FORMAT},
], ids=["text", "instructions", "multi_turn", "json_schema"])
def test_count_matches_generation_input(extra):
    """The preflight count equals the input tokens of the real generation for
    the same request: same instructions, roles, prompt framing and schema."""
    require_model()
    payload = {"model": MODEL, **extra}
    body = _count_ok(payload)
    if body is None:
        return
    assert body["input_tokens"] == _generated_input_tokens(payload)


@pytest.mark.model
def test_tool_definitions_are_counted_not_executed():
    """Tools add their definitions to the count; counting never runs a tool
    and never returns output."""
    require_model()
    without = _count_ok({"model": MODEL, "input": "Add 2 and 3."})
    body = _count_ok({"model": MODEL, "input": "Add 2 and 3.", "tools": [ADD_TOOL]})
    if body is None:
        return
    assert without is not None
    assert body["input_tokens"] > without["input_tokens"]
    assert set(body) == {"object", "input_tokens", "x_apfel"}


def _long_history(turns_needed_tokens):
    chunk = "The quick brown fox jumps over the lazy dog near the quiet river bank. " * 12
    items = []
    i = 0
    while len(items) * 150 < turns_needed_tokens:
        role = "user" if i % 2 == 0 else "assistant"
        items.append({"role": role, "content": f"Turn {i}. {chunk}"})
        i += 1
    if items[-1]["role"] == "user":
        items.append({"role": "assistant", "content": "Noted."})
    items.append({"role": "user", "content": "What was turn 0 about?"})
    return items


def _window():
    return httpx.get(f"{BASE_URL}/v1/models", timeout=30).json()["data"][0]["context_window"]


@pytest.mark.model
def test_disabled_truncation_over_budget_is_explicit_error():
    require_model()
    payload = {"model": MODEL, "input": _long_history(_window() * 2), "truncation": "disabled"}
    r = _count(payload)
    if not TOKENIZER_AVAILABLE:
        _assert_unavailable(r)
        return
    err = _err(r, 400)
    assert err["code"] == "context_length_exceeded"
    assert str(_window()) in err["message"]
    assert "disabled" in err["message"]


@pytest.mark.model
def test_auto_truncation_reports_removed_items_and_matches_generation():
    require_model()
    items = _long_history(_window() * 2)
    payload = {"model": MODEL, "input": items, "truncation": "auto"}
    body = _count_ok(payload)
    if body is None:
        return
    ext = body["x_apfel"]
    assert ext["trimmed"] is True
    assert ext["untrimmed_input_tokens"] > ext["input_budget"]
    assert body["input_tokens"] <= ext["input_budget"]
    removed = ext["removed_input_items"]
    assert removed and removed == list(range(len(removed))), "newest-first trimming drops the oldest items"
    # Counting the kept items alone with truncation disabled gives the same number.
    kept = [item for i, item in enumerate(items) if i not in set(removed)]
    again = _count_ok({"model": MODEL, "input": kept, "truncation": "disabled"})
    assert again is not None
    assert again["input_tokens"] == body["input_tokens"]
    assert again["x_apfel"]["trimmed"] is False
    # Generation trims to the same prepared input.
    assert _generated_input_tokens(payload) == body["input_tokens"]


@pytest.mark.model
def test_auto_truncation_cannot_save_an_oversized_final_prompt():
    require_model()
    huge = "word " * (_window() * 2)
    r = _count({"model": MODEL, "input": huge})
    if not TOKENIZER_AVAILABLE:
        _assert_unavailable(r)
        return
    err = _err(r, 400)
    assert err["code"] == "context_length_exceeded"
