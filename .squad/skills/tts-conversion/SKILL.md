# TTS Document Conversion Skill

## Purpose

Convert markdown documents to audio using Text-to-Speech for accessibility, briefings, and audio summaries.

## When to Use

- Generate audio versions of research reports
- Create podcast-style summaries of documentation
- Provide accessibility alternatives for visual content
- Produce briefing audio for executive summaries

## Technology

**MVP (Current):**
- Python 3.12+ with edge-tts library (v7.2.7)
- Microsoft Edge TTS service (free tier)
- Neural voice: en-US-JennyNeural
- Output format: MP3

**Production (Future):**
- Azure AI Speech Service
- Enhanced customization (voice, rate, pitch, volume)
- Higher rate limits
- Enterprise support and SLAs

## Usage Pattern

### Basic Conversion
```bash
python scripts/podcaster-prototype.py <markdown-file>
```

**Example:**
```bash
python scripts/podcaster-prototype.py RESEARCH_REPORT.md
# Output: RESEARCH_REPORT-audio.mp3
```

### Architecture

**Post-processing pipeline:**
- Document → Plain text → TTS → MP3 file
- Not real-time agent (batch/on-demand)
- Caching recommended for frequently accessed documents

## Installation

```bash
pip install edge-tts
```

## Key Learnings

1. **Python over Node.js**: edge-tts npm package has TypeScript compatibility issues
2. **Regex stripping sufficient**: No need for complex markdown parsers in MVP
3. **Network dependency**: Cloud-based TTS requires stable internet
4. **Neural quality excellent**: Free tier provides production-grade voices
5. **Migration path clear**: Architecture supports Azure AI Speech upgrade

## References

- Issue #214: Podcaster agent implementation
- PR #224: Working prototype
- PODCASTER_README.md: Detailed documentation

---

**Status:** MVP complete, ready for stakeholder review.
