#!/usr/bin/env python3

"""
Conversational Podcaster - Issue #237
Converts markdown to two-voice conversational podcast using edge-tts
"""

import asyncio
import re
import sys
import os
from pathlib import Path
import edge_tts
import tempfile

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

def parse_sections(markdown):
    """Parse markdown into sections by headers"""
    sections = []
    
    # Find all headers and their content
    lines = markdown.split('\n')
    current_section = {'title': None, 'content': []}
    
    for line in lines:
        header_match = re.match(r'^(#{1,6})\s+(.+)$', line)
        if header_match:
            # Save previous section if it has content
            if current_section['title'] or current_section['content']:
                sections.append(current_section)
            # Start new section
            current_section = {
                'title': header_match.group(2).strip(),
                'level': len(header_match.group(1)),
                'content': []
            }
        else:
            current_section['content'].append(line)
    
    # Add last section
    if current_section['title'] or current_section['content']:
        sections.append(current_section)
    
    return sections

def generate_conversational_script(sections, doc_title):
    """Generate conversational script between HOST and EXPERT"""
    script = []
    
    # Introduction
    script.append({
        'speaker': 'HOST',
        'text': f"Welcome to the Squad Briefing. I'm your host, and today we're diving into {doc_title}. I'm joined by our expert who's going to walk us through the key findings. Let's get started!"
    })
    
    script.append({
        'speaker': 'EXPERT',
        'text': "Thanks for having me! I'm excited to share what we've discovered."
    })
    
    # Process each section
    for i, section in enumerate(sections):
        if not section.get('title'):
            continue
            
        title = section['title']
        content = '\n'.join(section['content']).strip()
        
        if not content:
            continue
        
        # Strip markdown from content
        content_plain = strip_markdown(content)
        
        if not content_plain:
            continue
        
        # Host introduces the section
        if i == 0:
            host_intro = f"Let's start with {title}. What can you tell us about this?"
        elif i == len(sections) - 1:
            host_intro = f"Finally, let's talk about {title}. What should our listeners know?"
        else:
            host_intro = f"Interesting! Now, what about {title}?"
        
        script.append({
            'speaker': 'HOST',
            'text': host_intro
        })
        
        # Expert presents the content
        # Split long content into smaller chunks for more natural flow
        sentences = re.split(r'(?<=[.!?])\s+', content_plain)
        chunks = []
        current_chunk = []
        word_count = 0
        
        for sentence in sentences:
            sentence_words = len(sentence.split())
            if word_count + sentence_words > 100 and current_chunk:
                chunks.append(' '.join(current_chunk))
                current_chunk = [sentence]
                word_count = sentence_words
            else:
                current_chunk.append(sentence)
                word_count += sentence_words
        
        if current_chunk:
            chunks.append(' '.join(current_chunk))
        
        # Add expert responses with occasional host interjections
        for j, chunk in enumerate(chunks):
            script.append({
                'speaker': 'EXPERT',
                'text': chunk
            })
            
            # Add host interjections occasionally
            if j < len(chunks) - 1 and len(chunks) > 2:
                if j == len(chunks) // 2:
                    script.append({
                        'speaker': 'HOST',
                        'text': "That's really insightful. Please continue."
                    })
    
    # Conclusion
    script.append({
        'speaker': 'HOST',
        'text': "This has been incredibly informative. Any final thoughts before we wrap up?"
    })
    
    script.append({
        'speaker': 'EXPERT',
        'text': "Just that this work represents a significant step forward, and I'm excited to see where it leads."
    })
    
    script.append({
        'speaker': 'HOST',
        'text': "That wraps up today's Squad Briefing. Thanks for listening, and we'll catch you in the next episode!"
    })
    
    return script

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

async def generate_audio_segment(text, voice, output_path, max_retries=3):
    """Generate audio for a single segment with retry logic"""
    for attempt in range(max_retries):
        try:
            communicate = edge_tts.Communicate(text, voice)
            await communicate.save(str(output_path))
            return
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"\n   ⚠️  Retry {attempt + 1}/{max_retries - 1} after error: {str(e)[:50]}...")
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
            else:
                raise

