# Decision: F5-TTS Voice Cloning Infrastructure

**Date:** 2026-03-14
**Author:** B'Elanna (DevOps/Infrastructure)
**Status:** Implemented

## Context

Tamir requested real voice-cloned Hebrew podcasts using F5-TTS with voice samples from the מפתחים מחוץ לקופסא hosts (Dotan and Shahar). Initial assumption was that a GPU VM or DevBox would be needed since "this machine has no GPU."

## Decision

Run F5-TTS locally on the machine's RTX 500 Ada GPU (4GB VRAM) with 3 compatibility patches, avoiding cloud costs entirely.

## Patches Required (Windows + torchaudio 2.10 + low RAM)

1. **safetensors tensor-by-tensor loading** — Windows paging file limit prevents loading 1.2GB model at once. Load each tensor individually via `safe_open()`.
2. **torchaudio.load → soundfile** — torchaudio 2.10 forces torchcodec which has broken DLLs on Windows. Monkey-patch to use soundfile backend.
3. **ffmpeg PATH from imageio-ffmpeg** — F5-TTS uses Whisper for auto-transcription which needs ffmpeg. Use `imageio_ffmpeg` binary or provide non-empty `ref_text` to skip.

## Alternatives Considered

| Option | Status | Notes |
|--------|--------|-------|
| DevBox | Skipped | `az devcenter` extension install failed; DevBox GPU uncertain |
| Azure GPU VM | Skipped | Unnecessary — local GPU works |
| Coqui XTTS v2 | Failed | Requires Python <3.12 (we have 3.12.7) |
| ElevenLabs | Rejected | Tamir said NO PAYING |
| edge-tts + style transfer | Fallback | Works but not real voice cloning |

## Outcome

- **Output:** `hebrew-podcast-f5tts.mp3` — 24 turns, 19.3 min, 22.1 MB
- **Runner script:** `scripts/f5tts-podcast-runner.py` — reusable for future podcasts
- **Cost:** $0 (all local, all free/open-source)
- **Render time:** ~36 minutes on RTX 500 Ada

## Recommendations

1. Keep `f5tts-podcast-runner.py` as the standard entry point for voice-cloned podcasts
2. If upgrading torchaudio, re-test torchcodec compatibility
3. For faster rendering, consider DevBox with dedicated GPU or Colab notebooks
4. Reference audio quality matters — 20s mono WAV at 24kHz is the sweet spot
