#!/usr/bin/env python3
"""
.NET Rocks Voice Cloning Pipeline
==================================
Renders a .NET Rocks podcast demo with:
  1. Azure TTS baseline (English neural voices with SSML styling)
  2. Seed-VC voice conversion (zero-shot, if reference audio available)
  3. PyWorld formant correction
  4. Studio post-processing (EQ, compression, reverb, LUFS normalization)

Outputs:
  - dotnet-rocks-demo-azure-baseline.mp3
  - dotnet-rocks-demo-seedvc.mp3
  - dotnet-rocks-demo-formant.mp3
  - dotnet-rocks-demo-final.mp3
"""
import os, sys, time, random, shutil, math, struct
import numpy as np

sys.stdout.reconfigure(encoding='utf-8')
WORKDIR = r'C:\Users\tamirdresher\tamresearch1'
os.chdir(WORKDIR)

PYTHON = sys.executable
PYTHON_SEEDVC = r'seed-vc-env\Scripts\python.exe'
TEMP_DIR = os.path.join(WORKDIR, 'dotnet_rocks_temp')
SAMPLE_RATE = 24000
SR_OUTPUT = 44100

# Azure config
AZURE_KEY_FILE = os.path.expanduser('~/.squad/azure-speech-key-eastus')
AZURE_REGION = 'eastus'

# Voice mapping — English neural voices chosen for personality match
VOICE_MAP = {
    'Carl': 'en-US-DavisNeural',       # warm baritone, relaxed
    'Richard': 'en-US-JasonNeural',     # energetic mid-range
}

# Pitch targets (Hz) for formant correction
PITCH_TARGETS = {
    'Carl': 115.0,     # warm baritone ~100-130 Hz
    'Richard': 145.0,  # mid energetic ~130-160 Hz
}

# Formant targets for PyWorld correction
FORMANT_TARGETS = {
    'Carl':    {'F1': 650, 'F2': 1600, 'F3': 2700},  # warm baritone
    'Richard': {'F1': 580, 'F2': 1750, 'F3': 2800},  # mid energetic
}

# Reference audio for voice conversion (will be checked at runtime)
REF_MAP = {
    'Carl': os.path.join(WORKDIR, 'voice_samples', 'carl_franklin_ref.wav'),
    'Richard': os.path.join(WORKDIR, 'voice_samples', 'richard_campbell_ref.wav'),
}

# Demo script — .NET Rocks style conversation
SCRIPT = [
    ('Carl', "Welcome back to .NET Rocks! I'm Carl Franklin."),
    ('Richard', "And I'm Richard Campbell. Carl, we've got a great show today."),
    ('Carl', "We really do. We're going to talk about AI-assisted development and how it's changing the way we write code."),
    ('Richard', "You know, I've been playing with Copilot a lot lately, and it's just remarkable how much it understands about context."),
    ('Carl', "Right? It's not just autocomplete anymore. It actually understands your intent."),
    ('Richard', "But here's the thing — it doesn't replace thinking. You still need to know what good code looks like."),
    ('Carl', "Absolutely. And that's what makes it so interesting for experienced developers."),
    ('Richard', "Exactly. It amplifies your skills rather than replacing them."),
]

os.makedirs(TEMP_DIR, exist_ok=True)


# ═══════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════

def read_wav(path):
    """Read WAV file to float32 numpy array."""
    import soundfile as sf
    audio, sr = sf.read(path, dtype='float32')
    if audio.ndim > 1:
        audio = audio.mean(axis=1)
    return audio, sr


def write_wav(path, audio, sr):
    """Write numpy array to WAV."""
    import soundfile as sf
    audio = np.clip(audio, -1.0, 1.0)
    sf.write(path, audio, sr, subtype='PCM_16')


def add_sentence_breaks(text):
    """Insert SSML breaks between sentences for natural pacing."""
    import re
    parts = re.split(r'([.!?]+)\s+', text)
    result = []
    for i, part in enumerate(parts):
        result.append(part)
        if re.match(r'^[.!?]+$', part) and i < len(parts) - 1:
            result.append(' <break time="200ms"/> ')
    return ''.join(result)


