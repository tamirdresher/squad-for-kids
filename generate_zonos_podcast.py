"""
Generate Hebrew podcast using Zonos-Hebrew TTS with voice cloning.
Uses dotan_ref.wav for AVRI speaker and shahar_ref.wav for HILA speaker.
"""
import os
import sys
import re
import time

# Set espeak-ng paths before any imports that might need it
os.environ["PHONEMIZER_ESPEAK_LIBRARY"] = r"C:\temp\espeak-ng\eSpeak NG\libespeak-ng.dll"
os.environ["ESPEAK_DATA_PATH"] = r"C:\temp\espeak-ng\eSpeak NG"
os.environ["PATH"] = r"C:\temp\espeak-ng\eSpeak NG" + ";" + os.environ.get("PATH", "")

sys.path.insert(0, r"C:\temp\tamresearch1\Zonos-Hebrew")

import torch
import torchaudio
from zonos.model import Zonos
from zonos.conditioning import make_cond_dict

# Paths
SCRIPT_FILE = r"C:\temp\tamresearch1\hebrew-cloned-podcast.script.txt"
AVRI_REF = r"C:\temp\tamresearch1\voice_samples\dotan_ref.wav"
HILA_REF = r"C:\temp\tamresearch1\voice_samples\shahar_ref.wav"
OUTPUT_DIR = r"C:\temp\tamresearch1\zonos_output"
FINAL_OUTPUT = r"C:\temp\tamresearch1\hebrew-podcast-zonos.wav"

# Check VRAM
if torch.cuda.is_available():
    vram_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"GPU: {torch.cuda.get_device_name(0)}, VRAM: {vram_gb:.1f} GB")
    device = "cuda" if vram_gb >= 3.5 else "cpu"
else:
    device = "cpu"
print(f"Using device: {device}")

# Parse script
def parse_script(filepath):
    """Parse the Hebrew dialogue script into (speaker, text) tuples."""
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

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Parse dialogue
    turns = parse_script(SCRIPT_FILE)
    print(f"Parsed {len(turns)} dialogue turns")

    # Load model - try GPU first, fall back to CPU
    # Use Zyphra transformer model (compatible with Windows, no mamba-ssm needed)
    # with Hebrew phonemization from the Zonos-Hebrew conditioning code (phonikud)
    REPO_ID = "Zyphra/Zonos-v0.1-transformer"
    print(f"Loading Zonos model from {REPO_ID}...")
    try:
        model = Zonos.from_pretrained(REPO_ID, device=device)
        print(f"Model loaded on {device}")
    except RuntimeError as e:
        if "CUDA" in str(e) or "memory" in str(e).lower():
            print(f"GPU failed ({e}), falling back to CPU...")
            model = Zonos.from_pretrained(REPO_ID, device="cpu")
            print("Model loaded on CPU")
        else:
            raise

    # Create speaker embeddings
    print("Creating speaker embeddings...")
    avri_wav, avri_sr = torchaudio.load(AVRI_REF)
    hila_wav, hila_sr = torchaudio.load(HILA_REF)
    
    avri_speaker = model.make_speaker_embedding(avri_wav, avri_sr)
    hila_speaker = model.make_speaker_embedding(hila_wav, hila_sr)
    print("Speaker embeddings created")

    # Generate each turn
    generated_files = []
    for i, (speaker, text) in enumerate(turns):
        turn_file = os.path.join(OUTPUT_DIR, f"turn_{i:03d}_{speaker}.wav")
        
        # Skip if already generated (resume support)
        if os.path.exists(turn_file):
            print(f"[{i+1}/{len(turns)}] Skipping {speaker} (already exists)")
            generated_files.append(turn_file)
            continue
            
        speaker_emb = avri_speaker if speaker == "AVRI" else hila_speaker
        
        print(f"[{i+1}/{len(turns)}] Generating {speaker}: {text[:50]}...")
        start_time = time.time()

        try:
            torch.manual_seed(42 + i)
            
            cond_dict = make_cond_dict(
                text=text,
                speaker=speaker_emb,
                language="he",
                speaking_rate=13.0,  # Slightly faster for conversational tone
                pitch_std=25.0,      # More expressive pitch
                emotion=[0.35, 0.02, 0.02, 0.02, 0.02, 0.02, 0.25, 0.30],  # Neutral/pleasant
                device=model.device,
            )
            conditioning = model.prepare_conditioning(cond_dict)
            codes = model.generate(conditioning, progress_bar=False, disable_torch_compile=True)
            wavs = model.autoencoder.decode(codes).cpu()
            torchaudio.save(turn_file, wavs[0], model.autoencoder.sampling_rate)
            
            elapsed = time.time() - start_time
            print(f"    Done in {elapsed:.1f}s")
            generated_files.append(turn_file)
            
            # Clear GPU cache between turns
            if device == "cuda":
                torch.cuda.empty_cache()
                
        except RuntimeError as e:
            if "memory" in str(e).lower() or "CUDA" in str(e):
                print(f"    GPU OOM on turn {i+1}, switching to CPU for remaining turns...")
                model = model.cpu()
                torch.cuda.empty_cache()
                
                torch.manual_seed(42 + i)
                cond_dict = make_cond_dict(
                    text=text,
                    speaker=speaker_emb.cpu(),
                    language="he",
                    speaking_rate=13.0,
                    pitch_std=25.0,
                    emotion=[0.35, 0.02, 0.02, 0.02, 0.02, 0.02, 0.25, 0.30],
                    device="cpu",
                )
                conditioning = model.prepare_conditioning(cond_dict)
                codes = model.generate(conditioning, progress_bar=False, disable_torch_compile=True)
                wavs = model.autoencoder.decode(codes).cpu()
                torchaudio.save(turn_file, wavs[0], model.autoencoder.sampling_rate)
                generated_files.append(turn_file)
            else:
                print(f"    ERROR: {e}")
                raise

    # Concatenate all turns with short pauses
    print("\nConcatenating all turns...")
    sample_rate = model.autoencoder.sampling_rate
    silence_duration = int(0.5 * sample_rate)  # 0.5s pause between turns
    
    all_audio = []
    for f in generated_files:
        wav, sr = torchaudio.load(f)
        if sr != sample_rate:
            resampler = torchaudio.transforms.Resample(sr, sample_rate)
            wav = resampler(wav)
        all_audio.append(wav)
        # Add silence between turns
        silence = torch.zeros(1, silence_duration)
        all_audio.append(silence)
    
    if all_audio:
        # Remove trailing silence
        all_audio = all_audio[:-1]
        full_audio = torch.cat(all_audio, dim=1)
        torchaudio.save(FINAL_OUTPUT, full_audio, sample_rate)
        print(f"\nSaved concatenated podcast to: {FINAL_OUTPUT}")
        duration_sec = full_audio.shape[1] / sample_rate
        print(f"Total duration: {duration_sec/60:.1f} minutes ({duration_sec:.0f}s)")
    
    # Convert to MP3
    try:
        from pydub import AudioSegment
        mp3_output = FINAL_OUTPUT.replace(".wav", ".mp3")
        audio = AudioSegment.from_wav(FINAL_OUTPUT)
        audio.export(mp3_output, format="mp3", bitrate="192k")
        print(f"MP3 saved to: {mp3_output}")
    except Exception as e:
        print(f"MP3 conversion failed (pydub/ffmpeg needed): {e}")
        print("WAV output is still available.")

    print("\nDone!")

if __name__ == "__main__":
    main()
