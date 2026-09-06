"""Marker-discipline guards (#374) - keep the two-phase partition sound.

The pipeline runs `-m "not model and not serial"` in parallel and
`-m "model or serial"` serially. That split is only correct while the
markers stay truthful; these pure source scans (model-free, run on CI)
make marker rot a red build instead of a silent mis-phasing.
"""
import pathlib
import re

HERE = pathlib.Path(__file__).parent

# Suites whose tests drive real generation (or need Apple Intelligence up)
# wholesale; each must carry a module-level `pytestmark = pytest.mark.model`.
# CLAUDE.md "What GitHub CI CANNOT run" is the source of this list.
MODEL_SUITES = [
    "openai_client_test.py",
    "mcp_server_test.py",
    "mcp_remote_test.py",
    "openapi_conformance_test.py",
    "performance_test.py",
    "test_context_strict.py",
    "test_tdd_red.py",
]

# Suites that mutate machine-global state and must stay out of the
# parallel phase.
SERIAL_SUITES = ["test_brew_service.py"]


def _suite_files():
    return sorted(p for p in HERE.glob("*.py")
                  if p.name not in ("conftest.py", pathlib.Path(__file__).name))


def test_model_suites_carry_module_pytestmark():
    for name in MODEL_SUITES:
        src = (HERE / name).read_text()
        assert re.search(r"^pytestmark = pytest\.mark\.model$", src, re.M), (
            f"{name} is a whole-suite model file (MODEL_SUITES) but lacks "
            f"'pytestmark = pytest.mark.model'"
        )


def test_serial_suites_carry_module_pytestmark():
    for name in SERIAL_SUITES:
        src = (HERE / name).read_text()
        assert re.search(r"^pytestmark = pytest\.mark\.serial$", src, re.M), (
            f"{name} mutates global state (SERIAL_SUITES) but lacks "
            f"'pytestmark = pytest.mark.serial'"
        )


def test_every_require_model_caller_is_marked():
    """A test that gates on require_model() IS a model test - the decorator
    (or a module-level model pytestmark) must say so, or `-m "not model"`
    selects it and the fast phase pays for a model call (worse: on CI it
    fails via the APFEL_MODELFREE_ONLY tripwire, ten minutes later)."""
    offenders = []
    for path in _suite_files():
        src = path.read_text()
        if re.search(r"^pytestmark = pytest\.mark\.model$", src, re.M):
            continue  # module-wide marker covers every test in the file
        blocks = re.split(r"^(?=@|def test_)", src, flags=re.M)
        decorators = []
        for block in blocks:
            if block.startswith("@"):
                decorators.append(block.strip())
                continue
            if block.startswith("def test_"):
                name = block.split("(")[0][4:]
                if "require_model()" in block and not any(
                    "pytest.mark.model" in d for d in decorators
                ):
                    offenders.append(f"{path.name}::{name}")
            decorators = []
    assert not offenders, (
        "tests call require_model() without @pytest.mark.model: "
        + ", ".join(offenders)
    )


def test_no_local_model_gate_redefinitions():
    """require_model/model_available live in conftest.py only - the per-file
    copies this replaced had drifted (test_chat's version skipped where
    cli_e2e's failed loud). One implementation, one behavior."""
    offenders = []
    for path in _suite_files():
        src = path.read_text()
        if re.search(r"^def (require_model|model_available)\b", src, re.M):
            offenders.append(path.name)
    assert not offenders, (
        "local model-gate redefinitions (import from conftest instead): "
        + ", ".join(offenders)
    )
