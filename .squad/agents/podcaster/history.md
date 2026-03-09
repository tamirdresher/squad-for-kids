# Podcaster Agent History

## Creation
- **Date:** Issue #214 implementation
- **Purpose:** Audio summaries of research, briefings, and reports
- **Implementation:** Python prototype using edge-tts

## Learnings

### Initial Setup (Issue #214)
- Prototype successfully implemented in `scripts/podcaster-prototype.py`
- edge-tts library (v7.2.7) provides production-quality neural voices without Azure setup
- en-US-JennyNeural voice selected for professional female narration
- Markdown stripping logic handles: YAML frontmatter, code blocks, HTML comments, links, images, formatting
- Test results: EXECUTIVE_SUMMARY.md (14.52 KB) → 3.91 MB MP3 in 31.68s, ~6m 8s duration
- Free tier is sufficient for MVP; consider Azure AI Speech Service for production scale

### Technical Stack
- **Runtime:** Python 3.12+
- **TTS Engine:** edge-tts 7.2.7 (Microsoft Edge TTS)
- **Output Format:** MP3, neural-quality audio
- **Speech Rate:** ~150 words per minute
- **Voice Profile:** en-US-JennyNeural (professional, clear, natural intonation)

### Architecture Decisions
1. **edge-tts over Azure AI Speech** — Free tier, zero setup, production-grade quality for MVP
2. **Python over Node.js** — edge-tts npm package has TypeScript compatibility issues
3. **Markdown stripping** — Comprehensive regex-based approach removes all formatting artifacts
4. **Synchronous processing** — Async/await pattern for TTS conversion, blocking for user feedback

### Key Files
- `scripts/podcaster-prototype.py` — Main prototype implementation
- `PODCASTER_README.md` — Comprehensive prototype documentation
- `.squad/agents/podcaster/charter.md` — Agent charter and responsibilities
- `.squad/agents/podcaster/history.md` — This file

## Next Steps
- Test with additional document types (reports, briefings, etc.)
- Add configuration file for voice selection and audio parameters
- Implement batch processing for multiple documents
- Consider Azure AI Speech Service migration path for scale
- Add audio caching to avoid regeneration
- Create API endpoint for on-demand conversion
