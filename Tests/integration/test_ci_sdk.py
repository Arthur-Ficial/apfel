"""CI toolchain guards (#520).

Since v1.15.0 the sources use macOS 27-only FoundationModels API behind
runtime `#available` gates, so they only compile against the macOS 27 SDK.
The `macos-26` runner image ships Xcode 26 (SDK 26), which made every CI run
on main red from 2026-10-05 on. Build jobs therefore run on a runner that
carries the macOS 27 SDK.

apfel still promises one binary for macOS 26 AND 27. A 27-only symbol that is
linked strongly instead of weakly would crash the binary at launch on macOS 26
while every test on the 27 runner stays green. A separate job therefore takes
the binary built on the 27 SDK and launches it on a real macOS 26 runner.

Pure source scans of the workflow, so they run model-free on CI.
"""
import pathlib
import re

CI = pathlib.Path(__file__).parents[2] / ".github" / "workflows" / "ci.yml"


def _jobs() -> dict[str, str]:
    """Split ci.yml into {job_name: job_text} without a YAML dependency."""
    text = CI.read_text()
    body = text.split("\njobs:\n", 1)[1]
    jobs: dict[str, str] = {}
    current = None
    for line in body.splitlines():
        m = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if m:
            current = m.group(1)
            jobs[current] = ""
        elif current:
            jobs[current] += line + "\n"
    return jobs


def _runs_on(job_text: str) -> str:
    m = re.search(r"^    runs-on:\s*(\S+)", job_text, re.MULTILINE)
    return m.group(1) if m else ""


def test_swift_build_jobs_run_on_a_macos_27_sdk_runner():
    offenders = [
        f"{name} (runs-on: {_runs_on(text)})"
        for name, text in _jobs().items()
        if re.search(r"\b(swift build|make build|swift run)\b", text)
        and not _runs_on(text).startswith("xcode-27")
    ]
    assert offenders == [], (
        "These CI jobs compile apfel on a runner without the macOS 27 SDK: "
        f"{offenders}. Use `runs-on: xcode-27` (#520)."
    )


def test_binary_built_on_sdk_27_is_launched_on_macos_26():
    jobs = _jobs()
    launch = [
        name for name, text in jobs.items()
        if _runs_on(text) == "macos-26"
        and "actions/download-artifact" in text
        and "--version" in text
        and "minos" in text
    ]
    assert launch, (
        "No CI job launches the SDK-27-built binary on a macos-26 runner and "
        "checks its deployment floor (minos 26.0). One binary must keep working "
        "on macOS 26 (#205, #520)."
    )
    uploads = [n for n, t in jobs.items() if "actions/upload-artifact" in t]
    assert uploads, "The build job must upload the release binary as an artifact."
