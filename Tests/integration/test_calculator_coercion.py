"""Unit tests for MCP calculator server argument coercion.

The on-device 3B model routinely emits tool arguments as strings
(e.g. {"a": "999", "b": "1"}) even when the schema says type: number.
The calculator must coerce these to numbers, not silently string-concatenate.

These tests import the calculator server directly - no apfel binary or
Apple Intelligence needed, so they run in CI.
"""
import importlib.util
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CALC_PATH = ROOT / "mcp" / "calculator" / "server.py"


@pytest.fixture(scope="module")
def calculator():
    spec = importlib.util.spec_from_file_location("calculator", str(CALC_PATH))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestStringArgCoercion:
    """String arguments must be coerced to numbers, never concatenated."""

    def test_add_string_args_returns_sum_not_concatenation(self, calculator):
        result = calculator.execute("add", {"a": "999", "b": "1"})
        assert result == "1000", f"add('999','1') = {result!r}, expected '1000' (got concatenation?)"

    def test_subtract_string_args(self, calculator):
        result = calculator.execute("subtract", {"a": "10", "b": "3"})
        assert result == "7"

    def test_multiply_string_args(self, calculator):
        result = calculator.execute("multiply", {"a": "247", "b": "83"})
        assert result == "20501"

    def test_divide_string_args(self, calculator):
        result = calculator.execute("divide", {"a": "10", "b": "4"})
        assert result == "2.5"

    def test_sqrt_string_arg(self, calculator):
        result = calculator.execute("sqrt", {"a": "144"})
        assert result == "12"

    def test_power_string_args(self, calculator):
        result = calculator.execute("power", {"a": "2", "b": "10"})
        assert result == "1024"

    def test_round_number_string_arg(self, calculator):
        result = calculator.execute("round_number", {"a": "3.14159", "decimals": "2"})
        assert result == "3.14"

    def test_add_float_strings(self, calculator):
        result = calculator.execute("add", {"a": "1.5", "b": "2.5"})
        assert result == "4"

    def test_non_numeric_string_returns_error(self, calculator):
        result = calculator.execute("add", {"a": "hello", "b": "1"})
        assert result.startswith("Error:")

    def test_numeric_args_still_work(self, calculator):
        result = calculator.execute("add", {"a": 999, "b": 1})
        assert result == "1000"

    def test_mixed_numeric_and_string_args(self, calculator):
        result = calculator.execute("add", {"a": 999, "b": "1"})
        assert result == "1000"
