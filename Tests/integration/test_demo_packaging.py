"""
apfel Integration Tests -- Demo Script Packaging

Pins the brew install shape that ships demo/*  as apfel-<name> companion
commands. Verifies:
  1. Tarball produced by `make package-release-asset` (if present) bundles demo/.
  2. The homebrew tap formula generator writes a `def install` block that
     installs demo/ and creates apfel-<name> symlinks for every demo script.

Run: python3 -m pytest Tests/integration/test_demo_packaging.py -v
Requires nothing model-related -- pure packaging assertions.
"""

import pathlib
import re
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEMO_DIR = ROOT / "demo"
FORMULA_SCRIPT = ROOT / "scripts" / "write-homebrew-formula.sh"
EXPECTED_DEMOS = [
    "cmd",
    "explain",
    "gitsum",
    "mac-narrator",
    "naming",
    "oneliner",
    "port",
    "wtd",
]


def test_demo_directory_has_every_expected_script():
    for name in EXPECTED_DEMOS:
        path = DEMO_DIR / name
        assert path.exists(), f"demo/{name} missing"
        assert path.is_file(), f"demo/{name} is not a file"


def test_formula_generator_installs_demo_pkgshare(tmp_path):
    output = tmp_path / "apfel.rb"
    subprocess.run(
        [
            "bash",
            str(FORMULA_SCRIPT),
            "--version",
            "9.9.9",
            "--sha256",
            "0" * 64,
            "--output",
            str(output),
        ],
        check=True,
    )
    text = output.read_text()
    assert 'pkgshare.install "demo"' in text, (
        "formula should install demo/ to pkgshare"
    )


def test_formula_generator_installs_every_demo_symlink(tmp_path):
    output = tmp_path / "apfel.rb"
    subprocess.run(
        [
            "bash",
            str(FORMULA_SCRIPT),
            "--version",
            "9.9.9",
            "--sha256",
            "0" * 64,
            "--output",
            str(output),
        ],
        check=True,
    )
    text = output.read_text()
    for name in EXPECTED_DEMOS:
        assert name in text, f"formula should reference demo/{name}"
    assert "bin.install_symlink" in text, (
        "formula should symlink demos into bin with apfel- prefix"
    )


def test_formula_generator_exposes_demos_in_caveats(tmp_path):
    output = tmp_path / "apfel.rb"
    subprocess.run(
        [
            "bash",
            str(FORMULA_SCRIPT),
            "--version",
            "9.9.9",
            "--sha256",
            "0" * 64,
            "--output",
            str(output),
        ],
        check=True,
    )
    text = output.read_text()
    # Caveats list every demo by its installed name so users can discover them.
    for name in EXPECTED_DEMOS:
        assert f"apfel-{name}" in text, (
            f"caveats should advertise apfel-{name} so users can discover it"
        )


def test_formula_brew_test_asserts_demo_symlink(tmp_path):
    output = tmp_path / "apfel.rb"
    subprocess.run(
        [
            "bash",
            str(FORMULA_SCRIPT),
            "--version",
            "9.9.9",
            "--sha256",
            "0" * 64,
            "--output",
            str(output),
        ],
        check=True,
    )
    text = output.read_text()
    # The brew test must actually exercise the new symlink, otherwise
    # the new install block could silently regress.
    test_block = re.search(r"test do\b(.*?)\bend\b", text, re.DOTALL)
    assert test_block, "formula must keep a `test do` block"
    body = test_block.group(1)
    assert "apfel-cmd" in body, "brew test should assert apfel-cmd is installed"


def test_release_tarball_bundles_demos():
    """Pin tarball shape: package-release-asset must bundle binary + man + demos.

    Skipped if the release build artefacts are not on disk -- producing them
    requires `make build` + `make generate-man-page` and we do not want every
    test run to trigger that. CI release flows always have them, so the
    assertion bites where it matters.
    """
    binary = ROOT / ".build" / "release" / "apfel"
    man = ROOT / ".build" / "release" / "apfel.1"
    if not binary.exists() or not man.exists():
        pytest.skip(
            "Release build artefacts missing (run `make build && make generate-man-page`)"
        )

    subprocess.run(
        ["make", "package-release-asset"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    version = (ROOT / ".version").read_text().strip()
    asset = ROOT / f"apfel-{version}-arm64-macos.tar.gz"
    assert asset.exists(), f"expected tarball at {asset}"

    result = subprocess.run(
        ["tar", "-tzf", str(asset)], capture_output=True, text=True, check=True
    )
    entries = result.stdout.splitlines()
    assert "apfel" in entries, "tarball must contain the apfel binary"
    assert "apfel.1" in entries, "tarball must contain the man page"
    for name in EXPECTED_DEMOS:
        assert f"demo/{name}" in entries, (
            f"tarball must bundle demo/{name} so brew users can install it"
        )
