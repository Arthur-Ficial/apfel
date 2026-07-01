// ============================================================================
// LesbarFileReader.swift — the executable-side extractor injected into
// CLIArguments.parse (for -f) and used for piped file input.
//
// Turns any supported file into prompt-ready text via the shared lesbar package:
//   - plain text  -> raw passthrough (unchanged -f behaviour, no frame)
//   - PDF         -> text layer / OCR fallback, framed with a header
//   - image       -> OCR text PLUS "what the image is about" (Vision classification),
//                    framed so the model gets both. OCR alone is not enough.
//
// Pure framing lives in ApfelCore.FileFraming; this file is the framework seam.
// ============================================================================

import Foundation
import ApfelCore
import ApfelCLI
import LesbarCore
import Lesbar

enum LesbarFileReader {
    /// Default `-f <path>` extractor. Reads the file and returns prompt-ready text.
    static func extractForPrompt(path: String) throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { throw CLIParseError("no such file: \(path)") }
        guard fm.isReadableFile(atPath: path) else { throw CLIParseError("permission denied: \(path)") }
        let url = URL(fileURLWithPath: path)
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw CLIParseError("could not read file: \(path)") }
        return try extract(data: data, name: url.lastPathComponent, url: url)
    }

    /// Extract prompt-ready text from raw bytes. `url` must point at a real file on disk so
    /// lesbar can hand it to Vision/PDFKit (for piped input the caller writes a temp file).
    static func extract(data: Data, name: String, url: URL) throws -> String {
        let kind = FileKind.detect(data: data, filename: name)
        switch kind {
        case .plainText:
            // Raw passthrough — preserves apfel's existing text `-f` / pipe behaviour.
            return TextDecoding.decode(data).text

        case .pdf:
            let result = try runLesbar { try Lesbar.extract(url) }
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw CLIParseError("no text could be extracted from PDF: \(name)")
            }
            return FileFraming.document(name: name, kind: "pdf", text: result.text)

        case .image:
            // OCR is best-effort; a textless photo is still useful via classification.
            let ocr = ((try? runLesbar { try OCR.recognizeText(at: url) }) ?? []).joined(separator: "\n")
            let labels = (try? runLesbar { try ImageClassifier.classify(at: url) }) ?? []
            let summary = ImageInsight.summary(labels)
            if ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && summary.isEmpty {
                throw CLIParseError("could not extract text or identify image: \(name)")
            }
            return FileFraming.image(name: name, whatItShows: summary, ocrText: ocr)

        case .unknown:
            throw CLIParseError("unsupported file type: \(name) (apfel -f reads text, PDF, and images)")
        }
    }

    /// For piped stdin: if the bytes are an extractable non-text file (PDF or image),
    /// stage them in a temp file, extract, and return the framed prompt text. Plain text
    /// and unknown blobs return `nil` so the caller keeps its existing text handling.
    /// Throws `CLIParseError` when the bytes are clearly a PDF/image but extraction fails.
    static func extractPipedIfBinary(_ data: Data) throws -> String? {
        let kind = FileKind.detect(data: data, filename: nil)
        let ext: String
        let name: String
        switch kind {
        case .pdf: ext = "pdf"; name = "piped-document.pdf"
        case .image: ext = "img"; name = "piped-image"
        case .plainText, .unknown: return nil
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("apfel-stdin-\(ProcessInfo.processInfo.processIdentifier).\(ext)")
        do { try data.write(to: tmp) }
        catch { throw CLIParseError("could not stage piped input for extraction") }
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try extract(data: data, name: name, url: tmp)
    }

    private static func runLesbar<T>(_ body: () throws -> T) throws -> T {
        do { return try body() }
        catch let e as LesbarError { throw CLIParseError(e.userMessage) }
    }
}
