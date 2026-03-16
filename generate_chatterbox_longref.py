"""
Hebrew Podcast Generator — Chatterbox Multilingual with LONG reference clips.
Uses 3-minute reference samples for dramatically better voice cloning.
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

SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
VOICE_SAMPLES_DIR = r"C:\temp\tamresearch1\voice_samples"
OUTPUT_DIR = r"C:\temp\tamresearch1"
OUTPUT_WAV = os.path.join(OUTPUT_DIR, "hebrew-podcast-chatterbox-longref.wav")
OUTPUT_MP3 = os.path.join(OUTPUT_DIR, "hebrew-podcast-chatterbox-longref.mp3")

# Use LONG reference clips (60s each - 3x longer than original 20s)
SPEAKER_MAP = {
    "AVRI": os.path.join(VOICE_SAMPLES_DIR, "dotan_ref_60s.wav"),
    "HILA": os.path.join(VOICE_SAMPLES_DIR, "shahar_ref_60s.wav"),
}

PAUSE_SECONDS = 0.6


def parse_script(filepath):
    turns = []
    pattern = re.compile(r"^\[(\w+)\]\s*(.+)$")
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            match = pattern.match(line)
            if match:
                turns.append((match.group(1), match.group(2)))
    return turns


def generate_podcast():
    print("=" * 60)
    print("Hebrew Podcast — Chatterbox (LONG reference clips)")
    print("=" * 60)

    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        vram_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
        print(f"GPU: {gpu_name} ({vram_gb:.1f} GB VRAM)")
        device = "cuda"
    else:
        device = "cpu"
    print(f"Using device: {device}")

    if device == "cuda":
        torch.backends.cudnn.benchmark = True
        torch.cuda.empty_cache()

    turns = parse_script(SCRIPT_FILE)
    print(f"Parsed {len(turns)} dialogue turns")

    for speaker, ref_path in SPEAKER_MAP.items():
        if not os.path.exists(ref_path):
            print(f"ERROR: {ref_path} not found")
            sys.exit(1)
        import wave
        with wave.open(ref_path, 'r') as w:
            dur = w.getnframes() / w.getframerate()
        print(f"  {speaker} → {os.path.basename(ref_path)} ({dur:.1f}s)")

    print("\nLoading Chatterbox Multilingual model...")
    try:
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        model = ChatterboxMultilingualTTS.from_pretrained(device=device)
        sample_rate = model.sr
        print(f"Model loaded! Sample rate: {sample_rate}")
    except Exception as e:
        print(f"Failed on {device}: {e}")
        if device == "cuda":
            print("Retrying on CPU...")
            device = "cpu"
            model = ChatterboxMultilingualTTS.from_pretrained(device=device)
            sample_rate = model.sr
        else:
            raise

    all_audio = []
    pause_tensor = torch.zeros(1, int(PAUSE_SECONDS * sample_rate))

    for i, (speaker, text) in enumerate(turns):
        ref_path = SPEAKER_MAP.get(speaker)
        if not ref_path:
            print(f"WARNING: Unknown speaker '{speaker}', skipping")
            continue

        print(f"\n[{i+1}/{len(turns)}] {speaker}: {text[:60]}...")
        try:
            wav = model.generate(
                text,
                language_id="he",
                audio_prompt_path=ref_path,
                exaggeration=0.5,
                cfg_weight=0.5,
            )
            if wav.dim() == 1:
                wav = wav.unsqueeze(0)
            if wav.dim() == 3:
                wav = wav.squeeze(0)
            wav = wav.cpu()
            print(f"  Generated {wav.shape[-1]/sample_rate:.1f}s")
            all_audio.append(wav)
            all_audio.append(pause_tensor)

        except torch.cuda.OutOfMemoryError:
            print(f"  CUDA OOM! Falling back to CPU...")
            torch.cuda.empty_cache()
            model = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
            sample_rate = model.sr
            pause_tensor = torch.zeros(1, int(PAUSE_SECONDS * sample_rate))
            wav = model.generate(text, language_id="he", audio_prompt_path=ref_path,
                                 exaggeration=0.5, cfg_weight=0.5)
            if wav.dim() == 1: wav = wav.unsqueeze(0)
            if wav.dim() == 3: wav = wav.squeeze(0)
            wav = wav.cpu()
            print(f"  Generated {wav.shape[-1]/sample_rate:.1f}s (CPU)")
            all_audio.append(wav)
            all_audio.append(pause_tensor)
        except Exception as e:
            print(f"  ERROR: {e}")
            continue

    if not all_audio:
        print("No audio generated!")
        sys.exit(1)

    full_audio = torch.cat(all_audio, dim=-1)
    total_dur = full_audio.shape[-1] / sample_rate
    print(f"\nTotal duration: {total_dur:.1f}s ({total_dur/60:.1f} min)")

    import soundfile as sf
    audio_np = full_audio.squeeze(0).numpy()
    sf.write(OUTPUT_WAV, audio_np, sample_rate)
    print(f"Saved WAV: {OUTPUT_WAV}")

    try:
        import imageio_ffmpeg
        from pydub import AudioSegment
        AudioSegment.converter = imageio_ffmpeg.get_ffmpeg_exe()
        audio = AudioSegment.from_wav(OUTPUT_WAV)
        audio.export(OUTPUT_MP3, format="mp3", bitrate="192k")
        print(f"Saved MP3: {OUTPUT_MP3}")
    except Exception as e:
        print(f"MP3 conversion note: {e}")
        print(f"WAV available: {OUTPUT_WAV}")

    print("\n" + "=" * 60)
    print("DONE!")
    print("=" * 60)
    return OUTPUT_MP3 if os.path.exists(OUTPUT_MP3) else OUTPUT_WAV


if __name__ == "__main__":
    result = generate_podcast()
    print(f"\nOutput: {result}")
