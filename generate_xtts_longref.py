#!/usr/bin/env python3
"""
Hebrew Podcast Generator using Coqui XTTS v2 with LONG reference clips.
Uses 60-second reference samples for better voice cloning.
"""
import os
import re
import sys
import time
import glob

os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("=" * 60, flush=True)
print("XTTS v2 Hebrew Podcast — LONG Reference Clips", flush=True)
print("=" * 60, flush=True)

import torch
_original_torch_load = torch.load
def _patched_torch_load(*args, **kwargs):
    if 'weights_only' not in kwargs:
        kwargs['weights_only'] = False
    return _original_torch_load(*args, **kwargs)
torch.load = _patched_torch_load

print("\n[1/5] Loading XTTS v2 model...", flush=True)
t0 = time.time()
from TTS.api import TTS
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2")

if hasattr(tts, 'synthesizer') and hasattr(tts.synthesizer, 'tts_model') and hasattr(tts.synthesizer.tts_model, 'config'):
    cfg = tts.synthesizer.tts_model.config
    if hasattr(cfg, 'languages') and 'he' not in cfg.languages:
        cfg.languages.append('he')
        print("  Added 'he' to supported languages list", flush=True)

print(f"  Model loaded in {time.time()-t0:.1f}s", flush=True)

# LONG reference clips
DOTAN_REF = "voice_samples/dotan_ref_60s.wav"
SHAHAR_REF = "voice_samples/shahar_ref_60s.wav"

# Sanity test
print("\n[2/5] Sanity test with Hebrew...", flush=True)
test_text = "שלום, זהו מבחן קצר של סינתזה בעברית"
LANG = "he"
try:
    tts.tts_to_file(text=test_text, file_path="test_xtts_longref.wav",
                    speaker_wav=DOTAN_REF, language=LANG)
except Exception as e:
    print(f"  Hebrew failed: {str(e)[:100]}", flush=True)
    print("  Falling back to Arabic...", flush=True)
    LANG = "ar"
    try:
        tts.tts_to_file(text=test_text, file_path="test_xtts_longref.wav",
                        speaker_wav=DOTAN_REF, language=LANG)
    except:
        LANG = "en"
        tts.tts_to_file(text=test_text, file_path="test_xtts_longref.wav",
                        speaker_wav=DOTAN_REF, language=LANG)

print(f"  Using language='{LANG}'", flush=True)

# Parse script
print("\n[3/5] Parsing script...", flush=True)
script = open("hebrew-cloned-podcast.script.txt", encoding="utf-8").read()
turns = []
for line in script.strip().split("\n"):
    line = line.strip()
    if not line:
        continue
    match = re.match(r'\[(\w+)\]\s*(.*)', line)
    if match:
        speaker, text = match.groups()
        if text.strip():
            turns.append((speaker, text.strip()))

print(f"  {len(turns)} turns", flush=True)

# Generate
print("\n[4/5] Generating segments...", flush=True)
segment_files = []
for i, (speaker, text) in enumerate(turns):
    ref_wav = DOTAN_REF if speaker == "AVRI" else SHAHAR_REF
    out_file = f"temp_xtts_longref_{i:03d}.wav"
    
    print(f"  [{i+1}/{len(turns)}] {speaker}: {text[:50]}...", flush=True)
    t1 = time.time()
    
    try:
        tts.tts_to_file(text=text, file_path=out_file,
                        speaker_wav=ref_wav, language=LANG)
        elapsed = time.time() - t1
        print(f"    Done {elapsed:.1f}s", flush=True)
        segment_files.append(out_file)
    except Exception as e:
        print(f"    ERROR: {e}", flush=True)
        if len(text) > 100:
            parts = re.split(r'[,.]', text)
            for j, part in enumerate(parts):
                part = part.strip()
                if not part:
                    continue
                part_file = f"temp_xtts_longref_{i:03d}_{j}.wav"
                try:
                    tts.tts_to_file(text=part, file_path=part_file,
                                    speaker_wav=ref_wav, language=LANG)
                    segment_files.append(part_file)
                except:
                    pass

# Concatenate
print("\n[5/5] Concatenating...", flush=True)
import soundfile as sf
import numpy as np
import wave

all_audio = []
sr = None
for seg_file in segment_files:
    try:
        data, file_sr = sf.read(seg_file)
        if sr is None:
            sr = file_sr
        all_audio.append(data)
        all_audio.append(np.zeros(int(0.3 * sr)))  # 300ms pause
    except Exception as e:
        print(f"  Skip {seg_file}: {e}", flush=True)

if not all_audio:
    print("No audio!", flush=True)
    sys.exit(1)

full = np.concatenate(all_audio)
sr = sr or 22050

output_wav = "hebrew-podcast-xtts-longref.wav"
output_mp3 = "hebrew-podcast-xtts-longref.mp3"

sf.write(output_wav, full, sr)
print(f"  WAV: {output_wav} ({len(full)/sr:.1f}s)", flush=True)

# MP3 conversion
try:
    import imageio_ffmpeg
    ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
except:
    ffmpeg_path = "ffmpeg"

import subprocess
try:
    result = subprocess.run([ffmpeg_path, '-y', '-i', output_wav, '-b:a', '192k', output_mp3],
                           capture_output=True, text=True, timeout=120)
    if result.returncode == 0:
        print(f"  MP3: {output_mp3}", flush=True)
except Exception as e:
    print(f"  MP3 conversion failed: {e}", flush=True)

# Cleanup
for f in glob.glob("temp_xtts_longref_*.wav"):
    os.remove(f)
if os.path.exists("test_xtts_longref.wav"):
    os.remove("test_xtts_longref.wav")

print(f"\nDone! Duration: {len(full)/sr/60:.1f} min", flush=True)
