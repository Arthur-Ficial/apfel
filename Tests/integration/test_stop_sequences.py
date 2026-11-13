"""
apfel Integration Tests - OpenAI `stop` sequences and CLI `--stop` (#483).

Model-free (run on CI): request validation (string / array / null / empty /
too many / too long / wrong type), the plain-text-only combination rules
(client tools, MCP tools on 11435, json_object, json_schema), /v1/models
advertising, CLI flag errors (exit 2), and permit release after 400s.

Model (`@pytest.mark.model`, local `make test` / release only): live HTTP
non-streaming + streaming, a LangChain ReAct-shaped request via the openai
client, CLI plain + --stream, and permit release after a stop match.

The stop delimiter in the model tests is "5" in a counting prompt: any
counting answer that reaches 5 must be cut right before it, and nothing
after it may be delivered. Seeds rotate past answers that never count to 5
(a model outcome, not an apfel defect).

Run: python3 -m pytest Tests/integration/test_stop_sequences.py -v
"""

import json
import os
import pathlib
import subprocess
import time

import httpx
import pytest

from conftest import GUARDRAIL_SEEDS, is_guardrail_refusal, require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://localhost:11434"
MCP_URL = "http://localhost:11435"
MODEL = "apple-foundationmodel"

COUNT_PROMPT = "Count from 1 to 12. Write only the numbers, separated by single spaces, nothing else."
COUNT_STOP = "5"


def _post(payload, base=BASE_URL, timeout=10):
    return httpx.post(f"{base}/v1/chat/completions", json=payload, timeout=timeout)


def _body(**extra):
    payload = {"model": MODEL, "messages": [{"role": "user", "content": "Hello."}]}
    payload.update(extra)
    return payload


def _assert_stop_400(resp, needle):
    assert resp.status_code == 400, resp.text
    err = resp.json()["error"]
    assert err["type"] == "invalid_request_error", err
    assert err["param"] == "stop", err
    assert needle in err["message"], err


def _run_cli(args, timeout=60, env=None):
    merged = os.environ.copy()
    for key in ["NO_COLOR", "APFEL_SYSTEM_PROMPT", "APFEL_MCP", "APFEL_TEMPERATURE", "APFEL_MAX_TOKENS"]:
        merged.pop(key, None)
    if env:
        merged.update(env)
    return subprocess.run(
        [str(BINARY), *args],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        env=merged,
        timeout=timeout,
    )


def _active_requests():
    resp = httpx.get(f"{BASE_URL}/health", timeout=5)
    assert resp.status_code == 200
    return resp.json()["active_requests"]


def _sse_events(resp_text):
    events = []
    for line in resp_text.splitlines():
        if not line.startswith("data: "):
            continue
        data = line[len("data: "):]
        events.append(data if data == "[DONE]" else json.loads(data))
    return events


def _stream_content(events):
    parts = []
    for ev in events:
        if ev == "[DONE]" or not ev.get("choices"):
            continue
        delta = ev["choices"][0].get("delta") or {}
        if delta.get("content"):
            parts.append(delta["content"])
    return parts


def _finish_reason(events):
    reasons = [ev["choices"][0].get("finish_reason")
               for ev in events if ev != "[DONE]" and ev.get("choices")]
    return [r for r in reasons if r]


def _counted_to_stop(content):
    """A usable counting answer: reached 4 and was cut before 5."""
    return content is not None and "4" in content and not is_guardrail_refusal(content)


# ============================================================================
# Model-free: validation
# ============================================================================

def test_stop_empty_string_rejected():
    _assert_stop_400(_post(_body(stop="")), "non-empty")


def test_stop_empty_string_in_array_rejected():
    _assert_stop_400(_post(_body(stop=["END", ""])), "non-empty")


def test_stop_too_many_rejected():
    _assert_stop_400(_post(_body(stop=["a", "b", "c", "d", "e"])), "at most 4")


def test_stop_too_long_rejected():
    _assert_stop_400(_post(_body(stop=["x" * 257])), "256")


def test_stop_wrong_type_rejected():
    _assert_stop_400(_post(_body(stop=42)), "string or an array of strings")
    _assert_stop_400(_post(_body(stop={"a": "b"})), "string or an array of strings")


def test_stop_non_string_entry_rejected():
    _assert_stop_400(_post(_body(stop=["END", 7])), "index 1")


