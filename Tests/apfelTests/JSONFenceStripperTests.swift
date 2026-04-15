import Foundation
import ApfelCore

func runJSONFenceStripperTests() {
    test("strips ```json fence with trailing newline") {
        let input = "```json\n{\"a\":1}\n```"
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}")
    }

    test("strips plain ``` fence (no language tag)") {
        let input = "```\n{\"a\":1}\n```"
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}")
    }

    test("strips ```JSON fence case-insensitively") {
        let input = "```JSON\n{\"a\":1}\n```"
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}")
    }

    test("strips fence with surrounding whitespace") {
        let input = "   \n```json\n{\"a\":1}\n```\n   "
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}")
    }

    test("strips fence with multiline JSON") {
        let input = "```json\n{\n  \"chip\": \"M1\",\n  \"year\": 2020\n}\n```"
        try assertEqual(JSONFenceStripper.strip(input), "{\n  \"chip\": \"M1\",\n  \"year\": 2020\n}")
    }

    test("returns raw JSON unchanged when no fence present") {
        let input = "{\"a\":1}"
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}")
    }

    test("returns pretty-printed JSON unchanged when no fence present") {
        let input = "{\n  \"a\": 1\n}"
        try assertEqual(JSONFenceStripper.strip(input), "{\n  \"a\": 1\n}")
    }

    test("leaves unmatched opening fence alone") {
        let input = "```json\n{\"a\":1}"
        try assertEqual(JSONFenceStripper.strip(input), "```json\n{\"a\":1}")
    }

    test("leaves unmatched closing fence alone") {
        let input = "{\"a\":1}\n```"
        try assertEqual(JSONFenceStripper.strip(input), "{\"a\":1}\n```")
    }

    test("leaves non-JSON fenced text alone (no opening/closing JSON)") {
        let input = "```python\nprint('hi')\n```"
        try assertEqual(JSONFenceStripper.strip(input), "```python\nprint('hi')\n```")
    }

    test("result is directly parseable with JSONSerialization") {
        let input = "```json\n{\"chip\":\"M1\",\"year\":2020}\n```"
        let stripped = JSONFenceStripper.strip(input)
        let parsed = try JSONSerialization.jsonObject(with: Data(stripped.utf8)) as? [String: Any]
        try assertEqual(parsed?["chip"] as? String, "M1")
        try assertEqual(parsed?["year"] as? Int, 2020)
    }

    test("handles array JSON inside fence") {
        let input = "```json\n[1,2,3]\n```"
        try assertEqual(JSONFenceStripper.strip(input), "[1,2,3]")
    }
}
