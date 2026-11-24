"""The guided tool step on the other tool paths (#590 item 1): server
--mcp auto-execution, /v1/responses function tools, and the CLI --mcp
path all run the guided decision by default (`--tool-calling guided`);
`--tool-calling text` keeps the free-text format everywhere, including
the CLI.

Model prompts follow the 2026-11-17 measurement: the calculator
arithmetic prompts and "Hello" were the reliable ones on macOS 27.0.1,
so a failure here is a regression, not model noise. Servers started by
this file use ports 11450-11451 only.
"""

import json
import pathlib
import signal
import subprocess
import tempfile
import time

import httpx
import pytest

from conftest import GUARDRAIL_SEEDS, MCP_SERVER, is_guardrail_refusal, require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
GUIDED_PORT = 11450
TEXT_PORT = 11451
MODEL = "apple-foundationmodel"
TIMEOUT = 180

CALC_TOOL = {
    "type": "function",
    "name": "calculate",
    "description": "Calculates/evaluates the given expression.",
    "parameters": {"type": "object",
                   "properties": {"expression": {"type": "string", "title": "Expression"}},
                   "required": ["expression"]},
}


def _mcp_server_with_log(port, extra_args=()):
    """Start apfel --serve --mcp calculator on `port`; return (proc, read_log).

    Output goes to a temp file so tests can assert on the event log
    (same pattern as mcp_server_test._running_mcp_server_with_log)."""
    log_file = tempfile.NamedTemporaryFile(  # noqa: SIM115 - closed in fixture teardown
        mode="w+", encoding="utf-8", delete=False)
    proc = subprocess.Popen(
        [str(BINARY), "--serve", "--port", str(port), "--mcp", str(MCP_SERVER), *extra_args],
        stdout=log_file, stderr=log_file, text=True)
    url = f"http://127.0.0.1:{port}"
    for _ in range(20):
        if proc.poll() is not None:
            break
        try:
            if httpx.get(f"{url}/health", timeout=2).status_code == 200:
                def read_log():
                    log_file.flush()
                    with open(log_file.name, "r", encoding="utf-8") as fh:
                        return fh.read()
                return proc, read_log
        except httpx.HTTPError:
            pass
        time.sleep(0.5)
    proc.kill()
    proc.wait()
    pytest.fail(f"Could not start apfel --serve --mcp on port {port}")


def _stop(proc):
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


@pytest.fixture(scope="module")
def guided_mcp():
    """Guided (default) MCP server on 11450; yields (base_url, read_log)."""
    proc, read_log = _mcp_server_with_log(GUIDED_PORT)
    yield f"http://127.0.0.1:{GUIDED_PORT}", read_log
    _stop(proc)


@pytest.fixture(scope="module")
def text_mcp():
    """--tool-calling text MCP server on 11451; yields (base_url, read_log)."""
    proc, read_log = _mcp_server_with_log(TEXT_PORT, ["--tool-calling", "text"])
    yield f"http://127.0.0.1:{TEXT_PORT}", read_log
    _stop(proc)


def _chat(base, payload, stream=False):
    body = {"model": MODEL, **payload}
    if stream:
        body["stream"] = True
    return httpx.post(f"{base}/v1/chat/completions", json=body, timeout=TIMEOUT)


def _chat_rotating(base, payload):
    """Rotate seeds past guardrail refusals; return the parsed body."""
    data = None
    for seed in GUARDRAIL_SEEDS:
        r = _chat(base, {**payload, "seed": seed})
        assert r.status_code == 200, r.text
        data = r.json()
        content = data["choices"][0]["message"].get("content") or ""
        if not is_guardrail_refusal(content):
            return data
    pytest.fail(f"every seed refused; last: {data}")


# --- model-free --------------------------------------------------------------

def test_tool_calling_flag_is_valid_without_serve():
    # #590: the flag now applies to the CLI --mcp path, so a prompt-mode
    # invocation must not reject it as a usage error. Bad values still are.
    out = subprocess.run([str(BINARY), "--tool-calling", "native", "hi"],
                         capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=30)
    assert out.returncode == 2, out
    assert "--tool-calling" in out.stderr and "guided" in out.stderr


def test_man_page_scopes_tool_calling_beyond_serve():
    man = (ROOT / "man" / "apfel.1.in").read_text(encoding="utf-8")
    flag_section = man.split("\\-\\-tool-calling", 1)[1][:400]
    assert "mcp" in flag_section.lower(), flag_section


# --- model: server --mcp auto-execution --------------------------------------

@pytest.mark.model
def test_mcp_first_round_is_guided_by_default(guided_mcp):
    require_model()
    base, read_log = guided_mcp
    data = _chat_rotating(base, {"messages": [
        {"role": "user", "content": "What's 17 times 23?"}]})
    choice = data["choices"][0]
    assert choice["finish_reason"] == "stop", choice
    assert "391" in (choice["message"]["content"] or ""), choice
    assert not choice["message"].get("tool_calls"), choice
    time.sleep(0.5)
    log = read_log()
    assert "guided tool step" in log, "expected the guided step event in the server log"
    assert "mcp tool:" in log, "expected the decided call to be executed"


@pytest.mark.model
def test_mcp_guided_streaming_delivers_the_answer(guided_mcp):
    require_model()
    base, _ = guided_mcp
    content, finish = "", None
    for seed in GUARDRAIL_SEEDS:
        r = _chat(base, {"messages": [
            {"role": "user", "content": "What is 1234 + 5678?"}], "seed": seed}, stream=True)
        assert r.status_code == 200, r.text
        content, finish = "", None
        for line in r.text.strip().split("\n"):
            if not line.startswith("data: ") or line == "data: [DONE]":
                continue
            chunk = json.loads(line[6:])
            for choice in chunk.get("choices", []):
                content += choice.get("delta", {}).get("content") or ""
                finish = choice.get("finish_reason") or finish
        if not is_guardrail_refusal(content):
            break
    assert finish == "stop"
    assert "6912" in content, content
    assert '"tool_calls"' not in content, f"raw tool JSON leaked: {content[:200]}"


