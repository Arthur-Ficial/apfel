"""
Guard against TOC/body divergence in docs/EXAMPLES.md and its generator script.

The EXAMPLES.md TOC is hardcoded in scripts/generate-examples.sh. If a section
is added to the body without updating the TOC (or vice versa), these tests fail.
No apfel binary or Apple Intelligence needed - pure file reads.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
EXAMPLES_MD = ROOT / "docs" / "EXAMPLES.md"
GENERATE_SH = ROOT / "scripts" / "generate-examples.sh"

HEADING_RE = re.compile(r"^## (\d+)\. (.+)$", re.MULTILINE)
ECHO_HEADING_RE = re.compile(r'^echo "## (\d+)\. (.+?)"$', re.MULTILINE)
TOC_RE = re.compile(r"^\d+\. \[(.+?)\]", re.MULTILINE)


def test_every_section_heading_appears_in_toc():
    """Every ## N. heading in EXAMPLES.md must have a matching TOC entry."""
    text = EXAMPLES_MD.read_text()
    toc_end = text.index("\n---")
    toc_section = text[:toc_end]
    body_section = text[toc_end:]

    toc_titles = [m.group(1) for m in TOC_RE.finditer(toc_section)]
    body_headings = [(m.group(1), m.group(2)) for m in HEADING_RE.finditer(body_section)]

    missing = []
    for num, title in body_headings:
        if not any(title in t for t in toc_titles):
            missing.append(f"## {num}. {title}")

    assert not missing, (
        f"Section headings in body missing from TOC: {missing}. "
        f"Update the TOC in scripts/generate-examples.sh."
    )


def test_toc_entries_match_body_headings():
    """Every TOC entry must have a corresponding ## N. heading in the body."""
    text = EXAMPLES_MD.read_text()
    toc_end = text.index("\n---")
    toc_section = text[:toc_end]
    body_section = text[toc_end:]

    toc_titles = [m.group(1) for m in TOC_RE.finditer(toc_section)]
    body_titles = [m.group(2) for m in HEADING_RE.finditer(body_section)]

    orphaned = []
    for toc_title in toc_titles:
        if not any(toc_title in bt for bt in body_titles):
            orphaned.append(toc_title)

    assert not orphaned, (
        f"TOC entries with no matching body heading: {orphaned}. "
        f"Either add the section or remove the TOC entry."
    )


def test_script_toc_matches_script_sections():
    """The TOC in generate-examples.sh must list every section the script emits."""
    script = GENERATE_SH.read_text()

    toc_titles = [m.group(1) for m in TOC_RE.finditer(script)]

    echo_headings = ECHO_HEADING_RE.findall(script)
    seen = set()
    script_titles = []
    for num, title in echo_headings:
        if title not in seen:
            seen.add(title)
            script_titles.append(title)

    missing_from_toc = [t for t in script_titles if not any(t in tc for tc in toc_titles)]
    assert not missing_from_toc, (
        f"Script emits sections not listed in its TOC: {missing_from_toc}. "
        f"Add them to the hardcoded TOC in generate-examples.sh."
    )
