"""
apfel Integration Tests -- Anthropic Messages API (`POST /v1/messages`)

Validates that apfel serves the EXACT Anthropic Messages wire contract that the
`anthropics/ClaudeForFoundationModels` Swift library emits, so a developer can
target on-device FoundationModels via apfel with `auth: .proxied(...)`.

This is an EXPERIMENT branch (experiment/anthropic-messages-api). The endpoint
is additive: the OpenAI `/v1/chat/completions` default is unchanged.

Raw wire only -- these tests use `httpx` and do NOT assume the `anthropic`
Python SDK is installed. One optional SDK smoke test is guarded by an import
and skipped if the package is absent.

Reuses the conftest guard_server_11434 / guard_server_11435 autouse fixtures
(plain server on 11434, MCP-calculator server on 11435). No new server
fixtures are introduced here.

Run: python3 -m pytest Tests/integration/anthropic_messages_test.py -v
"""

import json

import httpx
import pytest

# Plain server (11434) and MCP-calculator server (11435), matching conftest.
BASE_URL = "http://localhost:11434"
MESSAGES_URL = f"{BASE_URL}/v1/messages"
HEALTH_URL = f"{BASE_URL}/health"
CHAT_URL = f"{BASE_URL}/v1/chat/completions"

MCP_BASE_URL = "http://localhost:11435"
MCP_MESSAGES_URL = f"{MCP_BASE_URL}/v1/messages"

MODEL = "apple-foundationmodel"
ANTHROPIC_VERSION = "2023-06-01"
TIMEOUT = 120


# MARK: - Helpers


def _require_apple_intelligence():
    """Skip gracefully when Apple Intelligence is unavailable (same pattern the
    rest of the suite relies on -- the model is needed for real responses)."""
    try:
        resp = httpx.get(HEALTH_URL, timeout=5)
    except httpx.HTTPError as exc:  # pragma: no cover - server not up
        pytest.skip(f"apfel server on 11434 not reachable: {exc}")
    if resp.status_code != 200 or not resp.json().get("model_available"):
        pytest.skip("Apple Intelligence is not enabled / model unavailable")


def _post_messages(body, url=MESSAGES_URL, headers=None, timeout=TIMEOUT):
    """POST a Messages request. Default headers mirror what the Swift library
    sends in proxied mode (content-type + anthropic-version, NO x-api-key)."""
    h = {"content-type": "application/json", "anthropic-version": ANTHROPIC_VERSION}
    if headers:
        h.update(headers)
    return httpx.post(url, json=body, headers=h, timeout=timeout)


def _parse_sse_messages(resp):
    """Parse a text/event-stream Anthropic Messages stream.

    Returns an ordered list of (event_name, json_payload) tuples. The `event:`
    line is decoration; the contract switches on the JSON `type`, but we capture
    both so tests can assert ordering and event-line presence.
    """
    events = []
    pending_event = None
    for raw in resp.text.splitlines():
        line = raw.rstrip("\r")
        if line.startswith("event:"):
            pending_event = line[len("event:"):].strip()
            continue
        if line.startswith("data:"):
            payload = line[len("data:"):].strip()
            if not payload or payload == "[DONE]":
                continue
            events.append((pending_event, json.loads(payload)))
            pending_event = None
    return events


# MARK: - Non-streaming basic


def test_messages_non_stream_basic():
    """POST /v1/messages (content as block array) -> 200 with the required
    Anthropic response envelope and a real, non-zero output_tokens count."""
    _require_apple_intelligence()
    resp = _post_messages({
        "model": MODEL,
        "max_tokens": 64,
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": "Say hi in one word."}]}
        ],
    })
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["id"], "missing id"
    assert data["type"] == "message"
    assert data["role"] == "assistant"
    assert data["model"] == MODEL, f"model not echoed: {data.get('model')!r}"
    assert isinstance(data["content"], list) and data["content"], "empty content"
    assert data["content"][0]["type"] == "text"
    assert isinstance(data["content"][0]["text"], str) and data["content"][0]["text"]
    usage = data["usage"]
    assert usage["input_tokens"] > 0, f"input_tokens not real: {usage}"
    assert usage["output_tokens"] > 0, f"output_tokens not real: {usage}"


