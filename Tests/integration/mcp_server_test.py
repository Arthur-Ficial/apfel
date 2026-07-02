"""
apfel Integration Tests -- MCP auto-execution in server mode

Validates that when apfel --serve --mcp <server> receives a chat completion
request WITHOUT client-provided tools, it auto-executes MCP tool calls and
returns the final text answer (not raw tool_calls).

Requires: pip install pytest httpx
Requires: apfel --serve --mcp mcp/calculator/server.py running on localhost:11435

Run: python3 -m pytest Tests/integration/mcp_server_test.py -v

Speed optimization: module-scoped fixtures cache LLM responses so multiple
tests that check different aspects of the same response share a single call.
"""

import json
import contextlib
import pathlib
import pytest
import httpx
import socket
import subprocess
import tempfile
import time

BASE_URL = "http://localhost:11435"
API_URL = f"{BASE_URL}/v1"
MODEL = "apple-foundationmodel"
TIMEOUT = 60
ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
FIXTURES = ROOT / "Tests" / "integration" / "fixtures"


def collect_sse(resp):
    """Parse SSE response into content, finish_reason, and raw chunks."""
    content = ""
    finish_reason = None
    saw_tool_calls = False
    chunks = []

    for line in resp.text.strip().split("\n"):
        if not line.startswith("data: "):
            continue
        payload = line[len("data: "):]
        if payload == "[DONE]":
            break
        chunk = json.loads(payload)
        chunks.append(chunk)
        choices = chunk.get("choices", [])
        if choices:
            choice = choices[0]
            delta = choice.get("delta", {})
            if delta.get("content"):
                content += delta["content"]
            if delta.get("tool_calls"):
                saw_tool_calls = True
            if choice.get("finish_reason"):
                finish_reason = choice["finish_reason"]

    return content, finish_reason, saw_tool_calls, chunks


def assert_no_raw_tool_calls(content):
    """Verify response content doesn't contain leaked tool_calls JSON."""
    if content:
        # Raw tool_calls JSON leak indicators
        assert '"tool_calls"' not in content, \
            f"Response leaked raw tool_calls JSON: {content[:200]}"


def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for_server(base_url, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            resp = httpx.get(f"{base_url}/health", timeout=1)
            if resp.status_code == 200:
                return
        except httpx.HTTPError:
            pass
        time.sleep(0.2)
    raise TimeoutError(f"Timed out waiting for server at {base_url}")


@contextlib.contextmanager
def running_custom_mcp_server(mcp_script):
    port = find_free_port()
    with tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8") as log_file:
        proc = subprocess.Popen(
            [
                str(BINARY),
                "--serve",
                "--port",
                str(port),
                "--mcp",
                str(mcp_script),
            ],
            stdout=log_file,
            stderr=log_file,
            text=True,
        )
        base_url = f"http://127.0.0.1:{port}"
        try:
            wait_for_server(base_url)
            yield f"{base_url}/v1"
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


@contextlib.contextmanager
def running_mcp_servers(mcp_scripts):
    """Start apfel --serve with several --mcp servers; yield (api_url, read_log).

    read_log() returns the captured stdout+stderr so a test can assert on
    startup diagnostics (e.g. the tool-name collision warning, #239).
    """
    port = find_free_port()
    with tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8") as log_file:
        args = [str(BINARY), "--serve", "--port", str(port)]
        for script in mcp_scripts:
            args += ["--mcp", str(script)]
        proc = subprocess.Popen(args, stdout=log_file, stderr=log_file, text=True)
        base_url = f"http://127.0.0.1:{port}"

        def read_log():
            log_file.flush()
            with open(log_file.name, "r", encoding="utf-8") as fh:
                return fh.read()

        try:
            wait_for_server(base_url)
            yield f"{base_url}/v1", read_log
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


@contextlib.contextmanager
def running_mcp_server_with_env(mcp_script, extra_env):
    """Start apfel --serve --mcp <script> with extra env vars; yield read_log.

    Used to prove the local MCP subprocess env is scrubbed (#229): the parent
    apfel process is given secrets, and the fixture reflects what it could see
    through its tool names, which apfel prints on the startup banner.
    """
    import os as _os

    port = find_free_port()
    env = _os.environ.copy()
    env.update(extra_env)
    with tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8") as log_file:
        proc = subprocess.Popen(
            [str(BINARY), "--serve", "--port", str(port), "--mcp", str(mcp_script)],
            stdout=log_file,
            stderr=log_file,
            text=True,
            env=env,
        )
        base_url = f"http://127.0.0.1:{port}"

        def read_log():
            log_file.flush()
            with open(log_file.name, "r", encoding="utf-8") as fh:
                return fh.read()

        try:
            wait_for_server(base_url)
            yield read_log
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)


