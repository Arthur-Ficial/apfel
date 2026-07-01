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
        guard case .number(let name, _) = ir else {
            throw TestFailure("expected .number for integer, got \(ir)")
        }
        try assertEqual(name, "i")
    }

    test("parse number primitive") {
        let ir = try SchemaParser.parse(json: #"{"type":"number"}"#, name: "n")
        guard case .number = ir else {
            throw TestFailure("expected .number, got \(ir)")
        }
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

    test("object properties sorted alphabetically for determinism") {
        // Parsers that hash dicts must still yield deterministic output.
        let json = #"""
        {"type":"object","properties":{"z":{"type":"string"},"a":{"type":"string"},"m":{"type":"string"}}}
        """#
        let ir = try SchemaParser.parse(json: json, name: "obj")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.map { $0.name }, ["a", "m", "z"])
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

    // MARK: anyOf / oneOf / type-array (nullable optional pattern)

    test("anyOf nullable pattern parses the non-null variant") {
        let json = #"""
        {"anyOf":[{"type":"string"},{"type":"null"}]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "opt")
        guard case .string(let name, _, _) = ir else {
            throw TestFailure("expected .string, got \(ir)")
        }
        try assertEqual(name, "opt")
    }

    test("oneOf nullable pattern parses the non-null variant") {
        let json = #"""
        {"oneOf":[{"type":"integer"},{"type":"null"}]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "optInt")
        guard case .number(let name, _) = ir else {
            throw TestFailure("expected .number, got \(ir)")
        }
        try assertEqual(name, "optInt")
    }

    test("type array nullable parses the non-null type") {
        let json = #"""
        {"type":["string","null"]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "nullable")
        guard case .string(let name, _, _) = ir else {
            throw TestFailure("expected .string, got \(ir)")
        }
        try assertEqual(name, "nullable")
    }

    test("type array with description preserved") {
        let json = #"""
        {"type":["boolean","null"],"description":"flag"}
        """#
        let ir = try SchemaParser.parse(json: json, name: "flag")
        guard case .bool(_, let desc) = ir else {
            throw TestFailure("expected .bool, got \(ir)")
        }
        try assertEqual(desc, "flag")
    }

    test("anyOf description inherited from outer schema") {
        let json = #"""
        {"anyOf":[{"type":"string"},{"type":"null"}],"description":"city name"}
        """#
        let ir = try SchemaParser.parse(json: json, name: "city")
        guard case .string(_, let desc, _) = ir else {
            throw TestFailure("expected .string, got \(ir)")
        }
        try assertEqual(desc, "city name")
    }

    test("anyOf inner description takes precedence over outer") {
        let json = #"""
        {"anyOf":[{"type":"string","description":"inner"},{"type":"null"}],"description":"outer"}
        """#
        let ir = try SchemaParser.parse(json: json, name: "x")
        guard case .string(_, let desc, _) = ir else {
            throw TestFailure("expected .string, got \(ir)")
        }
        try assertEqual(desc, "inner")
    }

    test("anyOf with object variant (Pydantic-style optional object)") {
        let json = #"""
        {"anyOf":[{"type":"object","properties":{"lat":{"type":"number"},"lon":{"type":"number"}},"required":["lat","lon"]},{"type":"null"}]}
        """#
        let ir = try SchemaParser.parse(json: json, name: "location")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object, got \(ir)")
        }
        try assertEqual(props.count, 2)
        try assertTrue(props.allSatisfy { !$0.isOptional })
    }

    test("anyOf with multiple non-null variants throws unsupportedType") {
        let json = #"""
        {"anyOf":[{"type":"string"},{"type":"integer"}]}
        """#
        do {
            _ = try SchemaParser.parse(json: json, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType(let t) {
            try assertTrue(t.contains("union"), "message should mention union: \(t)")
        }
    }

    test("type array with multiple non-null types throws unsupportedType") {
        let json = #"""
        {"type":["string","integer"]}
        """#
        do {
            _ = try SchemaParser.parse(json: json, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType(let t) {
            try assertTrue(t.contains("string"), "message should list types: \(t)")
        }
    }

    test("allOf throws unsupportedType") {
        let json = #"""
        {"allOf":[{"type":"object","properties":{"x":{"type":"string"}}},{"type":"object","properties":{"y":{"type":"string"}}}]}
        """#
        do {
            _ = try SchemaParser.parse(json: json, name: "bad")
            throw TestFailure("expected throw")
        } catch SchemaParser.Error.unsupportedType(let t) {
            try assertTrue(t.contains("allOf"), "message should mention allOf: \(t)")
        }
    }

    test("anyOf inside object property (real-world Pydantic optional field)") {
        let json = #"""
        {
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"anyOf": [{"type": "integer"}, {"type": "null"}], "description": "optional age"}
          },
          "required": ["name"]
        }
        """#
        let ir = try SchemaParser.parse(json: json, name: "person")
        guard case .object(_, _, let props) = ir else {
            throw TestFailure("expected .object")
        }
        try assertEqual(props.count, 2)
        let age = props.first { $0.name == "age" }!
        guard case .number = age.schema else {
            throw TestFailure("age should be .number, got \(age.schema)")
        }
        try assertEqual(age.description, "optional age")
        try assertTrue(age.isOptional, "age not in required")
    }

    test("missing type without anyOf/oneOf/allOf still defaults to object") {
        let ir = try SchemaParser.parse(
            json: #"{"properties":{"x":{"type":"string"}}}"#,
            name: "root"
        )
        guard case .object = ir else {
            throw TestFailure("expected .object when type omitted and no composition keywords")
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
        // Alphabetical: location, unit
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
}
