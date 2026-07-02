"""Unit tests for the MCP calculator server (model-free).

Tests the calculator's execute() and _coerce_num() functions directly,
without any server or model dependency. Validates that string arguments
from the on-device model are coerced to numbers, not concatenated.
"""
import importlib.util
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CALC_PATH = ROOT / "mcp" / "calculator" / "server.py"

spec = importlib.util.spec_from_file_location("calculator", CALC_PATH)
calculator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calculator)

execute = calculator.execute
_coerce_num = calculator._coerce_num


class TestCoerceNum:
    def test_int_passthrough(self):
        assert _coerce_num(42) == 42

    def test_float_passthrough(self):
        assert _coerce_num(3.14) == 3.14

    def test_string_int(self):
        assert _coerce_num("999") == 999

    def test_string_float(self):
        assert _coerce_num("3.14") == 3.14

    def test_non_numeric_string_raises(self):
        with pytest.raises(ValueError):
            _coerce_num("abc")

    def test_none_raises(self):
        with pytest.raises((ValueError, TypeError)):
            _coerce_num(None)

    def test_list_raises(self):
        with pytest.raises((ValueError, TypeError)):
            _coerce_num([1, 2])


class TestExecuteStringArgs:
    """The core regression: string args must compute, not concatenate (#322)."""

    def test_add_string_args_computes_sum(self):
        result = execute("add", {"a": "999", "b": "1"})
        assert result == "1000", f"add('999','1') must be 1000, got {result}"

    def test_add_string_args_never_concatenates(self):
        result = execute("add", {"a": "999", "b": "1"})
        assert result != "9991", "add() must not string-concatenate"

    def test_subtract_string_args(self):
        assert execute("subtract", {"a": "10", "b": "3"}) == "7"

    def test_multiply_string_args(self):
        assert execute("multiply", {"a": "247", "b": "83"}) == "20501"

    def test_divide_string_args(self):
        assert execute("divide", {"a": "10", "b": "4"}) == "2.5"

    def test_sqrt_string_arg(self):
        assert execute("sqrt", {"a": "144"}) == "12"

    def test_power_string_args(self):
        assert execute("power", {"a": "2", "b": "10"}) == "1024"

    def test_round_number_string_arg(self):
        assert execute("round_number", {"a": "3.14159", "decimals": "2"}) == "3.14"

    def test_non_numeric_string_returns_error(self):
        result = execute("add", {"a": "hello", "b": "1"})
        assert result.startswith("Error:")

    def test_mixed_string_and_numeric(self):
        assert execute("add", {"a": "999", "b": 1}) == "1000"
        assert execute("add", {"a": 999, "b": "1"}) == "1000"


class TestExecuteNumericArgs:
    """Regression guard: normal numeric args still work after the fix."""

    def test_add(self):
        assert execute("add", {"a": 10, "b": 3}) == "13"

    def test_subtract(self):
        assert execute("subtract", {"a": 10, "b": 3}) == "7"

    def test_multiply(self):
        assert execute("multiply", {"a": 247, "b": 83}) == "20501"

    def test_divide(self):
        assert execute("divide", {"a": 10, "b": 4}) == "2.5"

    def test_divide_by_zero(self):
        assert execute("divide", {"a": 10, "b": 0}) == "Error: division by zero"

    def test_sqrt(self):
        assert execute("sqrt", {"a": 144}) == "12"

    def test_power(self):
        assert execute("power", {"a": 2, "b": 10}) == "1024"

    def test_round_number(self):
        assert execute("round_number", {"a": 3.14159, "decimals": 2}) == "3.14"

    def test_unknown_tool(self):
        assert execute("unknown", {"a": 1}) == "Error: unknown tool 'unknown'"