def test_messages_no_auth_still_200():
    """Proxied mode sends no credential. An identical request with NO x-api-key
    header still returns 200 -- apfel must not 401 the Anthropic route."""
    _require_apple_intelligence()
    resp = httpx.post(
        MESSAGES_URL,
        json={
            "model": MODEL,
            "max_tokens": 32,
            "messages": [{"role": "user", "content": "Say hi."}],
        },
        # Deliberately omit x-api-key entirely.
        headers={"content-type": "application/json", "anthropic-version": ANTHROPIC_VERSION},
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["type"] == "message"
    assert data["role"] == "assistant"


def test_messages_string_shorthand_content():
    """messages[].content may be a bare string (shorthand). It must be accepted
    and produce a normal 200 response."""
    _require_apple_intelligence()
    resp = _post_messages({
        "model": MODEL,
        "max_tokens": 32,
        "messages": [{"role": "user", "content": "Say hi in one word."}],
    })
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["type"] == "message"
    assert data["content"][0]["type"] == "text"
    assert data["usage"]["output_tokens"] > 0


@pytest.mark.parametrize("model", ["claude-sonnet-4-6", "apple-foundationmodel"])
def test_messages_model_echoed_back(model):
    """apfel accepts ANY model string and echoes it back unchanged in the
    response body (and message_start.message.model for streams)."""
    _require_apple_intelligence()
    resp = _post_messages({
        "model": model,
        "max_tokens": 32,
        "messages": [{"role": "user", "content": "Say hi."}],
    })
    assert resp.status_code == 200, resp.text
    assert resp.json()["model"] == model


def test_messages_system_string_accepted():
    """`system` is a PLAIN STRING (not blocks). It must be accepted and steer
    the response without erroring."""
    _require_apple_intelligence()
    resp = _post_messages({
        "model": MODEL,
        "max_tokens": 32,
        "system": "You always reply in a single word.",
        "messages": [{"role": "user", "content": "Greet me."}],
    })
    assert resp.status_code == 200, resp.text
    assert resp.json()["content"][0]["type"] == "text"


# MARK: - Streaming


def test_messages_streaming_event_order_and_text():
    """stream:true -> text/event-stream with the exact ordered Anthropic frames:
    message_start -> content_block_start -> >=1 content_block_delta(text_delta)
    -> content_block_stop -> message_delta(usage.output_tokens) -> message_stop.
    Reconstructed text must be non-empty and message_start carries usage."""
    _require_apple_intelligence()
    with httpx.stream(
        "POST",
        MESSAGES_URL,
        json={
            "model": MODEL,
            "max_tokens": 64,
            "stream": True,
            "messages": [{"role": "user", "content": "Say hello in a short sentence."}],
        },
        headers={"content-type": "application/json", "anthropic-version": ANTHROPIC_VERSION},
        timeout=TIMEOUT,
    ) as resp:
        assert resp.status_code == 200, resp.read().decode("utf-8", "replace")
        ctype = resp.headers.get("content-type", "")
        assert "text/event-stream" in ctype, f"bad content-type: {ctype!r}"
        resp.read()
        events = _parse_sse_messages(resp)

    types = [payload["type"] for _, payload in events]

    # All required frame types are present.
    for required in (
        "message_start",
        "content_block_start",
        "content_block_delta",
        "content_block_stop",
        "message_delta",
        "message_stop",
    ):
        assert required in types, f"missing {required} frame; got order {types}"

    # Ordering: message_start first, message_stop last, and the block frames in order.
    assert types[0] == "message_start", f"first frame must be message_start, got {types[0]}"
    assert types[-1] == "message_stop", f"last frame must be message_stop, got {types[-1]}"
    i_start = types.index("message_start")
    i_block_start = types.index("content_block_start")
    i_first_delta = types.index("content_block_delta")
    i_block_stop = types.index("content_block_stop")
    i_msg_delta = types.index("message_delta")
    i_msg_stop = types.index("message_stop")
    assert i_start < i_block_start < i_first_delta < i_block_stop < i_msg_delta < i_msg_stop, (
        f"frames out of order: {types}"
    )

    # message_start.message.usage must decode as Usage.
    start_payload = next(p for _, p in events if p["type"] == "message_start")
    start_usage = start_payload["message"]["usage"]
    assert "input_tokens" in start_usage
    assert start_usage["output_tokens"] == 0, "message_start output_tokens must start at 0"
    assert start_payload["message"]["model"] == MODEL

    # At least one text_delta, and reconstructed text is non-empty.
    text = ""
    saw_text_delta = False
    for _, payload in events:
        if payload["type"] == "content_block_delta":
            delta = payload["delta"]
            if delta.get("type") == "text_delta":
                saw_text_delta = True
                text += delta.get("text", "")
    assert saw_text_delta, "no text_delta deltas in stream"
    assert text.strip(), f"reconstructed streamed text is empty: {text!r}"

    # message_delta carries real output_tokens.
    delta_payload = next(p for _, p in events if p["type"] == "message_delta")
    assert delta_payload["usage"]["output_tokens"] > 0, (
        f"message_delta.usage.output_tokens not real: {delta_payload}"
    )


# MARK: - Tool use (MCP calculator on 11435)


def test_messages_tool_use_non_stream():
    """Provide the calculator as an Anthropic tool and prompt arithmetic.

    Mirrors mcp_server_test.py's triggering approach. Depending on whether the
    on-device model emits a tool call or answers directly, the contract is:
    either a tool_use block appears (stop_reason == "tool_use") OR a normal
    text answer is returned. Both are valid wire shapes; we assert the request
    is accepted and the response is well-formed Anthropic.
    """
    _require_apple_intelligence()
    resp = _post_messages(
        {
            "model": MODEL,
            "max_tokens": 256,
            "tools": [
                {
                    "name": "add",
                    "description": "Add two numbers and return the sum",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "a": {"type": "number"},
                            "b": {"type": "number"},
                        },
                        "required": ["a", "b"],
                    },
                }
            ],
            "messages": [
                {"role": "user", "content": "Use the add tool to compute what is 2+2."}
            ],
        },
        url=MCP_MESSAGES_URL,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["type"] == "message"
    block_types = [b["type"] for b in data["content"]]
    tool_use_blocks = [b for b in data["content"] if b["type"] == "tool_use"]

    if tool_use_blocks:
        # If a tool_use block is present, it must be well-formed and stop_reason
        # must reflect the tool call.
        tu = tool_use_blocks[0]
        assert tu.get("id"), f"tool_use block missing id: {tu}"
        assert tu.get("name"), f"tool_use block missing name: {tu}"
        assert isinstance(tu.get("input"), dict), f"tool_use input not an object: {tu}"
        assert data.get("stop_reason") == "tool_use", (
            f"tool_use block present but stop_reason != tool_use: {data.get('stop_reason')}"
        )
    else:
        # Otherwise the model answered directly: there must be text content and
        # the answer should contain 4 (2+2).
        assert "text" in block_types, f"no tool_use and no text block: {block_types}"
        joined = " ".join(b.get("text", "") for b in data["content"] if b["type"] == "text")
        assert "4" in joined, f"direct answer did not contain 4: {joined!r}"


