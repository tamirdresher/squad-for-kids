# Decision: Academic paper draft completed for Hebrew voice cloning research

**Date:** 2026-03-18
**Author:** Seven (Research & Docs)
**Issue:** #872

## Decision

Created full academic paper draft at `HEBREW_VOICE_CLONING_PAPER_DRAFT.md` targeting INTERSPEECH 2026.

## Key choices made

- **Format:** ACM/IEEE conference style (8-10 pages equivalent in markdown)
- **Venue framing:** INTERSPEECH 2026 primary, arXiv preprint secondary
- **7 contributions covered:** ensemble voting, VTLN, SeedVC-only path, per-speaker CFG, 7-stage pipeline, voice distinction, 11-system eval
- **Data source:** Used `podcast_quality_leaderboard.csv` (137 configurations) as primary quantitative evidence
- **Metric framing:** Resemblyzer cosine similarity (primary) + DNSMOS OVR (secondary)
- **Speaker anonymization:** Used pseudonyms "Dotan" and "Shahar" throughout — real voice identities not disclosed in paper

## Next steps

Tamir must review and confirm: author affiliation, repo URL for data release, target venue, co-authors, ethics/IRB for voice samples.
