"""CI Python-environment hygiene guards (#477).

Both pip steps in ci.yml used to run `pip3 install --break-system-packages`
into the runner's brew-managed system prefix. When a transitive dependency
wanted a newer `typing_extensions`, pip tried to uninstall brew's copy, found
no RECORD file, and aborted the whole job - non-deterministically, on roughly a
third of runs, regardless of the diff under test. That made every red check in
the PR queue meaningless.

These are pure source scans of the workflow, so they run model-free on CI.
"""
import pathlib
import re

WORKFLOWS = pathlib.Path(__file__).parents[2] / ".github" / "workflows"


def _workflow_files():
    return sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))


def test_no_workflow_installs_into_the_system_prefix():
    """`--break-system-packages` is the flag that lets pip fight brew. Ban it."""
    offenders = [
        p.name for p in _workflow_files()
        if "--break-system-packages" in p.read_text()
    ]
    assert offenders == [], (
        "These workflows install into the runner's brew-managed system prefix: "
        f"{offenders}. Install into a venv instead (#477) - a venv owns its own "
        "site-packages, so there is no RECORD-less brew distribution for pip to "
        "try to uninstall."
    )


def test_every_pip_install_step_targets_a_venv():
    """A bare `pip3 install` is the same bug wearing a different flag."""
    bad = []
    for p in _workflow_files():
        for lineno, line in enumerate(p.read_text().splitlines(), 1):
            if re.search(r"(^|\s)pip3?\s+install\b", line) and "venv" not in line:
                bad.append(f"{p.name}:{lineno}: {line.strip()}")
    assert bad == [], (
        "These pip invocations do not target a venv (#477):\n" + "\n".join(bad)
    )


def test_venv_bin_is_put_on_github_path():
    """Creating the venv is useless if later `python3 -m pytest` steps miss it."""
    for p in _workflow_files():
        text = p.read_text()
        if "python3 -m venv" not in text:
            continue
        assert "GITHUB_PATH" in text, (
            f"{p.name} creates a venv but never appends its bin/ to $GITHUB_PATH, "
            "so subsequent steps still resolve the system python3 (#477)."
        )