def test_messages_tool_use_stream():
    """Streamed tool use: when the model calls the tool, the stream carries
    input_json_delta deltas and message_delta.stop_reason == "tool_use".

    Tolerant like the non-stream case: if the model answers directly, the stream
    is a normal text stream and we only assert it is well-formed."""
    _require_apple_intelligence()
    with httpx.stream(
        "POST",
        MCP_MESSAGES_URL,
        json={
            "model": MODEL,
            "max_tokens": 256,
            "stream": True,
            "tools": [
                {
                    "name": "multiply",
                    "description": "Multiply two numbers and return the product",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "a": {"type": "number"},
                            "b": {"type": "number"},
                        },
                        "required": ["a", "b"],
                    },
                }
            ],
            "messages": [
                {"role": "user", "content": "Use the multiply tool to compute 6 times 7."}
            ],
        },
        headers={"content-type": "application/json", "anthropic-version": ANTHROPIC_VERSION},
        timeout=TIMEOUT,
    ) as resp:
        assert resp.status_code == 200, resp.read().decode("utf-8", "replace")
        resp.read()
        events = _parse_sse_messages(resp)

    types = [p["type"] for _, p in events]
    assert types[0] == "message_start"
    assert types[-1] == "message_stop"

    # Did the stream signal a tool call?
    saw_input_json_delta = any(
        p["type"] == "content_block_delta" and p["delta"].get("type") == "input_json_delta"
        for _, p in events
    )
    msg_delta = next((p for _, p in events if p["type"] == "message_delta"), None)
    assert msg_delta is not None, f"no message_delta frame; got {types}"
    stop_reason = msg_delta["delta"].get("stop_reason")

    if saw_input_json_delta or stop_reason == "tool_use":
        # Tool-use path: the tool_use block must have started and stop_reason set.
        assert stop_reason == "tool_use", (
            f"input_json_delta seen but stop_reason != tool_use: {stop_reason}"
        )
        tool_block_starts = [
            p for _, p in events
            if p["type"] == "content_block_start"
            and p["content_block"].get("type") == "tool_use"
        ]
        assert tool_block_starts, "input_json_delta without a tool_use content_block_start"
    else:
        # Direct-answer path: a normal text stream that reconstructs non-empty.
        text = "".join(
            p["delta"].get("text", "")
            for _, p in events
            if p["type"] == "content_block_delta" and p["delta"].get("type") == "text_delta"
        )
        assert text.strip(), f"direct-answer stream produced no text: {text!r}"


