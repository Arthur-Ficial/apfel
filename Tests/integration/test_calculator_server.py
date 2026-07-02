"""
apfel Integration Tests -- MCP calculator server correctness

Validates that the bundled MCP calculator server (mcp/calculator/server.py)
returns correct results regardless of argument type. The on-device 3B model
routinely sends string arguments (e.g. {"a": "999", "b": "1"}) even though
the schema declares {"type": "number"} -- the server must coerce, not
string-concatenate.

These tests call the calculator server directly via subprocess (stdio MCP),
so they need no running apfel binary or Apple Intelligence.

Run: python3 -m pytest Tests/integration/test_calculator_server.py -v
"""

import json
import pathlib
import subprocess
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CALC = ROOT / "mcp" / "calculator" / "server.py"


def mcp_call(tool_name, arguments):
    """Call the MCP calculator server via stdio and return (text, isError)."""
    init_msg = json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "apfel-test", "version": "1.0"},
        },
    })
    call_msg = json.dumps({
        "jsonrpc": "2.0", "id": 2, "method": "tools/call",
        "params": {"name": tool_name, "arguments": arguments},
    })
    proc = subprocess.run(
        [sys.executable, str(CALC)],
        input=f"{init_msg}\n{call_msg}\n",
        capture_output=True,
        text=True,
        timeout=5,
    )
    assert proc.returncode == 0, f"calculator server crashed: {proc.stderr}"
    for line in proc.stdout.strip().split("\n"):
        msg = json.loads(line)
        if msg.get("id") == 2:
            result = msg["result"]
            text = result["content"][0]["text"]
            is_error = result.get("isError", False)
            return text, is_error
    pytest.fail("no tools/call response from calculator server")


# -- String argument coercion (#322) -----------------------------------------

class TestStringArgumentCoercion:
    """The model often sends string args. The server must coerce, not concatenate."""

    def test_add_string_args_returns_sum_not_concatenation(self):
        text, is_error = mcp_call("add", {"a": "999", "b": "1"})
        assert not is_error, f"unexpected error: {text}"
        assert text == "1000", f"expected '1000', got '{text}' (string concatenation?)"

    def test_add_string_args_never_returns_9991(self):
        text, _ = mcp_call("add", {"a": "999", "b": "1"})
        assert text != "9991", "add('999','1') = 9991 means string concatenation, not addition"

    def test_subtract_string_args(self):
        text, is_error = mcp_call("subtract", {"a": "10", "b": "3"})
        assert not is_error
        assert text == "7"

    def test_multiply_string_args(self):
        text, is_error = mcp_call("multiply", {"a": "247", "b": "83"})
        assert not is_error
        assert text == "20501"

    def test_divide_string_args(self):
        text, is_error = mcp_call("divide", {"a": "10", "b": "4"})
        assert not is_error
        assert text == "2.5"

    def test_sqrt_string_arg(self):
        text, is_error = mcp_call("sqrt", {"a": "144"})
        assert not is_error
        assert text == "12"

    def test_power_string_args(self):
        text, is_error = mcp_call("power", {"a": "2", "b": "10"})
        assert not is_error
        assert text == "1024"

    def test_round_number_string_args(self):
        text, is_error = mcp_call("round_number", {"a": "3.14159", "decimals": "2"})
        assert not is_error
        assert text == "3.14"

    def test_add_float_strings(self):
        text, is_error = mcp_call("add", {"a": "1.5", "b": "2.5"})
        assert not is_error
        assert text == "4"

    def test_non_numeric_string_returns_error(self):
        text, is_error = mcp_call("add", {"a": "hello", "b": "1"})
        assert is_error, f"expected isError for non-numeric arg, got: {text}"
        assert "numeric" in text.lower() or "number" in text.lower() or "error" in text.lower()


# -- Numeric argument baseline (regression guard) ----------------------------

class TestNumericArgumentBaseline:
    """Normal numeric arguments must still work after the coercion fix."""

    def test_add_integers(self):
        text, is_error = mcp_call("add", {"a": 999, "b": 1})
        assert not is_error
        assert text == "1000"

    def test_add_floats(self):
        text, is_error = mcp_call("add", {"a": 1.5, "b": 2.5})
        assert not is_error
        assert text == "4"

    def test_multiply_integers(self):
        text, is_error = mcp_call("multiply", {"a": 247, "b": 83})
        assert not is_error
        assert text == "20501"

    def test_divide_by_zero(self):
        text, is_error = mcp_call("divide", {"a": 10, "b": 0})
        assert is_error
        assert "division by zero" in text.lower()

    def test_sqrt_negative(self):
        text, is_error = mcp_call("sqrt", {"a": -1})
        assert is_error
