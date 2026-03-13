# Decision: Conversational Podcast Quality Strategy

**Date:** 2026-03-13  
**Author:** Data  
**Issue:** #455  
**PR:** #457  
**Status:** Implemented — Phase 1 Complete

---

## Context

Current podcaster sounds like "someone reading from a page." Seven's research (research/active/podcast-quality/README.md) identified the root cause and solution.

---

## Decision

**Adopt 2-phase architecture for podcast generation:**

1. **Phase 1: LLM Conversation Script Generation** — Generate realistic dialogue with natural banter, disagreements, filler words, interruptions
2. **Phase 2: Multi-Voice TTS with Prosody** — Render with distinct voices, rate variation, natural pauses

**Key Finding:** Script quality matters more than TTS quality.

---

## Implementation (Phase 1 Complete)

### LLM Improvements

**Enhanced Prompts (generate-podcast-script.py):**
- Detailed host personalities (Alex: curious/interrupts, Sam: expert/skeptical)
- Conversational style guidelines (interruptions, disagreements, filler words, emotional shifts)
- Specific instructions for natural dialogue (3-5 interruptions, 1+ debate, casual banter)

### TTS Improvements

**Rendering (podcaster-conversational.py):**
- Rate variation: Alex +5% (excitable), Sam -2% (measured)
- Enhanced pauses: 400-700ms between speakers, 200-350ms same speaker
- Prosody markers for filler words
- Natural turn-taking

### Technology Stack

- **LLM:** Azure OpenAI / OpenAI (with template fallback)
- **TTS:** edge-tts (free, no API keys, neural quality)
- **Architecture:** Separate script generation + rendering scripts

---

## Rationale

1. **Script quality > TTS quality:** Research shows a great script with decent TTS beats perfect TTS with a flat script
2. **Edge-TTS sufficient for Phase 1:** Free, neural quality, no API setup
3. **LLM prompts are high-leverage:** Small prompt changes produce significantly more natural output
4. **Modular architecture:** Separate script generation allows testing different LLMs or manual script editing

---

## Impact

- More natural-sounding podcasts that feel like real conversations
- Better engagement — listeners hear two people talking, not one person reading
- Foundation for Phase 2 TTS upgrades (Fish Speech, ElevenLabs)

---

## Future Phases

**Phase 2 (Optional):**
- Evaluate Fish Speech S2 (open-source, LLM-integrated) or ElevenLabs (premium) for TTS upgrade
- Fine-tune LLM prompts based on user feedback
- A/B test different host personalities

---

## References

- Research: research/active/podcast-quality/README.md
- Seven's key insight: Google NotebookLM's success comes from conversation script quality
- Issue: #455
- PR: #457