# ═══════════════════════════════════════════════════════════════════════
# STEP 1: Azure TTS Baseline
# ═══════════════════════════════════════════════════════════════════════

def pick_style(speaker, text, turn_idx):
    """Vary SSML express-as style for natural .NET Rocks feel."""
    is_question = text.rstrip().endswith('?')
    is_exclaim = text.rstrip().endswith('!')
    has_dash = '—' in text or '--' in text

    if turn_idx <= 1:
        return 'chat', '1.8'           # warm opening
    if is_question:
        return random.choice(['friendly', 'empathetic']), '1.5'
    if is_exclaim:
        return 'cheerful', '1.8'
    if has_dash:
        return 'chat', '1.5'
    return 'chat', random.choice(['1.2', '1.5', '1.3'])


def render_azure_tts():
    """Render all turns with Azure TTS."""
    import azure.cognitiveservices.speech as speechsdk

    print("\n" + "=" * 70)
    print("  STEP 1: Azure TTS Baseline (English Neural Voices)")
    print("=" * 70)

    azure_key = open(AZURE_KEY_FILE).read().strip()
    config = speechsdk.SpeechConfig(subscription=azure_key, region=AZURE_REGION)
    config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
    )
    synth = speechsdk.SpeechSynthesizer(speech_config=config, audio_config=None)

    tts_paths = []
    for i, (speaker, text) in enumerate(SCRIPT):
        wav_path = os.path.join(TEMP_DIR, f'turn_{i:02d}_{speaker}_azure.wav')
        tts_paths.append(wav_path)

        if os.path.exists(wav_path) and os.path.getsize(wav_path) > 1000:
            audio, sr = read_wav(wav_path)
            dur = len(audio) / sr
            print(f"  Turn {i:02d} [{speaker:8s}] — cached ({dur:.1f}s)")
            continue

        voice = VOICE_MAP[speaker]
        style, degree = pick_style(speaker, text, i)
        text_breaks = add_sentence_breaks(text)

        # SSML with express-as for conversational style
        ssml = f"""<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis'
  xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='en-US'>
  <voice name='{voice}'>
    <mstts:express-as style='{style}' styledegree='{degree}'>
      <prosody rate='+3%' pitch='+1%'>
        {text_breaks}
      </prosody>
    </mstts:express-as>
  </voice>
</speak>"""

        print(f"  Turn {i:02d} [{speaker:8s}] voice={voice} style={style} deg={degree} ... ",
              end='', flush=True)

        result = synth.speak_ssml_async(ssml).get()
        if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
            with open(wav_path, 'wb') as f:
                f.write(result.audio_data)
            dur = len(result.audio_data) / (SAMPLE_RATE * 2)
            print(f"OK ({dur:.1f}s)")
        else:
            details = result.cancellation_details
            print(f"FAILED: {details.reason} - {details.error_details}")
        time.sleep(0.15)

    return tts_paths


# ═══════════════════════════════════════════════════════════════════════
# STEP 2: Seed-VC Voice Conversion
# ═══════════════════════════════════════════════════════════════════════

def check_reference_audio():
    """Check if we have reference audio for Carl and Richard."""
    available = {}
    for speaker, path in REF_MAP.items():
        if os.path.exists(path) and os.path.getsize(path) > 1000:
            audio, sr = read_wav(path)
            dur = len(audio) / sr
            available[speaker] = {'path': path, 'duration': dur, 'sr': sr}
            print(f"  ✓ {speaker}: {path} ({dur:.1f}s)")
        else:
            print(f"  ✗ {speaker}: reference audio not found at {path}")
    return available


