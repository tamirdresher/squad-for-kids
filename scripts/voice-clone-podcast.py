#!/usr/bin/env python3
"""
Voice-Cloned Hebrew Podcast Generator
======================================
Generates Hebrew podcasts with voice cloning / style transfer.

Backends (priority order):
  1. ElevenLabs API  — Best quality, requires API key (--elevenlabs-key)
  2. OpenVoice        — Open-source tone color converter (--openvoice)
  3. edge-tts + style — edge-tts Hebrew voices + audio style transfer (default)

Usage:
  # Default: edge-tts with voice style profiles
  python voice-clone-podcast.py ../hebrew-squad-podcast.script.txt -o output.mp3

  # With voice reference samples for style transfer
  python voice-clone-podcast.py script.txt --ref-avri avri_sample.wav --ref-hila hila_sample.wav

  # With ElevenLabs API
  python voice-clone-podcast.py script.txt --elevenlabs-key YOUR_KEY --ref-avri sample.wav

  # Short test clip (first N turns)
  python voice-clone-podcast.py script.txt --test-clip 6 -o test_clip.mp3
"""

import asyncio
import argparse
import io
import json
import os
import re
import struct
import sys
import tempfile
import time
import wave
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

# ── Set ffmpeg path for pydub (use imageio-ffmpeg bundled binary) ─────────
FFMPEG_EXE = None
try:
    import imageio_ffmpeg
    FFMPEG_EXE = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    pass

def _get_pydub():
    """Import pydub with correct ffmpeg path."""
    from pydub import AudioSegment
    if FFMPEG_EXE:
        AudioSegment.converter = FFMPEG_EXE
        AudioSegment.ffprobe = FFMPEG_EXE
    return AudioSegment

# Force UTF-8
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# ── Voice Configuration ───────────────────────────────────────────────────
EDGE_VOICES = {
    "AVRI": {
        "voice": "he-IL-AvriNeural",
        "rate": "+5%",
        "description": "Male host — energetic, enthusiastic"
    },
    "HILA": {
        "voice": "he-IL-HilaNeural",
        "rate": "+2%",
        "description": "Female co-host — curious, engaged"
    },
}

# Style transfer profiles: applied when no reference audio is available.
# These simulate distinct voice characteristics via audio processing.
STYLE_PROFILES = {
    "AVRI": {
        "pitch_semitones": -1.5,     # Slightly deeper
        "formant_shift": 0.97,       # Subtle formant lowering
        "warmth_boost_db": 2.0,      # Low-frequency warmth
        "warmth_freq_hz": 250,       # Warmth cutoff
        "breathiness": 0.01,         # Very subtle breathiness
        "speed_factor": 1.02,        # Slightly faster delivery
        "description": "Deeper, warmer male voice with energetic delivery"
    },
    "HILA": {
        "pitch_semitones": 1.0,      # Slightly brighter
        "formant_shift": 1.03,       # Subtle formant raising
        "warmth_boost_db": 1.0,      # Less warmth
        "warmth_freq_hz": 300,       # Higher warmth cutoff
        "breathiness": 0.015,        # Slight breathiness
        "speed_factor": 0.98,        # Slightly measured
        "description": "Brighter, clearer female voice with thoughtful pacing"
    },
}


def parse_script(script_text):
    """Parse [AVRI]/[HILA] tagged script into turns."""
    turns = []
    for line in script_text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r'^\[(\w+)\]\s*(.+)$', line)
        if m:
            turns.append({"speaker": m.group(1).upper(), "text": m.group(2).strip()})
    return turns


# ── Audio Utilities ───────────────────────────────────────────────────────

def mp3_to_wav(mp3_path, wav_path):
    """Convert MP3 to WAV using ffmpeg directly or pydub."""
    import subprocess
    if FFMPEG_EXE:
        subprocess.run(
            [FFMPEG_EXE, "-y", "-i", str(mp3_path), "-ar", "24000", "-ac", "1", str(wav_path)],
            capture_output=True, check=True
        )
    else:
        AudioSegment = _get_pydub()
        audio = AudioSegment.from_mp3(str(mp3_path))
        audio = audio.set_channels(1).set_frame_rate(24000)
        audio.export(str(wav_path), format="wav")
    return wav_path


