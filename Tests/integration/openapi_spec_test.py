"""
apfel Integration Tests — OpenAI API Schema Validation

Validates that apfel's server responses conform to the OpenAI API schema
at the structural level. This proves compatibility beyond "the Python client
accepts it" — every field, type, and required property is checked.

Schemas are derived from the official OpenAI API reference:
https://platform.openai.com/docs/api-reference/chat/object

Requires: pip install jsonschema httpx pyyaml
Requires: apfel --serve running on localhost:11434

Run: python3 -m pytest Tests/integration/openapi_spec_test.py -v
"""

import json
import pytest
import httpx
from jsonschema import validate, ValidationError

BASE_URL = "http://localhost:11434"
MODEL = "apple-foundationmodel"


# ============================================================================
# OpenAI Schemas — ChatCompletion (non-streaming)
# ============================================================================

USAGE_SCHEMA = {
    "type": "object",
    "required": ["prompt_tokens", "completion_tokens", "total_tokens"],
    "properties": {
        "prompt_tokens": {"type": "integer"},
        "completion_tokens": {"type": "integer"},
        "total_tokens": {"type": "integer"},
    },
    "additionalProperties": True,  # OpenAI adds extra fields over time
}

TOOL_CALL_SCHEMA = {
    "type": "object",
    "required": ["id", "type", "function"],
    "properties": {
        "id": {"type": "string"},
        "type": {"type": "string", "enum": ["function"]},
        "function": {
            "type": "object",
            "required": ["name", "arguments"],
            "properties": {
                "name": {"type": "string"},
                "arguments": {"type": "string"},
            },
        },
    },
}

MESSAGE_SCHEMA = {
    "type": "object",
    "required": ["role"],
    "properties": {
        "role": {"type": "string", "enum": ["assistant"]},
        "content": {"type": ["string", "null"]},
        "tool_calls": {
            "type": "array",
            "items": TOOL_CALL_SCHEMA,
        },
    },
}

CHOICE_SCHEMA = {
    "type": "object",
    "required": ["index", "message", "finish_reason"],
    "properties": {
        "index": {"type": "integer"},
        "message": MESSAGE_SCHEMA,
        "finish_reason": {
            "type": ["string", "null"],
            "enum": ["stop", "length", "tool_calls", "content_filter", None],
        },
    },
}

CHAT_COMPLETION_SCHEMA = {
    "type": "object",
    "required": ["id", "object", "created", "model", "choices", "usage"],
    "properties": {
        "id": {"type": "string", "pattern": "^chatcmpl-"},
        "object": {"type": "string", "enum": ["chat.completion"]},
        "created": {"type": "integer"},
        "model": {"type": "string"},
        "choices": {"type": "array", "items": CHOICE_SCHEMA, "minItems": 1},
        "usage": USAGE_SCHEMA,
    },
}


# ============================================================================
# OpenAI Schemas — ChatCompletionChunk (streaming)
# ============================================================================

DELTA_SCHEMA = {
    "type": "object",
    "properties": {
        "role": {"type": ["string", "null"]},
        "content": {"type": ["string", "null"]},
        "tool_calls": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["index"],
                "properties": {
                    "index": {"type": "integer"},
                    "id": {"type": "string"},
                    "type": {"type": "string"},
                    "function": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "arguments": {"type": "string"},
                        },
                    },
                },
            },
        },
    },
}

CHUNK_CHOICE_SCHEMA = {
    "type": "object",
    "required": ["index", "delta"],
    "properties": {
        "index": {"type": "integer"},
        "delta": DELTA_SCHEMA,
        "finish_reason": {
            "type": ["string", "null"],
            "enum": ["stop", "length", "tool_calls", "content_filter", None],
        },
    },
}

CHAT_COMPLETION_CHUNK_SCHEMA = {
    "type": "object",
    "required": ["id", "object", "created", "model", "choices"],
    "properties": {
        "id": {"type": "string", "pattern": "^chatcmpl-"},
        "object": {"type": "string", "enum": ["chat.completion.chunk"]},
        "created": {"type": "integer"},
        "model": {"type": "string"},
        "choices": {"type": "array", "items": CHUNK_CHOICE_SCHEMA},
        "usage": {
            "anyOf": [
                USAGE_SCHEMA,
                {"type": "null"},
            ]
        },
    },
}


# ============================================================================
# OpenAI Schemas — Models List
# ============================================================================

