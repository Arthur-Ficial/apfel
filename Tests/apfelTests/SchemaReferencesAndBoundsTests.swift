// ============================================================================
// SchemaReferencesAndBoundsTests.swift - Unit tests for #479
//
// Local `$ref` / `$defs` resolution, numeric and array bounds, unique node
// naming, and explicit rejection of validation keywords that schema-guided
// generation cannot enforce. Pure ApfelCore; the FoundationModels adapter is
// covered by the integration suites.
// ============================================================================

import Foundation
import ApfelCore

func runSchemaReferencesAndBoundsTests() {

    // Pull the object named `name` out of an object IR's property list.
    func property(_ ir: SchemaIR, _ name: String) throws -> SchemaIR.Property {
        guard case .object(_, _, let props) = ir else { throw TestFailure("expected .object, got \(ir)") }
        guard let p = props.first(where: { $0.name == name }) else {
            throw TestFailure("no property \(name) in \(props.map { $0.name })")
        }
        return p
    }

    func expectError(_ json: String, name: String = "root", _ check: (SchemaParser.Error) throws -> Void) throws {
        do {
            let ir = try SchemaParser.parse(json: json, name: name)
            throw TestFailure("expected SchemaParser.Error, parsed to \(ir)")
        } catch let e as SchemaParser.Error {
            try check(e)
        }
    }

    // MARK: - $ref / $defs resolution

    test("$ref to $defs resolves the referenced object's properties") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Address":{"type":"object","properties":{"street":{"type":"string"},"city":{"type":"string"}},"required":["street","city"]}},
         "properties":{"billing":{"$ref":"#/$defs/Address"}},
         "required":["billing"]}
        """##
        let ir = try SchemaParser.parse(json: json, name: "Order")
        let billing = try property(ir, "billing")
        try assertTrue(!billing.isOptional)
        guard case .object(let name, _, let props) = billing.schema else {
            throw TestFailure("billing must resolve to an object, got \(billing.schema)")
        }
        try assertEqual(name, "Address", "a referenced definition is named after its $defs key")
        try assertEqual(props.map { $0.name }, ["city", "street"])
    }

    test("shared $ref used twice yields identical IR under one name") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Address":{"type":"object","properties":{"street":{"type":"string"}},"required":["street"]}},
         "properties":{"billing":{"$ref":"#/$defs/Address"},"shipping":{"$ref":"#/$defs/Address"}},
         "required":["billing","shipping"]}
        """##
        let ir = try SchemaParser.parse(json: json, name: "Order")
        let billing = try property(ir, "billing").schema
        let shipping = try property(ir, "shipping").schema
        try assertEqual(billing, shipping)
        guard case .object(let n, _, _) = shipping else { throw TestFailure("expected object") }
        try assertEqual(n, "Address")
    }

    test("draft-4 `definitions` container resolves too") {
        let json = ##"""
        {"type":"object",
         "definitions":{"Geo":{"type":"object","properties":{"lat":{"type":"number"}}}},
         "properties":{"where":{"$ref":"#/definitions/Geo"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(let n, _, let props) = try property(ir, "where").schema else { throw TestFailure("expected object") }
        try assertEqual(n, "Geo")
        try assertEqual(props.first?.name, "lat")
    }

    test("nested definitions: a definition may reference another definition") {
        let json = ##"""
        {"type":"object",
         "$defs":{
           "Geo":{"type":"object","properties":{"lat":{"type":"number"}},"required":["lat"]},
           "Address":{"type":"object","properties":{"geo":{"$ref":"#/$defs/Geo"}},"required":["geo"]}},
         "properties":{"home":{"$ref":"#/$defs/Address"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let home = try property(ir, "home").schema
        let geo = try property(home, "geo").schema
        guard case .object(let n, _, let props) = geo else { throw TestFailure("expected Geo object") }
        try assertEqual(n, "Geo")
        try assertEqual(props.first?.name, "lat")
    }

    test("JSON pointer escapes ~1 and ~0 and percent-encoding are decoded") {
        // Key is literally `a/b~c`; pointer form is `a~1b~0c`. `%24defs` is `$defs`.
        let json = ##"""
        {"type":"object",
         "$defs":{"a/b~c":{"type":"integer"}},
         "properties":{"x":{"$ref":"#/%24defs/a~1b~0c"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .integer(let n, _) = try property(ir, "x").schema else { throw TestFailure("expected integer") }
        try assertEqual(n, "a/b~c")
    }

    test("$ref may point at any local schema node, not only $defs") {
        let json = ##"""
        {"type":"object",
         "properties":{
           "home":{"type":"object","properties":{"city":{"type":"string"}}},
           "work":{"$ref":"#/properties/home"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(_, _, let props) = try property(ir, "work").schema else { throw TestFailure("expected object") }
        try assertEqual(props.first?.name, "city")
    }

    test("$ref sibling description overrides the definition's description") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Address":{"type":"object","description":"generic","properties":{"city":{"type":"string"}}}},
         "properties":{"billing":{"$ref":"#/$defs/Address","description":"where the invoice goes"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let billing = try property(ir, "billing")
        try assertEqual(billing.description, "where the invoice goes")
        guard case .object(_, let desc, _) = billing.schema else { throw TestFailure("expected object") }
        try assertEqual(desc, "where the invoice goes")
    }

    test("nullable $ref (Optional[Model] in Pydantic) is an optional resolved object") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Address":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}},
         "properties":{"shipping":{"anyOf":[{"$ref":"#/$defs/Address"},{"type":"null"}]}},
         "required":["shipping"]}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let shipping = try property(ir, "shipping")
        try assertTrue(shipping.isOptional, "nullable ref must be optional even when required")
        guard case .object(let n, _, let props) = shipping.schema else { throw TestFailure("expected object") }
        try assertEqual(n, "Address")
        try assertEqual(props.first?.name, "city")
    }

    test("$ref to a definition that is itself a nullable union unwraps") {
        let json = ##"""
        {"type":"object",
         "$defs":{"MaybeName":{"anyOf":[{"type":"string"},{"type":"null"}]}},
         "properties":{"nick":{"$ref":"#/$defs/MaybeName"}},
         "required":["nick"]}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let nick = try property(ir, "nick")
        try assertTrue(nick.isOptional)
        guard case .string = nick.schema else { throw TestFailure("expected string, got \(nick.schema)") }
    }

    test("$ref to a bounded primitive definition keeps its bounds") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Score":{"type":"integer","minimum":0,"maximum":10}},
         "properties":{"s":{"$ref":"#/$defs/Score"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .boundedInteger(_, _, let lo, let hi) = try property(ir, "s").schema else {
            throw TestFailure("expected boundedInteger")
        }
        try assertEqual(lo, 0)
        try assertEqual(hi, 10)
    }

    test("root may itself be a $ref") {
        let json = ##"""
        {"$ref":"#/$defs/Person","$defs":{"Person":{"type":"object","properties":{"name":{"type":"string"}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(let n, _, let props) = ir else { throw TestFailure("expected object") }
        try assertEqual(n, "root", "the root keeps the caller-supplied name")
        try assertEqual(props.first?.name, "name")
    }

    test("array items may be a $ref") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Item":{"type":"object","properties":{"sku":{"type":"string"}}}},
         "properties":{"items":{"type":"array","items":{"$ref":"#/$defs/Item"}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .array(_, let inner) = try property(ir, "items").schema else { throw TestFailure("expected array") }
        guard case .object(let n, _, let props) = inner else { throw TestFailure("expected object items") }
        try assertEqual(n, "Item")
        try assertEqual(props.first?.name, "sku")
    }

    // MARK: - Reference errors

    test("external $ref (URL) is rejected with externalReference and path") {
        let json = ##"{"type":"object","properties":{"x":{"$ref":"https://example.com/schema.json#/Foo"}}}"##
        try expectError(json) { e in
            guard case .externalReference(let ref, let path) = e else { throw TestFailure("expected externalReference, got \(e)") }
            try assertEqual(ref, "https://example.com/schema.json#/Foo")
            try assertEqual(path, "#/properties/x")
        }
    }

    test("external $ref (relative file) is rejected with externalReference") {
        let json = ##"{"type":"object","properties":{"x":{"$ref":"other.json"}}}"##
        try expectError(json) { e in
            guard case .externalReference(let ref, _) = e else { throw TestFailure("expected externalReference, got \(e)") }
            try assertEqual(ref, "other.json")
        }
    }

    test("unresolved local $ref is rejected with unresolvedReference and path") {
        let json = ##"{"type":"object","$defs":{},"properties":{"x":{"$ref":"#/$defs/Missing"}}}"##
        try expectError(json) { e in
            guard case .unresolvedReference(let ref, let path) = e else { throw TestFailure("expected unresolvedReference, got \(e)") }
            try assertEqual(ref, "#/$defs/Missing")
            try assertEqual(path, "#/properties/x")
        }
    }

    test("$ref to a non-object node (an array) is unresolved") {
        let json = ##"""
        {"type":"object","$defs":{"A":{"type":"object","required":["q"],"properties":{"q":{"type":"string"}}}},
         "properties":{"x":{"$ref":"#/$defs/A/required"}}}
        """##
        try expectError(json) { e in
            guard case .unresolvedReference = e else { throw TestFailure("expected unresolvedReference, got \(e)") }
        }
    }

    test("plain-name fragment ($anchor style) is unresolved") {
        let json = ##"{"type":"object","properties":{"x":{"$ref":"#Address"}}}"##
        try expectError(json) { e in
            guard case .unresolvedReference = e else { throw TestFailure("expected unresolvedReference, got \(e)") }
        }
    }

    test("non-string $ref is an invalid constraint") {
        let json = ##"{"type":"object","properties":{"x":{"$ref":42}}}"##
        try expectError(json) { e in
            guard case .invalidConstraint(let kw, let path, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "$ref")
            try assertEqual(path, "#/properties/x")
        }
    }

    test("self-recursive definition is rejected with cyclicReference") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Node":{"type":"object","properties":{"next":{"$ref":"#/$defs/Node"}}}},
         "properties":{"head":{"$ref":"#/$defs/Node"}}}
        """##
        try expectError(json) { e in
            guard case .cyclicReference(let ref, let path) = e else { throw TestFailure("expected cyclicReference, got \(e)") }
            try assertEqual(ref, "#/$defs/Node")
            try assertEqual(path, "#/$defs/Node/properties/next")
        }
    }

    test("mutually recursive definitions are rejected with cyclicReference") {
        let json = ##"""
        {"type":"object",
         "$defs":{"A":{"type":"object","properties":{"b":{"$ref":"#/$defs/B"}}},
                  "B":{"type":"object","properties":{"a":{"$ref":"#/$defs/A"}}}},
         "properties":{"a":{"$ref":"#/$defs/A"}}}
        """##
        try expectError(json) { e in
            guard case .cyclicReference = e else { throw TestFailure("expected cyclicReference, got \(e)") }
        }
    }

    test("$ref '#' to the document root from inside it is cyclic") {
        let json = ##"{"type":"object","properties":{"child":{"$ref":"#"}}}"##
        try expectError(json) { e in
            guard case .cyclicReference(let ref, _) = e else { throw TestFailure("expected cyclicReference, got \(e)") }
            try assertEqual(ref, "#")
        }
    }

    test("a reference chain deeper than the limit is rejected, not followed forever") {
        // D0 -> D1 -> ... -> D40, acyclic but far deeper than any sane schema.
        var defs: [String] = []
        for i in 0..<40 {
            defs.append(##""D\##(i)":{"$ref":"#/$defs/D\##(i + 1)"}"##)
        }
        defs.append(##""D40":{"type":"string"}"##)
        let json = ##"{"type":"object","$defs":{\##(defs.joined(separator: ","))},"properties":{"x":{"$ref":"#/$defs/D0"}}}"##
        try expectError(json) { e in
            guard case .referenceDepthExceeded(let limit, _) = e else { throw TestFailure("expected referenceDepthExceeded, got \(e)") }
            try assertTrue(limit > 0)
        }
    }

    test("exponential fan-out through shared references is bounded by a node budget") {
        // Each level has 8 properties referencing the next level: 8^4 = 4096 leaves.
        let json = ##"""
        {"type":"object",
         "$defs":{
           "L3":{"type":"string"},
           "L2":{"type":"object","properties":{"a":{"$ref":"#/$defs/L3"},"b":{"$ref":"#/$defs/L3"},"c":{"$ref":"#/$defs/L3"},"d":{"$ref":"#/$defs/L3"},"e":{"$ref":"#/$defs/L3"},"f":{"$ref":"#/$defs/L3"},"g":{"$ref":"#/$defs/L3"},"h":{"$ref":"#/$defs/L3"}}},
           "L1":{"type":"object","properties":{"a":{"$ref":"#/$defs/L2"},"b":{"$ref":"#/$defs/L2"},"c":{"$ref":"#/$defs/L2"},"d":{"$ref":"#/$defs/L2"},"e":{"$ref":"#/$defs/L2"},"f":{"$ref":"#/$defs/L2"},"g":{"$ref":"#/$defs/L2"},"h":{"$ref":"#/$defs/L2"}}},
           "L0":{"type":"object","properties":{"a":{"$ref":"#/$defs/L1"},"b":{"$ref":"#/$defs/L1"},"c":{"$ref":"#/$defs/L1"},"d":{"$ref":"#/$defs/L1"},"e":{"$ref":"#/$defs/L1"},"f":{"$ref":"#/$defs/L1"},"g":{"$ref":"#/$defs/L1"},"h":{"$ref":"#/$defs/L1"}}}},
         "properties":{"a":{"$ref":"#/$defs/L0"},"b":{"$ref":"#/$defs/L0"},"c":{"$ref":"#/$defs/L0"},"d":{"$ref":"#/$defs/L0"},"e":{"$ref":"#/$defs/L0"},"f":{"$ref":"#/$defs/L0"},"g":{"$ref":"#/$defs/L0"},"h":{"$ref":"#/$defs/L0"}}}
        """##
        try expectError(json) { e in
            guard case .schemaTooLarge(let limit) = e else { throw TestFailure("expected schemaTooLarge, got \(e)") }
            try assertTrue(limit > 0)
        }
    }

    test("a realistic Pydantic-sized schema is well under the node budget") {
        // 30 properties, three shared definitions used twice each.
        var props: [String] = []
        for i in 0..<30 { props.append(##""f\##(i)":{"type":"string"}"##) }
        props.append(##""b":{"$ref":"#/$defs/A"},"s":{"$ref":"#/$defs/A"},"i":{"type":"array","items":{"$ref":"#/$defs/I"}}"##)
        let json = ##"""
        {"type":"object",
         "$defs":{"A":{"type":"object","properties":{"street":{"type":"string"},"city":{"type":"string"}}},
                  "I":{"type":"object","properties":{"sku":{"type":"string"},"qty":{"type":"integer","minimum":1}}}},
         "properties":{\##(props.joined(separator: ","))}}
        """##
        _ = try SchemaParser.parse(json: json, name: "root")
    }

    // MARK: - Unique names (FoundationModels hoists named nodes by name)

    test("two differently shaped objects with the same property name get distinct names") {
        // Before #479 both were named `x`; FoundationModels merged them into one
        // $defs entry and the second shape silently vanished from generation.
        let json = ##"""
        {"type":"object","properties":{
          "a":{"type":"object","properties":{"x":{"type":"object","properties":{"p":{"type":"string"}}}}},
          "b":{"type":"object","properties":{"x":{"type":"object","properties":{"q":{"type":"string"}}}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let ax = try property(try property(ir, "a").schema, "x").schema
        let bx = try property(try property(ir, "b").schema, "x").schema
        guard case .object(let an, _, _) = ax, case .object(let bn, _, _) = bx else { throw TestFailure("expected objects") }
        try assertEqual(an, "x")
        try assertEqual(bn, "x_2")
    }

    test("two identically shaped objects with the same name share the name") {
        let json = ##"""
        {"type":"object","properties":{
          "a":{"type":"object","properties":{"x":{"type":"object","properties":{"p":{"type":"string"}}}}},
          "b":{"type":"object","properties":{"x":{"type":"object","properties":{"p":{"type":"string"}}}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let ax = try property(try property(ir, "a").schema, "x").schema
        let bx = try property(try property(ir, "b").schema, "x").schema
        try assertEqual(ax, bx)
        guard case .object(let bn, _, _) = bx else { throw TestFailure("expected object") }
        try assertEqual(bn, "x")
    }

    test("two string enums with the same name but different values get distinct names") {
        let json = ##"""
        {"type":"object","properties":{
          "temp":{"type":"object","properties":{"unit":{"type":"string","enum":["c","f"]}}},
          "mass":{"type":"object","properties":{"unit":{"type":"string","enum":["kg","lb"]}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        let massUnit = try property(try property(ir, "mass").schema, "unit").schema
        let tempUnit = try property(try property(ir, "temp").schema, "unit").schema
        guard case .string(let mn, _, let mv) = massUnit, case .string(let tn, _, let tv) = tempUnit else {
            throw TestFailure("expected string enums")
        }
        // Properties are visited alphabetically: mass first, temp second.
        try assertEqual(mn, "unit")
        try assertEqual(mv ?? [], ["kg", "lb"])
        try assertEqual(tn, "unit_2")
        try assertEqual(tv ?? [], ["c", "f"])
    }

    test("a nested object that wants the root's name is renamed; the root keeps its name") {
        let json = ##"""
        {"type":"object","properties":{"Order":{"type":"object","properties":{"id":{"type":"string"}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "Order")
        guard case .object(let rootName, _, _) = ir else { throw TestFailure("expected object") }
        try assertEqual(rootName, "Order")
        guard case .object(let childName, _, _) = try property(ir, "Order").schema else { throw TestFailure("expected object") }
        try assertEqual(childName, "Order_2")
    }

    test("a $defs key colliding with a differently shaped inline object is disambiguated") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Address":{"type":"object","properties":{"street":{"type":"string"}}}},
         "properties":{
           "Address":{"type":"object","properties":{"zip":{"type":"string"}}},
           "billing":{"$ref":"#/$defs/Address"}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .object(let inlineName, _, _) = try property(ir, "Address").schema,
              case .object(let refName, _, _) = try property(ir, "billing").schema else {
            throw TestFailure("expected objects")
        }
        try assertEqual(inlineName, "Address")
        try assertEqual(refName, "Address_2")
    }

    test("array item objects with the same array name but different shapes get distinct names") {
        let json = ##"""
        {"type":"object","properties":{
          "a":{"type":"object","properties":{"tags":{"type":"array","items":{"type":"object","properties":{"p":{"type":"string"}}}}}},
          "b":{"type":"object","properties":{"tags":{"type":"array","items":{"type":"object","properties":{"q":{"type":"string"}}}}}}}}
        """##
        let ir = try SchemaParser.parse(json: json, name: "root")
        guard case .array(_, let aItems) = try property(try property(ir, "a").schema, "tags").schema,
              case .array(_, let bItems) = try property(try property(ir, "b").schema, "tags").schema,
              case .object(let an, _, _) = aItems, case .object(let bn, _, _) = bItems else {
            throw TestFailure("expected arrays of objects")
        }
        try assertEqual(an, "tags_item")
        try assertEqual(bn, "tags_item_2")
    }

    // MARK: - Numeric bounds

    test("integer minimum and maximum parse to boundedInteger") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","minimum":1,"maximum":5}"##, name: "rating")
        guard case .boundedInteger(let n, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(n, "rating")
        try assertEqual(lo, 1)
        try assertEqual(hi, 5)
    }

    test("integer with only a minimum has nil maximum") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","minimum":10}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 10)
        try assertNil(hi)
    }

    test("integer with only a maximum has nil minimum") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","maximum":-3}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertNil(lo)
        try assertEqual(hi, -3)
    }

    test("integer without bounds still parses to the plain .integer case") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","description":"d"}"##, name: "i")
        guard case .integer = ir else { throw TestFailure("expected .integer, got \(ir)") }
    }

    test("integer exclusiveMinimum/exclusiveMaximum (numeric form) become the adjacent inclusive integers") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","exclusiveMinimum":0,"exclusiveMaximum":10}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 1)
        try assertEqual(hi, 9)
    }

    test("integer fractional bounds round inward") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","minimum":1.5,"maximum":4.5}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 2)
        try assertEqual(hi, 4)
    }

    test("integer draft-4 boolean exclusive flags are honoured") {
        let ir = try SchemaParser.parse(
            json: ##"{"type":"integer","minimum":0,"exclusiveMinimum":true,"maximum":10,"exclusiveMaximum":true}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 1)
        try assertEqual(hi, 9)
    }

    test("integer draft-4 exclusive flag false is a no-op") {
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","minimum":0,"exclusiveMinimum":false}"##, name: "i")
        guard case .boundedInteger(_, _, let lo, _) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 0)
    }

    test("number minimum and maximum parse to boundedNumber") {
        let ir = try SchemaParser.parse(json: ##"{"type":"number","minimum":0.5,"maximum":9.75}"##, name: "price")
        guard case .boundedNumber(let n, _, let lo, let hi) = ir else { throw TestFailure("expected boundedNumber, got \(ir)") }
        try assertEqual(n, "price")
        try assertEqual(lo, 0.5)
        try assertEqual(hi, 9.75)
    }

    test("number exclusiveMinimum 0 (Pydantic gt=0) becomes the smallest Double above 0") {
        let ir = try SchemaParser.parse(json: ##"{"type":"number","exclusiveMinimum":0}"##, name: "price")
        guard case .boundedNumber(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedNumber, got \(ir)") }
        try assertEqual(lo, Double(0).nextUp)
        try assertNil(hi)
    }

    test("number exclusiveMaximum becomes the largest Double below it") {
        let ir = try SchemaParser.parse(json: ##"{"type":"number","exclusiveMaximum":1.0}"##, name: "p")
        guard case .boundedNumber(_, _, _, let hi) = ir else { throw TestFailure("expected boundedNumber, got \(ir)") }
        try assertEqual(hi, Double(1).nextDown)
    }

    test("number without bounds still parses to the plain .number case") {
        let ir = try SchemaParser.parse(json: ##"{"type":"number"}"##, name: "n")
        guard case .number = ir else { throw TestFailure("expected .number, got \(ir)") }
    }

    test("bounds survive a nullable union") {
        let json = ##"{"anyOf":[{"type":"integer","minimum":1,"maximum":5},{"type":"null"}]}"##
        let ir = try SchemaParser.parse(json: json, name: "r")
        guard case .boundedInteger(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedInteger, got \(ir)") }
        try assertEqual(lo, 1)
        try assertEqual(hi, 5)
    }

    test("bounds survive a nullable type array") {
        let ir = try SchemaParser.parse(json: ##"{"type":["number","null"],"maximum":100}"##, name: "r")
        guard case .boundedNumber(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedNumber, got \(ir)") }
        try assertNil(lo)
        try assertEqual(hi, 100)
    }

    test("integer minimum above maximum is an invalid constraint with path") {
        let json = ##"{"type":"object","properties":{"x":{"type":"integer","minimum":5,"maximum":1}}}"##
        try expectError(json) { e in
            guard case .invalidConstraint(let kw, let path, let reason) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minimum")
            try assertEqual(path, "#/properties/x")
            try assertTrue(reason.contains("5") && reason.contains("1"), reason)
        }
    }

    test("integer exclusive bounds that leave no integer are invalid") {
        try expectError(##"{"type":"integer","exclusiveMinimum":1,"exclusiveMaximum":2}"##) { e in
            guard case .invalidConstraint(_, let path, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(path, "#")
        }
    }

    test("number minimum above maximum is an invalid constraint") {
        try expectError(##"{"type":"number","minimum":2.5,"maximum":2.4}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minimum")
        }
    }

    test("non-numeric minimum is an invalid constraint") {
        try expectError(##"{"type":"integer","minimum":"5"}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minimum")
        }
    }

    test("boolean-valued minimum is an invalid constraint, not the number 1") {
        try expectError(##"{"type":"integer","minimum":true}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minimum")
        }
    }

    test("integer bound outside Int range is an invalid constraint") {
        try expectError(##"{"type":"integer","minimum":1e30}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minimum")
        }
    }

    test("numeric keywords on a string node do not apply and are ignored") {
        // JSON Schema scopes `minimum` to numbers; on a string it constrains nothing.
        let ir = try SchemaParser.parse(json: ##"{"type":"string","minimum":3}"##, name: "s")
        guard case .string = ir else { throw TestFailure("expected .string, got \(ir)") }
    }

    // MARK: - Array bounds

    test("minItems and maxItems parse to boundedArray") {
        let ir = try SchemaParser.parse(json: ##"{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":3}"##, name: "tags")
        guard case .boundedArray(let n, let items, let lo, let hi) = ir else { throw TestFailure("expected boundedArray, got \(ir)") }
        try assertEqual(n, "tags")
        try assertEqual(lo, 2)
        try assertEqual(hi, 3)
        guard case .string = items else { throw TestFailure("expected string items") }
    }

    test("only minItems has nil maxItems") {
        let ir = try SchemaParser.parse(json: ##"{"type":"array","items":{"type":"integer"},"minItems":1}"##, name: "a")
        guard case .boundedArray(_, _, let lo, let hi) = ir else { throw TestFailure("expected boundedArray, got \(ir)") }
        try assertEqual(lo, 1)
        try assertNil(hi)
    }

    test("array without bounds still parses to the plain .array case") {
        let ir = try SchemaParser.parse(json: ##"{"type":"array","items":{"type":"string"}}"##, name: "a")
        guard case .array = ir else { throw TestFailure("expected .array, got \(ir)") }
    }

    test("minItems above maxItems is an invalid constraint") {
        try expectError(##"{"type":"array","items":{"type":"string"},"minItems":5,"maxItems":1}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minItems")
        }
    }

    test("negative minItems is an invalid constraint") {
        try expectError(##"{"type":"array","items":{"type":"string"},"minItems":-1}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "minItems")
        }
    }

    test("fractional maxItems is an invalid constraint") {
        try expectError(##"{"type":"array","items":{"type":"string"},"maxItems":2.5}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "maxItems")
        }
    }

    test("bounded array of bounded items nests correctly") {
        let json = ##"{"type":"array","items":{"type":"number","minimum":0},"maxItems":10}"##
        let ir = try SchemaParser.parse(json: json, name: "xs")
        guard case .boundedArray(_, let items, let lo, let hi) = ir else { throw TestFailure("expected boundedArray, got \(ir)") }
        try assertNil(lo)
        try assertEqual(hi, 10)
        guard case .boundedNumber(_, _, let ilo, _) = items else { throw TestFailure("expected boundedNumber items") }
        try assertEqual(ilo, 0)
    }

    // MARK: - Unsupported validation keywords are rejected, not dropped

    test("multipleOf is rejected with keyword and path") {
        let json = ##"{"type":"object","properties":{"x":{"type":"number","multipleOf":0.5}}}"##
        try expectError(json) { e in
            guard case .unsupportedConstraint(let kw, let path) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "multipleOf")
            try assertEqual(path, "#/properties/x")
        }
    }

    test("string minLength / maxLength / pattern are rejected") {
        for kw in ["minLength", "maxLength", "pattern"] {
            let value = kw == "pattern" ? ##""^a$""## : "3"
            try expectError(##"{"type":"string","\##(kw)":\##(value)}"##) { e in
                guard case .unsupportedConstraint(let got, let path) = e else { throw TestFailure("expected unsupportedConstraint for \(kw), got \(e)") }
                try assertEqual(got, kw)
                try assertEqual(path, "#")
            }
        }
    }

    test("string format is an annotation and is accepted") {
        let ir = try SchemaParser.parse(json: ##"{"type":"string","format":"date-time"}"##, name: "when")
        guard case .string = ir else { throw TestFailure("expected .string") }
    }

    test("uniqueItems true is rejected, uniqueItems false is accepted") {
        try expectError(##"{"type":"array","items":{"type":"string"},"uniqueItems":true}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "uniqueItems")
        }
        _ = try SchemaParser.parse(json: ##"{"type":"array","items":{"type":"string"},"uniqueItems":false}"##, name: "a")
    }

    test("array contains / prefixItems are rejected") {
        try expectError(##"{"type":"array","items":{"type":"string"},"contains":{"type":"string"}}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "contains")
        }
        try expectError(##"{"type":"array","items":{"type":"string"},"prefixItems":[{"type":"string"}]}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "prefixItems")
        }
    }

    test("enum on a non-string type is rejected") {
        try expectError(##"{"type":"integer","enum":[1,2,3]}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "enum")
        }
        try expectError(##"{"type":"boolean","enum":[true]}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "enum")
        }
    }

    test("string const becomes a single-value enum") {
        let ir = try SchemaParser.parse(json: ##"{"type":"string","const":"fixed"}"##, name: "s")
        guard case .string(_, _, let values) = ir else { throw TestFailure("expected .string") }
        try assertEqual(values ?? [], ["fixed"])
    }

    test("const on a non-string type is rejected") {
        try expectError(##"{"type":"integer","const":7}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "const")
        }
    }

    test("enum with non-string members on a string node is invalid") {
        try expectError(##"{"type":"string","enum":["a",1]}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "enum")
        }
    }

    test("empty enum is unsatisfiable and invalid") {
        try expectError(##"{"type":"string","enum":[]}"##) { e in
            guard case .invalidConstraint(let kw, _, _) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "enum")
        }
    }

    test("enum of strings without an explicit type is a string enum, not an empty object") {
        let ir = try SchemaParser.parse(json: ##"{"enum":["a","b"]}"##, name: "e")
        guard case .string(_, _, let values) = ir else { throw TestFailure("expected .string, got \(ir)") }
        try assertEqual(values ?? [], ["a", "b"])
    }

    test("not / if / allOf-style applicators are rejected") {
        try expectError(##"{"type":"string","not":{"const":"x"}}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "not")
        }
        try expectError(##"{"type":"object","if":{"required":["a"]},"then":{"required":["b"]}}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "if")
        }
    }

    test("object minProperties / patternProperties / propertyNames / dependentRequired are rejected") {
        let cases: [(String, String)] = [
            ("minProperties", "1"),
            ("maxProperties", "3"),
            ("patternProperties", ##"{"^x":{"type":"string"}}"##),
            ("propertyNames", ##"{"pattern":"^a"}"##),
            ("dependentRequired", ##"{"a":["b"]}"##),
        ]
        for (kw, value) in cases {
            try expectError(##"{"type":"object","properties":{"a":{"type":"string"}},"\##(kw)":\##(value)}"##) { e in
                guard case .unsupportedConstraint(let got, _) = e else { throw TestFailure("expected unsupportedConstraint for \(kw), got \(e)") }
                try assertEqual(got, kw)
            }
        }
    }

    test("additionalProperties false and true are accepted; a schema value is rejected") {
        _ = try SchemaParser.parse(json: ##"{"type":"object","properties":{"a":{"type":"string"}},"additionalProperties":false}"##, name: "o")
        _ = try SchemaParser.parse(json: ##"{"type":"object","properties":{"a":{"type":"string"}},"additionalProperties":true}"##, name: "o")
        try expectError(##"{"type":"object","additionalProperties":{"type":"integer"}}"##) { e in
            guard case .unsupportedConstraint(let kw, _) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "additionalProperties")
        }
    }

    test("required naming a property that does not exist is unsatisfiable") {
        let json = ##"{"type":"object","properties":{"a":{"type":"string"}},"required":["a","ghost"]}"##
        try expectError(json) { e in
            guard case .invalidConstraint(let kw, let path, let reason) = e else { throw TestFailure("expected invalidConstraint, got \(e)") }
            try assertEqual(kw, "required")
            try assertEqual(path, "#")
            try assertTrue(reason.contains("ghost"), reason)
        }
    }

    test("non-applicable keywords on other types are ignored (spec scoping)") {
        // minLength scopes to strings; on an integer it constrains nothing.
        let ir = try SchemaParser.parse(json: ##"{"type":"integer","minLength":3}"##, name: "i")
        guard case .integer = ir else { throw TestFailure("expected .integer, got \(ir)") }
        // minItems scopes to arrays.
        let ir2 = try SchemaParser.parse(json: ##"{"type":"object","minItems":3}"##, name: "o")
        guard case .object = ir2 else { throw TestFailure("expected .object, got \(ir2)") }
    }

    test("annotation keywords are accepted everywhere") {
        let json = ##"""
        {"$schema":"https://json-schema.org/draft/2020-12/schema","$id":"https://example.com/order","$comment":"c",
         "title":"Order","description":"d","type":"object","deprecated":false,"readOnly":false,"x-vendor":1,
         "properties":{"a":{"type":"string","title":"A","default":"x","examples":["y"],"format":"email","nullable":true,"x-note":"n"}},
         "required":["a"]}
        """##
        _ = try SchemaParser.parse(json: json, name: "Order")
    }

    test("an error inside a definition reports the definition's path, where the fix goes") {
        let json = ##"""
        {"type":"object",
         "$defs":{"Item":{"type":"object","properties":{"price":{"type":"number","multipleOf":0.01}}}},
         "properties":{"items":{"type":"array","items":{"$ref":"#/$defs/Item"}}}}
        """##
        try expectError(json) { e in
            guard case .unsupportedConstraint(let kw, let path) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(kw, "multipleOf")
            try assertEqual(path, "#/$defs/Item/properties/price")
        }
    }

    test("paths for inline nodes walk properties and items") {
        let json = ##"{"type":"object","properties":{"tags":{"type":"array","items":{"type":"string","pattern":"x"}}}}"##
        try expectError(json) { e in
            guard case .unsupportedConstraint(_, let path) = e else { throw TestFailure("expected unsupportedConstraint, got \(e)") }
            try assertEqual(path, "#/properties/tags/items")
        }
    }

    // MARK: - Error descriptions (what the 400 body / exit-2 message says)

    test("error descriptions name the keyword, the path, and the reason") {
        let unsupported = SchemaParser.Error.unsupportedConstraint(keyword: "multipleOf", path: "#/properties/x")
        try assertTrue(unsupported.description.contains("multipleOf"), unsupported.description)
        try assertTrue(unsupported.description.contains("#/properties/x"), unsupported.description)

        let invalid = SchemaParser.Error.invalidConstraint(keyword: "minimum", path: "#/a", reason: "minimum 5 exceeds maximum 1")
        try assertTrue(invalid.description.contains("minimum 5 exceeds maximum 1"), invalid.description)
        try assertTrue(invalid.description.contains("#/a"), invalid.description)

        let external = SchemaParser.Error.externalReference(ref: "https://x/y.json", path: "#/properties/a")
        try assertTrue(external.description.contains("https://x/y.json"), external.description)
        try assertTrue(external.description.lowercased().contains("local"), external.description)

        let unresolved = SchemaParser.Error.unresolvedReference(ref: "#/$defs/Nope", path: "#/properties/a")
        try assertTrue(unresolved.description.contains("#/$defs/Nope"), unresolved.description)

        let cyclic = SchemaParser.Error.cyclicReference(ref: "#/$defs/Node", path: "#/$defs/Node/properties/next")
        try assertTrue(cyclic.description.lowercased().contains("recursive"), cyclic.description)

        try assertTrue(SchemaParser.Error.schemaTooLarge(limit: 512).description.contains("512"))
        try assertTrue(SchemaParser.Error.referenceDepthExceeded(limit: 16, path: "#/x").description.contains("16"))

        // Existing cases keep their established wording (pinned by the --schema tests).
        try assertEqual(SchemaParser.Error.invalidJSON.description, "not valid JSON")
        try assertTrue(SchemaParser.Error.unsupportedType("bigint").description.contains("bigint"))
        try assertTrue(SchemaParser.Error.missingArrayItems.description.contains("items"))
        try assertTrue(SchemaParser.Error.invalidProperty("p").description.contains("\"p\""))
    }

    // MARK: - Regressions: existing behaviour must be untouched

    test("#219 unsupported unions still throw unsupportedType") {
        try expectError(##"{"anyOf":[{"type":"string"},{"type":"number"}]}"##) { e in
            guard case .unsupportedType = e else { throw TestFailure("expected unsupportedType, got \(e)") }
        }
    }

    test("#243 integer and number remain distinct with bounds") {
        let i = try SchemaParser.parse(json: ##"{"type":"integer","minimum":0}"##, name: "x")
        let n = try SchemaParser.parse(json: ##"{"type":"number","minimum":0}"##, name: "x")
        try assertTrue(i != n)
        guard case .boundedInteger = i, case .boundedNumber = n else { throw TestFailure("expected bounded cases") }
    }

    test("parse is deterministic for a schema with shared references and bounds") {
        let json = ##"""
        {"type":"object",
         "$defs":{"A":{"type":"object","properties":{"n":{"type":"integer","minimum":1}}}},
         "properties":{"p":{"$ref":"#/$defs/A"},"q":{"$ref":"#/$defs/A"},"r":{"type":"array","items":{"type":"string"},"maxItems":3}}}
        """##
        let a = try SchemaParser.parse(json: json, name: "t")
        let b = try SchemaParser.parse(json: json, name: "t")
        try assertEqual(a, b)
    }
}
