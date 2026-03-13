#!/usr/bin/env python3

"""
Conversational Podcaster v2 - Multi-voice TTS renderer
Renders [ALEX]/[SAM] podcast scripts OR markdown files into two-voice audio.

Modes:
  1. Script mode (--script): Renders a pre-generated .podcast-script.txt
  2. Legacy mode: Reads markdown, generates template conversation, renders audio

Usage:
  python podcaster-conversational.py --script article.podcast-script.txt
  python podcaster-conversational.py article.md
  python podcaster-conversational.py --script script.txt -o my-podcast.mp3
"""

import asyncio
import argparse
import io
import os
import random
import re
import sys
import time
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    import edge_tts
except ImportError:
    print("edge-tts not installed. Run: pip install edge-tts")
    sys.exit(1)

import tempfile


def strip_markdown(markdown):
    text = markdown
    text = re.sub(r'^---\n[\s\S]*?\n---\n', '', text, flags=re.MULTILINE)
    text = re.sub(r'<!--[\s\S]*?-->', '', text)
    text = re.sub(r'```[\s\S]*?```', '', text)
    text = re.sub(r'`[^`]+`', '', text)
    text = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
    text = re.sub(r'\*([^*]+)\*', r'\1', text)
    text = re.sub(r'__([^_]+)__', r'\1', text)
    text = re.sub(r'_([^_]+)_', r'\1', text)
    text = re.sub(r'^[-*_]{3,}\s*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'^>\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'^[\*\-\+]\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\d+\.\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def parse_podcast_script(script_text):
    turns = []
    script_text = script_text.replace('[HOST_A]', '[ALEX]').replace('[HOST_B]', '[SAM]')
    script_text = script_text.replace('[HOST]', '[ALEX]').replace('[EXPERT]', '[SAM]')
    for line in script_text.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r'^\[(ALEX|SAM)\]\s*(.+)$', line)
        if m:
            turns.append({'speaker': m.group(1), 'text': m.group(2).strip()})
    return turns


def generate_legacy_script(markdown):
    script_gen = Path(__file__).parent / "generate-podcast-script.py"
    if script_gen.exists():
        import importlib.util
        spec = importlib.util.spec_from_file_location("gen", str(script_gen))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        title = mod.extract_title(markdown, "article")
        raw = mod.generate_template_script(markdown, title)
        return parse_podcast_script(raw)

    plain = strip_markdown(markdown)
    title_m = re.search(r'^#\s+(.+)$', markdown, re.MULTILINE)
    title = title_m.group(1) if title_m else "this topic"
    turns = [
        {'speaker': 'ALEX', 'text': f'Hey everyone! Today we are covering {title}.'},
        {'speaker': 'SAM', 'text': 'Let me walk you through the highlights.'},
    ]
    sentences = re.split(r'(?<=[.!?])\s+', plain)
    chunk, wc, chunks = [], 0, []
    for s in sentences:
        sw = len(s.split())
        if wc + sw > 80 and chunk:
            chunks.append(' '.join(chunk)); chunk, wc = [s], sw
        else:
            chunk.append(s); wc += sw
    if chunk: chunks.append(' '.join(chunk))
    for i, c in enumerate(chunks):
        turns.append({'speaker': 'SAM', 'text': c})
        if i < len(chunks) - 1 and i % 3 == 1:
            turns.append({'speaker': 'ALEX', 'text': 'Interesting, keep going.'})
    turns.append({'speaker': 'ALEX', 'text': 'Thanks for listening!'})
    return turns


def format_bytes(size):
    if size < 1024: return f"{size} B"
    elif size < 1024 * 1024: return f"{size / 1024:.1f} KB"
    return f"{size / (1024 * 1024):.1f} MB"


async def generate_audio_segment(text, voice, output_path, rate="+0%", volume="+0%", max_retries=3):
    for attempt in range(max_retries):
        try:
            comm = edge_tts.Communicate(text, voice, rate=rate, volume=volume)
            await comm.save(str(output_path))
            return True
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"   Retry {attempt + 1}: {str(e)[:60]}...")
                await asyncio.sleep(2 ** attempt)
            else:
                print(f"   Failed: {e}")
                return False


