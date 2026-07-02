import json
import pathlib
import statistics
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"

# Benchmarks with a large, reliably measurable algorithmic win (binary-search
# trims, schema-convert caching, capture short-circuits). A single wall-clock
# run can still dip below 1.0 under scheduler noise on a loaded release machine
# (#264: this class of flake aborted `make release` mid-flight). We assert the
# MEDIAN speedup across repeated runs instead, which is robust to occasional
# noisy runs while still proving the algorithmic win is real.
_SPEEDUP_BENCHMARKS = [
    "trim_newest_first",
    "trim_oldest_first",
    "tool_schema_convert",
    "request_body_capture_disabled",
    "stream_debug_capture_disabled",
]
# Odd count so the median is a single observed run, never an average of two.
_SPEEDUP_RUNS = 5


def _run_benchmarks():
    result = subprocess.run(
        [str(BINARY), "--benchmark", "-o", "json"],
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    return {entry["name"]: entry for entry in payload["benchmarks"]}


def test_benchmark_reports_real_speedups():
    # Collect speedup ratios across several runs; also keep the correctness
    # assertions (validated output, real baseline) on every run.
    ratios = {name: [] for name in _SPEEDUP_BENCHMARKS}
    benchmarks = None
    for _ in range(_SPEEDUP_RUNS):
        benchmarks = _run_benchmarks()
        for name in _SPEEDUP_BENCHMARKS:
            entry = benchmarks[name]
            assert entry["validated"] is True, entry
            assert entry["baseline_avg_ms"] is not None, entry
            assert entry["speedup_ratio"] is not None, entry
            ratios[name].append(entry["speedup_ratio"])

    # De-flaked gate: the MEDIAN of repeated wall-clock runs must show the win.
    # A lone noisy run below 1.0 no longer aborts a release.
    for name in _SPEEDUP_BENCHMARKS:
        median = statistics.median(ratios[name])
        assert median > 1.0, (name, median, ratios[name])

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


def test_benchmark_environment_token_counter_reflects_tokenizer():
    """token_counter_available must reflect tokenizer API availability, not
    model generation availability (#328, #325). On macOS < 26.4 with Apple
    Intelligence enabled, the model can generate but the tokenizer API does
    not exist - the field must be false in that case."""
    result = subprocess.run(
        [str(BINARY), "--benchmark", "-o", "json"],
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    env = payload["environment"]
    assert isinstance(env["token_counter_available"], bool)
    assert env["context_window"] > 0