@pytest.mark.model
def test_mcp_guided_usage_includes_the_step(guided_mcp):
    require_model()
    base, _ = guided_mcp
    data = _chat_rotating(base, {"messages": [
        {"role": "user", "content": "What's 17 times 23?"}]})
    usage = data["usage"]
    assert usage["prompt_tokens"] > 0 and usage["completion_tokens"] > 0, usage
    assert usage["total_tokens"] == usage["prompt_tokens"] + usage["completion_tokens"], usage


@pytest.mark.model
def test_mcp_text_mode_skips_the_guided_step(text_mcp):
    require_model()
    base, read_log = text_mcp
    data = _chat_rotating(base, {"messages": [
        {"role": "user", "content": "What's 17 times 23?"}]})
    assert "391" in (data["choices"][0]["message"]["content"] or ""), data
    time.sleep(0.5)
    assert "guided tool step" not in read_log(), \
        "--tool-calling text must not run the guided step"


# --- model: /v1/responses function tools -------------------------------------

@pytest.mark.model
def test_responses_function_call_is_guided_by_default(guided_mcp):
    require_model()
    base, read_log = guided_mcp
    r = httpx.post(f"{base}/v1/responses", json={
        "model": MODEL, "input": "What's 17 times 23?", "tools": [CALC_TOOL]},
        timeout=TIMEOUT)
    assert r.status_code == 200, r.text
    calls = [item for item in r.json()["output"] if item["type"] == "function_call"]
    assert len(calls) == 1, r.json()["output"]
    assert calls[0]["name"] == "calculate"
    assert calls[0]["status"] == "completed"
    assert calls[0]["call_id"].startswith("call_")
    args = json.loads(calls[0]["arguments"])  # strict JSON, schema argument names
    assert set(args) == {"expression"}, args
    usage = r.json()["usage"]
    assert usage["input_tokens"] > 0 and usage["output_tokens"] > 0, usage
    time.sleep(0.5)
    assert "guided tool step" in read_log()


@pytest.mark.model
def test_responses_guided_answer_is_a_plain_message(guided_mcp):
    require_model()
    base, _ = guided_mcp
    r = httpx.post(f"{base}/v1/responses", json={
        "model": MODEL, "input": "Hello", "tools": [CALC_TOOL]}, timeout=TIMEOUT)
    assert r.status_code == 200, r.text
    output = r.json()["output"]
    assert [item["type"] for item in output] == ["message"], output
    text = output[0]["content"][0]["text"]
    assert text.strip(), output


@pytest.mark.model
def test_responses_text_mode_keeps_free_text_detection(text_mcp):
    require_model()
    base, read_log = text_mcp
    # The subject is the flag, not the model: the guided step must not run.
    # A prompt that needs no tool, 20/20 in text mode on macOS 27.0.1 and
    # 26.1 (2026-11-24); the calculator prompt makes 26.1 write broken
    # escaping in text mode (0/20), which is a 500 unrelated to the flag.
    r = httpx.post(f"{base}/v1/responses", json={
        "model": MODEL, "input": "Write me a short story about a space adventure in three sentences.",
        "tools": [CALC_TOOL]},
        timeout=TIMEOUT)
    assert r.status_code == 200, r.text
    time.sleep(0.5)
    assert "guided tool step" not in read_log()


# --- model: CLI --mcp ---------------------------------------------------------

def _run_cli(args, timeout=TIMEOUT):
    return subprocess.run([str(BINARY), *args], capture_output=True, text=True,
                          stdin=subprocess.DEVNULL, timeout=timeout)


@pytest.mark.model
def test_cli_mcp_first_round_is_guided_by_default():
    require_model()
    result = None
    for seed in GUARDRAIL_SEEDS:
        result = _run_cli(["--debug", "--seed", str(seed),
                           "--mcp", str(MCP_SERVER), "What's 17 times 23?"])
        if result.returncode == 0 and not is_guardrail_refusal(result.stdout):
            break
    assert result.returncode == 0, result.stderr
    assert "391" in result.stdout, result.stdout
    assert "tool step decided: call" in result.stderr, result.stderr[-2000:]


@pytest.mark.model
def test_cli_mcp_guided_answer_streams_without_tools():
    require_model()
    result = None
    for seed in GUARDRAIL_SEEDS:
        result = _run_cli(["--debug", "--seed", str(seed), "--stream",
                           "--mcp", str(MCP_SERVER), "Hello"])
        if result.returncode == 0 and not is_guardrail_refusal(result.stdout):
            break
    assert result.returncode == 0, result.stderr
    assert "tool step decided: answer" in result.stderr, result.stderr[-2000:]
    assert result.stdout.strip(), "expected a plain answer on stdout"
    assert '"tool_calls"' not in result.stdout, result.stdout[:200]


@pytest.mark.model
def test_cli_tool_calling_text_keeps_the_free_text_format():
    require_model()
    result = None
    for seed in GUARDRAIL_SEEDS:
        result = _run_cli(["--debug", "--seed", str(seed), "--tool-calling", "text",
                           "--mcp", str(MCP_SERVER), "What's 17 times 23?"])
        if result.returncode == 0 and not is_guardrail_refusal(result.stdout):
            break
    assert result.returncode == 0, result.stderr
    assert "391" in result.stdout, result.stdout
    assert "tool step decided" not in result.stderr, result.stderr[-2000:]
