#!/usr/bin/env python3
"""Keep the translated READMEs in i18n/ interlinked and checkable.

Usage:
  python3 scripts/i18n-readme.py           insert/refresh the language bar in README.md and i18n/README.*.md
  python3 scripts/i18n-readme.py check     fail on a missing translation, a missing/stale bar or a broken
                                           relative link; warn (never fail) on a stale translation
  python3 scripts/i18n-readme.py source    print the English README prepared for translation from i18n/
                                           (links rewritten to ../, version badge removed, source header)

The languages are the landing page languages (apfel.franzai.com footer), same codes and native names.
Every translation starts with `<!-- i18n-source: <commit> -->`, the commit of the English README it was
translated from. `check` reports it as stale when the English README changed since then.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
I18N = ROOT / "i18n"

# code -> native name, exactly as in the apfel.franzai.com language footer (sr = Latin script).
LANGS: dict[str, str] = {
    "ar": "العربية", "be": "Беларуская", "bg": "Български", "bn": "বাংলা", "bs": "Bosanski",
    "ca": "Català", "cs": "Čeština", "da": "Dansk", "de": "Deutsch", "el": "Ελληνικά",
    "es": "Español", "et": "Eesti", "fa": "فارسی", "fi": "Suomi", "fr": "Français",
    "gu": "ગુજરાતી", "hi": "हिन्दी", "hr": "Hrvatski", "hu": "Magyar", "it": "Italiano",
    "ja": "日本語", "kn": "ಕನ್ನಡ", "ko": "한국어", "lt": "Lietuvių", "lv": "Latviešu",
    "mk": "Македонски", "ml": "മലയാളം", "mr": "मराठी", "nb": "Norsk bokmål", "nl": "Nederlands",
    "pl": "Polski", "pt": "Português", "ro": "Română", "ru": "Русский", "sk": "Slovenčina",
    "sl": "Slovenščina", "sq": "Shqip", "sr": "Srpski", "sv": "Svenska", "ta": "தமிழ்",
    "te": "తెలుగు", "tr": "Türkçe", "uk": "Українська", "ur": "اردو", "zh-hans": "简体中文",
    "zh-hant": "繁體中文",
}

BAR_PREFIX = "**Languages:**"
BAR_ANCHOR = "## Quick Start"  # root README only: the bar goes right before this heading
SOURCE_RE = re.compile(r"^<!-- i18n-source: ([0-9a-f]{7,40}) -->")
VERSION_BADGE = "img.shields.io/badge/version-"  # rewritten by every release, kept out of translations
LINK_RE = re.compile(r"\]\(([^)\s]+)\)|src=\"([^\"]+)\"")


def translation_path(code: str) -> Path:
    return I18N / f"README.{code}.md"


def bar_for(current: str) -> str:
    """The language bar for the file of language `current` ("en" = root README)."""
    in_root = current == "en"
    parts = ["**English**" if in_root else "[English](../README.md)"]
    for code, name in LANGS.items():
        if code == current:
            parts.append(f"**{name}**")
        else:
            parts.append(f"[{name}]({'i18n/' if in_root else ''}README.{code}.md)")
    return f"{BAR_PREFIX} " + " | ".join(parts)


def with_bar(text: str, bar: str, is_root: bool) -> str:
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith(BAR_PREFIX):
            lines[i] = bar
            return "\n".join(lines)
    if not is_root:
        raise SystemExit("translation has no '**Languages:**' line; re-run `source` and keep that line")
    idx = lines.index(BAR_ANCHOR)
    return "\n".join(lines[:idx] + [bar, ""] + lines[idx:])


def files() -> list[tuple[str, Path]]:
    return [("en", README)] + [(c, translation_path(c)) for c in LANGS if translation_path(c).exists()]


def refresh() -> int:
    for code, path in files():
        text = path.read_text(encoding="utf-8")
        new = with_bar(text, bar_for(code), code == "en")
        if new != text:
            path.write_text(new, encoding="utf-8")
            print(f"updated {path.relative_to(ROOT)}")
    return 0


def outside_code(text: str) -> str:
    """Text with fenced code blocks and inline code removed (links there are not links)."""
    out, fenced = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            out.append(re.sub(r"`[^`]*`", "", line))
    return "\n".join(out)


def broken_links(path: Path, is_root: bool) -> list[str]:
    bad = []
    for m in LINK_RE.finditer(outside_code(path.read_text(encoding="utf-8"))):
        target = m.group(1) or m.group(2)
        if re.match(r"^[a-z][a-z0-9+.-]*:", target):  # http:, https:, mailto:
            continue
        if target.startswith("#"):
            if not is_root:  # headings are translated, so in-page anchors cannot be trusted
                bad.append(f"{target} (in-page anchor; link ../README.md{target} instead)")
            continue
        rel = target.split("#", 1)[0]
        if not (path.parent / rel).exists():
            bad.append(target)
    return bad


def normalized(text: str) -> str:
    """The English README minus the lines that change without the prose changing (bar, version badge)."""
    kept = "\n".join(l for l in text.split("\n") if not l.startswith(BAR_PREFIX) and VERSION_BADGE not in l)
    return re.sub(r"\n{3,}", "\n\n", kept).strip()


def git_show(commit: str) -> str | None:
    r = subprocess.run(["git", "show", f"{commit}:README.md"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def check() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    english = normalized(README.read_text(encoding="utf-8"))
    for code in LANGS:
        if not translation_path(code).exists():
            errors.append(f"missing translation {translation_path(code).relative_to(ROOT)}")
    for code, path in files():
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        bars = [l for l in text.split("\n") if l.startswith(BAR_PREFIX)]
        if not bars:
            errors.append(f"{rel}: no language bar")
        elif bars != [bar_for(code)]:
            errors.append(f"{rel}: language bar stale or duplicated (run python3 scripts/i18n-readme.py)")
        for link in broken_links(path, code == "en"):
            errors.append(f"{rel}: broken relative link {link}")
        if code == "en":
            continue
        m = SOURCE_RE.match(text)
        if not m:
            errors.append(f"{rel}: first line must be <!-- i18n-source: <commit> -->")
            continue
        old = git_show(m.group(1))
        if old is None:
            warnings.append(f"{rel}: source commit {m.group(1)} not in this checkout, staleness unknown")
        elif normalized(old) != english:
            warnings.append(f"{rel}: stale, English README changed since {m.group(1)[:7]}")
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"i18n-readme check: {len(LANGS)} languages, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


def source() -> int:
    """The English README as a translation source for a file living in i18n/."""
    commit = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", "README.md"], cwd=ROOT, capture_output=True, text=True
    ).stdout.strip()
    out = []
    for line in README.read_text(encoding="utf-8").split("\n"):
        if VERSION_BADGE in line:
            continue
        out.append(line)
    text = "\n".join(out)

    def fix(m: re.Match[str]) -> str:
        target = m.group(1) or m.group(2)
        if re.match(r"^[a-z][a-z0-9+.-]*:", target):
            return m.group(0)
        new = "../README.md" + target if target.startswith("#") else os.path.normpath("../" + target)
        if target.endswith("/") and not new.endswith("/"):
            new += "/"
        return m.group(0).replace(target, new, 1)

    print(f"<!-- i18n-source: {commit} -->")
    print(LINK_RE.sub(fix, text), end="")
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "refresh"
    if cmd == "refresh":
        return refresh()
    if cmd == "check":
        return check()
    if cmd == "source":
        return source()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