def run_seedvc_conversion(tts_paths, ref_available, diffusion_steps=3, cfg_strength=0.5):
    """Convert Azure TTS output using Seed-VC zero-shot voice conversion."""
    print("\n" + "=" * 70)
    print("  STEP 2: Seed-VC Voice Conversion")
    print("=" * 70)

    refs = check_reference_audio()

    if not refs:
        print("\n  ⚠ No reference audio available for voice conversion.")
        print("  To enable: place carl_franklin_ref.wav and richard_campbell_ref.wav in voice_samples/")
        print("  Skipping Seed-VC — using Azure TTS as-is.")
        return tts_paths, False

    # Check which speakers have refs
    speakers_with_refs = set(refs.keys())
    all_speakers = set(s for s, _ in SCRIPT)
    missing = all_speakers - speakers_with_refs
    if missing:
        print(f"\n  ⚠ Missing reference audio for: {missing}")
        print(f"  Will only convert speakers with refs: {speakers_with_refs}")

    # Load Seed-VC
    print("\n  Loading Seed-VC model...")
    import torch
    from seed_vc.seed_vc_wrapper import SeedVCWrapper
    import soundfile as sf

    t0 = time.time()
    vc = SeedVCWrapper(device=torch.device('cpu'))
    print(f"  Model loaded in {time.time()-t0:.1f}s")

    # Prepare reference audio (trim to optimal length)
    ref_files = {}
    for speaker, info in refs.items():
        ref_secs = min(10, info['duration'])  # 10s optimal for CPU
        audio, sr = read_wav(info['path'])
        samples = int(ref_secs * sr)
        trimmed = audio[:samples]
        ref_path = os.path.join(TEMP_DIR, f'{speaker}_ref_{ref_secs:.0f}s.wav')
        write_wav(ref_path, trimmed, sr)
        ref_files[speaker] = ref_path
        print(f"  Prepared {speaker} ref: {ref_secs:.0f}s")

    # Convert each turn
    seedvc_paths = []
    total_t0 = time.time()
    converted = 0

    for i, (speaker, text) in enumerate(SCRIPT):
        out_path = os.path.join(TEMP_DIR, f'turn_{i:02d}_{speaker}_seedvc.wav')

        if os.path.exists(out_path) and os.path.getsize(out_path) > 500:
            audio, sr = read_wav(out_path)
            dur = len(audio) / sr
            seedvc_paths.append(out_path)
            converted += 1
            print(f"  Turn {i:02d} [{speaker:8s}] — cached ({dur:.1f}s)")
            continue

        if speaker not in ref_files:
            seedvc_paths.append(tts_paths[i])
            print(f"  Turn {i:02d} [{speaker:8s}] — no ref, using TTS")
            continue

        print(f"  Turn {i:02d} [{speaker:8s}] converting (steps={diffusion_steps})...",
              end='', flush=True)
        t0 = time.time()

        try:
            chunks = list(vc.convert_voice(
                source=tts_paths[i],
                target=ref_files[speaker],
                diffusion_steps=diffusion_steps,
                length_adjust=1.0,
                inference_cfg_rate=cfg_strength,
                f0_condition=False,
                auto_f0_adjust=True,
                pitch_shift=0,
                stream_output=True,
            ))

            if not chunks:
                raise ValueError("Empty output")

            last = chunks[-1]
            if isinstance(last, tuple) and isinstance(last[1], tuple):
                output_sr, audio_data = last[1]
            elif isinstance(last, tuple):
                audio_data = last[-1]
                output_sr = 22050
            else:
                audio_data = last
                output_sr = 22050

            if hasattr(audio_data, 'numpy'):
                audio_np = audio_data.cpu().numpy()
            else:
                audio_np = np.array(audio_data)
            if audio_np.ndim > 1:
                audio_np = audio_np.squeeze()

            elapsed = time.time() - t0
            if len(audio_np) > 100:
                sf.write(out_path, audio_np, output_sr)
                dur = len(audio_np) / output_sr
                seedvc_paths.append(out_path)
                converted += 1
                print(f" ✓ {dur:.1f}s ({elapsed:.0f}s)")
            else:
                print(f" ✗ too short ({elapsed:.0f}s)")
                seedvc_paths.append(tts_paths[i])

        except Exception as e:
            elapsed = time.time() - t0
            print(f" ✗ {e} ({elapsed:.0f}s)")
            seedvc_paths.append(tts_paths[i])

    total_elapsed = time.time() - total_t0
    print(f"\n  Total: {converted}/{len(SCRIPT)} converted in {total_elapsed/60:.1f} min")
    return seedvc_paths, converted > 0


# ═══════════════════════════════════════════════════════════════════════
# STEP 3: PyWorld Formant Correction
# ═══════════════════════════════════════════════════════════════════════

