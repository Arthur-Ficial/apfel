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

public indirect enum SchemaIR: Equatable, Sendable {
    case object(name: String, description: String?, properties: [Property])
    case string(name: String, description: String?, enumValues: [String]?)
    case number(name: String, description: String?)   // covers integer + number
    case bool(name: String, description: String?)
    case array(itemName: String, items: SchemaIR)

    public struct Property: Equatable, Sendable {
        public let name: String
        public let description: String?
        public let schema: SchemaIR
        public let isOptional: Bool

        public init(name: String, description: String?, schema: SchemaIR, isOptional: Bool) {
            self.name = name
            self.description = description
            self.schema = schema
            self.isOptional = isOptional
        }
    }
}
