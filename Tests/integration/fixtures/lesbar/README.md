# lesbar extraction fixtures (public domain)

Real-world files for the `apfel -f` / piped-file extraction integration tests
([../../test_file_extraction.py](../../test_file_extraction.py)). All are public domain
so they can be committed and redistributed freely.

| File | Kind | Text? | Source / license |
|------|------|-------|------------------|
| [apollo11_plaque.jpg](apollo11_plaque.jpg) | photo | **with text** (engraved plaque: "...WE CAME IN PEACE FOR ALL MANKIND") | NASA `as11-40-5899`, public domain |
| [nasa_space.jpg](nasa_space.jpg) | photo | **without text** | NASA `PIA12235`, public domain |
| [irs_w9.pdf](irs_w9.pdf) | document | **with text** (born-digital text layer) | US IRS Form W-9, US government work, public domain |
| [plain.txt](plain.txt) | text | with text | authored for this repo |

NASA media are public domain (see https://www.nasa.gov/nasa-brand-center/images-and-media/).
US government works (IRS forms) are not subject to copyright (17 U.S.C. 105).

These exercise every extraction path end-to-end against real files: PDF text layer,
image OCR (text present), and image classification ("what the image is about", no text).