def test_stop_with_client_tools_rejected():
    tools = [{"type": "function", "function": {"name": "add", "parameters": {"type": "object"}}}]
    _assert_stop_400(_post(_body(stop="END", tools=tools)), "tool_choice")


def test_stop_with_json_object_rejected():
    _assert_stop_400(_post(_body(stop="END", response_format={"type": "json_object"})), "json_object")


def test_stop_with_json_schema_rejected():
    rf = {"type": "json_schema", "json_schema": {"name": "x", "schema": {"type": "object"}}}
    _assert_stop_400(_post(_body(stop="END", response_format=rf)), "json_schema")


def test_stop_with_mcp_server_tools_rejected():
    """The 11435 server has MCP tools attached: they are in scope for every request."""
    _assert_stop_400(_post(_body(stop="END"), base=MCP_URL), "--mcp")


def test_stop_validation_error_streaming_is_400_json():
    resp = _post(_body(stop="", stream=True))
    _assert_stop_400(resp, "non-empty")


def test_models_advertise_stop_as_supported():
    resp = httpx.get(f"{BASE_URL}/v1/models", timeout=10)
    assert resp.status_code == 200
    entry = resp.json()["data"][0]
    assert "stop" in entry["supported_parameters"], entry
    assert "stop" not in entry["unsupported_parameters"], entry


@pytest.mark.serial
def test_stop_validation_failures_release_permits():
    """400s for bad stop values, streaming or not, leak no concurrency permit (#213)."""
    for stream in (False, True, False, True, False):
        assert _post(_body(stop=["a", "b", "c", "d", "e"], stream=stream)).status_code == 400
    assert _active_requests() == 0


# ============================================================================
# Model-free: CLI flag errors (exit 2)
# ============================================================================

def test_cli_stop_empty_is_usage_error():
    r = _run_cli(["--stop", "", "hi"])
    assert r.returncode == 2, r.stderr
    assert "--stop requires a non-empty stop sequence" in r.stderr


def test_cli_stop_with_chat_is_usage_error():
    r = _run_cli(["--chat", "--stop", "END"])
    assert r.returncode == 2, r.stderr
    assert "cannot combine with --chat" in r.stderr


def test_cli_stop_with_mcp_is_usage_error():
    r = _run_cli(["--mcp", str(ROOT / "mcp" / "calculator" / "server.py"), "--stop", "END", "hi"])
    assert r.returncode == 2, r.stderr
    assert "--stop cannot be combined with MCP tool calling" in r.stderr


def test_cli_stop_too_many_is_usage_error():
    args = []
    for s in ["a", "b", "c", "d", "e"]:
        args += ["--stop", s]
    r = _run_cli(args + ["hi"])
    assert r.returncode == 2, r.stderr
    assert "at most 4" in r.stderr


def test_cli_help_lists_stop():
    r = _run_cli(["--help"])
    assert r.returncode == 0
    assert "--stop <text>" in r.stdout


# ============================================================================
# Model: live HTTP
# ============================================================================

def _post_rotating(payload, timeout=120):
    """Non-streaming POST rotating seeds until the model counts up to the stop."""
    last = None
    for seed in GUARDRAIL_SEEDS:
        body = dict(payload, seed=seed)
        resp = _post(body, timeout=timeout)
        assert resp.status_code == 200, resp.text
        data = resp.json()
        last = data["choices"][0]["message"]["content"]
        if _counted_to_stop(last):
            return data
    pytest.fail(f"model never counted to the stop on seeds {GUARDRAIL_SEEDS}; last: {last!r}")


def _stream_rotating(payload, timeout=120):
    last = None
    for seed in GUARDRAIL_SEEDS:
        body = dict(payload, seed=seed, stream=True)
        resp = _post(body, timeout=timeout)
        assert resp.status_code == 200, resp.text
        events = _sse_events(resp.text)
        parts = _stream_content(events)
        last = "".join(parts)
        if _counted_to_stop(last):
            return events, parts
    pytest.fail(f"model never counted to the stop on seeds {GUARDRAIL_SEEDS}; last: {last!r}")


