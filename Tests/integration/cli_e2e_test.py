"""
apfel Integration Tests — CLI E2E

Exercises the release binary as a real UNIX tool:
- help/version/exit codes
- ANSI vs NO_COLOR under a TTY
- direct prompt, piped stdin, streaming, and quiet JSON output

Run via `make test` (or `python3 -m pytest Tests/integration/`) after the
release binary has been built.
"""

import functools
import json
import os
import pathlib
import pty
import re
import select
import signal
import subprocess
import time
import warnings

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


def run_cli_chat_json(args, steps, env=None, timeout=60, stop_when=None):
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

    stdout_read_fd, stdout_write_fd = os.pipe()
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="This process .* use of forkpty\\(\\) may lead to deadlocks in the child\\.",
            category=DeprecationWarning,
        )
        pid, master_fd = pty.fork()
    if pid == 0:
        os.close(stdout_read_fd)
        os.dup2(stdout_write_fd, 1)
        if stdout_write_fd != 1:
            os.close(stdout_write_fd)
        os.execve(str(BINARY), [str(BINARY), *args], merged_env)

    os.close(stdout_write_fd)
    stdout_output = bytearray()
    tty_output = bytearray()
    deadline = time.time() + timeout
    pending_steps = list(steps)
    exit_status = None

    try:
        while True:
            if time.time() > deadline:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                raise TimeoutError(f"Timed out waiting for {' '.join(args)}")

            if pending_steps:
                step = pending_steps[0]
                if len(step) == 2:
                    wait_for, data = step
                    delay = 0
                else:
                    wait_for, data, delay = step
                haystacks = (stdout_output, tty_output)
                if wait_for is None or any(wait_for in output for output in haystacks):
                    if delay:
                        time.sleep(delay)
                    os.write(master_fd, data)
                    pending_steps.pop(0)
                    continue

            ready, _, _ = select.select([master_fd, stdout_read_fd], [], [], 0.1)
            for fd in ready:
                try:
                    chunk = os.read(fd, 4096)
                except OSError:
                    chunk = b""
                if not chunk:
                    continue
                if fd == master_fd:
                    tty_output.extend(chunk)
                else:
                    stdout_output.extend(chunk)

            if stop_when is not None and stop_when(stdout_output, tty_output):
                os.kill(pid, signal.SIGKILL)
                _, exit_status = os.waitpid(pid, 0)
                break

            waited_pid, status = os.waitpid(pid, os.WNOHANG)
            if waited_pid == pid and not ready:
                exit_status = status
                break
    finally:
        os.close(master_fd)
        os.close(stdout_read_fd)

    if exit_status is None:
        _, exit_status = os.waitpid(pid, 0)

    return (
        os.waitstatus_to_exitcode(exit_status),
        stdout_output.decode("utf-8", errors="replace"),
        tty_output.decode("utf-8", errors="replace"),
    )


def run_cli_chat_tty(args, steps, env=None, timeout=60, stop_when=None):
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

    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="This process .* use of forkpty\\(\\) may lead to deadlocks in the child\\.",
            category=DeprecationWarning,
        )
        pid, master_fd = pty.fork()
    if pid == 0:
        os.execve(str(BINARY), [str(BINARY), *args], merged_env)

    output = bytearray()
    deadline = time.time() + timeout
    pending_steps = list(steps)
    exit_status = None

    try:
        while True:
            if time.time() > deadline:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                raise TimeoutError(f"Timed out waiting for {' '.join(args)}")

            if pending_steps:
                step = pending_steps[0]
                if len(step) == 2:
                    wait_for, data = step
                    delay = 0
                else:
                    wait_for, data, delay = step
                if wait_for is None or wait_for in output:
                    if delay:
                        time.sleep(delay)
                    os.write(master_fd, data)
                    pending_steps.pop(0)
                    continue

            ready, _, _ = select.select([master_fd], [], [], 0.1)
            if master_fd in ready:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    chunk = b""
                if chunk:
                    output.extend(chunk)

            if stop_when is not None and stop_when(output):
                os.kill(pid, signal.SIGKILL)
                _, exit_status = os.waitpid(pid, 0)
                break

            waited_pid, status = os.waitpid(pid, os.WNOHANG)
            if waited_pid == pid and master_fd not in ready:
                exit_status = status
                break
    finally:
        os.close(master_fd)

    if exit_status is None:
        _, exit_status = os.waitpid(pid, 0)

    return os.waitstatus_to_exitcode(exit_status), output.decode("utf-8", errors="replace")


def parse_json_lines(text):
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def parse_json_lines_from_output(text):
    return [json.loads(line) for line in text.splitlines() if line.lstrip().startswith("{")]


@functools.lru_cache(maxsize=1)
def model_available():
    result = run_cli(["--model-info"], timeout=20)
    return result.returncode == 0 and "available:  yes" in result.stdout.lower()


