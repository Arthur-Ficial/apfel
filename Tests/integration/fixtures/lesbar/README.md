# lesbar extraction fixtures (public domain)

Real-world files for the `apfel -f` / piped-file extraction integration tests
([../../test_file_extraction.py](../../test_file_extraction.py)). All are public domain
so they can be committed and redistributed freely.

| File | Kind | Text? | Source / license |
|------|------|-------|------------------|
| [irs_w9.pdf](irs_w9.pdf) | document | **with text** (born-digital text layer) | US IRS Form W-9, US government work, public domain (17 U.S.C. 105) |
| [wikimedia_declaration.jpg](wikimedia_declaration.jpg) | document scan | **with text** ("IN CONGRESS. JULY 4. 1776 ...") | Wikimedia Commons, US Declaration of Independence, **public domain** |
| [apollo11_plaque.jpg](apollo11_plaque.jpg) | photo | **with text** (engraved: "...WE CAME IN PEACE FOR ALL MANKIND") | NASA `as11-40-5899`, public domain |
| [wikimedia_mona_lisa.jpg](wikimedia_mona_lisa.jpg) | painting | **without text** (classifies as "art, painting") | Wikimedia Commons, Leonardo da Vinci (d. 1519), **public domain** |
| [nasa_space.jpg](nasa_space.jpg) | photo | **without text** | NASA `PIA12235`, public domain |
| [text_sample.png](text_sample.png) | image | **with text** ("APFEL LESBAR OCR") | authored for this repo (public domain); the multi-format test converts it to PNG/JPEG/TIFF/GIF/BMP/HEIC at runtime with `sips` |
| [plain.txt](plain.txt) | text | with text | authored for this repo |

Provenance of the downloaded files:

- **Wikimedia Commons** items were confirmed `LicenseShortName: "Public domain"` via the
  MediaWiki `imageinfo`/`extmetadata` API before committing. Mona Lisa is PD-old (author died
  1519); the Declaration of Independence is PD-US (published 1776).
- **NASA** media are public domain (https://www.nasa.gov/nasa-brand-center/images-and-media/).
- **US government works** (IRS forms) are not subject to copyright (17 U.S.C. 105).

These exercise every extraction path end-to-end against real files: PDF text layer, image OCR
(text present), and image classification ("what the image is about", no text), across many
image formats.
