# Install with Homebrew

`apfel` is available through the `Arthur-Ficial/tap` tap:

```bash
brew tap Arthur-Ficial/tap
brew install apfel
apfel service install
```

Verify the install:

```bash
apfel --version
apfel --release
apfel service status
```

## Requirements

- Apple Silicon
- macOS 26.4 or newer
- Apple Intelligence enabled

Homebrew installs the `apfel` binary. You do **not** need Xcode.

If you want the OpenAI-compatible server to stay up without an open terminal:

```bash
apfel service install
```

Change the port later by re-running install:

```bash
apfel service install --port 11435
```

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

See [release.md](release.md) for the release workflow and Homebrew tap maintenance.
