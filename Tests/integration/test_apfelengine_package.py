"""
Smoke-test `ApfelEngine` as a downstream SwiftPM product (#531).

A fixture package depends on the repo by local path, imports `ApfelEngine`,
builds an engine through `EngineFactory` and reads its data-only status
surface. Model-free: nothing is generated, so it runs on CI too. Fails until
`Package.swift` exposes `.library(name: "ApfelEngine", ...)`.
"""

import pathlib
import subprocess

import pytest


FIXTURE = pathlib.Path(__file__).resolve().parent / "fixtures" / "apfelengine-consumer"


@pytest.fixture(scope="session", autouse=True)
def guard_server_11434():
    yield


@pytest.fixture(scope="session", autouse=True)
def guard_server_11435():
    yield


def test_apfelengine_can_be_imported_by_a_downstream_package():
    result = subprocess.run(
        ["swift", "run", "apfelengine-consumer"],
        cwd=FIXTURE,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
    )
    assert result.returncode == 0, (
        "downstream SwiftPM consumer failed to build or run\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
    assert result.stdout.strip() == "engine|true|0"
