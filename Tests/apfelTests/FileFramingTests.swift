import Foundation
import ApfelCore

// Pure framing for extracted non-text files. Text files keep their raw passthrough
// behaviour (no header) to preserve existing `-f` output; only newly-supported PDF and
// image inputs get a framed block so the model knows what it is looking at.
func runFileFramingTests() {
    // MARK: document (PDF)

    test("document frame wraps text with a name+kind header") {
        let out = FileFraming.document(name: "report.pdf", kind: "pdf", text: "Q3 revenue up 12%.")
        try assertEqual(out, "=== report.pdf (pdf) ===\nQ3 revenue up 12%.")
    }
    test("document frame trims trailing whitespace on the body") {
        let out = FileFraming.document(name: "a.pdf", kind: "pdf", text: "hello\n\n")
        try assertEqual(out, "=== a.pdf (pdf) ===\nhello")
    }

    // MARK: image (OCR + classification)

    test("image frame shows what it is about and the OCR text") {
        let out = FileFraming.image(name: "receipt.jpg", whatItShows: "receipt, paper, text", ocrText: "TOTAL 9.99")
        try assertEqual(out,
            "=== receipt.jpg (image) ===\nwhat the image shows: receipt, paper, text\ntext in image:\nTOTAL 9.99")
    }
    test("image frame is honest when no labels cleared the threshold") {
        let out = FileFraming.image(name: "blur.png", whatItShows: "", ocrText: "SIGN")
        try assertTrue(out.contains("what the image shows: (could not confidently identify the image)"))
        try assertTrue(out.contains("text in image:\nSIGN"))
    }
    test("image frame is honest when no text was detected") {
        let out = FileFraming.image(name: "cat.jpg", whatItShows: "cat, animal", ocrText: "")
        try assertTrue(out.contains("what the image shows: cat, animal"))
        try assertTrue(out.contains("text in image: (none detected)"))
    }
    test("image frame with neither labels nor text still frames honestly") {
        let out = FileFraming.image(name: "x.png", whatItShows: "", ocrText: "")
        try assertTrue(out.hasPrefix("=== x.png (image) ==="))
        try assertTrue(out.contains("(could not confidently identify the image)"))
        try assertTrue(out.contains("text in image: (none detected)"))
    }
}