def test_local_mcp_subprocess_env_is_scrubbed():
    """Local MCP scripts must not inherit apfel/secret env vars (#229).

    Model-free: only exercises initialize + tools/list. The fixture names a
    ``leaked_*`` tool for every canary secret it can still see and a ``saw_*``
    tool for every allowlisted passthrough var; apfel prints the tool names on
    startup, so the banner reveals exactly what crossed the boundary.
    """
    secrets = {
        "APFEL_TOKEN": "server-secret-xyz",
        "APFEL_MCP_TOKEN": "mcp-secret-xyz",
        "TEST_CANARY_SECRET": "leak-secret",
        "TEST_CANARY_API_KEY": "leak-key",
        "TEST_CANARY_TOKEN": "leak-token",
        "PYTHONPATH": "/tmp/pythonpath-canary",
    }
    with running_mcp_server_with_env(
        FIXTURES / "env_echo_mcp_server.py", secrets
    ) as read_log:
        banner = read_log()
    # The fixture ran (handshake + tools/list succeeded).
    assert "env_report" in banner
    # No secret crossed into the child.
    assert "leaked_" not in banner, banner
    # Allowlisted PYTHON var still passed through so venv/FastMCP servers work.
    assert "saw_pythonpath" in banner
    # Baseline vars the child needs are present.
    assert "saw_path" in banner


# ============================================================================
# Module-scoped fixtures -- each makes ONE LLM call, shared across tests
# ============================================================================

@pytest.fixture(scope="module")
def health_response():
    """GET /health -- no LLM call, but cached for multiple tests."""
    resp = httpx.get(f"{BASE_URL}/health", timeout=TIMEOUT)
    return resp


@pytest.fixture(scope="module")
def multiply_247x83_response():
    """Non-streaming multiply 247*83 -- shared by auto-execute and result tests."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    return resp.json()


@pytest.fixture(scope="module")
def multiply_streaming_response():
    """Streaming multiply 13*7 -- tests streaming MCP auto-execute."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the multiply tool to compute 13 times 7. Reply with just the number."}
        ],
        "stream": True,
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    return collect_sse(resp)


@pytest.fixture(scope="module")
def normal_nonstreaming_response():
    """Non-streaming plain text -- shared by normal-response, id, and structure tests."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [{"role": "user", "content": "What is the capital of France? Reply in one word, no tools needed."}],
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    return resp.json()


@pytest.fixture(scope="module")
def normal_streaming_response():
    """Streaming 'Say hello.' -- shared by normal-streaming and SSE structure tests."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hello."}],
        "stream": True,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    return resp


@pytest.fixture(scope="module")
def add_tool_response():
    """Non-streaming add 100+200 -- shared by stop-not-tool_calls, usage, and
    result tests. Rotates seeds on guardrail refusal (#323)."""
    for seed in (42, 7, 123, 0, 99):
        resp = httpx.post(f"{API_URL}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the add function to add 100 and 200. Reply with just the number."}
            ],
            "seed": seed,
        }, timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        content = data["choices"][0]["message"]["content"] or ""
        if not _is_guardrail_refusal(content):
            return data
    pytest.fail(
        f"model guardrail-refused add(100,200) on every seed; last content: {content}"
    )


