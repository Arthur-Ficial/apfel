# Install with Homebrew

`apfel` is available in `homebrew-core`:

```bash
brew install apfel
```

Verify the install:

```bash
apfel --version
apfel --release
```

## Requirements

- Apple Silicon
- macOS 26.4 or newer
- Apple Intelligence enabled

Homebrew installs the `apfel` binary. You do **not** need Xcode.

## Troubleshooting

If the binary runs but generation is unavailable, check:

```bash
apfel --model-info
```

If you already installed `apfel` manually into `/usr/local/bin/apfel`, make sure the Homebrew binary is first in your `PATH`:

```bash
which apfel
brew --prefix
```

## Maintainers

See [release.md](release.md) for the release workflow.
