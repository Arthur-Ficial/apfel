// ============================================================================
// ServedModelTests.swift - the server's model registry (follow-up to #170):
// `apple-foundationmodel` (general, the default) and
// `apple-foundationmodel-content-tagging` (SystemLanguageModel.UseCase
// .contentTagging). Covers id resolution, the use-case mapping, the
// per-model tool policy, and how the chat, Responses and input-token
// validators accept or reject each id.
//
// Probe on macOS 26.7.3 (2026-11-16): the tagging adapter reports the same runtime
// context window as the general model, follows guided generation, and never calls a tool (asked
// to, it emits a tag such as "time inquiry"), hence tools are rejected for it.
// ============================================================================

import Foundation
import ApfelCore
import ApfelEngine

func runServedModelTests() {

    let general = "apple-foundationmodel"
    let tagging = "apple-foundationmodel-content-tagging"

    func chat(_ json: String) throws -> ChatCompletionRequest {
        try JSONDecoder().decode(ChatCompletionRequest.self, from: Data(json.utf8))
    }
    func responses(_ json: String) throws -> ResponsesRequest {
        try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
    }

    // MARK: - Registry

    test("served model ids are stable and general is the default") {
        try assertEqual(ServedModel.general.rawValue, general)
        try assertEqual(ServedModel.contentTagging.rawValue, tagging)
        try assertEqual(ServedModel.default, .general)
        try assertEqual(ServedModel.allCases.map(\.rawValue), [general, tagging])
    }

    test("resolve maps known ids and rejects everything else") {
        try assertEqual(ServedModel.resolve(general), .general)
        try assertEqual(ServedModel.resolve(tagging), .contentTagging)
        try assertNil(ServedModel.resolve("gpt-5"))
        try assertNil(ServedModel.resolve(""))
        try assertNil(ServedModel.resolve("APPLE-FOUNDATIONMODEL"))
    }

    test("each served model maps to its SystemLanguageModel use case") {
        try assertEqual(ServedModel.general.useCase, .general)
        try assertEqual(ServedModel.contentTagging.useCase, .contentTagging)
    }

    test("only the general model supports tool calling") {
        try assertTrue(ServedModel.general.supportsTools)
        try assertTrue(!ServedModel.contentTagging.supportsTools)
    }

    test("available ids are listed for error messages") {
        try assertEqual(ServedModel.availableList, "'\(general)', '\(tagging)'")
    }

    test("tagging model advertises no tool parameters in /v1/models") {
        try assertTrue(ServedModel.general.supportedParameters.contains("tools"))
        try assertTrue(ServedModel.general.supportedParameters.contains("tool_choice"))
        let taggingParams = ServedModel.contentTagging.supportedParameters
        try assertTrue(!taggingParams.contains("tools"))
        try assertTrue(!taggingParams.contains("tool_choice"))
        try assertTrue(!taggingParams.contains("parallel_tool_calls"))
        try assertTrue(taggingParams.contains("response_format"))
        try assertTrue(ServedModel.contentTagging.notes.contains("content-tagging"))
    }

    test("tagging model drops tool_calling from the reported capabilities") {
        let reported = ["tool_calling", "guided_generation", "vision"]
        try assertEqual(ServedModel.general.capabilities(from: reported), reported)
        try assertEqual(ServedModel.contentTagging.capabilities(from: reported), ["guided_generation", "vision"])
    }

    // MARK: - Chat completions validator

    test("chat validator accepts both served model ids") {
        try assertNil(ChatRequestValidator.validate(try chat(
            #"{"model":"\#(general)","messages":[{"role":"user","content":"hi"}]}"#)))
        try assertNil(ChatRequestValidator.validate(try chat(
            #"{"model":"\#(tagging)","messages":[{"role":"user","content":"hi"}]}"#)))
    }

    test("chat validator 404s an unknown model and lists every served id") {
        let failure = ChatRequestValidator.validate(try chat(
            #"{"model":"gpt-5","messages":[{"role":"user","content":"hi"}]}"#))
        try assertEqual(failure, .invalidModel("gpt-5"))
        try assertEqual(failure?.httpStatusCode, 404)
        try assertEqual(failure?.errorCode, "model_not_found")
        try assertEqual(
            failure?.message,
            "The model 'gpt-5' does not exist. Available models: '\(general)', '\(tagging)'.")
    }

    test("chat validator rejects client tools for the tagging model") {
        let failure = ChatRequestValidator.validate(try chat(#"""
            {"model":"\#(tagging)","messages":[{"role":"user","content":"hi"}],
             "tools":[{"type":"function","function":{"name":"f","parameters":{"type":"object"}}}]}
            """#))
        try assertEqual(failure?.httpStatusCode, 400)
        try assertTrue(failure?.message.contains("'tools'") == true)
        try assertTrue(failure?.message.contains(tagging) == true)
    }

    test("chat validator still accepts client tools for the general model") {
        try assertNil(ChatRequestValidator.validate(try chat(#"""
            {"model":"\#(general)","messages":[{"role":"user","content":"hi"}],
             "tools":[{"type":"function","function":{"name":"f","parameters":{"type":"object"}}}]}
            """#)))
    }

    test("chat validator accepts an empty tools array for the tagging model") {
        try assertNil(ChatRequestValidator.validate(try chat(
            #"{"model":"\#(tagging)","messages":[{"role":"user","content":"hi"}],"tools":[]}"#)))
    }

    // MARK: - Responses validator

    test("responses validator accepts both served model ids") {
        try assertNil(ResponsesRequestValidator.validate(try responses(
            #"{"model":"\#(general)","input":"hi"}"#)))
        try assertNil(ResponsesRequestValidator.validate(try responses(
            #"{"model":"\#(tagging)","input":"hi"}"#)))
    }

    test("responses validator 404s an unknown model and lists every served id") {
        let failure = ResponsesRequestValidator.validate(try responses(
            #"{"model":"gpt-4o","input":"hi"}"#))
        try assertEqual(failure, .invalidModel("gpt-4o"))
        try assertEqual(
            failure?.message,
            "Model 'gpt-4o' not found. Available models: '\(general)', '\(tagging)'.")
    }

    test("responses validator rejects function tools for the tagging model") {
        let failure = ResponsesRequestValidator.validate(try responses(#"""
            {"model":"\#(tagging)","input":"hi",
             "tools":[{"type":"function","name":"f","parameters":{"type":"object"}}]}
            """#))
        try assertEqual(failure?.httpStatusCode, 400)
        try assertTrue(failure?.message.contains("'tools'") == true)
        try assertTrue(failure?.message.contains(tagging) == true)
    }

    // MARK: - Input-token counting validator

    test("input-token validator accepts both served model ids") {
        try assertNil(ResponsesInputTokensValidator.validate(
            try responses(#"{"model":"\#(general)","input":"hi"}"#),
            presentKeys: ["model", "input"]))
        try assertNil(ResponsesInputTokensValidator.validate(
            try responses(#"{"model":"\#(tagging)","input":"hi"}"#),
            presentKeys: ["model", "input"]))
    }

    // MARK: - Session options (ApfelEngine)

    test("session options default to the general use case") {
        try assertEqual(SessionOptions.defaults.useCase, .general)
    }

    test("session options carry the tagging use case when asked") {
        let opts = SessionOptions(
            temperature: nil, topP: nil, maxTokens: nil, seed: nil,
            permissive: false, contextConfig: .defaults,
            retryEnabled: false, retryCount: 3, useCase: .contentTagging)
        try assertEqual(opts.useCase, .contentTagging)
    }
}
