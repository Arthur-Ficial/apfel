// ============================================================================
// FinishReasonResolverTests.swift — Unit tests for the pure decision logic
// that selects the OpenAI finish_reason ("stop" | "length" | "tool_calls").
// ============================================================================

import Foundation
import ApfelCore

func runFinishReasonResolverTests() {
    test("no tool calls, no max tokens -> stop") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: false, completionTokens: 100, maxTokens: nil)
        try assertEqual(r, .stop)
    }

    test("no tool calls, completion < max -> stop") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: false, completionTokens: 50, maxTokens: 100)
        try assertEqual(r, .stop)
    }

    test("no tool calls, completion == max -> length") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: false, completionTokens: 100, maxTokens: 100)
        try assertEqual(r, .length)
    }

    test("no tool calls, completion > max -> length") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: false, completionTokens: 250, maxTokens: 100)
        try assertEqual(r, .length)
    }

    test("tool calls present -> tool_calls (overrides length)") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: true, completionTokens: 999, maxTokens: 100)
        try assertEqual(r, .toolCalls)
    }

    test("tool calls present, no max -> tool_calls") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: true, completionTokens: 10, maxTokens: nil)
        try assertEqual(r, .toolCalls)
    }

    test("openAI string mapping is canonical") {
        try assertEqual(FinishReason.stop.openAIValue, "stop")
        try assertEqual(FinishReason.length.openAIValue, "length")
        try assertEqual(FinishReason.toolCalls.openAIValue, "tool_calls")
    }

    test("zero completion tokens with max set -> stop (not length)") {
        let r = FinishReasonResolver.resolve(
            hasToolCalls: false, completionTokens: 0, maxTokens: 100)
        try assertEqual(r, .stop)
    }
}
