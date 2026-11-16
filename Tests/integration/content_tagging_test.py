"""
apfel Integration Tests - the content-tagging served model (follow-up to #170)

`apfel --serve` serves Apple's content-tagging adapter
(SystemLanguageModel(useCase: .contentTagging)) as a second model id next to
the default `apple-foundationmodel`.

Two kinds of test:
  - model-free (no marker): /v1/models listing, the 404 for unknown ids, the
    400 for tools on the tagging model, the default model's id unchanged.
  - @pytest.mark.model: real tagging through chat completions (plain,
    json_schema, streamed), the Responses API and the token preflight, each
    echoing the requested model id.

Requires: apfel --serve on localhost:11434 (and the MCP server on 11435 for
the "no MCP tools for tagging" test).
Run: python3 -m pytest Tests/integration/content_tagging_test.py -v
"""

import json

import httpx
import pytest

from conftest import require_model

BASE_URL = "http://localhost:11434"
MCP_URL = "http://localhost:11435"
GENERAL = "apple-foundationmodel"
TAGGING = "apple-foundationmodel-content-tagging"
TIMEOUT = 120

TAGS_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "tags",
        "schema": {
            "type": "object",
            "properties": {"tags": {"type": "array", "items": {"type": "string"}}},
            "required": ["tags"],
        },
    },
}
A_TOOL = {"type": "function", "function": {"name": "f", "parameters": {"type": "object"}}}


def _chat(payload, base=BASE_URL):
    return httpx.post(f"{base}/v1/chat/completions", json=payload, timeout=TIMEOUT)


# ============================================================================
# Model-free: the contract
# ============================================================================

def test_models_lists_both_ids_general_first():
    data = httpx.get(f"{BASE_URL}/v1/models", timeout=TIMEOUT).json()["data"]
    assert [m["id"] for m in data] == [GENERAL, TAGGING]


def test_models_tagging_entry_advertises_no_tools():
    data = {m["id"]: m for m in httpx.get(f"{BASE_URL}/v1/models", timeout=TIMEOUT).json()["data"]}
    tagging, general = data[TAGGING], data[GENERAL]
    for param in ("tools", "tool_choice", "parallel_tool_calls"):
        assert param in general["supported_parameters"]
        assert param not in tagging["supported_parameters"]
    assert "tool_calling" not in tagging["capabilities"]
    assert "response_format" in tagging["supported_parameters"]
    assert tagging["context_window"] == general["context_window"]


def test_unknown_model_404_lists_every_id():
    resp = _chat({"model": "gpt-5", "messages": [{"role": "user", "content": "hi"}]})
    assert resp.status_code == 404, resp.text
    err = resp.json()["error"]
    assert err["code"] == "model_not_found"
    assert GENERAL in err["message"] and TAGGING in err["message"]


def test_tools_on_tagging_model_are_400():
    resp = _chat({"model": TAGGING, "messages": [{"role": "user", "content": "hi"}], "tools": [A_TOOL]})
    assert resp.status_code == 400, resp.text
    assert "'tools'" in resp.json()["error"]["message"]


def test_tools_on_tagging_model_are_400_on_responses():
    resp = httpx.post(f"{BASE_URL}/v1/responses", json={
        "model": TAGGING, "input": "hi",
        "tools": [{"type": "function", "name": "f", "parameters": {"type": "object"}}],
    }, timeout=TIMEOUT)
    assert resp.status_code == 400, resp.text
    assert resp.json()["error"]["param"] == "tools"


# ============================================================================
# Model: real tagging
# ============================================================================

@pytest.mark.model
def test_tagging_json_schema_returns_tags():
    require_model()
    resp = _chat({
        "model": TAGGING,
        "messages": [
            {"role": "system", "content": "Extract topic tags."},
            {"role": "user", "content": "The quarterly budget review moved to Friday; finance needs the slides."},
        ],
        "response_format": TAGS_SCHEMA,
    })
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["model"] == TAGGING
    tags = json.loads(body["choices"][0]["message"]["content"])["tags"]
    assert isinstance(tags, list) and tags and all(isinstance(t, str) and t for t in tags)


@pytest.mark.model
def test_tagging_stream_chunks_echo_the_tagging_id():
    require_model()
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions", json={
        "model": TAGGING, "stream": True,
        "messages": [{"role": "user", "content": "Kubernetes pods keep crashing under load."}],
    }, timeout=TIMEOUT) as resp:
        assert resp.status_code == 200
        chunks = [json.loads(line[6:]) for line in resp.iter_lines()
                  if line.startswith("data: {")]
    assert chunks
    assert {c["model"] for c in chunks} == {TAGGING}
    text = "".join((c["choices"][0]["delta"].get("content") or "")
                   for c in chunks if c.get("choices"))
    assert text.strip()


@pytest.mark.model
def test_general_model_still_echoes_its_own_id():
    require_model()
    resp = _chat({"model": GENERAL, "messages": [{"role": "user", "content": "Reply with exactly: ok"}]})
    assert resp.status_code == 200, resp.text
    assert resp.json()["model"] == GENERAL


@pytest.mark.model
def test_tagging_on_responses_api_echoes_the_tagging_id():
    require_model()
    resp = httpx.post(f"{BASE_URL}/v1/responses", json={
        "model": TAGGING, "input": "A thrilling, scary movie night with friends.",
    }, timeout=TIMEOUT)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["model"] == TAGGING
    assert body["status"] == "completed"


@pytest.mark.model
def test_input_tokens_accepts_the_tagging_id():
    require_model()
    resp = httpx.post(f"{BASE_URL}/v1/responses/input_tokens",
                      json={"model": TAGGING, "input": "hello there"}, timeout=TIMEOUT)
    # 200 with a count on macOS 26.4+, an honest 501 below (no tokenizer API).
    assert resp.status_code in (200, 501), resp.text
    if resp.status_code == 200:
        assert resp.json()["input_tokens"] > 0


@pytest.mark.model
def test_tagging_model_gets_no_mcp_tools():
    """The MCP server (11435) auto-executes calculator tools for the general
    model; the tagging model must never be handed them (it would only tag)."""
    require_model()
    resp = _chat({"model": TAGGING, "messages": [
        {"role": "user", "content": "What is 17 times 23? Use the calculator."}]}, base=MCP_URL)
    assert resp.status_code == 200, resp.text
    message = resp.json()["choices"][0]["message"]
    assert not message.get("tool_calls")
    assert "391" not in (message.get("content") or "")