def require_model():
    if model_available():
        return
    # Marker discipline (#266): on a deliberately model-free run (CI sets
    # APFEL_MODELFREE_ONLY=1 and selects `-m "not model"`), a model test should
    # never reach this point - if it does, its @pytest.mark.model decorator is
    # missing and it leaked past the filter. Fail loudly instead of skipping so
    # the forgotten marker turns CI red rather than passing green-by-skip.
    if os.environ.get("APFEL_MODELFREE_ONLY"):
        pytest.fail(
            "model test ran in a model-free selection (-m 'not model'); it is "
            "missing @pytest.mark.model"
        )
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


def test_count_tokens_in_help():
    result = run_cli(["--help"])
    assert result.returncode == 0
    assert "--count-tokens" in result.stdout
    assert "--strict" in result.stdout


# --- Shell completions (#259) ------------------------------------------------

def test_completions_zsh_exit_and_content():
    """`apfel completions zsh` exits 0 and prints a zsh completion script."""
    result = run_cli(["completions", "zsh"], timeout=15)
    assert result.returncode == 0, f"stderr: {result.stderr}"
    assert result.stdout.startswith("#compdef apfel"), result.stdout[:80]
    assert "--context-strategy" in result.stdout
    assert "newest-first" in result.stdout


def test_completions_bash_and_fish_content():
    bash = run_cli(["completions", "bash"], timeout=15)
    assert bash.returncode == 0
    assert "complete -F _apfel apfel" in bash.stdout
    fish = run_cli(["completions", "fish"], timeout=15)
    assert fish.returncode == 0
    assert "complete -c apfel" in fish.stdout


def test_completions_missing_shell_is_usage_error():
    result = run_cli(["completions"], timeout=15)
    assert result.returncode == 2
    assert "shell" in result.stderr.lower()


def test_completions_bad_shell_is_usage_error():
    result = run_cli(["completions", "powershell"], timeout=15)
    assert result.returncode == 2


def test_completions_in_help():
    result = run_cli(["--help"])
    assert result.returncode == 0
    assert "completions" in result.stdout


def test_committed_completion_files_match_binary():
    """The checked-in completions/apfel.{bash,zsh,fish} must match the binary.

    Packagers install the committed files; if the generator changes, they must
    be regenerated (`apfel completions <shell> > completions/apfel.<shell>`).
    """
    for shell in ("bash", "zsh", "fish"):
        committed = (ROOT / "completions" / f"apfel.{shell}").read_text()
        generated = run_cli(["completions", shell], timeout=15).stdout
        assert committed == generated, (
            f"completions/apfel.{shell} is stale; regenerate it from the binary"
        )


def test_count_tokens_json_shape():
    """--count-tokens -o json returns the documented breakdown (model-free)."""
    result = run_cli(["--count-tokens", "-o", "json", "hello"], timeout=30)
    assert result.returncode == 0, f"stderr: {result.stderr}"
    import json
    data = json.loads(result.stdout.strip())
    for key in (
        "prompt_tokens", "system_tokens", "file_tokens", "mcp_tool_tokens",
        "total", "budget", "output_reserve", "fits", "approximate", "context_size",
    ):
        assert key in data, f"missing key {key!r} in {data}"
    assert isinstance(data["file_tokens"], list)
    assert isinstance(data["fits"], bool)


def test_count_tokens_fallback_warning_names_real_reason():
    """#315: when --count-tokens falls back to chars/4, the stderr warning
    must name the actual cause. On macOS < 26.4 the tokenizer API does not
    exist at runtime, so the warning must say so - not falsely claim
    "Apple Intelligence unavailable" while generation works fine.
    Model-free: asserts against the host OS version, not model output."""
    import platform
    result = run_cli(["--count-tokens", "-o", "json", "hello"], timeout=30)
    assert result.returncode == 0, f"stderr: {result.stderr}"
    data = json.loads(result.stdout.strip())
    mac_ver = tuple(int(x) for x in platform.mac_ver()[0].split(".")[:2])
    if mac_ver < (26, 4):
        assert data["approximate"] is True
        assert "token count is approximate" in result.stderr
        assert "macOS 26.4" in result.stderr, (
            f"warning must name the OS requirement (#315): {result.stderr!r}"
        )
        assert "Apple Intelligence unavailable" not in result.stderr, (
            f"warning must not blame Apple Intelligence for a missing OS API "
            f"(#315): {result.stderr!r}"
        )
    elif "token count is approximate" in result.stderr:
        # OS supports the API: the only truthful fallback reason left is
        # genuine model unavailability.
        assert data["approximate"] is True
        assert "Apple Intelligence unavailable" in result.stderr, (
            f"unexpected fallback reason on macOS >= 26.4: {result.stderr!r}"
        )
    else:
        assert data["approximate"] is False


