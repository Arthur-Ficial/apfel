"""
apfel Integration Tests - image input (#510) and capability reporting.

macOS 27: data-URL images reach the on-device model natively (chat
completions, /v1/responses, CLI -f and piped bytes), and the OS reports
model capabilities on /health, /v1/models, and --model-info.
macOS 26: nothing changes - image requests get the honest 400 with the
"image input requires macOS 27" hint, capabilities read as not reported.

Every test asserts BOTH OS branches explicitly (no skips), so the suite is
green on a macOS 26 Mac and on a macOS 27 Mac.

Run: python3 -m pytest Tests/integration/test_vision.py -v
"""

import base64
import pathlib
import platform
import struct
import zlib

import httpx
import pytest

from conftest import require_model, post_chat_rotating_seeds
from cli_e2e_test import run_cli

BASE = "http://localhost:11434"
CHAT = f"{BASE}/v1/chat/completions"
RESPONSES = f"{BASE}/v1/responses"
MODEL = "apple-foundationmodel"
FIXTURES = pathlib.Path(__file__).parent / "fixtures" / "lesbar"

MACOS_MAJOR = int(platform.mac_ver()[0].split(".")[0])
VISION = MACOS_MAJOR >= 27

# The honest macOS 26 rejection (validator message, extended in #510).
NEEDS_27 = "image input requires macOS 27"


def make_red_png(size=64):
    """A solid-red PNG, generated in-process (no fixtures, no tools)."""
    def chunk(kind, payload):
        data = kind + payload
        return struct.pack(">I", len(payload)) + data + struct.pack(">I", zlib.crc32(data))
    raw = b"".join(b"\x00" + b"\xff\x00\x00" * size for _ in range(size))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def red_data_url():
    return "data:image/png;base64," + base64.b64encode(make_red_png()).decode()


def image_message(url, text="What color is this image? Answer with one word."):
    parts = []
    if text:
        parts.append({"type": "text", "text": text})
    parts.append({"type": "image_url", "image_url": {"url": url}})
    return {"role": "user", "content": parts}


def post_chat(messages, **kwargs):
    payload = {"model": MODEL, "messages": messages, **kwargs}
    return httpx.post(CHAT, json=payload, timeout=120)


# ============================================================================
# Capabilities on the wire (model-free)
# ============================================================================

def test_health_reports_capabilities():
    data = httpx.get(f"{BASE}/health", timeout=10).json()
    assert isinstance(data["capabilities"], list)
    assert isinstance(data["capabilities_reported"], bool)
    if VISION:
        assert data["capabilities_reported"] is True
        assert "vision" in data["capabilities"]
        assert "tool_calling" in data["capabilities"]
        assert "guided_generation" in data["capabilities"]
    else:
        assert data["capabilities_reported"] is False
        assert data["capabilities"] == []


def test_models_entry_reports_capabilities():
    entry = httpx.get(f"{BASE}/v1/models", timeout=10).json()["data"][0]
    assert isinstance(entry["capabilities"], list)
    assert isinstance(entry["capabilities_reported"], bool)
    if VISION:
        assert entry["capabilities_reported"] is True
        assert "vision" in entry["capabilities"]
    else:
        assert entry["capabilities_reported"] is False
        assert entry["capabilities"] == []


def test_model_info_has_capabilities_line():
    result = run_cli(["--model-info"])
    assert result.returncode == 0
    line = next((l for l in result.stdout.splitlines() if "capabilities:" in l), None)
    assert line is not None, f"no capabilities line in: {result.stdout}"
    if VISION:
        assert "vision" in line
    else:
        assert "not reported" in line


# ============================================================================
# Rejection paths (model-free: validation fires before any session)
# ============================================================================

def _assert_image_400(resp, needle_27):
    """400 on both OSes: the specific message on 27, the honest hint on 26."""
    assert resp.status_code == 400, f"HTTP {resp.status_code}: {resp.text[:200]}"
    message = resp.json()["error"]["message"]
    if VISION:
        assert needle_27 in message, message
    else:
        assert NEEDS_27 in message, message


