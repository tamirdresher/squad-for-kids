#!/usr/bin/env python3

"""
VibeVoice Podcaster — Wrapper for Microsoft's VibeVoice multi-speaker TTS.

VibeVoice (MIT-licensed) supports up to 4 speakers, long-form podcast synthesis
(~90 minutes), and next-token diffusion for expressive, natural-sounding audio.

GitHub:  https://github.com/microsoft/VibeVoice
Model:   https://huggingface.co/microsoft/VibeVoice-1.5B
License: MIT

Requirements:
  - CUDA-compatible GPU (recommended)
  - pip install vibevoice   (or: git clone + pip install -e .)
  - pip install flash-attn --no-build-isolation  (optional, for speed)

Usage:
  python podcaster-vibevoice.py --script article.podcast-script.txt
  python podcaster-vibevoice.py --script script.txt -o my-podcast.wav
  python podcaster-vibevoice.py --check   # verify installation

Integration Status (issue #464):
  VibeVoice is available on GitHub (microsoft/VibeVoice) and has an unofficial
  PyPI package. The official repo availability may fluctuate due to responsible
  AI considerations. This wrapper provides a ready-to-use integration once the
  package is installed. GPU with CUDA is required for inference.
"""

import argparse
import io
import os
import re
import sys
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


def check_vibevoice_available() -> bool:
    """Check if VibeVoice is installed and importable."""
    try:
        import vibevoice  # noqa: F401
        return True
    except ImportError:
        return False


def check_cuda_available() -> bool:
    """Check if CUDA is available for GPU inference."""
    try:
        import torch
        return torch.cuda.is_available()
    except ImportError:
        return False


def parse_script(script_text: str) -> list[dict]:
    """Parse [ALEX]/[SAM] script into speaker turns."""
    turns = []
    for line in script_text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        # Normalise speaker tags
        line = line.replace('[HOST_A]', '[ALEX]').replace('[HOST_B]', '[SAM]')
        m = re.match(r'^\[(ALEX|SAM)\]\s+(.+)$', line)
        if m:
            turns.append({'speaker': m.group(1), 'text': m.group(2).strip()})
    return turns


def render_with_vibevoice(turns: list[dict], output_path: str,
                          model_name: str = "microsoft/VibeVoice-1.5B") -> bool:
    """Render podcast script using VibeVoice multi-speaker TTS.

    Maps ALEX and SAM to distinct VibeVoice speaker IDs for natural
    two-host podcast audio with expressive prosody.
    """
    try:
        import torch
        from vibevoice import VibeVoiceModel
    except ImportError as e:
        print(f"❌ VibeVoice import failed: {e}")
        print("   Install: pip install vibevoice")
        print("   Or: git clone https://github.com/microsoft/VibeVoice && pip install -e .")
        return False

    device = "cuda" if torch.cuda.is_available() else "cpu"
    if device == "cpu":
        print("⚠️  Running on CPU — this will be very slow. GPU recommended.")

    print(f"🔧 Loading VibeVoice model: {model_name} (device: {device})")
    try:
        model = VibeVoiceModel.from_pretrained(model_name)
        model = model.to(device)
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        print("   Try: pip install -U vibevoice transformers")
        return False

    # Map hosts to VibeVoice speaker IDs (0-3 supported)
    speaker_map = {'ALEX': 0, 'SAM': 1}

    # Build the conversation for VibeVoice
    conversation = []
    for turn in turns:
        conversation.append({
            'speaker_id': speaker_map.get(turn['speaker'], 0),
            'text': turn['text'],
        })

    total_words = sum(len(t['text'].split()) for t in turns)
    est_min = round(total_words / 150)
    print(f"📊 Script: {len(turns)} turns, ~{total_words} words (~{est_min} min)")
    print(f"🎙️  Rendering audio with VibeVoice...")

    try:
        audio = model.synthesize_conversation(
            conversation,
            sample_rate=24000,
        )

        # Save to file
        import soundfile as sf
        sf.write(output_path, audio.cpu().numpy(), 24000)
        file_size = os.path.getsize(output_path)
        size_mb = file_size / (1024 * 1024)
        print(f"✅ Podcast rendered: {output_path} ({size_mb:.1f} MB)")
        return True
    except Exception as e:
        print(f"❌ Synthesis failed: {e}")
        return False