def test_count_tokens_strict_exit_over_budget():
    """--strict exits 4 when input exceeds the token budget.
    50 000 x's ≈ 6 200 real tokens (measured: 20 000 x's → 2 508 tokens),
    safely above the 3 584-token budget regardless of tokenizer path.
    """
    huge = "x" * 50000
    result = run_cli(["--count-tokens", "--strict", huge], timeout=30)
    assert result.returncode == 4, f"expected exit 4, got {result.returncode}: {result.stderr}"


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


def test_empty_no_color_still_colors_under_tty():
    """#258: NO_COLOR="" (empty) must NOT disable color."""
    returncode, output = run_cli_tty(["--help"], env={"NO_COLOR": ""})
    assert returncode == 0
    assert ANSI_RE.search(output), output


def _run_split_tty(args, env=None, timeout=30):
    """Run the binary with stdout on a pty (a TTY) but stderr on a plain pipe.

    Reproduces the `apfel ... 2>err.log` case from a terminal: stdout is a
    terminal, stderr is redirected. Returns (returncode, stderr_bytes).
    """
    merged_env = os.environ.copy()
    for key in ["NO_COLOR", "APFEL_SYSTEM_PROMPT", "APFEL_HOST",
                "APFEL_PORT", "APFEL_TEMPERATURE", "APFEL_MAX_TOKENS"]:
        merged_env.pop(key, None)
    if env:
        merged_env.update(env)

    stdout_master, stdout_slave = pty.openpty()
    err_read, err_write = os.pipe()
    proc = subprocess.Popen(
        [str(BINARY), *args],
        stdin=stdout_slave, stdout=stdout_slave, stderr=err_write,
        env=merged_env, close_fds=True,
    )
    os.close(stdout_slave)
    os.close(err_write)
    err = bytearray()
    deadline = time.time() + timeout
    while True:
        if time.time() > deadline:
            proc.kill()
            raise TimeoutError(f"Timed out waiting for {' '.join(args)}")
        try:
            chunk = os.read(err_read, 4096)
        except OSError:
            break
        if not chunk:
            break
        err.extend(chunk)
    os.close(err_read)
    os.close(stdout_master)
    proc.wait(timeout=max(1, int(deadline - time.time())))
    return proc.returncode, bytes(err)


def test_redirected_stderr_has_no_ansi_when_stdout_is_tty():
    """#249: color must key off stderr's TTY-ness, not stdout's.

    With stdout on a terminal and stderr redirected, the error line must
    contain no ANSI escape bytes.
    """
    returncode, err = _run_split_tty(["--definitely-not-a-real-flag"])
    assert returncode == 2
    assert b"\x1b" not in err, err


def test_empty_stdin_usage_error_keeps_stdout_empty():
    """#250: usage-error exit (2) must not write usage to stdout."""
    result = run_cli([], input_text="")
    assert result.returncode == 2
    assert result.stdout == "", f"stdout should be empty on usage error, got: {result.stdout!r}"


def _run_no_args_tty_stdin(timeout=15):
    """No args with stdin on a pty (interactive TTY), stdout/stderr on pipes.

    Reproduces launching `apfel` with nothing to do at a terminal. Returns
    (returncode, stdout_bytes, stderr_bytes).
    """
    merged_env = os.environ.copy()
    for key in ["NO_COLOR", "APFEL_SYSTEM_PROMPT", "APFEL_HOST",
                "APFEL_PORT", "APFEL_TEMPERATURE", "APFEL_MAX_TOKENS"]:
        merged_env.pop(key, None)
    stdin_master, stdin_slave = pty.openpty()
    out_r, out_w = os.pipe()
    err_r, err_w = os.pipe()
    proc = subprocess.Popen(
        [str(BINARY)],
        stdin=stdin_slave, stdout=out_w, stderr=err_w,
        env=merged_env, close_fds=True,
    )
    os.close(stdin_slave)
    os.close(out_w)
    os.close(err_w)
    out = b"".join(iter(lambda: os.read(out_r, 4096), b""))
    err = b"".join(iter(lambda: os.read(err_r, 4096), b""))
    os.close(out_r)
    os.close(err_r)
    os.close(stdin_master)
    proc.wait(timeout=timeout)
    return proc.returncode, out, err


def test_no_args_tty_usage_goes_to_stderr():
    """#250: no-args at a terminal prints usage to stderr, not stdout, exit 2."""
    returncode, out, err = _run_no_args_tty_stdin()
    assert returncode == 2
    assert out == b"", f"stdout should be empty, got {out[:80]!r}"
    assert b"USAGE:" in err, err[:120]


def test_help_usage_goes_to_stdout():
    """#250: --help keeps usage on stdout and exits 0."""
    result = run_cli(["--help"])
    assert result.returncode == 0
    assert "USAGE:" in result.stdout
    assert result.stderr == "", f"--help should not write to stderr, got: {result.stderr!r}"


