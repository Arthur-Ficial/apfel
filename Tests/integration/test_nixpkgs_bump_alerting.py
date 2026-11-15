"""
apfel Integration Tests - nixpkgs bump failure alerting.

Two units make the nixpkgs pipeline self-healing instead of silently failing
for days (as it did when a GitHub 2FA-compliance break stopped PR creation):

  1. scripts/publish-nixpkgs-bump.sh classifies its outcome on a final
     `NIXPKGS_BUMP_STATUS=<TOKEN> version=<X.Y.Z>` line + a matching exit code,
     and explicitly detects the NixOS 2FA-compliance error (which 403s even
     reads) via an early read-probe so it fails fast and loud as AUTH_2FA.

  2. scripts/nixpkgs-bump-cron.sh (the launchd wrapper) runs the bump, reads the
     status, and emails Franz via hm-send AT MOST ONCE per distinct
     (status, version) failure - benign outcomes stay silent and clear the
     dedup state so a future regression re-alerts.

These tests stub gh / hm-send / the bump script entirely; no network, no nix.
"""

import os
import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BUMP = ROOT / "scripts" / "publish-nixpkgs-bump.sh"
CRON = ROOT / "scripts" / "nixpkgs-bump-cron.sh"

TWO_FA_MSG = (
    "GraphQL: `NixOS` requires everyone in the organization to enable "
    "two-factor authentication with any of the following methods: "
    "Authenticator app, GitHub Mobile, Security Keys, and Passkeys. "
    "Please remove SMS if configured as it is not considered secure. (repository)"
)


def _run(args, env=None, **kwargs):
    proc = subprocess.run(args, capture_output=True, text=True, env=env, **kwargs)
    return proc.returncode, proc.stdout, proc.stderr


def _write_exec(path: pathlib.Path, body: str):
    path.write_text(body)
    path.chmod(0o755)


# --------------------------------------------------------------------------
# Cron wrapper (scripts/nixpkgs-bump-cron.sh)
# --------------------------------------------------------------------------

