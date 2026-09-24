// ============================================================================
// SchemaParser.swift - Pure JSON Schema -> SchemaIR converter
// Part of ApfelCore - no FoundationModels dependency
//
// Mirrors the subset of JSON Schema that FoundationModels'
// DynamicGenerationSchema can represent: object, string (with enum),
// number/integer (with inclusive bounds), boolean, and array-of-something
// (with element-count bounds). Local `$ref` pointers are resolved by
// expanding the referenced definition in place (#479).
//
// Contract (see docs/openai-api-compatibility.md, "JSON Schema support"):
//   - A validation keyword that applies to a node's type and has no faithful
//     mapping onto schema-guided generation is rejected with its path. The
//     caller's contract is never silently weakened.
//   - Annotations (title, description, default, examples, format, ...) and
//     keywords that constrain nothing for the node's type are accepted.
//   - Object and string-enum nodes get names that are unique per distinct
//     shape within one document. FoundationModels hoists named nodes into
//     `$defs` by name, so two differently shaped nodes sharing a name would
//     otherwise be merged and one shape silently lost.
// ============================================================================

import Foundation

public enum SchemaParser {
    public enum Error: Swift.Error, Equatable {
        case invalidJSON
        case unsupportedType(String)
        case missingArrayItems
        case invalidProperty(String)

        // MARK: Reference and constraint errors (#479)
        //
        // `path` is the JSON pointer (`#/properties/price`) of the schema node
        // the error refers to - the location in the caller's document to fix.

        /// A `$ref` that is not a local `#/...` JSON pointer. apfel never reads
        /// other files or URLs to resolve a schema.
        case externalReference(ref: String, path: String)
        /// A local `$ref` whose JSON pointer does not lead to a schema object
        /// in this document.
        case unresolvedReference(ref: String, path: String)
        /// A `$ref` that (directly or through other references) points back at
        /// a schema currently being expanded. Recursive schemas are not supported.
        case cyclicReference(ref: String, path: String)
        /// A chain of references deeper than the parser's limit.
        case referenceDepthExceeded(limit: Int, path: String)
        /// Expanding references produced more schema nodes than the parser's limit.
        case schemaTooLarge(limit: Int)
        /// A validation keyword that applies to the node's type but has no
        /// faithful mapping onto schema-guided generation. Rejected rather than
        /// silently dropped so the caller's contract is never weakened.
        case unsupportedConstraint(keyword: String, path: String)
        /// A keyword whose value is malformed or unsatisfiable, e.g. a
        /// `minimum` above the `maximum`, a negative `minItems`, or a `required`
        /// entry with no matching property.
        case invalidConstraint(keyword: String, path: String, reason: String)
    }

    /// Maximum length of a `$ref` chain (nested definitions referencing
    /// definitions) before the parser gives up. Cycles are detected separately.
    static let referenceDepthLimit = 16

    /// Maximum number of IR nodes one parsed document may expand to. Shared
    /// definitions are expanded at every use, so this bounds the work a
    /// fan-out schema can cause; it is far above anything the on-device
    /// context window could carry anyway.
    static let nodeLimit = 512

    public static func parse(json: String, name: String) throws -> SchemaIR {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidJSON
        }
        return try Document(root: obj).parseRoot(name: name)
    }
}

extension SchemaParser.Error: CustomStringConvertible {
    /// Human-readable, caller-actionable wording. This is the text of the HTTP
    /// 400 body and of the `--schema` exit-2 message.
    public var description: String {
        switch self {
        case .invalidJSON:
            return "not valid JSON"
        case .unsupportedType(let t):
            return "unsupported type \"\(t)\" (supported: object, string, integer, number, boolean, array)"
        case .missingArrayItems:
            return "array schema is missing \"items\""
        case .invalidProperty(let p):
            return "property \"\(p)\" is not a schema object"
        case .externalReference(let ref, let path):
            return "$ref \"\(ref)\" at \(path) is not a local reference; only \"#/...\" JSON pointers into this schema document are resolved, and apfel never fetches external schemas"
        case .unresolvedReference(let ref, let path):
            return "$ref \"\(ref)\" at \(path) does not resolve to a schema object in this document"
        case .cyclicReference(let ref, let path):
            return "$ref \"\(ref)\" at \(path) is recursive; recursive schemas are not supported"
        case .referenceDepthExceeded(let limit, let path):
            return "$ref chain at \(path) is nested deeper than \(limit) levels"
        case .schemaTooLarge(let limit):
            return "schema expands to more than \(limit) nodes after resolving references"
        case .unsupportedConstraint(let keyword, let path):
            return "\"\(keyword)\" at \(path) cannot be enforced by on-device schema-guided generation; remove it or express the constraint with a supported keyword (see docs/openai-api-compatibility.md, \"JSON Schema support\")"
        case .invalidConstraint(let keyword, let path, let reason):
            return "\"\(keyword)\" at \(path) is invalid: \(reason)"
        }
    }
}

