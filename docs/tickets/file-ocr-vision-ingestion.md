# feat(-f): native on-device extraction for PDF, image (OCR + Vision), and Office files

## Problem / Motivation

`apfel -f <file>` is text-only. Anything that isn't UTF-8 is rejected at `Sources/CLI/CLIArguments.swift:593` (`fileErrorMessage`). The current copy literally tells the user to go install a third-party OCR tool:

> `cannot attach image: <path> — the on-device model is text-only (no vision). Try: tesseract <path> stdout | apfel`
> `cannot attach binary file: <path> — only text files are supported` (pdf/…)

This is a dead end for the most common attachments a person actually has — a PDF report, a screenshot, a photo of a receipt, a `.docx`. Every one of these is text-extractable **natively on-device** with frameworks Apple already ships (Vision, PDFKit, `NSAttributedString`) — **zero new SPM dependencies**, 100% offline, perfectly aligned with apfel's "no downloads / on-device" ethos. The FoundationModels LLM is text-only with a 4096-token window, so the job is: **turn the file into trustworthy TEXT, frame it honestly, fit the budget, and never hallucinate.**

## Goal

Make `-f <path>` accept **PDF, images, and Office/RTF/HTML** in addition to plain text. Auto-detect the real type (UTI + magic bytes, never the extension alone), extract text natively, and for images extract **rich Vision info beyond OCR**. When a file (esp. an image) yields no usable signal, **degrade honestly** with a factual stub — never an invented description. Feed the result as framed text into the existing prompt-injection path. The user types the same command; it now just works:

```
apfel -f report.pdf "summarize the key findings"
apfel -f receipt.jpg "what's the total?"
apfel -f memo.docx "rewrite as bullet points"
apfel -f chart.png --image-report "explain this chart"
```

## Design overview

### The Extractor seam (preserve `parse()` purity)

`CLIArguments.parse(_:env:readFile:)` (`CLIArguments.swift:194-198`) injects `readFile: (String) throws -> String`. We add a **parallel injected closure** `extract` of the **same shape**, so `parse()` stays pure and the unit suite never imports Vision/PDFKit.

```swift
public enum AttachmentKind: String, Sendable, Equatable { case text, pdf, image, office, unknown }

public struct ExtractedFile: Sendable, Equatable {
    public let text: String          // framed text that becomes FileAttachment.content
    public let kind: AttachmentKind
    public let method: String        // provenance: "UTF-8" | "PDFKit" | "Vision-OCR" | "NSAttributedString" | "none"
    public let confidence: Double?   // nil for text/pdf-text; mean OCR confidence 0…1 otherwise
    public let pageCount: Int?
    public let truncated: Bool        // clipped to fit token budget
    public let degraded: Bool         // honest "couldn't read this" path taken
    public let notice: String?        // one-line stderr provenance line (suppressed by --quiet)
}

public enum ExtractError: Error, Equatable {
    case unreadable(String), unsupported(String), encrypted(String), empty(String)
}

public static func parse(
    _ args: [String],
    env: [String: String] = [:],
    readFile: (_ path: String) throws -> String = { try String(contentsOfFile: $0, encoding: .utf8) },
    extract:  (_ path: String) throws -> ExtractedFile = DefaultExtractor.extract   // NEW
) throws -> CLIArguments
```

**Sync seam, async work bridged internally.** Vision's modern API is `async`; the injected `extract` closure stays **synchronous** (`throws -> ExtractedFile`) so `parse()`'s signature and the test harness are untouched. The production `DefaultExtractor` bridges async Vision/PDF work internally (run the async request on a private context and block the worker thread, or use the synchronous legacy `VNImageRequestHandler.perform([...])`). **`parse()` never touches disk or a framework** — the default closure (and all I/O) lives in the executable target, injected from `main.swift`. This is the one cross-cutting design decision; do not make `parse()` async.

### Format dispatch (inside `DefaultExtractor`, never in `parse()`)

Detect by **content, not extension** — a PDF named `foo.txt` must be detected as PDF; a JPEG named `foo.dat` must be OCR'd, not UTF-8-rejected.

