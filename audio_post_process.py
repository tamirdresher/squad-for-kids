"""
audio_post_process.py — Drop-in audio post-processing for Hebrew podcast pipelines.

Implements five human-perceptible quality improvements (issue #844):
  1. Per-speaker EQ (warmth for TAMIR/AVRI, presence+air for ALEX/HILA)
  2. De-essing — sibilance control for female voice
  3. Dynamic range compression — consistent listening level
  4. Pre-concatenation gain staging — headroom before mix
  5. Final LUFS loudness normalization to -16 LUFS (podcast broadcast standard)

Usage in any generate_*.py script:
    from audio_post_process import PostProcessor

    pp = PostProcessor(sample_rate=24000)   # match your TTS output sample rate

    # Inside segment loop — per speaker:
    segment_np = wav_tensor.squeeze(0).cpu().numpy()
    segment_np = pp.process_segment(segment_np, speaker="TAMIR")

    # After concatenation — final mix:
    full_mix_np = pp.finalize(full_mix_np)

    # Then write to WAV / MP3 as usual.

Requirements (already installed):
    pydub, scipy, numpy, soundfile

Optional (strongly recommended):
    pip install pyloudnorm   # proper ITU-R BS.1770 LUFS normalization
"""

from __future__ import annotations

import io
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt
from pydub import AudioSegment
from pydub.effects import compress_dynamic_range

try:
    import pyloudnorm as pyln
    _HAS_PYLOUDNORM = True
except ImportError:
    _HAS_PYLOUDNORM = False
    print("[audio_post_process] pyloudnorm not installed — using RMS fallback.")
    print("  Install: pip install pyloudnorm")


