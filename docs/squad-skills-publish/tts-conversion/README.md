# 🎙️ TTS Document Conversion

Convert markdown documents to audio using Text-to-Speech. Produces accessible audio versions of reports, documentation, and briefings.

## What It Does

- **Markdown → Audio** — Strip formatting and convert to spoken audio
- **Multiple engines** — Support for edge-tts (free) and Azure AI Speech (production)
- **Batch conversion** — Process multiple documents at once
- **Configurable voices** — Choose voice, rate, pitch, and language

## Trigger Phrases

- `convert to audio`, `text to speech`
- `generate podcast`, `audio summary`
- `read aloud`, `tts`

## Quick Start

### Prerequisites

```bash
pip install edge-tts
```

### Example Usage

```
User: "Convert RESEARCH_REPORT.md to audio"
Agent: [Strips markdown → generates TTS → saves MP3]
Agent: "✅ Generated RESEARCH_REPORT-audio.mp3 (245 KB)"
```

## Technology Options

| Engine | Cost | Quality | Setup |
|--------|------|---------|-------|
| edge-tts | Free | High (neural) | `pip install edge-tts` |
| Azure AI Speech | Pay-per-use | Highest | Azure subscription + API key |
| Other TTS | Varies | Varies | Engine-specific |

## Pipeline

1. Read markdown document
2. Strip formatting to plaintext (regex-based)
3. Send to TTS engine
4. Save as MP3
5. Verify output file size

## See Also

- [Voice Writing](../voice-writing/) — Create content worth converting to audio
- [News Broadcasting](../news-broadcasting/) — Deliver content via channels