def correct_pitch_pyworld(audio, sr, target_f0, strength=0.5):
    """Correct pitch using PyWorld for better formant preservation."""
    import pyworld as pw

    # Ensure contiguous float64
    audio_f64 = np.ascontiguousarray(audio, dtype=np.float64)

    # Extract F0 and spectral envelope
    f0, t = pw.harvest(audio_f64, sr, f0_floor=60.0, f0_ceil=400.0)
    sp = pw.cheaptrick(audio_f64, f0, t, sr)
    ap = pw.d4c(audio_f64, f0, t, sr)

    # Calculate correction
    voiced = f0 > 0
    if not np.any(voiced):
        return audio

    median_f0 = np.median(f0[voiced])
    if median_f0 <= 0:
        return audio

    # Gentle pitch shift toward target
    ratio = target_f0 / median_f0
    correction_ratio = 1.0 + (ratio - 1.0) * strength

    f0_corrected = f0.copy()
    f0_corrected[voiced] *= correction_ratio

    # Resynthesize
    result = pw.synthesize(f0_corrected, sp, ap, sr)
    return result.astype(np.float32)


def correct_formants_pyworld(audio, sr, speaker, strength=0.3):
    """Shift formants toward target using spectral envelope manipulation."""
    import pyworld as pw

    targets = FORMANT_TARGETS[speaker]
    audio_f64 = np.ascontiguousarray(audio, dtype=np.float64)

    f0, t = pw.harvest(audio_f64, sr, f0_floor=60.0, f0_ceil=400.0)
    sp = pw.cheaptrick(audio_f64, f0, t, sr)
    ap = pw.d4c(audio_f64, f0, t, sr)

    # Spectral envelope warping for formant adjustment
    # Shift the spectral envelope to move formants toward targets
    freq_axis = np.arange(sp.shape[1]) * sr / (2 * sp.shape[1])

    # Simple spectral warping — compress/expand around formant regions
    # This is a gentle effect to nudge formants in the right direction
    target_f1 = targets['F1']
    warp_factor = 1.0 + (target_f1 / 700.0 - 1.0) * strength * 0.3  # subtle

    new_freq = freq_axis * warp_factor
    sp_warped = np.zeros_like(sp)
    for frame_i in range(sp.shape[0]):
        sp_warped[frame_i] = np.interp(freq_axis, new_freq, sp[frame_i])

    result = pw.synthesize(f0, sp_warped, ap, sr)
    return result.astype(np.float32)


def apply_formant_correction(audio_paths):
    """Apply PyWorld formant correction to all turns."""
    print("\n" + "=" * 70)
    print("  STEP 3: PyWorld Formant Correction")
    print("=" * 70)

    import librosa

    corrected_paths = []
    for i, (speaker, text) in enumerate(SCRIPT):
        src = audio_paths[i]
        dst = os.path.join(TEMP_DIR, f'turn_{i:02d}_{speaker}_formant.wav')
        corrected_paths.append(dst)

        if os.path.exists(dst) and os.path.getsize(dst) > 500:
            audio, sr = read_wav(dst)
            dur = len(audio) / sr
            print(f"  Turn {i:02d} [{speaker:8s}] — cached ({dur:.1f}s)")
            continue

        audio, sr = read_wav(src)

        # Resample to target if needed
        if sr != SAMPLE_RATE:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
            sr = SAMPLE_RATE

        # Pitch correction
        target_f0 = PITCH_TARGETS[speaker]
        audio = correct_pitch_pyworld(audio, sr, target_f0, strength=0.5)

        # Formant correction
        audio = correct_formants_pyworld(audio, sr, speaker, strength=0.3)

        dur = len(audio) / sr
        write_wav(dst, audio, sr)
        print(f"  Turn {i:02d} [{speaker:8s}] → {dur:.1f}s (target F0={target_f0}Hz)")

    return corrected_paths


# ═══════════════════════════════════════════════════════════════════════
# STEP 4: Post-Processing & Assembly
# ═══════════════════════════════════════════════════════════════════════