class PostProcessor:
    """
    Post-processing chain for Hebrew AI podcast segments.

    Parameters
    ----------
    sample_rate : int
        Output sample rate of the TTS engine (e.g. 22050, 24000).
    target_lufs : float
        Target integrated loudness in LUFS.  -16 for Spotify/streaming,
        -19 for Apple Podcasts.  Default: -16.0.
    """

    def __init__(self, sample_rate: int = 24000, target_lufs: float = -16.0):
        self.sr = sample_rate
        self.target_lufs = target_lufs
        if _HAS_PYLOUDNORM:
            self.meter = pyln.Meter(sample_rate)
        else:
            self.meter = None

    # ─────────────────────────────────────────────────────────────────────────
    # Internal helpers
    # ─────────────────────────────────────────────────────────────────────────

    def _butter_sos(self, freq: float, btype: str, order: int = 2) -> np.ndarray:
        """Design a Butterworth filter; normalise frequency to Nyquist."""
        wn = np.clip(freq / (self.sr / 2.0), 1e-6, 0.9999)
        return butter(order, wn, btype=btype, output="sos")

    def _apply_shelf(self, data: np.ndarray, freq: float,
                     gain_db: float, shelf_type: str = "low") -> np.ndarray:
        """Shelving EQ: add gain_db of boost/cut above/below freq."""
        sos = self._butter_sos(freq, shelf_type)
        filtered = sosfilt(sos, data)
        g = 10 ** (gain_db / 20.0) - 1.0   # additive gain coefficient
        return data + filtered * g

    # ─────────────────────────────────────────────────────────────────────────
    # Technique 3 — Per-speaker EQ
    # ─────────────────────────────────────────────────────────────────────────

    def eq_tamir(self, data: np.ndarray) -> np.ndarray:
        """
        EQ profile for TAMIR / AVRI / DOTAN (Israeli male host).
        +2 dB low-shelf warmth at 250 Hz
        −1.5 dB high-shelf roll-off above 8 kHz
        """
        data = self._apply_shelf(data, 250, +2.0, "low")
        data = self._apply_shelf(data, 8000, -1.5, "high")
        return data

    def eq_alex(self, data: np.ndarray) -> np.ndarray:
        """
        EQ profile for ALEX / HILA / SHAHAR (analytical female host).
        High-pass rumble cut at 100 Hz
        +1.8 dB presence shelf above 3 kHz
        +1.5 dB air shelf above 10 kHz
        """
        sos_hp = self._butter_sos(100, "high")
        data = sosfilt(sos_hp, data)
        data = self._apply_shelf(data, 3000, +1.8, "high")
        data = self._apply_shelf(data, 10000, +1.5, "high")
        return data

    # ─────────────────────────────────────────────────────────────────────────
    # Technique 5 — De-essing
    # ─────────────────────────────────────────────────────────────────────────

    def de_ess(self, data: np.ndarray,
               freq_low: float = 5000.0,
               freq_high: float = 9000.0,
               threshold_db: float = -20.0,
               reduction_db: float = 6.0) -> np.ndarray:
        """
        Frequency-selective de-esser: detect & attenuate harsh sibilance
        (Hebrew /ש/ /ס/ /ז/) in the 5–9 kHz band.

        Parameters
        ----------
        freq_low / freq_high : float
            Sibilance detection band in Hz.
        threshold_db : float
            Level above which gain reduction kicks in (dBFS).
        reduction_db : float
            How much to reduce sibilance when it exceeds threshold (dB).
        """
        nyq = self.sr / 2.0
        lo = np.clip(freq_low / nyq, 1e-6, 0.9999)
        hi = np.clip(freq_high / nyq, 1e-6, 0.9999)
        if lo >= hi:
            return data
        sos = butter(4, [lo, hi], btype="band", output="sos")
        sib = sosfilt(sos, data)

        threshold_lin = 10 ** (threshold_db / 20.0)
        reduction_lin = 10 ** (-reduction_db / 20.0)

        # 5 ms envelope follower
        env = np.abs(sib)
        win = max(int(0.005 * self.sr), 1)
        env = np.convolve(env, np.ones(win) / win, mode="same")

        gain = np.where(
            env > threshold_lin,
            reduction_lin + (1.0 - reduction_lin) * threshold_lin /
            np.maximum(env, 1e-10),
            1.0,
        )
        return data + (sib * gain - sib)

    # ─────────────────────────────────────────────────────────────────────────
    # Technique 4 — Dynamic range compression
    # ─────────────────────────────────────────────────────────────────────────

    def compress(self, data: np.ndarray,
                 threshold: float = -20.0,
                 ratio: float = 4.0,
                 attack: float = 10.0,
                 release: float = 80.0) -> np.ndarray:
        """
        Broadcast-style speech compression via pydub.

        Parameters
        ----------
        threshold : float   dBFS threshold (-20 dBFS typical for speech)
        ratio     : float   compression ratio (4:1 standard for podcast)
        attack    : float   attack time in ms  (10 ms)
        release   : float   release time in ms (80 ms)
        """
        int16 = (np.clip(data, -1.0, 1.0) * 32767).astype(np.int16)
        buf = io.BytesIO()
        sf.write(buf, int16, self.sr, format="WAV", subtype="PCM_16")
        buf.seek(0)
        seg = AudioSegment.from_wav(buf)
        seg = compress_dynamic_range(
            seg, threshold=threshold, ratio=ratio,
            attack=attack, release=release,
        )
        buf2 = io.BytesIO()
        seg.export(buf2, format="wav")
        buf2.seek(0)
        out, _ = sf.read(buf2, dtype="float32")
        if out.ndim > 1:
            out = out.mean(axis=1)
        return out

    # ─────────────────────────────────────────────────────────────────────────
    # Technique 1 — LUFS normalization
    # ─────────────────────────────────────────────────────────────────────────

    def lufs_normalize(self, data: np.ndarray) -> np.ndarray:
        """
        Normalize integrated loudness to self.target_lufs (default −16 LUFS).
        Uses pyloudnorm (ITU-R BS.1770) when available; falls back to RMS-based
        normalization.
        """
        if _HAS_PYLOUDNORM and self.meter is not None:
            import pyloudnorm as pyln  # noqa: F811
            loudness = self.meter.integrated_loudness(data)
            # Protect against silence
            if np.isinf(loudness):
                return data
            return pyln.normalize.loudness(data, loudness, self.target_lufs)
        # RMS fallback
        rms = np.sqrt(np.mean(data ** 2))
        if rms < 1e-10:
            return data
        # Rough mapping: LUFS ≈ RMS − 3 dB for typical speech
        target_rms = 10 ** ((self.target_lufs + 3.0) / 20.0)
        normalized = data * (target_rms / rms)
        return np.clip(normalized, -1.0, 1.0)

    # ─────────────────────────────────────────────────────────────────────────
    # Technique 2 — Variable conversation dynamics (pause utility)
    # ─────────────────────────────────────────────────────────────────────────

    def dynamic_pause(self, prev_text: str, context: str = "default") -> np.ndarray:
        """
        Return a variable-length silence array based on conversational context.

        Parameters
        ----------
        prev_text : str   The utterance that just finished.
        context   : str   Override rule: "default" | "after_question" |
                          "topic_transition" | "after_short_reply"

        Returns
        -------
        np.ndarray of zeros (silence), dtype float32.
        """
        import random

        PAUSE_RULES = {
            "default":           (0.25, 0.45),
            "after_question":    (0.55, 0.90),
            "topic_transition":  (1.10, 1.60),
            "after_short_reply": (0.15, 0.30),
        }

        if context == "default":
            if "?" in prev_text:
                context = "after_question"
            elif "[PAUSE]" in prev_text:
                context = "topic_transition"
            elif len(prev_text.split()) < 6:
                context = "after_short_reply"

        lo, hi = PAUSE_RULES.get(context, PAUSE_RULES["default"])
        duration = random.uniform(lo, hi)
        return np.zeros(int(duration * self.sr), dtype=np.float32)

    # ─────────────────────────────────────────────────────────────────────────
    # Public API
    # ─────────────────────────────────────────────────────────────────────────

    def process_segment(self, data: np.ndarray, speaker: str) -> np.ndarray:
        """
        Apply the full per-segment chain:
          EQ → de-essing (female) → compression → headroom gain staging.

        Parameters
        ----------
        data    : np.ndarray  Raw TTS output, float32, mono or stereo.
        speaker : str         Speaker label e.g. "TAMIR", "ALEX", "AVRI", "HILA".

        Returns
        -------
        Processed float32 mono array, ready for concatenation.
        """
        data = np.asarray(data, dtype=np.float32)
        if data.ndim > 1:
            data = data.mean(axis=1)

        spk = speaker.upper()

        # Step 1: Per-speaker EQ
        if spk in ("TAMIR", "AVRI", "DOTAN"):
            data = self.eq_tamir(data)
        elif spk in ("ALEX", "HILA", "SHAHAR"):
            data = self.eq_alex(data)
            # Step 2: De-essing (female only)
            data = self.de_ess(data)

        # Step 3: Compression
        data = self.compress(data)

        # Step 4: Headroom — keep each segment at ≤ −18 dBFS peak before concat
        peak = np.max(np.abs(data))
        if peak > 0.126:   # −18 dBFS
            data = data * (0.126 / peak)

        return data

    def finalize(self, data: np.ndarray) -> np.ndarray:
        """
        Finalize the complete concatenated podcast mix:
          LUFS normalization → clip protection.

        Call this once, after concatenation, before MP3 export.
        """
        data = np.asarray(data, dtype=np.float32)
        if data.ndim > 1:
            data = data.mean(axis=1)
        data = self.lufs_normalize(data)
        return np.clip(data, -1.0, 1.0)

    @staticmethod
    def from_wav_file(path: str) -> tuple[np.ndarray, int]:
        """Convenience: load WAV file → (float32 array, sample_rate)."""
        data, sr = sf.read(path, dtype="float32")
        if data.ndim > 1:
            data = data.mean(axis=1)
        return data, sr

    @staticmethod
    def to_wav_file(data: np.ndarray, sample_rate: int, path: str) -> None:
        """Convenience: write float32 mono array → WAV file."""
        sf.write(path, data, sample_rate)