// MARK: - Document walk

extension SchemaParser {
    private typealias JSONObject = [String: Any]

    /// One parse of one schema document. Holds the raw document for `$ref`
    /// resolution, the unique-name registry and the node budget.
    private final class Document {
        private let root: JSONObject
        private var names = NameRegistry()
        private var nodeCount = 0

        init(root: JSONObject) {
            self.root = root
        }

        func parseRoot(name: String) throws -> SchemaIR {
            names.reserve(name)
            // The root document is being expanded, so a `$ref` back to `#` is a cycle.
            return try parseNode(root, name: name, path: "#", activeRefs: ["#"], isRoot: true).ir
        }

        // MARK: Node

        /// Parses one schema node. `name` is the name the node would get from its
        /// position (property key, `<array>_item`, or the caller's root name); a
        /// node reached through `$ref` is named after the referenced definition
        /// instead, except at the root, which keeps the caller's name.
        private func parseNode(
            _ raw: JSONObject, name positional: String, path: String, activeRefs: [String], isRoot: Bool = false
        ) throws -> ParsedNode {
            let resolved = try resolve(raw, path: path, activeRefs: activeRefs)
            let node = resolved.node
            let path = resolved.path
            let name = isRoot ? positional : (resolved.definitionName ?? positional)
            let description = node["description"] as? String

            nodeCount += 1
            guard nodeCount <= SchemaParser.nodeLimit else {
                throw Error.schemaTooLarge(limit: SchemaParser.nodeLimit)
            }

            let type = inferType(node)
            try rejectApplicators(node, path: path)
            if type != "string" {
                // `enum` / `const` are representable only as string choices.
                for keyword in ["enum", "const"] where node[keyword] != nil {
                    throw Error.unsupportedConstraint(keyword: keyword, path: path)
                }
            }

            let ir = try parseTyped(type, node: node, name: name, description: description, path: path,
                                    activeRefs: resolved.activeRefs, isRoot: isRoot)
            return ParsedNode(ir: ir, nullable: resolved.nullable, description: description)
        }

        private struct ParsedNode {
            let ir: SchemaIR
            let nullable: Bool
            /// The resolved node's own `description`, for the enclosing property.
            let description: String?
        }

        private func parseTyped(
            _ type: String, node: JSONObject, name: String, description: String?, path: String,
            activeRefs: [String], isRoot: Bool
        ) throws -> SchemaIR {
            switch type {
            case "object":
                return try parseObject(node, name: name, description: description, path: path,
                                       activeRefs: activeRefs, isRoot: isRoot)

            case "string":
                try rejectKeywords(node, path: path, ["minLength", "maxLength", "pattern",
                                                      "contentEncoding", "contentMediaType", "contentSchema"])
                let values = try enumValues(node, path: path)
                guard let values else {
                    return .string(name: name, description: description, enumValues: nil)
                }
                // Enums are named nodes in FoundationModels - unique per shape.
                return names.allocate(preferred: name, isRoot: isRoot) {
                    .string(name: $0, description: description, enumValues: values)
                }

            case "integer":
                try rejectKeywords(node, path: path, ["multipleOf"])
                let (lo, hi) = try integerBounds(node, path: path)
                if lo == nil && hi == nil {
                    return .integer(name: name, description: description)
                }
                return .boundedInteger(name: name, description: description, minimum: lo, maximum: hi)

            case "number":
                try rejectKeywords(node, path: path, ["multipleOf"])
                let (lo, hi) = try numberBounds(node, path: path)
                if lo == nil && hi == nil {
                    return .number(name: name, description: description)
                }
                return .boundedNumber(name: name, description: description, minimum: lo, maximum: hi)

            case "boolean":
                return .bool(name: name, description: description)

            case "array":
                try rejectKeywords(node, path: path, ["contains", "minContains", "maxContains",
                                                      "prefixItems", "additionalItems"])
                if let unique = node["uniqueItems"], SchemaParser.jsonBool(unique) != false {
                    throw Error.unsupportedConstraint(keyword: "uniqueItems", path: path)
                }
                if let unevaluated = node["unevaluatedItems"], SchemaParser.jsonBool(unevaluated) == nil {
                    throw Error.unsupportedConstraint(keyword: "unevaluatedItems", path: path)
                }
                guard let items = node["items"] as? JSONObject else {
                    throw Error.missingArrayItems
                }
                let (lo, hi) = try arrayBounds(node, path: path)
                let inner = try parseNode(items, name: "\(name)_item", path: path + "/items",
                                          activeRefs: activeRefs).ir
                if lo == nil && hi == nil {
                    return .array(itemName: name, items: inner)
                }
                return .boundedArray(itemName: name, items: inner, minItems: lo, maxItems: hi)

            default:
                throw Error.unsupportedType(type)
            }
        }

