// ============================================================================
// SchemaIR.swift — Pure intermediate representation for JSON Schema
// Part of ApfelCore — no FoundationModels dependency
//
// The tool-calling surface needs to convert arbitrary OpenAI JSON Schema
// into FoundationModels' DynamicGenerationSchema. Doing the parsing into this
// pure IR first lets us unit-test the parser without the FM framework.
// The adapter from IR -> DynamicGenerationSchema lives in the main target
// and is mechanical enough to not need dedicated tests.
// ============================================================================

import Foundation

/// Pure intermediate representation for the JSON Schema subset ApfelCore supports.
public indirect enum SchemaIR: Equatable, Hashable, Sendable {
    /// An object schema with named child properties.
    case object(name: String, description: String?, properties: [Property])
    /// A string schema, optionally constrained to an enum of allowed values.
    case string(name: String, description: String?, enumValues: [String]?)
    /// A numeric schema. Covers both JSON Schema `integer` and `number`.
    case number(name: String, description: String?)   // covers integer + number
    /// A Boolean schema.
    case bool(name: String, description: String?)
    /// An array schema whose items are described by another schema node.
    case array(itemName: String, items: SchemaIR)

    /// A named property within an object schema.
    public struct Property: Equatable, Hashable, Sendable {
        /// The JSON property name.
        public let name: String
        /// Optional human-readable help text for the property.
        public let description: String?
        /// The property's nested schema.
        public let schema: SchemaIR
        /// Whether the property may be omitted.
        public let isOptional: Bool

        /// Creates a schema property.
        ///
        /// - Parameters:
        ///   - name: The JSON property name.
        ///   - description: Optional human-readable help text.
        ///   - schema: The nested schema for the property.
        ///   - isOptional: Whether the property may be omitted.
        public init(name: String, description: String?, schema: SchemaIR, isOptional: Bool) {
            self.name = name
            self.description = description
            self.schema = schema
            self.isOptional = isOptional
        }
    }
}
