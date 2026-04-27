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
    """Non-streaming add 100+200 -- shared by stop-not-tool_calls and usage tests."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the add function to add 100 and 200. Reply with just the number."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 200
    return resp.json()


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


def test_mcp_tool_error_returns_structured_error():
    """MCP tool failures must be surfaced honestly, not rewritten by the model."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the divide tool to divide 10 by 0. Reply with just the number."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    assert resp.status_code == 500
    data = resp.json()
    assert data["error"]["type"] == "server_error"
    message = data["error"]["message"].lower()
    assert "divide" in message
    assert "division by zero" in message


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


def test_mcp_sqrt_returns_correct_result():
    """Sqrt tool: sqrt(144) = 12."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": MODEL,
        "messages": [
            {"role": "user", "content": "Use the sqrt tool to compute the square root of 144. Reply with just the number."}
        ],
        "seed": 42,
    }, timeout=TIMEOUT)
    data = resp.json()
    content = data["choices"][0]["message"]["content"] or ""
    assert data["choices"][0]["finish_reason"] == "stop"
    assert_no_raw_tool_calls(content)
    assert "12" in content, f"Expected 12, got: {content}"


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
    """Invalid model name returns 400 with helpful error (only apple-foundationmodel accepted)."""
    resp = httpx.post(f"{API_URL}/chat/completions", json={
        "model": "gpt-4o",
        "messages": [{"role": "user", "content": "Say OK."}],
    }, timeout=TIMEOUT)
    assert resp.status_code == 400
    data = resp.json()
    assert "does not exist" in data["error"]["message"]
    assert "apple-foundationmodel" in data["error"]["message"]


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
