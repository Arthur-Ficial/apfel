"""
apfel Integration Tests — CLI E2E

Exercises the release binary as a real UNIX tool:
- help/version/exit codes
- ANSI vs NO_COLOR under a TTY
- direct prompt, piped stdin, streaming, and quiet JSON output

Run via Tests/integration/run_tests.sh after the release binary has been built.
"""

import functools
import json
import os
import pathlib
import pty
import re
import select
import subprocess
import time

import pytest


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def run_cli(args, input_text=None, env=None, timeout=60):
    merged_env = os.environ.copy()
    for key in [
        "NO_COLOR",
        "APFEL_SYSTEM_PROMPT",
        "APFEL_HOST",
        "APFEL_PORT",
        "APFEL_TEMPERATURE",
        "APFEL_MAX_TOKENS",
    ]:
        merged_env.pop(key, None)
    if env:
        merged_env.update(env)
    return subprocess.run(
        [str(BINARY), *args],
        input=input_text,
        text=True,
        capture_output=True,
        env=merged_env,
        timeout=timeout,
    )


def run_cli_tty(args, env=None, timeout=30):
    merged_env = os.environ.copy()
    for key in [
        "NO_COLOR",
        "APFEL_SYSTEM_PROMPT",
        "APFEL_HOST",
        "APFEL_PORT",
        "APFEL_TEMPERATURE",
        "APFEL_MAX_TOKENS",
    ]:
        merged_env.pop(key, None)
    if env:
        merged_env.update(env)

    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        [str(BINARY), *args],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        env=merged_env,
        close_fds=True,
    )
    os.close(slave_fd)

    output = bytearray()
    deadline = time.time() + timeout
    try:
        while True:
            if time.time() > deadline:
                proc.kill()
                raise TimeoutError(f"Timed out waiting for {' '.join(args)}")

            ready, _, _ = select.select([master_fd], [], [], 0.1)
            if master_fd in ready:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)

            if proc.poll() is not None and master_fd not in ready:
                break
    finally:
        os.close(master_fd)

    proc.wait(timeout=max(1, int(deadline - time.time())))
    return proc.returncode, output.decode("utf-8", errors="replace")


@functools.lru_cache(maxsize=1)
def model_available():
    result = run_cli(["--model-info"], timeout=20)
    return result.returncode == 0 and "available:  yes" in result.stdout.lower()


def require_model():
    if not model_available():
        pytest.skip("Apple Intelligence is not enabled for CLI generation tests.")


def test_release_binary_exists():
    assert BINARY.exists(), f"Expected release binary at {BINARY}"


def test_help_exit_success():
    result = run_cli(["--help"])
    assert result.returncode == 0
    assert "USAGE:" in result.stdout


def test_version_exit_success():
    result = run_cli(["--version"])
    assert result.returncode == 0
    assert result.stdout.startswith("apfel v")


def test_invalid_flag_exit_code():
    result = run_cli(["--definitely-not-a-real-flag"])
    assert result.returncode == 2
    assert "unknown option" in result.stderr


def test_help_uses_ansi_under_tty():
    returncode, output = run_cli_tty(["--help"])
    assert returncode == 0
    assert ANSI_RE.search(output), output


def test_no_color_disables_ansi_under_tty():
    returncode, output = run_cli_tty(["--help"], env={"NO_COLOR": "1"})
    assert returncode == 0
    assert not ANSI_RE.search(output), output


def test_quiet_json_prompt_output_is_machine_readable():
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "What is 2+2? Reply with just the number."],
        timeout=90,
    )
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert payload["model"] == "apple-foundationmodel"
    assert payload["content"].strip()
    assert result.stderr == ""


def test_piped_stdin_json_output_is_machine_readable():
    require_model()
    result = run_cli(
        ["-q", "-o", "json"],
        input_text="What is 2+2? Reply with just the number.",
        timeout=90,
    )
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert payload["model"] == "apple-foundationmodel"
    assert payload["content"].strip()
    assert result.stderr == ""


def test_json_output_no_trailing_newline():
    """Regression: --json piped output must not end with a newline (GH-9)."""
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "What is 2+2? Reply with just the number."],
        timeout=90,
    )
    assert result.returncode == 0
    assert not result.stdout.endswith("\n"), (
        f"JSON stdout ends with trailing newline: {result.stdout!r}"
    )
    # Ensure the output is still valid JSON
    json.loads(result.stdout)


def test_stream_returns_content():
    require_model()
    result = run_cli(["--stream", "Reply with the single word OK."], timeout=90)
    assert result.returncode == 0
    assert result.stdout.strip()
