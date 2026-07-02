"""
apfel Integration Tests -- docs/EXAMPLES.md internal consistency

Model-free: pure file checks. Guards #331: the generator script's Table of
Contents is a hardcoded list that historically drifted from the sections the
script actually emits (section 14 was appended without a TOC entry, so every
regeneration reproduced a TOC contradicting the document body).

Run: python3 -m pytest Tests/integration/test_examples_doc.py -v
"""

import pathlib
import re

EXAMPLES = pathlib.Path(__file__).parent.parent.parent / "docs" / "EXAMPLES.md"


def test_toc_matches_section_headings():
    text = EXAMPLES.read_text()
    toc = re.findall(r"^(\d+)\. \[([^\]]+)\]", text, flags=re.MULTILINE)
    headings = re.findall(r"^## (\d+)\. (.+)$", text, flags=re.MULTILINE)
    assert toc, "no TOC entries found in docs/EXAMPLES.md"
    assert headings, "no numbered section headings found in docs/EXAMPLES.md"
    toc_set = {(num, title.strip()) for num, title in toc}
    heading_set = {(num, title.strip()) for num, title in headings}
    missing_from_toc = heading_set - toc_set
    missing_from_body = toc_set - heading_set
    assert not missing_from_toc, f"sections missing from the TOC: {sorted(missing_from_toc)}"
    assert not missing_from_body, f"TOC entries without a section: {sorted(missing_from_body)}"