@pytest.mark.model
def test_stop_non_streaming_cuts_before_delimiter():
    require_model()
    data = _post_rotating(_body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                                stop=[COUNT_STOP], temperature=0))
    content = data["choices"][0]["message"]["content"]
    assert COUNT_STOP not in content, content
    for later in ("6", "7", "8", "9"):
        assert later not in content, f"text after the delimiter was delivered: {content!r}"
    assert data["choices"][0]["finish_reason"] == "stop"


@pytest.mark.model
def test_stop_non_streaming_stops_generation_early():
    """Usage reflects a cut generation, not a full count to 12 (on macOS 27 the
    runtime-reported tokens of the consumed snapshots, on 26 the delivered text)."""
    require_model()
    data = _post_rotating(_body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                                stop=COUNT_STOP, temperature=0))
    assert data["usage"]["completion_tokens"] < 20, data["usage"]


@pytest.mark.model
def test_stop_streaming_never_leaks_delimiter():
    require_model()
    events, parts = _stream_rotating(_body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                                           stop=[COUNT_STOP], temperature=0))
    content = "".join(parts)
    for part in parts:
        assert COUNT_STOP not in part, f"delimiter fragment streamed: {parts!r}"
    for later in ("6", "7", "8", "9"):
        assert later not in content, f"withheld text was emitted: {parts!r}"
    assert _finish_reason(events) == ["stop"], events
    assert events[-1] == "[DONE]"


@pytest.mark.model
def test_stop_streaming_and_non_streaming_deliver_the_same_text():
    """Same seed, temperature 0: the delivered text is identical on both paths."""
    require_model()
    payload = _body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                    stop=[COUNT_STOP], temperature=0)
    for seed in GUARDRAIL_SEEDS:
        resp = _post(dict(payload, seed=seed), timeout=120)
        assert resp.status_code == 200, resp.text
        whole = resp.json()["choices"][0]["message"]["content"]
        if not _counted_to_stop(whole):
            continue
        resp = _post(dict(payload, seed=seed, stream=True), timeout=120)
        assert resp.status_code == 200, resp.text
        streamed = "".join(_stream_content(_sse_events(resp.text)))
        assert streamed == whole
        return
    pytest.fail(f"model never counted to the stop on seeds {GUARDRAIL_SEEDS}")


@pytest.mark.model
def test_stop_unmatched_delivers_full_answer():
    """A delimiter the model never produces changes nothing: full answer, finish stop."""
    require_model()
    resp = _post(_body(messages=[{"role": "user", "content": "Say hello in one short sentence."}],
                       stop=["☃☃☃"], seed=42), timeout=120)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["choices"][0]["message"]["content"].strip()
    assert data["choices"][0]["finish_reason"] == "stop"


@pytest.mark.model
def test_langchain_react_shaped_request_is_accepted():
    """LangChain's classic ReAct agent binds stop=["\\nObservation"] via the openai client."""
    require_model()
    from openai import OpenAI

    client = OpenAI(base_url=f"{BASE_URL}/v1", api_key="unused")
    prompt = (
        "Answer the following question using this format:\n\n"
        "Thought: you should always think about what to do\n"
        "Action: the action to take, one of [search]\n"
        "Action Input: the input to the action\n"
        "Observation: the result of the action\n\n"
        "Begin!\n\nQuestion: What is the capital of Austria?\nThought:"
    )
    for seed in GUARDRAIL_SEEDS:
        completion = client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": prompt}],
            stop=["\nObservation"],
            temperature=0,
            n=1,
            seed=seed,
        )
        content = completion.choices[0].message.content or ""
        if is_guardrail_refusal(content):
            continue
        assert "\nObservation" not in content, content
        assert completion.choices[0].finish_reason == "stop"
        return
    pytest.fail("model refused the ReAct prompt on every seed")


@pytest.mark.model
@pytest.mark.serial
def test_stop_match_releases_permit():
    """A stop match ends the request: no active request remains afterwards."""
    require_model()
    _stream_rotating(_body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                           stop=[COUNT_STOP], temperature=0))
    _post_rotating(_body(messages=[{"role": "user", "content": COUNT_PROMPT}],
                         stop=[COUNT_STOP], temperature=0))
    deadline = time.time() + 5
    while _active_requests() != 0 and time.time() < deadline:
        time.sleep(0.1)
    assert _active_requests() == 0


# ============================================================================
# Model: live CLI
# ============================================================================

