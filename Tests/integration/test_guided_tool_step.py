"""The guided tool step (#533, #580, #581): client tool calls on
/v1/chat/completions are generated under a JSON schema by default
(`--tool-calling guided`); `--tool-calling text` keeps the free-text format.

Model tests use prompts that were 20/20 on macOS 27.0.1 and 26.1 in the
2026-11-17 measurement (calculator, tool_choice, a tool-result turn), so a
failure here is a regression, not model noise.
"""

import json
import os
import pathlib
import signal
import subprocess

import httpx
import pytest

from conftest import _start_server, require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
# Defaults: the shared 11434 server (conftest) and a text server on 11438.
# Override both to run against servers you started yourself (e.g. while
# another worktree's run owns these ports):
#   APFEL_TEST_BASE=http://127.0.0.1:11456 APFEL_TEST_TEXT_PORT=11458
BASE_URL = os.environ.get("APFEL_TEST_BASE", "http://127.0.0.1:11434")
TEXT_PORT = int(os.environ.get("APFEL_TEST_TEXT_PORT", "11438"))
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


TIME = {"type": "function", "function": {
    "name": "get_current_time", "description": "Get current time in a specific timezone",
    "parameters": {"type": "object", "properties": {"timezone": {"type": "string",
        "description": "IANA timezone name (e.g., 'America/New_York', 'Europe/London')."}}}}}


SIX_TOOLS = [CALC, WEATHER, TIME] + [
    {"type": "function", "function": {
        "name": name, "description": desc,
        "parameters": {"type": "object", "properties": {arg: {"type": "string", "description": desc}},
                       "required": [arg]}}}
    for name, arg, desc in [
        ("search_web", "query", "Search the web and return the top results for a natural language query."),
        ("fetch_page", "url", "Fetch a web page and return its readable content as markdown."),
        ("convert_currency", "amount", "Convert an amount of money between two currencies at today's rate."),
    ]
]
FILLER = "The quick brown fox jumps over the lazy dog near the quiet river bank. "


def _overflows(base, repeats):
    # One user turn, no history: nothing for the trimming strategy to drop,
    # so the pre-generation budget check decides. max_tokens only caps the
    # visible answer; the output reserve is fixed by the server.
    r = _chat({"messages": [{"role": "user", "content": "Summarize these notes in one line. " + FILLER * repeats}],
               "tools": SIX_TOOLS, "max_tokens": 8}, base=base)
    if r.status_code == 400 and "context_length_exceeded" in r.text:
        return True
    assert r.status_code == 200, r.text
    return False


@pytest.mark.model
def test_guided_step_that_does_not_fit_falls_back_to_free_text(text_server):
    # #590 item 2: the step schema plus the tool list cost tokens the
    # free-text format does not. A request free text can serve must not
    # become a 400 just because guided is the default.
    require_model()
    lo, hi = 1, 1500  # largest repeat count the free-text format still fits
    assert not _overflows(text_server, lo) and _overflows(text_server, hi)
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if _overflows(text_server, mid):
            hi = mid
        else:
            lo = mid
    assert not _overflows(BASE_URL, lo), f"guided overflowed at {lo} repeats, free text fits"


@pytest.mark.model
def test_text_format_still_returns_tool_calls(text_server):
    # The one prompt the free-text format got right 40/40 on macOS 27.0.1
    # and 26.1 (2026-11-17); the 26.1 model writes a degenerate envelope for
    # several others, which is why guided is the default.
    require_model()
    r = _chat({"messages": [{"role": "user", "content": "What time is it in Tokyo?"}],
               "tools": [TIME]}, base=text_server)
    assert r.status_code == 200, r.text
    name, args = _only_call(r.json())
    assert name == "get_current_time" and set(args) <= {"timezone"}, args
