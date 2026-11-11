// ============================================================================
// PromptBudgetCheckTests.swift - when a one-shot CLI prompt needs an exact
// token count before generation (#544)
// ============================================================================

import Foundation
import ApfelCore

func runPromptBudgetCheckTests() {
    test("ordinary prompts skip the exact count (no extra tokenizer call)") {
        try assertTrue(!PromptBudgetCheck.needsExactCount(characters: 40, budget: 3584))
        try assertTrue(!PromptBudgetCheck.needsExactCount(characters: 6000, budget: 3584))
    }

    test("a prompt that could be near the budget is counted exactly") {
        // 4 characters per token is the usual English density; anything that
        // could reach half the budget is worth one exact count.
        try assertTrue(PromptBudgetCheck.needsExactCount(characters: 7168, budget: 3584))
        try assertTrue(PromptBudgetCheck.needsExactCount(characters: 80000, budget: 3584))
    }

    test("a larger window raises the threshold") {
        try assertTrue(!PromptBudgetCheck.needsExactCount(characters: 10000, budget: 7680))
        try assertTrue(PromptBudgetCheck.needsExactCount(characters: 16000, budget: 7680))
    }

    test("a non-positive budget always counts") {
        try assertTrue(PromptBudgetCheck.needsExactCount(characters: 1, budget: 0))
    }
}
