# Decision: Podcaster Natural Speech Post-Processing Architecture

**Date:** 2026-03-13  
**Author:** Data  
**Issue:** #464 — Podcaster quality improvements  
**Status:** 🟡 Proposed

## Decision

Post-processing for natural speech (contractions, fillers, disfluencies, backchannels) runs as a separate pass AFTER script generation but BEFORE TTS rendering. Both features are opt-in via CLI flags (`--natural-speech`, `--backchannels`) and do not alter existing behavior when flags are omitted.

## Rationale

- **Separation of concerns**: Script generation (LLM or template) produces clean dialogue; speech naturalization is a distinct transformation step
- **Backward compatibility**: All existing scripts, automation, and TTS pipelines work unchanged
- **Composability**: Each post-processing step is independent — users can enable contractions without backchannels, or vice versa
- **Randomization**: Filler/backchannel insertion uses random sampling (not deterministic) to avoid repetitive patterns across episodes

## VibeVoice Integration

VibeVoice wrapper (`podcaster-vibevoice.py`) is created but VibeVoice is not installed as a dependency. It requires CUDA GPU and the package availability on PyPI fluctuates. The wrapper is ready for use once the team has appropriate hardware.

## Impact

- `generate-podcast-script.py`: +200 lines (new functions, no existing code modified)
- `podcaster.ps1`: +15 lines (new parameters, pipeline integration)
- `podcaster-vibevoice.py`: New file, standalone wrapper
