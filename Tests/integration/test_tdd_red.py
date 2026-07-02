"""
apfel Integration Tests - regression guards for tickets #167-#183, #219, #243.

Originally written as TDD RED tests (branch tdd/red-tests-167-183). All tickets
are now closed and fixed. These tests are REGRESSION GUARDS that lock the fixes
in place - they should stay green.

Wire/CLI-boundary tests (things the pure-Swift unit target cannot reach):
  #167 json_schema, #169 prewarm (model-free),
  #171 streamed structured output, #176 tool-def token undercount,
  #219 anyOf/oneOf unions, #243 number allows fractional

Source-level wiring guards (failure condition not externally triggerable, so the
test asserts the fix's structural presence in source code):
  #168 top_p/greedy mapping, #175 summarize budget, #179 refusal accounting,
  #182 streaming-retry stdout

Model-dependent tests run under local `make test` where Apple Intelligence is
present. #169 and the source-level guards are model-free and run anywhere.

Run: python3 -m pytest Tests/integration/test_tdd_red.py -v
"""

import json
import pathlib

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE = "http://localhost:11434"
BASE_URL = f"{BASE}/v1"
MODEL = "apple-foundationmodel"
TIMEOUT = 60


def _chat(payload):
    return httpx.post(f"{BASE_URL}/chat/completions", json=payload, timeout=TIMEOUT)


# ---------------------------------------------------------------------------
# #169 prewarm() — MODEL-FREE, runs everywhere (including GitHub CI)
# ---------------------------------------------------------------------------

def test_169_health_reports_prewarmed():
    """/health must expose whether the model was prewarmed at startup (#169).

    Contract chosen in the plan: GET /health returns a boolean "prewarmed"
    field. Today the field is absent -> RED.
    """
    data = httpx.get(f"{BASE}/health", timeout=10).json()
    assert "prewarmed" in data, "/health must include a 'prewarmed' field (#169)"
    assert isinstance(data["prewarmed"], bool)


# ---------------------------------------------------------------------------
# #167 response_format: json_schema — guaranteed structured outputs
# ---------------------------------------------------------------------------

def test_167_json_schema_conformance():
    """response_format json_schema must return content conforming to the schema (#167).

    Today only json_object is supported; json_schema is unsupported -> RED.
    """
    schema = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"},
        },
        "required": ["name", "age"],
        "additionalProperties": False,
    }
    resp = _chat({
        "model": MODEL,
        "messages": [{"role": "user", "content": "Return a person named Alice aged 30."}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "Person", "schema": schema, "strict": True},
        },
    })
    assert resp.status_code == 200, f"json_schema request should succeed, got {resp.status_code}: {resp.text}"
    content = resp.json()["choices"][0]["message"]["content"]
    data = json.loads(content)  # must be valid JSON
    assert set(data.keys()) == {"name", "age"}, "output must conform exactly to the schema (no extra/missing keys)"
    assert isinstance(data["age"], int)


# ---------------------------------------------------------------------------
# #168 top_p honored + temperature:0 deterministic
# ---------------------------------------------------------------------------