@pytest.mark.model
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


@pytest.mark.model
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


@pytest.mark.model
def test_json_output_trailing_newline():
    """--json piped output ends with exactly one trailing newline (#259).

    Reverses the earlier GH-9 no-trailing-newline decision: a single final
    newline makes `read`-loop and `wc -l` consumption of JSON output work
    without an awkward last byte of `}`. Exactly one newline, never two.
    """
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "What is 2+2? Reply with just the number."],
        timeout=90,
    )
    assert result.returncode == 0
    assert result.stdout.endswith("}\n"), (
        f"JSON stdout should end with '}}\\n': {result.stdout!r}"
    )
    assert not result.stdout.endswith("}\n\n"), (
        f"JSON stdout has a double trailing newline: {result.stdout!r}"
    )
    # Ensure the output is still valid JSON
    json.loads(result.stdout)


def test_count_tokens_json_trailing_newline():
    """--count-tokens -o json output ends with a single trailing newline (#259).

    Model-free: --count-tokens never calls the model, so this runs everywhere.
    """
    result = run_cli(["--count-tokens", "-o", "json", "hello"], timeout=30)
    assert result.returncode == 0, f"stderr: {result.stderr}"
    assert result.stdout.endswith("}\n"), (
        f"count-tokens JSON should end with '}}\\n': {result.stdout!r}"
    )
    assert not result.stdout.endswith("}\n\n"), (
        f"count-tokens JSON has a double trailing newline: {result.stdout!r}"
    )
    json.loads(result.stdout)


@pytest.mark.model
def test_stream_returns_content():
    require_model()
    result = run_cli(["--stream", "Reply with the single word OK."], timeout=90)
    assert result.returncode == 0
    assert result.stdout.strip()


@pytest.mark.model
def test_chat_json_left_arrow_edits_input():
    require_model()
    returncode, output = run_cli_chat_tty(
        ["--chat", "-o", "json", "--max-tokens", "1"],
        steps=[
            (b"you\xe2\x80\xba ", b"helo\x1b[D\x1b[Dl\n", 0.2),
        ],
        stop_when=lambda output: output.count(b'"role":"user"') >= 1,
    )
    assert returncode != 0
    messages = parse_json_lines_from_output(output)
    user_messages = [message for message in messages if message["role"] == "user"]
    assert user_messages[0]["content"] == "hello"
    assert "^[[D" not in output
    assert "\x1b[D" not in output


@pytest.mark.model
def test_chat_json_up_arrow_replays_previous_prompt():
    require_model()
    first_prompt = "Reply ALPHA."
    returncode, output = run_cli_chat_tty(
        ["--chat", "-o", "json", "--max-tokens", "1"],
        steps=[
            (b"you\xe2\x80\xba ", f"{first_prompt}\n\x1b[A\n".encode("utf-8"), 0.2),
        ],
        stop_when=lambda output: output.count(b'"role":"user"') >= 2,
    )
    assert returncode != 0
    messages = parse_json_lines_from_output(output)
    user_messages = [message for message in messages if message["role"] == "user"]
    assert [message["content"] for message in user_messages[:2]] == [
        first_prompt,
        first_prompt,
    ]


@pytest.mark.model
def test_chat_json_keeps_prompt_chrome_off_stdout():
    require_model()
    returncode, stdout, tty = run_cli_chat_json(
        ["--chat", "-o", "json", "--max-tokens", "1"],
        steps=[
            (b"Type 'quit' to exit.", b"Hello\n", 0.2),
        ],
        stop_when=lambda stdout, _tty: stdout.count(b'"role":"user"') >= 1,
    )
    assert returncode != 0
    messages = parse_json_lines(stdout)
    assert [message["role"] for message in messages] == ["user"]
    assert messages[0]["content"] == "Hello"
    assert "Type 'quit' to exit." not in stdout
    assert "you› " not in stdout
    assert "Type 'quit' to exit." in tty


def _assert_system_prompt_honored(args):
    require_model()
    system_prompt = "You are a pirate. Reply in pirate speech and include matey or arrr."
    command = [
        system_prompt if arg == "__SYSTEM_PROMPT__" else arg
        for arg in args
    ]
    result = run_cli(["-q", "-o", "json", *command], timeout=90)
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    content = payload["content"].lower()
    assert "matey" in content or "arrr" in content or "arr" in content, payload["content"]


@pytest.mark.model
def test_system_prompt_controls_non_stream_prompt():
    _assert_system_prompt_honored(["-s", "__SYSTEM_PROMPT__", "What is recursion?"])


@pytest.mark.model
def test_system_prompt_is_honored_with_stream_after_short_flag():
    _assert_system_prompt_honored(["-s", "__SYSTEM_PROMPT__", "--stream", "What is recursion?"])


