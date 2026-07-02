import json
import pathlib
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"

# Wall-clock speedup ratios are noisy under scheduler load. A tight > 1.0
# gate aborts `make release` mid-flight on a loaded machine even when the
# algorithmic win is real (see #264, same class as the message_text_content
# de-flake in v1.6.1). 0.5 catches genuine regressions (optimized path 2x
# slower than baseline) while tolerating scheduling jitter.
SPEEDUP_FLOOR = 0.5


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

    # Optimizations with a genuine algorithmic win (binary-search trims,
    # schema-convert caching, capture short-circuits). We assert correctness
    # via `validated` and a noise-tolerant speedup floor via SPEEDUP_FLOOR.
    for name in [
        "trim_newest_first",
        "trim_oldest_first",
        "tool_schema_convert",
        "request_body_capture_disabled",
        "stream_debug_capture_disabled",
    ]:
        entry = benchmarks[name]
        assert entry["validated"] is True, entry
        assert entry["baseline_avg_ms"] is not None, entry
        assert entry["speedup_ratio"] is not None, entry
        assert entry["speedup_ratio"] > SPEEDUP_FLOOR, (
            f"{name}: speedup_ratio {entry['speedup_ratio']:.2f} below "
            f"floor {SPEEDUP_FLOOR} (baseline {entry['baseline_avg_ms']:.3f} ms, "
            f"current {entry['current_avg_ms']:.3f} ms)"
        )

    # message_text_content is a single-pass correctness/clarity refactor: it
    # drops one extra pass over `parts` (the image scan), but both paths still
    # build and join the same intermediate string array, so that shared cost
    # dominates and the speedup ratio sits at ~1.0 -- below reliable wall-clock
    # resolution and noisy run-to-run. We assert output correctness and that the
    # benchmark executed, but not a speedup ratio it cannot stably deliver.
    text = benchmarks["message_text_content"]
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
        assert benchmarks[name]["current_avg_ms"] >= 0
