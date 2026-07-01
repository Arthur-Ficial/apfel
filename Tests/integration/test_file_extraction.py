"""Integration tests for `apfel -f` and piped-file extraction via the lesbar package.

Exercises every extraction path against REAL public-domain fixtures (see
fixtures/lesbar/README.md): a text-layer PDF (US IRS W-9), a photo WITH text
(Apollo 11 plaque), a photo WITHOUT text (NASA space image), and a plain text file.

Most assertions use `--count-tokens`, which is model-free and deterministic: it proves
extraction produced text of the expected magnitude without invoking Apple Intelligence.
PDF text extraction is pure PDFKit; image OCR/classification uses Vision (present on
macOS). The one end-to-end content check requires Apple Intelligence and skips otherwise.
"""
import pathlib
import re
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
FIXTURES = pathlib.Path(__file__).parent / "fixtures" / "lesbar"

PLAQUE = FIXTURES / "apollo11_plaque.jpg"   # photo WITH text (NASA, public domain)
SPACE = FIXTURES / "nasa_space.jpg"         # photo WITHOUT text (NASA, public domain)
W9 = FIXTURES / "irs_w9.pdf"                # document WITH text (US IRS, public domain)
PLAIN = FIXTURES / "plain.txt"
MONA = FIXTURES / "wikimedia_mona_lisa.jpg"   # painting WITHOUT text (Wikimedia, public domain)
DECL = FIXTURES / "wikimedia_declaration.jpg" # document scan WITH text (Wikimedia, public domain)
TEXT_SAMPLE = FIXTURES / "text_sample.png"    # authored PD text image, converted per-format at runtime

# Image formats apfel must accept (detected by content, not extension).
FORMATS = ["png", "jpeg", "tiff", "gif", "bmp", "heic"]

TOTAL_RE = re.compile(r"(\d+)/\d+ tokens")
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

# Skip the whole module (rather than error) if the release binary is not built.
pytestmark = pytest.mark.skipif(not BINARY.exists(), reason=f"apfel release binary not built at {BINARY}")


def _tokens_from_output(text: str) -> int:
    m = TOTAL_RE.search(text)
    assert m, f"no token total in output: {text!r}"
    return int(m.group(1))


def count_tokens_file(path: pathlib.Path) -> int:
    """Run `apfel -f <path> --count-tokens` and return the total token count.

    Raises AssertionError (failing the test) if extraction exits non-zero.
    """
    r = subprocess.run(
        [str(BINARY), "-f", str(path), "--count-tokens"],
        capture_output=True, text=True, timeout=60,
    )
    assert r.returncode == 0, f"extraction failed for {path.name}: {r.stderr}"
    return _tokens_from_output(r.stdout)


def count_tokens_piped(path: pathlib.Path) -> int:
    """Run `cat <path> | apfel --count-tokens` and return the total token count."""
    data = path.read_bytes()
    r = subprocess.run(
        [str(BINARY), "--count-tokens"],
        input=data, capture_output=True, timeout=60,
    )
    assert r.returncode == 0, f"piped extraction failed: {r.stderr.decode(errors='replace')}"
    return _tokens_from_output(r.stdout.decode(errors="replace"))


def model_available() -> bool:
    r = subprocess.run([str(BINARY), "--model-info"], capture_output=True, text=True, timeout=20)
    return r.returncode == 0 and "available:  yes" in r.stdout.lower()


def debug_extract(path: pathlib.Path) -> str:
    """Return exactly what apfel puts to the API for a file.

    Runs `apfel -f <path> --count-tokens --debug`, which is model-free: `--debug` prints
    the framed extraction (and full prompt) to stderr, `--count-tokens` avoids the model.
    This is the "see what we actually send" path, used to assert extracted content
    deterministically without depending on model output.
    """
    r = subprocess.run(
        [str(BINARY), "-f", str(path), "--count-tokens", "--debug"],
        capture_output=True, text=True, timeout=60,
    )
    assert r.returncode == 0, f"extraction failed for {path.name}: {r.stderr}"
    return ANSI_RE.sub("", r.stderr)


def sips_convert(src: pathlib.Path, fmt: str, dest: pathlib.Path) -> bool:
    r = subprocess.run(
        ["sips", "-s", "format", fmt, str(src), "--out", str(dest)],
        capture_output=True, text=True, timeout=30,
    )
    return r.returncode == 0 and dest.exists()


