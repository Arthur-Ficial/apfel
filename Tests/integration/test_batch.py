"""
apfel Integration Tests - `apfel --batch` JSONL record processing (#481).

Model-free (run on CI): invalid flag combinations exit 2 before the model is
touched, and a terminal on stdin is a usage error (records must be piped).

Model (`@pytest.mark.model`, local `make test` / release only): the
mixed success/failure fixture, schema-guided records, incremental output
while stdin stays open, no transcript leakage between records, truncation
marked as incomplete, stdout backpressure suspending stdin intake, SIGINT
mid-batch, a closed stdout pipe, quiet diagnostics and NO_COLOR, plus a
recorded (never asserted) process-startup saving versus one process per
record. Every --batch run passes the model-availability gate first, so even
the record-validation paths are model tests.

Run: python3 -m pytest Tests/integration/test_batch.py -v
"""

import json
import os
import pathlib
import platform
import pty
import select
import signal
import subprocess
import threading
import time

import pytest

from conftest import require_model

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
FIXTURES = pathlib.Path(__file__).parent / "fixtures" / "batch"
MIXED = FIXTURES / "mixed.jsonl"
TICKETS = FIXTURES / "tickets.jsonl"
LABEL_SCHEMA = FIXTURES / "ticket_label.json"

FIELDS = ["line", "custom_id", "status", "content", "finish_reason", "partial_content", "error"]


def _env(**extra):
    env = {k: v for k, v in os.environ.items() if not k.startswith("APFEL_")}
    env.update(extra)
    return env


def _run(args, stdin_text="", timeout=180, **env):
    return subprocess.run(
        [str(BINARY), *args], input=stdin_text, capture_output=True,
        text=True, timeout=timeout, env=_env(**env))


def _records(stdout):
    out = []
    for raw in stdout.splitlines():
        obj = json.loads(raw)
        assert list(obj.keys()) == FIELDS, f"field order/contract changed: {raw}"
        out.append(obj)
    return out


def _readline_with_timeout(stream, timeout):
    """Read one line from a binary pipe without blocking past `timeout`."""
    deadline = time.monotonic() + timeout
    buf = b""
    fd = stream.fileno()
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], max(0.0, deadline - time.monotonic()))
        if not ready:
            break
        chunk = os.read(fd, 1)
        if not chunk:
            break
        buf += chunk
        if chunk == b"\n":
            return buf.decode()
    return None


def _exact_finish_signal():
    """macOS 26.4+ has the on-device tokenizer API; below it an explicit
    --max-tokens cap cannot be detected exactly (CompletionPolicy)."""
    major, minor = (platform.mac_ver()[0].split(".") + ["0"])[:2]
    return (int(major), int(minor)) >= (26, 4)


# ============================================================================
# Model-free: invocation errors (exit 2) before the availability gate
# ============================================================================

@pytest.mark.parametrize("args,needle", [
    (["--batch", "hello"], "--batch reads records from stdin"),
    (["--batch", "-o", "json"], "--batch always writes JSONL"),
    (["--batch", "--stream"], "--batch"),
    (["--batch", "--code"], "--code requires a single one-shot prompt"),
    (["--batch", "--require-complete"], "--batch already treats a truncated record as a failure"),
    (["--batch", "--mcp", "mcp/calculator/server.py"], "--batch cannot be combined with MCP tool calling"),
    (["--batch", "--messages", "-"], "--messages cannot be combined with --batch"),
])
def test_batch_invalid_flag_combinations_exit_2(args, needle):
    r = _run(args, stdin_text='{"custom_id":"a","prompt":"hi"}\n', timeout=20)
    assert r.returncode == 2, r.stderr
    assert needle in r.stderr
    assert r.stdout == ""


def test_batch_env_mcp_is_rejected():
    r = _run(["--batch"], stdin_text="", timeout=20, APFEL_MCP=str(ROOT / "mcp/calculator/server.py"))
    assert r.returncode == 2
    assert "--batch cannot be combined with MCP tool calling" in r.stderr


