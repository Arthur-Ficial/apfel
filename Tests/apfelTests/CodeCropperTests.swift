// ============================================================================
// CodeCropperTests.swift — unit tests for the --code extraction spec (#373)
// Fixtures marked "real transcript" are verbatim model output captured during
// the 20-prompt validation run on 2026-07-09 (see issue #373).
// ============================================================================

import Foundation
import ApfelCore

func runCodeCropperTests() {

    // Case 1: prose + one ```python block + prose (real transcript, abridged)
    test("extracts first python block from prose-wrapped response") {
        let input = """
        Certainly! Here's a simple Python calculator that can perform basic arithmetic operations:

        ```python
        def calculator():
            print("Welcome!")
        ```

        ### How to Use:
        1. Run the script in a Python environment.
        """
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "def calculator():\n    print(\"Welcome!\")\n")
        try assertEqual(crop?.language, "python")
    }

    // Case 2: response that is only a fenced block
    test("extracts block when response is only the fence") {
        let crop = CodeCropper.extract(from: "```bash\npmset -g batt\n```")
        try assertEqual(crop?.code, "pmset -g batt\n")
        try assertEqual(crop?.language, "bash")
    }

    // Case 3: multiple blocks — first wins (real transcript shape)
    test("first block wins over later blocks") {
        let input = """
        ```python
        s[::-1]
        ```

        Or with a loop:

        ```python
        for char in s: r = char + r
        ```

        Both produce:

        ```
        !dlroW ,olleH
        ```
        """
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "s[::-1]\n")
    }

    // Case 4: info string with attributes
    test("info string attributes stripped, language kept") {
        let crop = CodeCropper.extract(from: "```python title=calc.py\nx = 1\n```")
        try assertEqual(crop?.code, "x = 1\n")
        try assertEqual(crop?.language, "python")
    }

    // Case 5: no info string
    test("language is nil without info string") {
        let crop = CodeCropper.extract(from: "```\nls -la\n```")
        try assertEqual(crop?.code, "ls -la\n")
        try assertNil(crop?.language ?? nil)
    }

    // Case 6: tilde fences
    test("tilde fences extract") {
        let crop = CodeCropper.extract(from: "~~~ruby\nputs 1\n~~~")
        try assertEqual(crop?.code, "puts 1\n")
        try assertEqual(crop?.language, "ruby")
    }

    // Case 7: opening fence indented 1-3 spaces
    test("fence indented up to 3 spaces extracts") {
        let crop = CodeCropper.extract(from: "   ```sh\n   echo hi\n   ```")
        try assertEqual(crop?.code, "   echo hi\n")
        try assertEqual(crop?.language, "sh")
    }

    test("fence indented 4 spaces is not a fence opener") {
        let crop = CodeCropper.extract(from: "    ```sh\n    echo hi\n    ```")
        try assertNil(crop)
    }

    // Case 8: 4-backtick fence containing a ``` sequence inside
    test("longer fence preserves inner triple backticks") {
        let input = "````markdown\nUse a fence:\n```python\nx = 1\n```\ndone\n````"
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "Use a fence:\n```python\nx = 1\n```\ndone\n")
        try assertEqual(crop?.language, "markdown")
    }

    // Case 9: closing fence shorter than opener is not a close
    test("shorter closing run does not close; salvages to EOF") {
        let input = "````\ncode line\n```\nstill inside"
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "code line\n```\nstill inside\n")
    }

    // Case 10: unclosed fence at EOF = salvage (real transcript shape from --max-tokens 80)
    test("unclosed fence at EOF salvages remainder") {
        let input = """
        Certainly! Below is a simple Python calculator script:

        ```python
        def add(a, b):
            return a + b

        def multiply(a, b):
        """
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "def add(a, b):\n    return a + b\n\ndef multiply(a, b):\n")
        try assertEqual(crop?.language, "python")
    }

    // Case 11: empty block found-but-empty
    test("empty block yields empty code, not nil") {
        let crop = CodeCropper.extract(from: "```\n```")
        try assertNotNil(crop)
        try assertEqual(crop?.code, "")
    }

    // Case 12: inline code spans only — no extraction, no heuristics
    test("inline code spans are not extracted") {
        let crop = CodeCropper.extract(from: "Just run `pmset -g batt` in your terminal.")
        try assertNil(crop)
    }

    // Case 13: plain prose, zero backticks
    test("plain prose yields nil") {
        try assertNil(CodeCropper.extract(from: "Paris is the capital of France."))
    }

    // Case 14: fence markers mid-line are not fences
    test("triple backticks mid-line are not a fence") {
        try assertNil(CodeCropper.extract(from: "In markdown, use ``` to open a fence and ``` to close it."))
    }

    // CommonMark: backtick fence info string cannot contain backticks, so the
    // first line is NOT an opener — the later bare ``` is, and it salvages to
    // EOF. The assertion is that "not code" was never treated as a block.
    test("backtick opener with backtick in info string is not a fence") {
        let crop = CodeCropper.extract(from: "``` a`b\nnot code\n```\ntrailing")
        try assertEqual(crop?.code, "trailing\n")
    }

    // Case 15: CRLF line endings
    test("CRLF input extracts with LF output") {
        let crop = CodeCropper.extract(from: "```bash\r\necho hi\r\n```\r\n")
        try assertEqual(crop?.code, "echo hi\n")
        try assertEqual(crop?.language, "bash")
    }

    // Case 16: interior blank lines and indentation preserved byte-for-byte
    test("interior blank lines and indentation preserved") {
        let input = "```python\ndef f():\n\n\tif x:\n\t\treturn  1\n```"
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "def f():\n\n\tif x:\n\t\treturn  1\n")
    }

    // Case 17: output ends with exactly one newline
    test("output always ends with exactly one newline") {
        let crop = CodeCropper.extract(from: "```\nls\n\n\n```")
        try assertEqual(crop?.code, "ls\n")
    }

    // Case 18: leading and trailing blank lines inside the block trimmed
    test("leading and trailing blank lines trimmed, interior kept") {
        let crop = CodeCropper.extract(from: "```\n\n\nfirst\n\nlast\n\n\n```")
        try assertEqual(crop?.code, "first\n\nlast\n")
    }

    // Case 19: whitespace-only block treated as empty
    test("whitespace-only block yields empty code") {
        let crop = CodeCropper.extract(from: "```\n   \n\t\n```")
        try assertNotNil(crop)
        try assertEqual(crop?.code, "")
    }

    // Case 20: info string lowercased
    test("uppercase info string lowercased") {
        let crop = CodeCropper.extract(from: "```PYTHON\nx = 1\n```")
        try assertEqual(crop?.language, "python")
    }

    // Case 21: wrong/nonsense info string extracts normally (real transcript:
    // the model labeled a curl command ```markdown)
    test("wrong-language info string extracts normally") {
        let input = "```markdown\ncurl -X POST https://api.example.com -H \"Authorization: Bearer T\"\n```"
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "curl -X POST https://api.example.com -H \"Authorization: Bearer T\"\n")
        try assertEqual(crop?.language, "markdown")
    }

    // Case 22: junk later blocks discarded (real transcript: German prompt run
    // echoed the user's own prompt back inside a second fence)
    test("echoed-prompt second block is discarded") {
        let input = """
        ```bash
        find . -maxdepth 1 -exec ls -l {} \\;
        ```

        ```bash
        gib mir einen shell-befehl der die groessten dateien im ordner anzeigt
        ```
        """
        let crop = CodeCropper.extract(from: input)
        try assertEqual(crop?.code, "find . -maxdepth 1 -exec ls -l {} \\;\n")
    }

    // Empty / degenerate inputs
    test("empty string yields nil") {
        try assertNil(CodeCropper.extract(from: ""))
    }

    test("bare opening fence with no content salvages to empty") {
        let crop = CodeCropper.extract(from: "```python\n")
        try assertNotNil(crop)
        try assertEqual(crop?.code, "")
        try assertEqual(crop?.language, "python")
    }

    // Steering directive: locked wording (validated 20/20 in #373; changing it
    // requires re-running the prompt battery, so a drift here must be loud)
    test("steering directive is the validated wording") {
        try assertTrue(CodeCropper.steeringDirective.contains("exactly one fenced markdown code block"))
        try assertTrue(CodeCropper.steeringDirective.contains("No text before or after"))
    }

    // macOS 27 model: the phrase "language info string" was read as a JSON
    // key - the model answered `{"language_info": {...}, "command": ...}` or
    // appended `# lang: python` / `LANG=en_US` (#193). The directive names the
    // fence shape by example instead and never says "info string".
    test("steering directive shows the fence by example, never says 'info string' (#193)") {
        try assertTrue(CodeCropper.steeringDirective.contains("```bash"))
        try assertTrue(!CodeCropper.steeringDirective.lowercased().contains("info string"))
        try assertTrue(!CodeCropper.steeringDirective.lowercased().contains("language info"))
    }

    // ========================================================================
    // MARK: - crop(from:) — the full --code policy (fence, else pass-through)
    // A model that complies with the steering so well that it omits the fence
    // entirely must still work: the bare response IS the code.
    // ========================================================================

    test("crop: fenced block wins, same as extract") {
        let crop = CodeCropper.crop(from: "prose\n```bash\npmset -g batt\n```\nmore prose")
        try assertEqual(crop?.code, "pmset -g batt\n")
        try assertEqual(crop?.language, "bash")
    }

    test("crop: bare single-line command passes through") {
        let crop = CodeCropper.crop(from: "pmset -g batt | grep -o '[0-9]*%'")
        try assertEqual(crop?.code, "pmset -g batt | grep -o '[0-9]*%'\n")
        try assertNil(crop?.language ?? nil)
    }

    test("crop: bare multi-line code passes through with interior preserved") {
        let crop = CodeCropper.crop(from: "def add(a, b):\n    return a + b\n")
        try assertEqual(crop?.code, "def add(a, b):\n    return a + b\n")
    }

    test("crop: pass-through trims surrounding blank lines, one trailing newline") {
        let crop = CodeCropper.crop(from: "\n\nls -la\n\n\n")
        try assertEqual(crop?.code, "ls -la\n")
    }

    test("crop: whole-response inline code span is unwrapped") {
        let crop = CodeCropper.crop(from: "`pmset -g batt`")
        try assertEqual(crop?.code, "pmset -g batt\n")
    }

    // Real transcript (integration battery, 2026-07-09): the model wrapped a
    // one-liner in triple backticks ON ONE LINE. Not a CommonMark fence
    // (content on the fence line), but a valid inline span with 3-backtick
    // delimiters — must unwrap, never leak backticks into a pipe.
    test("crop: single-line triple-backtick wrapping is unwrapped") {
        let crop = CodeCropper.crop(from: "```awk '{sum($2) % 100}' < input.csv > output.csv```")
        try assertEqual(crop?.code, "awk '{sum($2) % 100}' < input.csv > output.csv\n")
    }

    test("crop: single-line wrapped span with inner backtick passes through") {
        let input = "```echo `date```` and stuff"
        let crop = CodeCropper.crop(from: input)
        try assertEqual(crop?.code, input + "\n")
    }

    test("crop: inline span inside prose is NOT unwrapped (pass-through verbatim)") {
        let crop = CodeCropper.crop(from: "Just run `pmset -g batt` in your terminal.")
        try assertEqual(crop?.code, "Just run `pmset -g batt` in your terminal.\n")
    }

    test("crop: CRLF pass-through normalized to LF") {
        let crop = CodeCropper.crop(from: "echo hi\r\necho ho\r\n")
        try assertEqual(crop?.code, "echo hi\necho ho\n")
    }

    test("crop: empty response yields nil (exit 7)") {
        try assertNil(CodeCropper.crop(from: ""))
        try assertNil(CodeCropper.crop(from: "   \n\t\n"))
    }

    test("crop: empty fenced block still yields empty code, not pass-through") {
        let crop = CodeCropper.crop(from: "```\n```")
        try assertNotNil(crop)
        try assertEqual(crop?.code, "")
    }
}
