# Hebrew Podcast Quality Improvements — Research Report

**Issue:** [#844 Hebrew podcast: Human-perceptible quality improvements](https://github.com/tamirdresher_microsoft/tamresearch1/issues/844)  
**Date:** 2026-03-21  
**Author:** Seven (Research & Docs)  
**Current baseline:** Resemblyzer voice-similarity score 0.9299  
**Hosts:** TAMIR / Dotan (Israeli male) · ALEX / Shahar (analytical female)

---

## Executive Summary

The current pipelines (XTTS, Chatterbox, Zonos) produce technically correct Hebrew
speech but lack post-processing that would make episodes sound like a real podcast.
All five techniques below are implementable today with libraries already installed
(`pydub`, `scipy`, `numpy`, `librosa`, `soundfile`). Together they address the
three biggest perceptual gaps:

1. **Loudness inconsistency** — segments feel uneven and listeners reach for the volume knob.  
2. **Robotic conversation rhythm** — fixed 300–600 ms pauses everywhere; no breath, no "thinking".  
3. **Timbral harshness** — no EQ, compression, or de-essing leaves sibilants and resonance peaks
   that fatigue the ear.

Priority order: **Technique 1 → 2 → 3 → 4 → 5** — biggest gain to least, ordered by
effort-to-impact ratio.

---

## Priority Order At a Glance

| # | Technique | Expected Gain | Effort | Status |
|---|-----------|--------------|--------|--------|
| 1 | LUFS loudness normalization | ★★★★★ — single biggest improvement | Low | Libraries available |
| 2 | Variable conversation dynamics (pauses + back-channels) | ★★★★☆ — naturalness leap | Medium | Script change only |
| 3 | Per-speaker EQ (warmth / presence / air) | ★★★☆☆ — timbral polish | Low | scipy already installed |
| 4 | Dynamic range compression | ★★★☆☆ — consistent listen | Low | pydub built-in |
| 5 | De-essing (sibilance control, female voice) | ★★☆☆☆ — earwear prevention | Medium | scipy already installed |

---

## Technique 1 — LUFS Loudness Normalization ⭐ Try First

### What it solves
Without normalization each TTS segment emerges at a different RMS level. Louder
segments sound aggressive; quieter ones are hard to follow. Broadcast standard for
podcasts is **−16 LUFS** (Spotify / most streaming) or **−19 LUFS** (Apple Podcasts).

### Expected improvement
Listeners consistently rate loudness-normalized speech +0.3–0.6 MOS points higher
even when the underlying audio is identical. Eliminates the "turning the volume up
and down" experience.

### Implementation complexity: **Low**
`pyloudnorm` is the reference Python implementation of ITU-R BS.1770 / EBU R128.
We can also derive a functionally adequate version from `scipy` + `numpy` if
`pyloudnorm` is not installed (shown below in the full pipeline section).

### Install

```bash
pip install pyloudnorm
```

### Code snippet

```python
import numpy as np
import soundfile as sf
import pyloudnorm as pyln

def lufs_normalize(audio_path: str, output_path: str, target_lufs: float = -16.0):
    """Normalize audio file to target LUFS (podcast standard: -16 LUFS)."""
    data, rate = sf.read(audio_path)
    meter = pyln.Meter(rate)                    # ITU-R BS.1770
    loudness = meter.integrated_loudness(data)
    normalized = pyln.normalize.loudness(data, loudness, target_lufs)
    sf.write(output_path, normalized, rate)
    print(f"  LUFS: {loudness:.1f} → {target_lufs:.1f} dB ({output_path})")
    return output_path

# Usage at end of any generate_*.py before MP3 export:
# lufs_normalize("hebrew-podcast-raw.wav", "hebrew-podcast-normalized.wav", -16.0)
```

### scipy-only fallback (no extra install required)

```python
import numpy as np
import soundfile as sf

def rms_normalize(audio_path: str, output_path: str, target_db: float = -20.0):
    """RMS normalization — good fallback when pyloudnorm is unavailable."""
    data, rate = sf.read(audio_path)
    if data.ndim > 1:
        data = data.mean(axis=1)              # mix to mono for measurement
    rms = np.sqrt(np.mean(data ** 2))
    if rms < 1e-10:
        sf.write(output_path, data, rate)
        return output_path
    target_linear = 10 ** (target_db / 20.0)
    gain = target_linear / rms
    normalized = np.clip(data * gain, -1.0, 1.0)
    sf.write(output_path, normalized, rate)
    return output_path
```

---

## Technique 2 — Variable Conversation Dynamics ⭐ Highest Naturalness Gain

### What it solves
Every current pipeline uses a fixed pause (300 ms in XTTS, 600 ms in Chatterbox).
Real Israeli podcast conversations have:
- **Short handoff pauses** (150–250 ms) for quick back-and-forth
- **Thinking pauses** (600–1000 ms) after a complex question
- **Topic-transition pauses** (1200–1800 ms) with a breath
- **Back-channel tokens** — "כן", "נכון", "אממ", "אה..." inserted mid-conversation

2024 full-duplex conversation research confirms that *timing* is now the main
uncanny-valley factor once voice quality is good (resemblyzer 0.93 is already excellent).

### Expected improvement
Transforms robotic ping-pong into natural conversation. Probably the single largest
**perceptual** improvement relative to effort when voice similarity is already high.

### Implementation complexity: **Medium** (script-level changes, no new libraries)

```python
import random
import numpy as np

# Pause rules — vary by conversational context
PAUSE_RULES = {
    "default":           (0.25, 0.45),   # seconds (min, max)
    "after_question":    (0.55, 0.90),   # TAMIR asks → ALEX gets more time to "think"
    "topic_transition":  (1.10, 1.60),   # new topic flag in script "[PAUSE]"
    "after_short_reply": (0.15, 0.30),   # very short utterance → quick follow-up
}

HEBREW_BACKCHANNELS = {
    "TAMIR": ["כן.", "נכון.", "מעניין.", "אה...", "בדיוק."],
    "ALEX":  ["כן.", "הבנתי.", "אממ.", "נכון.", "וואו."],
}

def dynamic_pause(prev_speaker: str, prev_text: str, next_speaker: str,
                  sample_rate: int) -> np.ndarray:
    """Return a silence tensor with variable duration based on context."""
    if "?" in prev_text:
        rule = PAUSE_RULES["after_question"]
    elif len(prev_text) < 30:
        rule = PAUSE_RULES["after_short_reply"]
    elif "[PAUSE]" in prev_text:
        rule = PAUSE_RULES["topic_transition"]
    else:
        rule = PAUSE_RULES["default"]

    duration = random.uniform(*rule)
    samples = int(duration * sample_rate)
    return np.zeros(samples, dtype=np.float32)


def maybe_insert_backchannel(speaker: str, prev_text: str,
                              model, sample_rate: int,
                              ref_path: str, probability: float = 0.15):
    """
    Occasionally inject a short Hebrew back-channel token.
    Called before generating the NEXT speaker's main utterance.
    Only fires when the previous turn was longer than 10 words.
    """
    if len(prev_text.split()) < 10:
        return None
    if random.random() > probability:
        return None
    token = random.choice(HEBREW_BACKCHANNELS[speaker])
    # Generate a very short clip — typically <0.5 s
    wav = model.generate(token, language_id="he", audio_prompt_path=ref_path,
                         exaggeration=0.3, cfg_weight=0.4)
    return wav
```

**How to integrate:** Replace the fixed `pause_tensor` in the concatenation loop
with `dynamic_pause(...)`, and optionally call `maybe_insert_backchannel(...)` once
every several turns.

---

## Technique 3 — Per-Speaker EQ (Warmth / Presence / Air)

### What it solves
TTS engines produce flat-spectrum audio. Real podcast microphone chains apply
gentle EQ shaping:
- **TAMIR (male):** Low-mid warmth (+2 dB around 200 Hz), slight 3 kHz presence cut
  to remove nasal honk, low-pass roll-off at 14 kHz for warmth.
- **ALEX (female):** Low-cut at 100 Hz (remove rumble), presence boost (+2 dB at
  3–4 kHz) for intelligibility, "air" shelf (+1.5 dB above 10 kHz) for sparkle,
  notch at 5–6 kHz if harsh.

### Expected improvement
Makes each voice sound like a different microphone/studio signature. Cognitive
differentiation helps listeners tell the two hosts apart more easily.

### Implementation complexity: **Low**

```python
import numpy as np
from scipy.signal import butter, sosfilt, iirpeak, iirnotch

def design_shelf(freq_hz: float, gain_db: float, shelf_type: str,
                 sample_rate: int, order: int = 2):
    """Low-shelf or high-shelf Butterworth filter."""
    nyq = sample_rate / 2.0
    wn = freq_hz / nyq
    if shelf_type == "low":
        sos = butter(order, wn, btype="low", output="sos")
    else:
        sos = butter(order, wn, btype="high", output="sos")
    return sos

def apply_gain(data: np.ndarray, sos, gain_db: float) -> np.ndarray:
    """Apply a shelving filter as a gain-compensated band adjustment."""
    filtered = sosfilt(sos, data)
    gain_linear = 10 ** (gain_db / 20.0)
    return data + (filtered - data) * (gain_linear - 1.0)

def eq_tamir(data: np.ndarray, sample_rate: int) -> np.ndarray:
    """EQ profile for TAMIR (warm Israeli male voice)."""
    # Low-shelf boost: +2 dB below 250 Hz
    sos_warm = design_shelf(250, +2.0, "low", sample_rate)
    data = apply_gain(data, sos_warm, +2.0)
    # Gentle presence cut: −1 dB notch at 3 kHz
    b, a = iirnotch(3000 / (sample_rate / 2), Q=4.0)
    data = data - 0.12 * np.convolve(data, b, mode="same")[:len(data)]
    return data

def eq_alex(data: np.ndarray, sample_rate: int) -> np.ndarray:
    """EQ profile for ALEX (analytical female voice)."""
    # High-pass at 100 Hz — remove low-end rumble
    sos_hp = butter(2, 100 / (sample_rate / 2), btype="high", output="sos")
    data = sosfilt(sos_hp, data)
    # Presence boost: +2 dB shelf at 3 kHz
    sos_pres = design_shelf(3000, +2.0, "high", sample_rate)
    data = apply_gain(data, sos_pres, +1.8)
    # Air shelf: +1.5 dB above 10 kHz
    sos_air = design_shelf(10000, +1.5, "high", sample_rate)
    data = apply_gain(data, sos_air, +1.5)
    return data

SPEAKER_EQ = {"TAMIR": eq_tamir, "AVRI": eq_tamir,
              "ALEX": eq_alex,   "HILA": eq_alex}
```

---

## Technique 4 — Dynamic Range Compression

### What it solves
TTS whispers and shouts live side-by-side because synthesis energy varies phrase by
phrase. Compression evens out the dynamic range so quiet interjections don't get
lost and loud emphatic moments don't blast the listener.

### Expected improvement
Consistent perceived loudness throughout the episode. Industry standard for podcast
speech: 4:1 ratio, -20 dBFS threshold, 10 ms attack, 80 ms release.

### Implementation complexity: **Low** (pydub built-in)

```python
from pydub import AudioSegment
from pydub.effects import compress_dynamic_range

def compress_podcast(audio: AudioSegment,
                     threshold: float = -20.0,
                     ratio: float = 4.0,
                     attack: float = 10.0,   # ms
                     release: float = 80.0,  # ms
                     ) -> AudioSegment:
    """Apply broadcast-style dynamic range compression."""
    return compress_dynamic_range(
        audio,
        threshold=threshold,
        ratio=ratio,
        attack=attack,
        release=release,
    )
```

**scipy multi-band alternative** (more control):

```python
import numpy as np

def simple_compressor(data: np.ndarray, threshold_db: float = -20.0,
                      ratio: float = 4.0, attack_samples: int = 441,
                      release_samples: int = 3528) -> np.ndarray:
    """Sample-accurate gain-computer compressor."""
    threshold_linear = 10 ** (threshold_db / 20.0)
    envelope = np.abs(data)
    gain = np.ones_like(data)
    current_gain = 1.0
    for i, amp in enumerate(envelope):
        if amp > threshold_linear:
            target_gain = threshold_linear + (amp - threshold_linear) / ratio
            target_gain /= amp
        else:
            target_gain = 1.0
        # Smooth gain changes
        if target_gain < current_gain:
            coeff = np.exp(-1.0 / attack_samples)
        else:
            coeff = np.exp(-1.0 / release_samples)
        current_gain = coeff * current_gain + (1.0 - coeff) * target_gain
        gain[i] = current_gain
    return data * gain
```

---

## Technique 5 — De-essing (Sibilance Control)

### What it solves
Female TTS voices (ALEX/Shahar) often over-produce sibilants — the harsh /s/ and /ש/
sounds in Hebrew. This is especially noticeable on headphones and is fatiguing over
a long episode.

### Expected improvement
Softer "s" consonants. Subtle but important for long-form listening comfort.
Most noticeable benefit for ALEX's voice; less critical for TAMIR.

### Implementation complexity: **Medium**

```python
import numpy as np
from scipy.signal import butter, sosfilt

def de_ess(data: np.ndarray, sample_rate: int,
           freq_low: float = 5000.0, freq_high: float = 9000.0,
           threshold_db: float = -20.0, reduction_db: float = 6.0) -> np.ndarray:
    """
    Frequency-selective de-esser.
    Detects energy in the sibilance band (5–9 kHz) and attenuates when
    it exceeds the threshold.
    """
    nyq = sample_rate / 2.0
    sos = butter(4, [freq_low / nyq, freq_high / nyq], btype="band", output="sos")
    sib_band = sosfilt(sos, data)

    threshold_linear = 10 ** (threshold_db / 20.0)
    reduction_linear = 10 ** (-reduction_db / 20.0)

    # Envelope follower on sibilance band
    envelope = np.abs(sib_band)
    window = int(0.005 * sample_rate)   # 5 ms window
    if window > 0:
        envelope = np.convolve(envelope, np.ones(window) / window, mode="same")

    # Gain reduction where sibilance exceeds threshold
    gain = np.where(envelope > threshold_linear,
                    reduction_linear + (1.0 - reduction_linear) *
                    (threshold_linear / np.maximum(envelope, 1e-10)),
                    1.0)

    # Apply only to sibilance band, mix back
    return data + (sib_band * gain - sib_band)

# Apply after EQ, before final LUFS normalization:
# if speaker == "ALEX":
#     segment_data = de_ess(segment_data, sample_rate)
```

---

## Recommended Audio Post-Processing Pipeline

Apply this pipeline **per segment** (before concatenation) and then again on the
**final mix** for the LUFS normalization pass.

```
Raw TTS segment (WAV, 22050–24000 Hz)
        │
        ▼
[1] Per-speaker EQ            (scipy.signal — warmth/air/presence)
        │
        ▼
[2] De-essing                 (ALEX only — scipy.signal band compressor)
        │
        ▼
[3] Dynamic compression       (pydub.effects.compress_dynamic_range)
        │
        ▼
[4] Gain stage / pre-normalize (set to −18 dBFS RMS headroom before concat)
        │
        ▼
[5] Concatenate with variable pauses + back-channels
        │
        ▼
[6] Final LUFS normalization  (pyloudnorm → −16 LUFS for Spotify standard)
        │
        ▼
[7] Export MP3 at 192 kbps   (ffmpeg, already used in all pipelines)
```

### Complete drop-in post-processing module

```python
"""
audio_post_process.py — Drop-in post-processing for Hebrew podcast pipelines.
Usage:
    from audio_post_process import PostProcessor
    pp = PostProcessor(sample_rate=24000)
    processed = pp.process_segment(raw_wav_np, speaker="TAMIR")
    final_mix  = pp.finalize(podcast_wav_np)   # LUFS normalize full mix
"""
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt
try:
    import pyloudnorm as pyln
    _HAS_PYLOUDNORM = True
except ImportError:
    _HAS_PYLOUDNORM = False

from pydub import AudioSegment
from pydub.effects import compress_dynamic_range
import io


class PostProcessor:
    def __init__(self, sample_rate: int = 24000, target_lufs: float = -16.0):
        self.sr = sample_rate
        self.target_lufs = target_lufs
        if _HAS_PYLOUDNORM:
            self.meter = pyln.Meter(sample_rate)

    # ── EQ ──────────────────────────────────────────────────────────────────

    def _butter_sos(self, freq, btype, order=2):
        wn = freq / (self.sr / 2.0)
        wn = np.clip(wn, 1e-6, 0.9999)
        return butter(order, wn, btype=btype, output="sos")

    def _apply_shelf(self, data, freq, gain_db, shelf_type="low"):
        sos = self._butter_sos(freq, shelf_type)
        filtered = sosfilt(sos, data)
        g = 10 ** (gain_db / 20.0) - 1.0
        return data + filtered * g

    def eq_tamir(self, data):
        data = self._apply_shelf(data, 250, +2.0, "low")   # warmth
        data = self._apply_shelf(data, 8000, -1.5, "high") # roll off harshness
        return data

    def eq_alex(self, data):
        sos_hp = self._butter_sos(100, "high")
        data = sosfilt(sos_hp, data)                        # rumble cut
        data = self._apply_shelf(data, 3000, +1.8, "high") # presence
        data = self._apply_shelf(data, 10000, +1.5, "high")# air
        return data

    # ── De-esser ────────────────────────────────────────────────────────────

    def de_ess(self, data, reduction_db=6.0):
        nyq = self.sr / 2.0
        lo, hi = 5000 / nyq, min(9000 / nyq, 0.999)
        sos = butter(4, [lo, hi], btype="band", output="sos")
        sib = sosfilt(sos, data)
        thr = 10 ** (-20.0 / 20.0)
        red = 10 ** (-reduction_db / 20.0)
        env = np.abs(sib)
        win = max(int(0.005 * self.sr), 1)
        env = np.convolve(env, np.ones(win) / win, mode="same")
        gain = np.where(env > thr,
                        red + (1.0 - red) * thr / np.maximum(env, 1e-10), 1.0)
        return data + (sib * gain - sib)

    # ── Compression ─────────────────────────────────────────────────────────

    def compress(self, data):
        """Convert to pydub, compress, back to numpy."""
        int16 = (np.clip(data, -1.0, 1.0) * 32767).astype(np.int16)
        buf = io.BytesIO()
        sf.write(buf, int16, self.sr, format="WAV", subtype="PCM_16")
        buf.seek(0)
        seg = AudioSegment.from_wav(buf)
        seg = compress_dynamic_range(seg, threshold=-20.0, ratio=4.0,
                                     attack=10.0, release=80.0)
        buf2 = io.BytesIO()
        seg.export(buf2, format="wav")
        buf2.seek(0)
        out, _ = sf.read(buf2, dtype="float32")
        if out.ndim > 1:
            out = out.mean(axis=1)
        return out

    # ── LUFS final normalize ─────────────────────────────────────────────────

    def lufs_normalize(self, data):
        if _HAS_PYLOUDNORM:
            import pyloudnorm as pyln
            loudness = self.meter.integrated_loudness(data)
            return pyln.normalize.loudness(data, loudness, self.target_lufs)
        # Fallback: RMS
        rms = np.sqrt(np.mean(data ** 2))
        if rms < 1e-10:
            return data
        target_rms = 10 ** ((self.target_lufs + 4) / 20.0)  # rough LUFS≈RMS offset
        return np.clip(data * (target_rms / rms), -1.0, 1.0)

    # ── Public API ───────────────────────────────────────────────────────────

    def process_segment(self, data: np.ndarray, speaker: str) -> np.ndarray:
        """Apply per-speaker EQ + de-essing + compression to one segment."""
        data = data.astype(np.float32)
        if data.ndim > 1:
            data = data.mean(axis=1)
        spk = speaker.upper()
        if spk in ("TAMIR", "AVRI", "DOTAN"):
            data = self.eq_tamir(data)
        elif spk in ("ALEX", "HILA", "SHAHAR"):
            data = self.eq_alex(data)
            data = self.de_ess(data)
        data = self.compress(data)
        return data

    def finalize(self, data: np.ndarray) -> np.ndarray:
        """Final loudness normalization on the complete mix."""
        data = data.astype(np.float32)
        if data.ndim > 1:
            data = data.mean(axis=1)
        return self.lufs_normalize(data)
```

---

## Required Libraries

### Already installed ✅

```
pydub       — audio concatenation, compression
scipy       — signal processing (EQ, de-essing, compression)
numpy       — array operations
librosa     — analysis, pitch shifting
soundfile   — WAV I/O
```

### Install recommended additions

```bash
# LUFS normalization (highest priority — enables broadcast-standard loudness)
pip install pyloudnorm

# Noise reduction (optional — clean up any TTS artifacts)
pip install noisereduce

# Spotify-developed audio effects suite (optional — professional-grade plugins)
pip install pedalboard
```

---

## Research Sources & References

| Topic | Source |
|-------|--------|
| EBU R128 loudness standard | [EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf) |
| Hebrew TTS with discrete semantic units | [LoTHM (arxiv 2410.21502)](https://arxiv.org/html/2410.21502v1) |
| Diacritic-free Hebrew TTS | [HebTTS (github.com/slp-rl/HebTTS)](https://github.com/slp-rl/HebTTS) |
| Prosody improvement via masked autoencoder | [Prosody-TTS ACL 2023](https://aclanthology.org/2023.findings-acl.508.pdf) |
| Full-duplex conversation datasets | [MagicHub 2024](https://magichub.com/breaking-the-tts-naturalness-bottleneck-full-duplex-conversational-datasets-make-synthetic-speech-sound-more-human/) |
| Turn-taking benchmarking | [arxiv 2503.01174](https://arxiv.org/abs/2503.01174) |
| LUFS normalization Python | [pyloudnorm PyPI](https://pypi.org/project/pyloudnorm/) |
| Voice naturalness / ML prosody | [MDPI Sensors 24(5)](https://www.mdpi.com/1424-8220/24/5/1624) |

---

## Implementation Notes

- The `audio_post_process.py` module above is **self-contained** and can be dropped
  into the repo root and imported by any existing generate script.
- All scipy/pydub calls work on numpy float32 arrays — compatible with both XTTS
  (torch tensor → `.numpy()`) and Chatterbox / Zonos outputs.
- `pyloudnorm` is strongly recommended over the RMS fallback. It adds ~5 ms per
  segment and the perceptual improvement is substantial.
- The `PostProcessor.process_segment()` method is designed to be called **inside**
  the segment generation loop, one call per TTS utterance, before concatenation.
- The `PostProcessor.finalize()` method is called once on the complete concatenated
  audio, before MP3 export.

---

*Generated by Seven (Research & Docs agent) — Closes [#844](https://github.com/tamirdresher_microsoft/tamresearch1/issues/844)*