# ============================================================================
# Prerequisites
# ============================================================================

def test_mcp_server_health(health_response):
    """Server with MCP must be healthy and model available."""
    assert health_response.status_code == 200
    data = health_response.json()
    assert data["model_available"] is True


# ============================================================================
# Core: MCP auto-execution (the main fix for issue #35)
# ============================================================================

def test_mcp_auto_execute_non_streaming(multiply_247x83_response):
    """Server auto-executes MCP tool calls and returns final text (non-streaming).

    The key test: finish_reason must be 'stop' (not 'tool_calls') and the
    response must contain the correct computed result.
    """
    data = multiply_247x83_response
    assert data["choices"][0]["finish_reason"] == "stop", \
        f"Expected 'stop' but got '{data['choices'][0]['finish_reason']}'"
    content = data["choices"][0]["message"]["content"]
    assert content is not None, "Response content is None"
    assert "20501" in content or "20,501" in content, \
        f"Expected '20501' in response but got: {content}"


def test_mcp_auto_execute_streaming(multiply_streaming_response):
    """Server auto-executes MCP tool calls and returns final text (streaming).

    When MCP auto-executes, the SSE stream should contain the final text
    answer (not intermediate tool_calls chunks).
    """
    content, finish_reason, saw_tool_calls, _ = multiply_streaming_response

    assert not saw_tool_calls, "Server streamed raw tool_calls instead of auto-executing"
    assert finish_reason == "stop", f"Expected 'stop' but got '{finish_reason}'"
    # Model either uses tool (91) or computes directly -- either way should be correct
    assert len(content) > 0, "Empty streaming response"
    assert_no_raw_tool_calls(content)


# ============================================================================
# Normal responses must NOT be affected by MCP being enabled
# ============================================================================

def test_normal_response_not_affected_by_mcp(normal_nonstreaming_response):
    """Plain text prompt returns normal response when MCP is enabled."""
    data = normal_nonstreaming_response
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert content is not None
    assert len(content) > 0
    assert_no_raw_tool_calls(content)


def test_normal_streaming_not_affected_by_mcp(normal_streaming_response):
    """Streaming a normal response with MCP enabled works correctly."""
    content, finish_reason, _, _ = collect_sse(normal_streaming_response)
    assert finish_reason == "stop"
    assert len(content) > 0
    assert_no_raw_tool_calls(content)


def test_system_prompt_preserved_with_mcp():
    """System prompt still works when MCP tools are injected."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "system", "content": "Always respond in French."},
            {"role": "user", "content": "What is 2+2?"}
        ],
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert content is not None


def test_multi_turn_conversation_with_mcp():
    """Multi-turn conversation returns 200 with MCP tools enabled."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "What is 2+2?"},
            {"role": "assistant", "content": "4"},
            {"role": "user", "content": "And what is that plus 3?"}
        ],
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert content is not None
    assert len(content) > 0


# ============================================================================
# Client-provided tools must NOT be auto-executed
# ============================================================================

def test_client_tools_not_auto_executed():
    """Client-provided tools are returned as tool_calls (standard OpenAI flow).

    Auto-execution only applies to MCP-injected tools. Client tools are the
    client's responsibility to execute.
    """
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the get_weather function for Vienna."}
        ],
        "tools": [{
            "type": "function",
            "function": {
                "name": "get_weather",
                "description": "Get weather for a city",
                "parameters": {
                    "type": "object",
                    "properties": {"city": {"type": "string"}},
                    "required": ["city"]
                }
            }
        }],
        "tool_choice": {"type": "function", "function": {"name": "get_weather"}},
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "tool_calls", \
        f"Expected 'tool_calls' for client tools but got '{data['choices'][0]['finish_reason']}'"