async def render_podcast(turns, output_path, voice_alex, voice_sam, rate, volume):
    total_words = sum(len(t['text'].split()) for t in turns)
    est_min = round(total_words / 150)
    print(f"Dialogue: {len(turns)} turns, ~{total_words} words (~{est_min} min)")

    voices = {'ALEX': voice_alex, 'SAM': voice_sam}
    rate_offsets = {'ALEX': "+2%", 'SAM': "-1%"} if rate == "+0%" else {'ALEX': rate, 'SAM': rate}

    start_time = time.time()
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        segment_files = []
        for i, turn in enumerate(turns):
            speaker = turn['speaker']
            text = turn['text']
            voice = voices.get(speaker, voice_alex)
            seg_rate = rate_offsets.get(speaker, rate)
            seg_path = tmp / f"seg_{i:04d}_{speaker}.mp3"
            preview = text[:55] + ("..." if len(text) > 55 else "")
            print(f"  [{i+1}/{len(turns)}] {speaker}: {preview}")
            ok = await generate_audio_segment(text, voice, seg_path, rate=seg_rate, volume=volume)
            if ok:
                segment_files.append((seg_path, speaker))

        if not segment_files:
            print("No segments generated!"); sys.exit(1)

        print(f"\nConcatenating {len(segment_files)} segments...")
        concatenated = False
        try:
            from pydub import AudioSegment
            combined = AudioSegment.empty()
            prev_speaker = None
            for seg_path, speaker in segment_files:
                audio = AudioSegment.from_mp3(str(seg_path))
                if prev_speaker is not None:
                    pause_ms = random.randint(300, 500) if speaker != prev_speaker else random.randint(150, 250)
                    combined += AudioSegment.silent(duration=pause_ms)
                combined += audio
                prev_speaker = speaker
            combined.export(str(output_path), format="mp3", bitrate="192k")
            concatenated = True
            print("  High-quality concatenation with natural pauses")
        except Exception as e:
            print(f"  pydub/ffmpeg unavailable, using binary concatenation")

        if not concatenated:
            with open(output_path, 'wb') as out:
                for seg_path, _ in segment_files:
                    with open(seg_path, 'rb') as inp:
                        out.write(inp.read())
            print("  Binary concatenation complete")

    elapsed = time.time() - start_time
    file_size = output_path.stat().st_size
    print(f"\nPodcast rendered in {elapsed:.1f}s")
    print(f"   File: {output_path}")
    print(f"   Size: {format_bytes(file_size)}")
    print(f"   Voices: Alex ({voice_alex}) + Sam ({voice_sam})")
    print(f"   Turns: {len(turns)}")


async def main():
    parser = argparse.ArgumentParser(description="Conversational Podcaster v2")
    parser.add_argument("input_file", nargs='?', help="Markdown file (legacy mode)")
    parser.add_argument("--script", help="Pre-generated podcast script ([ALEX]/[SAM] format)")
    parser.add_argument("-o", "--output", help="Output MP3 path")
    parser.add_argument("--rate", default="+0%", help="Base speech rate")
    parser.add_argument("--volume", default="+0%", help="Volume adjustment")
    parser.add_argument("--alex-voice", default="en-US-GuyNeural", help="Voice for Alex")
    parser.add_argument("--sam-voice", default="en-US-JennyNeural", help="Voice for Sam")
    parser.add_argument("--host-voice", help="(Legacy) alias for --alex-voice")
    parser.add_argument("--expert-voice", help="(Legacy) alias for --sam-voice")
    args = parser.parse_args()

    alex_voice = args.host_voice or args.alex_voice
    sam_voice = args.expert_voice or args.sam_voice

    if args.script:
        script_path = Path(args.script).resolve()
        if not script_path.exists():
            print(f"Script file not found: {script_path}"); sys.exit(1)
        stem = script_path.stem.replace('.podcast-script', '')
        output_path = Path(args.output).resolve() if args.output else script_path.parent / f"{stem}-podcast.mp3"
        print(f"Conversational Podcaster v2 - Script Mode")
        print(f"Script: {script_path}")
        print(f"Output: {output_path}")
        print(f"Voices: Alex ({alex_voice}) + Sam ({sam_voice})\n")
        raw = script_path.read_text(encoding='utf-8')
        turns = parse_podcast_script(raw)
        if not turns:
            print("No dialogue turns found. Expected [ALEX]/[SAM] format."); sys.exit(1)

    elif args.input_file:
        input_path = Path(args.input_file).resolve()
        if not input_path.exists():
            print(f"File not found: {input_path}"); sys.exit(1)
        output_path = Path(args.output).resolve() if args.output else input_path.with_name(f"{input_path.stem}-podcast.mp3")
        print(f"Conversational Podcaster v2 - Legacy Mode")
        print(f"Input:  {input_path}")
        print(f"Output: {output_path}")
        print(f"Voices: Alex ({alex_voice}) + Sam ({sam_voice})\n")
        markdown = input_path.read_text(encoding='utf-8')
        print("Generating conversation from markdown...")
        turns = generate_legacy_script(markdown)
    else:
        parser.print_help(); sys.exit(1)

    await render_podcast(turns, output_path, alex_voice, sam_voice, args.rate, args.volume)
    print(f"\nDone! Podcast ready: {output_path}")


if __name__ == "__main__":
    asyncio.run(main())
