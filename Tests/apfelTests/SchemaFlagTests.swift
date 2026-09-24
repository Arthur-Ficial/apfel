// ============================================================================
// SchemaFlagTests.swift - Unit tests for the --schema flag (#361)
// Parse behavior, parse-time JSON Schema validation, schema-name derivation,
// and every cross-flag rejection. Error tests verify CLIParseError + message.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI

private let validSchema = """
{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name"]}
"""

func runSchemaFlagTests() {

    // ========================================================================
    // MARK: - Happy path
    // ========================================================================

    test("--schema reads the file and stores raw JSON") {
        let args = try CLIArguments.parse(["--schema", "person.schema.json", "extract"], readFile: { path in
            guard path == "person.schema.json" else { throw CLIParseError("unexpected path") }
            return validSchema
        })
        try assertEqual(args.mode, .single)
        try assertEqual(args.schemaJSON, validSchema)
        try assertEqual(args.prompt, "extract")
    }

    test("--schema derives the schema name from the filename stem") {
        let args = try CLIArguments.parse(["--schema", "/tmp/invoice.schema.json", "x"], readFile: { _ in validSchema })
        try assertEqual(args.schemaName, "invoice")
    }

    test("--schema works with piped-style empty prompt (prompt filled later)") {
        let args = try CLIArguments.parse(["--schema", "s.json"], readFile: { _ in validSchema })
        try assertEqual(args.mode, .single)
        try assertEqual(args.prompt, "")
        try assertEqual(args.schemaJSON, validSchema)
    }

    // ========================================================================
    // MARK: - Schema name derivation (pure helper)
    // ========================================================================

    test("schemaName strips directory and all extensions") {
        try assertEqual(CLIArguments.schemaName(fromPath: "/a/b/invoice.schema.json"), "invoice")
    }

    test("schemaName sanitizes non-alphanumerics to underscores") {
        try assertEqual(CLIArguments.schemaName(fromPath: "My Schema-v2.json"), "My_Schema_v2")
    }

    test("schemaName falls back to 'schema' for empty stems") {
        try assertEqual(CLIArguments.schemaName(fromPath: ".json"), "schema")
    }

    // ========================================================================
    // MARK: - Parse errors
    // ========================================================================

    test("--schema without a value throws") {
        do {
            _ = try CLIArguments.parse(["--schema"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
        }
    }

    test("--schema with unreadable file throws with the path in the message") {
        do {
            _ = try CLIArguments.parse(["--schema", "missing.json", "x"], readFile: { _ in
                throw NSError(domain: "test", code: 1)
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("missing.json"))
        }
    }

    test("--schema with malformed JSON throws a schema error at parse time") {
        do {
            _ = try CLIArguments.parse(["--schema", "bad.json", "x"], readFile: { _ in "{not json" })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("schema"))
        }
    }

    test("--schema with unsupported schema type throws at parse time") {
        do {
            _ = try CLIArguments.parse(["--schema", "odd.json", "x"], readFile: { _ in
                "{\"type\":\"tuple\"}"
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("schema"))
        }
    }

    test("--schema with a $ref/$defs schema is accepted at parse time (#479)") {
        let args = try CLIArguments.parse(["--schema", "order.schema.json", "x"], readFile: { _ in
            ##"{"type":"object","$defs":{"A":{"type":"object","properties":{"c":{"type":"string"}}}},"properties":{"a":{"$ref":"#/$defs/A"}}}"##
        })
        try assertNotNil(args.schemaJSON)
    }

    test("--schema with an unrepresentable constraint is a usage error naming keyword, path and file (#479)") {
        do {
            _ = try CLIArguments.parse(["--schema", "strict.schema.json", "x"], readFile: { _ in
                ##"{"type":"object","properties":{"code":{"type":"string","pattern":"^[A-Z]{3}$"}}}"##
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("strict.schema.json"), e.message)
            try assertTrue(e.message.contains("pattern"), e.message)
            try assertTrue(e.message.contains("#/properties/code"), e.message)
        }
    }

    test("--schema with an external $ref is a usage error that says apfel does not fetch it (#479)") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "x"], readFile: { _ in
                ##"{"type":"object","properties":{"a":{"$ref":"https://example.com/a.json"}}}"##
            })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("https://example.com/a.json"), e.message)
            try assertTrue(e.message.lowercased().contains("local"), e.message)
        }
    }

    test("--schema - (stdin) is rejected") {
        do {
            _ = try CLIArguments.parse(["--schema", "-", "x"])
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("stdin"))
        }
    }

    // ========================================================================
    // MARK: - Cross-flag rejections
    // ========================================================================

    test("--schema with --chat throws") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "--chat"], readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("--chat"))
        }
    }

    test("--schema with --stream throws") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "--stream", "x"], readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("--stream"))
        }
    }

    test("--schema with --count-tokens throws") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "--count-tokens", "x"], readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("--count-tokens"))
        }
    }

    test("--schema with --serve throws") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "--serve"], readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("--serve"))
        }
    }

    test("--schema with --mcp throws") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "--mcp", "server.py", "x"], readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("--mcp"))
        }
    }

    test("--schema with APFEL_MCP env throws (same rule as --mcp)") {
        do {
            _ = try CLIArguments.parse(["--schema", "s.json", "x"],
                                       env: ["APFEL_MCP": "server.py"],
                                       readFile: { _ in validSchema })
            try assertTrue(false, "should have thrown")
        } catch let e as CLIParseError {
            try assertTrue(e.message.contains("--schema"))
            try assertTrue(e.message.contains("MCP"))
        }
    }

    // ========================================================================
    // MARK: - Flag table membership
    // ========================================================================

    test("knownFlags contains --schema") {
        try assertTrue(CLIArguments.knownFlags.contains("--schema"))
    }
}
