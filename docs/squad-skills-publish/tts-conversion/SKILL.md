---
name: tts-conversion
description: "Convert markdown documents to audio using Text-to-Speech for accessibility, briefings, and audio summaries. Use when documents need audio versions."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Podcaster agent implementation patterns
---

# TTS Document Conversion

**Convert markdown documents to audio** using Text-to-Speech. Produces accessible audio versions of reports, documentation, and briefings.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `convert to audio`, `text to speech` | HIGH — Direct request |
| `generate podcast`, `audio summary` | HIGH — Content production |
| `read aloud`, `tts` | MEDIUM — Quick conversion |
| `podcast generation` | MEDIUM — Batch production |

---

## When to Use

- Generate audio versions of research reports
- Create podcast-style summaries of documentation
- Provide accessibility alternatives for visual content
- Produce briefing audio for executive summaries
- Batch-convert documentation for audio consumption

## When Not to Use

- Real-time voice interaction (use speech-to-text instead)
- Music or sound effect generation
- Transcription (speech-to-text is the reverse)

---

## Technology Options

### Option A: edge-tts (Free, Recommended for MVP)

**Pros:** Free, high-quality neural voices, no API key needed
**Cons:** Cloud-dependent, rate limits on high volume

```bash
pip install edge-tts
```

```python
import edge_tts
import asyncio

async def convert(text, output_file, voice="en-US-JennyNeural"):
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(output_file)

asyncio.run(convert("Hello world", "output.mp3"))
```

**Popular voices:**
| Voice | Language | Style |
|-------|----------|-------|
| `en-US-JennyNeural` | English (US) | Conversational |
| `en-US-GuyNeural` | English (US) | Narrative |
| `en-GB-SoniaNeural` | English (UK) | Professional |
| `en-US-AriaNeural` | English (US) | Friendly |

### Option B: Azure AI Speech (Production)

**Pros:** Enterprise SLA, custom voices, higher rate limits
**Cons:** Requires Azure subscription and API key

```bash
pip install azure-cognitiveservices-speech
```

```python
import azure.cognitiveservices.speech as speechsdk

def convert(text, output_file):
    config = speechsdk.SpeechConfig(
        subscription=os.environ["AZURE_SPEECH_KEY"],
        region=os.environ["AZURE_SPEECH_REGION"]
    )
    config.speech_synthesis_voice_name = "en-US-JennyNeural"
    config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoMp3
    )
    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=config,
        audio_config=speechsdk.audio.AudioOutputConfig(filename=output_file)
    )
    synthesizer.speak_text_async(text).get()
```

### Option C: Other TTS Engines

Any TTS engine that accepts plaintext input works. The skill's value is in the **markdown-to-plaintext pipeline**, not the TTS engine.

---

## Conversion Pipeline

### Step 1: Strip Markdown to Plaintext

Remove formatting that sounds unnatural when spoken:

```python
import re

def markdown_to_plaintext(md_text):
    text = md_text

    # Remove YAML frontmatter
    text = re.sub(r'^---\n.*?\n---\n', '', text, flags=re.DOTALL)

    # Remove code blocks
    text = re.sub(r'```[\s\S]*?```', '[code block omitted]', text)

    # Remove inline code
    text = re.sub(r'`[^`]+`', '', text)

    # Remove images
    text = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', text)

    # Convert links to text only
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)

    # Remove headers markers but keep text
    text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)

    # Remove bold/italic markers
    text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
    text = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', text)

    # Remove horizontal rules
    text = re.sub(r'^[-*_]{3,}\s*$', '', text, flags=re.MULTILINE)

    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)

    # Normalize whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()
```

### Step 2: Generate Audio

```python
async def convert_document(md_file, voice="en-US-JennyNeural"):
    with open(md_file, 'r', encoding='utf-8') as f:
        md_text = f.read()

    plaintext = markdown_to_plaintext(md_text)
    output_file = md_file.replace('.md', '-audio.mp3')

    communicate = edge_tts.Communicate(plaintext, voice)
    await communicate.save(output_file)

    return output_file
```

### Step 3: Verify Output

```python
import os

def verify_audio(output_file):
    size = os.path.getsize(output_file)
    if size < 1000:
        raise ValueError(f"Audio file too small ({size} bytes) — likely empty")
    print(f"✅ Generated {output_file} ({size / 1024:.1f} KB)")
```

---

## Batch Conversion

```bash
# Convert all markdown files in a directory
for file in *.md; do
    python convert.py "$file"
done
```

---

## Key Learnings

1. **Python over Node.js**: Python TTS libraries are more mature and stable
2. **Regex stripping is sufficient**: No need for complex markdown parsers in most cases
3. **Network dependency**: Cloud-based TTS requires stable internet
4. **Neural voice quality**: Free-tier neural voices produce production-grade output
5. **Graceful degradation**: Always handle TTS failures without blocking workflows
6. **Caching**: Cache audio for documents that don't change frequently

---

## See Also

- [Voice Writing](../voice-writing/) — Maintain consistent writing voice for content
- [News Broadcasting](../news-broadcasting/) — Deliver content via team channels