1. **Magic bytes** (read first 16 via `FileHandle.read(upToCount: 16)`): `%PDF-`→PDF; `\xFF\xD8\xFF`→JPEG; `\x89PNG`→PNG; `GIF8`→GIF; `RIFF…WEBP`→WebP; `II*\0`/`MM\0*`→TIFF; `ftyp`+`heic/heif/mif1` brand→HEIC; `{\rtf`→RTF; `PK\x03\x04`→ZIP container (peek for `word/`, `ppt/`, `xl/`, `[Content_Types].xml` to distinguish OOXML from a plain `.zip`); `\xD0\xCF\x11\xE0`→OLE (`.doc`).
2. **UTType conformance** as tiebreaker: `UTType(filenameExtension:)` / `url.resourceValues(forKeys:[.contentTypeKey]).contentType`, then `.conforms(to: .pdf/.image/.rtf/.html/.plainText)` + OOXML id `org.openxmlformats.wordprocessingml.document`.
3. **UTF-8 probe**: decodes cleanly → plain text (current behavior, unchanged). Else → `ExtractError.unsupported`.

| Resolved kind | Extractor |
|---|---|
| `.text` | `String(contentsOfFile:encoding:.utf8)` — **byte-identical to today** |
| `.pdf` | PDFKit text layer; per-page OCR fallback for scanned pages |
| `.image` | Vision OCR + Vision image-report; honest stub if no signal |
| `.office` (`.docx/.doc/.rtf/.rtfd/.odt`) | `NSAttributedString(url:options:)` → `.string` |
| `.unknown` (zip/exe/dmg/mp3/mp4/…) | **still rejected** by `fileErrorMessage` |

### Framing for the text-only 4096-token model

Extracted bytes never enter the prompt raw. A **pure** `frame(_ e: ExtractedFile, path:) -> String` helper (unit-tested, no I/O) wraps each attachment with a delimited, provenance-bearing header so the LLM knows source, type, and **trust level** (the anti-hallucination signal). `FileAttachment.content` carries the framed string — downstream join (`main.swift:140`) and token count (`CLI.swift:146`) are untouched.

```
=== report.pdf (PDF, 12 pages, text layer) ===
<body>
=== end report.pdf ===
```
- pdf OCR fallback: `=== scan.pdf (PDF, 4 pages, OCR, confidence 0.82) ===`
- image OCR+report: `=== receipt.heic (image, OCR + Vision, confidence 0.91) ===`
- truncated: append ` [truncated to fit context]` to the header.
- degraded image: `=== blur.jpg (image, Vision — no readable text; low confidence) ===` with a body that lists **only measured facts + an explicit do-not-invent instruction** (see Honest fallback).

## Detailed behavior per format

### PDF (`import PDFKit`)
- `PDFDocument(url:)` → `nil` ⇒ `ExtractError.unsupported` ("corrupt or not a valid PDF"). Guard `isLocked`/`isEncrypted`: attempt `unlock(withPassword: "")` (succeeds for owner-encrypted/empty-user-password PDFs); on failure throw `ExtractError.encrypted`. **Never** prompt interactively (apfel is pipe-friendly).
- **Tier 1 (born-digital):** iterate `page(at:)?.string`. Fast, lossless, ~95% of PDFs.
- **Tier 2 (scanned, per-page):** a page is "scanned" if its stripped `.string` length `< minCharsPerPage` (16) **and** the page has visual content. Render that page to a `CGImage` (`PDFPage.thumbnail(of:for:)` or `page.draw(with:to:)` into a sized `CGContext`, scale ≈2.0 for ~200–300 DPI) and OCR it. Mixed PDFs fall back page-by-page. Whole-doc guard: if total born-digital text `< minCharsPerDoc`, OCR every page.
- Output preserves structure with `--- page N ---` / `--- page N (OCR) ---` delimiters and a `[PDF: name — N pages, K OCR'd]` header (the `(OCR)` tag = honest provenance). Process pages **sequentially** (one `CGImage` live) to bound memory; stop rendering once the token cap is hit.
- Empty-but-valid page ⇒ `[page N: no extractable text]`. OCR page with zero above-confidence candidates ⇒ `[page N (OCR): no text recognized]`. Never fabricated.

