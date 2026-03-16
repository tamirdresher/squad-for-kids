"""
Generate Hebrew podcast using:
  1. edge-tts for Hebrew speech generation (native Hebrew support)
  2. OpenVoice V2 tone color converter for voice cloning

Uses dotan_ref.wav for AVRI speaker and shahar_ref.wav for HILA speaker.
"""
import os
import sys
import re
import time
import asyncio

# Paths
SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
AVRI_REF = r"C:\temp\tamresearch1\voice_samples\dotan_ref.wav"
HILA_REF = r"C:\temp\tamresearch1\voice_samples\shahar_ref.wav"
OUTPUT_DIR = r"C:\temp\tamresearch1\openvoice_output"
FINAL_OUTPUT_WAV = r"C:\temp\tamresearch1\hebrew-podcast-openvoice.wav"

# Hebrew edge-tts voices
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
    """Apply OpenVoice V2 tone color conversion to all files."""
    import torch
    from openvoice_cli.api import ToneColorConverter
    from openvoice_cli import se_extractor
    from openvoice_cli.downloader import download_checkpoint

    device = "cuda:0" if torch.cuda.is_available() else "cpu"

    # Download checkpoint if needed
    pkg_dir = os.path.dirname(os.path.realpath(__import__('openvoice_cli').__file__))
    ckpt_dir = os.path.join(pkg_dir, 'checkpoints', 'converter')
    if not os.path.exists(ckpt_dir):
        os.makedirs(ckpt_dir, exist_ok=True)
        download_checkpoint(ckpt_dir)

    # Load converter
    converter = ToneColorConverter(
        os.path.join(ckpt_dir, 'config.json'), device=device
    )
    converter.load_ckpt(os.path.join(ckpt_dir, 'checkpoint.pth'))
    print(f"OpenVoice converter loaded on {device}")

    # Extract speaker embeddings from reference audio
    print("Extracting AVRI reference embedding...")
    avri_se, _ = se_extractor.get_se(ref_avri, converter, vad=True)
    print("Extracting HILA reference embedding...")
    hila_se, _ = se_extractor.get_se(ref_hila, converter, vad=True)

    cloned_files = []
    for i, (speaker, text) in enumerate(turns):
        cloned_file = os.path.join(output_dir, f"cloned_{i:03d}_{speaker}.wav")

        if os.path.exists(cloned_file):
            print(f"[{i+1}/{len(turns)}] Skipping {speaker} clone (exists)")
            cloned_files.append(cloned_file)
            continue

        base_file = base_files[i]
        target_se = avri_se if speaker == "AVRI" else hila_se

        # Get source speaker embedding
        try:
            source_se, _ = se_extractor.get_se(base_file, converter, vad=True)
        except Exception as e:
            print(f"[{i+1}/{len(turns)}] SE extraction failed: {e}, using base file")
            cloned_files.append(base_file)
            continue

        print(f"[{i+1}/{len(turns)}] Cloning {speaker}: {text[:50]}...")
        start = time.time()

        try:
            converter.convert(
                audio_src_path=base_file,
                src_se=source_se,
                tgt_se=target_se,
                output_path=cloned_file,
            )
            elapsed = time.time() - start
            print(f"    Done in {elapsed:.1f}s")
            cloned_files.append(cloned_file)
        except Exception as e:
            print(f"    Clone failed: {e}, using base file")
            cloned_files.append(base_file)

    return cloned_files

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    turns = parse_script(SCRIPT_FILE)
    print(f"Parsed {len(turns)} dialogue turns")

    # Step 1: Generate base Hebrew speech with edge-tts
    print("\n=== Step 1: Generating Hebrew speech with edge-tts ===")
    base_files = []
    for i, (speaker, text) in enumerate(turns):
        base_file = os.path.join(OUTPUT_DIR, f"base_{i:03d}_{speaker}.mp3")
        if os.path.exists(base_file):
            print(f"[{i+1}/{len(turns)}] Skipping {speaker} base (exists)")
            base_files.append(base_file)
            continue

        voice = AVRI_VOICE if speaker == "AVRI" else HILA_VOICE
        print(f"[{i+1}/{len(turns)}] edge-tts {speaker}: {text[:50]}...")
        start = time.time()
        asyncio.run(generate_edge_tts(text, voice, base_file))
        elapsed = time.time() - start
        print(f"    Done in {elapsed:.1f}s")
        base_files.append(base_file)

    # Step 2: Apply voice cloning
    print("\n=== Step 2: Applying voice cloning with OpenVoice V2 ===")
    cloned_files = apply_voice_cloning_openvoice(
        base_files, turns, AVRI_REF, HILA_REF, OUTPUT_DIR
    )

    # Step 3: Concatenate
    print("\n=== Step 3: Concatenating podcast ===")
    import torch
    import torchaudio

    all_audio = []
    sample_rate = None
    for f in cloned_files:
        wav, sr = torchaudio.load(f)
        if sample_rate is None:
            sample_rate = sr
        elif sr != sample_rate:
            resampler = torchaudio.transforms.Resample(sr, sample_rate)
            wav = resampler(wav)
        # Ensure mono
        if wav.shape[0] > 1:
            wav = wav.mean(dim=0, keepdim=True)
        all_audio.append(wav)
        silence = torch.zeros(1, int(0.5 * sample_rate))
        all_audio.append(silence)

    if all_audio:
        all_audio = all_audio[:-1]
        full_audio = torch.cat(all_audio, dim=1)
        torchaudio.save(FINAL_OUTPUT_WAV, full_audio, sample_rate)
        duration = full_audio.shape[1] / sample_rate
        print(f"Saved: {FINAL_OUTPUT_WAV}")
        print(f"Duration: {duration/60:.1f} min ({duration:.0f}s)")

    print("\nDone!")

if __name__ == "__main__":
    main()