def test_mcp_tool_iserror_is_fed_back_to_model_not_500():
    """An MCP `isError: true` tool result (e.g. divide by zero) is fed back to
    the model to recover, not aborted with HTTP 500 (#220).

    Per the MCP spec, execution errors "should be reported inside the result
    object ... so the LLM can see it and act". Previously apfel turned isError
    into a thrown MCPError.serverError -> HTTP 500. Now the request completes
    normally (200) with a natural-language answer; only transport/protocol
    failures (timeout, dead pipe) still surface as 500 (covered by the timeout
    and crashed-server tests below).
    """
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the divide tool to divide 10 by 0, then tell me what happened."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200, f"isError must no longer 500: {resp.status_code} {resp.text[:200]}"
    data = resp.json()
    choice = data["choices"][0]
    assert choice["finish_reason"] == "stop"
    content = choice["message"]["content"]
    assert content and content.strip(), "model must produce a recovery answer, not empty content"
    # The raw tool-call JSON must not leak to the client as the answer.
    assert '"tool_calls"' not in content


def test_mcp_tool_timeout_returns_structured_error():
    """A hung MCP tool must fail fast with a structured timeout error.

    max_tokens is set explicitly so the test isolates MCP timeout behaviour
    from the model-wandering latency that omitted max_tokens can introduce
    on the small on-device model.
    """
    with running_custom_mcp_server(FIXTURES / "hanging_mcp_server.py") as api_url:
        started = time.time()
        resp = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
            ],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=30)
        elapsed = time.time() - started

    assert elapsed < 25, f"Timed out too slowly: {elapsed:.2f}s"
    assert resp.status_code == 500
    data = resp.json()
    assert data["error"]["type"] == "server_error"
    message = data["error"]["message"].lower()
    assert "multiply" in message
    assert "timed out" in message


def test_mcp_crashed_server_does_not_kill_apfel():
    """A crashed MCP server must not take down the whole apfel process (#215).

    crashing_mcp_server.py answers the handshake (so the tool registers and the
    server is healthy) then exits before any tools/call. When the model then
    calls the tool, apfel writes to a pipe whose read end is closed. Before the
    fix that raised SIGPIPE and killed the whole --serve process (exit 141);
    now the write fails with a recoverable MCPError and the HTTP server stays up.
    """
    with running_custom_mcp_server(FIXTURES / "crashing_mcp_server.py") as api_url:
        base_url = api_url.rsplit("/", 1)[0]
        # A large product the on-device model will route to the tool rather than
        # computing in-head, so the write to the dead pipe actually happens.
        resp = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
            ],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=30)
        # The individual request surfaces a structured 500 (the dead pipe write
        # is a tool-execution failure), not a connection reset.
        assert resp.status_code == 500, f"Expected 500, got {resp.status_code}: {resp.text[:200]}"
        data = resp.json()
        assert data["error"]["type"] == "server_error"
        # The server must still be alive and serving after the crashed-pipe write.
        health = httpx.get(f"{base_url}/health", timeout=5)
        assert health.status_code == 200, "apfel server died after writing to a crashed MCP server (SIGPIPE)"
        assert health.json()["model_available"] is True


def test_mcp_duplicate_tool_names_warn_and_dedupe():
    """Two --mcp servers exposing the same tool name must warn loudly and keep
    the first registration; the shadowed duplicate is dropped (#239).

    Model-free: only inspects the startup diagnostics and /health, so it runs on
    CI too (no Apple Intelligence needed).
    """
    scripts = [FIXTURES / "dup_tool_server_a.py", FIXTURES / "dup_tool_server_b.py"]
    with running_mcp_servers(scripts) as (api_url, read_log):
        base_url = api_url.rsplit("/", 1)[0]
        health = httpx.get(f"{base_url}/health", timeout=5)
        assert health.status_code == 200
        log = read_log()

    # Loud collision warning naming the tool and both servers, first-wins.
    assert "shared_tool" in log, f"no collision warning for shared_tool in log:\n{log}"
    assert "dup_tool_server_a.py" in log
    assert "dup_tool_server_b.py" in log
    assert "ignoring" in log.lower(), f"warning must state the duplicate is ignored:\n{log}"
    # Both servers still registered their unique tools.
    assert "only_a" in log
    assert "only_b" in log