### Image OCR (`import Vision`, modern API)
```swift
var req = RecognizeTextRequest()                 // value type, macOS 15+/26-current
req.recognitionLevel = .accurate                 // .fast via APFEL_OCR_FAST / --ocr-fast
req.usesLanguageCorrection = true
req.automaticallyDetectsLanguage = true
req.recognitionLanguages = [Locale.Language(identifier: "en-US")]   // optional override
let handler = ImageRequestHandler(url)           // ImageIO decodes png/jpeg/heic/heif/tiff/gif/bmp/webp
let obs: [RecognizedTextObservation] = try await handler.perform(req)
// per obs: obs.topCandidates(1).first?.string / .confidence
```
- **Legacy fallback** (note, gate on availability): `VNRecognizeTextRequest` + `VNImageRequestHandler(url:options:).perform([req])` → `[VNRecognizedTextObservation]`. Modern `RecognizeTextRequest` is canonical for Swift 6.3 / macOS 26; reviewers must NOT "correct" it back to `VN*`.
- **Reading-order assembly** (Vision returns ~top-to-bottom, not guaranteed L→R): take `topCandidates(1)` per obs → `(string, confidence, boundingBox)`; cluster into lines by box midY (tolerance ≈0.5× median box height); sort within line by minX; join words with spaces, lines with `\n`, large vertical gaps (>1.5× line height) → blank line (paragraph). Drop observations below confidence floor **0.30**.
- Multi-column/table layouts linearize best-effort — the provenance header tells the model the text is OCR-linearized so it doesn't over-trust column adjacency. (True table reconstruction is out of scope.)

### Image understanding beyond OCR (`import Vision`)
One shared `ImageRequestHandler` (decode once), compose requests, serialize a **≤~220-token** ranked report. Cut from the bottom to fit budget:

| Rank | Signal | Request |
|---|---|---|
| 1 | barcode/QR decoded payload | `DetectBarcodesRequest` → `.payloadStringValue`, `.symbology` |
| 2 | scene/object labels (top-K, conf ≥0.10, ≤8) | `ClassifyImageRequest` → `[ClassificationObservation]` |
| 3 | document present? (reframes OCR) | `DetectDocumentSegmentationRequest` |
| 4 | animal labels | `RecognizeAnimalsRequest` |
| 5 | **face COUNT only** (no identity/landmarks) | `DetectFaceRectanglesRequest` → `.count` |
| 6 | dims/orientation/EXIF make+model+date, GPS **presence only** | `CGImageSource` properties (ImageIO) |
| 7 | dominant colors (3–4, nearest CSS name) | CoreImage `CIAreaAverage` on a downscale |
| 8 | salient subject location | `GenerateAttentionBasedSaliencyImageRequest` |

`GenerateImageFeaturePrintRequest` is **excluded** (2048-float vector, not LLM-readable). **VisionKit `ImageAnalyzer` is explicitly rejected** — it's the UI/Live-Text layer; raw Vision gives the same payloads headless. `ImageAnalysisInteraction` is iOS-only; never reference it.

Example serialized block:
```
=== image report (apfel Vision, on-device) ===
3024×4032 HEIC photo, portrait, iPhone 15 Pro, 2026-06-20.
subjects: dog (0.94), grass (0.71), outdoor (0.55)
animals: dog
faces: 1
qr/barcode (untrusted): https://example.com  (QR)
dominant colors: green, brown, blue
```

