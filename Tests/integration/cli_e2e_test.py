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


def assert_system_prompt_honored(args):
    require_model()
    system_prompt = "You are a pirate. Reply in pirate speech and include matey or arrr."
    command = [
        system_prompt if arg == "__SYSTEM_PROMPT__" else arg
        for arg in args
    ]
    result = run_cli(
        ["-q", "-o", "json", *command],
        timeout=90,
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    content = payload["content"].lower()
    assert "matey" in content or "arrr" in content or "arr" in content, payload["content"]


def test_system_prompt_controls_non_stream_prompt():
    assert_system_prompt_honored(
        ["-s", "__SYSTEM_PROMPT__", "What is recursion?"],
    )


def test_system_prompt_is_honored_with_stream_after_short_flag():
    assert_system_prompt_honored(
        ["-s", "__SYSTEM_PROMPT__", "--stream", "What is recursion?"],
    )


def test_system_prompt_is_honored_with_stream_before_short_flag():
    assert_system_prompt_honored(
        ["--stream", "-s", "__SYSTEM_PROMPT__", "What is recursion?"],
    )


# --- File flag (-f/--file) tests (GH-12) ---


def test_help_shows_file_flag():
    result = run_cli(["--help"])
    assert result.returncode == 0
    assert "--file" in result.stdout
    assert "-f," in result.stdout


def test_file_flag_missing_path():
    result = run_cli(["-f"])
    assert result.returncode == 2
    assert "requires a file path" in result.stderr


def test_file_flag_nonexistent_file():
    result = run_cli(["-f", "/tmp/apfel_no_such_file_ever.txt", "summarize"])
    assert result.returncode == 2
    assert "Cannot read file" in result.stderr


def test_file_flag_with_prompt():
    """apfel -f <file> <prompt> should prepend file content to the prompt."""
    require_model()
    tmp = pathlib.Path("/tmp/apfel_test_file_flag.txt")
    tmp.write_text("The capital of Austria is Vienna.")
    try:
        result = run_cli(
            ["-q", "-o", "json", "-f", str(tmp), "What city is mentioned? Reply with just the city name."],
            timeout=90,
        )
        assert result.returncode == 0
        payload = json.loads(result.stdout)
        assert "vienna" in payload["content"].lower()
    finally:
        tmp.unlink(missing_ok=True)


def test_file_flag_no_prompt():
    """apfel -f <file> with no prompt argument should use file content as the prompt."""
    require_model()
    tmp = pathlib.Path("/tmp/apfel_test_file_noprompt.txt")
    tmp.write_text("What is 2+2? Reply with just the number.")
    try:
        result = run_cli(
            ["-q", "-o", "json", "-f", str(tmp)],
            timeout=90,
        )
        assert result.returncode == 0
        payload = json.loads(result.stdout)
        assert payload["content"].strip()
    finally:
        tmp.unlink(missing_ok=True)


def test_multiple_file_flags():
    """apfel -f a.txt -f b.txt <prompt> should include content from both files."""
    require_model()
    tmp_a = pathlib.Path("/tmp/apfel_test_multi_a.txt")
    tmp_b = pathlib.Path("/tmp/apfel_test_multi_b.txt")
    tmp_a.write_text("Fact A: The sky is blue.")
    tmp_b.write_text("Fact B: Grass is green.")
    try:
        result = run_cli(
            ["-q", "-o", "json", "-f", str(tmp_a), "-f", str(tmp_b),
             "List both facts. Reply with just the two facts, one per line."],
            timeout=90,
        )
        assert result.returncode == 0
        payload = json.loads(result.stdout)
        content = payload["content"].lower()
        assert "blue" in content
        assert "green" in content
    finally:
        tmp_a.unlink(missing_ok=True)
        tmp_b.unlink(missing_ok=True)


def test_stdin_with_prompt_argument():
    """Piped stdin + prompt argument should combine (stdin prepended to prompt)."""
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "What city is mentioned above? Reply with just the city name."],
        input_text="The capital of France is Paris.",
        timeout=90,
    )
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert "paris" in payload["content"].lower()


def test_file_flag_with_stdin_and_prompt():
    """apfel -f <file> <prompt> with piped stdin should include all three."""
    require_model()
    tmp = pathlib.Path("/tmp/apfel_test_file_stdin.txt")
    tmp.write_text("File content: The answer is 42.")
    try:
        result = run_cli(
            ["-q", "-o", "json", "-f", str(tmp),
             "What number is mentioned? Reply with just the number."],
            input_text="Stdin content: ignore this.",
            timeout=90,
        )
        assert result.returncode == 0
        payload = json.loads(result.stdout)
        assert "42" in payload["content"]
    finally:
        tmp.unlink(missing_ok=True)