MODEL_OBJECT_SCHEMA = {
    "type": "object",
    "required": ["id", "object", "created", "owned_by"],
    "properties": {
        "id": {"type": "string"},
        "object": {"type": "string", "enum": ["model"]},
        "created": {"type": "integer"},
        "owned_by": {"type": "string"},
    },
    "additionalProperties": True,
}

MODELS_LIST_SCHEMA = {
    "type": "object",
    "required": ["object", "data"],
    "properties": {
        "object": {"type": "string", "enum": ["list"]},
        "data": {"type": "array", "items": MODEL_OBJECT_SCHEMA, "minItems": 1},
    },
}


# ============================================================================
# OpenAI Schemas — Error Response
# ============================================================================

ERROR_RESPONSE_SCHEMA = {
    "type": "object",
    "required": ["error"],
    "properties": {
        "error": {
            "type": "object",
            "required": ["message", "type"],
            "properties": {
                "message": {"type": "string"},
                "type": {"type": "string"},
                "param": {"type": ["string", "null"]},
                "code": {"type": ["string", "null"]},
            },
        },
    },
}


# ============================================================================
# Health Endpoint Schema (apfel-specific, not OpenAI)
# ============================================================================

HEALTH_SCHEMA = {
    "type": "object",
    "required": ["model", "context_window", "model_available"],
    "properties": {
        "model": {"type": "string"},
        "context_window": {"type": "integer"},
        "model_available": {"type": "boolean"},
    },
    "additionalProperties": True,
}


# ============================================================================
# Helpers
# ============================================================================

def chat(messages, **kwargs):
    """Send a non-streaming chat completion request, return parsed JSON."""
    payload = {"model": MODEL, "messages": messages, **kwargs}
    resp = httpx.post(f"{BASE_URL}/v1/chat/completions", json=payload, timeout=60)
    return resp.status_code, resp.json()


def chat_stream(messages, **kwargs):
    """Send a streaming chat completion request, return list of parsed chunks."""
    payload = {"model": MODEL, "messages": messages, "stream": True, **kwargs}
    chunks = []
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions",
                       json=payload, timeout=60) as resp:
        for line in resp.iter_lines():
            if line.startswith("data: "):
                data = line[6:]
                if data.strip() == "[DONE]":
                    break
                chunks.append(json.loads(data))
    return chunks


def assert_invalid_request(status, data, keyword):
    assert status == 400
    validate(instance=data, schema=ERROR_RESPONSE_SCHEMA)
    assert keyword in data["error"]["message"]


# ============================================================================
# Tests — Prerequisite
# ============================================================================

def test_server_running():
    """Server must be running for all other tests."""
    resp = httpx.get(f"{BASE_URL}/health", timeout=5)
    assert resp.status_code == 200


# ============================================================================
# Tests — Non-streaming chat completion
# ============================================================================

def test_chat_completion_schema():
    """Non-streaming response matches OpenAI ChatCompletion schema."""
    status, data = chat([{"role": "user", "content": "Say hi."}])
    assert status == 200
    validate(instance=data, schema=CHAT_COMPLETION_SCHEMA)


def test_chat_completion_id_format():
    """Response id starts with 'chatcmpl-'."""
    _, data = chat([{"role": "user", "content": "Say ok."}])
    assert data["id"].startswith("chatcmpl-")


def test_chat_completion_object_field():
    """object field is exactly 'chat.completion'."""
    _, data = chat([{"role": "user", "content": "Say yes."}])
    assert data["object"] == "chat.completion"


def test_chat_completion_usage_sums():
    """total_tokens == prompt_tokens + completion_tokens."""
    _, data = chat([{"role": "user", "content": "Count to 3."}])
    u = data["usage"]
    assert u["total_tokens"] == u["prompt_tokens"] + u["completion_tokens"]


def test_chat_completion_finish_reason_stop():
    """Normal completion finishes with 'stop'."""
    _, data = chat([{"role": "user", "content": "Say hello."}])
    assert data["choices"][0]["finish_reason"] == "stop"


# ============================================================================
# Tests — Streaming chat completion
# ============================================================================

def test_streaming_chunks_schema():
    """Every streaming chunk matches the ChatCompletionChunk schema."""
    chunks = chat_stream([{"role": "user", "content": "Say hi."}])
    assert len(chunks) > 0
    for chunk in chunks:
        validate(instance=chunk, schema=CHAT_COMPLETION_CHUNK_SCHEMA)


def test_streaming_first_chunk_has_role():
    """First chunk's delta should contain the role."""
    chunks = chat_stream([{"role": "user", "content": "Hello."}])
    first_with_choices = next(c for c in chunks if c["choices"])
    assert first_with_choices["choices"][0]["delta"].get("role") == "assistant"