def test_168_top_p_and_greedy_mapping():
    """#168: top_p must map to .random(probabilityThreshold:) and temperature:0
    to .greedy.

    Verified NOT externally observable: the on-device model is already
    empirically deterministic at temperature:0 for ordinary prompts (so an
    output-equality test is a false green), and top_p has no API-visible effect.
    The mapping lived in Session.makeGenerationOptions in the FoundationModels-
    coupled executable target, which the unit runner cannot import.

    FIXED (#168): the sampling policy was extracted into a pure,
    FoundationModels-free decision — SamplingDecision.resolve(temperature:topP:seed:)
    in ApfelCore — so it is exercised deterministically by the unit suite
    (Tests/apfelTests/SamplingDecisionTests.swift, runSamplingDecisionTests):
    top_p -> .nucleus(probabilityThreshold:seed:), temperature:0 (no top_p) ->
    .greedy, seed-only -> .topK(top:50,seed:). The executable's
    makeGenerationOptions/makeSamplingMode translate that decision into the SDK's
    GenerationOptions.SamplingMode. SessionOptions and the OpenAI request type
    now carry top_p, plumbed from both the server (Sources/Handlers.swift) and
    the CLI (`--top-p`).

    This source-level guard pins the wiring so the mapping cannot silently
    regress, and the wire smoke test below confirms a top_p request still 200s.
    """
    session = (ROOT / "Sources" / "Session.swift").read_text()
    assert "SamplingDecision.resolve(" in session, (
        "makeGenerationOptions must derive its sampling mode from the pure "
        "SamplingDecision.resolve seam (#168)")
    assert ".random(probabilityThreshold: probabilityThreshold, seed: seed)" in session, (
        "top_p (nucleus) must map to .random(probabilityThreshold:seed:) (#168)")
    assert "return .greedy" in session, (
        "temperature:0 (no top_p) must map to .greedy for determinism (#168)")

    decision = (ROOT / "Sources" / "Core" / "SamplingDecision.swift").read_text()
    assert "public static func resolve(" in decision, (
        "the pure sampling-policy seam must live in ApfelCore so it is "
        "unit-testable without FoundationModels (#168)")


def test_168_top_p_request_succeeds():
    """A chat request carrying top_p must be accepted (200), not rejected (#168)."""
    resp = _chat({
        "model": MODEL,
        "messages": [{"role": "user", "content": "Say hi."}],
        "top_p": 0.9,
    })
    assert resp.status_code == 200, f"top_p request should succeed, got {resp.status_code}: {resp.text}"


# ---------------------------------------------------------------------------
# #171 streamed structured output (PartiallyGenerated) — depends on #167
# ---------------------------------------------------------------------------

def test_171_streaming_json_schema_yields_valid_final_json():
    """Streaming with json_schema must produce a valid, conforming final JSON (#171)."""
    schema = {
        "type": "object",
        "properties": {"steps": {"type": "array", "items": {"type": "string"}}},
        "required": ["steps"],
        "additionalProperties": False,
    }
    with httpx.stream(
        "POST", f"{BASE_URL}/chat/completions",
        json={
            "model": MODEL,
            "messages": [{"role": "user", "content": "List three steps to brew tea."}],
            "response_format": {"type": "json_schema", "json_schema": {"name": "Steps", "schema": schema}},
            "stream": True,
        },
        timeout=TIMEOUT,
    ) as r:
        assert r.status_code == 200, f"streamed json_schema should succeed, got {r.status_code}"
        acc = ""
        for line in r.iter_lines():
            if line.startswith("data: ") and "[DONE]" not in line:
                chunk = json.loads(line[len("data: "):])
                delta = chunk["choices"][0]["delta"].get("content")
                if delta:
                    acc += delta
    final = json.loads(acc)
    assert "steps" in final and isinstance(final["steps"], list)


# ---------------------------------------------------------------------------
# #176 fallback token counter ignores tool definitions (this machine = 26.3.1,
# so the buggy fallbackCount path is live)
# ---------------------------------------------------------------------------

def test_176_tool_definitions_count_toward_prompt_tokens():
    """A large tool definition must increase usage.prompt_tokens (#176).

    fallbackCount (macOS < 26.4) ignores Instructions.toolDefinitions entirely,
    so adding a huge tool schema barely changes prompt_tokens -> RED.
    """
    msg = [{"role": "user", "content": "Say hi."}]
    base = _chat({"model": MODEL, "messages": msg})
    assert base.status_code == 200, base.text
    base_pt = base.json()["usage"]["prompt_tokens"]

    big_desc = "This tool does an extremely elaborate calculation. " * 80  # ~4k chars
    withtool = _chat({
        "model": MODEL,
        "messages": msg,
        "tools": [{
            "type": "function",
            "function": {
                "name": "elaborate_calc",
                "description": big_desc,
                "parameters": {
                    "type": "object",
                    "properties": {"x": {"type": "number", "description": big_desc}},
                    "required": ["x"],
                },
            },
        }],
    })
    assert withtool.status_code == 200, withtool.text
    tool_pt = withtool.json()["usage"]["prompt_tokens"]
    assert tool_pt > base_pt + 200, (
        f"large tool definition must add to prompt_tokens; base={base_pt}, with_tool={tool_pt} "
        "(fallbackCount ignores toolDefinitions)")


