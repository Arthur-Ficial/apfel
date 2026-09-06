"""
apfel Integration Tests -- OpenAI Official Spec Conformance

Validates apfel's HTTP responses against the OFFICIAL OpenAI API spec
(vendored at Tests/integration/openai_spec/openapi.yaml) using
openapi-core's runtime validator. No manual schema maintenance --
if OpenAI updates their spec, we refresh the YAML and any new drift
shows up automatically.

This is complementary to openapi_spec_test.py which tests apfel-specific
invariants (ID format, enum values) that the generic spec can't cover.

Requires: pip install openapi-core httpx
Requires: apfel --serve running on localhost:11434
          apfel --serve --mcp mcp/calculator/server.py running on localhost:11435

Run: python3 -m pytest Tests/integration/openapi_conformance_test.py -v
"""

import json

import httpx
import pytest

# Whole-suite marker: these tests drive real on-device generation (or, for
# the permit/benchmark suites, need Apple Intelligence up); GitHub CI cannot
# run them (CLAUDE.md "What GitHub CI CANNOT run"). Keeps -m "not model" a
# complete, correct model-free selector for the fast preflight phase (#374).
pytestmark = pytest.mark.model


BASE_URL = "http://localhost:11434"
MCP_URL = "http://localhost:11435"
MODEL = "apple-foundationmodel"
TIMEOUT = 60


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _validate(openai_spec, method, path, status_code, response_body, content_type="application/json"):
    """Validate a response against the OpenAI spec.

    Uses openapi-core's mock objects so we don't need a real WSGI/ASGI app.
    Raises on validation errors -- pytest treats that as a test failure.
    """
    from openapi_core.testing import MockRequest, MockResponse

    request = MockRequest(
        "https://api.openai.com",  # spec's server URL
        method.lower(),
        path,
    )
    response = MockResponse(
        data=json.dumps(response_body).encode("utf-8") if isinstance(response_body, dict) else response_body,
        status_code=status_code,
        content_type=content_type,
    )
    openai_spec.validate_response(request, response)


# ---------------------------------------------------------------------------
# Non-streaming chat completion
# ---------------------------------------------------------------------------

class TestChatCompletionConformance:
    """POST /v1/chat/completions (non-streaming) matches the official schema.

    Known gaps (tracked for server-side fix):
    - choices[].logprobs is missing (spec requires it, nullable)
    - message.content is missing when tool_calls present (spec requires it, nullable)
    - message.refusal is missing (spec requires it, nullable)
    """

    def test_basic_response_matches_spec(self, openai_spec):
        resp = httpx.post(
            f"{BASE_URL}/v1/chat/completions",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": "Say hello in one word."}],
            },
            timeout=TIMEOUT,
        )
        assert resp.status_code == 200
        _validate(openai_spec, "post", "/v1/chat/completions", resp.status_code, resp.json())

    def test_with_temperature_and_max_tokens(self, openai_spec):
        resp = httpx.post(
            f"{BASE_URL}/v1/chat/completions",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": "One word: yes or no."}],
                "temperature": 0.0,
                "max_tokens": 10,
            },
            timeout=TIMEOUT,
        )
        assert resp.status_code == 200
        _validate(openai_spec, "post", "/v1/chat/completions", resp.status_code, resp.json())

    def test_json_mode_response_matches_spec(self, openai_spec):
        resp = httpx.post(
            f"{BASE_URL}/v1/chat/completions",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": "Return {\"answer\": 42} as JSON."}],
                "response_format": {"type": "json_object"},
            },
            timeout=TIMEOUT,
        )
        assert resp.status_code == 200
        _validate(openai_spec, "post", "/v1/chat/completions", resp.status_code, resp.json())


# ---------------------------------------------------------------------------
# Streaming chat completion
# ---------------------------------------------------------------------------