def test_mcp_server_chained_tool_calls_do_not_leak_json():
    """The server MCP auto-execute path must run the CLI's bounded re-detection
    loop: if the model answers the tool-result follow-up with another tool call,
    it is executed and re-prompted, and any trailing tool-call JSON is stripped
    on cap exhaustion - never returned as message.content with finish_reason
    stop (#240).
    """
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "First use the multiply tool to compute 6 times 7, then use the add tool to add 100 to that result. Give me the final number."}
        ],
        "seed": 42,
        "max_tokens": 300,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    choice = data["choices"][0]
    content = choice["message"]["content"]
    # Whether or not the model chains, raw tool-call protocol JSON must never
    # reach the client as the answer.
    assert '"tool_calls"' not in content, f"raw tool-call JSON leaked to client: {content[:300]}"
    assert content and content.strip(), "must produce a natural-language answer"


def test_mcp_huge_tool_output_is_truncated_not_fatal():
    """A tool result far larger than the 4096-token window must be truncated
    head+tail before the follow-up prompt, not overflow or be dropped (#221).

    Before the fix the un-truncated ~40 KB result overflowed the context window
    after the tool ran (CLI) or was dropped whole by the context trimmer while
    the prompt still referenced it (server -> hallucination). Now the request
    completes with a real answer instead of a context-overflow 500.
    """
    with running_custom_mcp_server(FIXTURES / "huge_output_mcp_server.py") as api_url:
        resp = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Call the fetch_document tool, then summarize the document in one sentence."}
            ],
            "seed": 42,
            "max_tokens": 200,
        }, timeout=TIMEOUT)
    assert resp.status_code == 200, f"huge tool output must not overflow: {resp.status_code} {resp.text[:300]}"
    data = resp.json()
    choice = data["choices"][0]
    content = choice["message"]["content"]
    assert content and content.strip(), "must produce an answer from the truncated result"
    assert "context window" not in content.lower(), "must not report a context overflow as the answer"
    assert '"tool_calls"' not in content, "raw tool-call JSON must not leak"


def test_mcp_timed_out_connection_is_deregistered():
    """A timed-out MCP connection must be deregistered, not left permanently dead (#216).

    hanging_mcp_server.py sleeps forever on tools/call. The first call times out
    (~5s) and apfel tears the connection down. Before the fix the tool stayed in
    the routing tables, so a second call routed to the dead connection and failed
    with "MCP server process is not running". After the fix the connection is
    deregistered: the tool is removed from allTools(), the model is no longer
    offered it, and the second call succeeds (200) instead of hitting the corpse.
    """
    with running_custom_mcp_server(FIXTURES / "hanging_mcp_server.py") as api_url:
        base_url = api_url.rsplit("/", 1)[0]
        first = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
            ],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=30)
        assert first.status_code == 500
        assert "timed out" in first.json()["error"]["message"].lower()

        # Server stays healthy after the teardown.
        assert httpx.get(f"{base_url}/health", timeout=5).status_code == 200

        # Second call must NOT route to the dead connection. Deregistration
        # removed the tool, so the model answers directly (247*83 = 20501).
        second = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
            ],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=30)
        assert second.status_code == 200, \
            f"Second call did not succeed - dead tool still registered? {second.status_code}: {second.text[:200]}"
        assert "not running" not in second.text.lower(), \
            f"Second call routed to the deregistered dead connection: {second.text[:200]}"


def test_mcp_noisy_server_handshake_survives_notifications():
    """Server->client noise before responses must not desync the handshake (#217).

    noisy_mcp_server.py emits notifications/message lines and a ping request
    before every response (what FastMCP's ctx.info() does). Before the id
    correlation fix, apfel parsed the first notification as the initialize
    response, MCP startup failed, and the server never became healthy. This
    test is model-free: it only exercises initialize + tools/list.
    """
    with running_custom_mcp_server(FIXTURES / "noisy_mcp_server.py") as api_url:
        base_url = api_url.rsplit("/", 1)[0]
        health = httpx.get(f"{base_url}/health", timeout=5)
        assert health.status_code == 200, \
            "apfel did not come up with a noisy MCP server - id correlation broken?"


