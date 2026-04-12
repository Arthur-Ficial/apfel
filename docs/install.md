# Install — Detailed Guide

## Requirements

| Requirement | Details |
|-------------|---------|
| **Mac** | Apple Silicon |
| **macOS** | **macOS 26.4** or later |
| **Apple Intelligence** | Must be [enabled in System Settings](https://support.apple.com/en-us/121115) |

## Option 1: Homebrew (recommended)

```bash
brew install apfel
```

No build tools needed. See [brew-install.md](brew-install.md) for troubleshooting.

## Option 2: Build from source

Requires Swift 6.3+ with developer tools that include the **macOS 26.4 SDK**. Xcode is **not** required - Command Line Tools are enough.

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

## Alternative install methods

### Mint

```bash
mint install Arthur-Ficial/apfel
```

### mise

```bash
mise use -g github:Arthur-Ficial/apfel
```

Supports project-scoped installs (`mise use github:Arthur-Ficial/apfel` without `-g`). Installs directly from GitHub releases.

## Verify

```bash
apfel 'Hello, world!'
apfel --version
apfel --release       # full build info
```

## Troubleshooting: "Model unavailable"

If `apfel --model-info` shows `available: no`, the specific reason is printed alongside it. There are three possible causes, all from Apple's FoundationModels framework:

| Reason | What it means | Fix |
|---|---|---|
| **Apple Intelligence not enabled** | The toggle is off, or your device language and Siri language do not match, or Siri is set to an unsupported language | **System Settings > Apple Intelligence & Siri** → turn on. Ensure **Device Language** and **Siri Language** are set to the SAME supported language (English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Chinese Simplified/Traditional, Japanese, Korean, Vietnamese). |
| **Device not eligible** | Intel Mac, or Mac older than M1 | Apple Silicon (M1 or later) is required. This is a hard Apple requirement - there is no workaround. |
| **Model not ready** | On-device model is still downloading (~3-4 GB on first enable) | Keep your Mac on **Wi-Fi and power**. Check download progress in System Settings > Apple Intelligence & Siri. Try again in a few minutes. |

apfel is a thin wrapper around Apple's on-device model — it cannot turn on Apple Intelligence for you. Once the underlying Apple toggle is on and models are downloaded, apfel just works.

Apple's full Apple Intelligence setup guide: [support.apple.com/en-us/121115](https://support.apple.com/en-us/121115)

Geographic note: Apple Intelligence is blocked in **China mainland** (both device purchase location and Apple Account Country/Region matter). Hong Kong, EU, and most other regions are supported as of macOS 26.1.
