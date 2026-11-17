"""#576: /v1/models, /health and `apfel --model-info` report which Apple
Foundation Model variant serves requests.

Model-free: the variant is read from the OS (macOS 27: the runtime's
SystemLanguageModel.variant; macOS 26: AFM 2.1 Core from 26.4, AFM 2 Core
before), so these run in CI too. Mapping from Apple's "Detecting available
Apple Foundation Models".
"""

import pathlib
import platform
import subprocess

import httpx

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
BASE_URL = "http://127.0.0.1:11434"


def _expected_ids():
    major, minor = (int(p) for p in (platform.mac_ver()[0].split(".") + ["0"])[:2])
    if major >= 27:
        # core3 / coreAdvanced3, or the display name of a newer variant.
        return None
    return {"core2_1"} if (major, minor) >= (26, 4) else {"core2"}


def _check(variant):
    assert set(variant) == {"id", "display_name"}, variant
    assert variant["id"] and variant["display_name"]
    expected = _expected_ids()
    if expected is not None:
        assert variant["id"] in expected, variant
    else:
        assert variant["display_name"].startswith("AFM"), variant


def test_models_report_the_variant():
    data = httpx.get(f"{BASE_URL}/v1/models", timeout=10).json()["data"]
    for entry in data:
        _check(entry["variant"])


def test_health_reports_the_variant():
    _check(httpx.get(f"{BASE_URL}/health", timeout=10).json()["variant"])


def test_health_and_models_agree():
    health = httpx.get(f"{BASE_URL}/health", timeout=10).json()["variant"]
    models = httpx.get(f"{BASE_URL}/v1/models", timeout=10).json()["data"][0]["variant"]
    assert health == models


def test_model_info_prints_the_variant():
    out = subprocess.run([str(BINARY), "--model-info"], capture_output=True, text=True,
                         stdin=subprocess.DEVNULL, timeout=60, env={"NO_COLOR": "1", "PATH": "/usr/bin:/bin"})
    assert out.returncode == 0, out.stderr
    line = next((l for l in out.stdout.splitlines() if "variant:" in l), None)
    assert line is not None, out.stdout
    health = httpx.get(f"{BASE_URL}/health", timeout=10).json()["variant"]
    assert health["display_name"] in line and f"({health['id']})" in line, line
