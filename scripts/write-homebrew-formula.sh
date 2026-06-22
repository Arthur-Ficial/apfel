#!/usr/bin/env bash

set -euo pipefail

version=""
sha256=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha256="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" || -z "$sha256" || -z "$output" ]]; then
  echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
  exit 1
fi

cat > "$output" <<EOF
class Apfel < Formula
  desc "On-device Apple FoundationModels CLI and OpenAI-compatible server"
  homepage "https://github.com/Arthur-Ficial/apfel"
  url "https://github.com/Arthur-Ficial/apfel/releases/download/v${version}/apfel-${version}-arm64-macos.tar.gz"
  sha256 "${sha256}"
  license "MIT"

  depends_on arch: :arm64
  # macOS-only hard block. Unlike homebrew-core's formula (which builds from
  # source and has \`depends_on xcode: [..., :build]\`, naturally excluding Linux),
  # this tap installs a prebuilt macOS binary with no xcode build-dep. A bare
  # top-level \`depends_on :macos\` is the only thing that hard-blocks Linux: a
  # versioned \`depends_on macos: :tahoe\` is auto-satisfied on Linux (brew shows
  # "macOS >= 26 (or Linux)"), so an arm64 Linux host would otherwise install a
  # non-functional macOS binary. The macOS version floor still has to be enforced,
  # so it lives inside \`on_macos\`: combining a top-level bare \`depends_on :macos\`
  # with a top-level \`depends_on macos:\` is deprecated and prints a runtime
  # warning on every brew operation that loads the formula.
  depends_on :macos
  on_macos do
    depends_on macos: :tahoe
  end

  def install
    bin.install "apfel"
    man1.install "apfel.1"

    # Ship the demo/ pipe-friendly examples (cmd, explain, gitsum, mac-narrator,
    # naming, oneliner, port, wtd) as apfel-<name> companion commands. The
    # apfel- prefix avoids global PATH collisions ('port' would shadow MacPorts).
    if File.directory?("demo")
      pkgshare.install "demo"
      %w[cmd explain gitsum mac-narrator naming oneliner port wtd].each do |d|
        target = pkgshare/"demo/#{d}"
        next unless target.exist?

        bin.install_symlink target => "apfel-#{d}"
      end
    end
  end

  service do
    run [opt_bin/"apfel", "--serve"]
    keep_alive true
    log_path var/"log/apfel.log"
    error_log_path var/"log/apfel.log"
  end

  def caveats
    s = <<~EOS
      apfel requires:
        - macOS 26 Tahoe or newer (enforced by this formula)
        - Apple Silicon (M1 or later) - Tahoe is Apple Silicon only
        - Apple Intelligence enabled in System Settings > Apple Intelligence & Siri

      Verify everything is ready:
        apfel --model-info

      If the model is unavailable, enable Apple Intelligence:
        https://support.apple.com/en-us/121115

      Companion demo commands (pipe-friendly bash scripts) installed:
        apfel-cmd           natural language -> shell command
        apfel-oneliner      complex awk/sed/find pipe chains
        apfel-explain       explain a command, error, or code snippet
        apfel-wtd           "what's this directory?" project orientation
        apfel-naming        suggest names for functions/variables/classes
        apfel-port          identify the process on a port
        apfel-gitsum        plain-English summary of recent git activity
        apfel-mac-narrator  dry-British-humor system narration
    EOS
    unless Hardware::CPU.arm?
      s += <<~EOS

        Note: Homebrew reports this process as non-arm64. If you are on a real
        Apple Silicon Mac (M1+), apfel will still run - your brew install may
        be running under Rosetta. See:
        https://github.com/Arthur-Ficial/apfel/issues/45
      EOS
    end
    s
  end

  test do
    assert_match "apfel v#{version}", shell_output("#{bin}/apfel --version")
    assert_path_exists man1/"apfel.1"
    assert_path_exists bin/"apfel-cmd"
    assert_predicate bin/"apfel-cmd", :symlink?
  end
end
EOF
