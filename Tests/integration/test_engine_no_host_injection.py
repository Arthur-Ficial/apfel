"""ApfelEngine must work for a downstream app without host wiring (#531 review).

The first cut of ApfelEngine read model capabilities and the variant name
through `public nonisolated(unsafe) static var` closures that apfel's
main.swift overwrote at startup. A downstream app that did not copy those two
lines got `capabilities_reported: false` and no variant name even on macOS 27,
a silent downgrade, and the mutable globals opted out of Swift 6 checking.
Both readers live in ApfelEngine itself, so the engine calls them directly.

Pure source scan, model-free.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).parents[2]
ENGINE = ROOT / "Sources" / "Engine"


def test_engine_has_no_mutable_global_state():
    hits = []
    for path in sorted(ENGINE.rglob("*.swift")):
        for i, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r"nonisolated\(unsafe\)", line) and not line.lstrip().startswith("//"):
                hits.append(f"{path.relative_to(ROOT)}:{i}: {line.strip()}")
    assert hits == [], "ApfelEngine must not expose nonisolated(unsafe) state:\n" + "\n".join(hits)


def test_host_does_not_wire_engine_readers():
    main = (ROOT / "Sources" / "main.swift").read_text()
    assert "TokenCounter.capabilitiesReader" not in main
    assert "TokenCounter.variantReader" not in main


def test_token_counter_reads_capabilities_itself():
    text = (ENGINE / "TokenCounter.swift").read_text()
    assert "readModelCapabilities()" in text