@pytest.fixture
def cron_env(tmp_path):
    """A bin/ with a recording hm-send stub, an isolated XDG_STATE_HOME, and a
    helper to point the wrapper at a stub bump script with a chosen outcome."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    record = tmp_path / "hm-send.record"
    _write_exec(
        bindir / "hm-send",
        '#!/usr/bin/env bash\n'
        f'{{ echo "TO=$1"; echo "SUBJ=$2"; cat; echo; echo "===SENT==="; }} >> "{record}"\n',
    )
    state_home = tmp_path / "state"

    env = dict(os.environ)
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env["XDG_STATE_HOME"] = str(state_home)
    env["NIXPKGS_BUMP_ALERT_TO"] = "franz@example.com"
    env["HOME"] = str(tmp_path)  # keep LOG path off the real home

    def make_bump(status_line: str | None, exit_code: int):
        stub = tmp_path / "stub-bump.sh"
        lines = ['#!/usr/bin/env bash']
        if status_line is not None:
            lines.append(f'echo "{status_line}"')
        lines.append(f'exit {exit_code}')
        _write_exec(stub, "\n".join(lines) + "\n")
        env["NIXPKGS_BUMP_SCRIPT"] = str(stub)
        return stub

    state_file = state_home / "apfel" / "nixpkgs-bump-alert.state"
    return env, record, make_bump, state_file


def _email_count(record: pathlib.Path) -> int:
    if not record.exists():
        return 0
    return record.read_text().count("===SENT===")


def test_cron_exists_and_executable():
    assert CRON.exists(), f"missing: {CRON}"
    assert CRON.stat().st_mode & 0o111, "nixpkgs-bump-cron.sh is not executable"


def test_actionable_failure_emails_once_and_writes_state(cron_env):
    env, record, make_bump, state_file = cron_env
    make_bump("NIXPKGS_BUMP_STATUS=AUTH_2FA version=1.6.0", 20)

    rc, out, err = _run([str(CRON)], env=env)

    assert rc == 0, f"wrapper must always exit 0; got {rc}\n{out}\n{err}"
    assert _email_count(record) == 1
    body = record.read_text()
    assert "AUTH_2FA" in body
    assert "1.6.0" in body
    assert state_file.exists()
    assert "AUTH_2FA 1.6.0" in state_file.read_text()


def test_repeated_same_failure_dedups(cron_env):
    env, record, make_bump, _ = cron_env
    make_bump("NIXPKGS_BUMP_STATUS=AUTH_2FA version=1.6.0", 20)

    _run([str(CRON)], env=env)
    _run([str(CRON)], env=env)
    _run([str(CRON)], env=env)

    assert _email_count(record) == 1, "same failure must alert only once"


def test_new_version_failure_realerts(cron_env):
    env, record, make_bump, _ = cron_env

    make_bump("NIXPKGS_BUMP_STATUS=AUTH_2FA version=1.6.0", 20)
    _run([str(CRON)], env=env)
    make_bump("NIXPKGS_BUMP_STATUS=AUTH_2FA version=1.7.0", 20)
    _run([str(CRON)], env=env)

    assert _email_count(record) == 2, "a newer stuck version is a distinct alert"


def test_benign_status_no_email_and_clears_state(cron_env):
    env, record, make_bump, state_file = cron_env

    # first a failure -> emails + writes state
    make_bump("NIXPKGS_BUMP_STATUS=AUTH_2FA version=1.6.0", 20)
    _run([str(CRON)], env=env)
    assert _email_count(record) == 1
    assert state_file.exists()

    # then a recovery (PR opened) -> no new email, state cleared
    make_bump("NIXPKGS_BUMP_STATUS=PR_ADVANCED version=1.6.0", 0)
    rc, _, _ = _run([str(CRON)], env=env)
    assert rc == 0
    assert _email_count(record) == 1, "benign run must not email"
    assert not state_file.exists(), "recovery must clear alert state so a future failure re-alerts"


@pytest.mark.parametrize("status", ["IN_SYNC", "PR_OPENED", "PR_ADVANCED", "PR_WAITING"])
def test_benign_statuses_never_email(cron_env, status):
    env, record, make_bump, _ = cron_env
    make_bump(f"NIXPKGS_BUMP_STATUS={status} version=1.6.0", 0)
    _run([str(CRON)], env=env)
    assert _email_count(record) == 0


def test_script_death_without_status_is_actionable(cron_env):
    env, record, make_bump, _ = cron_env
    make_bump(None, 1)  # dies before emitting a status line
    rc, _, _ = _run([str(CRON)], env=env)
    assert rc == 0
    assert _email_count(record) == 1, "an unclassified non-zero exit must still alert"


# --------------------------------------------------------------------------
# Bump script 2FA read-probe classification
# --------------------------------------------------------------------------

def test_bump_detects_2fa_readblock_as_auth_2fa(tmp_path):
    """With a gh that authenticates but 403s NixOS reads with the 2FA message,
    the bump must fail fast as AUTH_2FA (exit 20) - BEFORE any clone/build."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    # gh: `api user` ok (authed); any NixOS repo read emits the 2FA error.
    _write_exec(
        bindir / "gh",
        '#!/usr/bin/env bash\n'
        'if [[ "$1" == "api" && "$2" == "user" ]]; then exit 0; fi\n'
        'if [[ "$1" == "api" && "$2" == repos/NixOS/* ]]; then\n'
        f'  echo {TWO_FA_MSG!r} >&2; exit 1\n'
        'fi\n'
        'exit 0\n',
    )
    # nix-prefetch-url must merely exist for the tool check to pass.
    _write_exec(bindir / "nix-prefetch-url", '#!/usr/bin/env bash\nexit 0\n')

    env = dict(os.environ)
    env["PATH"] = f"{bindir}:{env['PATH']}"
    # Point the checkout dir at a throwaway path so a regression that skips the
    # read-probe can never touch the real ~/dev/nixpkgs-bump.
    env["NIXPKGS_BUMP_DIR"] = str(tmp_path / "nixpkgs-checkout")
    # The repo may carry a real .nixpkgs-bump-paused; this test exercises the live path.
    env["NIXPKGS_BUMP_PAUSE_FILE"] = str(tmp_path / "not-paused")

    rc, out, err = _run([str(BUMP), "--version", "1.6.0"], env=env)

    assert rc == 20, f"expected AUTH_2FA exit 20, got {rc}\nstdout:{out}\nstderr:{err}"
    assert "NIXPKGS_BUMP_STATUS=AUTH_2FA" in out, f"missing status line\n{out}"


# --------------------------------------------------------------------------
# Pause switch (2026-11-15: a nixpkgs maintainer closed the automated bump PR
# under the contributing guidelines; no new automated PR until it is lifted)
# --------------------------------------------------------------------------

def test_bump_pause_file_stops_before_any_github_call(tmp_path):
    """A present pause file ends the bump as PAUSED (exit 0) before gh, git or
    nix are touched, so neither the launchd job nor `make release` opens a PR."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    marker = tmp_path / "gh-was-called"
    _write_exec(bindir / "gh", f'#!/usr/bin/env bash\ntouch {marker}\nexit 0\n')
    _write_exec(bindir / "nix-prefetch-url", '#!/usr/bin/env bash\nexit 0\n')
    pause = tmp_path / "paused"
    pause.write_text("closed by a nixpkgs maintainer, see NixOS/nixpkgs#565008\n")

    env = dict(os.environ)
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env["NIXPKGS_BUMP_DIR"] = str(tmp_path / "nixpkgs-checkout")
    env["NIXPKGS_BUMP_PAUSE_FILE"] = str(pause)

    rc, out, err = _run([str(BUMP), "--version", "1.18.0"], env=env)

    assert rc == 0, f"paused bump must exit 0, got {rc}\nstdout:{out}\nstderr:{err}"
    assert "NIXPKGS_BUMP_STATUS=PAUSED version=1.18.0" in out, out
    assert "NixOS/nixpkgs#565008" in out, "the pause reason must be printed"
    assert not marker.exists(), "gh must not be called while paused"
    assert not (tmp_path / "nixpkgs-checkout").exists(), "no clone while paused"


def test_paused_status_never_emails(cron_env):
    env, record, make_bump, _ = cron_env
    make_bump("NIXPKGS_BUMP_STATUS=PAUSED version=1.18.0", 0)
    _run([str(CRON)], env=env)
    assert _email_count(record) == 0