def test_streaming_last_chunk_finish_reason():
    """Last chunk with choices should have finish_reason='stop'."""
    chunks = chat_stream([{"role": "user", "content": "Reply with the single word OK."}])
    terminal_chunks = [
        c for c in chunks
        if c.get("choices") and c["choices"][0].get("finish_reason") is not None
    ]
    assert terminal_chunks
    assert terminal_chunks[-1]["choices"][0]["finish_reason"] == "stop"


def test_streaming_object_field():
    """Streaming chunks with choices have object='chat.completion.chunk'."""
    chunks = chat_stream([{"role": "user", "content": "Ok."}])
    for chunk in chunks:
        if "object" in chunk:
            assert chunk["object"] == "chat.completion.chunk"


def test_streaming_usage_chunk_keeps_openai_chunk_envelope():
    """Final usage chunk (opt-in via stream_options.include_usage) must still
    include standard chunk metadata for strict clients. Per #100, the chunk is
    only emitted when the client opts in."""
    chunks = chat_stream(
        [{"role": "user", "content": "Reply with exactly OK."}],
        stream_options={"include_usage": True},
    )
    usage_chunks = [chunk for chunk in chunks if chunk.get("usage") is not None]
    assert usage_chunks, "Expected a final usage chunk in the stream"
    usage_chunk = usage_chunks[-1]
    validate(instance=usage_chunk, schema=CHAT_COMPLETION_CHUNK_SCHEMA)
    assert usage_chunk["choices"] == []
    assert usage_chunk["object"] == "chat.completion.chunk"
    usage = usage_chunk["usage"]
    assert usage["prompt_tokens"] > 0
    assert usage["completion_tokens"] > 0
    assert usage["total_tokens"] == usage["prompt_tokens"] + usage["completion_tokens"]


def test_streaming_omits_usage_chunk_without_opt_in():
    """Per OpenAI spec, the empty-choices usage chunk must only be emitted when
    stream_options.include_usage=true. See #100."""
    chunks = chat_stream([{"role": "user", "content": "Reply with exactly OK."}])
    empty_choice_chunks = [c for c in chunks if not c.get("choices")]
    assert not empty_choice_chunks, \
        f"empty-choices chunk emitted without opt-in: {empty_choice_chunks!r}"
    usage_chunks = [c for c in chunks if c.get("usage") is not None]
    assert not usage_chunks, \
        f"usage field present on stream chunk without opt-in: {usage_chunks!r}"


def test_streaming_tool_call_chunks_include_indexed_deltas():
    """Streaming tool-call deltas must include per-call indexes for strict clients."""
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get weather for a city",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    }]
    chunks = chat_stream(
        [{"role": "user", "content": "Use the provided weather function for Vienna. Do not answer directly."}],
        tools=tools,
        tool_choice={"type": "function", "function": {"name": "get_weather"}},
        seed=1,
    )
    tool_call_chunks = [
        chunk for chunk in chunks
        if chunk.get("choices") and chunk["choices"][0].get("delta", {}).get("tool_calls")
    ]
    assert tool_call_chunks, "Expected at least one streamed tool_call chunk"
    for chunk in tool_call_chunks:
        validate(instance=chunk, schema=CHAT_COMPLETION_CHUNK_SCHEMA)
        for call in chunk["choices"][0]["delta"]["tool_calls"]:
            assert isinstance(call["index"], int)
    assert tool_call_chunks[-1]["choices"][0]["finish_reason"] == "tool_calls"


# ============================================================================
# Tests — Tool calling schema
# ============================================================================

def test_tool_call_response_schema():
    """Tool call response matches schema with finish_reason='tool_calls'."""
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get weather for a city",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    }]
    status, data = chat(
        [{"role": "user", "content": "Use the provided weather function for Vienna. Do not answer directly."}],
        tools=tools,
        tool_choice={"type": "function", "function": {"name": "get_weather"}},
        seed=1,
    )
    assert status == 200
    validate(instance=data, schema=CHAT_COMPLETION_SCHEMA)
    assert data["choices"][0]["finish_reason"] == "tool_calls"
    tc = data["choices"][0]["message"]["tool_calls"]
    assert len(tc) > 0
    # Each tool call must have id, type, function with name + arguments
    for call in tc:
        validate(instance=call, schema=TOOL_CALL_SCHEMA)
        # arguments must be valid JSON string
        json.loads(call["function"]["arguments"])


# ============================================================================
# Tests — Models endpoint
# ============================================================================