def print_installation_guide():
    """Print detailed installation instructions."""
    print("""
╔══════════════════════════════════════════════════════════╗
║           VibeVoice Installation Guide                  ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Option 1 — pip install (if available on PyPI):          ║
║    pip install vibevoice                                 ║
║                                                          ║
║  Option 2 — from source (recommended):                   ║
║    git clone https://github.com/microsoft/VibeVoice.git  ║
║    cd VibeVoice                                          ║
║    pip install -e .                                      ║
║                                                          ║
║  Option 3 — community fork:                              ║
║    git clone https://github.com/vibevoice-community/     ║
║      VibeVoice.git                                       ║
║    cd VibeVoice && pip install -e .                       ║
║                                                          ║
║  Additional deps:                                        ║
║    pip install flash-attn --no-build-isolation            ║
║    pip install soundfile torch transformers               ║
║                                                          ║
║  Requirements:                                           ║
║    • Python 3.9+                                         ║
║    • CUDA-compatible GPU (strongly recommended)          ║
║    • ~4GB VRAM for 1.5B model                            ║
║                                                          ║
║  Model: microsoft/VibeVoice-1.5B (HuggingFace)          ║
║  License: MIT                                            ║
╚══════════════════════════════════════════════════════════╝
""")


def main():
    parser = argparse.ArgumentParser(
        description="VibeVoice Podcaster — Multi-speaker TTS for podcast scripts"
    )
    parser.add_argument("--script", help="Podcast script file ([ALEX]/[SAM] format)")
    parser.add_argument("-o", "--output", help="Output audio file (default: <script>-vibevoice.wav)")
    parser.add_argument("--model", default="microsoft/VibeVoice-1.5B",
                        help="HuggingFace model name (default: microsoft/VibeVoice-1.5B)")
    parser.add_argument("--check", action="store_true",
                        help="Check if VibeVoice is installed and CUDA is available")
    parser.add_argument("--install-guide", action="store_true",
                        help="Print installation instructions")
    args = parser.parse_args()

    if args.install_guide:
        print_installation_guide()
        return

    if args.check:
        print("🔍 Checking VibeVoice installation...\n")
        vv = check_vibevoice_available()
        cuda = check_cuda_available()
        print(f"  VibeVoice package: {'✅ installed' if vv else '❌ not found'}")
        print(f"  CUDA available:    {'✅ yes' if cuda else '❌ no (CPU only — will be slow)'}")
        if not vv:
            print("\n  To install VibeVoice, run: python podcaster-vibevoice.py --install-guide")
        return

    if not args.script:
        parser.print_help()
        print("\n💡 Quick start:")
        print("  python podcaster-vibevoice.py --check          # verify setup")
        print("  python podcaster-vibevoice.py --install-guide  # installation help")
        print("  python podcaster-vibevoice.py --script my-script.podcast-script.txt")
        sys.exit(1)

    script_path = Path(args.script).resolve()
    if not script_path.exists():
        print(f"❌ Script file not found: {script_path}")
        sys.exit(1)

    output_path = args.output or str(script_path.with_suffix('.vibevoice.wav'))

    print("🎙️  VibeVoice Podcaster")
    print(f"📄 Script: {script_path}")
    print(f"🔊 Output: {output_path}")
    print(f"🤖 Model:  {args.model}\n")

    if not check_vibevoice_available():
        print("❌ VibeVoice is not installed.")
        print("   Run: python podcaster-vibevoice.py --install-guide")
        sys.exit(1)

    # Parse script
    raw = script_path.read_text(encoding='utf-8')
    turns = parse_script(raw)
    if not turns:
        print("❌ No dialogue turns found. Expected [ALEX]/[SAM] format.")
        sys.exit(1)

    # Render
    ok = render_with_vibevoice(turns, output_path, model_name=args.model)
    if not ok:
        sys.exit(1)

    print(f"\n✅ Done! Podcast ready: {output_path}")


if __name__ == "__main__":
    main()
