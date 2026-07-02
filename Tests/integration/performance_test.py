import json
import pathlib
import statistics
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"

RUNS = 3
SPEEDUP_THRESHOLD = 0.9


def _run_benchmark():
    result = subprocess.run(
        [str(BINARY), "--benchmark", "-o", "json"],
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def test_benchmark_reports_real_speedups():
    payloads = [_run_benchmark() for _ in range(RUNS)]

    all_benchmarks = {}
    for payload in payloads:
        for entry in payload["benchmarks"]:
            all_benchmarks.setdefault(entry["name"], []).append(entry)

    for name in [
        "trim_newest_first",
        "trim_oldest_first",
        "tool_schema_convert",
        "request_body_capture_disabled",
        "stream_debug_capture_disabled",
    ]:
        entries = all_benchmarks[name]
        for entry in entries:
            assert entry["validated"] is True, entry
            assert entry["baseline_avg_ms"] is not None, entry
            assert entry["speedup_ratio"] is not None, entry

        ratios = [e["speedup_ratio"] for e in entries]
        median_ratio = statistics.median(ratios)
        assert median_ratio > SPEEDUP_THRESHOLD, (
            f"{name}: median speedup {median_ratio:.2f} across {RUNS} runs "
            f"is below {SPEEDUP_THRESHOLD} (ratios: {[round(r, 2) for r in ratios]})"
        )

    text_entries = all_benchmarks["message_text_content"]
    for text in text_entries:
        assert text["validated"] is True, text
        assert text["baseline_avg_ms"] is not None, text
        assert text["current_avg_ms"] >= 0, text

    for name in [
        "context_manager_make_session",
        "request_pipeline_noninference",
        "request_decode",
        "tool_call_detect",
        "response_encode",
    ]:
        for entry in all_benchmarks[name]:
            assert entry["current_avg_ms"] >= 0
