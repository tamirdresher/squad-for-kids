# Podcaster - Audio Content Generation

## Overview

The Podcaster system converts markdown documents into audio summaries using Microsoft Edge's Text-to-Speech (TTS) service. Two modes are available:

1. **Single-voice mode** - Direct narration with one professional voice
2. **Conversational mode** - NotebookLM-style two-voice dialogue

## Features

- ✅ Automatic markdown formatting removal
- ✅ Neural-quality voice synthesis
- ✅ MP3 audio output
- ✅ No Azure setup or API keys required
- ✅ Two-voice conversational dialogues
- ✅ Automatic retry logic for network stability

## Installation

### Prerequisites

```bash
# Install Python 3.12 or higher
python --version

# Install required packages
pip install edge-tts pydub
```

**Optional:** Install ffmpeg for high-quality audio concatenation in conversational mode (not required, falls back to binary concatenation).

## Usage

### Single-Voice Mode

Convert a markdown document to audio with a single narrator:

```bash
python scripts/podcaster-prototype.py DOCUMENT.md
```

**Output:** Creates `DOCUMENT-audio.mp3` in the current directory.

**Voice:** en-US-JennyNeural (professional female narrator)

### Conversational Mode (NotebookLM-style)

Convert a markdown document to a two-voice conversational podcast:

```bash
python scripts/podcaster-conversational.py DOCUMENT.md
```

**Output:** Creates `DOCUMENT-conversational.mp3` in the current directory.

**Voices:**
- **HOST:** en-US-JennyNeural (female, curious, engaging)
- **EXPERT:** en-US-GuyNeural (male, authoritative, informative)

### How Conversational Mode Works

1. Parses markdown document into sections by headers
2. Generates natural conversational script:
   - HOST introduces each section with questions
   - EXPERT explains content in accessible language
   - HOST adds interjections for flow and engagement
3. Generates audio segments for each dialogue turn
4. Concatenates segments with natural pauses (400ms)
5. Outputs single MP3 file with complete podcast

## Audio Storage

**Important:** Generated audio files should NOT be committed to Git. Store them in cloud storage instead.

### Upload Scripts

**PowerShell (Windows):**
```powershell
.\scripts\upload-podcast.ps1 -FilePath "DOCUMENT-audio.mp3"
```

**Python (Cross-platform):**
```bash
python scripts/upload-podcast.py DOCUMENT-audio.mp3
```

### Upload Methods

1. **OneDrive Sync Folder** (Default, Simplest)
   - Copies file to `~/OneDrive/Squad/Podcasts/`
   - Works immediately if OneDrive is syncing
   - Get shareable link: Right-click file → Share

2. **Microsoft Graph API** (Proper API Integration)
   - Direct upload via Graph API with automatic sharing link
   - Requires Azure AD app registration
   - Set environment variables: `GRAPH_CLIENT_ID`, `GRAPH_CLIENT_SECRET`, `GRAPH_TENANT_ID`

3. **Azure Blob Storage** (Azure-Native)
   - Upload to Azure Storage account
   - Requires Azure CLI (`az login`)
   - Generates SAS URL valid for 90 days

### .gitignore Configuration

Audio files are automatically excluded from Git:
```
# Generated audio files — stored in cloud
*-audio.mp3
*-audio.wav
*.mp3
*.wav
```

## Example Workflow

1. Generate podcast:
   ```bash
   python scripts/podcaster-conversational.py RESEARCH_REPORT.md
   ```

2. Upload to cloud:
   ```powershell
   .\scripts\upload-podcast.ps1 -FilePath "RESEARCH_REPORT-conversational.mp3"
   ```

3. Share the OneDrive/Azure link with stakeholders

4. File remains local for playback but is NOT committed to Git

## Technical Details

### Markdown Processing

The system automatically removes:
- YAML frontmatter
- HTML comments
- Code blocks and inline code
- Images (keeps alt text)
- Links (keeps link text)
- Headers (keeps text)
- Bold/italic formatting
- Horizontal rules
- Blockquotes
- List markers

### Voice Quality

Both modes use Microsoft Neural TTS voices with production-grade quality:
- Speech rate: ~150 words per minute
- Output format: MP3
- Bitrate: Neural quality (variable)

### Error Handling

- Automatic retry logic for network timeouts
- Clear user feedback during conversion
- Graceful degradation (binary concatenation if ffmpeg unavailable)

## Performance Metrics

Example conversion (EXECUTIVE_SUMMARY.md):
- **Input:** 14.52 KB markdown
- **Processed:** 6.72 KB plain text
- **Duration:** 6 minutes 8 seconds
- **Output:** 3.94 MB MP3

Conversational mode (QUICK_REFERENCE.md):
- **Input:** 7.56 KB markdown
- **Output:** 3.94 MB MP3, 63 dialogue turns
- **Duration:** ~6 minutes
- **Conversion time:** 350 seconds (includes retries)

## Limitations

1. **Network dependency:** Requires internet connection to Microsoft Edge TTS service
2. **Rate limits:** Free tier has unspecified rate limits (use Azure for production scale)
3. **Voice selection:** Hardcoded to specific voices (can be made configurable)
4. **Language:** English only (en-US voices)

## Future Enhancements

1. **Configuration file** - Voice selection, rate, pitch, volume customization
2. **Batch processing** - Convert multiple files in one command
3. **Voice profiles** - Different voices for different document types
4. **Progress tracking** - Real-time conversion status with progress bar
5. **Azure migration** - Azure AI Speech Service for production scale
6. **API endpoint** - REST API for on-demand conversion
7. **Caching** - Store generated audio to avoid regeneration
8. **Multi-language support** - Additional language voices

## Files

- `scripts/podcaster-prototype.py` - Single-voice narrator mode
- `scripts/podcaster-conversational.py` - Two-voice conversational mode
- `scripts/upload-podcast.ps1` - PowerShell upload script
- `scripts/upload-podcast.py` - Python upload script (cross-platform)

## Troubleshooting

### Network Timeouts

If you see network timeout errors, the script will automatically retry. The conversational mode includes built-in retry logic.

### Audio Quality Issues

If audio quality is poor or choppy:
1. Check your internet connection stability
2. Install ffmpeg for better audio concatenation (conversational mode)
3. Consider using Azure AI Speech Service for production workloads

### Missing Dependencies

If you see import errors:
```bash
pip install --upgrade edge-tts pydub
```

## Production Deployment

For production use:
1. Migrate to Azure AI Speech Service for better rate limits and reliability
2. Implement caching to avoid regenerating the same content
3. Add queue-based processing for batch conversions
4. Set up monitoring and alerting for conversion failures
5. Consider CDN distribution for generated audio files

## Support

For issues, questions, or feature requests, create an issue with the `squad:podcaster` label.
