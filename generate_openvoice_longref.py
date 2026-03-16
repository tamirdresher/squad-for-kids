"""
Generate Hebrew podcast using:
  1. edge-tts for Hebrew speech generation (native Hebrew support)
  2. OpenVoice V2 tone color converter for voice cloning with LONG reference clips
"""
import os
import sys
import re
import time
import asyncio

SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
AVRI_REF = r"C:\temp\tamresearch1\voice_samples\dotan_ref_60s.wav"
HILA_REF = r"C:\temp\tamresearch1\voice_samples\shahar_ref_60s.wav"
OUTPUT_DIR = r"C:\temp\tamresearch1\openvoice_longref_output"
FINAL_OUTPUT_WAV = r"C:\temp\tamresearch1\hebrew-podcast-openvoice-longref.wav"
FINAL_OUTPUT_MP3 = r"C:\temp\tamresearch1\hebrew-podcast-openvoice-longref.mp3"

AVRI_VOICE = "he-IL-AvriNeural"
HILA_VOICE = "he-IL-HilaNeural"

def parse_script(filepath):
    turns = []
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            match = re.match(r"\[(AVRI|HILA)\]\s*(.*)", line)
            if match:
                speaker = match.group(1)
                text = match.group(2).strip()
                if text:
                    turns.append((speaker, text))
    return turns

async def generate_edge_tts(text, voice, output_path, rate="+5%"):
    import edge_tts
    communicate = edge_tts.Communicate(text, voice, rate=rate)
    await communicate.save(output_path)

def apply_voice_cloning_openvoice(base_files, turns, ref_avri, ref_hila, output_dir):
    import torch
    from openvoice_cli.api import ToneColorConverter
    from openvoice_cli import se_extractor
    from openvoice_cli.downloader import download_checkpoint

    device = "cuda:0" if torch.cuda.is_available() else "cpu"

    pkg_dir = os.path.dirname(os.path.realpath(__import__('openvoice_cli').__file__))
    ckpt_dir = os.path.join(pkg_dir, 'checkpoints', 'converter')
    if not os.path.exists(ckpt_dir):
        os.makedirs(ckpt_dir, exist_ok=True)
        download_checkpoint(ckpt_dir)

    converter = ToneColorConverter(
        os.path.join(ckpt_dir, 'config.json'), device=device
    )
    converter.load_ckpt(os.path.join(ckpt_dir, 'checkpoint.pth'))
    print(f"OpenVoice converter loaded on {device}", flush=True)

    # Extract speaker embeddings from LONG reference audio
    print(f"Extracting AVRI ref embedding from {os.path.basename(ref_avri)}...", flush=True)
    avri_se, _ = se_extractor.get_se(ref_avri, converter, vad=True)
    print(f"Extracting HILA ref embedding from {os.path.basename(ref_hila)}...", flush=True)
    hila_se, _ = se_extractor.get_se(ref_hila, converter, vad=True)

    cloned_files = []
    for i, (speaker, text) in enumerate(turns):
        cloned_file = os.path.join(output_dir, f"cloned_{i:03d}_{speaker}.wav")
        base_file = base_files[i]
        target_se = avri_se if speaker == "AVRI" else hila_se

        try:
            source_se, _ = se_extractor.get_se(base_file, converter, vad=True)
        except Exception as e:
            print(f"[{i+1}/{len(turns)}] SE extraction failed: {e}", flush=True)
            cloned_files.append(base_file)
            continue

        print(f"[{i+1}/{len(turns)}] Cloning {speaker}: {text[:50]}...", flush=True)
        start = time.time()
        try:
            converter.convert(
                audio_src_path=base_file,
                src_se=source_se,
                tgt_se=target_se,
                output_path=cloned_file,
            )
            elapsed = time.time() - start
            print(f"    Done in {elapsed:.1f}s", flush=True)
            cloned_files.append(cloned_file)
        except Exception as e:
            print(f"    Clone failed: {e}", flush=True)
            cloned_files.append(base_file)

    return cloned_files

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    turns = parse_script(SCRIPT_FILE)
    print(f"Parsed {len(turns)} dialogue turns", flush=True)

    # Step 1: Generate base Hebrew speech with edge-tts
    print("\n=== Step 1: edge-tts base speech ===", flush=True)
    base_files = []
    for i, (speaker, text) in enumerate(turns):
        mp3_file = os.path.join(OUTPUT_DIR, f"base_{i:03d}_{speaker}.mp3")
        wav_file = os.path.join(OUTPUT_DIR, f"base_{i:03d}_{speaker}.wav")
        if os.path.exists(wav_file) and os.path.getsize(wav_file) > 100:
            base_files.append(wav_file)
            continue
        voice = AVRI_VOICE if speaker == "AVRI" else HILA_VOICE
        print(f"[{i+1}/{len(turns)}] {speaker}: {text[:50]}...", flush=True)
        if not os.path.exists(mp3_file):
            asyncio.run(generate_edge_tts(text, voice, mp3_file))
        # Convert MP3 to WAV for OpenVoice compatibility
        import subprocess, imageio_ffmpeg
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-i', mp3_file,
                       '-ar', '22050', '-ac', '1', wav_file],
                      capture_output=True, timeout=30)
        base_files.append(wav_file)

    # Step 2: Apply voice cloning with LONG references
    print("\n=== Step 2: OpenVoice V2 cloning (LONG refs) ===", flush=True)
    cloned_files = apply_voice_cloning_openvoice(
        base_files, turns, AVRI_REF, HILA_REF, OUTPUT_DIR
    )

    # Step 3: Concatenate
    print("\n=== Step 3: Concatenate ===", flush=True)
    import soundfile as sf
    import numpy as np

    all_audio = []
    sample_rate = None
    for f in cloned_files:
        try:
            data, sr = sf.read(f)
            if sample_rate is None:
                sample_rate = sr
            if len(data.shape) > 1:
                data = data.mean(axis=1)
            all_audio.append(data)
            all_audio.append(np.zeros(int(0.4 * sr)))
        except Exception as e:
            print(f"  Skip {f}: {e}", flush=True)

    if not all_audio:
        print("No audio!", flush=True)
        return

    full = np.concatenate(all_audio)
    sf.write(FINAL_OUTPUT_WAV, full, sample_rate)
    dur = len(full) / sample_rate
    print(f"Saved: {FINAL_OUTPUT_WAV} ({dur:.1f}s)", flush=True)

    # MP3
    try:
        import imageio_ffmpeg
        ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
        import subprocess
        subprocess.run([ffmpeg_path, '-y', '-i', FINAL_OUTPUT_WAV, '-b:a', '192k', FINAL_OUTPUT_MP3],
                      capture_output=True, timeout=120)
        print(f"Saved: {FINAL_OUTPUT_MP3}", flush=True)
    except Exception as e:
        print(f"MP3 failed: {e}", flush=True)

    print(f"\nDone! Duration: {dur/60:.1f} min", flush=True)

if __name__ == "__main__":
    main()