        private func parseObject(
            _ node: JSONObject, name: String, description: String?, path: String,
            activeRefs: [String], isRoot: Bool
        ) throws -> SchemaIR {
            try rejectKeywords(node, path: path, ["patternProperties", "propertyNames", "minProperties",
                                                  "maxProperties", "dependentRequired", "dependentSchemas",
                                                  "dependencies"])
            // Generation never emits undeclared properties, so any boolean
            // `additionalProperties` / `unevaluatedProperties` is satisfied. A
            // schema value describes a free-form map, which cannot be produced.
            for keyword in ["additionalProperties", "unevaluatedProperties"] {
                if let value = node[keyword], SchemaParser.jsonBool(value) == nil {
                    throw Error.unsupportedConstraint(keyword: keyword, path: path)
                }
            }

            let propsDict = node["properties"] as? JSONObject ?? [:]
            let required = try requiredNames(node, declared: Set(propsDict.keys), path: path)

            // Sort keys alphabetically so the IR is deterministic regardless
            // of JSON dictionary ordering.
            let sortedKeys = propsDict.keys.sorted()
            var properties: [SchemaIR.Property] = []
            properties.reserveCapacity(sortedKeys.count)
            for key in sortedKeys {
                guard let propSchema = propsDict[key] as? JSONObject else {
                    throw Error.invalidProperty(key)
                }
                let child = try parseNode(propSchema, name: key, path: path + "/properties/" + SchemaParser.escapePointerSegment(key),
                                          activeRefs: activeRefs)
                // A nullable property is optional regardless of the `required`
                // list (FoundationModels cannot represent "present but null").
                properties.append(.init(
                    name: key,
                    description: child.description,
                    schema: child.ir,
                    isOptional: !required.contains(key) || child.nullable
                ))
            }
            return names.allocate(preferred: name, isRoot: isRoot) {
                .object(name: $0, description: description, properties: properties)
            }
        }

        // MARK: Type inference

        /// Explicit `type` wins. Without one, `properties` means object and a
        /// string `enum` / `const` means string (a Pydantic `Literal[...]` emits
        /// `{"enum": [...]}` without a type). Anything else defaults to object,
        /// matching OpenAI function schemas whose root omits `type`.
        private func inferType(_ node: JSONObject) -> String {
            if let explicit = node["type"] as? String { return explicit }
            if node["properties"] != nil { return "object" }
            if let values = node["enum"] as? [Any], !values.isEmpty, values.allSatisfy({ $0 is String }) {
                return "string"
            }
            if node["const"] is String { return "string" }
            return "object"
        }

        // MARK: Keyword rejection

        /// Applicators that combine or condition subschemas have no counterpart
        /// in guided generation for any type. (`allOf` and multi-type unions are
        /// rejected earlier by `normalizeUnion`.)
        private func rejectApplicators(_ node: JSONObject, path: String) throws {
            try rejectKeywords(node, path: path, ["not", "if", "then", "else", "$dynamicRef", "$recursiveRef"])
        }

        private func rejectKeywords(_ node: JSONObject, path: String, _ keywords: [String]) throws {
            for keyword in keywords where node[keyword] != nil {
                throw Error.unsupportedConstraint(keyword: keyword, path: path)
            }
        }

        // MARK: Constraint extraction