@pytest.mark.model
def test_system_prompt_is_honored_with_stream_before_short_flag():
    _assert_system_prompt_honored(["--stream", "-s", "__SYSTEM_PROMPT__", "What is recursion?"])


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
    assert "no such file" in result.stderr


def test_file_flag_image_gives_clear_error():
    """Attaching an image file should explain that vision is not supported."""
    tmp = pathlib.Path("/tmp/apfel_test_image.jpeg")
    tmp.write_bytes(b'\xff\xd8\xff\xe0\x00\x10JFIF')  # JPEG header
    result = run_cli(["-f", str(tmp), "describe this"])
    assert result.returncode == 2
    assert "text-only" in result.stderr or "image" in result.stderr, \
        f"Expected image-specific error, got: {result.stderr}"
    tmp.unlink()


def test_file_flag_binary_gives_clear_error():
    """Attaching a binary file should explain that only text is supported."""
    tmp = pathlib.Path("/tmp/apfel_test_binary.zip")
    tmp.write_bytes(b'PK\x03\x04' + bytes(range(128, 256)) * 4)  # ZIP header + invalid UTF-8
    result = run_cli(["-f", str(tmp), "read this"])
    assert result.returncode == 2
    assert "binary" in result.stderr or "text" in result.stderr, \
        f"Expected binary-specific error, got: {result.stderr}"
    tmp.unlink()


def test_file_flag_unknown_binary_gives_utf8_error():
    """Attaching an unknown binary file should mention UTF-8."""
    tmp = pathlib.Path("/tmp/apfel_test_unknown.dat2")
    tmp.write_bytes(b'\x80\x81\x82\x83\xff\xfe')  # invalid UTF-8
    result = run_cli(["-f", str(tmp), "read this"])
    assert result.returncode == 2
    assert "utf-8" in result.stderr.lower() or "binary" in result.stderr.lower() or "text" in result.stderr.lower(), \
        f"Expected UTF-8/binary error, got: {result.stderr}"
    tmp.unlink()


@pytest.mark.model
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


@pytest.mark.model
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


@pytest.mark.model
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


@pytest.mark.model
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


@pytest.mark.model
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


# --- Stdin + --stream tests (GH-82) ---


@pytest.mark.model
def test_stdin_with_stream_flag():
    """Piped stdin + --stream + prompt should combine (GH-82)."""
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "--stream",
         "What city is mentioned above? Reply with just the city name."],
        input_text="The capital of France is Paris.",
        timeout=90,
    )
    assert result.returncode == 0, f"stderr: {result.stderr}"
    payload = json.loads(result.stdout)
    assert "paris" in payload["content"].lower()


@pytest.mark.model
def test_stdin_only_with_stream_flag():
    """Piped stdin as sole prompt with --stream (GH-82)."""
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "--stream"],
        input_text="What is 2+2? Reply with just the number.",
        timeout=90,
    )
    assert result.returncode == 0, f"stderr: {result.stderr}"
    payload = json.loads(result.stdout)
    assert payload["content"].strip()


@pytest.mark.model
def test_file_flag_with_stdin_and_stream():
    """apfel -f <file> --stream <prompt> with piped stdin should include all three (GH-82)."""
    require_model()
    tmp = pathlib.Path("/tmp/apfel_test_file_stdin_stream.txt")
    tmp.write_text("File content: The answer is 42.")
    try:
        result = run_cli(
            ["-q", "-o", "json", "-f", str(tmp), "--stream",
             "What number is mentioned? Reply with just the number."],
            input_text="Stdin content: ignore this.",
            timeout=90,
        )
        assert result.returncode == 0, f"stderr: {result.stderr}"
        payload = json.loads(result.stdout)
        assert "42" in payload["content"]
    finally:
        tmp.unlink(missing_ok=True)


@pytest.mark.model
def test_stdin_stream_with_system_prompt():
    """Piped stdin + --stream + system prompt should all combine (GH-82)."""
    require_model()
    result = run_cli(
        ["-q", "-o", "json", "--stream",
         "-s", "You are a helpful assistant. Always reply in uppercase.",
         "What city is mentioned?"],
        input_text="The capital of France is Paris.",
        timeout=90,
    )
    assert result.returncode == 0, f"stderr: {result.stderr}"
    payload = json.loads(result.stdout)
    assert "paris" in payload["content"].lower() or "PARIS" in payload["content"]


# --- Self-update tests (--update) ---


def test_update_flag_exits_success():
    """--update should exit 0 regardless of install method."""
    result = run_cli(["--update"])
    assert result.returncode == 0


def test_update_shows_version():
    """--update output should contain the current version."""
    result = run_cli(["--update"])
    assert "apfel v" in result.stdout


def test_update_detects_install_method():
    """--update should identify either 'Homebrew' or 'from source'."""
    result = run_cli(["--update"])
    assert "Homebrew" in result.stdout or "from source" in result.stdout


