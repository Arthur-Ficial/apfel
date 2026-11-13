// ============================================================================
// StopSequenceTests.swift - Unit tests for OpenAI `stop` support (#483).
// The pure incremental matcher (every split position, overlapping and
// shared-prefix delimiters, ties, multiple matches, Unicode, EOF), the
// request-side decode/limits, and the plain-text-only combination rules.
// ============================================================================

import Foundation
import ApfelCore

/// Feed `text` to a fresh matcher as cumulative snapshots ending at each
/// scalar offset in `cuts` (then the full text), and return the
/// concatenation of every released delta plus the EOF flush.
private func streamed(_ stops: [String], _ text: String, cuts: [Int]) -> (text: String, matched: String?, deltas: [String]) {
    var matcher = StopSequenceMatcher(stops: stops)
    let scalars = Array(text.unicodeScalars)
    var deltas: [String] = []
    for cut in cuts + [scalars.count] {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[0..<cut])
        deltas.append(matcher.feed(cumulative: String(view)))
    }
    deltas.append(matcher.finish())
    return (deltas.joined(), matcher.matchedStop, deltas)
}

/// Reference semantics, written independently of the matcher: the first
/// delimiter to be COMPLETELY generated wins (smallest end offset in Unicode
/// scalars); at the same end offset the longest delimiter wins. Delivered
/// text is everything before that delimiter, or the whole text without one.
private func reference(_ stops: [String], _ text: String) -> (text: String, matched: String?) {
    let scalars = Array(text.unicodeScalars)
    let stopScalars = stops.map { Array($0.unicodeScalars) }
    for end in 0..<scalars.count {
        var best: Int? = nil
        for (i, stop) in stopScalars.enumerated() where stop.count <= end + 1 {
            if Array(scalars[(end + 1 - stop.count)...end]) == stop,
               best == nil || stop.count > stopScalars[best!].count {
                best = i
            }
        }
        if let best {
            var view = String.UnicodeScalarView()
            view.append(contentsOf: scalars[0..<(end + 1 - stopScalars[best].count)])
            return (String(view), stops[best])
        }
    }
    return (text, nil)
}

