"""
apfel Integration Tests - MCP calculator numeric coercion.

The on-device 3B model routinely emits string arguments for numeric
parameters (e.g. {"a": "999", "b": "1"} instead of {"a": 999, "b": 1}).
The calculator must coerce these to numbers, not silently string-concatenate.

No model or running server needed - tests call execute() directly.
"""

import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "mcp" / "calculator"))
import server as calc


def test_add_string_args_returns_numeric_sum():
    result = calc.execute("add", {"a": "999", "b": "1"})
    assert result == "1000", f"add('999','1') should be 1000, got {result}"


def test_add_numeric_args_still_works():
    result = calc.execute("add", {"a": 999, "b": 1})
    assert result == "1000"


def test_add_mixed_string_and_numeric():
    result = calc.execute("add", {"a": "3.5", "b": 2})
    assert result == "5.5"


def test_subtract_string_args():
    result = calc.execute("subtract", {"a": "100", "b": "30"})
    assert result == "70"


def test_multiply_string_args():
    result = calc.execute("multiply", {"a": "247", "b": "83"})
    assert result == "20501"


def test_divide_string_args():
    result = calc.execute("divide", {"a": "10", "b": "4"})
    assert result == "2.5"


def test_sqrt_string_arg():
    result = calc.execute("sqrt", {"a": "144"})
    assert result == "12"


def test_power_string_args():
    result = calc.execute("power", {"a": "2", "b": "10"})
    assert result == "1024"


def test_round_number_string_arg():
    result = calc.execute("round_number", {"a": "3.14159", "decimals": "2"})
    assert result == "3.14"


def test_non_numeric_string_returns_error():
    result = calc.execute("add", {"a": "hello", "b": "1"})
    assert result.startswith("Error:"), f"Non-numeric arg should error, got {result}"


def test_divide_by_zero_string_args():
    result = calc.execute("divide", {"a": "10", "b": "0"})
    assert result == "Error: division by zero"