        private func enumValues(_ node: JSONObject, path: String) throws -> [String]? {
            var values: [String]? = nil
            if let raw = node["enum"] {
                guard let members = raw as? [Any] else {
                    throw Error.invalidConstraint(keyword: "enum", path: path, reason: "must be an array")
                }
                guard !members.isEmpty else {
                    throw Error.invalidConstraint(keyword: "enum", path: path, reason: "an empty enum can never be satisfied")
                }
                let strings = members.compactMap { $0 as? String }
                guard strings.count == members.count else {
                    throw Error.invalidConstraint(keyword: "enum", path: path, reason: "only string members are supported")
                }
                values = strings
            }
            if let raw = node["const"] {
                guard let constant = raw as? String else {
                    throw Error.invalidConstraint(keyword: "const", path: path, reason: "only a string constant is supported")
                }
                if let values, !values.contains(constant) {
                    throw Error.invalidConstraint(keyword: "const", path: path, reason: "\"\(constant)\" is not one of the enum values")
                }
                values = [constant]
            }
            return values
        }

        private func requiredNames(_ node: JSONObject, declared: Set<String>, path: String) throws -> Set<String> {
            guard let raw = node["required"] else { return [] }
            guard let list = raw as? [Any], let names = list as? [String] else {
                throw Error.invalidConstraint(keyword: "required", path: path, reason: "must be an array of property names")
            }
            // A required property that is never declared can never be generated,
            // so every output would violate the schema.
            if let ghost = names.first(where: { !declared.contains($0) }) {
                throw Error.invalidConstraint(keyword: "required", path: path,
                                              reason: "names property \"\(ghost)\", which is not declared in properties")
            }
            return Set(names)
        }

        private func integerBounds(_ node: JSONObject, path: String) throws -> (Int?, Int?) {
            var lo: Int? = nil
            var hi: Int? = nil
            if let raw = node["minimum"] {
                var bound = try number(raw, keyword: "minimum", path: path)
                // Draft-4 boolean flag: `minimum` is exclusive.
                if SchemaParser.jsonBool(node["exclusiveMinimum"]) == true, bound == bound.rounded() { bound += 1 }
                lo = try integer(bound.rounded(.up), keyword: "minimum", path: path)
            }
            if let raw = node["exclusiveMinimum"], SchemaParser.jsonBool(raw) == nil {
                let bound = try number(raw, keyword: "exclusiveMinimum", path: path)
                let inclusive = try integer(bound.rounded(.down) + 1, keyword: "exclusiveMinimum", path: path)
                lo = max(lo ?? inclusive, inclusive)
            }
            if let raw = node["maximum"] {
                var bound = try number(raw, keyword: "maximum", path: path)
                if SchemaParser.jsonBool(node["exclusiveMaximum"]) == true, bound == bound.rounded() { bound -= 1 }
                hi = try integer(bound.rounded(.down), keyword: "maximum", path: path)
            }
            if let raw = node["exclusiveMaximum"], SchemaParser.jsonBool(raw) == nil {
                let bound = try number(raw, keyword: "exclusiveMaximum", path: path)
                let inclusive = try integer(bound.rounded(.up) - 1, keyword: "exclusiveMaximum", path: path)
                hi = min(hi ?? inclusive, inclusive)
            }
            if let lo, let hi, lo > hi {
                throw Error.invalidConstraint(keyword: "minimum", path: path, reason: "minimum \(lo) exceeds maximum \(hi)")
            }
            return (lo, hi)
        }

        private func numberBounds(_ node: JSONObject, path: String) throws -> (Double?, Double?) {
            var lo: Double? = nil
            var hi: Double? = nil
            if let raw = node["minimum"] {
                let bound = try number(raw, keyword: "minimum", path: path)
                lo = SchemaParser.jsonBool(node["exclusiveMinimum"]) == true ? bound.nextUp : bound
            }
            if let raw = node["exclusiveMinimum"], SchemaParser.jsonBool(raw) == nil {
                // x > e is exactly x >= nextUp(e) over Double.
                let inclusive = try number(raw, keyword: "exclusiveMinimum", path: path).nextUp
                lo = max(lo ?? inclusive, inclusive)
            }
            if let raw = node["maximum"] {
                let bound = try number(raw, keyword: "maximum", path: path)
                hi = SchemaParser.jsonBool(node["exclusiveMaximum"]) == true ? bound.nextDown : bound
            }
            if let raw = node["exclusiveMaximum"], SchemaParser.jsonBool(raw) == nil {
                let inclusive = try number(raw, keyword: "exclusiveMaximum", path: path).nextDown
                hi = min(hi ?? inclusive, inclusive)
            }
            if let lo, let hi, lo > hi {
                throw Error.invalidConstraint(keyword: "minimum", path: path, reason: "minimum \(lo) exceeds maximum \(hi)")
            }
            return (lo, hi)
        }