# ---------------------------------------------------------------------------
# #175 summarize strategy must not exceed the context budget
# ---------------------------------------------------------------------------

def test_175_summarize_keeps_prompt_within_budget():
    """#175: the summarize strategy must cap summary size and verify the final
    assembly fits the budget. Source-level guard: assert the structural wiring
    that prevents unbounded summary overflow is present in the executable target.
    """
    summarizer = (ROOT / "Sources" / "Summarizer.swift").read_text()
    assert "budget / summaryBudgetFraction" in summarizer, (
        "generateSummary must cap summary tokens to a fraction of the budget (#175)")
    assert "fitsTranscriptBudget(" in summarizer, (
        "trimWithSummary must verify assembled transcript fits the budget (#175)")
    assert "trimNewestFirst(" in summarizer, (
        "trimWithSummary must fall back to trimNewestFirst when budget is exceeded (#175)")
    assert "summarize: Summarizer" in summarizer, (
        "trimWithSummary must accept an injectable summarizer for deterministic testing (#175)")


# ---------------------------------------------------------------------------
# Tier 3 — failure condition is NOT externally triggerable. Explicit RED
# placeholders; a deterministic test needs the fix PR to add a testability seam
# (these bugs live in the FoundationModels-coupled executable target, which the
# unit runner cannot import, and the trigger — a mid-stream refusal / mid-stream
# retryable error — cannot be forced from a client).
# ---------------------------------------------------------------------------

def test_179_streaming_refusal_counts_pre_refusal_tokens():
    """#179: a refusal AFTER content has streamed must include the pre-refusal
    content in usage.completion_tokens.

    A client cannot force the model to stream content and THEN refuse, so the
    accounting itself is exercised deterministically in the pure-Swift unit
    suite via StreamErrorResolver.refusalCompletionText (see
    Tests/apfelTests/StreamErrorResolverTests.swift). The fix extracted that
    seam and wired the streaming refusal branch in Sources/Handlers.swift to
    count `prev + explanation` rather than `explanation` alone. This test
    guards that wiring at the source level so the bug cannot silently regress.
    """
    handlers = (ROOT / "Sources" / "Handlers.swift").read_text()
    # The refusal branch must count the pre-refusal streamed content, not just
    # the explanation. The pure helper combines both.
    assert "refusalCompletionText(prev: prev, explanation: explanation)" in handlers, (
        "streaming refusal must token-count the pre-refusal streamed content "
        "(prev) plus the explanation via the pure helper")
    assert "TokenCounter.shared.count(explanation)" not in handlers, (
        "refusal completion tokens must NOT count the explanation alone "
        "(that drops the already-streamed `prev` content)")

    resolver = (ROOT / "Sources" / "Core" / "Chat" / "StreamOutcome.swift").read_text()
    assert "func refusalCompletionText(prev: String, explanation: String) -> String" in resolver, (
        "the pure completion-token helper must exist in ApfelCore so it is "
        "unit-testable without FoundationModels")


def test_182_streaming_retry_prints_output_once():
    """#182: a retryable error mid-stream must not reprint already-streamed output.
    Source-level guard: assert StreamPrintSink exists with its high-water mark
    seam, and that the streaming loop in Session.swift uses it.
    """
    policy = (ROOT / "Sources" / "Core" / "Chat" / "StreamRetryPolicy.swift").read_text()
    assert "public actor StreamPrintSink" in policy, (
        "StreamPrintSink must exist as the retry-safe print seam (#182)")
    assert "emittedCount" in policy, (
        "StreamPrintSink must track a high-water mark of emitted characters (#182)")
    assert "func feed(cumulative content: String)" in policy, (
        "StreamPrintSink must expose a cumulative-snapshot feed method (#182)")

    session = (ROOT / "Sources" / "Session.swift").read_text()
    assert "StreamPrintSink()" in session, (
        "the streaming loop must create a StreamPrintSink instance (#182)")