def test_update_in_help():
    """--update should appear in the help text."""
    result = run_cli(["--help"])
    assert "--update" in result.stdout


def test_update_non_interactive():
    """--update with piped stdin should not hang waiting for input."""
    result = run_cli(["--update"], input_text="", timeout=30)
    assert result.returncode == 0


# --- Empty-pipe stderr hint tests (GH-152) ---


def test_empty_pipe_no_args_shows_stderr_hint():
    """When stdin is a pipe but empty and no args given, hint about stderr redirection (#152)."""
    result = run_cli([], input_text="", timeout=10)
    assert result.returncode == 2
    assert "piped input was empty" in result.stderr
    assert "2>&1" in result.stderr


def test_empty_pipe_with_prompt_shows_stderr_hint():
    """When stdin is a pipe but empty with a prompt, hint about stderr redirection (#152)."""
    result = run_cli(["What went wrong?"], input_text="", timeout=30)
    # Hint appears regardless of whether model is available.
    assert "piped input was empty" in result.stderr
    assert "2>&1" in result.stderr


def test_empty_pipe_quiet_suppresses_hint():
    """--quiet should suppress the empty-pipe hint (#152)."""
    result = run_cli(["-q", "What went wrong?"], input_text="", timeout=30)
    assert "piped input was empty" not in result.stderr


def test_empty_file_redirect_no_hint(tmp_path):
    """Empty regular-file redirect (`apfel "q" < empty.txt`) should NOT emit the
    pipe hint - the hint is only useful for `command 2>&1 | apfel` (#152)."""
    empty_file = tmp_path / "empty.txt"
    empty_file.write_text("")
    merged_env = os.environ.copy()
    for key in ["NO_COLOR", "APFEL_SYSTEM_PROMPT", "APFEL_HOST", "APFEL_PORT",
                "APFEL_TEMPERATURE", "APFEL_MAX_TOKENS"]:
        merged_env.pop(key, None)
    with open(empty_file, "rb") as fh:
        result = subprocess.run(
            [str(BINARY), "What went wrong?"],
            stdin=fh,
            capture_output=True,
            text=True,
            env=merged_env,
            timeout=30,
        )
    assert "piped input was empty" not in result.stderr


# --- Release info tests ---


def test_release_exits_success():
    """--release should exit 0."""
    result = run_cli(["--release"])
    assert result.returncode == 0


def test_release_shows_version_from_dotfile():
    """--release version must match the .version file (single source of truth)."""
    expected = (ROOT / ".version").read_text().strip()
    result = run_cli(["--release"])
    assert f"version:    {expected}" in result.stdout, \
        f"Expected version '{expected}' in output:\n{result.stdout}"


def test_release_shows_build_info_from_generated_file():
    """--release must display all fields from the auto-generated BuildInfo.swift."""
    build_info = (ROOT / "Sources" / "BuildInfo.swift").read_text()
    result = run_cli(["--release"])
    output = result.stdout

    # Extract values from BuildInfo.swift
    for field, label in [
        ("buildCommit", "commit:"),
        ("buildBranch", "branch:"),
        ("buildDate", "built:"),
        ("buildSwiftVersion", "swift:"),
        ("buildOS", "os:"),
    ]:
        # Parse: let buildFoo = "value"
        match = re.search(rf'let {field} = "(.+?)"', build_info)
        assert match, f"Missing {field} in BuildInfo.swift"
        value = match.group(1)
        assert value in output, \
            f"BuildInfo.swift has {field}={value!r} but --release output doesn't contain it"


def test_release_contains_no_hardcoded_token_count():
    """Context size must not be hardcoded - it changes with SDK versions."""
    result = run_cli(["--release"])
    assert "4096" not in result.stdout, \
        "--release should not hardcode token counts"


def test_release_mentions_mcp():
    """--release should mention MCP tool server support."""
    result = run_cli(["--release"])
    assert "mcp" in result.stdout.lower(), \
        "--release should mention MCP support"


def test_release_in_help():
    """--release should appear in the help text."""
    result = run_cli(["--help"])
    assert "--release" in result.stdout


def test_release_is_not_async():
    """--release must return instantly (no network, no model queries)."""
    import time
    start = time.time()
    result = run_cli(["--release"], timeout=5)
    elapsed = time.time() - start
    assert result.returncode == 0
    assert elapsed < 2, f"--release took {elapsed:.2f}s - should be instant"


# --- MCP CLI UNIX correctness tests ---

MCP_CALC = str(ROOT / "mcp" / "calculator" / "server.py")


