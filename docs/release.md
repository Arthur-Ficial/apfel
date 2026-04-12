# Release & Homebrew Packaging

## How releases work

The `Publish Release` GitHub Actions workflow handles everything:

1. Bumps `.version` (patch, minor, or major)
2. Reuses existing `make build` / `make release-minor` / `make release-major` targets
3. Builds the release binary on `macos-26`
4. Regenerates `Sources/BuildInfo.swift` and updates the README version badge
5. Commits the release files and pushes the Git tag
6. Publishes `apfel-<version>-arm64-macos.tar.gz` on GitHub Releases

## Publishing a release

1. Open **Actions** in `Arthur-Ficial/apfel`
2. Run **Publish Release**
3. Choose `patch`, `minor`, or `major`

## Validation

After the workflow completes:

```bash
brew update
brew reinstall apfel
brew test apfel
brew audit --strict apfel
```

## Local builds

`make build` and `make install` still handle the normal auto-version bump and local release build.