def apply_warmth_eq(audio, sr, boost_db=2.0, cutoff=300):
    """Low-shelf boost for warm broadcast feel."""
    from scipy.signal import butter, sosfilt
    sos = butter(2, cutoff, btype='low', fs=sr, output='sos')
    low = sosfilt(sos, audio)
    gain = 10 ** (boost_db / 20) - 1.0
    return audio + gain * low


def apply_presence_eq(audio, sr, boost_db=1.5, center=3000, bandwidth=1500):
    """Mid-range presence boost for clarity."""
    from scipy.signal import butter, sosfilt
    low = center - bandwidth / 2
    high = center + bandwidth / 2
    sos = butter(2, [low, high], btype='band', fs=sr, output='sos')
    mid = sosfilt(sos, audio)
    gain = 10 ** (boost_db / 20) - 1.0
    return audio + gain * mid


def soft_compress(audio, threshold_db=-20, ratio=3.0):
    """Broadcast-style soft-knee compressor."""
    threshold = 10 ** (threshold_db / 20)
    out = np.copy(audio)
    mask = np.abs(out) > threshold
    signs = np.sign(out[mask])
    above = np.abs(out[mask]) - threshold
    compressed = threshold + above / ratio
    out[mask] = signs * compressed
    return out


def add_room_reverb(audio, sr, delay_ms=50, wet=0.02):
    """Subtle studio room reverb."""
    delay_samples = int(sr * delay_ms / 1000)
    reverb = np.zeros(len(audio) + delay_samples)
    reverb[:len(audio)] += audio
    reverb[delay_samples:delay_samples + len(audio)] += audio * wet
    return reverb[:len(audio)]


def compute_lufs_approx(audio, sr):
    """Approximate integrated loudness."""
    rms = np.sqrt(np.mean(audio ** 2))
    if rms == 0:
        return -100
    return 20 * np.log10(rms) + 0.691


def normalize_lufs(audio, sr, target=-16):
    """Normalize to approximate LUFS target."""
    current = compute_lufs_approx(audio, sr)
    diff = target - current
    gain = 10 ** (diff / 20)
    return audio * min(gain, 10.0)  # cap to avoid explosion