def test_remote_image_url_rejected():
    resp = post_chat([image_message("https://example.com/cat.png")])
    _assert_image_400(resp, "apfel does not fetch remote images - send a data URL")


def test_file_url_and_local_path_rejected():
    for url in ("file:///etc/passwd", "/etc/passwd"):
        resp = post_chat([image_message(url)])
        _assert_image_400(resp, "does not read local file paths")


def test_unsupported_media_type_rejected():
    resp = post_chat([image_message("data:image/tiff;base64,QUJD")])
    _assert_image_400(resp, "unsupported image media type 'image/tiff'")


def test_invalid_base64_rejected():
    resp = post_chat([image_message("data:image/png;base64,@@@@")])
    _assert_image_400(resp, "not valid base64")


def test_non_base64_data_url_rejected():
    resp = post_chat([image_message("data:image/png,plaintext")])
    _assert_image_400(resp, "must be base64-encoded")


def test_image_part_outside_user_message_rejected():
    messages = [
        {"role": "assistant", "content": [
            {"type": "image_url", "image_url": {"url": red_data_url()}}]},
        {"role": "user", "content": "hi"},
    ]
    resp = post_chat(messages)
    _assert_image_400(resp, "only supported in 'user' messages")


def test_undecodable_image_bytes_rejected():
    # Valid base64, valid media type, but the bytes are not a PNG. Passes
    # wire validation; the ImageIO decode rejects it as a 400 (macOS 27).
    junk = base64.b64encode(b"not an image at all, just bytes" * 8).decode()
    resp = post_chat([image_message(f"data:image/png;base64,{junk}")])
    _assert_image_400(resp, "could not be decoded")


def test_oversized_image_rejected():
    # 20 MB base64 cap (macOS 27). On macOS 26 the unchanged 1 MiB body cap
    # rejects the request first - as a 413, exactly as today.
    url = "data:image/png;base64," + "A" * (20 * 1024 * 1024 + 4)
    resp = post_chat([image_message(url)])
    if VISION:
        assert resp.status_code == 400, f"HTTP {resp.status_code}: {resp.text[:200]}"
        assert "exceeds the 20 MB base64 limit" in resp.json()["error"]["message"]
    else:
        assert resp.status_code == 413


def test_responses_input_file_part_rejected():
    payload = {"model": MODEL, "input": [{"role": "user", "content": [
        {"type": "input_text", "text": "x"},
        {"type": "input_file", "file_id": "f1"},
    ]}]}
    resp = httpx.post(RESPONSES, json=payload, timeout=30)
    assert resp.status_code == 400
    message = resp.json()["error"]["message"]
    if VISION:
        assert "input_file" in message, message
    else:
        assert NEEDS_27 in message, message


def test_responses_remote_image_rejected():
    payload = {"model": MODEL, "input": [{"role": "user", "content": [
        {"type": "input_image", "image_url": "https://example.com/cat.png"},
    ]}]}
    resp = httpx.post(RESPONSES, json=payload, timeout=30)
    assert resp.status_code == 400
    message = resp.json()["error"]["message"]
    if VISION:
        assert "apfel does not fetch remote images" in message, message
    else:
        assert NEEDS_27 in message, message


# ============================================================================
# Live vision (model) - macOS 27 answers, macOS 26 keeps the honest 400
# ============================================================================

@pytest.mark.model
def test_red_square_answers_red():
    require_model()
    if not VISION:
        _assert_image_400(post_chat([image_message(red_data_url())]), "")
        return
    data = post_chat_rotating_seeds(CHAT, {
        "model": MODEL, "messages": [image_message(red_data_url())],
    }, timeout=120)
    content = data["choices"][0]["message"]["content"].lower()
    assert "red" in content, content
    # The runtime prices the image into prompt_tokens (#510 item 1).
    assert data["usage"]["prompt_tokens"] > 20, data["usage"]


