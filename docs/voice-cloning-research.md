# Voice Cloning Research for Hebrew Podcast Generation

**Date:** 2026-03-13
**Author:** Podcaster Agent
**Issue:** #465
**Status:** ✅ MVP Delivered — edge-tts + audio style transfer working

## Executive Summary

We researched voice cloning options for Hebrew podcast generation and built a working
implementation. The key challenge: **Hebrew is not natively supported** by most open-source
voice cloning models. Our solution uses edge-tts Hebrew neural voices as a high-quality base,
with audio signal processing for voice style differentiation.

## Research Findings

### 1. Coqui TTS / XTTS v2 (Open Source)

| Aspect | Details |
|--------|---------|
| Hebrew Support | ❌ Not natively supported |
| Voice Cloning | ✅ From ~6s audio sample |
| Languages | EN, ES, FR, DE, IT, PT, PL, TR, RU, NL, CZ, AR, ZH, JA, HU, KO, HI |
| GPU Required | Strongly recommended |
| Feasibility | Would require custom fine-tuning on Hebrew data |

**Verdict:** Not viable today. Hebrew fine-tuning would take weeks of data preparation.

### 2. ElevenLabs API (Commercial)

| Aspect | Details |
|--------|---------|
| Hebrew Support | ✅ Full support |
| Voice Cloning | ✅ Instant from short sample |
| Free Tier | 10-20K chars/month |
| Quality | Excellent — best in class |
| API Key Required | Yes |

**Verdict:** Best quality option. Implemented in script but requires API key.
Script ready at `scripts/voice-clone-podcast.py --backend elevenlabs --elevenlabs-key KEY`.

### 3. OpenVoice V2 (Open Source, MyShell/MIT)

| Aspect | Details |
|--------|---------|
| Hebrew Support | ❌ Not native (EN, ES, FR, ZH, JA, KO) |
| Tone Color Cloning | ✅ Cross-language tone transfer |
| CPU Compatible | ✅ (slower than GPU) |
| Approach | Use edge-tts for Hebrew → OpenVoice tone color converter |
| License | MIT |

**Verdict:** Promising medium-term option. The pipeline would be:
1. Generate Hebrew with edge-tts
2. Apply OpenVoice tone color converter to match reference speaker
3. Requires PyTorch install (~2GB) and model download

Not implemented yet due to PyTorch size and no GPU, but documented as next step.

### 4. Azure Custom Neural Voice (Enterprise)

| Aspect | Details |
|--------|---------|
| Hebrew Support | ✅ (Azure TTS supports Hebrew) |
| Voice Cloning | Requires training data + Azure subscription |
| Quality | Enterprise-grade |
| Cost | High — requires Azure AI Services |

**Verdict:** Overkill for current needs. Reserve for production.

## What We Built

### `scripts/voice-clone-podcast.py`

A multi-backend Hebrew podcast generator with voice style transfer:

```
python scripts/voice-clone-podcast.py <script.txt> [options]
```

**Backends:**
1. **edge-tts-style** (default) — edge-tts Hebrew voices + audio style transfer
2. **elevenlabs** — ElevenLabs API with instant voice cloning
3. **openvoice** — Placeholder for OpenVoice integration

**Voice Style Transfer (edge-tts-style backend):**
- Pitch shifting (semitone-level control via resampling)
- Formant manipulation for voice character
- Warmth boost (low-frequency enhancement)
- Breathiness injection (envelope-shaped noise)
- Speed adjustment (time stretch)
- Reference audio matching (F0 analysis + pitch alignment)

**Features:**
- `--ref-avri sample.wav` — Match AVRI voice to reference recording
- `--ref-hila sample.wav` — Match HILA voice to reference recording
- `--test-clip N` — Generate short test clip (first N turns)
- `--analyze-ref file.mp3` — Analyze voice characteristics of a sample
- `--list-styles` — Show available voice style profiles

### Test Results

```
✅ Voice-cloned podcast generated!
   Backend:  edge-tts-style
   Duration: 53.0s (0.9 min)
   Size:     1.0 MB
   Turns:    6/6
   Time:     7.0s
   Voice cloning: Synthetic style profiles
```

6-turn test clip generated in 7 seconds. Both AVRI and HILA voices have distinct
characteristics applied (deeper/warmer male vs brighter/clearer female).

## Environment

- **GPU:** ❌ None (CPU only DevBox)
- **Python:** 3.12.10
- **Dependencies:** edge-tts, numpy, scipy, pydub, soundfile, imageio-ffmpeg
- **OS:** Windows (DevBox)

## Recommendations & Next Steps

### Short-term (This Week)
1. **Get ElevenLabs API key** — Free tier gives 10-20K chars/month. Instant voice
   cloning from a ~30s sample of the מפתחים מחוץ לקופסא hosts would produce
   dramatically better results.
2. **Obtain voice samples** — Record or extract 30-60s clips of Avri and Hila's
   actual voices for reference matching.

### Medium-term (Next Sprint)
3. **Install OpenVoice V2** — On a GPU-capable machine, the edge-tts → OpenVoice
   tone color converter pipeline would give near-voice-cloning quality.
4. **Experiment with XTTS v2 Hebrew fine-tuning** — If we can gather ~30 minutes
   of Hebrew training data, XTTS v2 could be fine-tuned for native Hebrew voice cloning.

### Long-term
5. **Azure Custom Neural Voice** — For production podcasts, train a custom neural
   voice model with Azure AI Services.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Hebrew Script ([AVRI]/[HILA] tagged)                   │
└──────────────────┬──────────────────────────────────────┘
                   │
         ┌─────────▼─────────┐
         │  Backend Router    │
         └─┬───────┬───────┬─┘
           │       │       │
    ┌──────▼──┐ ┌──▼───┐ ┌─▼────────┐
    │edge-tts │ │Eleven│ │OpenVoice │
    │+ Style  │ │Labs  │ │(planned) │
    │Transfer │ │API   │ │          │
    └──────┬──┘ └──┬───┘ └─┬────────┘
           │       │       │
         ┌─▼───────▼───────▼─┐
         │  WAV Segments      │
         └─────────┬──────────┘
                   │
         ┌─────────▼─────────┐
         │  Concatenation +   │
         │  Natural Pauses    │
         └─────────┬──────────┘
                   │
         ┌─────────▼─────────┐
         │  Output MP3/WAV    │
         └────────────────────┘
```

## Dependencies

```
pip install edge-tts numpy scipy pydub soundfile imageio-ffmpeg
```

Optional (for ElevenLabs backend):
```
pip install httpx
```
