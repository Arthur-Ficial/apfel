"""
apfel Integration Tests - streamed schema-constrained output (#532).

`stream: true` + `response_format: json_schema` on /v1/chat/completions and
`apfel --stream --schema` print the schema-valid JSON as it is generated.
The contract (decision on #532):

- every streamed piece is append-only: the concatenation of all deltas is
  byte-identical to the non-streamed document for the same seed;
- a multi-field schema arrives in more than one content chunk;
- finish_reason and usage behave as in the non-schema stream.

Model-free (run on CI): CLI flag combinations that stay usage errors.
Model (`@pytest.mark.model`): everything that needs a completion.

Run: python3 -m pytest Tests/integration/test_structured_stream.py -v
"""

import json
import os
import pathlib
import select
import subprocess
import time

import httpx
import pytest

from conftest import require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://localhost:11434"
MODEL = "apple-foundationmodel"
TIMEOUT = 180
SEED = 42

# Strings, an array, a number, an integer and a boolean: the number and the
# boolean are the values the server must hold back until complete (a partial
# number can change, measured on macOS 27.0.1: 4 -> 4.5).
POEM_SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string"},
        "lines": {"type": "array", "items": {"type": "string"}},
        "rating": {"type": "number"},
        "line_count": {"type": "integer"},
        "rhymes": {"type": "boolean"},
    },
    "required": ["title", "lines", "rating", "line_count", "rhymes"],
    "additionalProperties": False,
}
POEM_PROMPT = (
    "Write a four-line poem about the sea with a title. Rate it from 1 to 5 "
    "(decimals allowed), give the number of lines and say whether it rhymes."
)


def _body(stream, include_usage=False, seed=SEED, schema=POEM_SCHEMA, prompt=POEM_PROMPT):
    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "seed": seed,
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "poem", "schema": schema, "strict": True},
        },
    }
    if stream:
        payload["stream"] = True
        if include_usage:
            payload["stream_options"] = {"include_usage": True}
    return payload


def _non_streamed(seed=SEED):
    resp = httpx.post(f"{BASE_URL}/v1/chat/completions", json=_body(False, seed=seed), timeout=TIMEOUT)
    assert resp.status_code == 200, resp.text
    return resp.json()


def _streamed(include_usage=True, seed=SEED):
    """Return (content deltas, finish_reasons, usage chunk or None, saw [DONE])."""
    deltas, finishes, usage, done = [], [], None, False
    with httpx.stream("POST", f"{BASE_URL}/v1/chat/completions",
                      json=_body(True, include_usage, seed=seed), timeout=TIMEOUT) as r:
        assert r.status_code == 200, r.read()
        for line in r.iter_lines():
            if not line.startswith("data: "):
                continue
            data = line[len("data: "):]
            if data == "[DONE]":
                done = True
                continue
            chunk = json.loads(data)
            assert "error" not in chunk, chunk
            if chunk.get("usage"):
                usage = chunk["usage"]
            for choice in chunk.get("choices", []):
                piece = choice["delta"].get("content")
                if piece is not None:
                    deltas.append(piece)
                if choice.get("finish_reason"):
                    finishes.append(choice["finish_reason"])
    return deltas, finishes, usage, done


def _schema_file(tmp_path):
    path = tmp_path / "poem.json"
    path.write_text(json.dumps(POEM_SCHEMA))
    return path


def _cli(args, timeout=TIMEOUT):
    return subprocess.run([str(BINARY), *args], capture_output=True, text=True,
                          timeout=timeout, stdin=subprocess.DEVNULL)


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

@pytest.mark.model
def test_streamed_deltas_concatenate_to_the_non_streamed_document():
    require_model()
    expected = _non_streamed()["choices"][0]["message"]["content"]
    deltas, _, _, _ = _streamed()
    assert "".join(deltas) == expected, (deltas, expected)
    doc = json.loads(expected)
    assert set(doc) == set(POEM_SCHEMA["properties"]), doc


@pytest.mark.model
def test_multi_field_schema_streams_in_more_than_one_chunk():
    require_model()
    deltas, _, _, _ = _streamed()
    assert len(deltas) > 1, f"expected incremental delivery, got {deltas!r}"
    assert all(deltas), f"no empty content deltas: {deltas!r}"
    # Append-only, not a final dump: the first delta opens the document and
    # is a strict prefix of it.
    full = "".join(deltas)
    assert deltas[0].startswith("{") and len(deltas[0]) < len(full)
    json.loads(full)


@pytest.mark.model
def test_streamed_finish_reason_and_usage_match_the_non_streamed_request():
    require_model()
    reference = _non_streamed()
    deltas, finishes, usage, done = _streamed(include_usage=True)
    assert finishes == [reference["choices"][0]["finish_reason"]] == ["stop"], finishes
    assert done, "stream must end with [DONE]"
    assert usage is not None, "include_usage must deliver a usage chunk"
    assert usage["prompt_tokens"] == reference["usage"]["prompt_tokens"], (usage, reference["usage"])
    assert usage["completion_tokens"] > 0
    assert usage["total_tokens"] == usage["prompt_tokens"] + usage["completion_tokens"]