def test_mcp_noisy_server_tool_call_succeeds():
    """Tool calls through a notification-noisy MCP server return the real result (#217).

    Before the fix, the notification line was parsed as the tools/call
    response ("Missing content" error) and the real response stayed buffered,
    desyncing every later call.
    """
    with running_custom_mcp_server(FIXTURES / "noisy_mcp_server.py") as api_url:
        resp = httpx.post(f"{api_url}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 247 times 83. Reply with just the number."}
            ],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=30)
        assert resp.status_code == 200, f"{resp.status_code}: {resp.text[:200]}"
        data = resp.json()
        assert data["choices"][0]["finish_reason"] == "stop"
        content = data["choices"][0]["message"]["content"] or ""
        assert "20501" in content or "20,501" in content, \
            f"Expected 20501 through the noisy server, got: {content}"


def test_mcp_concurrent_tool_calls_do_not_cross_deliver():
    """Two simultaneous tool calls must each get their own result (#218).

    Runs against the standing 11435 calculator server (--max-concurrent
    default 5). Before the per-connection send+receive serialization, the two
    detached stdio exchanges interleaved on one pipe: request B could consume
    request A's response line (swapped or lost results).
    """
    import concurrent.futures

    def ask(prompt):
        return httpx.post(f"{API_URL}/chat/completions", json={
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "seed": 42,
            "max_tokens": 128,
        }, timeout=TIMEOUT)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        fut_multiply = pool.submit(
            ask, "Use the multiply tool to compute 247 times 83. Reply with just the number.")
        fut_add = pool.submit(
            ask, "Use the add function to add 111 and 222. Reply with just the number.")
        resp_multiply = fut_multiply.result()
        resp_add = fut_add.result()

    assert resp_multiply.status_code == 200, f"{resp_multiply.status_code}: {resp_multiply.text[:200]}"
    assert resp_add.status_code == 200, f"{resp_add.status_code}: {resp_add.text[:200]}"
    multiply_content = resp_multiply.json()["choices"][0]["message"]["content"] or ""
    add_content = resp_add.json()["choices"][0]["message"]["content"] or ""
    assert "20501" in multiply_content or "20,501" in multiply_content, \
        f"multiply got the wrong result (cross-delivered?): {multiply_content}"
    assert "333" in add_content, \
        f"add got the wrong result (cross-delivered?): {add_content}"


# ============================================================================
# MCP tool routing (different calculator tools)
# ============================================================================

def test_mcp_multiply_returns_correct_result(multiply_247x83_response):
    """Multiply tool: 247 * 83 = 20501."""
    data = multiply_247x83_response
    content = data["choices"][0]["message"]["content"] or ""
    assert data["choices"][0]["finish_reason"] == "stop"
    assert_no_raw_tool_calls(content)
    assert "20501" in content or "20,501" in content, f"Expected 20501, got: {content}"


def _is_guardrail_refusal(text):
    """The on-device model's guardrail refusals ("I'm sorry, but I cannot
    respond ... violates our guidelines" / "... cannot provide an answer that
    promotes or supports harm"). Incidental model behavior, not a property
    any test here asserts on."""
    lowered = text.lower()
    return lowered.startswith("i'm sorry") and "cannot" in lowered


