# Install — Detailed Guide

## Requirements

| Requirement | Details |
|-------------|---------|
| **Mac** | Apple Silicon |
| **macOS** | **macOS 26.4** or later |
| **Apple Intelligence** | Must be [enabled in System Settings](https://support.apple.com/en-us/121115) |

## Option 1: Homebrew (recommended)

```bash
brew tap Arthur-Ficial/tap
brew install Arthur-Ficial/tap/apfel
```

No build tools needed. See [brew-install.md](brew-install.md) for troubleshooting.

## Option 2: Build from source

Requires Swift 6.2+ with developer tools that include the **macOS 26.4 SDK**. Xcode is **not** required — Command Line Tools are enough.

```bash
git clone https://github.com/Arthur-Ficial/apfel.git
cd apfel
make install
```

`make install` auto-bumps the version, builds a release binary, and installs to `/usr/local/bin/apfel`.

### Verify your toolchain

```bash
# Check macOS version (needs 26+)
sw_vers

# Check Swift is installed
swift --version

# Check the active Apple SDK version (must be 26.4+)
xcrun --show-sdk-version

# If Swift is missing, install Command Line Tools:
xcode-select --install
```

### Troubleshooting build errors

If `make install` fails with:

```text
value of type 'SystemLanguageModel' has no member 'tokenCount'
value of type 'SystemLanguageModel' has no member 'contextSize'
```

Your selected Command Line Tools are older than the macOS 26.4 SDK. Fix:

```bash
# update/install Command Line Tools
xcode-select --install

# ensure the CLT developer dir is selected
sudo xcode-select -s /Library/Developer/CommandLineTools

# confirm the active SDK is new enough
xcrun --show-sdk-version

# retry
make install
```

`xcrun --show-sdk-version` must print `26.4` or newer.

## Verify

```bash
apfel "Hello, world!"
apfel --version
apfel --release       # full build info
```

## Errors
If you get this error, "error: Apple Intelligence is not enabled or model is not ready. Run: apfel --model-info", check to see that you have Apple Intelligence enabled. (System Settings GUI (Apple menu > System Settings > Apple Intelligence & Siri))