        private func arrayBounds(_ node: JSONObject, path: String) throws -> (Int?, Int?) {
            func count(_ keyword: String) throws -> Int? {
                guard let raw = node[keyword] else { return nil }
                let value = try integer(try number(raw, keyword: keyword, path: path), keyword: keyword, path: path)
                guard value >= 0 else {
                    throw Error.invalidConstraint(keyword: keyword, path: path, reason: "must not be negative")
                }
                return value
            }
            let lo = try count("minItems")
            let hi = try count("maxItems")
            if let lo, let hi, lo > hi {
                throw Error.invalidConstraint(keyword: "minItems", path: path, reason: "minItems \(lo) exceeds maxItems \(hi)")
            }
            return (lo, hi)
        }

        private func number(_ raw: Any, keyword: String, path: String) throws -> Double {
            guard let value = SchemaParser.jsonNumber(raw) else {
                throw Error.invalidConstraint(keyword: keyword, path: path, reason: "must be a number")
            }
            return value.doubleValue
        }

        private func integer(_ value: Double, keyword: String, path: String) throws -> Int {
            guard let exact = Int(exactly: value) else {
                throw Error.invalidConstraint(keyword: keyword, path: path, reason: "must be a whole number within integer range")
            }
            return exact
        }

        // MARK: $ref resolution

        private struct Resolved {
            let node: JSONObject
            let nullable: Bool
            /// JSON pointer of `node` in the document (the referenced location
            /// after a `$ref`, so errors point at where the fix goes).
            let path: String
            /// Last pointer segment of the definition this node was resolved
            /// from, used as the node's name. `nil` for inline nodes.
            let definitionName: String?
            /// Pointers currently being expanded on this branch, for cycle detection.
            let activeRefs: [String]
        }

        /// Unwraps nullable unions and follows `$ref` chains until the node is a
        /// plain schema object. Sibling keywords of a `$ref` overlay the
        /// referenced definition (so a per-use `description` wins).
        private func resolve(_ raw: JSONObject, path: String, activeRefs: [String]) throws -> Resolved {
            var node = raw
            var nullable = false
            var path = path
            var refs = activeRefs
            var definitionName: String? = nil

            while true {
                let (unwrapped, isNullable) = try normalizeUnion(node)
                node = unwrapped
                nullable = nullable || isNullable

                guard let rawRef = node["$ref"] else { break }
                guard let ref = rawRef as? String else {
                    throw Error.invalidConstraint(keyword: "$ref", path: path, reason: "must be a string")
                }
                let target = try resolvePointer(ref, at: path)
                if refs.contains(target.path) {
                    throw Error.cyclicReference(ref: ref, path: path)
                }
                refs.append(target.path)
                if refs.count > SchemaParser.referenceDepthLimit {
                    throw Error.referenceDepthExceeded(limit: SchemaParser.referenceDepthLimit, path: path)
                }
                var merged = target.node
                for (key, value) in node where key != "$ref" {
                    merged[key] = value
                }
                node = merged
                path = target.path
                definitionName = target.lastSegment ?? definitionName
            }
            return Resolved(node: node, nullable: nullable, path: path, definitionName: definitionName, activeRefs: refs)
        }

        private struct PointerTarget {
            let node: JSONObject
            /// Canonical `#/a/b` form (decoded, then re-escaped) so two spellings
            /// of one location compare equal for cycle detection.
            let path: String
            let lastSegment: String?
        }

        private func resolvePointer(_ ref: String, at path: String) throws -> PointerTarget {
            guard ref.hasPrefix("#") else {
                throw Error.externalReference(ref: ref, path: path)
            }
            let fragment = ref.dropFirst()
            if fragment.isEmpty {
                return PointerTarget(node: root, path: "#", lastSegment: nil)
            }
            // A plain-name fragment (`#Address`, i.e. `$anchor`) is not a JSON pointer.
            guard fragment.hasPrefix("/") else {
                throw Error.unresolvedReference(ref: ref, path: path)
            }
            var segments: [String] = []
            for rawSegment in fragment.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
                guard let decoded = String(rawSegment).removingPercentEncoding else {
                    throw Error.unresolvedReference(ref: ref, path: path)
                }
                segments.append(decoded.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~"))
            }
            var current: Any = root
            for segment in segments {
                if let object = current as? JSONObject, let next = object[segment] {
                    current = next
                } else if let array = current as? [Any], let index = Int(segment), array.indices.contains(index) {
                    current = array[index]
                } else {
                    throw Error.unresolvedReference(ref: ref, path: path)
                }
            }
            guard let node = current as? JSONObject else {
                throw Error.unresolvedReference(ref: ref, path: path)
            }
            let canonical = "#/" + segments.map(SchemaParser.escapePointerSegment).joined(separator: "/")
            return PointerTarget(node: node, path: canonical, lastSegment: segments.last)
        }

