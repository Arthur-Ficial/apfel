# nixpkgs: retired

apfel is no longer distributed through nixpkgs. This page records why.

## Facts

- On 2026-11-15 a nixpkgs maintainer closed our automated bump PR [NixOS/nixpkgs#565008](https://github.com/NixOS/nixpkgs/pull/565008) under the nixpkgs automation/AI policy: [https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy).
- apfel is developed entirely by AI agents, so it cannot follow that policy.
- We therefore opened [NixOS/nixpkgs#588623](https://github.com/NixOS/nixpkgs/pull/588623) ("apfel-llm: drop") asking nixpkgs to remove the package.
- Until that PR merges, nixpkgs still ships the outdated 1.10.0 as `apfel-llm`. We do not maintain it and do not support it.
- The bump tooling (`scripts/publish-nixpkgs-bump.sh`, `scripts/nixpkgs-bump-cron.sh`, `scripts/bump-nixpkgs.sh`, the launchd job `com.arthurficial.apfel-nixpkgs-bump` and its tests) was removed in the PR "Drop nixpkgs as a distribution channel".

## Install instead

```bash
brew install apfel
```

See [install.md](install.md).
