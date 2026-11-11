#!/usr/bin/env python3
"""Extract text + render a 200dpi PNG from one or more invoice PDFs.

Usage:
    python extract_invoice.py invoice.pdf [more.pdf ...] --out DIR
    python extract_invoice.py invoice.pdf --out DIR --dpi 200

Outputs per PDF:
    <out>/<stem>.txt   plain text, in reading order
    <out>/<stem>.png   rendered first page (for 添加发票 → 图片)

Requires: pymupdf  (pip install pymupdf)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def extract(pdf: Path, out: Path, dpi: int) -> tuple[Path, Path]:
    import fitz  # pymupdf

    doc = fitz.open(pdf)
    if doc.page_count == 0:
        raise RuntimeError(f"{pdf.name}: no pages")

    chunks = [f"===== {pdf.name} pages={doc.page_count} ====="]
    for i, page in enumerate(doc):
        chunks.append(f"--- page {i + 1} ---")
        chunks.append(page.get_text("text").strip())

    txt_path = out / f"{pdf.stem}.txt"
    txt_path.write_text("\n".join(chunks) + "\n", encoding="utf-8")

    zoom = dpi / 72.0
    pix = doc[0].get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
    png_path = out / f"{pdf.stem}.png"
    pix.save(png_path)

    doc.close()
    return txt_path, png_path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pdfs", nargs="+", type=Path)
    ap.add_argument("--out", type=Path, default=Path("."))
    ap.add_argument("--dpi", type=int, default=200)
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    failed = 0
    for pdf in args.pdfs:
        if not pdf.is_file():
            print(f"SKIP (not found): {pdf}", file=sys.stderr)
            failed += 1
            continue
        try:
            txt, png = extract(pdf, args.out, args.dpi)
            print(f"OK  {pdf.name}\n    text: {txt}\n    png : {png}")
        except Exception as exc:  # noqa: BLE001
            print(f"FAIL {pdf.name}: {exc}", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