### Office / RTF / HTML (`import AppKit` + `UniformTypeIdentifiers`)
```swift
let attr = try NSAttributedString(
    url: url,
    options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],  // .docx
    documentAttributes: nil)
let text = attr.string
```
`DocumentType`: `.officeOpenXML` (.docx), `.docFormat` (legacy .doc, brittle — `catch`/degrade, never crash), `.rtf`, `.rtfd`, `.openDocument` (.odt). `.string` flattens runs; paragraph breaks survive as `\n`; tables/lists flatten to reading-order text (acceptable for an LLM). `.md/.csv/.tsv/.txt` are **pass-through UTF-8** (no round-trip — exact bytes).

- **HTML/webarchive is rejected by default — security critical.** `NSAttributedString`'s HTML importer spins up a WebKit parser that **fetches remote resources** (`<img src=http…>`, `@import`, web fonts) = network leak + SSRF/tracking-pixel vector. `.baseURL=nil` is **insufficient**. Default: reject HTML/webarchive (opt-in flag later, or local tag-strip). `.docx/.rtf/.odt` are local-only — allowed.
- **No native `.xlsx/.pptx/.pages` text path** (they're zip+XML; Foundation has no public unzip). Degrade honestly: `presentation/spreadsheet text extraction not yet supported; export to .docx or paste as text`.

### Honest fallback for unreadable images
Fires only when **both** signals are weak: `ocrTextStripped.count < MIN_TEXT_CHARS (8)` **AND** (`topLabel == nil || topLabel.confidence < LABEL_CONF_FLOOR (0.30)`). Tiers: `unreadable` (all labels <0.30) vs `low-signal` (best label 0.30–0.50, listed as guesses). The stub is **deterministic, every field a measured fact**, plus an in-band do-not-invent instruction:

```
[apfel: image attachment — automatic on-device extraction]
file: noise.png
format: PNG  dimensions: 1200x1200 px  orientation: .up
dominant colors: #1A1C2B (41%), #8C7A55 (22%)
saliency: none detected
text (Apple OCR): none readable
classification: none above confidence threshold (0.30)
note: The on-device vision pass could not reliably read text or identify this
image. Do NOT describe specifics (people, words, brands, numbers) not listed
here. If asked what the image shows, say it could not be reliably interpreted.
```
- Metadata fields (dims/format/colors/orientation) are **always present and true**, even when OCR + classification both fail — the model reasons about *the file*, never invents *the content*.
- **EXIF strings (UserComment/ImageDescription) must NOT be copied into the stub** — they're attacker-controllable and would smuggle text past the "none readable" honesty. Only structural facts + Vision-derived labels go in.
- Undecodable/vector (SVG/ICO) or `CGImageSourceCreateImageAtIndex == nil` ⇒ degenerate stub (`format + "image could not be decoded for vision analysis"`), still non-empty, still honest.

## CLI surface & flags

All optional; defaults make `-f` work with zero new flags. Flags are **invocation-global** (apply to every `-f`) and are **no-ops** (silently ignored) for formats they don't apply to.

| Flag | Arg | Default | Effect |
|---|---|---|---|
| `--extract` | `text\|describe\|both` | `text` (docs), `both` (images) | What to pull: OCR/PDF text, Vision description, or both. |
| `--ocr-lang` | BCP-47 csv `en-US,de-DE` | auto (`NLLanguageRecognizer` + Vision auto-detect) | Sets `recognitionLanguages` in order. |
| `--ocr-fast` | bool | off (`.accurate`) | `recognitionLevel = .fast`. |
| `--no-vision` | bool | off | Disable image *description* path (OCR text only). Help text must clarify it does NOT disable OCR; alias `--ocr-only`. |
| `--image-report` | bool | off | Emit the full structured Vision report regardless of `--extract`. |
| `--summarize-files` | bool | off | Over-budget files are summarized (`Summarizer`) instead of truncated. |

Env mirrors in the existing env-default block (`CLIArguments.swift:202-217`): `APFEL_EXTRACT`, `APFEL_OCR_LANG`, `APFEL_OCR_FAST`.

**Notices** go to **stderr**, suppressed by `--quiet`, never pollute stdout (`apfel -f x.pdf q | pbcopy` carries only the answer): e.g. `apfel: report.pdf has no embedded text — OCR'd 4 pages (Vision, en-US)`.

**`--help` / `man apfel`** gain a FILE ATTACHMENT section listing all six flags, closing with the honesty line: `Images are read on-device (Apple Vision). The model sees extracted TEXT, never the pixels.`

## Token-budget policy

The 4096-token window is shared by prompt + system prompt + MCP tool defs + files. Extraction can produce arbitrarily large text, so a budget layer sits **between extraction and `FileAttachment` construction** (in the `main.swift` assembly layer, so `parse()` stays pure). Reuse existing math — **never hardcode 4096**; read `SystemLanguageModel.contextSize` via `TokenCounter`.

```
fileBudget = TokenCounter.shared.inputBudget(reservedForOutput: outputReserve) - filePromptReserve   // filePromptReserve default 512
```
- If `promptTokens > filePromptReserve`, re-derive `fileBudget = inputBudget - promptTokens` so the user's prompt is never starved.
- **Per-file caps**, greedy fair-split across N files in **`-f` argument order**: small files pass whole; remaining budget divided among over-cap files; each file guaranteed a minimum viable slice (≈128 tokens) or dropped-with-notice. When N files overflow even after capping, drop **last-file-first** (earliest `-f` wins).
- **Three policies:** (1) **Fits** → verbatim, no notice. (2) **Truncate-with-notice (DEFAULT)** → token-accurate cut (binary-search `TokenCounter.count`, seeded by chars/4; cut on a paragraph boundary in the last ~10%; **cut on `String.Index`, never raw byte offsets** to avoid corrupting CJK/emoji) + visible marker `…[apfel: truncated 7,412 → 2,800 tokens; 38% of "report.pdf" shown. --summarize-files to fit the whole document.]`. (3) **Auto-summarize (`--summarize-files`)** → route through existing `Summarizer.generateSummary(_:maxTokens:permissive:)` (`Summarizer.swift:107`), wrapped with a `[apfel: "report.pdf" summarized from N→M tokens by the on-device model. Detail may be lost…]` marker. On `nil`/failure → **fall back to truncate-with-notice**, never silently drop, never block.
- Truncation is the **honest default** (summarizing a contract silently is a worse failure than visible truncation). Degraded/empty extractions are **never** summarized or truncated — they carry only the honest stub.
- `--count-tokens` (`CLI.swift:145-149,184-186`): report **shown** tokens against budget, plus `(extracted N, <disposition>)` when `rawTokens != shownTokens`. JSON gains additive `extracted_tokens` + `disposition` per file. `total` is computed from post-budget `content` (already correct) so the number is what's actually sent.
- chars/4 fallback (when `isTokenCountingAvailable == false`): apply a **10% safety margin** to caps and surface `(approximate)`.

## Security / privacy guarantees

**Fail closed, degrade honestly, never hallucinate.** Three pre-flight gates run **before any framework touches the file** (cheapest → most expensive, all on-device, no network):
1. **Stat gate** — `URLResourceValues.fileSize` > `maxFileBytes` (default 100 MB) → reject before reading a byte (kills compression bombs at the door).
2. **Type gate** — resolve UTI by content sniff, never trust the extension.
3. **Pixel gate (images)** — `CGImageSourceCopyPropertiesAtIndex` (header only, no decode) → reject `W*H > maxPixels` (default 40 MP). **This is the real OOM defense:** a 2 KB PNG can declare 50000×50000 and demand `W*H*4 ≈ 10 GB` on decode. For huge-but-legal images, cap decode via `CGImageSourceCreateThumbnailAtIndex` (`kCGImageSourceThumbnailMaxPixelSize`).

Other guarantees:
- **Zero network on any `-f` path.** Verified with `nettop`/`sandbox-exec` deny-network. The #1 leak risk is the `NSAttributedString` HTML importer (WebKit remote fetch) → **HTML/webarchive rejected by default**.
- **No JS execution** from PDFs: `.string` extraction never instantiates `PDFView`; embedded PDF JS only runs in the UI layer we never touch.
- **PII minimization:** face **count only** (no identity/landmarks, no biometric entitlement); EXIF **GPS stripped to a boolean** (coords never emitted); EXIF serial/owner not surfaced by default. Extracted content is **not written to logs** at default verbosity (`Sources/Logging.swift` logs the *path*, not the *content*).
- **Untrusted-input fencing:** OCR'd text and decoded **barcode/QR payloads** (can carry prompt-injection like "ignore previous instructions") route through `Sources/SecurityMiddleware.swift` and are fenced/labeled `(untrusted)`; never interpolated raw.
- **Entitlements stay minimal** (Vision OCR/classify + PDFKit + `NSAttributedString` need only file read) so the "100% on-device, no downloads" claim and the Developer ID codesign/notarize story (team `7D2YX5DQ6M`) stay clean. No camera/photos/contacts/biometric/network entitlement.
- Factor shared limits (`maxFileBytes`, `maxPixels`, `maxPdfPages` default 200, allow/deny UTI lists, the HTML-remote ban) into one `ExtractionPolicy` SSOT so a future `/extract` HTTP route (behind `SecurityMiddleware`) reuses them.

## Testing plan

**The unit suite must never import Vision/PDFKit/AppKit.** Three layers, separated by *what they invoke*:

| Layer | Invokes | Location | Network |
|---|---|---|---|
| **Unit** (joins the 687 tier) | `parse()` with a **fake** sync `extract` closure returning literal `ExtractedFile` | `Tests/apfelTests/FileExtractionTests.swift` (custom `func test`/`assertEqual` harness; register in `Tests/apfelTests/main.swift`) | never |
| **Extractor-logic unit** | pure helpers fed stub values: `detectKind`, reading-order assembly, `frame()`, confidence→degraded gate, scanned-PDF text-empty→OCR branch, budget split (`fileBudget`/`perFileCaps`) | same file | never |
| **Integration** (joins the 301 tier) | **real** Vision/PDFKit/AppKit vs committed fixtures; `@available(macOS 26, *)`, **skip-not-fail** | `Tests/integration/` | never |

Rule: anything importing Vision/PDFKit/AppKit lives **only** in `Tests/integration/`. Precedent for the injection seam: `Tests/apfelTests/CLIArgumentsTests.swift:117,837,862` (readFile injection).

**Fixtures** (`Tests/integration/fixtures/extract/`, tiny + reproducible via committed `scripts/gen-extract-fixtures.swift`): `hello.png` (golden "HELLO 8BIT"), `onepage-text.pdf` (born-digital, no OCR), `scanned.pdf` (forces text-empty→OCR branch), `tiny.docx`+`tiny.rtf` (`NSAttributedString` golden), `noise.png` (degraded — asserts no fabricated text), `barcode.png` (known payload).

**Vision determinism:** integration goldens assert **normalized substring containment** (`out.uppercased().contains("HELLO")`), never exact string/confidence equality; confidence asserted only as a threshold (`>= 0.3`) and the `degraded` boolean; `noise.png` asserts the *negation* (no fixture token leaks).

**Pre-existing tests break by design:** the image/pdf rejection-string assertions in `CLIArgumentsTests.swift` are the RED tests — update them to the new contract; flag so nobody "fixes" them back. Binary rejection (`zip/exe/mp4`) regression-guarded at `CLIArguments.swift:605`.

## Acceptance criteria

- [ ] `parse()` exposes an injectable **synchronous** `extract:` closure mirroring `readFile:` (`CLIArguments.swift:194`); default wired to `DefaultExtractor` in the executable target; `parse()` touches no disk/framework and stays pure.
- [ ] `-f x.txt` produces **byte-identical** `FileAttachment.content` to today except for the added `=== … ===` provenance header (golden-locked); `.md/.csv/.tsv` pass through unchanged.
- [ ] `-f report.pdf`, `-f memo.docx`, `-f x.rtf`, `-f x.jpg/.png/.heic` all **exit 0** and inject extracted text — no "cannot attach" rejection.
- [ ] Type detection ignores wrong extensions: PDF named `foo.txt` → PDF (magic bytes); JPEG named `foo.dat` → OCR, not UTF-8-rejected.
- [ ] Born-digital PDF uses `PDFPage.string`, **no OCR** invoked (render-counter spy = 0); scanned PDF detects empty text layer, renders per page, OCRs via `RecognizeTextRequest`; mixed PDF tags OCR'd pages `(OCR)` with correct `--- page N ---` delimiters and `[PDF: name — N pages, K OCR'd]` header.
- [ ] Encrypted PDF: `unlock("")` attempted; on failure → `ExtractError.encrypted` with `qpdf --decrypt` hint, no crash/empty/hallucination. Corrupt `.pdf` → `PDFDocument(url:)` nil → clean error.
- [ ] Image OCR yields human reading order (top→bottom, L→R, paragraph breaks); mixed-language image (EN+DE) extracts both with `automaticallyDetectsLanguage`; below-0.30 observations dropped; mean confidence in the provenance header.
- [ ] Image-report block ≤~220 tokens, ranked, cut bottom-up; QR/barcode → `.payloadStringValue` + symbology, fenced `(untrusted)`; animal/face count correct; **EXIF GPS coords never appear** (presence boolean only); face landmarks/identity never emitted.
- [ ] Content-free image (noise/sunset) → **exit 0**, honest stub with true dims/format/colors + do-not-invent note + `none readable`/`none above confidence threshold`; **no fabricated caption** (asserted: body ⊆ measured fields + confidence-tagged labels). EXIF description strings absent from the stub.
- [ ] `.docx/.doc/.rtf/.rtfd/.odt` → readable plain text, no markup leakage; corrupt Office → typed `ExtractError`, never partial garbage. **HTML/webarchive rejected by default**; canary fixture (`<img src=http://canary>`) triggers **zero** outbound connections.
- [ ] `--extract describe|both`, `--ocr-lang`, `--ocr-fast`, `--no-vision`, `--image-report`, `--summarize-files` behave per the table; env mirrors honored; flags are no-ops for inapplicable formats.
- [ ] Token budget: over-window PDF truncated to ≤ per-file cap with visible marker; run completes (no `contextOverflow`); `--count-tokens -f big.pdf` shows `shown (extracted N, truncated)` and `fits`. `--summarize-files` → `summarized` disposition; model-unavailable → falls back to `truncated`, no crash. Multi-file injected in arg order; overflow drops earliest-first with one notice. Token cut is `String.Index`-safe and token-accurate (≤ cap under both real tokenizer and chars/4+10%-margin fallback).
- [ ] Pre-flight gates: file > 100 MB rejected before read; 2 KB PNG declaring 50000×50000 rejected before decode (RSS stays bounded); both measured.
- [ ] Notices on **stderr**, suppressed by `--quiet`; stdout clean for piping.
- [ ] **Zero new SPM dependencies** (`Package.swift` `dependencies:` unchanged; `swift package show-dependencies` identical); only `Vision`/`PDFKit`/`AppKit`/`UniformTypeIdentifiers`/`NaturalLanguage` system imports added, all in the executable target (`ApfelCore`/`ApfelCLI` stay framework-free). Builds clean on `.macOS(.v26)` / Swift 6.3 with no `@available` shims for the modern Vision path.
- [ ] Modern Vision API used as the headline path (`RecognizeTextRequest`/`ImageRequestHandler`/`ClassifyImageRequest`), **not** `VN*`; no VisionKit `ImageAnalyzer`/`ImageAnalysisInteraction` anywhere.
- [ ] `fileErrorMessage` (`CLIArguments.swift:593`) no longer blanket-rejects images/pdf; still rejects `zip/tar/gz/dmg/pkg/exe/bin/mp3/mp4/mov/avi/wav` and `svg/ico` with honest copy; the `tesseract` hint is gone.
- [ ] `main.swift:140` join and `CLI.swift:146` token count consume `FileAttachment.content` with **no signature change**.
- [ ] Unit suite (`swift run apfel-tests`) imports no Vision/PDFKit/AppKit, performs no network/disk I/O, passes offline; integration tier skip-not-fails when unavailable.

