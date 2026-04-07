"""
apfel Integration Tests — Background Service

Validates the CLI surface and the internal service runner without mutating the
real user's LaunchAgents or Application Support directories.
"""

import json
import os
import pathlib
import socket
import subprocess
import tempfile
import time

import httpx


ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"


def run_cli(args, env=None, timeout=30):
    merged_env = os.environ.copy()
    for key in [
        "NO_COLOR",
        "APFEL_SYSTEM_PROMPT",
        "APFEL_HOST",
        "APFEL_PORT",
        "APFEL_TOKEN",
        "APFEL_TEMPERATURE",
        "APFEL_MAX_TOKENS",
    ]:
        merged_env.pop(key, None)
    if env:
        merged_env.update(env)
    return subprocess.run(
        [str(BINARY), *args],
        text=True,
        capture_output=True,
        env=merged_env,
        timeout=timeout,
    )


def find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait_for_server(base_url, timeout=20):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            response = httpx.get(f"{base_url}/health", timeout=1)
            if response.status_code == 200:
                return
        except httpx.HTTPError:
            pass
        time.sleep(0.2)
    raise TimeoutError(f"Timed out waiting for server at {base_url}")


def test_help_mentions_service_commands():
    result = run_cli(["--help"])
    assert result.returncode == 0, result.stderr
    assert "apfel service install" in result.stdout
    assert "apfel service status" in result.stdout
    assert "apfel service uninstall" in result.stdout


def test_service_status_reports_uninstalled_in_clean_home():
    with tempfile.TemporaryDirectory() as temp_home:
        result = run_cli(["service", "status"], env={"HOME": temp_home})
        assert result.returncode == 0, result.stderr
        assert "not installed" in result.stdout.lower()


def test_service_run_starts_from_persisted_config():
    with tempfile.TemporaryDirectory() as temp_home:
        port = find_free_port()
        support_dir = pathlib.Path(temp_home) / "Library" / "Application Support" / "apfel"
        support_dir.mkdir(parents=True)
        config_path = support_dir / "server.json"
        config_path.write_text(json.dumps({
            "host": "127.0.0.1",
            "port": port,
            "cors": False,
            "maxConcurrent": 5,
            "debug": False,
            "allowedOrigins": [
                "http://127.0.0.1",
                "http://localhost",
                "http://[::1]",
            ],
            "originCheckEnabled": True,
            "token": None,
            "publicHealth": False,
            "mcpServerPaths": [],
        }), encoding="utf-8")

        proc = subprocess.Popen(
            [str(BINARY), "service", "run"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env={**os.environ, "HOME": temp_home},
        )
        try:
            wait_for_server(f"http://127.0.0.1:{port}")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
