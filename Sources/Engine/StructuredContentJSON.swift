// ============================================================================
// StructuredContentJSON.swift - GeneratedContent -> schema-ordered JSON (#532)
//
// The runtime's `GeneratedContent.jsonString` lists keys in a different order
// on every snapshot (measured on macOS 27.0.1), so apfel serializes guided
// output itself: object members follow the schema's property order, which is
// also the order the model generates them in. Both the streamed and the
// non-streamed paths go through here, so their bytes match.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

/// Renders guided-generation content as JSON in schema property order.
package struct StructuredJSONRenderer: Sendable {
    private let schema: SchemaIR?

    /// - Parameter schema: the parsed schema that drives member order. Keys the
    ///   schema does not name (or a nil schema) follow in sorted order.
    package init(schema: SchemaIR?) {
        self.schema = schema
    }

    /// Parse `schemaJSON` for its property order. The schema was already
    /// validated when the GenerationSchema was built; a parse failure here
    /// only loses the order, never the content.
    package init(schemaJSON: String, name: String) {
        self.init(schema: try? SchemaParser.parse(json: schemaJSON, name: name))
    }

    /// The complete document for a finished response.
    package func finalJSON(_ content: GeneratedContent) -> String {
        StructuredJSON.serialize(partial(content, schema: schema))
    }

    /// The stable, append-only prefix of a streaming snapshot.
    package func stablePrefix(_ content: GeneratedContent) -> String {
        StructuredJSON.stablePrefix(partial(content, schema: schema))
    }

    package func partial(_ content: GeneratedContent, schema: SchemaIR?) -> PartialJSON {
        let complete = content.isComplete
        switch content.kind {
        case .structure(let properties, _):
            let order = Self.propertyOrder(schema)
            let known = order.map(\.name).filter { properties[$0] != nil }
            let extra = properties.keys.filter { key in !order.contains { $0.name == key } }.sorted()
            let members = (known + extra).map { key in
                PartialJSON.Member(
                    key: key,
                    value: partial(properties[key]!, schema: order.first { $0.name == key }?.schema))
            }
            return .object(members, complete: complete)
        case .array(let items):
            let itemSchema = Self.itemSchema(schema)
            return .array(items.map { partial($0, schema: itemSchema) }, complete: complete)
        case .string(let s):
            return .string(s, complete: complete)
        case .number(let d):
            return .number(d, complete: complete)
        case .bool(let b):
            return .bool(b, complete: complete)
        case .null:
            return .null
        @unknown default:
            return .string(content.jsonString, complete: complete)
        }
    }

    private static func propertyOrder(_ schema: SchemaIR?) -> [SchemaIR.Property] {
        if case .object(_, _, let properties)? = schema { return properties }
        return []
    }

    private static func itemSchema(_ schema: SchemaIR?) -> SchemaIR? {
        switch schema {
        case .array(_, let items)?: return items
        case .boundedArray(_, let items, _, _)?: return items
        default: return nil
        }
    }
}
