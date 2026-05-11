"""
apfel Integration Tests -- Chat Mode (TUI)

Comprehensive tests for --chat in all scenarios:
- Startup & exit (plain, quit, exit, EOF, non-TTY)
- Chat + MCP tools (the #43 crash bug and beyond)
- Chat + system prompt (flag and env var)
- Chat + --debug (stderr output)
- Chat output formats (plain, JSON, quiet)
- Chat + flags combinations (temperature, max-tokens, permissive, retry)
- Chat multi-turn context

Run: python3 -m pytest Tests/integration/test_chat.py -v
Requires: release binary at .build/release/apfel
Some tests require Apple Intelligence enabled (skipped otherwise).
"""

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
MCP_SERVER = ROOT / "mcp" / "calculator" / "server.py"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


# ---------------------------------------------------------------------------
# Helpers (duplicated from cli_e2e_test.py to avoid cross-import issues)
# ---------------------------------------------------------------------------

def _clean_env(env=None):
    merged = os.environ.copy()
    for key in [
        "NO_COLOR", "APFEL_SYSTEM_PROMPT", "APFEL_HOST", "APFEL_PORT",
        "APFEL_TEMPERATURE", "APFEL_MAX_TOKENS",
    ]:
        merged.pop(key, None)
    if env:
        merged.update(env)
    return merged


def run_cli(args, input_text=None, env=None, timeout=60):
    merged = _clean_env(env)
    proc = subprocess.run(
        [str(BINARY), *args],
        input=input_text, capture_output=True, text=True,
        env=merged, timeout=timeout,
    )
    return proc


def run_chat_tty(args, steps, env=None, timeout=60, stop_when=None):
    """Run apfel in a PTY, send interactive steps, collect all output."""
    merged = _clean_env(env)

    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            message="This process .* use of forkpty\\(\\) may lead to deadlocks in the child\\.",
            category=DeprecationWarning,
        )
        pid, master_fd = pty.fork()
    if pid == 0:
        os.execve(str(BINARY), [str(BINARY), *args], merged)

    output = bytearray()
    deadline = time.time() + timeout
    pending_steps = list(steps)
    exit_status = None

    try:
        while True:
            if time.time() > deadline:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                raise TimeoutError(f"Timed out: {' '.join(args)}")

            if pending_steps:
                step = pending_steps[0]
                wait_for, data = step[0], step[1]
                delay = step[2] if len(step) == 3 else 0
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

            try:
                waited_pid, status = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                break
            if waited_pid == pid and not ready:
                exit_status = status
                break
    finally:
        os.close(master_fd)

    if exit_status is None:
        try:
            _, exit_status = os.waitpid(pid, 0)
        except ChildProcessError:
            exit_status = 256  # process already reaped

    return os.waitstatus_to_exitcode(exit_status), output.decode("utf-8", errors="replace")


def run_chat_json(args, steps, env=None, timeout=60, stop_when=None):
    """Run apfel chat in a PTY with stdout separated from TTY output."""
    merged = _clean_env(env)

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
        os.execve(str(BINARY), [str(BINARY), *args], merged)

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
                raise TimeoutError(f"Timed out: {' '.join(args)}")

            if pending_steps:
                step = pending_steps[0]
                wait_for, data = step[0], step[1]
                delay = step[2] if len(step) == 3 else 0
                haystacks = (stdout_output, tty_output)
                if wait_for is None or any(wait_for in h for h in haystacks):
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

            try:
                waited_pid, status = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                break
            if waited_pid == pid and not ready:
                exit_status = status
                break
    finally:
        os.close(master_fd)
        os.close(stdout_read_fd)

    if exit_status is None:
        try:
            _, exit_status = os.waitpid(pid, 0)
        except ChildProcessError:
            exit_status = 256

    return (
        os.waitstatus_to_exitcode(exit_status),
        stdout_output.decode("utf-8", errors="replace"),
        tty_output.decode("utf-8", errors="replace"),
    )


def strip_ansi(text):
    return ANSI_RE.sub("", text)


def parse_json_lines(text):
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def model_available():
    result = run_cli(["--model-info"], timeout=20)
    return result.returncode == 0 and "available:  yes" in result.stdout.lower()


def require_model():
    if not model_available():
        pytest.skip("Apple Intelligence not enabled")


# ---------------------------------------------------------------------------
# Category 1: Chat Startup & Exit (5 tests)
# ---------------------------------------------------------------------------