@pytest.mark.model
def test_streamed_without_include_usage_sends_no_usage_chunk():
    require_model()
    _, finishes, usage, done = _streamed(include_usage=False)
    assert finishes == ["stop"] and done
    assert usage is None


@pytest.mark.model
def test_streamed_document_is_append_only_across_seeds():
    """Three more seeds: each streamed document equals its non-streamed twin."""
    require_model()
    for seed in (7, 123, 2024):
        expected = _non_streamed(seed)["choices"][0]["message"]["content"]
        deltas, _, _, _ = _streamed(seed=seed)
        assert "".join(deltas) == expected, f"seed {seed}: {deltas!r} != {expected!r}"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def test_stream_schema_with_mcp_exits_2(tmp_path):
    result = _cli(["--stream", "--schema", str(_schema_file(tmp_path)),
                   "--mcp", "mcp/calculator/server.py", "x"], timeout=30)
    assert result.returncode == 2, result.stderr
    assert "--schema cannot be combined with MCP" in result.stderr


def test_stream_schema_with_stop_exits_2(tmp_path):
    result = _cli(["--stream", "--schema", str(_schema_file(tmp_path)), "--stop", "x", "x"], timeout=30)
    assert result.returncode == 2, result.stderr
    assert "--stop cannot be combined with --schema" in result.stderr


@pytest.mark.model
def test_cli_stream_schema_prints_the_same_json_as_the_buffered_run(tmp_path):
    require_model()
    schema = str(_schema_file(tmp_path))
    buffered = _cli(["--seed", str(SEED), "--schema", schema, POEM_PROMPT])
    streamed = _cli(["--seed", str(SEED), "--stream", "--schema", schema, POEM_PROMPT])
    assert buffered.returncode == 0, buffered.stderr
    assert streamed.returncode == 0, streamed.stderr
    assert streamed.stdout == buffered.stdout, (streamed.stdout, buffered.stdout)
    assert streamed.stdout.endswith("}\n")
    doc = json.loads(streamed.stdout)
    assert set(doc) == set(POEM_SCHEMA["properties"]), doc


@pytest.mark.model
def test_cli_stream_schema_writes_output_while_generating(tmp_path):
    """The JSON reaches stdout in more than one write, the first one well
    before the process exits."""
    require_model()
    proc = subprocess.Popen(
        [str(BINARY), "--seed", str(SEED), "--stream", "--schema", str(_schema_file(tmp_path)), POEM_PROMPT],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    reads, first_at, out = 0, None, b""
    fd = proc.stdout.fileno()
    deadline = time.monotonic() + TIMEOUT
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], 1.0)
        if not ready:
            if proc.poll() is not None:
                break
            continue
        data = os.read(fd, 65536)
        if not data:
            break
        reads += 1
        out += data
        if first_at is None:
            first_at = time.monotonic()
    proc.wait(timeout=30)
    ended_at = time.monotonic()
    assert proc.returncode == 0, proc.stderr.read()
    json.loads(out)
    assert reads > 1, f"expected streamed output in several writes, got {reads}: {out!r}"
    assert first_at is not None and ended_at - first_at > 0.1, "first bytes arrived only at exit"


@pytest.mark.model
def test_cli_stream_schema_json_output_is_the_buffered_envelope(tmp_path):
    require_model()
    schema = str(_schema_file(tmp_path))
    buffered = _cli(["--seed", str(SEED), "-o", "json", "--schema", schema, POEM_PROMPT])
    streamed = _cli(["--seed", str(SEED), "-o", "json", "--stream", "--schema", schema, POEM_PROMPT])
    assert buffered.returncode == 0 and streamed.returncode == 0, (buffered.stderr, streamed.stderr)
    b, s = json.loads(buffered.stdout), json.loads(streamed.stdout)
    assert s["content"] == b["content"]
    json.loads(s["content"])


@pytest.mark.model
def test_cli_messages_stream_schema_prints_the_same_json_as_the_buffered_run(tmp_path):
    """--messages composes with --stream --schema: the streamed reply to the
    conversation equals the buffered one."""
    require_model()
    schema = str(_schema_file(tmp_path))
    messages = tmp_path / "messages.json"
    messages.write_text(json.dumps([
        {"role": "system", "content": "You write short poems."},
        {"role": "user", "content": POEM_PROMPT},
    ]))
    buffered = _cli(["--seed", str(SEED), "--messages", str(messages), "--schema", schema])
    streamed = _cli(["--seed", str(SEED), "--stream", "--messages", str(messages), "--schema", schema])
    assert buffered.returncode == 0, buffered.stderr
    assert streamed.returncode == 0, streamed.stderr
    assert streamed.stdout == buffered.stdout, (streamed.stdout, buffered.stdout)
    json.loads(streamed.stdout)