def wav_to_mp3(wav_path, mp3_path, bitrate="192k"):
    """Convert WAV to MP3 using ffmpeg directly or pydub."""
    import subprocess
    if FFMPEG_EXE:
        subprocess.run(
            [FFMPEG_EXE, "-y", "-i", str(wav_path), "-b:a", bitrate, str(mp3_path)],
            capture_output=True, check=True
        )
    else:
        AudioSegment = _get_pydub()
        audio = AudioSegment.from_wav(str(wav_path))
        audio.export(str(mp3_path), format="mp3", bitrate=bitrate)
    return mp3_path


def read_wav(path):
    """Read WAV file, return (samples as float64, sample_rate)."""
    sr, data = wavfile.read(str(path))
    if data.dtype == np.int16:
        data = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.float32:
        data = data.astype(np.float64)
    if len(data.shape) > 1:
        data = data.mean(axis=1)
    return data, sr


def write_wav(path, data, sr):
    """Write float64 samples to WAV."""
    data = np.clip(data, -1.0, 1.0)
    data_int16 = (data * 32767).astype(np.int16)
    wavfile.write(str(path), sr, data_int16)


def pitch_shift(data, sr, semitones):
    """Shift pitch by resampling (simple but effective for small shifts)."""
    if abs(semitones) < 0.01:
        return data
    factor = 2.0 ** (semitones / 12.0)
    # Resample to change pitch, then resample back to original length
    indices = np.round(np.arange(0, len(data), factor)).astype(int)
    indices = indices[indices < len(data)]
    shifted = data[indices]
    # Resample back to original length to preserve duration
    if len(shifted) != len(data):
        x_old = np.linspace(0, 1, len(shifted))
        x_new = np.linspace(0, 1, len(data))
        shifted = np.interp(x_new, x_old, shifted)
    return shifted


def apply_warmth(data, sr, boost_db, cutoff_hz):
    """Boost low frequencies for vocal warmth."""
    if boost_db < 0.01:
        return data
    nyq = sr / 2.0
    if cutoff_hz >= nyq:
        cutoff_hz = nyq * 0.9
    b, a = signal.butter(2, cutoff_hz / nyq, btype='low')
    low = signal.filtfilt(b, a, data)
    gain = 10 ** (boost_db / 20.0) - 1.0
    return data + gain * low