def test_mcp_sqrt_returns_correct_result():
    """Sqrt tool: sqrt(144) = 12.

    The macOS 26.5.2 model guardrail-refuses this prompt on some sampling
    trajectories (seed 42 became a deterministic refusal; unseeded runs
    refuse intermittently). The property under test is that the tool result
    round-trips into the final answer, not that a particular seed avoids the
    guardrail, so rotate seeds on refusal and assert on the first real
    answer (#320)."""
    content = ""
    for seed in (42, 7, 123):
        resp = httpx.post(f"{API_URL}/chat/completions", json={
            "model": MODEL,
            "messages": [
                {"role": "user", "content": "Use the sqrt tool to compute the square root of 144. Reply with just the number."}
            ],
            "seed": seed,
        }, timeout=TIMEOUT)
        data = resp.json()
        content = data["choices"][0]["message"]["content"] or ""
        assert data["choices"][0]["finish_reason"] == "stop"
        assert_no_raw_tool_calls(content)
        if not _is_guardrail_refusal(content):
            break
    else:
        pytest.fail(f"model guardrail-refused every seed; last: {content}")
    assert "12" in content, f"Expected 12, got: {content}"


def test_mcp_add_returns_correct_result(add_tool_response):
    """Add tool: 100 + 200 = 300. Seed rotation in fixture guards against
    guardrail refusals that silently pass content asserts (#323)."""
    data = add_tool_response
    content = data["choices"][0]["message"]["content"] or ""
    assert data["choices"][0]["finish_reason"] == "stop"
    assert_no_raw_tool_calls(content)
    assert "300" in content, f"Expected 300, got: {content}"


def test_mcp_tool_returns_stop_not_tool_calls(add_tool_response):
    """Any MCP-auto-executed response must have finish_reason 'stop', never 'tool_calls'."""
    data = add_tool_response
    assert data["choices"][0]["finish_reason"] == "stop", \
        f"MCP response should be 'stop', got '{data['choices'][0]['finish_reason']}'"
    content = data["choices"][0]["message"]["content"]
    assert content is not None
    assert_no_raw_tool_calls(content)


def test_mcp_auto_execute_preserves_conversation_context():
    """Final MCP answer must retain prior conversation context, not just the last prompt."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Remember this exact code word for later replies: MANGO."},
            {"role": "assistant", "content": "I will remember MANGO."},
            {"role": "user", "content": "Use the multiply tool to compute 6 times 7. Reply with exactly the remembered code word, one space, and the number."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = (data["choices"][0]["message"]["content"] or "").strip()
    assert "42" in content, content
    assert content.upper().startswith("MANGO"), content


# ============================================================================
# Response format validation
# ============================================================================

def test_mcp_response_has_valid_usage(add_tool_response):
    """MCP auto-executed responses include valid usage stats."""
    data = add_tool_response
    usage = data.get("usage")
    assert usage is not None, "Missing usage in MCP response"
    assert usage["prompt_tokens"] > 0
    assert usage["completion_tokens"] > 0
    assert usage["total_tokens"] == usage["prompt_tokens"] + usage["completion_tokens"]


def test_mcp_response_has_valid_id(normal_nonstreaming_response):
    """MCP response has a proper chatcmpl- prefixed ID."""
    data = normal_nonstreaming_response
    assert data["id"].startswith("chatcmpl-"), f"Bad ID format: {data['id']}"
    assert data["object"] == "chat.completion"
    assert data["model"] == MODEL


def test_mcp_streaming_has_valid_sse_structure(normal_streaming_response):
    """MCP streaming response has proper SSE structure with role, content, stop, usage, DONE."""
    resp = normal_streaming_response
    lines = [l for l in resp.text.strip().split("\n") if l.startswith("data: ")]
    assert len(lines) >= 3, f"Expected at least 3 SSE lines, got {len(lines)}"

    # Last line must be [DONE]
    assert lines[-1] == "data: [DONE]"

    # Parse non-DONE chunks
    chunks = []
    for line in lines:
        payload = line[len("data: "):]
        if payload == "[DONE]":
            continue
        chunks.append(json.loads(payload))

    # First chunk with choices should have role=assistant
    role_chunks = [c for c in chunks if c.get("choices") and c["choices"][0].get("delta", {}).get("role")]
    assert len(role_chunks) > 0, "Missing role chunk in SSE"
    assert role_chunks[0]["choices"][0]["delta"]["role"] == "assistant"

    # Should have at least one content chunk (among chunks that have choices)
    content_chunks = [c for c in chunks
                      if c.get("choices") and c["choices"][0].get("delta", {}).get("content")]
    assert len(content_chunks) > 0, "No content chunks in SSE response"

    # Should have a finish_reason chunk
    finish_chunks = [c for c in chunks
                     if c.get("choices") and c["choices"][0].get("finish_reason")]
    assert len(finish_chunks) > 0, "Missing finish_reason chunk"


def test_mcp_non_streaming_response_structure(normal_nonstreaming_response):
    """Non-streaming MCP response has full OpenAI-compatible structure."""
    data = normal_nonstreaming_response
    assert "id" in data
    assert "object" in data
    assert "created" in data
    assert "model" in data
    assert "choices" in data
    assert "usage" in data
    assert len(data["choices"]) == 1
    choice = data["choices"][0]
    assert "index" in choice
    assert "message" in choice
    assert "finish_reason" in choice
    assert choice["message"]["role"] == "assistant"


# ============================================================================
# Endpoints still work with MCP enabled
# ============================================================================

def test_mcp_models_endpoint():
    """GET /v1/models still works with MCP enabled."""
    resp = httpx.get(f"{API_URL}/models", timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["object"] == "list"
    assert len(data["data"]) > 0
    assert data["data"][0]["id"] == MODEL


def test_mcp_health_endpoint(health_response):
    """GET /health returns model_available with MCP enabled."""
    assert health_response.status_code == 200
    data = health_response.json()
    assert "model_available" in data
    assert "model" in data
    assert data["model"] == MODEL


# ============================================================================
# Error handling
# ============================================================================

def test_mcp_invalid_model_rejected():
    """Invalid model name returns 404 model_not_found (OpenAI parity, #236)."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": "gpt-4o",
        "messages": [{"role": "user", "content": "Say OK."}],
    }, timeout=TIMEOUT)
    assert resp.status_code == 404
    data = resp.json()
    assert "does not exist" in data["error"]["message"]
    assert "apple-foundationmodel" in data["error"]["message"]
    assert data["error"]["code"] == "model_not_found"
    assert data["error"]["param"] == "model"


