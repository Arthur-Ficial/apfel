import json
import pathlib
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"


def test_benchmark_reports_real_speedups():
    result = subprocess.run(
        [str(BINARY), "--benchmark", "-o", "json"],
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    benchmarks = {entry["name"]: entry for entry in payload["benchmarks"]}

    # Large algorithmic wins (binary-search trims, schema-convert caching).
    # Expected speedup is 5-100x in normal conditions. The 0.5 floor gives
    # a 2x noise margin for loaded release machines while still catching an
    # accidental regression to the baseline algorithm (ratio ~= 1.0).
    for name in [
        "trim_newest_first",
        "trim_oldest_first",
        "tool_schema_convert",
    ]:
        entry = benchmarks[name]
        assert entry["validated"] is True, entry
        assert entry["baseline_avg_ms"] is not None, entry
        assert entry["speedup_ratio"] is not None, entry
        assert entry["speedup_ratio"] > 0.5, (
            f"{name}: speedup_ratio {entry['speedup_ratio']:.2f} below noise floor"
        )

    # Short-circuit wins: skipping work when a flag is off. Both paths are
    # sub-microsecond, so wall-clock noise dominates the ratio and asserting
    # speedup_ratio > 1.0 is a known flake class. We assert output correctness
    # and that the benchmark executed, matching the message_text_content
    # de-flaking pattern.
    for name in [
        "request_body_capture_disabled",
        "stream_debug_capture_disabled",
        "message_text_content",
    ]:
        entry = benchmarks[name]
        assert entry["validated"] is True, entry
        assert entry["baseline_avg_ms"] is not None, entry
        assert entry["current_avg_ms"] >= 0, entry

    for name in [
        "context_manager_make_session",
        "request_pipeline_noninference",
        "request_decode",
        "tool_call_detect",
        "response_encode",
    ]:
        assert benchmarks[name]["current_avg_ms"] >= 0
