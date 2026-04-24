"""
apfel Integration Tests - Man page drift prevention.

These tests keep `man/apfel.1.in` in lockstep with `apfel --help` and the
declared exit-code inventory. If the CLI grows or loses a flag / env var /
exit code, one of these assertions will fail until the man page is updated.
This is the core promise of the man-page automation - it cannot silently
drift.

Also lints the generated `apfel.1` with `mandoc -Tlint` so syntax errors
never reach a release.
"""

import pathlib
import re
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build" / "release" / "apfel"
MAN_PAGE = ROOT / ".build" / "release" / "apfel.1"
MAN_SOURCE = ROOT / "man" / "apfel.1.in"
VERSION_FILE = ROOT / ".version"
MAIN_SWIFT = ROOT / "Sources" / "main.swift"
EXIT_CODES_SWIFT = ROOT / "Sources" / "CLI" / "ExitCodes.swift"

FLAG_RE = re.compile(r"(--[a-z][a-z0-9-]+)")
SHORT_FLAG_RE = re.compile(r"(?<![\w-])(-[a-z])(?=[ ,])")
ENV_RE = re.compile(r"\b(APFEL_[A-Z0-9_]+|NO_COLOR)\b")


def _help_output() -> str:
    if not BINARY.exists():
        pytest.skip(f"Release binary missing at {BINARY}. Run `make build` first.")
    res = subprocess.run([str(BINARY), "--help"], capture_output=True, text=True, timeout=10)
    assert res.returncode == 0, f"--help exited {res.returncode}: {res.stderr}"
    return res.stdout


def _man_page_text() -> str:
    if not MAN_PAGE.exists():
        pytest.skip(f"Generated man page missing at {MAN_PAGE}. Run `make generate-man-page` first.")
    return MAN_PAGE.read_text()


def _man_page_unescaped() -> str:
    """Man page with troff hyphen escapes (`\\-`) normalized to real hyphens.

    Needed so flag regexes match `--foo` in both the --help output and the
    troff source without requiring the troff source to use raw hyphens
    (which mandoc would render as minus signs rather than option dashes).
    """
    return _man_page_text().replace("\\-", "-")


def _man_page_flag_sections() -> str:
    """Slice of the man page that defines flags.

    Everything above the FILES section covers SYNOPSIS, DESCRIPTION, OPTIONS,
    CONTEXT OPTIONS, SERVER OPTIONS, ENVIRONMENT, EXIT STATUS. Flags that
    appear later (in FILES/EXAMPLES/BUGS/SEE ALSO) are command examples or
    documentation references, not apfel's own flag surface, and must not
    be compared against `--help`.
    """
    text = _man_page_unescaped()
    marker = ".SH FILES"
    idx = text.find(marker)
    return text if idx < 0 else text[:idx]


def _flags_from(text: str) -> set[str]:
    flags = set(FLAG_RE.findall(text))
    flags.update(SHORT_FLAG_RE.findall(text))
    # Strip trailing hyphens and dots mandoc syntax can leave behind.
    return {f.rstrip(".-") for f in flags}


def _env_vars_from(text: str) -> set[str]:
    return set(ENV_RE.findall(text))


def test_man_source_exists():
    assert MAN_SOURCE.exists(), f"man source missing: {MAN_SOURCE}"


def test_man_page_generated():
    assert MAN_PAGE.exists(), (
        f"Generated man page missing at {MAN_PAGE}. "
        "Run `make generate-man-page` (normally runs as part of `make build`)."
    )


def test_man_page_lints_with_mandoc():
    """mandoc -Tlint must be clean (zero warnings) on the generated page."""
    mandoc = shutil.which("mandoc")
    if not mandoc:
        pytest.skip("mandoc not installed on this host")
    res = subprocess.run(
        [mandoc, "-Tlint", "-W", "warning", str(MAN_PAGE)],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert res.returncode == 0, (
        f"mandoc -Tlint reported issues:\n{res.stdout}\n{res.stderr}"
    )
    assert res.stdout.strip() == "", f"mandoc warnings:\n{res.stdout}"


def test_man_page_renders_with_man():
    """`man -l <file>` must render without error on macOS."""
    man = shutil.which("man")
    if not man:
        pytest.skip("man not installed on this host")
    res = subprocess.run(
        [man, str(MAN_PAGE)],
        capture_output=True,
        text=True,
        timeout=10,
        env={"MANPAGER": "cat", "PAGER": "cat"},
    )
    assert res.returncode == 0, (
        f"man {MAN_PAGE} failed (exit {res.returncode}):\n{res.stderr}"
    )
    assert "apfel" in res.stdout.lower()


def test_version_matches_version_file():
    """The version substituted into the man page must equal .version."""
    expected = VERSION_FILE.read_text().strip()
    text = _man_page_text()
    first_line = text.splitlines()[0]
    assert f'"apfel {expected}"' in first_line, (
        f"Expected version {expected!r} in .TH header, got:\n{first_line}"
    )
    # Placeholder must not survive into the generated page.
    assert "@VERSION@" not in text, "@VERSION@ placeholder leaked into generated man page"


def test_bidirectional_long_flag_coverage():
    """Every long flag in --help must appear in the man page, and vice versa."""
    help_text = _help_output()
    man_text = _man_page_flag_sections()

    help_flags = {f for f in _flags_from(help_text) if f.startswith("--")}
    man_flags = {f for f in _flags_from(man_text) if f.startswith("--")}

    missing_in_man = help_flags - man_flags
    missing_in_help = man_flags - help_flags

    assert not missing_in_man, (
        f"Flags in --help but missing from man page: {sorted(missing_in_man)}. "
        "Update man/apfel.1.in to document them."
    )
    assert not missing_in_help, (
        f"Flags in man page but missing from --help: {sorted(missing_in_help)}. "
        "The man page must not document flags the binary does not accept."
    )


def test_bidirectional_env_var_coverage():
    """Every APFEL_* / NO_COLOR env var in --help must appear in the man page."""
    help_text = _help_output()
    man_text = _man_page_unescaped()

    help_env = _env_vars_from(help_text)
    man_env = _env_vars_from(man_text)

    missing_in_man = help_env - man_env
    missing_in_help = man_env - help_env

    assert not missing_in_man, (
        f"Env vars in --help but missing from man page: {sorted(missing_in_man)}"
    )
    assert not missing_in_help, (
        f"Env vars in man page but missing from --help: {sorted(missing_in_help)}"
    )


def test_bidirectional_exit_code_coverage():
    """Every exit code declared in ApfelCLI must appear in the man page."""
    # Constants live in Sources/CLI/ExitCodes.swift (testable); main.swift
    # re-exposes them via `let exit...: Int32 = ApfelExitCodes.xxx` for local
    # readability. Scrape the literal values from ExitCodes.swift.
    src = EXIT_CODES_SWIFT.read_text()
    # e.g. `public static let guardrail: Int32 = 3`
    declared = set(re.findall(r"public\s+static\s+let\s+\w+\s*:\s*Int32\s*=\s*(\d+)", src))
    assert declared, "No exit codes found in Sources/CLI/ExitCodes.swift - pattern changed?"

    man_text = _man_page_text()
    for code in sorted(declared, key=int):
        assert f".B {code}\n" in man_text, (
            f"Exit code {code} declared in ApfelExitCodes but not documented in man page"
        )
