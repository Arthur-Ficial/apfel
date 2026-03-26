"""
apfel Integration Tests — OpenAI Python Client E2E

Validates that apfel's OpenAI-compatible server works with the real `openai` library.
Requires: pip install openai pytest httpx
Requires: apfel --serve running on localhost:11434

Run: python3 -m pytest Tests/integration/openai_client_test.py -v
"""

import json
import pytest
import openai
import httpx

BASE_URL = "http://localhost:11434/v1"
MODEL = "apple-foundationmodel"

client = openai.OpenAI(base_url=BASE_URL, api_key="ignored")


# MARK: - Prerequisites

def test_apple_intelligence_enabled():
    """Apple Intelligence must be enabled for all tests to work."""
    resp = httpx.get(f"{BASE_URL.replace('/v1', '')}/health")
    data = resp.json()
    assert data["model_available"] is True, \
        "Apple Intelligence is NOT enabled. Go to System Settings → Apple Intelligence & Siri → Turn on."


# MARK: - Basic Completions

def test_basic_completion():
    """Non-streaming completion returns a response with usage stats."""
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "What is 2+2? Reply with just the number."}]
    )
    assert resp.choices[0].message.content is not None
    assert len(resp.choices[0].message.content) > 0
    assert resp.choices[0].finish_reason == "stop"
    assert resp.usage.prompt_tokens > 0
    assert resp.usage.completion_tokens > 0
    assert resp.usage.total_tokens == resp.usage.prompt_tokens + resp.usage.completion_tokens


def test_streaming():
    """Streaming returns content deltas and terminates with [DONE]."""
    stream = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "Say hello in one word."}],
        stream=True
    )
    content = ""
    for chunk in stream:
        if chunk.choices:
            delta = chunk.choices[0].delta.content
            if delta:
                content += delta
    assert len(content) > 0


def test_multi_turn_history():
    """Server correctly processes multi-turn conversation history."""
    messages = [
        {"role": "user", "content": "What is the capital of France? Reply with just the city name."},
        {"role": "assistant", "content": "Paris"},
        {"role": "user", "content": "And what country is that city in? Reply with just the country name."}
    ]
    resp = client.chat.completions.create(model=MODEL, messages=messages)
    assert "France" in resp.choices[0].message.content


def test_system_prompt():
    """System prompt is respected."""
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": "You are a pirate. Always say 'Arrr'."},
            {"role": "user", "content": "Hello!"}
        ]
    )
    # Model should incorporate pirate behavior
    assert resp.choices[0].message.content is not None


# MARK: - Tool Calling

def test_tool_calling():
    """Tool calling returns finish_reason='tool_calls' with structured tool calls."""
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "The city name"}
                },
                "required": ["city"]
            }
        }
    }]
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "What's the weather in Vienna?"}],
        tools=tools
    )
    assert resp.choices[0].finish_reason == "tool_calls"
    assert len(resp.choices[0].message.tool_calls) > 0
    assert resp.choices[0].message.tool_calls[0].function.name == "get_weather"


# MARK: - JSON Mode

def test_json_mode():
    """response_format: json_object produces valid JSON (may need markdown stripping)."""
    resp = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "Return a JSON object with key 'answer' and value 42."}],
        response_format={"type": "json_object"}
    )
    content = resp.choices[0].message.content.strip()
    # Strip markdown code fences if present (model sometimes wraps JSON in ```)
    if content.startswith("```"):
        lines = content.split("\n")
        # Remove first line (```json or ```) and last line (```)
        lines = [l for l in lines if not l.strip().startswith("```")]
        content = "\n".join(lines).strip()
    parsed = json.loads(content)
    assert isinstance(parsed, dict)


# MARK: - Models Endpoint

def test_models_endpoint():
    """GET /v1/models returns the model list."""
    models = client.models.list()
    assert len(models.data) > 0
    assert models.data[0].id == MODEL


# MARK: - Error Handling

def test_image_rejection():
    """Image content is rejected with a clear error."""
    with pytest.raises(openai.BadRequestError) as exc:
        client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": [
                {"type": "text", "text": "What's in this image?"},
                {"type": "image_url", "image_url": {"url": "http://example.com/img.jpg"}}
            ]}]
        )
    assert "image" in str(exc.value).lower()


def test_empty_messages_rejected():
    """Empty messages array is rejected."""
    with pytest.raises(openai.BadRequestError):
        client.chat.completions.create(model=MODEL, messages=[])


# MARK: - Stub Endpoints

def test_completions_stub_501():
    """/v1/completions returns 501 Not Implemented."""
    resp = httpx.post(f"{BASE_URL.replace('/v1', '')}/v1/completions",
                      json={"model": MODEL, "prompt": "hi"})
    assert resp.status_code == 501


def test_embeddings_stub_501():
    """/v1/embeddings returns 501 Not Implemented."""
    resp = httpx.post(f"{BASE_URL.replace('/v1', '')}/v1/embeddings",
                      json={"model": MODEL, "input": "hi"})
    assert resp.status_code == 501


# MARK: - CORS

def test_cors_preflight():
    """OPTIONS preflight returns CORS headers."""
    resp = httpx.options(f"{BASE_URL.replace('/v1', '')}/v1/chat/completions")
    assert resp.status_code == 204
    assert "access-control-allow-origin" in resp.headers


# MARK: - Health

def test_health_endpoint():
    """GET /health returns model status."""
    resp = httpx.get(f"{BASE_URL.replace('/v1', '')}/health")
    assert resp.status_code == 200
    data = resp.json()
    assert "model" in data
    assert "context_window" in data
    assert "model_available" in data
