# ✍️ Voice Writing

Maintain consistent writing voice and style across AI-generated content. Ensures all content sounds like the same author.

## What It Does

- **Voice profiles** — Define author-specific tone, style, and rules
- **Consistency checks** — Verify content matches the voice profile before publishing
- **Content adaptation** — Adjust voice for different content types (blog, docs, social)
- **Series continuity** — Maintain callbacks and themes across content series
- **Sensitive content handling** — Sanitize internal references automatically

## Trigger Phrases

- `write in voice`, `match voice`
- `writing style`, `content voice`
- `author voice`, `tone matching`

## Quick Start

### Prerequisites

- Voice profile configuration (`voice-profile.json`)
- Reference material (published content that exemplifies the author's voice)

### Example Usage

```
User: "Write this technical update in my blog voice"
Agent: [Loads voice profile, applies rules: first-person, conversational, story-driven]
Agent: [Produces content matching author's established tone and style]
```

## Voice Profile

```json
{
  "author": "Your Name",
  "rules": {
    "perspective": "first-person",
    "tone": "conversational, technically deep",
    "humor": "natural, domain-specific",
    "avoid": ["corporate speak", "generic hype"]
  }
}
```

## Style Checklist

- [ ] Flowing prose over bullet points
- [ ] First-person perspective
- [ ] Natural humor (not forced)
- [ ] Story-driven technical content
- [ ] Real tool names and versions
- [ ] Honest about what worked and didn't

## See Also

- [Blog Publishing](../blog-publishing/) — Publish voice-matched content
- [TTS Conversion](../tts-conversion/) — Convert to audio
- [Reflect](../reflect/) — Capture voice feedback for improvement
