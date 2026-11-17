"""The guided tool step (#533, #580, #581): client tool calls on
/v1/chat/completions are generated under a JSON schema by default
(`--tool-calling guided`); `--tool-calling text` keeps the free-text format.

Model tests use prompts that were 20/20 on macOS 27.0.1 and 26.1 in the
2026-11-17 measurement (calculator, tool_choice, a tool-result turn), so a
failure here is a regression, not model noise.
"""

import json
import pathlib
import signal
import subprocess

import httpx
import pytest

from conftest import _start_server, require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://127.0.0.1:11434"
TEXT_PORT = 11438
TIMEOUT = 180

CALC = {"type": "function", "function": {
    "name": "calculate", "description": "Calculates/evaluates the given expression.",
    "parameters": {"type": "object", "properties": {"expression": {"type": "string", "title": "Expression"}},
                   "required": ["expression"]}}}
WEATHER = {"type": "function", "function": {
    "name": "get_weather", "description": "Get the current weather for a city.",
    "parameters": {"type": "object", "properties": {"city": {"type": "string", "minLength": 1}},
                   "required": ["city"], "additionalProperties": False}}}


def _chat(payload, base=BASE_URL):
    return httpx.post(f"{base}/v1/chat/completions",
                      json={"model": "apple-foundationmodel", **payload}, timeout=TIMEOUT)


def _only_call(body):
    msg = body["choices"][0]["message"]
    assert body["choices"][0]["finish_reason"] == "tool_calls", body
    assert msg["content"] is None, body
    assert len(msg["tool_calls"]) == 1, body
    call = msg["tool_calls"][0]
    assert call["type"] == "function" and call["id"].startswith("call_")
    return call["function"]["name"], json.loads(call["function"]["arguments"])  # strict JSON


# --- model-free -------------------------------------------------------------

def test_unknown_tool_calling_value_is_a_usage_error():
    out = subprocess.run([str(BINARY), "--serve", "--tool-calling", "native"], capture_output=True,
                         text=True, stdin=subprocess.DEVNULL, timeout=30)
    assert out.returncode == 2, out
    assert "--tool-calling" in out.stderr and "guided" in out.stderr


def test_help_documents_tool_calling():
    out = subprocess.run([str(BINARY), "--help"], capture_output=True, text=True,
                         stdin=subprocess.DEVNULL, timeout=30, env={"NO_COLOR": "1", "PATH": "/usr/bin:/bin"})
    assert "--tool-calling" in out.stdout


# --- model: guided (the default) -------------------------------------------

@pytest.mark.model
def test_guided_call_has_schema_arguments_and_strict_json():
    require_model()
    r = _chat({"messages": [{"role": "user", "content": "What's 17 times 23?"}], "tools": [CALC]})
    assert r.status_code == 200, r.text
    name, args = _only_call(r.json())
    assert name == "calculate"
    assert set(args) == {"expression"}, args
    usage = r.json()["usage"]
    assert usage["prompt_tokens"] > 0 and usage["completion_tokens"] > 0


@pytest.mark.model
def test_guided_call_streams_as_openai_tool_call_chunks():
    require_model()
    payload = {"model": "apple-foundationmodel", "stream": True,
               "stream_options": {"include_usage": True},
               "messages": [{"role": "user", "content": "What's 17 times 23?"}], "tools": [CALC]}
    chunks = []
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions", json=payload, timeout=TIMEOUT) as r:
        assert r.status_code == 200
        for line in r.iter_lines():
            if line.startswith("data: ") and line != "data: [DONE]":
                chunks.append(json.loads(line[6:]))
    deltas = [c["choices"][0] for c in chunks if c["choices"]]
    assert deltas[0]["delta"].get("role") == "assistant"
    calls = [d["delta"]["tool_calls"] for d in deltas if d["delta"].get("tool_calls")]
    assert len(calls) == 1 and calls[0][0]["function"]["name"] == "calculate"
    json.loads(calls[0][0]["function"]["arguments"])
    finishes = [d["finish_reason"] for d in deltas if d["finish_reason"]]
    assert finishes == ["tool_calls"]
    assert chunks[-1]["usage"]["prompt_tokens"] > 0
    assert not any(d["delta"].get("content") for d in deltas)


@pytest.mark.model
def test_guided_named_tool_choice_calls_that_tool_with_its_required_argument():
    require_model()
    r = _chat({"messages": [{"role": "user", "content": "I am planning a trip to Kyoto."}],
               "tools": [CALC, WEATHER],
               "tool_choice": {"type": "function", "function": {"name": "get_weather"}}})
    assert r.status_code == 200, r.text
    name, args = _only_call(r.json())
    assert name == "get_weather"
    assert set(args) == {"city"} and args["city"].strip(), args


@pytest.mark.model
def test_guided_answer_after_a_tool_result_is_plain_content():
    require_model()
    messages = [
        {"role": "user", "content": "What's 17 times 23?"},
        {"role": "assistant", "content": None, "tool_calls": [{"id": "call_1", "type": "function",
            "function": {"name": "calculate", "arguments": "{\"expression\": \"17 * 23\"}"}}]},
        {"role": "tool", "tool_call_id": "call_1", "content": "391"},
    ]
    r = _chat({"messages": messages, "tools": [CALC]})
    assert r.status_code == 200, r.text
    choice = r.json()["choices"][0]
    assert choice["finish_reason"] == "stop", choice
    assert "391" in choice["message"]["content"]
    assert not choice["message"].get("tool_calls")


# --- model: --tool-calling text --------------------------------------------

@pytest.fixture(scope="module")
def text_server():
    proc = _start_server(TEXT_PORT, ["--tool-calling", "text"])
    if proc is None:
        pytest.fail(f"Could not start apfel --tool-calling text on port {TEXT_PORT}")
    yield f"http://127.0.0.1:{TEXT_PORT}"
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


@pytest.mark.model
def test_text_format_still_returns_tool_calls(text_server):
    require_model()
    r = _chat({"messages": [{"role": "user", "content": "I am planning a trip to Kyoto."}],
               "tools": [WEATHER], "tool_choice": "required"}, base=text_server)
    assert r.status_code == 200, r.text
    name, args = _only_call(r.json())
    assert name == "get_weather" and "city" in args
