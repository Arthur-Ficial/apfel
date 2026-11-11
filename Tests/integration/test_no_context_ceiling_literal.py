"""No fixed context size in source prose (#513, #192, #330) - pure source scan.

The context window is read at runtime and differs per machine (4096 on macOS
26 and on M1/M2, 8192 on macOS 27 with an M3 or newer chip and 12 GB+, and
Apple may change it). A comment or message that says "the 4096-token window"
bakes a stale number into the source and the next reader trusts it. The one
deliberate number, ContextWindow's warm-up floor (#491), is written as a bare
integer and documented as an assumption, so it does not match.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SOURCES = ROOT / "Sources"
PATTERN = re.compile(r"\b(4096|8192)-token\b", re.IGNORECASE)


def test_no_fixed_token_window_in_sources():
    hits = []
    for path in sorted(SOURCES.rglob("*.swift")):
        for i, line in enumerate(path.read_text().splitlines(), 1):
            if PATTERN.search(line):
                hits.append(f"  {path.relative_to(ROOT)}:{i}: {line.strip()}")
    assert not hits, (
        "Found a fixed token window in Sources/ - say 'the context window' instead:\n"
        + "\n".join(hits)
    )
