---
name: voice-writing
description: "Maintain consistent writing voice and style across AI-generated content. Use when creating content that must match a specific author's voice."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Content voice consistency patterns
---

# Voice Writing

**Maintain a consistent author voice** across all AI-generated content. Ensures blog posts, documentation, and communications sound like they were written by the same person, every time.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `write in voice`, `match voice` | HIGH — Active content creation |
| `writing style`, `content voice` | MEDIUM — Style guidance |
| `author voice`, `tone matching` | MEDIUM — Consistency check |

---

## Voice Profile

Every author's voice can be captured in a structured profile. Create one per author:

### `voice-profile.json`

```json
{
  "author": "Your Name",
  "voice_id": "author-name",
  "reference_material": [
    "https://your-blog.com/best-post",
    "docs/voice-samples/sample-1.md"
  ],
  "rules": {
    "perspective": "first-person",
    "tone": "conversational, technically deep",
    "humor": "natural, self-deprecating, domain-specific",
    "structure": "story-driven with technical depth",
    "avoid": ["corporate speak", "generic hype language", "bullet-point-heavy sections"],
    "include": ["personal anecdotes", "real tool names", "honest observations"]
  },
  "style_guide": {
    "paragraphs_over_bullets": true,
    "use_first_person": true,
    "max_consecutive_bullets": 5,
    "code_examples": "real and runnable",
    "links": "inline, not footnotes"
  }
}
```

---

## Voice Matching Rules

### Core Principles

1. **Read reference material** as the gold standard for tone
2. **Conversational and personal** — like talking to a friend who knows the domain
3. **Humor should be natural** — not forced, not corporate. Domain-specific wit works best.
4. **Structure is story-driven** — start with a hook, build narrative, land the point
5. **Avoid corporate speak** — no "synergize", "leverage", "paradigm shift"
6. **Include real details** — tool names, version numbers, genuine observations

### Writing Style Checklist

- [ ] Written in flowing prose — paragraphs over bullet points
- [ ] Uses first-person perspective ("I", "my team", "we")
- [ ] Genuinely funny — not forced, not corporate
- [ ] Technical content is accessible and story-driven
- [ ] Includes personal anecdotes or observations
- [ ] Uses real tool/product names (not generic placeholders)
- [ ] Honest about what worked and what didn't

---

## Content Type Adaptations

| Content Type | Tone Shift | Structure |
|--------------|-----------|-----------|
| Blog post | Most personal, story-driven | Hook → narrative → technical → takeaway |
| Documentation | More structured, still conversational | Overview → details → examples → gotchas |
| Social media | Punchy, witty | One-liner or thread format |
| Email/comms | Professional but warm | Context → ask → next steps |
| Presentation | Engaging, visual-first | Slides: one idea per slide, speaker notes conversational |

---

## Voice Consistency Checks

Before publishing, verify content matches the voice profile:

### Automated Checks

```python
def check_voice_consistency(content, voice_profile):
    issues = []

    # Check perspective
    if voice_profile["rules"]["perspective"] == "first-person":
        if "the author" in content.lower() or "one might" in content.lower():
            issues.append("Use first-person ('I', 'we') instead of third-person")

    # Check for avoided terms
    for term in voice_profile["rules"]["avoid"]:
        if term.lower() in content.lower():
            issues.append(f"Avoid: '{term}' found in content")

    # Check bullet density
    lines = content.split('\n')
    bullet_streak = 0
    max_bullets = voice_profile["style_guide"].get("max_consecutive_bullets", 5)
    for line in lines:
        if line.strip().startswith(('- ', '* ', '• ')):
            bullet_streak += 1
            if bullet_streak > max_bullets:
                issues.append(f"Too many consecutive bullets ({bullet_streak}). Convert to prose.")
        else:
            bullet_streak = 0

    return issues
```

### Manual Review Checklist

1. Read the content aloud — does it sound like the author?
2. Compare opening paragraph to reference material
3. Check humor tone — is it natural or forced?
4. Verify no "avoid" terms slipped through
5. Confirm technical accuracy with real tool names

---

## Series Continuity

When writing a content series (blog series, documentation chapters):

1. **Follow series continuity** — each piece references and builds on previous pieces
2. **Study revision history** — understand what the author liked/disliked in past edits
3. **Before writing**: read ALL existing published pieces to internalize voice
4. **Maintain running themes** — callbacks to earlier posts create engagement
5. **Evolve naturally** — voice can mature but shouldn't suddenly change

---

## Sensitive Content

When the author's workplace or projects have confidentiality requirements:

1. **Never mention** specific internal project names unless cleared
2. **Use generic descriptions** — "my team's infrastructure platform" instead of specific names
3. **Check with the author** before referencing internal tools or processes
4. **Sanitize examples** — use realistic but fictional data in code samples

---

## See Also

- [Blog Publishing](../blog-publishing/) — Publish voice-matched content
- [TTS Conversion](../tts-conversion/) — Convert voice-matched content to audio
- [Reflect](../reflect/) — Capture voice feedback for improvement