func runStopSequenceTests() {

    // ========================================================================
    // MARK: - Matcher: basics
    // ========================================================================

    test("no stops: every snapshot is released immediately") {
        var m = StopSequenceMatcher(stops: [])
        try assertEqual(m.feed(cumulative: "Hel"), "Hel")
        try assertEqual(m.feed(cumulative: "Hello"), "lo")
        try assertEqual(m.finish(), "")
        try assertEqual(m.delivered, "Hello")
        try assertNil(m.matchedStop)
        try assertTrue(!m.isMatched)
    }

    test("text that cannot start a delimiter is released at once (no extra latency)") {
        var m = StopSequenceMatcher(stops: ["\nObservation"])
        try assertEqual(m.feed(cumulative: "Thought: go"), "Thought: go")
    }

    test("only the ambiguous suffix is held back") {
        var m = StopSequenceMatcher(stops: ["\nObservation"])
        try assertEqual(m.feed(cumulative: "Action: x\nObs"), "Action: x")
        try assertEqual(m.heldBack, "\nObs")
        // The prefix diverges: the held text is released, nothing is lost.
        try assertEqual(m.feed(cumulative: "Action: x\nObsolete"), "\nObsolete")
        try assertEqual(m.heldBack, "")
        try assertEqual(m.delivered, "Action: x\nObsolete")
    }

    test("a completed delimiter and everything after it are dropped") {
        var m = StopSequenceMatcher(stops: ["\nObservation"])
        try assertEqual(m.feed(cumulative: "Action: x\nObservation: 42 and more"), "Action: x")
        try assertTrue(m.isMatched)
        try assertEqual(m.matchedStop, "\nObservation")
        try assertEqual(m.delivered, "Action: x")
    }

    test("after a match, later snapshots and finish release nothing") {
        var m = StopSequenceMatcher(stops: ["END"])
        _ = m.feed(cumulative: "a END")
        try assertEqual(m.feed(cumulative: "a END b END c"), "")
        try assertEqual(m.finish(), "")
        try assertEqual(m.delivered, "a ")
    }

    test("a delimiter at the very start delivers empty text") {
        let r = StopSequenceMatcher.apply(["STOP"], to: "STOP and more")
        try assertEqual(r.text, "")
        try assertEqual(r.matchedStop, "STOP")
    }

    // ========================================================================
    // MARK: - Matcher: EOF
    // ========================================================================

    test("EOF with an unmatched delimiter prefix flushes the held text") {
        var m = StopSequenceMatcher(stops: ["\nObservation"])
        try assertEqual(m.feed(cumulative: "Answer\nObs"), "Answer")
        try assertEqual(m.finish(), "\nObs")
        try assertEqual(m.delivered, "Answer\nObs")
        try assertTrue(!m.isMatched)
    }

    test("finish is idempotent") {
        var m = StopSequenceMatcher(stops: ["xyz"])
        _ = m.feed(cumulative: "abcxy")
        try assertEqual(m.finish(), "xy")
        try assertEqual(m.finish(), "")
        try assertEqual(m.delivered, "abcxy")
    }

    test("a snapshot that does not grow releases nothing") {
        var m = StopSequenceMatcher(stops: ["Z"])
        try assertEqual(m.feed(cumulative: "abc"), "abc")
        try assertEqual(m.feed(cumulative: "abc"), "")
        try assertEqual(m.feed(cumulative: "ab"), "")
        try assertEqual(m.delivered, "abc")
    }

    // ========================================================================
    // MARK: - Matcher: every split position
    // ========================================================================

    test("every single split position yields the same delivered text") {
        let text = "Thought: call it\nAction: lookup\nObservation: 42\nFinal"
        let n = text.unicodeScalars.count
        for cut in 0...n {
            let r = streamed(["\nObservation"], text, cuts: [cut])
            try assertEqual(r.text, "Thought: call it\nAction: lookup", "cut \(cut)")
            try assertEqual(r.matched, "\nObservation", "cut \(cut)")
        }
    }

    test("every pair of split positions yields the same delivered text") {
        let text = "ab\nObs\nObservation tail"
        let n = text.unicodeScalars.count
        for a in 0...n {
            for b in a...n {
                let r = streamed(["\nObservation"], text, cuts: [a, b])
                try assertEqual(r.text, "ab\nObs", "cuts \(a),\(b)")
            }
        }
    }

    test("scalar-by-scalar streaming never releases a fragment of the delimiter") {
        let text = "x\nObservation"
        let cuts = Array(0..<text.unicodeScalars.count)
        let r = streamed(["\nObservation"], text, cuts: cuts)
        try assertEqual(r.text, "x")
        for delta in r.deltas {
            try assertTrue(!delta.contains("\n"), "delta \(delta.debugDescription) leaked a delimiter fragment")
        }
    }

    // ========================================================================
    // MARK: - Matcher: overlapping, shared prefixes, ties
    // ========================================================================

    test("overlapping delimiters: the first one completed wins") {
        // "abc" completes at offset 3, "bcd" only at offset 4.
        try assertEqual(StopSequenceMatcher.apply(["bcd", "abc"], to: "xabcd").text, "x")
        // "bcd" completes before the longer "abcde" that started earlier.
        let r = StopSequenceMatcher.apply(["abcde", "bcd"], to: "abcde")
        try assertEqual(r.text, "a")
        try assertEqual(r.matchedStop, "bcd")
    }

    test("same end offset: the longer delimiter wins (cuts more)") {
        let r = StopSequenceMatcher.apply(["c", "bc"], to: "abc")
        try assertEqual(r.text, "a")
        try assertEqual(r.matchedStop, "bc")
    }

    test("self-overlapping delimiter is found after a false start") {
        try assertEqual(StopSequenceMatcher.apply(["aab"], to: "aaab").text, "a")
        try assertEqual(StopSequenceMatcher.apply(["abab"], to: "abababx").text, "")
        try assertEqual(StopSequenceMatcher.apply(["abac"], to: "ababac!").text, "ab")
    }

    test("shared-prefix delimiters: whichever completes first") {
        let stops = ["\nObservation", "\nObs:"]
        try assertEqual(StopSequenceMatcher.apply(stops, to: "A\nObs: 1").text, "A")
        try assertEqual(StopSequenceMatcher.apply(stops, to: "A\nObservation").text, "A")
        let none = StopSequenceMatcher.apply(stops, to: "A\nObject")
        try assertEqual(none.text, "A\nObject")
        try assertNil(none.matchedStop)
    }

    test("held suffix is the longest one that could still become any delimiter") {
        var m = StopSequenceMatcher(stops: ["xyz", "yq"])
        try assertEqual(m.feed(cumulative: "axy"), "a")
        try assertEqual(m.heldBack, "xy")
        // "yq" completes: the "x" before it is released, the delimiter is not.
        try assertEqual(m.feed(cumulative: "axyq"), "x")
        try assertEqual(m.delivered, "ax")
        try assertEqual(m.matchedStop, "yq")
    }

    test("multiple occurrences: only the first match counts") {
        let r = StopSequenceMatcher.apply(["STOP"], to: "a STOP b STOP c")
        try assertEqual(r.text, "a ")
    }

    test("duplicate delimiters behave like one") {
        try assertEqual(StopSequenceMatcher.apply(["END", "END"], to: "x END y").text, "x ")
    }

    // ========================================================================
    // MARK: - Matcher: Unicode
    // ========================================================================

    test("non-BMP delimiter split at every scalar position") {
        let text = "go 🛑 no"
        for cut in 0...text.unicodeScalars.count {
            try assertEqual(streamed(["🛑"], text, cuts: [cut]).text, "go ", "cut \(cut)")
        }
    }

    test("multi-scalar (ZWJ) delimiter split inside the grapheme cluster") {
        let stop = "👩‍💻"
        let text = "dev \(stop) rest"
        for cut in 0...text.unicodeScalars.count {
            try assertEqual(streamed([stop], text, cuts: [cut]).text, "dev ", "cut \(cut)")
        }
    }

    test("matching is on exact Unicode scalars (no normalization)") {
        let precomposed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"
        try assertEqual(StopSequenceMatcher.apply([precomposed], to: "a \(decomposed)").text, "a \(decomposed)")
        try assertEqual(StopSequenceMatcher.apply([precomposed], to: "a \(precomposed) b").text, "a ")
    }

    test("a newline delimiter inside a CRLF cluster still matches") {
        try assertEqual(StopSequenceMatcher.apply(["\n"], to: "line1\r\nline2").text, "line1\r")
    }

    test("released deltas never split a held multi-scalar prefix mid-way") {
        var m = StopSequenceMatcher(stops: ["e\u{301}!"])
        try assertEqual(m.feed(cumulative: "ok e"), "ok ")
        try assertEqual(m.feed(cumulative: "ok e\u{301}"), "")
        try assertEqual(m.feed(cumulative: "ok e\u{301}?"), "e\u{301}?")
    }

    // ========================================================================
    // MARK: - Matcher: streaming == non-streaming (property)
    // ========================================================================

    test("streamed deltas equal the one-shot result and the reference for many inputs") {
        let alphabet: [Unicode.Scalar] = ["a", "b", "\n", "O", "é", "🛑"]
        let stopSets: [[String]] = [
            ["\nO"], ["ab", "ba"], ["aab", "b\n"], ["🛑a", "a🛑"], ["é\n", "\nOé", "a"], ["bbb"],
        ]
        // Deterministic LCG so the run is reproducible.
        var state: UInt64 = 0x483
        func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
        for round in 0..<400 {
            var view = String.UnicodeScalarView()
            for _ in 0..<(1 + next(18)) { view.append(alphabet[next(alphabet.count)]) }
            let text = String(view)
            let stops = stopSets[round % stopSets.count]
            let n = text.unicodeScalars.count
            var cuts: [Int] = []
            var at = 0
            while at < n { at += 1 + next(3); if at < n { cuts.append(at) } }
            let expected = reference(stops, text)
            let oneShot = StopSequenceMatcher.apply(stops, to: text)
            let live = streamed(stops, text, cuts: cuts)
            try assertEqual(oneShot.text, expected.text, "one-shot round \(round) text \(text.debugDescription) stops \(stops)")
            try assertEqual(oneShot.matchedStop, expected.matched, "one-shot matched round \(round)")
            try assertEqual(live.text, expected.text, "streamed round \(round) text \(text.debugDescription) cuts \(cuts)")
            try assertEqual(live.matched, expected.matched, "streamed matched round \(round)")
        }
    }

    // ========================================================================
    // MARK: - Request decode and limits
    // ========================================================================

    func raw(_ json: String) -> RawJSON {
        // Decode through the real request type so RawJSON canonicalization
        // matches what the server sees.
        let body = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stop":\#(json)}"#
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(ChatCompletionRequest.self, from: Data(body.utf8)).stop!
    }

    test("decode: absent / null stop means no stop sequences") {
        try assertEqual(StopSequences.decode(nil), .success([]))
        let body = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}],"stop":null}"#
        let req = try JSONDecoder().decode(ChatCompletionRequest.self, from: Data(body.utf8))
        try assertEqual(StopSequences.decode(req.stop), .success([]))
    }

    test("decode: a bare string is one stop sequence") {
        try assertEqual(StopSequences.decode(raw(#""\nObservation""#)), .success(["\nObservation"]))
    }

    test("decode: an array keeps order") {
        try assertEqual(StopSequences.decode(raw(#"["END","\n\n"]"#)), .success(["END", "\n\n"]))
    }

    test("decode: an empty array means no stop sequences") {
        try assertEqual(StopSequences.decode(raw("[]")), .success([]))
    }

    test("decode: Unicode survives the RawJSON round trip") {
        try assertEqual(StopSequences.decode(raw(#""🛑 é""#)), .success(["🛑 é"]))
    }

    test("decode: empty string is rejected") {
        try assertEqual(StopSequences.decode(raw(#""""#)), .failure(.emptySequence))
        try assertEqual(StopSequences.decode(raw(#"["a",""]"#)), .failure(.emptySequence))
    }

    test("decode: non-string array entries are rejected with their index") {
        try assertEqual(StopSequences.decode(raw("[1]")), .failure(.nonStringEntry(index: 0)))
        try assertEqual(StopSequences.decode(raw(#"["a",null]"#)), .failure(.nonStringEntry(index: 1)))
        try assertEqual(StopSequences.decode(raw(#"["a",["b"]]"#)), .failure(.nonStringEntry(index: 1)))
    }

    test("decode: numbers, booleans and objects are rejected") {
        try assertEqual(StopSequences.decode(raw("5")), .failure(.invalidType))
        try assertEqual(StopSequences.decode(raw("true")), .failure(.invalidType))
        try assertEqual(StopSequences.decode(raw(#"{"a":"b"}"#)), .failure(.invalidType))
    }

    test("limits: at most 4 sequences (OpenAI parity)") {
        try assertEqual(StopSequences.maxCount, 4)
        try assertEqual(StopSequences.decode(raw(#"["a","b","c","d"]"#)), .success(["a", "b", "c", "d"]))
        try assertEqual(StopSequences.decode(raw(#"["a","b","c","d","e"]"#)), .failure(.tooMany(count: 5)))
    }

    test("limits: total size is capped in Unicode scalars") {
        let cap = StopSequences.maxTotalScalars
        try assertEqual(cap, 256)
        let ok = [String(repeating: "x", count: cap - 6), "🛑🛑🛑🛑🛑🛑"]
        try assertNil(StopSequences.validate(ok))
        let over = [String(repeating: "x", count: cap - 6), "🛑🛑🛑🛑🛑🛑🛑"]
        try assertEqual(StopSequences.validate(over), .tooLong(scalars: cap + 1))
    }

    test("failure messages name the parameter and the limit") {
        try assertTrue(StopSequenceFailure.invalidType.message.contains("'stop' must be a string or an array of strings"))
        try assertTrue(StopSequenceFailure.emptySequence.message.contains("non-empty"))
        try assertTrue(StopSequenceFailure.nonStringEntry(index: 2).message.contains("index 2"))
        try assertTrue(StopSequenceFailure.tooMany(count: 7).message.contains("at most 4"))
        try assertTrue(StopSequenceFailure.tooMany(count: 7).message.contains("7"))
        try assertTrue(StopSequenceFailure.tooLong(scalars: 300).message.contains("256"))
        try assertTrue(StopSequenceFailure.withTools.message.contains("tool_choice"))
        try assertTrue(StopSequenceFailure.withMCPTools.message.contains("--mcp"))
        try assertTrue(StopSequenceFailure.withResponseFormat("json_object").message.contains("json_object"))
    }

    // ========================================================================
    // MARK: - Plain-text-only combinations
    // ========================================================================

    test("combination: plain text with stops is allowed") {
        try assertNil(StopSequences.combinationFailure(stops: ["x"], toolsInScope: false, responseFormat: nil))
        try assertNil(StopSequences.combinationFailure(stops: ["x"], toolsInScope: false, responseFormat: "text"))
    }

    test("combination: no stops never conflicts") {
        try assertNil(StopSequences.combinationFailure(stops: [], toolsInScope: true, responseFormat: "json_schema"))
    }

    test("combination: tools in scope conflict") {
        try assertEqual(StopSequences.combinationFailure(stops: ["x"], toolsInScope: true, responseFormat: nil), .withTools)
    }

    test("combination: json_object and json_schema conflict") {
        try assertEqual(StopSequences.combinationFailure(stops: ["x"], toolsInScope: false, responseFormat: "json_object"), .withResponseFormat("json_object"))
        try assertEqual(StopSequences.combinationFailure(stops: ["x"], toolsInScope: false, responseFormat: "json_schema"), .withResponseFormat("json_schema"))
    }

    // ========================================================================
    // MARK: - ChatRequestValidator integration
    // ========================================================================

    func request(_ extra: String) throws -> ChatCompletionRequest {
        let body = #"{"model":"apple-foundationmodel","messages":[{"role":"user","content":"hi"}]\#(extra)}"#
        return try JSONDecoder().decode(ChatCompletionRequest.self, from: Data(body.utf8))
    }

    let calcTool = #","tools":[{"type":"function","function":{"name":"add","parameters":{"type":"object"}}}]"#

    test("validator accepts a string stop") {
        try assertNil(ChatRequestValidator.validate(try request(#","stop":"END""#)))
    }

    test("validator accepts the LangChain ReAct shape") {
        try assertNil(ChatRequestValidator.validate(try request(#","stop":["\nObservation"],"stream":true"#)))
    }

    test("UnsupportedChatParameter.detect no longer flags stop") {
        try assertNil(UnsupportedChatParameter.detect(in: try request(#","stop":"END""#)))
    }

    test("validator rejects an empty stop string as a 400 on param 'stop'") {
        let failure = ChatRequestValidator.validate(try request(#","stop":"""#))
        try assertEqual(failure, .invalidStop(.emptySequence))
        try assertEqual(failure?.httpStatusCode, 400)
        try assertEqual(failure?.errorParam, "stop")
        try assertTrue(failure?.message.contains("'stop'") == true)
        try assertTrue(failure?.event.contains("stop") == true)
    }

    test("validator rejects too many stop sequences") {
        try assertEqual(ChatRequestValidator.validate(try request(#","stop":["a","b","c","d","e"]"#)), .invalidStop(.tooMany(count: 5)))
    }

    test("validator rejects a non-string stop") {
        try assertEqual(ChatRequestValidator.validate(try request(#","stop":42"#)), .invalidStop(.invalidType))
    }

    test("validator rejects stop with client tools") {
        try assertEqual(ChatRequestValidator.validate(try request(#","stop":"END""# + calcTool)), .invalidStop(.withTools))
    }

    test("validator accepts stop with tools when tool_choice is none") {
        try assertNil(ChatRequestValidator.validate(try request(#","stop":"END","tool_choice":"none""# + calcTool)))
    }

    test("validator rejects stop with response_format json_object and json_schema") {
        try assertEqual(
            ChatRequestValidator.validate(try request(#","stop":"END","response_format":{"type":"json_object"}"#)),
            .invalidStop(.withResponseFormat("json_object")))
        try assertEqual(
            ChatRequestValidator.validate(try request(#","stop":"END","response_format":{"type":"json_schema","json_schema":{"name":"x","schema":{"type":"object"}}}"#)),
            .invalidStop(.withResponseFormat("json_schema")))
    }

    test("validator accepts stop with response_format text") {
        try assertNil(ChatRequestValidator.validate(try request(#","stop":"END","response_format":{"type":"text"}"#)))
    }

    test("validator: null stop with tools is still fine") {
        try assertNil(ChatRequestValidator.validate(try request(#","stop":null"# + calcTool)))
    }
}