def _cli_rotating(extra, extract=lambda out: out):
    last = None
    for seed in GUARDRAIL_SEEDS:
        r = _run_cli(["--seed", str(seed), "--temperature", "0", "--stop", COUNT_STOP, *extra, COUNT_PROMPT], timeout=120)
        if r.returncode == 3:
            continue
        assert r.returncode == 0, r.stderr
        last = extract(r.stdout)
        if _counted_to_stop(last):
            return r
    pytest.fail(f"CLI never counted to the stop on seeds {GUARDRAIL_SEEDS}; last: {last!r}")


@pytest.mark.model
def test_cli_stop_plain():
    require_model()
    r = _cli_rotating([])
    assert COUNT_STOP not in r.stdout, r.stdout
    for later in ("6", "7", "8", "9"):
        assert later not in r.stdout, r.stdout


@pytest.mark.model
def test_cli_stop_stream():
    require_model()
    r = _cli_rotating(["--stream"])
    assert COUNT_STOP not in r.stdout, r.stdout
    for later in ("6", "7", "8", "9"):
        assert later not in r.stdout, r.stdout


@pytest.mark.model
def test_cli_stop_json_output():
    require_model()
    r = _cli_rotating(["-o", "json"], extract=lambda out: json.loads(out)["content"])
    content = json.loads(r.stdout)["content"]
    assert COUNT_STOP not in content, content
    assert json.loads(r.stdout)["finish_reason"] == "stop", r.stdout


# ============================================================================
# Model: --stop together with --require-complete / --max-tokens (#484)
# A matched delimiter is finish_reason=stop: complete, exit 0. The match is
# observed, not estimated, so it is exact on every OS, also where an explicit
# --max-tokens cap is only a chars/4 estimate (macOS < 26.4).
# ============================================================================

_EXACT_FINISH_SIGNAL = None


def _exact_finish_signal():
    """Whether this Mac detects an explicit --max-tokens cap exactly, read from
    the binary's own #315 capability report (same as cli_e2e_test.py)."""
    global _EXACT_FINISH_SIGNAL
    if _EXACT_FINISH_SIGNAL is None:
        r = _run_cli(["--count-tokens", "-o", "json", "hello"], timeout=30)
        assert r.returncode == 0, r.stderr
        _EXACT_FINISH_SIGNAL = "macOS 26.4" not in r.stderr
    return _EXACT_FINISH_SIGNAL


def _json_content(out):
    return json.loads(out)["content"]


@pytest.mark.model
def test_cli_stop_with_require_complete_is_complete():
    require_model()
    r = _cli_rotating(["--require-complete", "-o", "json"], extract=_json_content)
    envelope = json.loads(r.stdout)
    assert COUNT_STOP not in envelope["content"], envelope
    assert envelope["finish_reason"] == "stop", envelope


@pytest.mark.model
def test_cli_stop_with_require_complete_stream_is_complete():
    require_model()
    r = _cli_rotating(["--require-complete", "--stream"])
    assert COUNT_STOP not in r.stdout, r.stdout


@pytest.mark.model
def test_cli_matched_stop_with_cap_reports_stop_on_every_os():
    """Default mode, explicit cap, delimiter matched well before the cap: the
    envelope says stop everywhere, never the macOS < 26.4 'unknown' omission."""
    require_model()
    r = _cli_rotating(["--max-tokens", "64", "-o", "json"], extract=_json_content)
    envelope = json.loads(r.stdout)
    assert envelope.get("finish_reason") == "stop", (envelope, r.stderr)
    assert "cannot tell whether" not in r.stderr, r.stderr


@pytest.mark.model
def test_cli_stop_require_complete_with_cap():
    """--require-complete with an explicit cap: exact Macs run it and a matched
    stop is complete (exit 0); Macs without an exact cap signal still refuse
    up front (exit 2), because an unmatched run could not be judged."""
    require_model()
    if _exact_finish_signal():
        r = _cli_rotating(["--require-complete", "--max-tokens", "64", "-o", "json"], extract=_json_content)
        assert json.loads(r.stdout)["finish_reason"] == "stop", r.stdout
    else:
        r = _run_cli(["--stop", COUNT_STOP, "--require-complete", "--max-tokens", "64", COUNT_PROMPT], timeout=60)
        assert r.returncode == 2, r.stderr
        assert r.stdout == "", r.stdout
        assert "macOS 26.4" in r.stderr, r.stderr
