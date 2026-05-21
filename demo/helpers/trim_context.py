#!/usr/bin/env python3
"""Trim Markdown documentation for a small LLM context window.

Keeps high-value DocC sections first (overview, declaration, parameters), drops
navigation-heavy sections, then fills remaining budget with other sections.
The token count is approximate: 1 token ~= 4 characters.
"""

import argparse
import re
import sys


DROP_HEADINGS = (
    "inherited by",
    "conforms to",
    "conforming types",
    "relationships",
    "see also",
)

PRIORITY_HEADINGS = (
    "overview",
    "declaration",
    "discussion",
    "parameters",
    "creating",
    "using",
    "usage",
)


def section_title(line):
    match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
    return match.group(2).strip() if match else None


def split_sections(text):
    sections = []
    current = {"title": "", "lines": []}
    for line in text.splitlines():
        title = section_title(line)
        if title is not None:
            sections.append(current)
            current = {"title": title, "lines": [line]}
        else:
            current["lines"].append(line)
    sections.append(current)
    return [section for section in sections if section["lines"]]


def should_drop(title):
    lower = title.lower()
    return any(marker in lower for marker in DROP_HEADINGS)


def priority(title):
    if not title:
        return 0
    lower = title.lower()
    if any(marker in lower for marker in PRIORITY_HEADINGS):
        return 1
    return 2


def section_text(section):
    return "\n".join(section["lines"]).strip() + "\n"


def trim_to_chars(text, max_chars):
    if len(text) <= max_chars:
        return text.rstrip()
    clipped = text[:max_chars]
    last_newline = clipped.rfind("\n")
    if last_newline > max_chars * 0.75:
        clipped = clipped[:last_newline]
    return clipped.rstrip() + "\n\n[trimmed to fit context budget]"


def trim_markdown(text, max_tokens):
    max_chars = max(1000, max_tokens * 4)
    sections = [s for s in split_sections(text) if not should_drop(s["title"])]

    selected = set()
    used = 0
    for wanted_priority in (0, 1, 2):
        for index, section in enumerate(sections):
            if index in selected or priority(section["title"]) != wanted_priority:
                continue
            text_part = section_text(section)
            if used + len(text_part) <= max_chars:
                selected.add(index)
                used += len(text_part)
            elif wanted_priority < 2 and max_chars - used > 800:
                selected.add(index)
                used = max_chars
                break
        if used >= max_chars:
            break

    output = "\n".join(section_text(sections[i]).rstrip() for i in sorted(selected)).strip()
    return trim_to_chars(output, max_chars)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-tokens", type=int, default=2000)
    args = parser.parse_args()
    print(trim_markdown(sys.stdin.read(), args.max_tokens))


if __name__ == "__main__":
    main()
