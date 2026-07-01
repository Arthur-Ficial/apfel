# File extraction (`-f` and piped files)

apfel turns files into prompt text on-device before sending them to the model. Text files
pass through unchanged; PDFs and images are extracted with Apple's Vision and PDFKit via the
shared [lesbar](https://github.com/Arthur-Ficial/lesbar) package (also used by
[auge](https://github.com/Arthur-Ficial/auge)). No cloud, no API keys, no network.

## What each file type produces

| Input | How it is extracted | What the model receives |
|-------|--------------------|-------------------------|
| Text (`.txt`, `.md`, source, JSON, ...) | UTF-8 decode | the raw text, unchanged |
| PDF | PDFKit text layer; per-page Vision OCR fallback for scanned pages | `=== name (pdf) ===` header + the text |
| Image (JPEG, PNG, HEIC, TIFF, GIF, BMP, WebP) | Vision OCR **and** Vision classification | `=== name (image) ===` + "what the image shows" (classification) + the OCR text |
| Unknown / unsupported binary | rejected | a clear error, no silent garbage |

For images, OCR alone is not enough: a photo with no text still gets a sense of its content
from classification, and a photo with text gets both. A photo of a receipt yields its line
items; a photo of a beach yields "beach, ocean, sky".

## Attach a file with `-f`

```bash
apfel -f report.pdf "Summarize the key findings"
```

```bash
apfel -f receipt.jpg "What is the total?"
```

Attach several files at once:

```bash
apfel -f old.swift -f new.swift "What changed between these two files?"
```

## Pipe a file straight in

Piping a PDF or image works the same way as `-f`:

```bash
cat report.pdf | apfel "Summarize this"
```

```bash
cat photo.jpg | apfel "What is in this picture?"
```

## Check the token budget first

Extraction is model-free, so you can preflight how much a file adds to the prompt:

```bash
apfel --count-tokens -f report.pdf "Summarize this"
```

## Honest limits

- The on-device model has a small context window (about 4096 tokens). A large PDF can exceed
  it; use `--count-tokens` to check.
- OCR quality depends on the image. Engraved, handwritten, or low-contrast text may come out
  partial. apfel reports what Vision actually read and never invents text.
- Image classification labels are Vision's best guess. When nothing is confident, apfel says
  so ("could not confidently identify the image") rather than making something up.
- HTML and web archives are not extracted (they can fetch remote resources); save as PDF or
  text first.
