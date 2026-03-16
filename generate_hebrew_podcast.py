"""
Hebrew Podcast Generator using Chatterbox Multilingual TTS (Resemble AI)
Voice cloning from reference samples for two speakers.
"""
import os
import re
import sys

# Fix perth watermarker before importing chatterbox
import perth
if perth.PerthImplicitWatermarker is None:
    from perth.dummy_watermarker import DummyWatermarker
    perth.PerthImplicitWatermarker = DummyWatermarker
    print("Note: Using DummyWatermarker (perth native lib unavailable)")

import torch
import torchaudio as ta
from pathlib import Path

# Paths
SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
VOICE_SAMPLES_DIR = r"C:\temp\tamresearch1\voice_samples"
OUTPUT_DIR = r"C:\temp\tamresearch1"
OUTPUT_WAV = os.path.join(OUTPUT_DIR, "hebrew-podcast-chatterbox.wav")
OUTPUT_MP3 = os.path.join(OUTPUT_DIR, "hebrew-podcast-chatterbox.mp3")

# Speaker → reference audio mapping
SPEAKER_MAP = {
    "AVRI": os.path.join(VOICE_SAMPLES_DIR, "dotan_ref.wav"),
    "HILA": os.path.join(VOICE_SAMPLES_DIR, "shahar_ref.wav"),
}

PAUSE_SECONDS = 0.6  # pause between turns


def parse_script(filepath: str) -> list[tuple[str, str]]:
    """Parse script file into list of (speaker, text) tuples."""
    turns = []
    pattern = re.compile(r"^\[(\w+)\]\s*(.+)$")
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            match = pattern.match(line)
            if match:
                speaker = match.group(1)
                text = match.group(2)
                turns.append((speaker, text))
    return turns


def generate_podcast():
    print("=" * 60)
    print("Hebrew Podcast Generator — Chatterbox Multilingual")
    print("=" * 60)

    # Check CUDA
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        vram_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        print(f"GPU: {gpu_name} ({vram_gb:.1f} GB VRAM)")
        device = "cuda"
    else:
        device = "cpu"
    print(f"Using device: {device}")

    # Enable memory-efficient settings for tight VRAM
    if device == "cuda":
        torch.backends.cudnn.benchmark = True
        torch.cuda.empty_cache()

    # Parse script
    turns = parse_script(SCRIPT_FILE)
    print(f"Parsed {len(turns)} dialogue turns")

    # Validate voice samples exist
    for speaker, ref_path in SPEAKER_MAP.items():
        if not os.path.exists(ref_path):
            print(f"ERROR: Reference audio not found for {speaker}: {ref_path}")
            sys.exit(1)
        print(f"  {speaker} → {os.path.basename(ref_path)}")

    # Load model
    print("\nLoading Chatterbox Multilingual model...")
    try:
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        model = ChatterboxMultilingualTTS.from_pretrained(device=device)
        sample_rate = model.sr
        print(f"Model loaded! Sample rate: {sample_rate}")
    except Exception as e:
        print(f"Failed to load on {device}: {e}")
        if device == "cuda":
            print("Retrying on CPU...")
            device = "cpu"
            model = ChatterboxMultilingualTTS.from_pretrained(device=device)
            sample_rate = model.sr
            print(f"Model loaded on CPU! Sample rate: {sample_rate}")
        else:
            raise

    # Generate each turn
    all_audio = []
    pause_samples = int(PAUSE_SECONDS * sample_rate)
    pause_tensor = torch.zeros(1, pause_samples)

    for i, (speaker, text) in enumerate(turns):
        ref_path = SPEAKER_MAP.get(speaker)
        if not ref_path:
            print(f"WARNING: Unknown speaker '{speaker}', skipping turn {i+1}")
            continue

        print(f"\n[{i+1}/{len(turns)}] {speaker}: {text[:50]}...")
        try:
            wav = model.generate(
                text,
                language_id="he",
                audio_prompt_path=ref_path,
                exaggeration=0.5,
                cfg_weight=0.5,
            )
            # Ensure 2D tensor (channels, samples)
            if wav.dim() == 1:
                wav = wav.unsqueeze(0)
            if wav.dim() == 3:
                wav = wav.squeeze(0)

            # Move to CPU if needed
            wav = wav.cpu()
            duration = wav.shape[-1] / sample_rate
            print(f"  Generated {duration:.1f}s of audio")

            all_audio.append(wav)
            all_audio.append(pause_tensor)

        except torch.cuda.OutOfMemoryError:
            print(f"  CUDA OOM on turn {i+1}! Falling back to CPU...")
            torch.cuda.empty_cache()
            model = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
            sample_rate = model.sr
            pause_samples = int(PAUSE_SECONDS * sample_rate)
            pause_tensor = torch.zeros(1, pause_samples)
            wav = model.generate(
                text, language_id="he", audio_prompt_path=ref_path,
                exaggeration=0.5, cfg_weight=0.5,
            )
            if wav.dim() == 1:
                wav = wav.unsqueeze(0)
            if wav.dim() == 3:
                wav = wav.squeeze(0)
            wav = wav.cpu()
            duration = wav.shape[-1] / sample_rate
            print(f"  Generated {duration:.1f}s of audio (CPU)")
            all_audio.append(wav)
            all_audio.append(pause_tensor)

        except Exception as e:
            print(f"  ERROR on turn {i+1}: {e}")
            continue

    if not all_audio:
        print("No audio generated!")
        sys.exit(1)

    # Concatenate all audio
    print(f"\nConcatenating {len(all_audio)} segments...")
    full_audio = torch.cat(all_audio, dim=-1)
    total_duration = full_audio.shape[-1] / sample_rate
    print(f"Total podcast duration: {total_duration:.1f}s ({total_duration/60:.1f} min)")

    # Save WAV using soundfile (torchaudio.save requires torchcodec)
    import soundfile as sf
    audio_np = full_audio.squeeze(0).numpy()
    sf.write(OUTPUT_WAV, audio_np, sample_rate)
    print(f"Saved WAV: {OUTPUT_WAV}")

    # Convert to MP3
    try:
        from pydub import AudioSegment
        audio = AudioSegment.from_wav(OUTPUT_WAV)
        audio.export(OUTPUT_MP3, format="mp3", bitrate="192k")
        print(f"Saved MP3: {OUTPUT_MP3}")
        # Clean up WAV intermediate
        os.remove(OUTPUT_WAV)
        print("Cleaned up intermediate WAV file")
    except Exception as e:
        print(f"MP3 conversion failed: {e}")
        print(f"WAV file available at: {OUTPUT_WAV}")

    print("\n" + "=" * 60)
    print("DONE! Hebrew podcast generated successfully.")
    print("=" * 60)
    return OUTPUT_MP3 if os.path.exists(OUTPUT_MP3) else OUTPUT_WAV


if __name__ == "__main__":
    result = generate_podcast()
    print(f"\nOutput: {result}")
