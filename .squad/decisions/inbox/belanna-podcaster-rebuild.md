# Decision: Podcaster v2 — Conversational Podcast Architecture

**Date:** 2026-06-27
**Author:** B'Elanna (Infrastructure/DevOps)
**Status:** ✅ Implemented

## Decision

Rebuild the podcaster into a three-phase pipeline that separates **conversation script generation** from **TTS rendering**, enabling real two-host dialogue podcasts from any markdown input.

## Context

The original podcaster (`podcaster.ps1` + `podcaster-conversational.py`) read articles aloud using one or two voices, but there was no actual conversation. It sounded like someone reading a document, not like a podcast discussion. Tamir requested a rebuild to produce output resembling .NET Rocks or NotebookLM-style podcasts.

## Architecture

### Phase 1: Script Generation (`generate-podcast-script.py`)
- Converts articles into [ALEX]/[SAM] tagged dialogue
- **LLM backends** (tried in order): Azure OpenAI → OpenAI → built-in template engine
- Template engine works without any API keys for zero-config usage
- Output is a plain text `.podcast-script.txt` file

### Phase 2: TTS Rendering (`podcaster-conversational.py` v2)
- Parses [ALEX]/[SAM]/[HOST_A]/[HOST_B] tagged scripts
- Distinct neural voices: en-US-GuyNeural (Alex) + en-US-JennyNeural (Sam)
- Rate variation between speakers for natural feel
- Backward-compatible legacy mode preserved

### Phase 3: Pipeline (`podcaster.ps1 -PodcastMode`)
- Chains Phase 1 → Phase 2 automatically
- `-ScriptFile` parameter to skip generation with pre-made scripts

## Key Decisions

1. **Separation of script generation from TTS** — allows manual editing of conversation scripts before rendering, and decouples LLM dependency from audio pipeline
2. **Template engine fallback** — ensures podcasts can always be generated even without LLM API keys
3. **[ALEX]/[SAM] tagged format** — simple, parseable, human-editable dialogue format
4. **edge-tts neural voices** — free, high-quality, no API key needed; sufficient for v1

## Future Improvements

- LLM-generated scripts will be dramatically better than template output
- ffmpeg installation for proper pause insertion between turns
- Musical intro/outro if ffmpeg available
- More voice variety (en-US-AriaNeural, en-US-DavisNeural)