@pytest.mark.model
def test_mcp_tool_info_goes_to_stderr():
    """MCP discovery and tool call info must go to stderr, not stdout."""
    require_model()
    # max_tokens defaults to "use the rest of the window" -- the small
    # on-device model can ramble before/after the tool call, so MCP test
    # timeouts are sized to the worst case rather than to a fixed cap.
    result = run_cli(["--mcp", MCP_CALC, "What is 2 + 2?"], timeout=120)
    assert result.returncode == 0
    assert "mcp:" not in result.stdout, \
        f"mcp: discovery line leaked to stdout: {result.stdout[:200]}"
    assert "tool:" not in result.stdout, \
        f"tool: call line leaked to stdout: {result.stdout[:200]}"
    assert "mcp:" in result.stderr, \
        "mcp: discovery line missing from stderr"


@pytest.mark.model
def test_mcp_stdout_only_has_answer():
    """When piping, stdout must contain only the model's answer."""
    require_model()
    result = run_cli(["--mcp", MCP_CALC, "Use the add tool to add 10 and 20. Reply with just the number."], timeout=120)
    assert result.returncode == 0
    stdout_stripped = result.stdout.strip()
    assert "mcp:" not in stdout_stripped
    assert "tool:" not in stdout_stripped
    assert len(stdout_stripped) > 0, "stdout should contain the answer"


@pytest.mark.model
def test_mcp_quiet_suppresses_tool_info():
    """--quiet must suppress both mcp: and tool: lines on stderr."""
    require_model()
    result = run_cli(["-q", "--mcp", MCP_CALC, "What is 3 times 3?"], timeout=120)
    assert result.returncode == 0
    assert "mcp:" not in result.stderr, \
        f"mcp: discovery line not suppressed by -q: {result.stderr[:200]}"
    assert "tool:" not in result.stderr, \
        f"tool: call line not suppressed by -q: {result.stderr[:200]}"


@pytest.mark.model
def test_mcp_json_output_is_clean():
    """JSON output must not contain MCP diagnostic lines."""
    require_model()
    result = run_cli(["-o", "json", "--mcp", MCP_CALC, "What is 5 plus 5?"], timeout=120)
    assert result.returncode == 0
    import json
    data = json.loads(result.stdout.strip())
    assert "content" in data
    assert "mcp:" not in data["content"]


# --- README CLI Reference completeness test ---


def test_readme_cli_reference_complete():
    """Every flag from --help must appear in BOTH the quick-reference block AND the examples block."""
    result = run_cli(["--help"])
    assert result.returncode == 0, f"--help failed: {result.stderr}"

    # Parse flags from OPTIONS, CONTEXT OPTIONS, and SERVER OPTIONS sections only.
    flag_sections = []
    in_flag_section = False
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped in ("OPTIONS:", "CONTEXT OPTIONS:", "SERVER OPTIONS:"):
            in_flag_section = True
            continue
        if stripped in ("ENVIRONMENT:", "EXIT CODES:", "EXAMPLES:", "USAGE:"):
            in_flag_section = False
            continue
        if in_flag_section:
            flag_sections.append(line)

    help_flags = set(re.findall(r"--[a-z][-a-z]+", "\n".join(flag_sections)))
    assert help_flags, "Failed to extract any flags from --help output"

    # Read CLI Reference from docs/cli-reference.md (moved from README.md)
    cli_ref_path = ROOT / "docs" / "cli-reference.md"
    assert cli_ref_path.exists(), "Could not find docs/cli-reference.md"
    cli_reference = cli_ref_path.read_text()

    # Split into the two code blocks: quick-reference (first) and examples (second)
    code_blocks = re.findall(r"```(?:text|bash)?\n(.*?)```", cli_reference, re.DOTALL)
    assert len(code_blocks) >= 2, (
        f"Expected at least 2 code blocks in CLI Reference (quick-ref + examples), found {len(code_blocks)}"
    )
    quick_ref = code_blocks[0]
    examples = code_blocks[1]

    # Every flag must appear in the quick-reference block
    missing_from_ref = sorted(flag for flag in help_flags if flag not in quick_ref)
    assert not missing_from_ref, (
        f"CLI Reference quick-reference block is missing {len(missing_from_ref)} flag(s):\n  "
        + "\n  ".join(missing_from_ref)
    )

    # Every flag must appear in the examples block
    missing_from_examples = sorted(flag for flag in help_flags if flag not in examples)
    assert not missing_from_examples, (
        f"CLI Reference examples block is missing {len(missing_from_examples)} flag(s):\n  "
        + "\n  ".join(missing_from_examples)
    )


@pytest.mark.model
def test_apfel_mcp_env_var():
    """APFEL_MCP env var should attach MCP servers (same as --mcp flag)."""
    require_model()
    mcp_path = str(ROOT / "mcp" / "calculator" / "server.py")
    result = run_cli(
        ["What is 3 + 4? Use the add tool."],
        env={"APFEL_MCP": mcp_path},
        timeout=90,
    )
    assert result.returncode == 0
    # stderr must show MCP tool discovery ("mcp: ... add, subtract, ...")
    assert "mcp:" in result.stderr.lower(), \
        f"APFEL_MCP env var not loading MCP server. stderr: {result.stderr[:300]}"