class TestStreamingConformance:
    """POST /v1/chat/completions (stream=true) chunks match the official schema.

    openapi-core can't distinguish the streaming response schema
    (CreateChatCompletionStreamResponse) from the non-streaming one because
    both share the same endpoint. We validate streaming chunks manually
    against the structural invariants the spec requires.
    """

    def test_streaming_chunks_have_correct_structure(self, openai_spec):
        chunks = []
        with httpx.stream(
            "POST",
            f"{BASE_URL}/v1/chat/completions",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": "Say hi."}],
                "stream": True,
            },
            timeout=TIMEOUT,
        ) as resp:
            for line in resp.iter_lines():
                if line.startswith("data: "):
                    data = line[6:]
                    if data.strip() == "[DONE]":
                        break
                    chunks.append(json.loads(data))

        assert len(chunks) >= 2, "expected at least 2 streaming chunks"

        # Every chunk must have these top-level fields per the OpenAI spec
        for chunk in chunks:
            assert chunk["object"] == "chat.completion.chunk"
            assert "id" in chunk
            assert "created" in chunk
            assert "model" in chunk
            assert "choices" in chunk
            for choice in chunk["choices"]:
                assert "index" in choice
                assert "delta" in choice
                assert "logprobs" in choice  # must be present (null is fine)

        # First chunk should have role in delta
        first = chunks[0]
        assert first["choices"][0]["delta"].get("role") == "assistant"

        # One of the chunks must carry a finish_reason (the last content
        # chunk, before the usage-only chunk which has empty choices).
        finish_reasons = [
            c["choices"][0]["finish_reason"]
            for c in chunks
            if c.get("choices") and c["choices"][0].get("finish_reason")
        ]
        assert len(finish_reasons) >= 1, "no chunk had a finish_reason"
        assert finish_reasons[-1] in (
            "stop", "length", "tool_calls", "content_filter",
        )


# ---------------------------------------------------------------------------
# Models list
# ---------------------------------------------------------------------------

class TestModelsConformance:
    """GET /v1/models matches the official schema."""

    def test_models_list_matches_spec(self, openai_spec):
        resp = httpx.get(f"{BASE_URL}/v1/models", timeout=TIMEOUT)
        assert resp.status_code == 200
        _validate(openai_spec, "get", "/v1/models", resp.status_code, resp.json())


# ---------------------------------------------------------------------------
# Tool calling
# ---------------------------------------------------------------------------

class TestToolCallConformance:
    """Tool-call responses match the official schema."""

    def test_tool_call_response_matches_spec(self, openai_spec):
        """A prompt that triggers a tool call should produce a response with
        tool_calls in the message, matching the OpenAI spec structure."""
        resp = httpx.post(
            f"{MCP_URL}/v1/chat/completions",
            json={
                "model": MODEL,
                "messages": [{"role": "user", "content": "What is 15 times 27?"}],
                "tools": [
                    {
                        "type": "function",
                        "function": {
                            "name": "multiply",
                            "description": "Multiply two numbers",
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "a": {"type": "number"},
                                    "b": {"type": "number"},
                                },
                                "required": ["a", "b"],
                            },
                        },
                    }
                ],
            },
            timeout=TIMEOUT,
        )
        assert resp.status_code == 200
        _validate(openai_spec, "post", "/v1/chat/completions", resp.status_code, resp.json())


# ---------------------------------------------------------------------------
# Error responses
# ---------------------------------------------------------------------------

class TestErrorConformance:
    """Error responses match the official error schema."""

    def test_unsupported_embeddings_returns_spec_error(self, openai_spec):
        """POST /v1/embeddings returns 501 with a proper error body."""
        resp = httpx.post(
            f"{BASE_URL}/v1/embeddings",
            json={"model": MODEL, "input": "test"},
            timeout=TIMEOUT,
        )
        # apfel returns 501 for unsupported endpoints. The OpenAI spec
        # doesn't define 501 responses, so we validate the error body
        # structure manually rather than against the spec.
        assert resp.status_code == 501
        data = resp.json()
        assert "error" in data
        assert "message" in data["error"]

    def test_invalid_request_returns_spec_error(self, openai_spec):
        """A request missing required fields returns 400 with error body."""
        resp = httpx.post(
            f"{BASE_URL}/v1/chat/completions",
            json={"messages": [{"role": "user", "content": "hi"}]},
            timeout=TIMEOUT,
        )
        # Missing "model" field should produce a 400
        assert resp.status_code == 400
        data = resp.json()
        assert "error" in data
        assert "message" in data["error"]


