// ============================================================================
// PromptBudgetCheck.swift - when a one-shot CLI prompt is counted exactly
// before generation. Part of ApfelCore.
//
// A one-shot prompt without MCP tools went straight to the model, so an
// oversized prompt was judged by the runtime alone: macOS 27 answered with a
// typed context overflow, but macOS 26.1 rejected "x x x ..." as an
// unsupported language (exit 1) before looking at its size (#544). Counting
// every prompt would cost one tokenizer call per invocation, so only prompts
// that could plausibly reach the budget are counted.
// ============================================================================

public enum PromptBudgetCheck {
    /// True when a prompt of `characters` characters could reach half the
    /// input `budget` at four characters per token (the usual density of
    /// English; denser scripts only make the count smaller per character, and
    /// the check then still runs for anything long).
    public static func needsExactCount(characters: Int, budget: Int) -> Bool {
        guard budget > 0 else { return true }
        return characters >= budget * 2
    }
}