def test_homebrew_formula_has_service_block():
    """Homebrew formula must include a service do block for brew services."""
    formula_script = ROOT / "scripts" / "write-homebrew-formula.sh"
    content = formula_script.read_text()
    assert "service do" in content, "Formula missing 'service do' block"
    assert "keep_alive" in content, "Formula service block missing keep_alive"
    assert "log_path" in content, "Formula service block missing log_path"


def test_mcp_timeout_flag_in_help():
    """--mcp-timeout must appear in help output."""
    result = run_cli(["--help"])
    assert "--mcp-timeout" in result.stdout, \
        f"--mcp-timeout not in help: {result.stdout[:500]}"


def test_mcp_timeout_env_var_in_help():
    """APFEL_MCP_TIMEOUT must appear in help output."""
    result = run_cli(["--help"])
    assert "APFEL_MCP_TIMEOUT" in result.stdout, \
        f"APFEL_MCP_TIMEOUT not in help: {result.stdout[:500]}"


@pytest.mark.model  # needs an available model: the availability gate
# (exit 5, #222) fires before MCP init on ineligible hardware, so the
# MCP timeout path is unreachable on GitHub runners.
def test_mcp_timeout_short_causes_fast_failure():
    """--mcp-timeout 1 with a slow MCP server should fail within ~2 seconds."""
    require_model()
    slow_server = str(ROOT / "Tests" / "integration" / "fixtures" / "slow_startup_mcp_server.py")
    start = time.time()
    result = run_cli(
        ["--mcp-timeout", "1", "--mcp", slow_server, "hello"],
        timeout=10,
    )
    elapsed = time.time() - start
    assert result.returncode != 0, "Should have failed with timeout"
    assert "timed out" in result.stderr.lower(), \
        f"Expected timeout error, got: {result.stderr}"
    assert elapsed < 5, f"Timeout took {elapsed:.1f}s, expected <5s with --mcp-timeout 1"


@pytest.mark.model  # needs an available model: the availability gate
# (exit 5, #222) fires before MCP init on ineligible hardware, so the
# MCP timeout path is unreachable on GitHub runners.
def test_mcp_timeout_env_var_works():
    """APFEL_MCP_TIMEOUT=1 should timeout same as --mcp-timeout 1."""
    require_model()
    slow_server = str(ROOT / "Tests" / "integration" / "fixtures" / "slow_startup_mcp_server.py")
    start = time.time()
    result = run_cli(
        ["--mcp", slow_server, "hello"],
        env={"APFEL_MCP_TIMEOUT": "1"},
        timeout=10,
    )
    elapsed = time.time() - start
    assert result.returncode != 0
    assert "timed out" in result.stderr.lower()
    assert elapsed < 5, f"Env var timeout took {elapsed:.1f}s, expected <5s"


@pytest.mark.model
def test_mcp_timeout_default_unchanged():
    """Default MCP timeout (5s) should still work for normal fast servers."""
    require_model()
    mcp_path = str(ROOT / "mcp" / "calculator" / "server.py")
    result = run_cli(["--mcp", mcp_path, "What is 1+1?"], timeout=120)
    assert result.returncode == 0, f"Normal MCP should work with default timeout: {result.stderr}"


def test_mcp_child_reaped_on_exit_path():
    """MCP children are reaped on exit paths, not orphaned (#246).

    apfel with --mcp and empty stdin initializes the MCP server, then exits 2
    ("no prompt provided"). The eof-ignoring fixture never observes stdin EOF,
    so before the fix - which fired shutdown as a `defer { Task { ... } }` the
    exiting process never scheduled - the child was orphaned. The fix awaits MCP
    shutdown on every exit path (terminate + bounded waitUntilExit), so the child
    is reaped. Model-free: the exit-2 guard runs before any model call.
    """
    fixture = ROOT / "Tests" / "integration" / "fixtures" / "eof_ignoring_mcp_server.py"
    subprocess.run(["pkill", "-f", "eof_ignoring_mcp_server"], capture_output=True)
    time.sleep(0.5)
    result = run_cli(["--mcp", str(fixture)], input_text="", timeout=30)
    assert result.returncode == 2, f"expected exit 2, got {result.returncode}: {result.stderr}"
    # Any orphaned child would still be alive; the reap must have removed it.
    time.sleep(1)
    check = subprocess.run(
        ["pgrep", "-f", "eof_ignoring_mcp_server"], capture_output=True, text=True
    )
    orphans = [line for line in check.stdout.strip().split("\n") if line]
    if orphans:
        subprocess.run(["pkill", "-f", "eof_ignoring_mcp_server"], capture_output=True)
    assert not orphans, f"MCP child orphaned after exit (#246): pids {orphans}"