def test_batch_with_terminal_stdin_is_a_usage_error():
    master, slave = pty.openpty()
    try:
        r = subprocess.run([str(BINARY), "--batch"], stdin=slave, capture_output=True,
                           text=True, timeout=20, env=_env())
    finally:
        os.close(slave)
        os.close(master)
    assert r.returncode == 2
    assert "--batch reads JSONL records from piped stdin" in r.stderr
    assert r.stdout == ""


# ============================================================================
# Model: the record contract
# ============================================================================

@pytest.mark.model
def test_batch_mixed_fixture_success_and_failure():
    require_model()
    r = _run(["--batch", "--temperature", "0"], MIXED.read_text())
    assert r.returncode == 1, r.stderr
    recs = _records(r.stdout)
    # One line per non-blank input line, in input order (line 4 is blank).
    assert [x["line"] for x in recs] == [1, 2, 3, 5, 6, 7, 8]
    by_line = {x["line"]: x for x in recs}

    for line in (1, 6, 8):
        rec = by_line[line]
        if rec["status"] == "error" and rec["error"]["type"] == "content_policy_violation":
            continue  # a guardrail block is a model outcome, still a valid record
        assert rec["status"] == "ok", rec
        assert rec["content"].strip()
        assert rec["error"] is None
    assert "vienna" in by_line[1]["content"].lower() or by_line[1]["status"] == "error"

    for line in (2, 3, 5, 7):
        rec = by_line[line]
        assert rec["status"] == "error"
        assert rec["content"] is None
        assert rec["error"]["type"] == "invalid_record"
        assert rec["error"]["exit_code"] == 2
    assert by_line[2]["custom_id"] is None
    assert by_line[3]["custom_id"] == "no-input"
    assert by_line[5]["custom_id"] == "both"
    assert by_line[7]["custom_id"] is None
    # Repeated custom_id is echoed for both records; `line` disambiguates.
    assert by_line[1]["custom_id"] == by_line[8]["custom_id"] == "capital"

    assert "batch: 7 records" in r.stderr
    assert "4 failed" in r.stderr


@pytest.mark.model
def test_batch_all_ok_exits_0_and_empty_input_exits_0():
    require_model()
    r = _run(["--batch"], '{"custom_id":"a","prompt":"Say hello in one word."}\n')
    assert r.returncode == 0, r.stderr
    [rec] = _records(r.stdout)
    assert rec["status"] in ("ok", "error")
    empty = _run(["--batch"], "")
    assert empty.returncode == 0
    assert empty.stdout == ""
    assert "batch: 0 records" in empty.stderr


@pytest.mark.model
def test_batch_schema_guided_records():
    require_model()
    r = _run(["--batch", "--temperature", "0", "-s", "You label customer support tickets.",
              "--schema", str(LABEL_SCHEMA)], TICKETS.read_text())
    recs = _records(r.stdout)
    assert [x["custom_id"] for x in recs] == ["101", "102", "103"]
    for rec in recs:
        if rec["status"] == "error":
            assert rec["error"]["type"] == "content_policy_violation", rec
            continue
        assert rec["status"] == "ok"
        label = json.loads(rec["content"])
        assert label["category"] in ("billing", "bug", "question")
        # Schema-constrained decoding reports no finish reason.
        assert rec["finish_reason"] is None
    assert r.returncode in (0, 1)
    assert r.returncode == (1 if any(x["status"] != "ok" for x in recs) else 0)


