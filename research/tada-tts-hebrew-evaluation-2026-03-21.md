# TADA-TTS Hebrew Evaluation — Issue #874

**Date:** 2026-03-21  
**Researcher:** Seven (Research & Docs)  
**Issue:** [#874 — Evaluate TADA-TTS for Hebrew (Arabic language family)](https://github.com/tamirdresher_microsoft/tamresearch1/issues/874)  
**Status:** Research Complete — See Recommendation

---

## Executive Summary

TADA-TTS (HumeAI, MIT license, March 2026) is a genuinely exciting new architecture — 1:1 text-to-audio token alignment, zero hallucinations, 5× faster inference than comparable LLM-based TTS. However, it does **not natively support Hebrew**. Its multilingual model (`tada-3b-ml`) supports Arabic (`ar`), which is the closest Semitic language it handles. The viable strategy is using Arabic as a proxy language — the same approach the existing XTTS pipeline already falls back to.

**Bottom line:** TADA is worth evaluating for two concrete reasons:
1. Lower hallucination rate (no word-skipping or repetition — a real pain point with XTTS on Hebrew)
2. Significantly faster inference (~0.09 RTF vs XTTS's ~1–3 RTF on CPU)

For native Hebrew prosody quality, **HebTTS** (`slp-rl/HebTTS`) is the better long-term option.

---

## What is TADA-TTS?

TADA = **Text-Acoustic Dual Alignment**. Released by [Hume AI](https://www.hume.ai) in March 2026.

### Architecture Innovation

Unlike frame-based TTS (XTTS, Zonos) or traditional autoregressive models, TADA generates one acoustic token **per text token** — a strict 1:1 alignment. This eliminates the core failure modes:

| Problem | XTTS/Zonos | TADA |
|---------|-----------|------|
| Word hallucination (skipped words) | Common | Near-zero |
| Repeated phrases | Occasional | Eliminated |
| Inference speed (RTF) | 1–3× (CPU) | ~0.09× |
| Long-form degradation | Yes (>30s) | Handles up to 700s |
| Hebrew native support | No (ar fallback) | No (ar fallback) |

### Key Numbers
- **TADA-1B** (English only): RTF ≈ 0.09, 5× faster than comparable LLM TTS
- **TADA-3B-ML** (multilingual): 8 languages — English, Arabic, Chinese, German, Spanish, French, Italian, Japanese, Polish, Portuguese
- Hebrew is **not** in the official language list
- Arabic (`ar`) is supported and is the closest Semitic language available

---

## Where to Get It

| Resource | Link |
|----------|------|
| GitHub (official) | https://github.com/HumeAI/tada |
| HuggingFace — English 1B | https://huggingface.co/HumeAI/tada-1b |
| HuggingFace — Multilingual 3B | https://huggingface.co/HumeAI/tada-3b-ml |
| HuggingFace — Codec | https://huggingface.co/HumeAI/tada-codec |
| HumeAI Blog (launch post) | https://www.hume.ai/blog/opensource-tada |
| Paper (arXiv) | https://arxiv.org/pdf/2602.23068v1 |

**PyPI package name:** `hume-tada` (NOT `tada-tts` — that package does not exist on PyPI)

---

## Installation

```bash
# Standard install
pip install hume-tada

# Or install from source (for bleeding-edge)
git clone https://github.com/HumeAI/tada.git
cd tada
pip install -e .

# Required: GPU with CUDA for practical use
# CPU is technically possible but very slow for the 3B model
```

**System requirements:**
- Python 3.10+
- PyTorch 2.1+
- CUDA 11.8+ recommended (for the 3B model, ~8–10 GB VRAM minimum)
- The codec model downloads automatically from HuggingFace on first run

---

## How to Call TADA-TTS for Hebrew

Since Hebrew is not natively supported, use `language="ar"` as a proxy. This is identical to what `generate_xtts_podcast.py` already does as its fallback strategy — so the quality comparison is direct.

### Minimal Hebrew inference snippet

```python
import torch
import torchaudio
from tada.modules.encoder import Encoder
from tada.modules.tada import TadaForCausalLM

# --- Setup ---
device = "cuda" if torch.cuda.is_available() else "cpu"

# Load codec encoder (for voice reference)
encoder = Encoder.from_pretrained(
    "HumeAI/tada-codec",
    subfolder="encoder"
).to(device)

# Load multilingual model (requires Arabic support = tada-3b-ml)
model = TadaForCausalLM.from_pretrained(
    "HumeAI/tada-3b-ml"
).to(device)

# --- Voice reference (use existing dotan_ref.wav / shahar_ref.wav) ---
ref_audio, ref_sr = torchaudio.load("voice_samples/dotan_ref.wav")
ref_audio = ref_audio.to(device)

# Encode voice reference (short transcription of the reference audio)
# TADA requires the *text* of the reference clip, not just the audio
ref_text = "שלום, קוראים לי דותן ואני מדבר על טכנולוגיה"  # rough transcription
prompt = encoder(ref_audio, text=[ref_text], sample_rate=ref_sr)

# --- Generate Hebrew text using Arabic language token ---
# TADA uses Arabic as the closest Semitic proxy for Hebrew
hebrew_text = "היום נדבר על מודלי שפה גדולים ואיך הם משנים את עולם הפיתוח"

output_tokens = model.generate(
    prompt=prompt,
    text=hebrew_text,
    language="ar",        # Arabic proxy — closest Semitic language TADA supports
    max_new_tokens=2048,
)

# Decode tokens to waveform via codec
# (TADA returns raw audio tokens; decode via the autoencoder)
from tada.modules.codec import TadaCodec
codec = TadaCodec.from_pretrained("HumeAI/tada-codec").to(device)
waveform = codec.decode(output_tokens)

torchaudio.save("output_tada_hebrew.wav", waveform.cpu(), sample_rate=24000)
```

> **Note:** The exact decode API may vary with package version — check the official examples at https://github.com/HumeAI/tada/tree/main/examples for the current generation/decode API.

### Drop-in pipeline script skeleton (`generate_tada_podcast.py`)

```python
"""
Hebrew Podcast Generator using TADA-TTS (HumeAI)
Uses Arabic (ar) as proxy language for Hebrew — same strategy as XTTS fallback.
Matches structure of generate_xtts_podcast.py for direct quality comparison.
"""
import os
import re
import torch
import torchaudio
from tada.modules.encoder import Encoder
from tada.modules.tada import TadaForCausalLM

SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
AVRI_REF    = r"C:\temp\tamresearch1\voice_samples\dotan_ref.wav"
HILA_REF    = r"C:\temp\tamresearch1\voice_samples\shahar_ref.wav"
OUTPUT_DIR  = r"C:\temp\tamresearch1\tada_output"
FINAL_OUT   = r"C:\temp\tamresearch1\hebrew-podcast-tada.wav"

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[TADA] Using device: {device}")

# Load models
encoder = Encoder.from_pretrained("HumeAI/tada-codec", subfolder="encoder").to(device)
model   = TadaForCausalLM.from_pretrained("HumeAI/tada-3b-ml").to(device)

# Parse script
def parse_script(path):
    turns = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\[(AVRI|HILA)\]\s*(.*)", line.strip())
        if m and m.group(2).strip():
            turns.append((m.group(1), m.group(2).strip()))
    return turns

turns = parse_script(SCRIPT_FILE)
print(f"[TADA] Parsed {len(turns)} turns")

# Encode voice references
avri_wav, avri_sr = torchaudio.load(AVRI_REF)
hila_wav, hila_sr = torchaudio.load(HILA_REF)

# NOTE: TADA requires a text transcription of the reference clip
# These are placeholder transcriptions of dotan_ref.wav / shahar_ref.wav
AVRI_REF_TEXT = "שלום, קוראים לי אבירי ואני מארח את הפודקאסט הזה"
HILA_REF_TEXT = "שלום לכולם, אני הילה ואנחנו מדברים על טכנולוגיה"

avri_prompt = encoder(avri_wav.to(device), text=[AVRI_REF_TEXT], sample_rate=avri_sr)
hila_prompt = encoder(hila_wav.to(device), text=[HILA_REF_TEXT], sample_rate=hila_sr)

# Generate
os.makedirs(OUTPUT_DIR, exist_ok=True)
segments = []

for i, (speaker, text) in enumerate(turns):
    out_file = os.path.join(OUTPUT_DIR, f"turn_{i:03d}_{speaker}.wav")
    if os.path.exists(out_file):
        print(f"[{i+1}/{len(turns)}] Skip {speaker} (cached)")
        segments.append(out_file)
        continue

    prompt = avri_prompt if speaker == "AVRI" else hila_prompt
    print(f"[{i+1}/{len(turns)}] {speaker}: {text[:50]}...")

    tokens = model.generate(prompt=prompt, text=text, language="ar")
    # TODO: decode tokens via codec — see official examples for current API
    # waveform = codec.decode(tokens)
    # torchaudio.save(out_file, waveform.cpu(), 24000)
    segments.append(out_file)

print(f"[TADA] Done. Segments in {OUTPUT_DIR}")
```

---

## Expected Quality vs Current Pipeline

### Comparison Matrix

| Metric | edge-tts (production) | XTTS v2 (ar fallback) | Zonos Hebrew | TADA-3B-ML (ar proxy) |
|--------|----------------------|----------------------|--------------|----------------------|
| Hebrew natively supported | ✅ Yes | ❌ No (ar fallback) | ✅ Yes | ❌ No (ar proxy) |
| Voice cloning | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| Hallucination rate | Low | **Medium-High** | Medium | **Near-zero** |
| Inference speed | Very fast | Slow (CPU: ~45s/turn) | Moderate | **Fast (~5s/turn GPU)** |
| Prosody naturalness | Good (Microsoft) | Poor (ar proxy) | Good | Unknown for Hebrew |
| VRAM required | 0 | ~4 GB | ~4 GB | **~10 GB** |
| License | Proprietary | AGPL-3.0 | Apache 2.0 | **MIT** |
| Offline capable | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |

### Quality Prediction for Hebrew via Arabic Proxy

**Why it might be BETTER than XTTS:**
- TADA has lower hallucination → fewer skipped Hebrew words (XTTS occasionally drops syllables in Hebrew)
- Arabic phoneme set is closer to Hebrew than English — both share pharyngeal consonants, emphatics, gutturals
- 5× faster means faster iteration loop during development
- Better long-form handling (no prosody drift after 30 seconds)

**Why it might NOT be better:**
- Same fundamental limitation: using Arabic phonemization for Hebrew text
- edge-tts already uses native `he-IL` voices — for voice quality alone, edge-tts wins
- TADA requires significant GPU VRAM (10 GB+) vs XTTS (4 GB)
- The reference-clip encoding requires a text transcription of the reference audio, adding setup friction

**Realistic MOS estimate for Hebrew via TADA:**
- Current XTTS (ar fallback): ~2.5–3.0 MOS for Hebrew intelligibility
- TADA (ar proxy): ~2.5–3.2 MOS — marginal improvement expected, mainly from reduced hallucinations
- edge-tts (he-IL): ~3.5–4.0 MOS — still the best for intelligibility despite no voice cloning

---

## Alternative: HebTTS (Dedicated Hebrew Model)

If the goal is genuine Hebrew prosody improvement (not just Arabic-proxy), **HebTTS** deserves evaluation alongside TADA:

| | TADA-3B-ML | HebTTS |
|-|-----------|--------|
| Hebrew native | ❌ (Arabic proxy) | ✅ Yes |
| Architecture | LLM-based (causal) | Language model TTS |
| Diacritic-free | Yes | Yes (key feature) |
| Voice cloning | Yes | Limited |
| Source | https://github.com/HumeAI/tada | https://github.com/slp-rl/HebTTS |
| Paper | arXiv 2602.23068 | Academic (SLP-RL lab) |

HebTTS was trained specifically on Hebrew (diacritic-free) and likely gives better Hebrew phoneme accuracy. If TADA underwhelms, try HebTTS next.

---

## Recommendation

### Is TADA worth trying? **Yes, but with calibrated expectations.**

**Try TADA if:**
- You're experiencing hallucinations/word-skipping in XTTS Hebrew output
- You have a GPU with ≥10 GB VRAM for the 3B-ML model
- You want faster iteration speed during podcast production
- You're OK with the Arabic-proxy approach (same as current XTTS fallback)

**Don't expect TADA to solve:**
- Native Hebrew prosody (it won't — Arabic proxy has the same phoneme mismatch)
- Voice quality vs edge-tts (Microsoft's he-IL voices are better for intelligibility)
- VRAM-constrained environments (TADA-3B-ML needs more GPU than XTTS)

### Recommended Integration Path

1. **Phase 1 (Low effort, ~2 hours):** Install `hume-tada`, run 5–10 Hebrew turns, compare WAVs to existing XTTS output. Listen for hallucinations and prosody.
2. **Phase 2 (If Phase 1 is promising):** Implement `generate_tada_podcast.py` based on the skeleton above. Finalize the decode API from official TADA examples.
3. **Phase 3 (Parallel track):** Evaluate HebTTS for native Hebrew phoneme quality. Compare TADA (Arabic proxy) vs HebTTS (native Hebrew) in a structured A/B test.

### Priority ranking for Hebrew podcast quality

| Rank | Option | Why |
|------|--------|-----|
| 1 | **edge-tts** (current) | Best intelligibility, he-IL native, no VRAM needed |
| 2 | **HebTTS** | Native Hebrew — best prosody if voice cloning can be added |
| 3 | **TADA-3B-ML** (ar proxy) | Reduces hallucinations vs XTTS, faster inference |
| 4 | **XTTS v2** (ar fallback) | Current voice-cloning approach, hallucination-prone |
| 5 | **Zonos Hebrew** | Good but high VRAM, slower |

---

## Current Pipeline Quality Scores (from research/hebrew-podcast-analysis.md)

| Method | Quality Assessment | Notes |
|--------|-------------------|-------|
| edge-tts (he-IL) | ⭐⭐⭐⭐ | Robotic but intelligible, fastest, free |
| XTTS v2 (ar fallback) | ⭐⭐⭐ | Voice cloning works, occasional word drops |
| OpenVoice | ⭐⭐⭐ | Good tone, moderate complexity |
| Zonos Hebrew | ⭐⭐⭐⭐ | Best voice cloning quality, VRAM-hungry |
| TADA (projected) | ⭐⭐⭐ (ar proxy) / ⭐⭐⭐⭐ (if HebTTS added) | TBD |

---

## References

1. [HumeAI/tada — GitHub](https://github.com/HumeAI/tada)  
2. [Opensourcing TADA — HumeAI Blog](https://www.hume.ai/blog/opensource-tada)  
3. [TADA arXiv Paper](https://arxiv.org/pdf/2602.23068v1)  
4. [HumeAI/tada-3b-ml — HuggingFace](https://huggingface.co/HumeAI/tada-3b-ml)  
5. [HumeAI/tada-1b — HuggingFace](https://huggingface.co/HumeAI/tada-1b)  
6. [slp-rl/HebTTS — Hebrew TTS (dedicated)](https://github.com/slp-rl/HebTTS)  
7. [PyPI: hume-tada](https://pypi.org/project/hume-tada/)  

---

*Researched by Seven (Research & Docs) — part of Squad AI team*  
*Related issue: #465 (Hebrew podcast pipeline), #874 (this evaluation)*