def assemble_podcast(audio_paths, output_path, label=""):
    """Assemble turns into a finished podcast with realistic gaps."""
    print(f"\n  Assembling podcast{' (' + label + ')' if label else ''}...")

    import librosa

    segments = []
    for i, (speaker, text) in enumerate(SCRIPT):
        audio, sr = read_wav(audio_paths[i])
        if sr != SAMPLE_RATE:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
        segments.append(audio)

    sr = SAMPLE_RATE

    # Apply per-segment effects
    for i in range(len(segments)):
        seg = segments[i]
        seg = apply_warmth_eq(seg, sr, boost_db=2.0, cutoff=300)
        seg = apply_presence_eq(seg, sr, boost_db=1.5, center=3000)
        seg = soft_compress(seg, threshold_db=-18, ratio=3.5)

        # Fade in/out
        fade_in = int(0.05 * sr)
        fade_out = int(0.08 * sr)
        if len(seg) > fade_in + fade_out:
            seg[:fade_in] *= np.linspace(0, 1, fade_in)
            seg[-fade_out:] *= np.linspace(1, 0, fade_out)

        segments[i] = seg

    # Calculate variable gaps (natural conversation feel)
    gaps = [0.0]  # no gap before first turn
    for i in range(1, len(SCRIPT)):
        prev_spk = SCRIPT[i - 1][0]
        curr_spk = SCRIPT[i][0]
        text = SCRIPT[i][1]
        prev_text = SCRIPT[i - 1][1]

        # Questions get quick responses
        if prev_text.rstrip().endswith('?'):
            gap = random.uniform(0.15, 0.30)
        # Short responses — quick back-and-forth
        elif len(text) < 40:
            gap = random.uniform(0.20, 0.35)
        # Same speaker continuing
        elif prev_spk == curr_spk:
            gap = random.uniform(0.40, 0.60)
        # Normal turn change
        else:
            gap = random.uniform(0.25, 0.45)

        # Occasional slight overlap for rapid banter
        if len(text) < 25 and random.random() < 0.2:
            gap = random.uniform(-0.05, 0.05)

        gaps.append(gap)

    # Calculate total length
    intro_silence = int(0.4 * sr)
    outro_silence = int(0.8 * sr)
    total_samples = intro_silence + outro_silence
    for i, seg in enumerate(segments):
        gap_samples = int(gaps[i] * sr)
        total_samples += gap_samples + len(seg)

    # Mix
    mixed = np.zeros(total_samples + sr, dtype=np.float32)
    pos = intro_silence

    for i, seg in enumerate(segments):
        gap_samples = int(gaps[i] * sr) if i > 0 else 0
        pos += gap_samples
        start = max(0, pos)
        end = start + len(seg)
        if end > len(mixed):
            mixed = np.pad(mixed, (0, end - len(mixed) + sr))
        mixed[start:start + len(seg)] += seg
        pos = start + len(seg)

    # Trim
    mixed = mixed[:pos + outro_silence]

    # Room reverb
    mixed = add_room_reverb(mixed, sr, delay_ms=50, wet=0.02)

    # Ambient noise floor in silent regions
    noise = np.random.randn(len(mixed)).astype(np.float32) * 0.0015
    envelope = np.convolve(np.abs(mixed), np.ones(sr // 10) / (sr // 10), mode='same')
    quiet_mask = envelope < 0.005
    mixed[quiet_mask] += noise[quiet_mask]

    # Global LUFS normalization
    mixed = normalize_lufs(mixed, sr, target=-16)

    # Limiter
    mixed = np.clip(mixed, -0.95, 0.95)

    # Export as MP3
    from pydub import AudioSegment
    wav_tmp = output_path.replace('.mp3', '_tmp.wav')
    write_wav(wav_tmp, mixed, sr)

    audio_seg = AudioSegment.from_wav(wav_tmp)
    audio_seg.export(
        output_path,
        format='mp3',
        bitrate='320k',
        tags={
            'title': '.NET Rocks AI Demo',
            'artist': 'Carl Franklin & Richard Campbell (AI)',
            'album': '.NET Rocks Voice Clone Demo',
        }
    )
    os.remove(wav_tmp)

    dur = len(mixed) / sr
    size_kb = os.path.getsize(output_path) / 1024
    print(f"  ✓ {output_path} — {dur:.1f}s, {size_kb:.0f} KB")
    return dur


def assemble_baseline_only(tts_paths, output_path):
    """Assemble Azure TTS baseline (no voice conversion, minimal processing)."""
    print("\n  Assembling Azure TTS baseline...")

    import librosa

    segments = []
    for i, (speaker, text) in enumerate(SCRIPT):
        audio, sr = read_wav(tts_paths[i])
        if sr != SAMPLE_RATE:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
        segments.append(audio)

    sr = SAMPLE_RATE

    # Light processing only — keep it close to raw TTS
    for i in range(len(segments)):
        seg = segments[i]
        seg = apply_warmth_eq(seg, sr, boost_db=1.0, cutoff=250)
        fade_in = int(0.03 * sr)
        fade_out = int(0.05 * sr)
        if len(seg) > fade_in + fade_out:
            seg[:fade_in] *= np.linspace(0, 1, fade_in)
            seg[-fade_out:] *= np.linspace(1, 0, fade_out)
        segments[i] = seg

    # Simple gaps
    gaps = [0.0]
    for i in range(1, len(SCRIPT)):
        prev_text = SCRIPT[i - 1][1]
        if prev_text.rstrip().endswith('?'):
            gaps.append(random.uniform(0.20, 0.35))
        else:
            gaps.append(random.uniform(0.30, 0.50))

    # Concatenate
    intro = int(0.3 * sr)
    outro = int(0.5 * sr)
    total = intro + outro
    for i, seg in enumerate(segments):
        total += int(gaps[i] * sr) + len(seg)

    mixed = np.zeros(total + sr, dtype=np.float32)
    pos = intro
    for i, seg in enumerate(segments):
        gap = int(gaps[i] * sr) if i > 0 else 0
        pos += gap
        end = pos + len(seg)
        if end > len(mixed):
            mixed = np.pad(mixed, (0, end - len(mixed) + sr))
        mixed[pos:pos + len(seg)] = seg
        pos += len(seg)

    mixed = mixed[:pos + outro]
    mixed = normalize_lufs(mixed, sr, target=-16)
    mixed = np.clip(mixed, -0.95, 0.95)

    from pydub import AudioSegment
    wav_tmp = output_path.replace('.mp3', '_tmp.wav')
    write_wav(wav_tmp, mixed, sr)
    audio_seg = AudioSegment.from_wav(wav_tmp)
    audio_seg.export(output_path, format='mp3', bitrate='320k', tags={
        'title': '.NET Rocks AI Demo — Azure TTS Baseline',
        'artist': 'Carl Franklin & Richard Campbell (AI)',
        'album': '.NET Rocks Voice Clone Demo',
    })
    os.remove(wav_tmp)

    dur = len(mixed) / sr
    size_kb = os.path.getsize(output_path) / 1024
    print(f"  ✓ {output_path} — {dur:.1f}s, {size_kb:.0f} KB")
    return dur


# ═══════════════════════════════════════════════════════════════════════
# MAIN PIPELINE
# ═══════════════════════════════════════════════════════════════════════

def main():
    print("╔" + "═" * 68 + "╗")
    print("║  .NET Rocks Voice Cloning Pipeline                               ║")
    print("║  Carl Franklin (DavisNeural) + Richard Campbell (JasonNeural)     ║")
    print("╚" + "═" * 68 + "╝")

    t_start = time.time()
    random.seed(42)  # reproducible gaps

    # ── Step 1: Azure TTS ──
    tts_paths = render_azure_tts()

    # Verify all rendered
    missing = [i for i, p in enumerate(tts_paths) if not os.path.exists(p) or os.path.getsize(p) < 500]
    if missing:
        print(f"\n  ⚠ Missing TTS turns: {missing}")
        sys.exit(1)

    # ── Output 1: Azure Baseline ──
    baseline_path = os.path.join(WORKDIR, 'dotnet-rocks-demo-azure-baseline.mp3')
    assemble_baseline_only(tts_paths, baseline_path)

    # ── Step 2: Seed-VC Voice Conversion ──
    seedvc_paths, has_seedvc = run_seedvc_conversion(tts_paths, REF_MAP)

    # ── Output 2: Seed-VC version ──
    if has_seedvc:
        seedvc_output = os.path.join(WORKDIR, 'dotnet-rocks-demo-seedvc.mp3')
        assemble_podcast(seedvc_paths, seedvc_output, label="Seed-VC")
    else:
        print("\n  Seed-VC skipped — no reference audio available")
        seedvc_paths = tts_paths

    # ── Step 3: Formant Correction ──
    formant_paths = apply_formant_correction(seedvc_paths)

    # ── Output 3: Formant corrected ──
    formant_output = os.path.join(WORKDIR, 'dotnet-rocks-demo-formant.mp3')
    assemble_podcast(formant_paths, formant_output, label="Formant Corrected")

    # ── Output 4: Final post-processed ──
    final_output = os.path.join(WORKDIR, 'dotnet-rocks-demo-final.mp3')
    assemble_podcast(formant_paths, final_output, label="Final Production")

    # ── Summary ──
    total_time = time.time() - t_start
    print("\n" + "=" * 70)
    print("  PIPELINE COMPLETE")
    print("=" * 70)
    print(f"  Total time: {total_time:.0f}s ({total_time/60:.1f} min)")
    print(f"\n  Outputs:")
    for f in [baseline_path,
              os.path.join(WORKDIR, 'dotnet-rocks-demo-seedvc.mp3'),
              formant_output, final_output]:
        if os.path.exists(f):
            sz = os.path.getsize(f) / 1024
            print(f"    ✓ {os.path.basename(f)} ({sz:.0f} KB)")
        else:
            print(f"    ✗ {os.path.basename(f)} (not generated)")

    print(f"\n  Voice config:")
    for speaker in ['Carl', 'Richard']:
        voice = VOICE_MAP[speaker]
        f0 = PITCH_TARGETS[speaker]
        ref = REF_MAP[speaker]
        has_ref = "✓" if os.path.exists(ref) else "✗"
        print(f"    {speaker:8s}: {voice}, F0={f0}Hz, ref={has_ref}")

    return True


if __name__ == '__main__':
    main()