# ---------------------------------------------------------------------------
# Responses streaming terminal event (#412)
# ---------------------------------------------------------------------------

def _collect_responses_sse(url, body, timeout=TIMEOUT):
    """Stream a /v1/responses request and return (events, last_event_name).

    Each entry in events is (event_name, parsed_data_dict).
    """
    events = []
    with httpx.stream("POST", url, json=body, timeout=timeout) as resp:
        current_event = None
        for line in resp.iter_lines():
            if line.startswith("event: "):
                current_event = line[7:].strip()
            elif line.startswith("data: "):
                data = json.loads(line[6:])
                events.append((current_event or "message", data))
    return events


class TestResponsesStreamTerminalEvent:
    """The terminal SSE event name must match the response status (#412).

    A truncated stream must end with event: response.incomplete.
    A complete stream must end with event: response.completed.
    The event name and the nested response.status must always agree.
    """

    def test_responses_stream_truncated_emits_incomplete(self):
        """A stream truncated by max_output_tokens ends with response.incomplete."""
        events = _collect_responses_sse(
            f"{BASE_URL}/v1/responses",
            {
                "model": MODEL,
                "input": "List the numbers from one to one thousand.",
                "stream": True,
                "max_output_tokens": 1,
            },
        )
        terminal = [(name, data) for name, data in events if name in ("response.completed", "response.incomplete")]
        assert len(terminal) == 1, f"expected exactly one terminal event, got {len(terminal)}"
        event_name, payload = terminal[0]
        assert event_name == "response.incomplete", (
            f"truncated stream must emit response.incomplete, got {event_name}"
        )
        assert payload["type"] == "response.incomplete"
        assert payload["response"]["status"] == "incomplete"
        assert payload["response"]["incomplete_details"]["reason"] == "max_output_tokens"

    def test_responses_stream_complete_emits_completed(self):
        """A stream that finishes normally ends with response.completed."""
        events = _collect_responses_sse(
            f"{BASE_URL}/v1/responses",
            {
                "model": MODEL,
                "input": "Say hi.",
                "stream": True,
            },
        )
        terminal = [(name, data) for name, data in events if name in ("response.completed", "response.incomplete")]
        assert len(terminal) == 1, f"expected exactly one terminal event, got {len(terminal)}"
        event_name, payload = terminal[0]
        assert event_name == "response.completed", (
            f"complete stream must emit response.completed, got {event_name}"
        )
        assert payload["type"] == "response.completed"
        assert payload["response"]["status"] == "completed"

    def test_responses_terminal_event_matches_status(self):
        """The SSE event name and the nested response.status always agree."""
        for body, expected_status in [
            ({"model": MODEL, "input": "Say hi.", "stream": True, "max_output_tokens": 1}, "incomplete"),
            ({"model": MODEL, "input": "Say hi.", "stream": True}, "completed"),
        ]:
            events = _collect_responses_sse(f"{BASE_URL}/v1/responses", body)
            terminal = [(n, d) for n, d in events if n in ("response.completed", "response.incomplete")]
            assert len(terminal) == 1
            event_name, payload = terminal[0]
            nested_status = payload["response"]["status"]
            expected_event = f"response.{expected_status}"
            assert event_name == expected_event, (
                f"event name {event_name} does not match expected {expected_event}"
            )
            assert nested_status == expected_status, (
                f"nested status {nested_status} does not match expected {expected_status}"
            )
            assert payload["type"] == expected_event
