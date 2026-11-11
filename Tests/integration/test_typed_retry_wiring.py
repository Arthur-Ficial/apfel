"""Every main-target retry classifies through the typed classifier (#522).

ApfelCore's `withRetry(maxRetries:delays:operation:)` classifies with the pure
`ApfelError.classify`, which cannot see macOS 27's typed `LanguageModelError`
(ApfelCore is FoundationModels-free). A typed `rateLimited` whose localized
description has no English keyword was therefore not retried. Main-target code
must call `withModelRetry`, which injects `classifyModelError`.

Pure source scan, model-free.
"""
import pathlib
import re

SOURCES = pathlib.Path(__file__).parents[2] / "Sources"


def test_main_target_never_calls_bare_withRetry():
    offenders = []
    for path in sorted(SOURCES.rglob("*.swift")):
        rel = path.relative_to(SOURCES)
        if rel.parts[0] == "Core":
            continue  # ApfelCore defines withRetry; it may not see typed errors.
        for lineno, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            if re.search(r"(?<![A-Za-z])withRetry\(", line) and "classify:" not in line:
                offenders.append(f"{rel}:{lineno}: {line.strip()}")
    assert offenders == [], (
        "Main-target code calls ApfelCore's withRetry directly, so macOS 27 typed "
        "errors are classified by keyword only. Use withModelRetry (#522):\n"
        + "\n".join(offenders)
    )


def test_withModelRetry_injects_the_typed_classifier():
    text = (SOURCES / "TypedErrorSupport.swift").read_text()
    m = re.search(r"func withModelRetry.*?\n}\n", text, re.DOTALL)
    assert m, "withModelRetry must live next to classifyModelError in TypedErrorSupport.swift"
    assert "classify: classifyModelError" in m.group(0)
