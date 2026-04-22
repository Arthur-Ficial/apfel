"""
Smoke-test `ApfelCore` as a downstream SwiftPM product.

This fixture package depends on the repo by local path and imports
`ApfelCore` as an external product. The test should fail until
`Package.swift` exposes `.library(name: "ApfelCore", targets: ["ApfelCore"])`.
"""

import pathlib
import subprocess

import pytest


FIXTURE = pathlib.Path(__file__).resolve().parent / "fixtures" / "apfelcore-consumer"


@pytest.fixture(scope="session", autouse=True)
def guard_server_11434():
    yield


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    yield


def test_apfelcore_can_be_imported_by_a_downstream_package():
    result = subprocess.run(
        ["swift", "run", "apfelcore-consumer"],
        cwd=FIXTURE,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        "downstream SwiftPM consumer failed to build or run\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
    assert result.stdout.strip() == "hello|sliding-window"