# MARK: - Structured output


def test_messages_structured_output_json_schema():
    """output_config.format = json_schema -> the returned text block parses as
    JSON conforming to the supplied schema (returned as ordinary text content,
    no special block type)."""
    _require_apple_intelligence()
    schema = {
        "type": "object",
        "properties": {
            "city": {"type": "string"},
            "population": {"type": "integer"},
        },
        "required": ["city", "population"],
    }
    resp = _post_messages({
        "model": MODEL,
        "max_tokens": 128,
        "output_config": {"format": {"type": "json_schema", "schema": schema}},
        "messages": [
            {"role": "user", "content": "Give me the city of Vienna and a population estimate."}
        ],
    })
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["content"][0]["type"] == "text"
    text = data["content"][0]["text"]
    parsed = json.loads(text)  # must be directly parseable JSON, no markdown fence
    assert isinstance(parsed, dict)
    assert "city" in parsed, f"schema-required 'city' missing: {parsed}"
    assert "population" in parsed, f"schema-required 'population' missing: {parsed}"
    assert isinstance(parsed["city"], str)
    assert isinstance(parsed["population"], int)


# MARK: - Errors


def test_messages_oversized_prompt_context_error():
    """A prompt far exceeding the 4096-token context window must fail with
    HTTP >= 400 and the Anthropic error envelope, with the word "context" in
    the message (the Swift client maps that substring to contextSizeExceeded)."""
    _require_apple_intelligence()
    # ~50k words is well past the 4096-token window.
    huge = "context " * 50000
    resp = _post_messages(
        {
            "model": MODEL,
            "max_tokens": 64,
            "messages": [{"role": "user", "content": huge}],
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code >= 400, f"oversized prompt did not error: {resp.status_code} {resp.text}"
    data = resp.json()
    assert data["type"] == "error", f"missing error envelope: {data}"
    assert "type" in data["error"], f"error missing type: {data}"
    assert "context" in data["error"]["message"].lower(), (
        f"error message must mention 'context': {data['error']['message']!r}"
    )


# MARK: - Regression: OpenAI default unchanged


def test_openai_chat_completions_still_works():
    """The additive Anthropic route must not disturb the OpenAI default. A basic
    /v1/chat/completions request still returns 200 with usable content."""
    _require_apple_intelligence()
    resp = httpx.post(
        CHAT_URL,
        json={
            "model": MODEL,
            "messages": [{"role": "user", "content": "Reply with just the word OK."}],
            "max_tokens": 16,
        },
        timeout=TIMEOUT,
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["object"] == "chat.completion"
    assert data["choices"][0]["message"]["content"]


# MARK: - Optional anthropic SDK smoke test (skipped if not installed)


def test_messages_anthropic_sdk_smoke():
    """If the `anthropic` Python SDK is installed, a proxied client pointed at
    apfel must get a real message back. Skipped when the SDK is absent (the wire
    tests above are the real contract)."""
    _require_apple_intelligence()
    try:
        import anthropic  # noqa: F401
    except ImportError:
        pytest.skip("anthropic SDK not installed; raw-wire tests cover the contract")

    client = anthropic.Anthropic(api_key="ignored", base_url=BASE_URL)
    msg = client.messages.create(
        model=MODEL,
        max_tokens=32,
        messages=[{"role": "user", "content": "Say hi in one word."}],
    )
    assert msg.role == "assistant"
    assert msg.type == "message"
    assert msg.content and msg.content[0].type == "text"
    assert msg.content[0].text