## Out of scope / follow-ups

- `.xlsx/.pptx/.pages` text extraction (zip+XML; needs `Compression.compression_decode_buffer` manual OOXML inflate) — degrade honestly for now.
- HTML/webarchive ingestion with a **safe** local tag-stripper (network-blocked) behind an opt-in flag.
- Structured table/multi-column reconstruction from Vision bounding boxes (and `RecognizeDocumentsRequest` structured `.document`) — v1 linearizes best-effort.
- Whole-doc map-reduce summarization of over-budget PDFs (v1 truncates honestly).
- `--serve` `/v1/chat/completions` image input: carry the `image_url` payload (`OpenAIModels.swift:231` `ContentPart` currently **drops** it; `textContent` returns nil on image parts) and lower images→framed text before model dispatch (`Handlers.swift:167`). Gate non-`data:` URLs (SSRF), size-cap base64.
- Per-`-f` (vs invocation-global) extraction flags via positional pairing.
- `GenerateImageFeaturePrintRequest`-based image dedupe/similarity.

## References (Apple frameworks, macOS 26 Tahoe, all free system frameworks, zero SPM deps)

- **Vision** — `RecognizeTextRequest` (`.recognitionLevel`, `.usesLanguageCorrection`, `.automaticallyDetectsLanguage`, `.recognitionLanguages`), `ImageRequestHandler.perform(_:)` async → `[RecognizedTextObservation]` (`.topCandidates(_:)`, `.confidence`, `.boundingBox`); `ClassifyImageRequest`→`[ClassificationObservation]`, `DetectBarcodesRequest`→`[BarcodeObservation]`, `RecognizeAnimalsRequest`, `DetectFaceRectanglesRequest`, `DetectDocumentSegmentationRequest`, `GenerateAttentionBasedSaliencyImageRequest`. Legacy fallback: `VNRecognizeTextRequest`/`VNImageRequestHandler`.
- **PDFKit** — `PDFDocument(url:)`, `.isEncrypted/.isLocked`, `unlock(withPassword:)`, `.pageCount`, `page(at:)`, `PDFPage.string`, `.bounds(for:)`, `.thumbnail(of:for:)`, `.draw(with:to:)`.
- **AppKit** — `NSAttributedString(url:options:documentAttributes:)` with `DocumentType` `.officeOpenXML/.docFormat/.rtf/.rtfd/.openDocument`; `.string`.
- **UniformTypeIdentifiers** — `UTType(filenameExtension:)`, `url.resourceValues(forKeys:[.contentTypeKey])`, `.conforms(to:)`.
- **ImageIO** — `CGImageSourceCreateWithURL`, `CGImageSourceCopyPropertiesAtIndex` (pixel dims/EXIF/orientation, GPS presence), `CGImageSourceCreateThumbnailAtIndex`.
- **CoreImage** — `CIAreaAverage` (dominant colors).
- **NaturalLanguage** — `NLLanguageRecognizer.dominantLanguage(for:)` (OCR language auto-pick / degrade signal).
- **Foundation** — `FileHandle.read(upToCount:)` (magic bytes), `URLResourceValues.fileSize`.

**apfel integration seams:** `Sources/CLI/CLIArguments.swift` — `:13` `FileAttachment` (+`ExtractedFile`/`AttachmentKind`/`frame()` adjacent), `:194-198` add `extract:` param, `:496-508` `-f` calls `extract`+frames+appends, `:202-217` env mirrors, `:593-611` `fileErrorMessage` reject→route. `Sources/main.swift:140-148` join + budget layer + stderr notices. `Sources/CLI.swift:145-149,184-186` `--count-tokens` extended reporting. Reuse `Sources/TokenCounter.swift`, `Sources/Summarizer.swift`, `Sources/ContextManager.swift`, `Sources/SecurityMiddleware.swift`. New: `Sources/<exe>/DefaultExtractor.swift` (+`ExtractionPolicy`).
