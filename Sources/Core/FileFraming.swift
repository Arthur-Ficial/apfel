import Foundation

/// Pure framing for files that apfel extracts before feeding them to the model.
///
/// Plain-text files keep their raw passthrough (no header) so existing `-f` behaviour is
/// unchanged. Newly-supported PDF and image inputs get a small, honest framed block so the
/// model knows what it is looking at: a header, and for images both "what the image shows"
/// (Vision classification) and the OCR text. No framework code here - the executable runs
/// lesbar and hands the resulting strings to these pure builders, which are fully tested.
public enum FileFraming {
    /// Frame a document (PDF): a `=== name (kind) ===` header followed by the extracted text.
    public static func document(name: String, kind: String, text: String) -> String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return "=== \(name) (\(kind)) ===\n\(body)"
    }

    /// Frame an image: header, "what the image shows" (classification summary), and the OCR
    /// text. Both lines stay honest when empty rather than inventing content.
    public static func image(name: String, whatItShows: String, ocrText: String) -> String {
        let shows = whatItShows.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)

        let showsLine = shows.isEmpty
            ? "what the image shows: (could not confidently identify the image)"
            : "what the image shows: \(shows)"
        let textBlock = text.isEmpty
            ? "text in image: (none detected)"
            : "text in image:\n\(text)"

        return "=== \(name) (image) ===\n\(showsLine)\n\(textBlock)"
    }
}
