# Decision: F5-TTS Voice Cloning Integration

**Date:** 2026-03-13  
**Decision Maker:** Data (Code Expert)  
**Context:** Issue #465 — Hebrew podcast voice cloning support  
**Status:** Implemented

## Decision

Integrated F5-TTS as a voice cloning backend for Hebrew podcast generation in `voice-clone-podcast.py`.

## Context

Tamir requested Hebrew podcast support copying the style of מפתחים מחוץ לקופסא. The team approved F5-TTS (free, open-source zero-shot voice cloning) as the solution.

**Requirements:**
- Free, open-source solution (no API costs)
- Hebrew language support
- Voice cloning from reference audio
- Integration with existing podcast pipeline

## Options Considered

| Backend | Pros | Cons | Decision |
|---------|------|------|----------|
| **F5-TTS** | Free, zero-shot cloning, multilingual | Experimental Hebrew, GPU recommended | ✅ **Selected** |
| **ElevenLabs** | Best quality, native Hebrew | Paid API ($$$) | Already supported |
| **OpenVoice** | Open-source, tone color conversion | Complex setup, limited Hebrew | Not implemented |
| **edge-tts** | Fast, free, native Hebrew | No voice cloning | Already supported |

## Implementation Approach

### Backend Architecture

Added F5-TTS following the established backend pattern:

```python
async def generate_f5tts(text, speaker, output_wav, ref_audio=None):
    """
    Generate voice-cloned audio using F5-TTS.
    - Requires reference audio (10-30s samples)
    - Auto-downloads model (~500MB) on first use
    - Supports GPU (CUDA/MPS) and CPU modes
    """
```

### Integration Points

1. **Backend Selection:**
   - Priority: F5-TTS → ElevenLabs → edge-tts
   - Graceful fallback if dependencies missing
   - `--f5tts` flag for easy selection

2. **Reference Audio:**
   - Required for F5-TTS (10-30s per speaker)
   - `--ref-avri` and `--ref-hila` flags
   - Quality check via `--analyze-ref`

3. **Validation:**
   - Test suite (`test-f5tts-integration.py`)
   - Documentation (setup + examples)
   - Test clip generation (`--test-clip`)

## Technical Details

### Dependencies

```bash
pip install f5-tts torch torchaudio
```

- **f5-tts:** Zero-shot TTS model
- **torch:** Deep learning framework
- **torchaudio:** Audio I/O

### Performance

| Platform | Speed | Notes |
|----------|-------|-------|
| NVIDIA GPU (8GB+) | 30-60s per audio minute | Recommended |
| Apple M1/M2/M3 | 1-2 min per audio minute | Good for local use |
| CPU | 5-10 min per audio minute | Works but slow |

### Model Details

- **Checkpoint:** ~500MB (auto-downloaded)
- **Architecture:** Diffusion-based TTS
- **Languages:** Multilingual (Hebrew experimental)
- **License:** Apache 2.0

## Trade-offs

### Advantages
✅ Free and open-source (no API costs)  
✅ Zero-shot cloning (10-30s reference audio)  
✅ Supports Hebrew experimentally  
✅ High-quality synthesis  
✅ Local inference (privacy)  

### Limitations
⚠️ GPU recommended for production use  
⚠️ Hebrew support experimental (not native)  
⚠️ First run downloads ~500MB model  
⚠️ Requires reference audio (can't work without)  

## Documentation

Created comprehensive documentation:

1. **Setup Guide** (`docs/F5-TTS-SETUP.md`):
   - Installation instructions
   - Hardware requirements
   - Troubleshooting

2. **Quick Start** (`docs/F5-TTS-EXAMPLE.md`):
   - Usage examples
   - Reference audio guidelines
   - מפתחים מחוץ לקופסא style tips

3. **Test Suite** (`scripts/test-f5tts-integration.py`):
   - Dependency verification
   - Integration tests
   - GPU/CPU detection

## Validation

- ✅ Code integrated into `voice-clone-podcast.py`
- ✅ Test suite created and runnable
- ✅ Documentation complete
- ✅ Branch pushed: `squad/465-hebrew-f5tts-voiceclone`
- ✅ Commit: `545a5cea`

## Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Hebrew quality issues | Test clips before full generation; fallback to ElevenLabs if needed |
| Slow CPU performance | Document GPU requirement; provide cloud GPU options |
| Dependency installation | Comprehensive setup guide; test script validates install |
| Model download failure | Document caching behavior; retry mechanism in F5-TTS |

## Future Considerations

1. **Hebrew Fine-tuning:**
   - May need Hebrew-specific training data
   - Consider contributing to F5-TTS project

2. **Batch Processing:**
   - Optimize for long podcasts
   - Consider GPU memory management

3. **Reference Audio Library:**
   - Build curated reference samples
   - Document quality criteria

## References

- F5-TTS GitHub: https://github.com/SWivid/F5-TTS
- F5-TTS Paper: https://arxiv.org/abs/2410.06885
- Issue #465: Hebrew podcast support
- מפתחים מחוץ לקופסא: Approved usage

## Related Decisions

- Backend architecture established in original `voice-clone-podcast.py`
- Edge-tts Hebrew support (existing)
- ElevenLabs integration (existing)

---

**Approval:** Free option approved by Tamir; מפתחים מחוץ לקופסא team gave permission for voice style matching.
