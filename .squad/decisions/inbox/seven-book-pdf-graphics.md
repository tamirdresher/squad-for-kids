# Decision: Book PDF Graphics — Embed Diagrams from Image Plan

**Date:** 2026-03-14
**Author:** Seven (Research & Docs)
**Issue:** #502
**Status:** Applied (partial — code blocks embedded, rendered images pending)

## Context

The book PDF (research/book-the-squad-system.pdf) was delivered without any visual diagrams. Seven `[DIAGRAM:]` placeholders in chapters 2–5 were left as raw text. A comprehensive image plan existed (book-image-plan.md, ~30 figures) but was never reconciled with the chapter source files.

## Decision

1. Embed Mermaid diagram code and ASCII art directly into chapter markdown files, replacing all placeholder comments
2. Regenerate the PDF from the updated source
3. For fully rendered visual diagrams, a follow-up step is needed (pre-render Mermaid to PNG/SVG, or use a Mermaid-aware PDF pipeline)

## Rationale

Diagram code blocks are better than empty placeholders — readers can at least see the structure. Full rendering requires tooling decisions (mermaid-cli, pandoc+mermaid-filter) that need Tamir's input on desired output quality.

## Impact

- Chapters 2, 3, 4, 5 updated with embedded diagrams
- PDF regenerated (3.16 MB)
- Chapters 6, 7, 8 still have "Diagram Note" sections that could benefit from similar treatment