async def main():
    if len(sys.argv) < 2:
        print("Usage: python podcaster-conversational.py <markdown-file>")
        print("Example: python podcaster-conversational.py EXECUTIVE_SUMMARY.md")
        sys.exit(1)
    
    input_path = Path(sys.argv[1]).resolve()
    input_filename = input_path.stem
    output_path = Path(f"{input_filename}-conversational.mp3").resolve()
    
    print("🎙️  Conversational Podcaster - Issue #237\n")
    print(f"📄 Input: {input_path}")
    print(f"🔊 Output: {output_path}\n")
    
    try:
        # Read markdown file
        print("📖 Reading markdown file...")
        with open(input_path, 'r', encoding='utf-8') as f:
            markdown = f.read()
        print(f"   Markdown size: {format_bytes(len(markdown.encode('utf-8')))}")
        
        # Extract document title (first H1)
        title_match = re.search(r'^#\s+(.+)$', markdown, flags=re.MULTILINE)
        doc_title = title_match.group(1) if title_match else input_filename.replace('-', ' ').replace('_', ' ')
        
        # Parse into sections
        print("🔧 Parsing document sections...")
        sections = parse_sections(markdown)
        print(f"   Found {len(sections)} sections")
        
        # Generate conversational script
        print("💬 Generating conversational script...")
        script = generate_conversational_script(sections, doc_title)
        print(f"   Generated {len(script)} dialogue turns")
        
        # Calculate total word count
        total_words = sum(len(turn['text'].split()) for turn in script)
        print(f"   Total words: {total_words}")
        print(f"   Estimated duration: {estimate_duration(' '.join(turn['text'] for turn in script))}")
        
        # Generate audio segments
        print("\n🎤 Generating audio segments...")
        import time
        start_time = time.time()
        
        # Voice configuration
        voices = {
            'HOST': 'en-US-JennyNeural',    # Female, professional
            'EXPERT': 'en-US-GuyNeural'      # Male, authoritative
        }
        
        # Create temporary directory for segments
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            segment_files = []
            
            for i, turn in enumerate(script):
                speaker = turn['speaker']
                text = turn['text']
                voice = voices[speaker]
                segment_path = temp_path / f"segment_{i:03d}_{speaker}.mp3"
                
                print(f"   [{i+1}/{len(script)}] {speaker}: {text[:50]}...")
                await generate_audio_segment(text, voice, segment_path)
                segment_files.append(segment_path)
            
            # Concatenate segments
            print("\n🔗 Concatenating audio segments...")
            
            # Try using pydub if available and ffmpeg is present
            use_pydub = False
            try:
                from pydub import AudioSegment
                # Test if ffmpeg is available
                test_audio = AudioSegment.from_mp3(str(segment_files[0]))
                use_pydub = True
            except (ImportError, FileNotFoundError):
                use_pydub = False
            
            if use_pydub:
                try:
                    combined = AudioSegment.empty()
                    pause = AudioSegment.silent(duration=400)  # 400ms pause between speakers
                    
                    for segment_file in segment_files:
                        audio = AudioSegment.from_mp3(str(segment_file))
                        combined += audio + pause
                    
                    combined.export(str(output_path), format="mp3")
                    print("   Using pydub for high-quality concatenation")
                except Exception as e:
                    print(f"   pydub failed: {str(e)[:80]}, falling back to simple concatenation")
                    use_pydub = False
            
            if not use_pydub:
                # Fallback: simple binary concatenation (works for MP3)
                print("   Using simple concatenation (pydub/ffmpeg not available)")
                with open(output_path, 'wb') as outfile:
                    for segment_file in segment_files:
                        with open(segment_file, 'rb') as infile:
                            outfile.write(infile.read())
        
        end_time = time.time()
        conversion_time = end_time - start_time
        
        # Get output file stats
        file_size = output_path.stat().st_size
        
        print(f"\n✅ Conversion complete in {conversion_time:.2f}s")
        print(f"\n📊 Results:")
        print(f"   Audio file: {output_path}")
        print(f"   File size: {format_bytes(file_size)}")
        print(f"   Format: MP3")
        print(f"   Voices: HOST (en-US-JennyNeural) + EXPERT (en-US-GuyNeural)")
        print(f"   Dialogue turns: {len(script)}")
        print(f"   Quality: Neural (production-grade)")
        print(f"\n✨ Success! Conversational podcast generated.")
        
    except FileNotFoundError:
        print(f"\n❌ Error: File not found: {input_path}")
        sys.exit(1)
    except Exception as error:
        print(f"\n❌ Error: {error}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