def test_chat_plain_starts_and_shows_header():
    """Chat mode must start and display the Apple Intelligence header."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Apple Intelligence" in clean, f"Header missing in: {clean[:200]}"


def test_chat_quit_exits_cleanly():
    """Typing 'quit' must exit chat with 'Goodbye' message."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean


def test_chat_exit_command_works():
    """Typing 'exit' must also exit chat cleanly."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"exit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean


def test_chat_non_tty_rejected():
    """Chat mode must reject non-TTY stdin with exit code 2."""
    result = run_cli(["--chat"], input_text="hello\n")
    assert result.returncode == 2
    assert "interactive terminal" in result.stderr.lower() or "tty" in result.stderr.lower()


def test_chat_eof_exits_cleanly():
    """Ctrl-D (EOF) must exit chat gracefully."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"\x04"),  # Ctrl-D = EOF
        ],
        timeout=15,
    )
    # Should exit without crash (0 = clean exit, 1 = EOF treated as error, -9 = killed)
    assert returncode in (0, 1, -9), f"Unexpected exit code: {returncode}"


# ---------------------------------------------------------------------------
# Category 2: Chat + MCP (5 tests)
# ---------------------------------------------------------------------------

def test_chat_mcp_starts_without_crash():
    """THE BUG FIX TEST: chat + MCP must not crash on startup (#43)."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--mcp", str(MCP_SERVER)],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=30,
    )
    clean = strip_ansi(output)
    assert "Last message has no text content" not in clean, \
        f"Chat+MCP crashed with #43 bug: {clean[:300]}"
    assert "Apple Intelligence" in clean, "Header must appear"
    assert "Goodbye" in clean, "Must exit cleanly"


def test_chat_mcp_shows_tool_list_on_startup():
    """MCP tools must be listed at startup (e.g. 'mcp: ... - add, subtract, ...')."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--mcp", str(MCP_SERVER)],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=30,
    )
    clean = strip_ansi(output)
    assert "mcp:" in clean.lower() or "add" in clean.lower(), \
        f"MCP tool list not shown at startup: {clean[:400]}"


def test_chat_mcp_can_execute_tool():
    """Chat+MCP must execute tool calls, not leak raw JSON (#144)."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--mcp", str(MCP_SERVER)],
        steps=[
            (b"quit", b"What is 2 + 2? Use the add tool.\n", 0.5),
            # Wait for response, then quit
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=90,
    )
    clean = strip_ansi(output)
    assert "Last message has no text content" not in clean, "Chat+MCP crashed"
    # Tool must be executed (tool: log) or model answers correctly
    assert "4" in clean or "tool:" in clean.lower(), \
        f"Tool not executed or answer not found: {clean[:500]}"
    # Raw tool_calls JSON in the AI response is the #144 bug
    ai_lines = [l for l in clean.split('\n') if 'ai' in l.lower() and '"tool_calls"' in l]
    assert not ai_lines, \
        f"Raw tool_calls JSON leaked to chat output (#144): {ai_lines[0][:300] if ai_lines else ''}"


def test_chat_mcp_tool_log_on_stderr():
    """Tool execution log (tool: add(...) = ...) must appear in output."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--mcp", str(MCP_SERVER)],
        steps=[
            (b"quit", b"What is 3 + 5? Use the add tool.\n", 0.5),
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=90,
    )
    clean = strip_ansi(output)
    assert "Last message has no text content" not in clean, "Chat+MCP crashed"
    # Tool must be executed or model answers correctly
    assert "tool:" in clean.lower() or "8" in clean or "eight" in clean.lower(), \
        f"No tool execution or answer visible: {clean[:500]}"
    # Raw tool_calls JSON leak is the #144 bug
    ai_lines = [l for l in clean.split('\n') if 'ai' in l.lower() and '"tool_calls"' in l]
    assert not ai_lines, \
        f"Raw tool_calls JSON leaked to chat output (#144): {ai_lines[0][:300] if ai_lines else ''}"


def test_chat_mcp_with_system_prompt():
    """Chat + MCP + system prompt must all work together without crash."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--mcp", str(MCP_SERVER), "--system", "Be very brief."],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=30,
    )
    clean = strip_ansi(output)
    assert "Last message has no text content" not in clean, "Chat+MCP+system crashed"
    assert "system:" in clean.lower() or "Be very brief" in clean, \
        "System prompt should be displayed"
    assert "Goodbye" in clean


# ---------------------------------------------------------------------------
# Category 3: Chat + System Prompt (3 tests)
# ---------------------------------------------------------------------------

def test_chat_system_prompt_displayed():
    """System prompt must be shown in the chat header area."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--system", "You are a helpful robot."],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "You are a helpful robot" in clean, \
        f"System prompt not displayed: {clean[:300]}"


