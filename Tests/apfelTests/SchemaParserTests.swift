// ============================================================================
// SchemaParserTests.swift — Unit tests for SchemaParser + SchemaIR
// Covers JSON Schema -> pure IR parsing. The FoundationModels adapter
// (SchemaIR -> DynamicGenerationSchema) is covered separately by integration.
// ============================================================================

import Foundation
import ApfelCore

func runSchemaParserTests() {
    // MARK: Primitives

    test("parse string primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"string"}"#, name: "s")
        guard case .string(let name, let desc, let enums) = ir else {
            throw TestFailure("expected .string, got \(ir)")
        }
        try assertEqual(name, "s")
        try assertNil(desc)
        try assertNil(enums)
    }

    test("parse integer primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"integer"}"#, name: "i")
        guard case .integer(let name, _) = ir else {
            throw TestFailure("expected .integer for integer, got \(ir)")
        }
        try assertEqual(name, "i")
    }

    test("parse number primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"number"}"#, name: "n")
        guard case .number = ir else {
            throw TestFailure("expected .number, got \(ir)")
        }
    }

    test("integer and number parse to distinct IR cases (#243)") {
        let intIR = try SchemaParser.parse(json: #"{"type":"integer"}"#, name: "x")
        let numIR = try SchemaParser.parse(json: #"{"type":"number"}"#, name: "x")
        try assertTrue(intIR != numIR, "integer and number must not collapse to the same IR")
        guard case .integer = intIR else { throw TestFailure("expected .integer") }
        guard case .number = numIR else { throw TestFailure("expected .number") }
    }

    test("parse boolean primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"boolean"}"#, name: "b")
        guard case .bool = ir else {
            throw TestFailure("expected .bool, got \(ir)")
        }
    }

    test("description preserved on primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"string","description":"city name"}"#, name: "city")
        guard case .string(_, let desc, _) = ir else {
            throw TestFailure("expected .string")
        }
        try assertEqual(desc, "city name")
    }

    // MARK: String enums

    test("string with enum produces enumValues") {
        let ir = try SchemaParser.parse(
            json: #"{"type":"string","enum":["celsius","fahrenheit"]}"#,
            name: "unit"
        )
        guard case .string(_, _, let enums) = ir else {
            throw TestFailure("expected .string with enum")
        }
        try assertEqual(enums ?? [], ["celsius", "fahrenheit"])
    }

    test("string without enum has nil enumValues") {
        let ir = try SchemaParser.parse(json: #"{"type":"string"}"#, name: "free")
        guard case .string(_, _, let enums) = ir else {
            throw TestFailure("expected .string")
        }
        try assertNil(enums)
    }

    // MARK: Objects

    test("empty object") {
        let ir = try SchemaParser.parse(json: #"{"type":"object"}"#, name: "obj")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.count, 0)
    }

    test("object with one required property") {
        let json = #"""
        {"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "weather")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.count, 1)
        try assertEqual(props[0].name, "city")
        try assertTrue(!props[0].isOptional, "required property must not be optional")
    }

    test("object with optional property") {
        let json = #"""
        {"type":"object","properties":{"unit":{"type":"string"}}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "config")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.count, 1)
        try assertTrue(props[0].isOptional, "property not in required must be optional")
    }

    test("object properties follow declared order, not alphabetical (#560)") {
        let json = #"""
        {"type":"object","properties":{"z":{"type":"string"},"a":{"type":"string"},"m":{"type":"string"}}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "obj")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.map { $0.name }, ["z", "a", "m"])
    }

    test("object with mix of required and optional") {
        let json = #"""
        {"type":"object","properties":{"city":{"type":"string"},"unit":{"type":"string"}},"required":["city"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "weather")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.count, 2)
        let byName = Dictionary(uniqueKeysWithValues: props.map { ($0.name, $0.isOptional) })
        try assertEqual(byName["city"] ?? true, false)
        try assertEqual(byName["unit"] ?? false, true)
    }

    test("object property descriptions preserved") {
        let json = #"""
        {"type":"object","properties":{"city":{"type":"string","description":"City name"}}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "obj")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertEqual(props[0].description, "City name")
    }

    // MARK: Nested objects

    test("nested object (2 levels)") {
        let json = #"""
        {"type":"object","properties":{"location":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}},"required":["location"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(_, _, let props) = ir, props.count == 1 else {
            throw TestFailure("expected outer object with 1 property")
        }
        guard case .object(_, _, let innerProps) = props[0].schema else {
            throw TestFailure("expected nested object")
        }
        try assertEqual(innerProps.count, 1)
        try assertEqual(innerProps[0].name, "city")
        try assertTrue(!innerProps[0].isOptional)
    }

    test("nested object (3 levels) does not stack overflow") {
        let json = #"""
        {"type":"object","properties":{"a":{"type":"object","properties":{"b":{"type":"object","properties":{"c":{"type":"string"}}}}}}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "root")
        // Just walking it must not throw or overflow.
        guard case .object(_, _, let l1) = ir else { throw TestFailure("level 1") }
        guard case .object(_, _, let l2) = l1[0].schema else { throw TestFailure("level 2") }
        guard case .object(_, _, let l3) = l2[0].schema else { throw TestFailure("level 3") }
        try assertEqual(l3[0].name, "c")
    }

    // MARK: Arrays

    test("array of strings") {
        let json = #"""
        {"type":"array","items":{"type":"string"}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "tags")
        guard case .array(_, let items) = ir else {
            throw TestFailure("expected .array, got \(ir)")
        }
        guard case .string = items else {
            throw TestFailure("expected array items to be .string")
        }
    }

    test("array of objects") {
        let json = #"""
        {"type":"array","items":{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "users")
        guard case .array(_, let items) = ir else {
            throw TestFailure("expected .array")
        }
        guard case .object(_, _, let props) = items else {
            throw TestFailure("expected array items to be .object")
        }
        try assertEqual(props[0].name, "id")
    }

    test("array without items throws missingArrayItems") {
        do {
            _ = try SchemaParser.parse(json: #"{"type":"array"}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.missingArrayItems {
            // expected
        }
    }

    // MARK: Error cases

    test("malformed JSON throws invalidJSON") {
        do {
            _ = try SchemaParser.parse(json: "{not json}", name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.invalidJSON {
            // expected
        }
    }

    test("non-object top-level JSON throws invalidJSON") {
        do {
            _ = try SchemaParser.parse(json: "[1,2,3]", name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.invalidJSON {
            // expected
        }
    }

    test("unknown type throws unsupportedType") {
        do {
            _ = try SchemaParser.parse(json: #"{"type":"bigint"}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType(let t) {
            try assertEqual(t, "bigint")
        }
    }

    test("missing type defaults to object") {
        // OpenAI function schemas sometimes omit "type" on the root. Treating
        // root as object matches convertObject's existing behaviour.
        let ir = try SchemaParser.parse(
            json: #"{"properties":{"x":{"type":"string"}}}"#,
            name: "root"
        )
        guard case .object = ir else {
            throw TestFailure("expected .object when type omitted")
        }
    }

    // MARK: Real-world fixtures

    test("OpenAI weather function fixture") {
        let json = #"""
        {
          "type": "object",
          "properties": {
            "location": {
              "type": "string",
              "description": "The city and state, e.g. San Francisco, CA"
            },
            "unit": {
              "type": "string",
              "enum": ["celsius", "fahrenheit"]
            }
          },
          "required": ["location"]
        }
        """#
        let ir = try SchemaParser.parse(json: json, name: "get_current_weather")
        guard case .object(let objName, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(objName, "get_current_weather")
        try assertEqual(props.count, 2)
        try assertEqual(props[0].name, "location")
        try assertEqual(props[1].name, "unit")
        try assertTrue(!props[0].isOptional, "location is required")
        try assertTrue(props[1].isOptional, "unit is optional")
        guard case .string(_, _, let unitEnums) = props[1].schema else {
            throw TestFailure("unit must be string")
        }
        try assertEqual(unitEnums ?? [], ["celsius", "fahrenheit"])
    }

    test("MCP calculator fixture") {
        let json = #"""
        {
          "type": "object",
          "properties": {
            "a": {"type": "number", "description": "first operand"},
            "b": {"type": "number", "description": "second operand"},
            "op": {"type": "string", "enum": ["add", "sub", "mul", "div"]}
          },
          "required": ["a", "b", "op"]
        }
        """#
        let ir = try SchemaParser.parse(json: json, name: "calc")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertEqual(props.count, 3)
        // All required
        try assertTrue(props.allSatisfy { !$0.isOptional })
        // op has enum
        let op = props.first { $0.name == "op" }!
        guard case .string(_, _, let opEnums) = op.schema else { throw TestFailure("op must be string") }
        try assertEqual(opEnums ?? [], ["add", "sub", "mul", "div"])
    }

    // MARK: Equatable / determinism

    test("identical JSON parses to identical IR (Equatable)") {
        let json = #"""
        {"type":"object","properties":{"x":{"type":"string"}},"required":["x"]}
        """#
        let a = try SchemaParser.parse(json: json, name: "t")
        let b = try SchemaParser.parse(json: json, name: "t")
        try assertTrue(a == b, "parser output not deterministic")
    }

    test("different JSON parses to different IR (Equatable)") {
        let a = try SchemaParser.parse(json: #"{"type":"object","properties":{"x":{"type":"string"}}}"#, name: "t")
        let b = try SchemaParser.parse(json: #"{"type":"object","properties":{"y":{"type":"string"}}}"#, name: "t")
        try assertTrue(a != b)
    }

    // MARK: Nullable unions / type-arrays (#219)

    test("anyOf [X, null] unwraps to X") {
        let ir = try SchemaParser.parse(json: #"{"anyOf":[{"type":"string"},{"type":"null"}]}"#, name: "s")
        guard case .string = ir else { throw TestFailure("expected .string, got \(ir)") }
    }

    test("anyOf [null, X] (reversed order) unwraps to X") {
        let ir = try SchemaParser.parse(json: #"{"anyOf":[{"type":"null"},{"type":"number"}]}"#, name: "n")
        guard case .number = ir else { throw TestFailure("expected .number, got \(ir)") }
    }

    test("oneOf [X, null] unwraps to X") {
        let ir = try SchemaParser.parse(json: #"{"oneOf":[{"type":"integer"},{"type":"null"}]}"#, name: "i")
        guard case .integer = ir else { throw TestFailure("expected .integer, got \(ir)") }
    }

    test("type array [string, null] unwraps to string") {
        let ir = try SchemaParser.parse(json: #"{"type":["string","null"]}"#, name: "s")
        guard case .string = ir else { throw TestFailure("expected .string, got \(ir)") }
    }

    test("type array [null, integer] unwraps to integer") {
        let ir = try SchemaParser.parse(json: #"{"type":["null","integer"]}"#, name: "i")
        guard case .integer = ir else { throw TestFailure("expected .integer, got \(ir)") }
    }

    test("nullable anyOf preserves enum on the non-null branch") {
        let ir = try SchemaParser.parse(
            json: #"{"anyOf":[{"type":"string","enum":["a","b"]},{"type":"null"}]}"#,
            name: "u"
        )
        guard case .string(_, _, let enums) = ir else { throw TestFailure("expected .string") }
        try assertEqual(enums ?? [], ["a", "b"])
    }

    test("nullable property is optional even when listed in required") {
        // The common Pydantic/zod Optional[str] pattern: required but nullable.
        let json = #"""
        {"type":"object","properties":{"unit":{"anyOf":[{"type":"string"},{"type":"null"}]}},"required":["unit"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "cfg")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertEqual(props.count, 1)
        try assertEqual(props[0].name, "unit")
        try assertTrue(props[0].isOptional, "nullable property must be optional")
        guard case .string = props[0].schema else { throw TestFailure("unit must unwrap to .string") }
    }

    test("nullable type-array property is optional even when required") {
        let json = #"""
        {"type":"object","properties":{"age":{"type":["integer","null"]}},"required":["age"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "person")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertTrue(props[0].isOptional, "nullable type-array property must be optional")
        guard case .integer = props[0].schema else { throw TestFailure("age must unwrap to .integer") }
    }

    test("anyOf of two non-null types throws unsupportedType") {
        do {
            _ = try SchemaParser.parse(json: #"{"anyOf":[{"type":"string"},{"type":"number"}]}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType {
            // expected - engages the text-injection fallback (tools) / 400 (json_schema)
        }
    }

    test("allOf throws unsupportedType") {
        do {
            _ = try SchemaParser.parse(json: #"{"allOf":[{"type":"string"}]}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType {
            // expected
        }
    }

    test("type array with three entries throws unsupportedType") {
        do {
            _ = try SchemaParser.parse(json: #"{"type":["string","number","null"]}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType {
            // expected
        }
    }

    test("type array without null throws unsupportedType") {
        do {
            _ = try SchemaParser.parse(json: #"{"type":["string","number"]}"#, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType {
            // expected
        }
    }

    // MARK: Declared property order (#560)

    test("declared property order is preserved across many properties (#560)") {
        let json = #"""
        {"type":"object","properties":{
          "reasoning":{"type":"string"},
          "answer":{"type":"string"},
          "confidence":{"type":"number"},
          "tags":{"type":"array","items":{"type":"string"}},
          "id":{"type":"integer"}
        },"required":["reasoning","answer"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "result")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.map { $0.name }, ["reasoning", "answer", "confidence", "tags", "id"])
    }

    test("nested object properties follow their own declared order (#560)") {
        let json = #"""
        {"type":"object","properties":{
          "beta":{"type":"object","properties":{"second":{"type":"string"},"first":{"type":"string"}}},
          "alpha":{"type":"object","properties":{"z":{"type":"integer"},"a":{"type":"integer"}}}
        }}
        """#
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(_, _, let outer) = ir else { throw TestFailure("expected .object") }
        try assertEqual(outer.map { $0.name }, ["beta", "alpha"])
        guard case .object(_, _, let betaProps) = outer[0].schema else { throw TestFailure("expected beta object") }
        try assertEqual(betaProps.map { $0.name }, ["second", "first"])
        guard case .object(_, _, let alphaProps) = outer[1].schema else { throw TestFailure("expected alpha object") }
        try assertEqual(alphaProps.map { $0.name }, ["z", "a"])
    }

    test("a duplicate property key is listed once, not twice (#560)") {
        // JSONSerialization keeps one value per key; the byte scan sees both
        // occurrences. The scanned order must not duplicate the property.
        let json = #"{"type":"object","properties":{"b":{"type":"string"},"a":{"type":"string"},"b":{"type":"string"}}}"#
        let ir = try SchemaParser.parse(json: json, name: "t")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertEqual(props.map { $0.name }.sorted(), ["a", "b"])
    }

    test("escaped property keys keep their declared order (#560)") {
        let json = #"{"type":"object","properties":{"caf\u00e9":{"type":"string"},"a\"q":{"type":"string"},"a":{"type":"string"}}}"#
        let ir = try SchemaParser.parse(json: json, name: "t")
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object") }
        try assertEqual(props.map { $0.name }, ["café", "a\"q", "a"])
    }

    test("declared order is deterministic across multiple parses (#560)") {
        let json = #"""
        {"type":"object","properties":{"c":{"type":"string"},"b":{"type":"string"},"a":{"type":"string"}}}
        """#
        let ir1 = try SchemaParser.parse(json: json, name: "t")
        let ir2 = try SchemaParser.parse(json: json, name: "t")
        try assertEqual(ir1, ir2)
        guard case .object(_, _, let props) = ir1 else { throw TestFailure("expected .object") }
        try assertEqual(props.map { $0.name }, ["c", "b", "a"])
    }
}
