// ============================================================================
// StructuredJSONStreamTests.swift - #532: streamed schema-constrained JSON
// must be append-only. Every emitted delta is a prefix of the final document,
// so a client that concatenates the deltas gets exactly the non-streamed JSON.
//
// The snapshot sequences below mirror what FoundationModels produced on
// macOS 27.0.1 (probe, 2026-11-13): keys arrive in schema order, a string
// grows in place, and a partial number can CHANGE before it completes
// (rating went 4 -> 4.5), so numbers are held back until complete.
// ============================================================================

import Foundation
import FoundationModels
import ApfelCore
import ApfelEngine

private func obj(_ members: [(String, PartialJSON)], complete: Bool) -> PartialJSON {
    .object(members.map { PartialJSON.Member(key: $0.0, value: $0.1) }, complete: complete)
}

func runStructuredJSONStreamTests() {

    test("serialize: compact, keys in the given order, integral numbers without .0") {
        let value = obj([
            ("count", .number(4, complete: true)),
            ("lines", .array([.string("a", complete: true), .string("b", complete: true)], complete: true)),
            ("rating", .number(4.5, complete: true)),
            ("done", .bool(true, complete: true)),
            ("none", .null),
        ], complete: true)
        try assertEqual(StructuredJSON.serialize(value),
                        #"{"count": 4, "lines": ["a", "b"], "rating": 4.5, "done": true, "none": null}"#)
    }

    test("serialize: the output parses as JSON with the same values") {
        let value = obj([("t", .string("quote \" slash \\ nl \n tab \t ctl \u{01} é 🌊", complete: true))], complete: true)
        let text = StructuredJSON.serialize(value)
        let parsed = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String]
        try assertEqual(parsed?["t"], "quote \" slash \\ nl \n tab \t ctl \u{01} é 🌊")
        try assertTrue(text.contains(#"\u0001"#), "control characters are \\u escaped: \(text)")
    }

    test("stablePrefix: an open string is emitted without its closing quote") {
        let value = obj([("title", .string("Wh", complete: false))], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(value), #"{"title": "Wh"#)
    }

    test("stablePrefix: a partial number is held back, the key before it is stable") {
        let value = obj([("count", .number(4, complete: true)), ("rating", .number(4, complete: false))], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(value), #"{"count": 4, "rating": "#)
    }

    test("stablePrefix: a partial bool is held back") {
        let value = obj([("done", .bool(false, complete: false))], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(value), #"{"done": "#)
    }

    test("stablePrefix: members after the first incomplete one are not emitted") {
        let value = obj([
            ("a", .string("x", complete: false)),
            ("b", .string("y", complete: true)),
        ], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(value), #"{"a": "x"#)
    }

    test("stablePrefix: open arrays and nested objects stay open") {
        let value = obj([
            ("lines", .array([.string("one", complete: true), .string("tw", complete: false)], complete: false)),
        ], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(value), #"{"lines": ["one", "tw"#)
        let empty = obj([("lines", .array([], complete: false))], complete: false)
        try assertEqual(StructuredJSON.stablePrefix(empty), #"{"lines": ["#)
    }

    test("stablePrefix: a complete document equals its serialization") {
        let value = obj([("a", .number(1, complete: true))], complete: true)
        try assertEqual(StructuredJSON.stablePrefix(value), StructuredJSON.serialize(value))
    }

    test("stablePrefix: an empty incomplete root object is just the brace") {
        try assertEqual(StructuredJSON.stablePrefix(obj([], complete: false)), "{")
    }

    test("every stable prefix of the probe sequence is a prefix of the final document") {
        // Shape of the macOS 27 probe: count, lines, rating (4 -> 4.5), title.
        let lines = [PartialJSON.string("Whispers.", complete: true), .string("Waves", complete: true)]
        let snapshots: [PartialJSON] = [
            obj([], complete: false),
            obj([("count", .number(4, complete: false))], complete: false),
            obj([("count", .number(4, complete: true)), ("lines", .array([], complete: false))], complete: false),
            obj([("count", .number(4, complete: true)), ("lines", .array([.string("Whis", complete: false)], complete: false))], complete: false),
            obj([("count", .number(4, complete: true)), ("lines", .array(lines, complete: true)), ("rating", .number(4, complete: false))], complete: false),
            obj([("count", .number(4, complete: true)), ("lines", .array(lines, complete: true)), ("rating", .number(4.5, complete: true)), ("title", .string("Ser", complete: false))], complete: false),
            obj([("count", .number(4, complete: true)), ("lines", .array(lines, complete: true)), ("rating", .number(4.5, complete: true)), ("title", .string("Serenade", complete: true))], complete: true),
        ]
        let final = StructuredJSON.serialize(snapshots.last!)
        var streamer = StructuredJSONStreamer()
        var deltas: [String] = []
        for snap in snapshots {
            let prefix = StructuredJSON.stablePrefix(snap)
            try assertTrue(final.unicodeScalars.starts(with: prefix.unicodeScalars),
                           "stable prefix \(prefix) is not a prefix of \(final)")
            if let d = streamer.advance(to: prefix) { deltas.append(d) }
        }
        if let tail = try streamer.finish(with: final) { deltas.append(tail) }
        try assertEqual(deltas.joined(), final, "concatenated deltas equal the final document")
        try assertTrue(deltas.count > 3, "the document arrives in several deltas, got \(deltas)")
        try assertTrue(deltas.contains(where: { $0.hasSuffix(#""rating": "#) }),
                       "the partial rating was held back after its key: \(deltas)")
    }

    test("streamer: an equal or shorter prefix emits nothing") {
        var s = StructuredJSONStreamer()
        try assertEqual(s.advance(to: #"{"a": "x"#), #"{"a": "x"#)
        try assertEqual(s.advance(to: #"{"a": "x"#), nil)
        try assertEqual(s.advance(to: #"{"a"#), nil)
        try assertEqual(s.emitted, #"{"a": "x"#)
    }

    test("streamer: a prefix that rewrites sent text is held back, not emitted") {
        var s = StructuredJSONStreamer()
        _ = s.advance(to: #"{"a": "x"#)
        try assertEqual(s.advance(to: #"{"b": "yy"#), nil)
        try assertEqual(s.emitted, #"{"a": "x"#)
    }

    test("streamer: deltas are cut on Unicode scalars (combining marks, emoji)") {
        var s = StructuredJSONStreamer()
        try assertEqual(s.advance(to: "{\"a\": \"e"), "{\"a\": \"e")
        // e + COMBINING ACUTE ACCENT: a grapheme-level hasPrefix would say "e" is
        // not a prefix of "é" (#543); scalars say it is.
        try assertEqual(s.advance(to: "{\"a\": \"e\u{301}🌊"), "\u{301}🌊")
    }

    test("streamer: finish emits the remainder, or nothing when all was sent") {
        var s = StructuredJSONStreamer()
        _ = s.advance(to: #"{"a": 1"#)
        try assertEqual(try s.finish(with: #"{"a": 1}"#), "}")
        var t = StructuredJSONStreamer()
        _ = t.advance(to: #"{"a": 1}"#)
        try assertEqual(try t.finish(with: #"{"a": 1}"#), nil)
    }

    test("streamer: finish throws when the final document does not extend what was sent") {
        var s = StructuredJSONStreamer()
        _ = s.advance(to: #"{"a": "x"#)
        var threw = false
        do { _ = try s.finish(with: #"{"b": 2}"#) } catch let e as StructuredJSONStreamError {
            threw = true
            try assertTrue(e.message.contains("append-only"), e.message)
        }
        try assertTrue(threw, "divergence must be loud, never a silently corrupt stream")
    }

    test("renderer: object keys follow the schema order, not the runtime's") {
        let schemaJSON = #"{"type":"object","properties":{"title":{"type":"string"},"count":{"type":"integer"},"tags":{"type":"array","items":{"type":"object","properties":{"z":{"type":"boolean"},"a":{"type":"number"}}}}}}"#
        let renderer = StructuredJSONRenderer(schemaJSON: schemaJSON, name: "doc")
        let tag = GeneratedContent(properties: ["z": true, "a": 2.5])
        let content = GeneratedContent(properties: [
            "title": "T", "tags": GeneratedContent(elements: [tag]), "count": 4,
        ])
        // Declared order (#560): title, count, tags; nested objects too (z, a).
        try assertEqual(renderer.finalJSON(content),
                        #"{"title": "T", "count": 4, "tags": [{"z": true, "a": 2.5}]}"#)
        try assertEqual(renderer.stablePrefix(content), renderer.finalJSON(content),
                        "a complete document is entirely stable")
    }

    test("renderer: keys the schema does not name follow, sorted; no schema means sorted") {
        let renderer = StructuredJSONRenderer(schema: nil)
        let content = GeneratedContent(properties: ["b": "x", "a": "y"])
        try assertEqual(renderer.finalJSON(content), #"{"a": "y", "b": "x"}"#)
    }
}
