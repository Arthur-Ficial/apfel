import Foundation
import ApfelCore

func runToolResultTruncatorTests() {

    test("short result is returned unchanged") {
        let input = "The answer is 42."
        let result = ToolResultTruncator.truncate(input, maxCharacters: 100)
        try assertEqual(result, input)
    }

    test("result exactly at budget is returned unchanged") {
        let input = String(repeating: "x", count: 100)
        let result = ToolResultTruncator.truncate(input, maxCharacters: 100)
        try assertEqual(result, input)
    }

    test("result exceeding budget is truncated with marker") {
        let input = String(repeating: "A", count: 300)
        let result = ToolResultTruncator.truncate(input, maxCharacters: 100)
        try assertTrue(result.count < input.count, "truncated result should be shorter than input")
        try assertTrue(result.contains("[tool output truncated:"), "should contain truncation marker")
        try assertTrue(result.contains("of 300 characters]"), "marker should report original length")
    }

    test("truncated result contains head and tail of original") {
        var input = ""
        for i in 0..<100 {
            input += "LINE\(i)\n"
        }
        let result = ToolResultTruncator.truncate(input, maxCharacters: 200)
        try assertTrue(result.hasPrefix("LINE0\n"), "should start with beginning of original")
        try assertTrue(result.hasSuffix("LINE99\n"), "should end with end of original")
    }

    test("empty string is returned unchanged") {
        let result = ToolResultTruncator.truncate("", maxCharacters: 100)
        try assertEqual(result, "")
    }

    test("single character within budget is returned unchanged") {
        let result = ToolResultTruncator.truncate("x", maxCharacters: 100)
        try assertEqual(result, "x")
    }

    test("truncation marker includes character counts") {
        let input = String(repeating: "z", count: 10000)
        let result = ToolResultTruncator.truncate(input, maxCharacters: 500)
        try assertTrue(result.contains("of 10000 characters]"), "marker should show original length")
    }

    test("head portion is larger than tail portion") {
        let input = String(repeating: "H", count: 50) + String(repeating: "T", count: 950)
        let result = ToolResultTruncator.truncate(input, maxCharacters: 200)
        let markerRange = result.range(of: "[tool output truncated:")!
        let head = String(result[result.startIndex..<markerRange.lowerBound])
        let tail = String(result[result.range(of: "characters]")!.upperBound...])
        try assertTrue(head.count > tail.count, "head should be larger than tail (2:1 ratio)")
    }

    test("very large input is correctly truncated") {
        let input = String(repeating: "x", count: 100_000)
        let result = ToolResultTruncator.truncate(input, maxCharacters: 8000)
        try assertTrue(result.count <= 8200, "result should be roughly within budget plus marker")
        try assertTrue(result.contains("[tool output truncated:"), "should contain marker")
        try assertTrue(result.contains("of 100000 characters]"), "marker should show 100000")
    }

    test("budget of 1 still produces valid output") {
        let input = "Hello, world!"
        let result = ToolResultTruncator.truncate(input, maxCharacters: 1)
        try assertTrue(result.contains("[tool output truncated:"), "should truncate")
    }
}
