# apfel routines - operator guide

This directory holds the **prompt templates** for Anthropic Claude Code routines that act on the apfel repo. Each routine's live configuration lives in [claude.ai/code/routines](https://claude.ai/code/routines) against Franz's Max 20x account, but the prompt text is version-controlled here so any change goes through the same review process as code.

## What routines are (and are not)

**Are:** scheduled / webhook-triggered Claude Code agents on Anthropic's Linux cloud, with access to the apfel repo via a Claude GitHub App install.

**Are not:** replacements for CI, for `make preflight`, or for Franz's merge/release authority. They cannot run FoundationModels code, cannot do functional tests, cannot merge PRs, cannot cut releases, cannot touch any distribution channel. See [docs/routines.md](../../docs/routines.md) for the user-facing version of this line.

## File layout

| File | Role |
|---|---|
| `_golden-goal.md` | Canonical prefix inlined at the top of every live routine prompt. Contains golden goal, hard guardrails, environmental reality, tone. |
| `NN-<name>.md` | One routine. Trigger description + task instructions. The live claude.ai prompt = `_golden-goal.md` inlined + this file appended. |
| `README.md` | This file. Operator guide. |

## The `@include` pattern

The file `_golden-goal.md` is referenced by every routine. claude.ai doesn't natively support includes, so the mechanism is manual:

1. Edit `_golden-goal.md` and the routine's own prompt file here in repo
2. Commit + push
3. In claude.ai, paste the concatenation: contents of `_golden-goal.md`, a divider line (`---`), then the routine file's body (skipping the trigger metadata at the top)

If you update `_golden-goal.md`, you must re-paste into **every** live routine. This is a feature - it forces the operator to notice a global change.

## Setting up a new routine

1. Confirm the routine's prompt is committed to this directory and reviewed (same bar as code).
2. Ensure the Claude GitHub App is installed on `Arthur-Ficial/apfel` **only**, with minimum permissions: Contents (Read), Issues (Read + Write), Pull requests (Read + Write). Verify it is NOT on `Arthur-Ficial/homebrew-tap` or any release-side repo.
3. Go to [claude.ai/code/routines](https://claude.ai/code/routines) → New routine.
4. Name it exactly as the filename minus extension (`02-pr-auto-review`).
5. Trigger: the GitHub trigger described at the top of the routine file.
6. Prompt: `_golden-goal.md` body + `---` + routine file body (excluding the trigger frontmatter).
7. Save, enable.
8. Run the synthetic test described in the phase's verification criteria (see the plan file).
9. Watch the first few real runs in claude.ai's run history. If any run violates a guardrail, disable immediately.

## Disabling / killing a routine

Three ways, in descending preference:

1. **Disable in claude.ai** - instant, reversible. Preferred.
2. **Uninstall the Claude GitHub App from apfel** - revokes access entirely. Nuclear option.
3. **Revoke the fine-grained PATs** related to the routine - same effect.

After disabling a misbehaving routine, file an issue on `Arthur-Ficial/apfel` describing: what triggered the run, what the routine did wrong, the run ID from claude.ai, and the prompt change needed to prevent recurrence.

## Tuning a routine's prompt

1. Edit the routine file in this directory.
2. Commit (subject: `routines: tune <routine-name> - <reason>`).
3. Push to main.
4. In claude.ai, replace the live prompt with the re-concatenated version.
5. Document the change in the commit message body so the reason survives.

Never edit the live prompt in claude.ai without also updating this directory. Drift between the committed template and the live prompt defeats the version-control story.

## Auditing past runs

- claude.ai → Code → Routines → click routine → Run history
- Each run has a session URL; clicking it shows the full transcript
- Cross-reference routine runs against PR review IDs via `gh api repos/Arthur-Ficial/apfel/pulls/<n>/reviews`

## Budget

Max 20x plan: 15 routine runs per day. Webhook routines only burn budget when events fire. Realistic daily load for apfel based on current issue/PR volume: ~1-5 runs. We are comfortably under the cap.

## Current phase rollout

- **Phase 1 - live:** `02-pr-auto-review.md` - first responder on every PR.
- **Phase 2 - live:** `01-issue-triage.md` - first responder on every issue. Applies `bug` label which triggers #5.
- **Phase 3 - live:** `04-dist-channel-watch.md` - weekly Monday check of homebrew-core sync.
- **Bug solver - live:** `05-bug-solver.md` - fires on issues labeled `bug` or on `@Arthur-Ficial investigate` comments from Franz/Arthur. Drafts a fix PR.
- **Deferred indefinitely:** `03-first-time-ci.md` (folded into #2), `stale-sweep`, `post-release-verify` (already covered by `scripts/post-release-verify.sh`).

## Pipeline

```
issue opened
    |
    v
[#1 triage] -- classifies, labels, comments --
    |
    | (if label=bug applied)
    v
[#5 bug-solver] -- investigates, drafts PR --
    |
    v
(PR opened)
    |
    v
[#2 pr-auto-review] -- security audit, COMMENTED review --
    |
    v
Franz reviews, tests locally, merges.
```

Scheduled Monday: `[#4 dist-watch]` - independent, opens an issue if channels lag.

## Hard rule

If any routine run ever does something on this list, disable the routine IMMEDIATELY and file a P0 issue:

- Clicks `gh pr review --approve` or `gh pr merge`
- Pushes a commit to `main`
- Runs `make release`, creates a GitHub Release, or pushes a git tag
- Touches `Arthur-Ficial/homebrew-tap` or `NixOS/nixpkgs`
- Modifies `.version`, `Sources/BuildInfo.swift`, or the README badge directly
- Attempts any action that would change what end users install via Homebrew or Nix

The guardrails in `_golden-goal.md` are not suggestions. They are the product.
