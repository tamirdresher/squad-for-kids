# F5-TTS Voice Cloning Setup for Hebrew Podcasts

## Overview

F5-TTS is a free, open-source zero-shot voice cloning system that can replicate a speaker's voice from just 10-30 seconds of reference audio. It's approved by the מפתחים מחוץ לקופסא podcast team for voice cloning.

**Key Features:**
- ✅ **Free & Open Source** — No API costs
- ✅ **Zero-shot** — Works with just 10-30s reference audio
- ✅ **Multilingual** — Supports Hebrew, English, and many other languages
- ✅ **High Quality** — Natural-sounding speech synthesis
- ⚠️ **GPU Recommended** — Works on CPU but slower

## Installation

### 1. Install PyTorch

F5-TTS requires PyTorch. Install the version for your hardware:

**NVIDIA GPU (CUDA):**
```bash
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118
```

**AMD GPU (ROCm):**
```bash
pip install torch torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
```

**Apple Silicon (MPS):**
```bash
pip install torch torchaudio
```

**CPU Only:**
```bash
pip install torch torchaudio
```

### 2. Install F5-TTS

```bash
pip install f5-tts
```

### 3. Verify Installation

```bash
python -c "from f5_tts.api import F5TTS; print('F5-TTS installed successfully')"
```

**First Run:** The model checkpoint (~500MB) will be downloaded automatically on first use.

## Hardware Requirements

| Setup | Speed | Notes |
|-------|-------|-------|
| **NVIDIA GPU (8GB+ VRAM)** | Fast (30-60s per minute of audio) | Recommended |
| **Apple M1/M2/M3** | Medium (1-2 min per minute of audio) | Good for local use |
| **CPU** | Slow (5-10 min per minute of audio) | Works but not practical for long podcasts |

## Usage

### Basic Usage

```bash
python scripts/voice-clone-podcast.py hebrew-podcast.script.txt \
  --f5tts \
  --ref-avri avri_reference.wav \
  --ref-hila hila_reference.wav \
  -o output.mp3
```

### With Test Clip

Test with just the first 6 turns to verify voice quality:

```bash
python scripts/voice-clone-podcast.py script.txt \
  --f5tts \
  --ref-avri avri_reference.wav \
  --ref-hila hila_reference.wav \
  --test-clip 6 \
  -o test_clip.mp3
```

## Reference Audio Guidelines

For best results, your reference audio should:

1. **Duration:** 10-30 seconds
   - Too short (<10s): May not capture voice characteristics
   - Too long (>30s): Doesn't improve quality, slows processing

2. **Quality:**
   - Clear speech without background noise
   - Single speaker only
   - No music or sound effects
   - Good audio quality (not compressed/distorted)

3. **Content:**
   - Natural conversational speech
   - Varied intonation (not monotone)
   - Hebrew language preferred (for Hebrew TTS)

### Preparing Reference Audio

If you have a longer recording, extract a clean 15-20 second segment:

```bash
# Using ffmpeg
ffmpeg -i input.mp3 -ss 00:00:05 -t 00:00:15 -acodec copy reference.mp3
```

Or use the analyze tool to check voice characteristics:

```bash
python scripts/voice-clone-podcast.py --analyze-ref your_reference.wav
```

## Comparison: F5-TTS vs Other Backends

| Backend | Quality | Cost | Setup | Speed | Hebrew Support |
|---------|---------|------|-------|-------|----------------|
| **F5-TTS** | ⭐⭐⭐⭐ | Free | Medium | Medium | ✅ Experimental |
| **ElevenLabs** | ⭐⭐⭐⭐⭐ | $$ API | Easy | Fast | ✅ Native |
| **edge-tts + style** | ⭐⭐⭐ | Free | Easy | Fast | ✅ Native |

**When to use F5-TTS:**
- You want free voice cloning
- You have good reference audio (10-30s samples)
- You have GPU available for reasonable speed
- You want to match a specific voice style (like מפתחים מחוץ לקופסא)

**When to use alternatives:**
- **ElevenLabs:** Maximum quality, willing to pay
- **edge-tts:** Quick testing, no reference audio available

## Troubleshooting

### "F5-TTS not installed"
```bash
pip install f5-tts torch torchaudio
```

### "CUDA out of memory"
- Reduce text length (split into smaller segments)
- Use CPU instead: `export CUDA_VISIBLE_DEVICES=-1` (Linux/Mac)
- Upgrade GPU memory

### "Model download fails"
- Check internet connection
- The model is ~500MB, ensure you have space
- Try again (downloads are cached, won't re-download)

### "Generated audio is silent or garbled"
- Check reference audio quality (use --analyze-ref)
- Try different reference audio (10-30s segment)
- Verify PyTorch GPU support: `python -c "import torch; print(torch.cuda.is_available())"`

### "Too slow on CPU"
- Consider using edge-tts backend for faster generation
- Or rent a cloud GPU (Colab, RunPod, etc.)

## Advanced: Hebrew Language Tuning

While F5-TTS supports Hebrew experimentally, quality may vary. For best results:

1. **Use Hebrew reference audio** — The model learns voice AND language patterns
2. **Keep text natural** — Hebrew text should be properly formatted with nikud if needed
3. **Test first** — Always generate a test clip before full podcast

If quality is poor, consider:
- Trying different reference audio samples
- Using ElevenLabs for critical production work
- Fine-tuning F5-TTS on Hebrew dataset (advanced)

## Integration with Squad Workflow

The F5-TTS backend is fully integrated into the voice-clone-podcast.py script:

```python
# Backend selection priority:
# 1. F5-TTS (if --f5tts and reference audio provided)
# 2. ElevenLabs (if --elevenlabs-key provided)
# 3. edge-tts + style (fallback default)
```

This ensures graceful degradation if dependencies aren't available.

## License & Credits

- **F5-TTS:** Apache 2.0 License (https://github.com/SWivid/F5-TTS)
- **מפתחים מחוץ לקופסא:** Approved use for voice style matching
- **Integration:** Data (Tamir's squad) — Issue #465

## References

- F5-TTS GitHub: https://github.com/SWivid/F5-TTS
- F5-TTS Paper: https://arxiv.org/abs/2410.06885
- PyPI Package: https://pypi.org/project/f5-tts/