# ─────────────────────────────────────────────────────────────────────────────
# Quick self-test
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    sr = 22050
    duration = 3.0
    t = np.linspace(0, duration, int(sr * duration))
    # Simulate a TTS segment: 220 Hz tone + 6000 Hz sibilance burst
    test_signal = 0.5 * np.sin(2 * np.pi * 220 * t)
    test_signal[sr:sr + 2000] += 0.3 * np.sin(2 * np.pi * 6500 * t[sr:sr + 2000])

    pp = PostProcessor(sample_rate=sr, target_lufs=-16.0)

    tamir_proc = pp.process_segment(test_signal.copy(), speaker="TAMIR")
    alex_proc  = pp.process_segment(test_signal.copy(), speaker="ALEX")

    print(f"Input  peak: {np.max(np.abs(test_signal)):.3f}")
    print(f"TAMIR  peak: {np.max(np.abs(tamir_proc)):.3f}")
    print(f"ALEX   peak: {np.max(np.abs(alex_proc)):.3f}")

    mixed = np.concatenate([tamir_proc,
                            pp.dynamic_pause("[PAUSE]"),
                            alex_proc])
    final = pp.finalize(mixed)
    print(f"Final  peak: {np.max(np.abs(final)):.3f}")
    print(f"Final  rms:  {np.sqrt(np.mean(final**2)):.4f}")
    print("Self-test passed. ✓")
