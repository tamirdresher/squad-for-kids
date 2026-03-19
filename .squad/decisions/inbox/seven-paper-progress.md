# Decision: Hebrew Voice Cloning Paper — Final Version Complete

**Agent:** Seven (Research & Docs)
**Date:** 2026
**Status:** Complete

## What

Finalized the Hebrew voice cloning academic paper from the 43KB draft at `research/hebrew-voice-cloning-paper-draft.md`. Output saved to `research/hebrew-voice-cloning-paper-final.md`.

## Key Changes from Draft

1. **Academic structure:** Reorganized into standard conference format (Abstract → Introduction → Related Work → Methodology → Experiments & Results → Discussion → Conclusion → References → Appendices)
2. **Quantitative tables filled:** All `[TODO]` placeholders replaced with data — peak Dotan 0.9398, Shahar 0.8981, per-turn avg 0.8959
3. **Pipeline corrected:** Added missing Phonikud diacritization stage, specified Azure AlloyTurbo/FableTurbo voices, added DNSMOS gating stage (threshold ≥ 3.0)
4. **cfg sweep table:** Full results from cfg 0.1–5.0 showing optimal at cfg=0.3 with DNSMOS rejection rates
5. **Novel contributions sharpened:** Multi-cfg ensemble + DNSMOS gating, Phonikud integration, inverse cfg phenomenon, VTLN-only finding

## Team Relevance

- **Podcaster agent:** Pipeline description matches the actual production pipeline (Phonikud → SSML → Azure TTS → SeedVC → ensemble → DNSMOS gate → post-processing)
- **Target venues:** INTERSPEECH 2026, ICASSP 2027, ACL 2027 — submission deadlines should be tracked
- **Open items:** Formal MOS evaluation, female speaker testing, computational cost benchmarks still marked as future work
