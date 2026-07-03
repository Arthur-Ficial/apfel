// ============================================================================
// ResponsesModelsTests.swift - Unit tests for the /v1/responses pure layer
// (#365): ResponsesRequest decoding, ResponsesMapper (Responses -> chat
// internals), and ResponsesRequestValidator policy incl. every honest 501.
// ============================================================================

import Foundation
import ApfelCore

private func decodeResponses(_ json: String) throws -> ResponsesRequest {
    try JSONDecoder().decode(ResponsesRequest.self, from: Data(json.utf8))
}

func runResponsesModelsTests() {

    // ========================================================================
    // MARK: - Decoding
    // ========================================================================

    test("decodes a string input") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"hello"}"#)
        try assertEqual(r.model, "apple-foundationmodel")
        guard case .text(let t)? = r.input else { throw TestFailure("expected .text input") }
        try assertEqual(t, "hello")
    }

    test("decodes a message-list input") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":[{"role":"user","content":"hi"}]}"#)
        guard case .items(let items)? = r.input else { throw TestFailure("expected .items input") }
        try assertEqual(items.count, 1)
        try assertEqual(items[0].role, "user")
        try assertEqual(items[0].textContent, "hi")
    }

    test("decodes typed message items with content parts") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":[
          {"type":"message","role":"user","content":[
            {"type":"input_text","text":"line one"},
            {"type":"input_text","text":"line two"}]}]}
        """)
        guard case .items(let items)? = r.input else { throw TestFailure("expected .items input") }
        try assertEqual(items[0].textContent, "line one\nline two")
    }

    test("decodes instructions, sampling params, and metadata") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","instructions":"be terse",
         "temperature":0.5,"top_p":0.9,"max_output_tokens":64,
         "metadata":{"trace":"t1"}}
        """)
        try assertEqual(r.instructions, "be terse")
        try assertEqual(r.temperature, 0.5)
        try assertEqual(r.top_p, 0.9)
        try assertEqual(r.max_output_tokens, 64)
        try assertEqual(r.metadata?["trace"], "t1")
    }

    test("decodes text.format json_schema") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x",
         "text":{"format":{"type":"json_schema","name":"person",
                 "schema":{"type":"object","properties":{"name":{"type":"string"}}}}}}
        """)
        try assertEqual(r.text?.format?.type, "json_schema")
        try assertEqual(r.text?.format?.name, "person")
        try assertTrue(r.text?.format?.schema?.value.contains("\"name\"") == true)
    }

    test("decodes flat Responses function tools") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x",
         "tools":[{"type":"function","name":"add","description":"adds",
                   "parameters":{"type":"object","properties":{"a":{"type":"integer"}}}}]}
        """)
        try assertEqual(r.tools?.count, 1)
        try assertEqual(r.tools?[0].type, "function")
        try assertEqual(r.tools?[0].name, "add")
    }

    test("decodes 501-relevant fields") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x",
         "previous_response_id":"resp_123","background":true,"store":true,
         "include":["output[*]"],"reasoning":{"effort":"low"}}
        """)
        try assertEqual(r.previous_response_id, "resp_123")
        try assertEqual(r.background, true)
        try assertEqual(r.store, true)
        try assertEqual(r.include?.count, 1)
        try assertTrue(r.hasReasoning)
    }

    // ========================================================================
    // MARK: - Mapper
    // ========================================================================

    test("mapper: instructions become a leading system message") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"hi","instructions":"be terse"}"#)
        let msgs = ResponsesMapper.messages(from: r)
        try assertEqual(msgs.count, 2)
        try assertEqual(msgs[0].role, "system")
        try assertEqual(msgs[0].textContent, "be terse")
        try assertEqual(msgs[1].role, "user")
    }

    test("mapper: developer role maps to system") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":[
          {"role":"developer","content":"policy"},{"role":"user","content":"hi"}]}
        """)
        let msgs = ResponsesMapper.messages(from: r)
        try assertEqual(msgs[0].role, "system")
        try assertEqual(msgs[1].role, "user")
    }

    test("mapper: flat tools become nested OpenAI tools") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x",
         "tools":[{"type":"function","name":"add","description":"adds",
                   "parameters":{"type":"object"}}]}
        """)
        let tools = ResponsesMapper.tools(from: r)
        try assertEqual(tools?.count, 1)
        try assertEqual(tools?[0].type, "function")
        try assertEqual(tools?[0].function.name, "add")
        try assertEqual(tools?[0].function.description, "adds")
        try assertTrue(tools?[0].function.parameters?.value.contains("object") == true)
    }

    // ========================================================================
    // MARK: - Validator: 400/404
    // ========================================================================

    test("validator: unknown model is a 404 model_not_found") {
        let r = try decodeResponses(#"{"model":"gpt-4o","input":"x"}"#)
        let f = ResponsesRequestValidator.validate(r)
        try assertEqual(f, .invalidModel("gpt-4o"))
        try assertEqual(f?.httpStatusCode, 404)
        try assertEqual(f?.errorCode, "model_not_found")
        try assertEqual(f?.errorParam, "model")
    }

    test("validator: missing model is a 400") {
        let r = try decodeResponses(#"{"input":"x"}"#)
        let f = ResponsesRequestValidator.validate(r)
        try assertEqual(f, .missingModel)
        try assertEqual(f?.httpStatusCode, 400)
    }

    test("validator: missing input is a 400") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel"}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .missingInput)
    }

    test("validator: empty string input is a 400") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"  "}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .emptyInput)
    }

    test("validator: last input item must be a user turn") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":[
          {"role":"user","content":"hi"},{"role":"assistant","content":"yo"}]}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .invalidLastRole("assistant"))
    }

    test("validator: unknown text.format type is a 400") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","text":{"format":{"type":"yaml"}}}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .invalidTextFormat("yaml"))
    }

    test("validator: json_schema without a schema is a 400") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","text":{"format":{"type":"json_schema","name":"p"}}}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .missingSchema)
    }

    test("validator: out-of-range sampling params are 400s") {
        for json in [
            #"{"model":"apple-foundationmodel","input":"x","temperature":3}"#,
            #"{"model":"apple-foundationmodel","input":"x","top_p":1.5}"#,
            #"{"model":"apple-foundationmodel","input":"x","max_output_tokens":0}"#,
        ] {
            let r = try decodeResponses(json)
            let f = ResponsesRequestValidator.validate(r)
            try assertEqual(f?.httpStatusCode, 400, "expected 400 for \(json)")
        }
    }

    // ========================================================================
    // MARK: - Validator: honest 501s
    // ========================================================================

    test("validator: previous_response_id is a 501 (apfel is stateless)") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","previous_response_id":"resp_1"}"#)
        let f = ResponsesRequestValidator.validate(r)
        try assertEqual(f, .unsupported("previous_response_id"))
        try assertEqual(f?.httpStatusCode, 501)
        try assertTrue(f?.message.contains("stateless") == true)
    }

    test("validator: background is a 501") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","background":true}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("background"))
    }

    test("validator: reasoning is a 501") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","reasoning":{"effort":"low"}}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("reasoning"))
    }

    test("validator: store=true is a 501 (never pretend to have stored)") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","store":true}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("store"))
    }

    test("validator: store=false is fine") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","store":false}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), nil)
    }

    test("validator: include is a 501") {
        let r = try decodeResponses(#"{"model":"apple-foundationmodel","input":"x","include":["output[*]"]}"#)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("include"))
    }

    test("validator: hosted tools are a 501") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","tools":[{"type":"web_search"}]}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("tools[].type=web_search"))
    }

    test("validator: function tools with stream=true are a 501 (v1)") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","stream":true,
         "tools":[{"type":"function","name":"add"}]}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("tools with stream"))
    }

    test("validator: json_schema with stream=true is a 501 (v1)") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"x","stream":true,
         "text":{"format":{"type":"json_schema","name":"p","schema":{"type":"object"}}}}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("json_schema with stream"))
    }

    test("validator: function_call_output input items are a 501 (v1)") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":[
          {"type":"function_call_output","call_id":"c1","output":"42"}]}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), .unsupported("input[].type=function_call_output"))
    }

    test("validator: a plain valid request passes") {
        let r = try decodeResponses("""
        {"model":"apple-foundationmodel","input":"hello","instructions":"be brief",
         "temperature":0.7,"max_output_tokens":100,"stream":true}
        """)
        try assertEqual(ResponsesRequestValidator.validate(r), nil)
    }
}
