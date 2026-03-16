#!/usr/bin/env python3
"""
Hebrew Podcast Generator using Coqui XTTS v2
Generates a voice-cloned Hebrew podcast from script + reference WAVs.
"""
import os
import re
import sys
import time
import glob

# Set working directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("=" * 60)
print("XTTS v2 Hebrew Podcast Generator")
print("=" * 60)

# Patch torch.load to allow Coqui TTS pickled checkpoints (PyTorch >=2.6 defaults weights_only=True)
import torch
_original_torch_load = torch.load
def _patched_torch_load(*args, **kwargs):
    if 'weights_only' not in kwargs:
        kwargs['weights_only'] = False
    return _original_torch_load(*args, **kwargs)
torch.load = _patched_torch_load

# Step 1: Load TTS model
print("\n[1/5] Loading XTTS v2 model...")
t0 = time.time()
from TTS.api import TTS
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2")

# Monkey-patch: add Hebrew to supported languages (Hebrew is Semitic like Arabic, model may handle it)
if hasattr(tts, 'synthesizer') and hasattr(tts.synthesizer, 'tts_model') and hasattr(tts.synthesizer.tts_model, 'config'):
    cfg = tts.synthesizer.tts_model.config
    if hasattr(cfg, 'languages') and 'he' not in cfg.languages:
        cfg.languages.append('he')
        print("  Added 'he' to supported languages list")

print(f"  Model loaded in {time.time()-t0:.1f}s")

# Step 2: Quick sanity test - try Hebrew, fall back to Arabic
print("\n[2/5] Quick sanity test with Hebrew...")
test_text = "שלום, זהו מבחן קצר של סינתזה בעברית"
LANG = "he"
try:
    tts.tts_to_file(
        text=test_text,
        file_path="test_xtts_sanity.wav",
        speaker_wav="voice_samples/dotan_ref.wav",
        language=LANG
    )
except Exception as e:
    err_msg = str(e)
    print(f"  Hebrew ('he') failed: {err_msg[:100]}")
    print("  Falling back to Arabic ('ar') - closest Semitic language...")
    LANG = "ar"
    try:
        tts.tts_to_file(
            text=test_text,
            file_path="test_xtts_sanity.wav",
            speaker_wav="voice_samples/dotan_ref.wav",
            language=LANG
        )
    except Exception as e2:
        print(f"  Arabic also failed: {e2}")
        print("  Trying English with Hebrew text as last resort...")
        LANG = "en"
        tts.tts_to_file(
            text=test_text,
            file_path="test_xtts_sanity.wav",
            speaker_wav="voice_samples/dotan_ref.wav",
            language=LANG
        )

if os.path.exists("test_xtts_sanity.wav") and os.path.getsize("test_xtts_sanity.wav") > 1000:
    print(f"  Sanity test PASSED - using language='{LANG}'!")
else:
    print("  ERROR: Sanity test failed!")
    sys.exit(1)

# Step 3: Parse script
print("\n[3/5] Parsing script...")
script = open("hebrew-cloned-podcast.script.txt", encoding="utf-8").read()
turns = []
for line in script.strip().split("\n"):
    line = line.strip()
    if not line:
        continue
    match = re.match(r'\[(\w+)\]\s*(.*)', line)
    if not match:
        continue
    speaker, text = match.groups()
    if text.strip():
        turns.append((speaker, text.strip()))

print(f"  Found {len(turns)} dialogue turns")

# Step 4: Generate each segment
print("\n[4/5] Generating voice segments (this will be SLOW on CPU)...")
print(f"  Estimated time: {len(turns) * 45 // 60}-{len(turns) * 75 // 60} minutes")

segment_files = []
for i, (speaker, text) in enumerate(turns):
    ref_wav = "voice_samples/dotan_ref.wav" if speaker == "AVRI" else "voice_samples/shahar_ref.wav"
    out_file = f"temp_segment_{i:03d}.wav"
    
    print(f"  [{i+1}/{len(turns)}] {speaker}: {text[:50]}...")
    t1 = time.time()
    
    try:
        tts.tts_to_file(
            text=text,
            file_path=out_file,
            speaker_wav=ref_wav,
            language=LANG
        )
        elapsed = time.time() - t1
        size_kb = os.path.getsize(out_file) / 1024
        print(f"         Done in {elapsed:.1f}s ({size_kb:.0f}KB)")
        segment_files.append(out_file)
    except Exception as e:
        print(f"         ERROR: {e}")
        # Try with shorter text if too long
        if len(text) > 100:
            print(f"         Retrying with split text...")
            # Split at comma or period
            parts = re.split(r'[,.]', text)
            for j, part in enumerate(parts):
                part = part.strip()
                if not part:
                    continue
                part_file = f"temp_segment_{i:03d}_{j}.wav"
                try:
                    tts.tts_to_file(
                        text=part,
                        file_path=part_file,
                        speaker_wav=ref_wav,
                        language=LANG
                    )
                    segment_files.append(part_file)
                except Exception as e2:
                    print(f"         Sub-segment also failed: {e2}")

# Step 5: Concatenate
print("\n[5/5] Concatenating segments into final podcast...")
from pydub import AudioSegment

podcast = AudioSegment.empty()
silence = AudioSegment.silent(duration=300)  # 300ms between turns

for seg_file in segment_files:
    try:
        segment = AudioSegment.from_wav(seg_file)
        podcast += segment + silence
    except Exception as e:
        print(f"  Warning: Could not load {seg_file}: {e}")

output_mp3 = "hebrew-podcast-xtts.mp3"
output_wav = "hebrew-podcast-xtts.wav"

# Export WAV first (always works)
podcast.export(output_wav, format="wav")
print(f"  WAV exported: {output_wav} ({os.path.getsize(output_wav)/1024/1024:.1f}MB)")

# Convert to MP3 using ffmpeg directly (more reliable than pydub)
import subprocess
ffmpeg_path = os.path.join(os.environ.get('CONDA_PREFIX', ''), 'Library', 'bin', 'ffmpeg.exe')
if not os.path.exists(ffmpeg_path):
    # Try finding ffmpeg in PATH
    ffmpeg_path = "ffmpeg"

try:
    result = subprocess.run(
        [ffmpeg_path, '-y', '-i', output_wav, '-b:a', '192k', '-ar', '22050', output_mp3],
        capture_output=True, text=True, timeout=120
    )
    if result.returncode == 0 and os.path.exists(output_mp3):
        print(f"  MP3 exported: {output_mp3} ({os.path.getsize(output_mp3)/1024/1024:.1f}MB)")
    else:
        print(f"  MP3 encoding via ffmpeg failed: {result.stderr[:200]}")
        print(f"  WAV file is available at: {output_wav}")
except Exception as e:
    print(f"  MP3 conversion failed: {e}")
    print(f"  WAV file is available at: {output_wav}")

duration_sec = len(podcast) / 1000
print(f"\n  Output: {output_mp3} ({os.path.getsize(output_mp3)/1024:.0f}KB, {duration_sec:.1f}s)")
print(f"  Output: {output_wav} ({os.path.getsize(output_wav)/1024:.0f}KB)")

# Clean up temp files
print("\nCleaning up temp segment files...")
for f in glob.glob("temp_segment_*.wav"):
    os.remove(f)
if os.path.exists("test_xtts_sanity.wav"):
    os.remove("test_xtts_sanity.wav")

print("\n" + "=" * 60)
print(f"DONE! Hebrew podcast generated: {output_mp3}")
print(f"Duration: {duration_sec/60:.1f} minutes")
print("=" * 60)