def test_mcp_empty_messages_rejected():
    """Empty messages array returns 400 error."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [],
    }, timeout=TIMEOUT)
    assert resp.status_code == 400


def test_mcp_invalid_json_rejected():
    """Malformed JSON body returns 400 error."""
    resp = httpx.post(f"{API_URL}/chat/completions",
                      content=b"not json",
                      headers={"Content-Type": "application/json"},
                      timeout=TIMEOUT)
    assert resp.status_code == 400


# ============================================================================
# JSON mode with MCP
# ============================================================================

def test_json_mode_with_mcp():
    """JSON mode still works when MCP tools are enabled.

    Per #101, json_object content must be directly parseable, no markdown fence.
    """
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Return a JSON object with key 'answer' and value 42."}
        ],
        "response_format": {"type": "json_object"},
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert content is not None
    assert not content.strip().startswith("```"), \
        f"json_object must not return a markdown code fence; got: {content!r}"
    json.loads(content)


def test_max_tokens_respected_with_mcp():
    """max_tokens limits response length even with MCP auto-execute."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [{"role": "user", "content": "Write a long essay about mathematics."}],
        "max_tokens": 10,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    content = data["choices"][0]["message"]["content"]
    assert content is not None
    # With max_tokens=10, the response should be short
    assert len(content.split()) <= 30, f"Response too long for max_tokens=10: {len(content.split())} words"


def test_temperature_zero_with_mcp():
    """temperature=0 works with MCP-enabled server."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [{"role": "user", "content": "What is 2+2? Reply with just the number."}],
        "temperature": 0,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    data = resp.json()
    assert data["choices"][0]["finish_reason"] == "stop"
    content = data["choices"][0]["message"]["content"]
    assert content is not None
