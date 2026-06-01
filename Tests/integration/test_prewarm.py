"""
apfel Integration Tests - prewarm() integration hygiene.

Verifies that LanguageModelSession.prewarm() is wired into both the CLI
and server startup paths, guarded behind model availability.  These are
source-level structural checks - functional verification requires a local
test run on a Mac with Apple Intelligence.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = ROOT / "Sources"


def _read(name: str) -> str:
    return (SOURCES / name).read_text()


# -- TokenCounter: prewarm method exists and guards behind availability ------

def test_token_counter_has_prewarm_method():
    """TokenCounter must expose a prewarm() method."""
    src = _read("TokenCounter.swift")
    assert "func prewarm()" in src, (
        "TokenCounter.swift is missing func prewarm(). "
        "The model should be prewarmed via TokenCounter.shared.prewarm()."
    )


def test_prewarm_guards_behind_availability():
    """prewarm() must check isAvailable before calling LanguageModelSession.prewarm()."""
    src = _read("TokenCounter.swift")
    guard_pos = src.find("guard isAvailable")
    call_pos = src.find("LanguageModelSession.prewarm()")
    assert guard_pos != -1, "prewarm() must guard behind isAvailable"
    assert call_pos != -1, "prewarm() must call LanguageModelSession.prewarm()"
    assert guard_pos < call_pos, (
        "The availability guard must come before the prewarm() call"
    )


# -- Server: prewarm at startup ---------------------------------------------

def test_server_calls_prewarm_at_startup():
    """startServer() must call prewarm() before setting up routes."""
    src = _read("Server.swift")
    assert "prewarm()" in src, (
        "Server.swift must call prewarm() during startup so the first "
        "/v1/chat/completions request does not pay cold-start latency."
    )


def test_server_prewarm_after_property_prefetch():
    """prewarm() should come after the property pre-fetch (contextSize, supportedLanguages)."""
    src = _read("Server.swift")
    prefetch_pos = src.find("cachedLangs")
    prewarm_pos = src.find("prewarm()")
    router_pos = src.find("let router = Router()")
    assert prefetch_pos < prewarm_pos < router_pos, (
        "prewarm() must sit between the property pre-fetch and the router setup"
    )


# -- CLI: prewarm for inference modes ----------------------------------------

def test_main_calls_prewarm_for_inference_modes():
    """main.swift must call prewarm() for modes that use the model."""
    src = _read("main.swift")
    assert "TokenCounter.shared.prewarm()" in src, (
        "main.swift must call TokenCounter.shared.prewarm() for CLI inference modes."
    )


def test_main_prewarm_covers_all_inference_modes():
    """The prewarm switch must cover single, stream, chat, and benchmark."""
    src = _read("main.swift")
    # Find the prewarm switch block
    match = re.search(
        r"case\s+\.single.*?\.stream.*?\.chat.*?\.benchmark.*?prewarm\(\)",
        src,
        re.DOTALL,
    )
    assert match is not None, (
        "The prewarm call must be guarded by a switch covering "
        ".single, .stream, .chat, and .benchmark"
    )


def test_main_prewarm_before_mcp_init():
    """prewarm() should run before MCP servers are initialized."""
    src = _read("main.swift")
    prewarm_pos = src.find("TokenCounter.shared.prewarm()")
    mcp_pos = src.find("MCPManager(paths:")
    assert prewarm_pos < mcp_pos, (
        "prewarm() must run before MCP initialization so the model "
        "is loading while MCP servers start up"
    )
