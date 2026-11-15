# Routine #4 - Distribution-channel sync watch

**Triggers:** Scheduled, Mondays 09:00 UTC.
**Runs on:** Anthropic cloud (Linux, no Apple Intelligence).
**Status:** Phase 4 - script-driven.

When pasting this prompt into claude.ai, prepend `_golden-goal.md` verbatim, then append everything below the dividing line.

---

(paste `_golden-goal.md` above this line)

---

## Your job

Decide whether to open / comment / skip a `dist-sync` issue on `Arthur-Ficial/apfel`, based on the deterministic output of `scripts/dist-watch.sh`.

**You do not check channel versions yourself.** The script does that. You do not look up in-flight bump PRs yourself. The script does that. You do not write the issue body. The script does that. Your only job is to call `gh` correctly based on the script's three output modes.

This routine used to be a long narrative prompt that asked you to fetch URLs, parse versions, search PRs, and decide. That structure failed on 2026-05-18 when you skipped the in-flight-PR guard and filed a false-alarm issue #154 against a channel lag that was already covered by upstream PR #520183. The work was moved into a shell script so the decision is deterministic; your job is just to act on its output.

## The one command

```bash
body=$(./scripts/dist-watch.sh)
```

The script's exit code and stdout determine what you do next. Three cases:

### Case A - script exits non-zero

Hard failure (network, missing tool). Do not open or comment on anything. Exit clean. Next Monday will try again.

### Case B - script exits 0 with no stdout

All channels in sync, or the lag is covered by an in-flight upstream bump PR, or the canonical release is younger than the 48h grace window. **Do nothing.** No issue, no comment, no log line. Exit clean.

This is the case that misfired in #154. It must misfire as silence, not as a ticket.

### Case C - script exits 0, stdout starts with `STILL: `

A `dist-sync` issue is already open for the current canonical version and the lag hasn't cleared. **Comment on the existing issue, do not open a new one.**

Parse the issue number from the line (`STILL: dist-sync issue #N is still open ...`) and post:

```bash
issue_num=$(echo "$body" | sed -nE 's/STILL: dist-sync issue #([0-9]+).*/\1/p')
today=$(date -u +%Y-%m-%d)
gh issue comment "$issue_num" --repo Arthur-Ficial/apfel --body "Still not in sync as of ${today}. No action taken on my end.

Cheers, Arthur"
```

### Case D - script exits 0, stdout is a full markdown issue body

Real lag, no existing tracker issue. **Open one new issue.** Title format is fixed; body comes verbatim from the script.

```bash
canonical=$(gh release view --repo Arthur-Ficial/apfel --json tagName --jq '.tagName | sub("^v"; "")')
hours=$(echo "$body" | grep -oE '~[0-9]+h' | head -1 | tr -d '~h')
channels=$(echo "$body" | head -1 | sed -E 's/.*looks like (.*) trailing.*/\1/')

gh issue create --repo Arthur-Ficial/apfel \
  --title "dist-sync: ${channels} behind v${canonical} by ~${hours}h" \
  --body "$body"
```

## Hard limits

- **Never** edit the body. The script wrote it. If it looks wrong, that is a script bug and the routine should open a meta-issue against the script instead of patching prose on the fly.
- **Never** run `brew bump-formula-pr`, or push to `Arthur-Ficial/homebrew-tap` from the routine.
- **Never** close any issue.
- **Never** invent advice that isn't in the script's template. If the user sees stale workflow names or made-up fix commands, it is because you ignored this rule.
- The routine has no fallback "compose the body yourself if the script is unhappy". If the script is unhappy, that is Case A - exit clean.

## Exit criteria

Exactly one of:
- Case A (script failed): no side effects, exit clean.
- Case B (no lag): no side effects, exit clean.
- Case C (already tracked): one comment on the existing issue, exit clean.
- Case D (new lag): one new issue opened, exit clean.

Anything else - including a second comment, a second issue, an edit to the formula, a touch on the bump script, or any output to the user - is a routine failure.