def test_fixtures_present():
    for f in (PLAQUE, SPACE, W9, PLAIN, MONA, DECL, TEXT_SAMPLE):
        assert f.exists(), f"missing fixture {f}"


# --- Documents (PDF text layer) — model-free, Vision-free (pure PDFKit) ---

def test_pdf_text_layer_extracted():
    # The W-9 is text-dense; a real extraction yields hundreds+ of tokens.
    assert count_tokens_file(W9) > 500


def test_plain_text_passthrough():
    assert 0 < count_tokens_file(PLAIN) < 100


# --- Photos (Vision OCR + classification) ---

def test_photo_with_text_extracted():
    # Plaque: OCR recovers engraved text + classification frames it. Non-zero tokens.
    assert count_tokens_file(PLAQUE) > 0


def test_photo_without_text_still_classified():
    # NASA space image: no readable text, but classification still yields a framed
    # "what the image shows" block, so extraction succeeds with non-zero tokens.
    assert count_tokens_file(SPACE) > 0


# --- Piped files (stdin) ---

def test_piped_pdf_extracted():
    assert count_tokens_piped(W9) > 500


def test_piped_photo_extracted():
    assert count_tokens_piped(PLAQUE) > 0


# --- Unsupported input is rejected, not silently mishandled ---

def test_unsupported_file_errors(tmp_path):
    blob = tmp_path / "junk.bin"
    blob.write_bytes(b"PK\x03\x04" + bytes(range(256)) * 4)  # zip-ish binary, not text/pdf/image
    r = subprocess.run(
        [str(BINARY), "-f", str(blob), "hi"],
        capture_output=True, text=True, timeout=30,
    )
    assert r.returncode != 0
    assert "unsupported" in r.stderr.lower() or "utf-8" in r.stderr.lower()


# --- End-to-end content proof (requires Apple Intelligence) ---

def test_photo_ocr_content_reaches_model():
    if not model_available():
        pytest.skip("Apple Intelligence not enabled")
    r = subprocess.run(
        [str(BINARY), "-f", str(PLAQUE),
         "Output only the exact words you can read in the image, uppercase, nothing else."],
        capture_output=True, text=True, timeout=90,
    )
    assert r.returncode == 0, r.stderr
    out = r.stdout.upper()
    # The plaque reads "...WE CAME IN PEACE FOR ALL MANKIND". OCR + model should surface it.
    assert "PEACE" in out or "MANKIN" in out, f"OCR text did not reach the model: {r.stdout!r}"


# --- Wikimedia public-domain fixtures, inspected via --debug (model-free, deterministic) ---

def test_wikimedia_declaration_with_text_ocr():
    # PD-US document scan. OCR recovers period text; framing shows it as image text.
    out = debug_extract(DECL).upper()
    assert "(IMAGE)" in out
    assert "TEXT IN IMAGE:" in out
    assert "1776" in out or "CONGRESS" in out, f"expected Declaration text, got:\n{out[:400]}"


def test_wikimedia_mona_lisa_without_text_classified():
    # PD-old painting, no text: classification must supply "what the image is about".
    out = debug_extract(MONA)
    assert "(image)" in out
    lower = out.lower()
    assert "what the image shows:" in lower
    assert "art" in lower or "paint" in lower, f"expected art/painting labels, got:\n{out[:400]}"


# --- Many image formats, with and without text (converted at runtime with sips) ---

@pytest.mark.parametrize("fmt", FORMATS)
def test_image_with_text_all_formats(fmt, tmp_path):
    dest = tmp_path / f"text.{fmt}"
    if not sips_convert(TEXT_SAMPLE, fmt, dest):
        pytest.skip(f"sips could not produce {fmt}")
    out = debug_extract(dest).upper()
    assert "(IMAGE)" in out
    assert "TEXT IN IMAGE:" in out
    assert any(w in out for w in ("APFEL", "LESBAR", "OCR")), f"OCR failed for {fmt}:\n{out[:300]}"


@pytest.mark.parametrize("fmt", FORMATS)
def test_image_without_text_all_formats(fmt, tmp_path):
    dest = tmp_path / f"notext.{fmt}"
    if not sips_convert(MONA, fmt, dest):
        pytest.skip(f"sips could not produce {fmt}")
    out = debug_extract(dest).lower()
    assert "(image)" in out
    # A textless painting still yields a classification ("what the image shows"),
    # so extraction succeeds and frames it across every format.
    assert "what the image shows:" in out