@pytest.mark.model
def test_red_square_streaming():
    require_model()
    payload = {"model": MODEL, "stream": True,
               "messages": [image_message(red_data_url())]}
    if not VISION:
        _assert_image_400(httpx.post(CHAT, json=payload, timeout=30), "")
        return
    chunks = []
    with httpx.stream("POST", CHAT, json=payload, timeout=120) as resp:
        assert resp.status_code == 200
        for line in resp.iter_lines():
            if line.startswith("data: ") and line != "data: [DONE]":
                chunks.append(line)
    text = "".join(chunks).lower()
    assert "red" in text, text[:500]


@pytest.mark.model
def test_image_in_history_survives_followup():
    require_model()
    messages = [
        image_message(red_data_url(), text="Look at this image."),
        {"role": "assistant", "content": "I see it."},
        {"role": "user", "content": "What color was the image I showed you? One word."},
    ]
    if not VISION:
        _assert_image_400(post_chat(messages), "")
        return
    data = post_chat_rotating_seeds(CHAT, {"model": MODEL, "messages": messages}, timeout=120)
    assert "red" in data["choices"][0]["message"]["content"].lower()


@pytest.mark.model
def test_responses_input_image_answers_red():
    require_model()
    payload = {"model": MODEL, "input": [{"role": "user", "content": [
        {"type": "input_text", "text": "What color is this image? Answer with one word."},
        {"type": "input_image", "image_url": red_data_url(), "detail": "auto"},
    ]}]}
    resp = httpx.post(RESPONSES, json=payload, timeout=120)
    if not VISION:
        assert resp.status_code == 400
        assert NEEDS_27 in resp.json()["error"]["message"]
        return
    assert resp.status_code == 200, resp.text[:300]
    data = resp.json()
    text = data["output"][0]["content"][0]["text"].lower()
    assert "red" in text, text


@pytest.mark.model
def test_cli_file_image_attaches_natively(tmp_path):
    require_model()
    png = tmp_path / "red.png"
    png.write_bytes(make_red_png())
    if VISION:
        result = run_cli(["--debug", "-f", str(png),
                          "What color is this image? Answer with one word."], timeout=120)
        assert result.returncode == 0, result.stderr
        assert "red" in result.stdout.lower(), result.stdout
        assert "attached natively" in result.stderr, result.stderr
    else:
        # macOS 26, unchanged: text-only. Depending on what Vision labels
        # the image on this hardware, that is either the clear extraction
        # error (exit 2) or a text-only answer (exit 0) - never a crash,
        # never a native attachment.
        result = run_cli(["-f", str(png), "What color is this image?"], timeout=120)
        assert result.returncode in (0, 2), result.stderr
        if result.returncode == 2:
            assert "could not extract text or identify image" in result.stderr
        assert "attached natively" not in result.stderr


@pytest.mark.model
def test_cli_piped_image_bytes():
    require_model()
    from cli_e2e_test import run_cli_bytes
    if VISION:
        result = run_cli_bytes(
            ["What color is this image? Answer with one word."],
            make_red_png(), timeout=120)
        assert result.returncode == 0, result.stderr
        assert "red" in result.stdout.decode().lower(), result.stdout
    else:
        # macOS 26, unchanged: text-only answer or the clear extraction
        # error, depending on Vision's labels for this hardware.
        result = run_cli_bytes(["What color is this image?"], make_red_png(), timeout=120)
        assert result.returncode in (0, 2), result.stderr.decode()
        if result.returncode == 2:
            assert "could not extract text or identify image" in result.stderr.decode()


@pytest.mark.model
def test_count_tokens_notes_image_attachment(tmp_path):
    require_model()
    png = tmp_path / "red.png"
    png.write_bytes(make_red_png())
    if VISION:
        result = run_cli(["--count-tokens", "-f", str(png), "describe"], timeout=60)
        assert result.returncode == 0, result.stderr
        assert "image attachment not included in this count" in result.stderr
    else:
        result = run_cli(["--count-tokens", "-f", str(png), "describe"], timeout=120)
        # macOS 26 never attaches natively, so the note must not appear -
        # whether extraction produced labels (exit 0) or errored (exit 2).
        assert result.returncode in (0, 2), result.stderr
        assert "image attachment not included in this count" not in result.stderr
