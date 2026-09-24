// ============================================================================
// SchemaConverter.swift - Convert OpenAI JSON schemas to native FoundationModels types
// Part of apfel - Apple Intelligence from the command line
//
// The pure JSON -> SchemaIR parsing lives in ApfelCore/SchemaParser.swift and
// is unit-tested there. This file keeps only:
//   - the SchemaConversionCache actor
//   - the IR -> DynamicGenerationSchema adapter (a thin, mechanical mapping)
//   - makeArguments (tool-call argument hydration)
//   - the convert() / convertUncached() entry points used by callers
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore

enum SchemaConverter {

    private struct ToolSignature: Hashable, Sendable {
        let type: String
        let name: String
        let description: String?
        let parametersJSON: String?

        init(tool: OpenAITool) {
            type = tool.type
            name = tool.function.name
            description = tool.function.description
            parametersJSON = tool.function.parameters?.value
        }
    }

    private struct CachedSchemaConversion: Sendable {
        let native: [Transcript.ToolDefinition]
        let fallback: [ToolDef]
    }

    private actor SchemaConversionCache {
        static let shared = SchemaConversionCache()
        // Bounded LRU: at capacity, evict only the least-recently-used entry
        // instead of wiping all 64. A full flush let two alternating clients,
        // each with >32 distinct tool sets, churn the whole cache repeatedly (#247).
        private var cache = LRUCache<[ToolSignature], CachedSchemaConversion>(capacity: 64)

        func value(for key: [ToolSignature]) -> CachedSchemaConversion? {
            cache.value(forKey: key)
        }

        func insert(_ value: CachedSchemaConversion, for key: [ToolSignature]) {
            cache.insert(value, forKey: key)
        }
    }

    /// Convert OpenAI tools to native ToolDefinitions.
    /// Returns native definitions for tools that converted successfully,
    /// and ToolDef fallbacks for tools that failed (for text injection).
    static func convert(tools: [OpenAITool]) async -> (native: [Transcript.ToolDefinition], fallback: [ToolDef]) {
        guard !tools.isEmpty else { return ([], []) }

        let key = tools.map(ToolSignature.init)
        if let cached = await SchemaConversionCache.shared.value(for: key) {
            return (cached.native, cached.fallback)
        }

        let converted = convertUncached(tools: tools)
        await SchemaConversionCache.shared.insert(
            CachedSchemaConversion(native: converted.native, fallback: converted.fallback),
            for: key
        )
        return converted
    }

    static func convertUncached(tools: [OpenAITool]) -> (native: [Transcript.ToolDefinition], fallback: [ToolDef]) {
        var native: [Transcript.ToolDefinition] = []
        var fallback: [ToolDef] = []

        for tool in tools {
            let fn = tool.function
            do {
                let ir: SchemaIR
                if let paramsJSON = fn.parameters?.value {
                    ir = try SchemaParser.parse(json: paramsJSON, name: fn.name)
                } else {
                    ir = .object(name: fn.name, description: nil, properties: [])
                }
                let dynSchema = try dynamicSchema(from: ir)
                let schema = try GenerationSchema(root: dynSchema, dependencies: [])
                native.append(Transcript.ToolDefinition(
                    name: fn.name,
                    description: fn.description ?? fn.name,
                    parameters: schema
                ))
            } catch {
                // Conversion failed - fall back to text injection for this tool
                fallback.append(ToolDef(
                    name: fn.name,
                    description: fn.description,
                    parametersJSON: fn.parameters?.value
                ))
            }
        }

        return (native, fallback)
    }

    /// Build a native `GenerationSchema` from a caller-supplied JSON Schema.
    ///
    /// Used by the `response_format: json_schema` server path (#167) to drive
    /// guaranteed structured outputs via schema-guided generation. Reuses the
    /// same JSON -> SchemaIR parser and IR -> DynamicGenerationSchema adapter as
    /// tool-call conversion, so the supported subset is identical.
    ///
    /// - Throws: `SchemaParser.Error` for malformed/unsupported JSON Schema, or
    ///   a `GenerationSchema` construction error. Callers map these to a 400.
    static func generationSchema(fromJSON json: String, name: String) throws -> GenerationSchema {
        let ir = try SchemaParser.parse(json: json, name: name)
        let dynSchema = try dynamicSchema(from: ir)
        return try GenerationSchema(root: dynSchema, dependencies: [])
    }

    /// Convert a tool call's arguments JSON string to GeneratedContent.
    /// Returns nil on failure instead of crashing the process.
    static func makeArguments(_ json: String) -> GeneratedContent? {
        if let content = try? GeneratedContent(json: json) {
            return content
        }
        let sanitized = ToolCallHandler.ensureJSONArguments(json)
        if sanitized != json, let content = try? GeneratedContent(json: sanitized) {
            return content
        }
        return nil
    }

    // MARK: - IR -> DynamicGenerationSchema adapter

    /// Thin mechanical adapter. Tested indirectly via integration tests that
    /// round-trip an OpenAI tool through `convertUncached`. The parsing half
    /// is covered by SchemaParserTests.
    private static func dynamicSchema(from ir: SchemaIR) throws -> DynamicGenerationSchema {
        switch ir {
        case .object(let name, let description, let properties):
            let dynProps: [DynamicGenerationSchema.Property] = try properties.map { prop in
                let childSchema = try dynamicSchema(from: prop.schema)
                return .init(
                    name: prop.name,
                    description: prop.description,
                    schema: childSchema,
                    isOptional: prop.isOptional
                )
            }
            return DynamicGenerationSchema(name: name, description: description, properties: dynProps)

        case .string(let name, let description, let enumValues):
            if let values = enumValues {
                return DynamicGenerationSchema(name: name, description: description, anyOf: values)
            }
            // A plain string leaf must map to the String primitive, not an empty
            // object. The empty-object form produced "{}" for scalar fields under
            // schema-guided generation (#167).
            return DynamicGenerationSchema(type: String.self)

        case .integer:
            // JSON Schema `integer` -> whole numbers only.
            return DynamicGenerationSchema(type: Int.self)

        case .number:
            // JSON Schema `number` -> may be fractional; must map to Double so
            // structured output can produce values like 9.99 (#243). Mapping it
            // to Int made fractional outputs unreachable.
            return DynamicGenerationSchema(type: Double.self)

        case .bool:
            return DynamicGenerationSchema(type: Bool.self)

        case .array(_, let items):
            let inner = try dynamicSchema(from: items)
            return DynamicGenerationSchema(arrayOf: inner)

        // Bounds map onto FoundationModels guides / element limits, which the
        // framework renders as JSON Schema minimum/maximum/minItems/maxItems
        // and enforces during guided generation (#479). Contradictory bounds
        // were already rejected by the parser; the framework does not check.
        case .boundedInteger(_, _, let minimum, let maximum):
            var guides: [GenerationGuide<Int>] = []
            if let minimum { guides.append(.minimum(minimum)) }
            if let maximum { guides.append(.maximum(maximum)) }
            return DynamicGenerationSchema(type: Int.self, guides: guides)

        case .boundedNumber(_, _, let minimum, let maximum):
            var guides: [GenerationGuide<Double>] = []
            if let minimum { guides.append(.minimum(minimum)) }
            if let maximum { guides.append(.maximum(maximum)) }
            return DynamicGenerationSchema(type: Double.self, guides: guides)

        case .boundedArray(_, let items, let minItems, let maxItems):
            let inner = try dynamicSchema(from: items)
            return DynamicGenerationSchema(arrayOf: inner, minimumElements: minItems, maximumElements: maxItems)
        }
    }
}
