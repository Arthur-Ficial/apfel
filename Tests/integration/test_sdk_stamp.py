"""The binary's SDK stamp must not depend on the build system (#521).

The macOS 27 runtime decides typed LanguageModelError (context-window numbers,
Retry-After) and other 27 behaviour by the binary's LC_BUILD_VERSION sdk.
SwiftPM's default build system stamps sdk 26.0 even when building on the
macOS 27 SDK - homebrew-core's bottle for 1.16.0 measured `minos 26.0 sdk
26.0` - while `make build` (native build system) stamps 27.0. Package.swift
pins the stamp with a linker flag; it must stay equal to the minimum SDK that
check-toolchain enforces, and the floor must stay macOS 26.

Pure source scan, model-free.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).parents[2]


def _pin():
    text = (ROOT / "Package.swift").read_text()
    m = re.search(
        r'"-Xlinker", "-platform_version",\s*"-Xlinker", "macos",\s*'
        r'"-Xlinker", "([0-9.]+)",\s*"-Xlinker", "([0-9.]+)"', text)
    assert m, "Package.swift must pin -platform_version macos <floor> <sdk> for the apfel executable (#521)"
    return m.group(1), m.group(2)


def test_platform_version_pin_keeps_the_macos_26_floor():
    floor, _ = _pin()
    assert floor == "26.0", f"deployment floor must stay macOS 26.0 (#205), got {floor}"


def test_pinned_sdk_matches_the_check_toolchain_minimum():
    _, sdk = _pin()
    makefile = (ROOT / "Makefile").read_text()
    m = re.search(r'"\$\$major" -lt (\d+)', makefile)
    assert m, "check-toolchain SDK guard not found"
    assert sdk.split(".")[0] == m.group(1), (
        f"Package.swift stamps sdk {sdk} but check-toolchain requires SDK {m.group(1)}+; raise both together")
