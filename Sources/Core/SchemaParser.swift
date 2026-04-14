// ============================================================================
// SchemaParser.swift — Pure JSON Schema -> SchemaIR converter
// Part of ApfelCore — no FoundationModels dependency
//
// Mirrors the subset of JSON Schema that FoundationModels'
// DynamicGenerationSchema can represent: object, string (with enum),
// number/integer, boolean, and array-of-something.
// ============================================================================

import Foundation

public enum SchemaParser {
    public enum Error: Swift.Error, Equatable {
        case invalidJSON
        case unsupportedType(String)
        case missingArrayItems
    }

    public static func parse(json: String, name: String) throws -> SchemaIR {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidJSON
        }
        return try parseObject(obj, name: name)
    }

    /// Parse a single JSON-Schema node. Defaults to `object` when `type` is
    /// absent (matches OpenAI function-schema conventions where the root
    /// object sometimes omits its type).
    private static func parseObject(_ schema: [String: Any], name: String) throws -> SchemaIR {
        let type = schema["type"] as? String ?? "object"
        let description = schema["description"] as? String

        switch type {
        case "object":
            let propsDict = schema["properties"] as? [String: Any] ?? [:]
            let required = Set(schema["required"] as? [String] ?? [])

            // Sort keys alphabetically so the IR is deterministic regardless
            // of JSON dictionary ordering.
            let sortedKeys = propsDict.keys.sorted()
            var properties: [SchemaIR.Property] = []
            properties.reserveCapacity(sortedKeys.count)
            for key in sortedKeys {
                guard let propSchema = propsDict[key] as? [String: Any] else { continue }
                let childIR = try parseObject(propSchema, name: key)
                let childDesc = propSchema["description"] as? String
                properties.append(.init(
                    name: key,
                    description: childDesc,
                    schema: childIR,
                    isOptional: !required.contains(key)
                ))
            }
            return .object(name: name, description: description, properties: properties)

        case "string":
            let enumValues = schema["enum"] as? [String]
            return .string(name: name, description: description, enumValues: enumValues)

        case "integer", "number":
            return .number(name: name, description: description)

        case "boolean":
            return .bool(name: name, description: description)

        case "array":
            guard let items = schema["items"] as? [String: Any] else {
                throw Error.missingArrayItems
            }
            let inner = try parseObject(items, name: "\(name)_item")
            return .array(itemName: name, items: inner)

        default:
            throw Error.unsupportedType(type)
        }
    }
}
