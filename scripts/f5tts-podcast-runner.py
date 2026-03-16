#!/usr/bin/env python3
"""
F5-TTS Voice-Cloned Hebrew Podcast Runner
==========================================
Patches F5-TTS safetensors loading to use tensor-by-tensor CUDA loading,
working around Windows paging file limits on low-memory systems.

Then runs the full voice-clone-podcast.py pipeline with F5-TTS backend.
"""
import os
import sys
import gc

# Force UTF-8
if sys.stdout.encoding != 'utf-8':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    import io
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


def patch_safetensors_loading():
    """
    Monkey-patch safetensors.torch.load_file to load tensors one-by-one.
    This avoids the "paging file too small" error on Windows when the model
    file is larger than available virtual memory.
    """
    import safetensors.torch
    original_load_file = safetensors.torch.load_file

    def memory_efficient_load_file(filename, device="cpu"):
        from safetensors import safe_open
        state_dict = {}
        with safe_open(filename, framework="pt", device=str(device)) as f:
            for key in f.keys():
                state_dict[key] = f.get_tensor(key)
        return state_dict

    safetensors.torch.load_file = memory_efficient_load_file
    print("  ✅ Patched safetensors.torch.load_file for memory-efficient loading")


def setup_ffmpeg_path():
    """Add imageio-ffmpeg binary to PATH so Whisper/transformers can find it."""
    try:
        import imageio_ffmpeg
        ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
        ffmpeg_dir = os.path.dirname(ffmpeg_path)
        # Also create a symlink/copy named 'ffmpeg.exe' if the binary has a different name
        import shutil
        ffmpeg_standard = os.path.join(ffmpeg_dir, "ffmpeg.exe")
        if not os.path.exists(ffmpeg_standard):
            shutil.copy2(ffmpeg_path, ffmpeg_standard)
        os.environ["PATH"] = ffmpeg_dir + os.pathsep + os.environ.get("PATH", "")
        print(f"  ✅ Added ffmpeg to PATH: {ffmpeg_dir}")
    except ImportError:
        print("  ⚠ imageio-ffmpeg not installed, ffmpeg may not be available")


def patch_torchaudio_load():
    """
    Monkey-patch torchaudio.load to use soundfile backend.
    torchaudio 2.10+ forces torchcodec which may have broken DLLs on Windows.
    """
    import torch
    import torchaudio
    import soundfile

    def soundfile_load(uri, frame_offset=0, num_frames=-1, normalize=True,
                       channels_first=True, format=None, buffer_size=4096, backend=None):
        data, sr = soundfile.read(str(uri), dtype='float32',
                                  start=frame_offset,
                                  stop=frame_offset + num_frames if num_frames > 0 else None)
        waveform = torch.from_numpy(data)
        if waveform.dim() == 1:
            waveform = waveform.unsqueeze(0)
        elif channels_first:
            waveform = waveform.T
        return waveform, sr

    torchaudio.load = soundfile_load
    print("  ✅ Patched torchaudio.load to use soundfile backend")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="F5-TTS Voice-Cloned Hebrew Podcast Runner")
    parser.add_argument("script", help="Hebrew podcast script file (.script.txt)")
    parser.add_argument("--ref-avri", required=True, help="Reference audio for AVRI/Dotan voice")
    parser.add_argument("--ref-hila", required=True, help="Reference audio for HILA/Shahar voice")
    parser.add_argument("-o", "--output", default="hebrew-podcast-f5tts.mp3", help="Output file")
    parser.add_argument("--test-clip", type=int, help="Only render first N turns")
    args = parser.parse_args()

    print("🔧 Applying memory-efficient safetensors patch...")
    patch_safetensors_loading()
    setup_ffmpeg_path()
    patch_torchaudio_load()

    print("🎙️  Starting F5-TTS voice-cloned podcast generation...")
    print(f"   Script:   {args.script}")
    print(f"   Ref AVRI: {args.ref_avri}")
    print(f"   Ref HILA: {args.ref_hila}")
    print(f"   Output:   {args.output}")
    if args.test_clip:
        print(f"   Test clip: first {args.test_clip} turns")

    # Import after patching
    import asyncio
    from pathlib import Path

    # Add scripts dir to path so we can import the main module
    scripts_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, scripts_dir)

    # Import the voice-clone-podcast module
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "voice_clone_podcast",
        os.path.join(scripts_dir, "voice-clone-podcast.py")
    )
    vcp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vcp)

    # Parse script
    script_path = Path(args.script).resolve()
    raw = script_path.read_text(encoding="utf-8")
    turns = vcp.parse_script(raw)
    if not turns:
        print("✗ No turns found in script!")
        sys.exit(1)

    ref_samples = {
        "AVRI": Path(args.ref_avri).resolve(),
        "HILA": Path(args.ref_hila).resolve(),
    }

    output_path = Path(args.output).resolve()

    asyncio.run(vcp.render_podcast(
        turns, output_path,
        backend="f5tts",
        ref_samples=ref_samples,
        test_clip=args.test_clip,
    ))


if __name__ == "__main__":
    main()
