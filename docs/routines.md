# Routines

apfel uses Anthropic Claude Code **routines** - scheduled or webhook-triggered Claude Code sessions that run on Anthropic's cloud infrastructure - to handle first-responder tasks on GitHub issues and pull requests.

## What you'll see

If you open an issue or a pull request against `Arthur-Ficial/apfel`, a Claude-Code-driven automated reviewer may comment before a human does. Those comments:

- Say they are automated at the top and bottom
- Always cc @franzenzenhofer
- Will not close your issue, will not merge your PR, will not approve your PR code
- Focus on applying our published "Handling Issues" / "Handling Pull Requests" process from [CLAUDE.md](../CLAUDE.md)

If anything the routine says is wrong, unclear, or comes across poorly - that's on us. Reply on the issue/PR and @franzenzenhofer will take a look.

## What routines cannot do

Routines run on Anthropic's Linux cloud runners, so they cannot:

- Run `make test`, `make preflight`, `swift build`, or any integration test that needs Apple Intelligence (there is no Apple Intelligence on Linux)
- Test the actual behavior of code changes - only static review (style, structure, test coverage, security audit)
- Merge a PR, approve a PR, cut a release, or update any distribution channel (Homebrew, nixpkgs, tap)
- Change what you install via `brew install apfel` or `nix profile install nixpkgs#apfel-ai`

Every code-PR review from a routine contains an explicit note that functional correctness was **not** verified and that @franzenzenhofer needs to run tests locally before merging.

## Why we use them

- Faster first response on issues and PRs - especially for first-time contributors
- Consistent application of the security audit checklist
- Free the human reviewer to focus on judgment calls (architecture, release timing, breaking-change decisions)

## How to opt out

If you'd prefer a human-only review on a specific PR, add the comment `cc @franzenzenhofer please review without the routine` and we'll disable routines for that PR. For issues, simply tag @franzenzenhofer in the body and we'll skip the auto-triage.

## Technical details

For the operator-level guide - how prompts are version-controlled, how kill-switches work, how to audit past runs - see [.claude/routines/README.md](../.claude/routines/README.md). For the list of prompt templates, see the files in that directory.

## Phased rollout status

| Phase | Routine | Status |
|---|---|---|
| 1 | PR auto-review | **Live** (see `.claude/routines/02-pr-auto-review.md`) |
| 2 | Issue triage | Deferred until Phase 1 has 3 consecutive quality reviews |
| 3 | Distribution-channel sync watch | Deferred until Phase 2 is stable |
| - | Stale issue sweep, first-time CI approval as standalone, post-release verify | Not planned |

## Status

Phase 1 went live 2026-04-14.

## Security note

The Claude GitHub App is installed on `Arthur-Ficial/apfel` **only**, with minimum GitHub permissions: Contents (Read), Issues (Read + Write), Pull requests (Read + Write). It is explicitly NOT installed on `Arthur-Ficial/homebrew-tap`, `Arthur-Ficial/nixpkgs`, or `NixOS/nixpkgs` - those are release-side repos and routines must never reach them.