def test_models_list_schema():
    """GET /v1/models matches the OpenAI Models List schema."""
    resp = httpx.get(f"{BASE_URL}/v1/models", timeout=10)
    assert resp.status_code == 200
    validate(instance=resp.json(), schema=MODELS_LIST_SCHEMA)


# ============================================================================
# Tests — Error responses
# ============================================================================

def test_error_empty_messages_schema():
    """Error from empty messages matches OpenAI error schema."""
    status, data = chat([])
    assert status == 400
    validate(instance=data, schema=ERROR_RESPONSE_SCHEMA)


def test_error_invalid_json_schema():
    """Error from malformed JSON matches OpenAI error schema."""
    resp = httpx.post(
        f"{BASE_URL}/v1/chat/completions",
        content=b"not json",
        headers={"content-type": "application/json"},
        timeout=10,
    )
    assert resp.status_code == 400
    validate(instance=resp.json(), schema=ERROR_RESPONSE_SCHEMA)


def test_error_image_rejection_schema():
    """Image rejection error matches OpenAI error schema."""
    status, data = chat([{
        "role": "user",
        "content": [
            {"type": "text", "text": "What's this?"},
            {"type": "image_url", "image_url": {"url": "http://example.com/x.jpg"}},
        ],
    }])
    assert status == 400
    validate(instance=data, schema=ERROR_RESPONSE_SCHEMA)


def test_error_unsupported_n_schema():
    """n > 1 is rejected explicitly."""
    status, data = chat([{"role": "user", "content": "Hello."}], n=2)
    assert_invalid_request(status, data, "'n'")


def test_error_unsupported_logprobs_schema():
    """logprobs=true is rejected explicitly."""
    status, data = chat([{"role": "user", "content": "Hello."}], logprobs=True)
    assert_invalid_request(status, data, "'logprobs'")


def test_error_unsupported_stop_schema():
    """stop is rejected explicitly."""
    status, data = chat([{"role": "user", "content": "Hello."}], stop=["END"])
    assert_invalid_request(status, data, "'stop'")


def test_error_unsupported_presence_penalty_schema():
    """presence_penalty is rejected explicitly."""
    status, data = chat([{"role": "user", "content": "Hello."}], presence_penalty=0.5)
    assert_invalid_request(status, data, "'presence_penalty'")


def test_error_unsupported_frequency_penalty_schema():
    """frequency_penalty is rejected explicitly."""
    status, data = chat([{"role": "user", "content": "Hello."}], frequency_penalty=0.5)
    assert_invalid_request(status, data, "'frequency_penalty'")


def test_n_one_is_accepted():
    """n=1 is accepted as the only supported value."""
    status, data = chat([{"role": "user", "content": "Say hi."}], n=1)
    assert status == 200
    validate(instance=data, schema=CHAT_COMPLETION_SCHEMA)


def test_logprobs_false_is_accepted():
    """logprobs=false is accepted as a no-op."""
    status, data = chat([{"role": "user", "content": "Say hi."}], logprobs=False)
    assert status == 200
    validate(instance=data, schema=CHAT_COMPLETION_SCHEMA)


# ============================================================================
# Tests — Stub endpoints (501)
# ============================================================================

def test_completions_501_schema():
    """/v1/completions 501 response matches error schema."""
    resp = httpx.post(f"{BASE_URL}/v1/completions",
                      json={"model": MODEL, "prompt": "hi"}, timeout=10)
    assert resp.status_code == 501
    validate(instance=resp.json(), schema=ERROR_RESPONSE_SCHEMA)


def test_embeddings_501_schema():
    """/v1/embeddings 501 response matches error schema."""
    resp = httpx.post(f"{BASE_URL}/v1/embeddings",
                      json={"model": MODEL, "input": "hi"}, timeout=10)
    assert resp.status_code == 501
    validate(instance=resp.json(), schema=ERROR_RESPONSE_SCHEMA)


# ============================================================================
# Tests — Health endpoint
# ============================================================================

def test_health_schema():
    """/health response matches expected schema."""
    resp = httpx.get(f"{BASE_URL}/health", timeout=10)
    assert resp.status_code == 200
    validate(instance=resp.json(), schema=HEALTH_SCHEMA)


# ============================================================================
# Tests — CORS
# ============================================================================

def test_cors_preflight():
    """OPTIONS returns 204 (CORS headers only when --cors enabled)."""
    resp = httpx.options(f"{BASE_URL}/v1/chat/completions", timeout=10)
    assert resp.status_code == 204