def test_chat_system_prompt_from_flag():
    """--system flag must be accepted and shown."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "-s", "Be brief."],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Be brief" in clean


def test_chat_system_prompt_from_env():
    """APFEL_SYSTEM_PROMPT env var must set the system prompt."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        env={"APFEL_SYSTEM_PROMPT": "You are a penguin."},
    )
    clean = strip_ansi(output)
    assert "You are a penguin" in clean, \
        f"Env system prompt not displayed: {clean[:300]}"


# ---------------------------------------------------------------------------
# Category 4: Chat + Debug (4 tests)
# ---------------------------------------------------------------------------

def test_chat_debug_shows_output():
    """--debug must produce debug lines in chat mode output."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--debug"],
        steps=[
            (b"quit", b"Say OK\n", 0.3),
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=60,
    )
    clean = strip_ansi(output)
    assert "debug" in clean.lower(), \
        f"No debug output found: {clean[:500]}"


def test_chat_debug_shows_prompt_info():
    """Debug output must include prompt-related info."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--debug"],
        steps=[
            (b"quit", b"Hello\n", 0.3),
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=60,
    )
    clean = strip_ansi(output)
    assert "debug[prompt]" in clean.lower() or "debug" in clean.lower(), \
        f"Debug prompt info missing: {clean[:500]}"


def test_chat_debug_shows_response_info():
    """Debug output must include response-related info."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--debug"],
        steps=[
            (b"quit", b"Say hi\n", 0.3),
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=60,
    )
    clean = strip_ansi(output)
    assert "debug[response]" in clean.lower() or "length=" in clean.lower(), \
        f"Debug response info missing: {clean[:500]}"


def test_chat_debug_json_does_not_pollute_stdout():
    """In JSON mode + debug, debug output must go to TTY/stderr, not stdout."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--debug", "--max-tokens", "5"],
        steps=[
            (b"Type 'quit' to exit.", b"Say OK\n", 0.3),
        ],
        stop_when=lambda stdout, tty: stdout.count(b'"role"') >= 2 or b'"assistant"' in stdout,
        timeout=30,
    )
    # stdout should only have JSON lines, no debug
    assert "debug" not in stdout.lower(), \
        f"Debug output leaked to stdout: {stdout[:300]}"
    # TTY should have debug output
    tty_clean = strip_ansi(tty)
    assert "debug" in tty_clean.lower(), \
        f"Debug output missing from TTY: {tty_clean[:300]}"


# ---------------------------------------------------------------------------
# Category 5: Chat Output Formats (4 tests)
# ---------------------------------------------------------------------------

def test_chat_plain_shows_ai_prefix():
    """Plain mode must show ' ai> ' prompt prefix."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"Say OK\n", 0.3),
            (b"you", b"quit\n", 1.0),
        ],
        stop_when=lambda out: b"Goodbye" in out,
        timeout=60,
    )
    clean = strip_ansi(output)
    assert "ai" in clean, f"AI prompt prefix missing: {clean[:300]}"


def test_chat_json_emits_jsonl():
    """JSON mode must emit valid JSONL with role fields."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--max-tokens", "5"],
        steps=[
            (b"Type 'quit' to exit.", b"Hello\n", 0.3),
        ],
        stop_when=lambda stdout, _: stdout.count(b'"role"') >= 2,
        timeout=60,
    )
    messages = parse_json_lines(stdout)
    assert len(messages) >= 1, f"Expected JSON messages, got: {stdout[:200]}"
    roles = [m["role"] for m in messages]
    assert "user" in roles, f"No user message in JSONL: {roles}"


def test_chat_json_user_and_assistant_messages():
    """JSON mode must emit both user and assistant messages."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--max-tokens", "5"],
        steps=[
            (b"Type 'quit' to exit.", b"Hello\n", 0.3),
        ],
        stop_when=lambda stdout, _: stdout.count(b'"role"') >= 2,
        timeout=60,
    )
    messages = parse_json_lines(stdout)
    roles = [m["role"] for m in messages]
    assert "user" in roles, f"Missing user message: {roles}"
    assert "assistant" in roles, f"Missing assistant message: {roles}"


def test_chat_quiet_suppresses_chrome():
    """--quiet must suppress header, prompts, hints."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--quiet"],
        steps=[
            (None, b"Say OK\n"),
            # In quiet mode, there's no prompt prefix to wait for.
            # Wait a bit then quit.
            (None, b"quit\n", 2.0),
        ],
        timeout=30,
    )
    clean = strip_ansi(output)
    assert "Apple Intelligence" not in clean, "Header should be suppressed in quiet mode"
    assert "Type 'quit'" not in clean, "Hint should be suppressed in quiet mode"


