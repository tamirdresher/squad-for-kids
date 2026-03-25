# 🔊 Read Aloud Skill

> Adapted from the production squad's TTS conversion skill and podcaster system.

## Purpose

Convert lesson content, stories, and instructions into spoken audio for younger children who can't read well yet, or for auditory learners who absorb information better by listening. Makes the squad accessible to pre-readers (ages 4-6) and supports multisensory learning.

## Capabilities

- **Lesson narration** — convert any lesson to spoken audio
- **Story time** — read stories and adventures aloud with expression
- **Instructions** — speak task instructions for kids who can't read them
- **Multilingual voices** — natural-sounding voices in multiple languages
- **Adjustable speed** — slower for young kids, normal for older ones
- **Two-voice mode** — conversational format for engaging explanations (teacher + student dialogue)

## Technology Stack

### MVP (No API Keys Required)
- **Engine:** Microsoft Edge TTS (`edge-tts` Python library)
- **Quality:** Neural-quality voices, free, no signup
- **Voices by language:**
  | Language | Voice | Style |
  |----------|-------|-------|
  | English | `en-US-JennyNeural` | Warm, clear, child-friendly |
  | Hebrew | `he-IL-HilaNeural` | Natural Hebrew pronunciation |
  | Arabic | `ar-SA-ZariyahNeural` | Clear Modern Standard Arabic |
  | Spanish | `es-MX-DaliaNeural` | Friendly Latin American Spanish |
  | French | `fr-FR-DeniseNeural` | Natural French |
  | Chinese | `zh-CN-XiaoxiaoNeural` | Clear Mandarin |
  | Japanese | `ja-JP-NanamiNeural` | Natural Japanese |

### Production (When Scaling)
- **Azure AI Speech Service** — higher quality, more voices, SSML support
- **Custom voice profiles** — each squad agent gets their own voice personality

## Usage Modes

### Single Voice (Default)
Direct narration — the agent reads content aloud as themselves.

```
Input:  "Today we're going to learn about fractions! A fraction is..."
Output: lesson-fractions.mp3
```

### Conversational (Two Voices)
Teacher-student dialogue — more engaging for complex topics.

```
Input:  Lesson markdown about fractions
Output: Two voices discussing fractions in a natural back-and-forth
```

### Story Time
Expressive reading with pauses, emphasis, and emotion markers.

```
Input:  A story about a brave explorer
Output: Narrated story with dramatic reading style
```

## Content Pipeline

```
Lesson Markdown → Strip formatting → Age-appropriate simplification →
  → Voice selection (by agent personality) → TTS generation → MP3 output
```

## Age Adaptations

| Age Group | Speech Rate | Vocabulary | Session Length |
|-----------|------------|------------|---------------|
| 4-5 years | 0.8x (slow) | Very simple | 3-5 minutes |
| 6-7 years | 0.9x | Simple | 5-10 minutes |
| 8-10 years | 1.0x (normal) | Grade-level | 10-15 minutes |
| 11+ years | 1.0x-1.1x | Full | 15-20 minutes |

## Integration Points

- **Curriculum Lookup** → determines content to read
- **Kid-Friendly Skill** → ensures language matches age level
- **Study Scheduler** → triggers audio lessons at scheduled times
- **Gamification** → awards "Good Listener" badges for audio lessons completed

## File Management

- Audio files stored in `.squad/audio/` (gitignored — too large for Git)
- Cached locally to avoid regenerating the same content
- Automatic cleanup of files older than 30 days

## Upstream Reference

Adapted from the production squad's TTS conversion skill, edge-tts integration, and podcaster pipeline. See the squad framework documentation for architecture details.