        /// Normalizes the supported nullable-union and type-array forms.
        ///
        /// Returns the unwrapped single-type node plus whether the original node was
        /// nullable. Only the `[X, {"type":"null"}]` (anyOf/oneOf) and
        /// `["<type>","null"]` (type array) patterns are supported; every other
        /// union (`allOf`, multi-type unions, type arrays without exactly one null)
        /// throws `unsupportedType` so callers fall back to text injection / 400.
        /// Idempotent: a node with no union is returned unchanged with `nullable: false`.
        private func normalizeUnion(_ schema: JSONObject) throws -> (node: JSONObject, nullable: Bool) {
            for key in ["anyOf", "oneOf"] {
                guard let raw = schema[key] else { continue }
                guard let rawArr = raw as? [Any] else { throw Error.unsupportedType(key) }
                let branches = rawArr.compactMap { $0 as? JSONObject }
                guard branches.count == rawArr.count else { throw Error.unsupportedType(key) }
                let nonNull = branches.filter { ($0["type"] as? String) != "null" }
                let hasNull = branches.contains { ($0["type"] as? String) == "null" }
                guard branches.count == 2, hasNull, nonNull.count == 1 else {
                    throw Error.unsupportedType(key)
                }
                var node = nonNull[0]
                // Preserve an outer description if the surviving branch lacks its own.
                if node["description"] == nil, let outer = schema["description"] {
                    node["description"] = outer
                }
                return (node, true)
            }

            // `allOf` is an intersection we cannot represent.
            if schema["allOf"] != nil {
                throw Error.unsupportedType("allOf")
            }

            // `type` as an array: only exactly [<type>, "null"] (any order) is supported.
            if let rawType = schema["type"], !(rawType is String) {
                guard let typeArr = rawType as? [Any] else {
                    throw Error.unsupportedType("type")
                }
                let types = typeArr.compactMap { $0 as? String }
                let nonNull = types.filter { $0 != "null" }
                guard types.count == typeArr.count, typeArr.count == 2,
                      types.contains("null"), nonNull.count == 1 else {
                    throw Error.unsupportedType("type: [\(types.joined(separator: ","))]")
                }
                var node = schema
                node["type"] = nonNull[0]
                return (node, true)
            }

            return (schema, false)
        }
    }

    // MARK: - Unique names

    /// Names for FoundationModels' named nodes (objects, string enums). The
    /// first node to claim a name keeps it; a later node with the same name
    /// reuses it only when its shape is identical, otherwise it gets a numbered
    /// suffix. The root's name is reserved before its children are parsed so a
    /// nested node cannot take it.
    private struct NameRegistry {
        private enum Entry: Equatable {
            case reservedForRoot
            case node(SchemaIR)
        }
        private var entries: [String: Entry] = [:]

        mutating func reserve(_ name: String) {
            entries[name] = .reservedForRoot
        }

        mutating func allocate(preferred: String, isRoot: Bool, build: (String) -> SchemaIR) -> SchemaIR {
            var candidate = preferred
            var suffix = 2
            while true {
                let ir = build(candidate)
                switch entries[candidate] {
                case .none:
                    entries[candidate] = .node(ir)
                    return ir
                case .reservedForRoot where isRoot:
                    entries[candidate] = .node(ir)
                    return ir
                case .node(let existing) where existing == ir:
                    return ir
                default:
                    candidate = "\(preferred)_\(suffix)"
                    suffix += 1
                }
            }
        }
    }

    // MARK: - JSON helpers

    /// RFC 6901 escaping for one pointer segment.
    private static func escapePointerSegment(_ segment: String) -> String {
        segment.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }

    /// A JSON number, or `nil` for anything else - including JSON booleans,
    /// which Foundation also represents as `NSNumber`.
    private static func jsonNumber(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number
    }

    /// A JSON boolean, or `nil` for anything else - including JSON numbers.
    private static func jsonBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}
