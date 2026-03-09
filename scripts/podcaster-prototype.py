#!/usr/bin/env python3

"""
Podcaster Prototype - Issue #214
Converts markdown files to audio using edge-tts
"""

import asyncio
import re
import sys
import os
from pathlib import Path
import edge_tts

def strip_markdown(markdown):
    """Strip markdown formatting to plain text"""
    text = markdown
    
    # Remove YAML frontmatter
    text = re.sub(r'^---\n[\s\S]*?\n---\n', '', text, flags=re.MULTILINE)
    
    # Remove HTML comments
    text = re.sub(r'<!--[\s\S]*?-->', '', text)
    
    # Remove code blocks
    text = re.sub(r'```[\s\S]*?```', '', text)
    text = re.sub(r'`[^`]+`', '', text)
    
    # Remove images but keep alt text
    text = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', text)
    
    # Remove links but keep text
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    
    # Remove headers but keep text
    text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
    
    # Remove bold/italic
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
    text = re.sub(r'\*([^*]+)\*', r'\1', text)
    text = re.sub(r'__([^_]+)__', r'\1', text)
    text = re.sub(r'_([^_]+)_', r'\1', text)
    
    # Remove horizontal rules
    text = re.sub(r'^[-*_]{3,}\s*$', '', text, flags=re.MULTILINE)
    
    # Remove blockquotes
    text = re.sub(r'^>\s+', '', text, flags=re.MULTILINE)
    
    # Remove list markers
    text = re.sub(r'^[\*\-\+]\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\d+\.\s+', '', text, flags=re.MULTILINE)
    
    # Clean up multiple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # Trim whitespace
    text = text.strip()
    
    return text

def format_bytes(bytes_size):
    """Format file size"""
    if bytes_size < 1024:
        return f"{bytes_size} B"
    elif bytes_size < 1024 * 1024:
        return f"{bytes_size / 1024:.2f} KB"
    else:
        return f"{bytes_size / (1024 * 1024):.2f} MB"

def estimate_duration(text):
    """Estimate audio duration (rough: ~150 words per minute)"""
    words = len(text.split())
    minutes = words / 150
    seconds = round(minutes * 60)
    
    if seconds < 60:
        return f"{seconds}s"
    mins = seconds // 60
    secs = seconds % 60
    return f"{mins}m {secs}s"

async def main():
    if len(sys.argv) < 2:
        print("Usage: python podcaster-prototype.py <markdown-file>")
        print("Example: python podcaster-prototype.py RESEARCH_REPORT.md")
        sys.exit(1)
    
    input_path = Path(sys.argv[1]).resolve()
    input_filename = input_path.stem
    output_path = Path(f"{input_filename}-audio.mp3").resolve()
    
    print("🎙️  Podcaster Prototype - Issue #214\n")
    print(f"📄 Input: {input_path}")
    print(f"🔊 Output: {output_path}\n")
    
    try:
        # Read markdown file
        print("📖 Reading markdown file...")
        with open(input_path, 'r', encoding='utf-8') as f:
            markdown = f.read()
        print(f"   Markdown size: {format_bytes(len(markdown.encode('utf-8')))}")
        
        # Strip markdown formatting
        print("🔧 Stripping markdown formatting...")
        plain_text = strip_markdown(markdown)
        print(f"   Plain text size: {format_bytes(len(plain_text.encode('utf-8')))}")
        print(f"   Estimated duration: {estimate_duration(plain_text)}")
        
        # Convert to speech
        print("🎤 Converting to speech (using edge-tts)...")
        import time
        start_time = time.time()
        
        # Use Jenny Neural voice (professional female voice)
        communicate = edge_tts.Communicate(plain_text, "en-US-JennyNeural")
        await communicate.save(str(output_path))
        
        end_time = time.time()
        conversion_time = end_time - start_time
        
        # Get output file stats
        file_size = output_path.stat().st_size
        
        print(f"✅ Conversion complete in {conversion_time:.2f}s")
        print(f"\n📊 Results:")
        print(f"   Audio file: {output_path}")
        print(f"   File size: {format_bytes(file_size)}")
        print(f"   Format: MP3")
        print(f"   Voice: en-US-JennyNeural (Microsoft Neural TTS)")
        print(f"   Quality: Neural (production-grade)")
        print(f"\n✨ Success! Audio file generated.")
        
    except FileNotFoundError:
        print(f"\n❌ Error: File not found: {input_path}")
        sys.exit(1)
    except Exception as error:
        print(f"\n❌ Error: {error}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
