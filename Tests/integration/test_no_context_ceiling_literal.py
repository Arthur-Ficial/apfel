"""No-literal-ceiling guard (#513, #192, #330) - pure source scan.

The context window is dynamic (4096 on M1/M2, 8192 on M3+ with 12 GB+,
subject to change by Apple). Prose comments that say "the 4096-token ceiling"
or "the 4096-token context ceiling" bake a stale number into the source.

This model-free scan catches the two known patterns and keeps them from
creeping back.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SOURCES = ROOT / "Sources"


def _swift_files():
    """All .swift files under Sources/, recursively."""
    return sorted(SOURCES.rglob("*.swift"))


def test_no_4096_token_ceiling_in_comments():
    """No Swift source comment should say '4096-token ceiling' (#513)."""
    pattern = re.compile(r"4096-token\s+.*ceiling|4096-token\s+ceiling", re.IGNORECASE)
    hits = []
    for path in _swift_files():
        for i, line in enumerate(path.read_text().splitlines(), 1):
            stripped = line.lstrip()
            if not stripped.startswith("//"):
                continue
            if pattern.search(stripped):
                hits.append(f"  {path.relative_to(ROOT)}:{i}: {line.strip()}")
    assert not hits, (
        "Found '4096-token ceiling' in source comments - use 'the context window' instead:\n"
        + "\n".join(hits)
    )
