"""Smoke-test the runnable ApfelCore example targets.

These examples back the public Swift package docs. If they stop compiling
or their basic output changes unexpectedly, we want CI to fail loudly.
"""

import subprocess

import pytest


EXAMPLES = [
    (
        "apfelcore-context-strategies-example",
        [
            "strategy=sliding-window",
            "max_turns=8",
            "output_reserve=512",
        ],
    ),
    (
        "apfelcore-openai-types-example",
        [
            "model=apple-foundationmodel",
            "messages=2",
        ],
    ),
    (
        "apfelcore-tool-calling-example",
        [
            "## Tool Calling Format",
            '"name" : "add"',
        ],
    ),
    (
        "apfelcore-error-handling-example",
        [
            "[rate limited]",
            "[context overflow]",
            "[unsupported language]",
        ],
    ),
    (
        "apfelcore-mcp-protocol-example",
        [
            '"method":"initialize"',
            '"method":"tools\\/list"',
        ],
    ),
]


@pytest.fixture(scope="session", autouse=True)
def guard_server_11434():
    yield


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    yield


@pytest.mark.parametrize(("target", "expected_fragments"), EXAMPLES)
def test_apfelcore_examples_build_and_run(target, expected_fragments):
    result = subprocess.run(
        ["swift", "run", target],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"{target} failed to build or run\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
    for fragment in expected_fragments:
        assert fragment in result.stdout, (
            f"{target} output missing expected fragment: {fragment!r}\n"
            f"stdout:\n{result.stdout}"
        )