@pytest.mark.model
def test_batch_output_is_flushed_before_stdin_eof():
    """Record A's result arrives while stdin is still open."""
    require_model()
    proc = subprocess.Popen([str(BINARY), "--batch"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=_env())
    try:
        proc.stdin.write(b'{"custom_id":"first","prompt":"Say hi in one word."}\n')
        proc.stdin.flush()
        line = _readline_with_timeout(proc.stdout, 120)
        assert line is not None, "no output before EOF: records are not processed incrementally"
        assert json.loads(line)["custom_id"] == "first"
        assert proc.poll() is None, "apfel exited before stdin closed"
        proc.stdin.write(b'{"custom_id":"second","prompt":"Say bye in one word."}\n')
        proc.stdin.close()
        rest = proc.stdout.read().decode()
        assert proc.wait(timeout=120) in (0, 1)
        assert [json.loads(x)["custom_id"] for x in rest.splitlines()] == ["second"]
    finally:
        if proc.poll() is None:
            proc.kill()


@pytest.mark.model
def test_batch_records_do_not_share_transcript_history():
    require_model()
    stdin = (
        json.dumps({"custom_id": "a", "prompt": "Remember this secret code word: ZEBRA-7731. Reply with just OK."}) + "\n"
        + json.dumps({"custom_id": "b", "prompt": "What secret code word did I tell you earlier in this conversation? If you were not told one, reply exactly NONE."}) + "\n"
    )
    r = _run(["--batch", "--temperature", "0"], stdin)
    recs = _records(r.stdout)
    assert [x["custom_id"] for x in recs] == ["a", "b"]
    b = recs[1]
    text = (b["content"] or "") + (b["partial_content"] or "")
    assert "7731" not in text and "ZEBRA" not in text.upper(), b


@pytest.mark.model
def test_batch_truncation_is_marked_incomplete_and_fails():
    require_model()
    r = _run(["--batch", "--max-tokens", "4"],
             '{"custom_id":"long","prompt":"Write a 300-word essay about apples."}\n')
    [rec] = _records(r.stdout)
    if rec["status"] == "error":
        assert rec["error"]["type"] == "content_policy_violation", rec
        return
    if _exact_finish_signal():
        assert rec["status"] == "incomplete", rec
        assert rec["content"] is None
        assert rec["partial_content"]
        assert rec["finish_reason"] == "length"
        assert rec["error"]["type"] == "incomplete"
        assert rec["error"]["exit_code"] == 8
        assert r.returncode == 1
    else:
        # Below macOS 26.4 the cap cannot be detected: unknown, said so.
        assert rec["status"] == "ok"
        assert rec["finish_reason"] is None
        assert "cannot tell whether the --max-tokens 4 cap" in r.stderr


@pytest.mark.model
def test_batch_oversized_record_is_an_error_and_processing_continues():
    require_model()
    big = json.dumps({"custom_id": "big", "prompt": "x" * (1024 * 1024 + 10)})
    stdin = big + "\n" + '{"custom_id":"next","prompt":"Say ok in one word."}\n'
    r = _run(["--batch"], stdin)
    recs = _records(r.stdout)
    assert [x["line"] for x in recs] == [1, 2]
    assert recs[0]["status"] == "error"
    assert recs[0]["error"]["type"] == "invalid_record"
    assert "1048576" in recs[0]["error"]["message"]
    assert recs[1]["custom_id"] == "next"
    assert r.returncode == 1


@pytest.mark.model
def test_batch_stdout_backpressure_suspends_stdin_intake():
    """With nobody reading stdout, apfel stops reading stdin: read-ahead is
    bounded, it does not slurp the whole input into memory."""
    require_model()
    n = 60000
    record = b'{"custom_id":"x"}\n'  # invalid (no prompt): fast, no generation
    total = n * len(record)
    proc = subprocess.Popen([str(BINARY), "--batch", "-q"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=_env(), bufsize=0)
    written = [0]

    def writer():
        try:
            for i in range(0, total, 4096):
                chunk = (record * (4096 // len(record) + 1))[: min(4096, total - i)]
                proc.stdin.write(chunk)
                written[0] += len(chunk)
            proc.stdin.close()
        except BrokenPipeError:
            pass

    t = threading.Thread(target=writer, daemon=True)
    t.start()
    try:
        time.sleep(5)
        stalled_at = written[0]
        assert stalled_at < total, "apfel consumed all stdin while stdout was blocked"
        # Pipe buffers (stdin + stdout) plus one bounded read chunk, never ~1 MB.
        assert stalled_at < 600_000, f"read-ahead not bounded: {stalled_at} bytes taken"
        out = proc.stdout.read()
        t.join(timeout=60)
        assert proc.wait(timeout=60) == 1
        assert out.count(b"\n") == n
    finally:
        if proc.poll() is None:
            proc.kill()


@pytest.mark.model
def test_batch_sigint_exits_130_with_complete_lines():
    require_model()
    proc = subprocess.Popen([str(BINARY), "--batch"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=_env())
    try:
        proc.stdin.write(b'{"custom_id":"done","prompt":"Say hi in one word."}\n')
        proc.stdin.flush()
        line = _readline_with_timeout(proc.stdout, 120)
        assert line is not None
        proc.send_signal(signal.SIGINT)
        assert proc.wait(timeout=20) == 130
        rest = proc.stdout.read().decode()
        for raw in (line + rest).splitlines():
            json.loads(raw)  # every emitted line is a complete record
    finally:
        if proc.poll() is None:
            proc.kill()


@pytest.mark.model
def test_batch_closed_stdout_exits_141_quietly():
    require_model()
    proc = subprocess.Popen([str(BINARY), "--batch"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=_env())
    try:
        proc.stdin.write(b'{"custom_id":"one"}\n')
        proc.stdin.flush()
        assert _readline_with_timeout(proc.stdout, 60) is not None
        proc.stdout.close()
        proc.stdin.write(b'{"custom_id":"two"}\n{"custom_id":"three"}\n')
        proc.stdin.close()
        assert proc.wait(timeout=60) == 141
        err = proc.stderr.read().decode()
        assert "Fatal" not in err and "NSFileHandleOperationException" not in err
    finally:
        if proc.poll() is None:
            proc.kill()


@pytest.mark.model
def test_batch_quiet_suppresses_diagnostics_only():
    require_model()
    r = _run(["--batch", "-q"], '{"custom_id":"bad"}\n')
    assert r.returncode == 1
    assert r.stderr == ""
    [rec] = _records(r.stdout)
    assert rec["status"] == "error"


@pytest.mark.model
def test_batch_no_color_and_clean_stdout():
    """stdout is pure JSONL, never ANSI; the stderr summary honors NO_COLOR."""
    require_model()

    def run_with_tty_stderr(**env):
        master, slave = pty.openpty()
        try:
            r = subprocess.run([str(BINARY), "--batch"], input=b'{"custom_id":"bad"}\n',
                               stdout=subprocess.PIPE, stderr=slave, timeout=60, env=_env(**env))
            os.close(slave)
            slave_closed = True
            err = b""
            while True:
                ready, _, _ = select.select([master], [], [], 0.5)
                if not ready:
                    break
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                err += chunk
            return r, err
        finally:
            if not locals().get("slave_closed"):
                os.close(slave)
            os.close(master)

    colored, colored_err = run_with_tty_stderr()
    plain, plain_err = run_with_tty_stderr(NO_COLOR="1")
    assert b"\x1b[" not in colored.stdout and b"\x1b[" not in plain.stdout
    assert b"batch: 1 record" in colored_err and b"batch: 1 record" in plain_err
    assert b"\x1b[" in colored_err
    assert b"\x1b[" not in plain_err


@pytest.mark.model
def test_batch_process_startup_saving_is_recorded(record_property):
    """One process for N records vs N processes. Recorded, never asserted:
    wall-clock speedups are machine- and load-dependent."""
    require_model()
    prompts = ["Say one in one word.", "Say two in one word.", "Say three in one word."]
    stdin = "".join(json.dumps({"custom_id": str(i), "prompt": p}) + "\n" for i, p in enumerate(prompts))
    t0 = time.monotonic()
    batch = _run(["--batch", "--temperature", "0"], stdin)
    batch_s = time.monotonic() - t0
    t0 = time.monotonic()
    for p in prompts:
        _run(["--temperature", "0", p])
    separate_s = time.monotonic() - t0
    assert len(_records(batch.stdout)) == len(prompts)
    record_property("batch_seconds", round(batch_s, 2))
    record_property("separate_process_seconds", round(separate_s, 2))
    print(f"\n--batch {len(prompts)} records: {batch_s:.2f}s; {len(prompts)} processes: {separate_s:.2f}s")