# ---------------------------------------------------------------------------
# #219 anyOf/oneOf/type-arrays — nullable unions parse, unsupported ones 400
# ---------------------------------------------------------------------------

def test_219_json_schema_unsupported_union_returns_400():
    """An unsupported union in a json_schema must be an honest 400, not a silent
    accept of an empty (unconstrained) schema (#219).

    Server-only: schema conversion fails before the model is invoked, so this
    runs anywhere the server is up.
    """
    schema = {
        "type": "object",
        "properties": {"x": {"anyOf": [{"type": "string"}, {"type": "number"}]}},
        "required": ["x"],
    }
    resp = _chat({
        "model": MODEL,
        "messages": [{"role": "user", "content": "give me an x"}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "Bad", "schema": schema},
        },
    })
    assert resp.status_code == 400, (
        f"unsupported union schema must 400, got {resp.status_code}: {resp.text}")
    assert resp.json()["error"]["type"] == "invalid_request_error"


def test_219_json_schema_nullable_property_conforms():
    """A nullable (Optional[...]) property parses and generation is constrained
    to the real schema, not an empty object (#219). Model-dependent."""
    schema = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "nickname": {"anyOf": [{"type": "string"}, {"type": "null"}]},
        },
        "required": ["name", "nickname"],
        "additionalProperties": False,
    }
    resp = _chat({
        "model": MODEL,
        "messages": [{"role": "user", "content": "Return a person named Alice with no nickname."}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "Person", "schema": schema, "strict": True},
        },
    })
    assert resp.status_code == 200, (
        f"nullable-property json_schema should succeed, got {resp.status_code}: {resp.text}")
    data = json.loads(resp.json()["choices"][0]["message"]["content"])
    assert "name" in data, f"schema must constrain output to real properties, got {data}"


# ---------------------------------------------------------------------------
# #243 json_schema "number" must allow fractional output (was generated as Int)
# ---------------------------------------------------------------------------

def test_243_json_schema_number_allows_fractional():
    """A json_schema {"type":"number"} property must be able to produce a
    fractional value like 9.99. Previously the IR conflated integer+number and
    mapped both to Int, so fractional outputs were silently unreachable (#243).
    Model-dependent."""
    schema = {
        "type": "object",
        "properties": {"price": {"type": "number"}},
        "required": ["price"],
        "additionalProperties": False,
    }
    # The fix makes fractional values POSSIBLE; the model is not forced to
    # emit one on any single sample. Ask for an exact fractional price and
    # allow a few attempts so scheduler/sampling noise cannot flake a release
    # run (#264 discipline) - with the old Int mapping every attempt returns a
    # whole number, so the loop still fails deterministically pre-fix.
    last_price = None
    for _ in range(3):
        resp = _chat({
            "model": MODEL,
            "messages": [{"role": "user", "content": "The price is exactly 9.99 dollars. Return the price."}],
            "response_format": {
                "type": "json_schema",
                "json_schema": {"name": "Priced", "schema": schema, "strict": True},
            },
        })
        assert resp.status_code == 200, f"number json_schema should succeed, got {resp.status_code}: {resp.text}"
        data = json.loads(resp.json()["choices"][0]["message"]["content"])
        last_price = data["price"]
        if isinstance(last_price, float) and last_price != int(last_price):
            return
    raise AssertionError(
        f"a JSON Schema 'number' must permit a fractional value; 3 attempts all "
        f"returned whole numbers, last was {last_price!r} (Int mapping would make "
        "fractions unreachable)")