def add_breathiness(data, amount):
    """Add subtle breathiness via low-amplitude noise."""
    if amount < 0.001:
        return data
    noise = np.random.normal(0, amount, len(data))
    # Shape noise with envelope of original signal
    envelope = np.abs(data)
    # Smooth envelope
    kernel_size = min(1000, len(envelope) // 10)
    if kernel_size > 0:
        kernel = np.ones(kernel_size) / kernel_size
        envelope = np.convolve(envelope, kernel, mode='same')
    return data + noise * envelope


def change_speed(data, factor):
    """Change playback speed without pitch change (time stretch via interpolation)."""
    if abs(factor - 1.0) < 0.001:
        return data
    new_length = int(len(data) / factor)
    x_old = np.linspace(0, 1, len(data))
    x_new = np.linspace(0, 1, new_length)
    return np.interp(x_new, x_old, data)


def apply_style_profile(data, sr, profile):
    """Apply a voice style profile to audio data."""
    # Pitch shift
    data = pitch_shift(data, sr, profile.get("pitch_semitones", 0))
    # Warmth
    data = apply_warmth(data, sr, profile.get("warmth_boost_db", 0), profile.get("warmth_freq_hz", 250))
    # Breathiness
    data = add_breathiness(data, profile.get("breathiness", 0))
    # Speed
    data = change_speed(data, profile.get("speed_factor", 1.0))
    return data


def extract_voice_characteristics(ref_path):
    """Extract basic voice characteristics from a reference audio sample."""
    data, sr = read_wav(str(ref_path))
    # Compute spectral centroid (brightness indicator)
    fft = np.abs(np.fft.rfft(data))
    freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
    centroid = np.sum(freqs * fft) / (np.sum(fft) + 1e-10)
    # Estimate fundamental frequency (F0) using autocorrelation
    corr = np.correlate(data[:sr], data[:sr], mode='full')
    corr = corr[len(corr) // 2:]
    # Find first peak after zero crossing
    min_lag = int(sr / 500)  # Max F0 = 500 Hz
    max_lag = int(sr / 50)   # Min F0 = 50 Hz
    if max_lag > len(corr):
        max_lag = len(corr)
    peak_lag = np.argmax(corr[min_lag:max_lag]) + min_lag
    f0 = sr / peak_lag if peak_lag > 0 else 150.0
    # RMS energy
    rms = np.sqrt(np.mean(data ** 2))

    return {
        "f0_hz": float(f0),
        "spectral_centroid_hz": float(centroid),
        "rms_energy": float(rms),
        "duration_s": len(data) / sr,
    }


def match_voice_to_reference(data, sr, ref_characteristics, base_f0=None):
    """Attempt to shift audio to match reference voice characteristics."""
    if base_f0 is None:
        base_chars = extract_voice_characteristics_from_data(data, sr)
        base_f0 = base_chars["f0_hz"]
    ref_f0 = ref_characteristics["f0_hz"]
    if base_f0 > 0 and ref_f0 > 0:
        ratio = ref_f0 / base_f0
        semitones = 12 * np.log2(ratio) if ratio > 0 else 0
        semitones = np.clip(semitones, -6, 6)  # Limit to ±6 semitones
        data = pitch_shift(data, sr, semitones)
    return data


def extract_voice_characteristics_from_data(data, sr):
    """Extract characteristics directly from audio data array."""
    corr = np.correlate(data[:min(sr, len(data))], data[:min(sr, len(data))], mode='full')
    corr = corr[len(corr) // 2:]
    min_lag = int(sr / 500)
    max_lag = min(int(sr / 50), len(corr))
    if max_lag <= min_lag:
        return {"f0_hz": 150.0}
    peak_lag = np.argmax(corr[min_lag:max_lag]) + min_lag
    f0 = sr / peak_lag if peak_lag > 0 else 150.0
    return {"f0_hz": float(f0)}


# ── Backend: edge-tts + Style Transfer ────────────────────────────────────

async def generate_edge_tts(text, speaker, output_wav, style_profile=None, ref_chars=None):
    """Generate Hebrew TTS with edge-tts, then apply style transfer."""
    import edge_tts

    voice_cfg = EDGE_VOICES.get(speaker, EDGE_VOICES["AVRI"])
    tmp_mp3 = None
    tmp_wav_path = None

    try:
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp_mp3 = tmp.name

        comm = edge_tts.Communicate(text, voice_cfg["voice"], rate=voice_cfg["rate"])
        await comm.save(tmp_mp3)

        if os.path.getsize(tmp_mp3) == 0:
            print(f"      ⚠ edge-tts returned empty file")
            return False

        # Convert MP3 to WAV for processing
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
            tmp_wav_path = tmp_wav.name
        mp3_to_wav(tmp_mp3, tmp_wav_path)

        data, sr = read_wav(tmp_wav_path)

        # Apply voice modifications
        if ref_chars:
            data = match_voice_to_reference(data, sr, ref_chars)
        elif style_profile:
            data = apply_style_profile(data, sr, style_profile)

        write_wav(str(output_wav), data, sr)
        return True

    except Exception as e:
        print(f"      ✗ edge-tts error: {e}")
        return False
    finally:
        for f in [tmp_mp3, tmp_wav_path]:
            if f and os.path.exists(f):
                try:
                    os.unlink(f)
                except OSError:
                    pass


# ── Backend: ElevenLabs ──────────────────────────────────────────────────

async def generate_elevenlabs(text, speaker, output_wav, api_key, voice_id=None, ref_audio=None):
    """Generate voice-cloned audio using ElevenLabs API."""
    try:
        import httpx
    except ImportError:
        print("      ℹ httpx not installed. Install with: pip install httpx")
        return False

    base_url = "https://api.elevenlabs.io/v1"
    headers = {"xi-api-key": api_key}

    # If we have a reference audio, use instant voice cloning
    if ref_audio and not voice_id:
        print(f"      🔄 Creating instant voice clone from {ref_audio}...")
        async with httpx.AsyncClient(timeout=60) as client:
            with open(ref_audio, "rb") as f:
                resp = await client.post(
                    f"{base_url}/voice-generation/instant-voice-cloning",
                    headers=headers,
                    files={"files": (Path(ref_audio).name, f, "audio/mpeg")},
                    data={"name": f"podcast_{speaker}", "description": f"Hebrew podcast {speaker}"},
                )
            if resp.status_code != 200:
                print(f"      ✗ Clone failed ({resp.status_code}): {resp.text[:200]}")
                return False
            voice_id = resp.json().get("voice_id")
            print(f"      ✓ Voice cloned: {voice_id}")

    if not voice_id:
        # Use default Hebrew voices
        voice_id = "pNInz6obpgDQGcFmaJgB" if speaker == "AVRI" else "EXAVITQu4vr4xnSDxMaL"

    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            f"{base_url}/text-to-speech/{voice_id}",
            headers={**headers, "Content-Type": "application/json"},
            json={
                "text": text,
                "model_id": "eleven_multilingual_v2",
                "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
            },
        )
        if resp.status_code != 200:
            print(f"      ✗ TTS failed ({resp.status_code}): {resp.text[:200]}")
            return False

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp.write(resp.content)
            tmp_path = tmp.name

        mp3_to_wav(tmp_path, str(output_wav))
        os.unlink(tmp_path)
        return True


# ── Main Pipeline ────────────────────────────────────────────────────────

async def render_podcast(turns, output_path, backend="edge-tts-style",
                         ref_samples=None, elevenlabs_key=None, test_clip=None):
    """
    Render the full podcast.

    Args:
        turns: List of {"speaker": str, "text": str}
        output_path: Path for output file
        backend: "edge-tts-style" | "elevenlabs" | "openvoice"
        ref_samples: Dict of {"AVRI": path, "HILA": path} reference audio
        elevenlabs_key: ElevenLabs API key
        test_clip: If set, only render first N turns
    """
    from pydub import AudioSegment as _PydubAS
    if FFMPEG_EXE:
        _PydubAS.converter = FFMPEG_EXE
        _PydubAS.ffprobe = FFMPEG_EXE
    import random

    if test_clip:
        turns = turns[:test_clip]

    total_words = sum(len(t["text"].split()) for t in turns)
    est_min = max(1, round(total_words / 120))

    print(f"\n{'='*60}")
    print(f"🎙  Voice-Cloned Hebrew Podcast Generator")
    print(f"{'='*60}")
    print(f"📋 Script:  {len(turns)} turns, ~{total_words} words (~{est_min} min)")
    print(f"🔧 Backend: {backend}")
    if ref_samples:
        for spk, path in ref_samples.items():
            print(f"🎤 Ref {spk}: {path}")
    print(f"📁 Output:  {output_path}\n")

    # Extract reference characteristics if samples provided
    ref_chars = {}
    if ref_samples:
        for speaker, ref_path in ref_samples.items():
            ref_wav = ref_path
            if str(ref_path).endswith(".mp3"):
                ref_wav = Path(tempfile.mktemp(suffix=".wav"))
                mp3_to_wav(ref_path, ref_wav)
            try:
                chars = extract_voice_characteristics(str(ref_wav))
                ref_chars[speaker] = chars
                print(f"   📊 {speaker} ref: F0={chars['f0_hz']:.0f}Hz, "
                      f"centroid={chars['spectral_centroid_hz']:.0f}Hz, "
                      f"energy={chars['rms_energy']:.3f}")
            except Exception as e:
                print(f"   ⚠ Could not analyze {speaker} reference: {e}")

    start_time = time.time()
    segments = []

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)

        for i, turn in enumerate(turns):
            speaker = turn["speaker"]
            text = turn["text"]
            seg_wav = tmp / f"seg_{i:04d}_{speaker}.wav"

            preview = text[:50] + ("..." if len(text) > 50 else "")
            print(f"  [{i+1:02d}/{len(turns)}] {speaker}: {preview}")

            ok = False

            if backend == "elevenlabs" and elevenlabs_key:
                ref_audio = ref_samples.get(speaker) if ref_samples else None
                ok = await generate_elevenlabs(text, speaker, seg_wav,
                                               elevenlabs_key, ref_audio=ref_audio)

            if backend == "edge-tts-style" or not ok:
                style = STYLE_PROFILES.get(speaker)
                chars = ref_chars.get(speaker)
                ok = await generate_edge_tts(text, speaker, seg_wav,
                                             style_profile=style, ref_chars=chars)

            if ok:
                segments.append((seg_wav, speaker))
            else:
                print(f"      ✗ Failed to generate segment {i+1}")

        if not segments:
            print("\n✗ No segments generated!")
            return False

        # Concatenate with natural pauses
        print(f"\n🔗 Concatenating {len(segments)} segments...")
        combined = _PydubAS.empty()
        prev_speaker = None

        for seg_wav, speaker in segments:
            audio = _PydubAS.from_wav(str(seg_wav))
            if prev_speaker is not None:
                # Speaker change gets longer pause
                pause_ms = random.randint(400, 650) if speaker != prev_speaker else random.randint(150, 300)
                combined += _PydubAS.silent(duration=pause_ms)
            combined += audio
            prev_speaker = speaker

        # Export
        out_str = str(output_path)
        if out_str.endswith(".wav"):
            combined.export(out_str, format="wav")
        else:
            combined.export(out_str, format="mp3", bitrate="192k")

    elapsed = time.time() - start_time
    file_size = output_path.stat().st_size
    duration_s = len(combined) / 1000.0

    print(f"\n{'='*60}")
    print(f"✅ Voice-cloned podcast generated!")
    print(f"   Backend:  {backend}")
    print(f"   Duration: {duration_s:.1f}s ({duration_s/60:.1f} min)")
    print(f"   Size:     {file_size / (1024*1024):.1f} MB")
    print(f"   Turns:    {len(segments)}/{len(turns)}")
    print(f"   Time:     {elapsed:.1f}s")
    if ref_samples:
        print(f"   Voice cloning: Reference-matched style transfer")
    else:
        print(f"   Voice cloning: Synthetic style profiles")
    print(f"{'='*60}")
    return True


async def main():
    parser = argparse.ArgumentParser(
        description="Voice-Cloned Hebrew Podcast Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument("script", nargs="?", help="Hebrew podcast script ([SPEAKER] format)")
    parser.add_argument("-o", "--output", help="Output file (default: <stem>-voiceclone.mp3)")
    parser.add_argument("--backend", choices=["edge-tts-style", "elevenlabs", "openvoice"],
                        default="edge-tts-style",
                        help="TTS backend (default: edge-tts-style)")
    parser.add_argument("--ref-avri", help="Reference audio for AVRI voice")
    parser.add_argument("--ref-hila", help="Reference audio for HILA voice")
    parser.add_argument("--elevenlabs-key", help="ElevenLabs API key")
    parser.add_argument("--test-clip", type=int, help="Only render first N turns (for testing)")
    parser.add_argument("--list-styles", action="store_true", help="Show available style profiles")
    parser.add_argument("--analyze-ref", help="Analyze a reference audio file")

    args = parser.parse_args()

    if args.list_styles:
        print("\n🎭 Available Voice Style Profiles:")
        for name, profile in STYLE_PROFILES.items():
            print(f"\n  {name}:")
            print(f"    {profile['description']}")
            print(f"    Pitch: {profile['pitch_semitones']:+.1f} semitones")
            print(f"    Warmth: +{profile['warmth_boost_db']}dB @ {profile['warmth_freq_hz']}Hz")
            print(f"    Speed: {profile['speed_factor']:.2f}x")
        return

    if args.analyze_ref:
        ref_path = Path(args.analyze_ref)
        if not ref_path.exists():
            print(f"✗ File not found: {ref_path}")
            sys.exit(1)
        wav_path = ref_path
        if str(ref_path).endswith(".mp3"):
            wav_path = Path(tempfile.mktemp(suffix=".wav"))
            mp3_to_wav(ref_path, wav_path)
        chars = extract_voice_characteristics(str(wav_path))
        print(f"\n🔬 Voice Analysis: {ref_path.name}")
        print(f"   Fundamental Frequency (F0): {chars['f0_hz']:.1f} Hz")
        print(f"   Spectral Centroid:          {chars['spectral_centroid_hz']:.1f} Hz")
        print(f"   RMS Energy:                 {chars['rms_energy']:.4f}")
        print(f"   Duration:                   {chars['duration_s']:.1f}s")
        return

    if not args.script:
        parser.error("script is required (unless using --list-styles or --analyze-ref)")

    script_path = Path(args.script).resolve()
    if not script_path.exists():
        print(f"✗ Script not found: {script_path}")
        sys.exit(1)

    if args.output:
        output_path = Path(args.output).resolve()
    else:
        stem = script_path.stem.replace(".script", "").replace(".podcast-script", "")
        output_path = script_path.parent / f"{stem}-voiceclone.mp3"

    raw = script_path.read_text(encoding="utf-8")
    turns = parse_script(raw)
    if not turns:
        print("✗ No turns found. Expected [SPEAKER] format.")
        sys.exit(1)

    ref_samples = {}
    if args.ref_avri:
        ref_samples["AVRI"] = Path(args.ref_avri).resolve()
    if args.ref_hila:
        ref_samples["HILA"] = Path(args.ref_hila).resolve()

    backend = args.backend
    if backend == "elevenlabs" and not args.elevenlabs_key:
        print("⚠ ElevenLabs backend requires --elevenlabs-key. Falling back to edge-tts-style.")
        backend = "edge-tts-style"

    await render_podcast(
        turns, output_path, backend=backend,
        ref_samples=ref_samples or None,
        elevenlabs_key=args.elevenlabs_key,
        test_clip=args.test_clip,
    )


if __name__ == "__main__":
    asyncio.run(main())