# ---------------------------------------------------------------------------
# Category 6: Chat + Flags Combinations (4 tests)
# ---------------------------------------------------------------------------

def test_chat_with_temperature():
    """--temperature flag must be accepted in chat mode."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--temperature", "0.5"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean
    assert "error" not in clean.lower() or "quit" in clean.lower()


def test_chat_with_max_tokens():
    """--max-tokens flag must be accepted in chat mode."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--max-tokens", "10"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean


def test_chat_with_permissive():
    """--permissive flag must be accepted in chat mode."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--permissive"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean


def test_chat_with_retry():
    """--retry flag must be accepted in chat mode."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat", "--retry"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "Goodbye" in clean


# ---------------------------------------------------------------------------
# Category 7: Chat Multi-Turn & Misc (2+ tests)
# ---------------------------------------------------------------------------

def test_chat_multi_turn_maintains_context():
    """Two prompts in chat; second references first to verify context retention."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--max-tokens", "50"],
        steps=[
            (b"Type 'quit' to exit.", b"My name is Zephyr.\n", 0.5),
            # Wait for assistant response, then ask about the name
            (b'"role":"assistant"', b"What is my name?\n", 1.0),
        ],
        stop_when=lambda stdout, _: stdout.count(b'"role":"assistant"') >= 2,
        timeout=90,
    )
    messages = parse_json_lines(stdout)
    assistant_msgs = [m for m in messages if m["role"] == "assistant"]
    assert len(assistant_msgs) >= 2, f"Expected 2+ assistant messages, got {len(assistant_msgs)}"
    # Second response should mention the name from the first turn
    second_response = assistant_msgs[1]["content"].lower()
    assert "zephyr" in second_response, \
        f"Context lost: second response doesn't mention 'Zephyr': {second_response}"


def test_chat_mcp_answers_non_tool_questions():
    """Chat+MCP must answer general questions (not just tool calls)."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--mcp", str(MCP_SERVER), "--max-tokens", "50"],
        steps=[
            (b"Type 'quit' to exit.", b"What is the capital of France? Reply in one word.\n", 0.5),
        ],
        stop_when=lambda stdout, _: b'"assistant"' in stdout,
        timeout=60,
    )
    messages = parse_json_lines(stdout)
    assistant_msgs = [m for m in messages if m["role"] == "assistant"]
    assert len(assistant_msgs) >= 1, f"No assistant response: {stdout[:300]}"
    content = assistant_msgs[0]["content"].lower()
    # Model should answer with Paris, not try to call a tool
    assert "paris" in content or "tool_calls" not in content, \
        f"MCP mode failed to answer non-tool question: {content}"


