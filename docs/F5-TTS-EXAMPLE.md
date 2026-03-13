# F5-TTS Hebrew Podcast Example

This example shows how to use F5-TTS to generate Hebrew podcasts with voice cloning.

## Quick Start

### 1. Install Dependencies

```bash
# Install PyTorch (choose your platform)
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118  # NVIDIA GPU
# or
pip install torch torchaudio  # Apple Silicon / CPU

# Install F5-TTS
pip install f5-tts
```

### 2. Prepare Reference Audio

You need 10-30 second voice samples for each speaker. Extract clean segments:

```bash
# Example: Extract 15 seconds from minute 1:30
ffmpeg -i full_podcast.mp3 -ss 00:01:30 -t 00:00:15 -acodec copy avri_reference.mp3
```

### 3. Create Podcast Script

Create a script file with `[SPEAKER]` tags (e.g., `my-podcast.script.txt`):

```
[AVRI] שלום לכולם! ברוכים הבאים לפרק חדש של הפודקאסט שלנו.

[HILA] היי אברי! אני מאוד נרגשת לדבר היום על בינה מלאכותית.

[AVRI] אז בואי נתחיל. מה הדבר הכי מעניין שקרה השבוע?

[HILA] יש המון! בעיקר ההתפתחויות ב-AI agents...
```

### 4. Generate Podcast

```bash
python scripts/voice-clone-podcast.py my-podcast.script.txt \
  --f5tts \
  --ref-avri avri_reference.mp3 \
  --ref-hila hila_reference.mp3 \
  -o my-podcast.mp3
```

### 5. Test First

Always test with a short clip before generating the full podcast:

```bash
python scripts/voice-clone-podcast.py my-podcast.script.txt \
  --f5tts \
  --ref-avri avri_reference.mp3 \
  --ref-hila hila_reference.mp3 \
  --test-clip 4 \
  -o test.mp3
```

Listen to `test.mp3` to verify voice quality before committing to the full generation.

## מפתחים מחוץ לקופסא Style

To match the מפתחים מחוץ לקופסא podcast style:

1. **Use their podcast as reference:**
   - Extract clean 15-20s segments of each host
   - Avoid intro/outro music
   - Choose segments with clear, natural speech

2. **Script formatting:**
   - Keep turns conversational (not too long)
   - Natural Hebrew phrasing
   - Use proper punctuation for pauses

3. **Quality check:**
   - Generate test clips first
   - Verify voice similarity
   - Adjust reference audio if needed

## Tips for Best Results

### Reference Audio Quality
- ✅ Clear single-speaker audio
- ✅ No background noise/music
- ✅ Natural conversational tone
- ✅ 15-20 seconds is ideal
- ❌ Avoid compressed/low-quality audio
- ❌ Avoid shouting or extreme emotions

### Script Writing
- Keep turns 2-4 sentences each
- Use natural Hebrew phrasing
- Add punctuation for natural pauses
- Test with --test-clip first

### Performance
- **GPU:** 30-60s per minute of audio
- **CPU:** 5-10 min per minute of audio
- First run downloads ~500MB model

## Troubleshooting

### "F5-TTS not installed"
```bash
pip install f5-tts torch torchaudio
```

### Slow Generation
- Use GPU if available
- Reduce script length (test clips)
- Consider cloud GPU (Google Colab, RunPod)

### Poor Voice Quality
- Check reference audio (use --analyze-ref)
- Try different 15-20s segment
- Ensure single speaker in reference
- Verify Hebrew text formatting

### Out of Memory
- Reduce text length per turn
- Use CPU mode (slower but works)
- Close other applications

## Next Steps

- See [F5-TTS-SETUP.md](../docs/F5-TTS-SETUP.md) for detailed setup
- Run `python scripts/test-f5tts-integration.py` to verify installation
- Check [voice-clone-podcast.py](../scripts/voice-clone-podcast.py) for all options

## Related Files

- `scripts/voice-clone-podcast.py` — Main podcast generator
- `scripts/test-f5tts-integration.py` — Test F5-TTS installation
- `docs/F5-TTS-SETUP.md` — Detailed setup guide
- `scripts/podcaster-conversational.py` — Alternative podcast tools
