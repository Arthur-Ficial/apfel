// ============================================================================
// DocsAppleScriptTests.swift - Static regression checks for demo/docs-apple.
// ============================================================================

import Foundation

func runDocsAppleScriptTests() {

    func findRepoRoot() -> URL {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<6 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: fm.currentDirectoryPath)
    }

    let root = findRepoRoot()
    let scriptPath = root.appendingPathComponent("demo/docs-apple").path

    test("docs-apple builds a probable documentation query before fetching") {
        let text = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        try assertTrue(text.contains("build_probable_doc_query()"),
                       "docs-apple should derive a focused Apple docs query from detected framework/symbol/user intent")
    }

    test("docs-apple searches Apple docs before direct heuristic fetches") {
        let text = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        let searchMarker = "Search Apple docs first using the most probable documentation query."
        let directFetchMarker = "Search failed — try direct fetch heuristics."

        guard let searchRange = text.range(of: searchMarker) else {
            throw TestFailure("missing search-first marker")
        }
        guard let directFetchRange = text.range(of: directFetchMarker) else {
            throw TestFailure("missing direct-fetch fallback marker")
        }

        try assertTrue(searchRange.lowerBound < directFetchRange.lowerBound,
                       "Apple docs search must happen before direct framework/symbol brute force")
    }

    test("docs-apple uses model-only fallback only after docs search and fetch attempts") {
        let text = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        let directFetchMarker = "Search failed — try direct fetch heuristics."
        let modelFallbackMarker = "Fallback to direct general query"

        guard let directFetchRange = text.range(of: directFetchMarker) else {
            throw TestFailure("missing direct-fetch fallback marker")
        }
        guard let modelFallbackRange = text.range(of: modelFallbackMarker) else {
            throw TestFailure("missing model fallback marker")
        }

        try assertTrue(directFetchRange.lowerBound < modelFallbackRange.lowerBound,
                       "model-only fallback must happen after docs search/fetch attempts")
    }

    test("docs-apple extracts explicit @keyword tokens for prioritized Apple docs search") {
        let text = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        try assertTrue(text.contains("EXPLICIT_TAGS"),
                       "docs-apple must extract @keyword tokens from the query for explicit keyword control")
    }

    test("explicit @keyword tokens take priority over auto-detection in build_probable_doc_query") {
        let text = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        let extractCall = "extract_explicit_tags"
        let docQueryCall = "DOC_QUERY=$(build_probable_doc_query)"

        guard let extractRange = text.range(of: extractCall) else {
            throw TestFailure("missing extract_explicit_tags call")
        }
        guard let docQueryRange = text.range(of: docQueryCall) else {
            throw TestFailure("missing DOC_QUERY build call")
        }

        try assertTrue(extractRange.lowerBound < docQueryRange.lowerBound,
                       "extract_explicit_tags must be called before build_probable_doc_query so @keyword gets priority")
    }
}