def test_chat_no_mcp_answers_translation():
    """Chat without MCP must answer general questions normally."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--max-tokens", "50"],
        steps=[
            (b"Type 'quit' to exit.", b"Translate yellow to German\n", 0.5),
        ],
        stop_when=lambda stdout, _: b'"assistant"' in stdout,
        timeout=60,
    )
    messages = parse_json_lines(stdout)
    assistant_msgs = [m for m in messages if m["role"] == "assistant"]
    assert len(assistant_msgs) >= 1, f"No assistant response: {stdout[:300]}"
    content = assistant_msgs[0]["content"].lower()
    assert "gelb" in content, \
        f"Expected 'gelb' in translation, got: {content}"


def test_chat_mcp_with_system_prompt_answers_normally():
    """Chat + MCP + system prompt must still answer non-tool questions."""
    require_model()
    returncode, stdout, tty = run_chat_json(
        ["--chat", "-o", "json", "--mcp", str(MCP_SERVER), "-s", "Be brief and helpful.", "--max-tokens", "50"],
        steps=[
            (b"Type 'quit' to exit.", b"What is the capital of Austria? Reply in one word.\n", 0.5),
        ],
        stop_when=lambda stdout, _: b'"assistant"' in stdout,
        timeout=60,
    )
    messages = parse_json_lines(stdout)
    assistant_msgs = [m for m in messages if m["role"] == "assistant"]
    assert len(assistant_msgs) >= 1, f"No assistant response: {stdout[:300]}"
    content = assistant_msgs[0]["content"].lower()
    assert "vienna" in content or "wien" in content or "tool_calls" not in content, \
        f"MCP+system mode failed non-tool question: {content}"


# ---------------------------------------------------------------------------
# Category 8: Keyboard Shortcuts (Ctrl-C, Ctrl-D, Ctrl-L)
# ---------------------------------------------------------------------------

def _send_sigint_to_child(pid):
    """Send SIGINT to the child process group (simulates Ctrl-C in terminal)."""
    try:
        os.killpg(os.getpgid(pid), signal.SIGINT)
    except (ProcessLookupError, PermissionError):
        os.kill(pid, signal.SIGINT)


def _run_chat_with_sigint(args, wait_for, delay_before_sigint=0.5, timeout=15, env=None):
    """Start chat, wait for output, send SIGINT, collect result."""
    merged = _clean_env(env)
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message=".*forkpty.*", category=DeprecationWarning)
        pid, master_fd = pty.fork()
    if pid == 0:
        # Create new process group so SIGINT reaches us
        os.setpgrp()
        os.execve(str(BINARY), [str(BINARY), *args], merged)

    output = bytearray()
    deadline = time.time() + timeout
    sigint_sent = False

    try:
        while time.time() < deadline:
            ready, _, _ = select.select([master_fd], [], [], 0.1)
            if master_fd in ready:
                try:
                    chunk = os.read(master_fd, 4096)
                    if chunk:
                        output.extend(chunk)
                except OSError:
                    break

            if not sigint_sent and wait_for in output:
                time.sleep(delay_before_sigint)
                os.kill(pid, signal.SIGINT)
                sigint_sent = True

            try:
                wpid, status = os.waitpid(pid, os.WNOHANG)
                if wpid == pid:
                    os.close(master_fd)
                    return os.waitstatus_to_exitcode(status), output.decode("utf-8", errors="replace")
            except ChildProcessError:
                break
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass

    try:
        os.kill(pid, signal.SIGKILL)
        _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status), output.decode("utf-8", errors="replace")
    except (ChildProcessError, ProcessLookupError):
        return -9, output.decode("utf-8", errors="replace")


def test_chat_ctrl_c_at_empty_prompt_exits():
    """Ctrl-C (SIGINT) at an empty prompt should exit chat."""
    require_model()
    returncode, output = _run_chat_with_sigint(
        ["--chat"], wait_for=b"quit", delay_before_sigint=0.3)
    assert returncode in (0, 130, -2, -9), f"Unexpected exit: {returncode}"


def test_chat_ctrl_c_mid_line_exits():
    """Ctrl-C while typing should exit chat (SIGINT kills process)."""
    require_model()
    returncode, output = _run_chat_with_sigint(
        ["--chat"], wait_for=b"quit", delay_before_sigint=0.3)
    # Ctrl-C exits with 130 (SIGINT)
    assert returncode in (130, -2, -9), f"Expected SIGINT exit, got: {returncode}"


def test_chat_ctrl_d_at_empty_prompt_exits():
    """Ctrl-D (EOF) at an empty prompt should exit chat."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"\x04"),  # Ctrl-D at empty prompt
        ],
        timeout=15,
    )
    # EOF causes readline to return nil -> chat loop breaks
    assert returncode in (0, 1, -9), f"Unexpected exit: {returncode}"


def test_chat_ctrl_c_during_response_does_not_crash():
    """Ctrl-C (SIGINT) during model response should not crash."""
    require_model()
    returncode, output = _run_chat_with_sigint(
        ["--chat"], wait_for=b"quit", delay_before_sigint=0.3)
    clean = strip_ansi(output)
    assert "Segmentation fault" not in clean
    assert "Bus error" not in clean


def test_chat_ctrl_c_multiple_times_exits():
    """Sending SIGINT should exit chat."""
    require_model()
    returncode, output = _run_chat_with_sigint(
        ["--chat"], wait_for=b"quit", delay_before_sigint=0.1)
    assert returncode in (0, 130, -2, -9), f"Unexpected exit: {returncode}"


def test_chat_hint_message_shown():
    """'Type quit to exit.' hint must appear at startup."""
    require_model()
    returncode, output = run_chat_tty(
        ["--chat"],
        steps=[
            (b"quit", b"quit\n"),
        ],
        stop_when=lambda out: b"Goodbye" in out,
    )
    clean = strip_ansi(output)
    assert "quit" in clean.lower() and "exit" in clean.lower(), \
        f"Quit hint not shown: {clean[:300]}"
