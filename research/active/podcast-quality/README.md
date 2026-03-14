# Research: Making AI Podcasts Sound Like Real Tech Podcasts

**Date:** 2026-03-13  
**Researcher:** Seven (Research & Docs specialist)  
**Status:** COMPLETE — Ready for implementation  
**Confidence:** HIGH  

---

## Executive Summary

The current podcaster sounds like "someone reading from a page" because it uses a simple TTS-from-flat-script approach. Real tech podcasts like .NET Rocks and Google NotebookLM sound conversational because they employ a **2-phase architecture**:

1. **Phase 1: Conversation Script Generation** — LLM creates a realistic dialogue between two hosts (with natural banter, disagreements, follow-up questions, filler words "hmm interesting", jokes)
2. **Phase 2: Multi-Voice TTS with Prosody** — Advanced TTS renders the script with emotional range, overlapping speech, turn-taking cues, and natural pacing

**Key Finding:** The script quality matters more than TTS quality. A great conversation script with decent TTS beats perfect TTS reading a flat script.

---

## How Google NotebookLM Does It

Google NotebookLM's "Audio Overview" (podcast feature) uses:

1. **Gemini LLM** parses source documents (PDFs, URLs, text, videos)
2. **Conversational Scripting:** Gemini generates a two-host dialogue script that:
   - Connects themes across sources
   - Includes natural back-and-forth exchanges
   - Adds realistic pauses, interjections ("um," "oh," "hold on")
   - Mimics human discussion patterns
3. **Google WaveNet/Neural TTS:** Renders script with:
   - Realistic tone and pacing
   - Emotional nuance
   - Two distinct voices
4. **Output:** MP3 podcast that sounds like genuine discussion

**Why It Works:** Listeners hear two people *talking*, not one person *reading*.

---

## Recommended 2-Phase Architecture

### Phase 1: LLM Conversation Script Generation

**Input:** Topic/content (markdown, JSON, or raw text)

**LLM Task:** Generate a two-host dialogue script that includes:
- **Opening banter** — Casual introduction to the topic
- **Host personalities** — Host A is curious/asks questions; Host B has more expertise
- **Natural interruptions** — "Wait, so you're saying..."; "Right, and also..."
- **Filler words** — Strategically placed "hmm", "you know", "exactly"
- **Disagreements/debate** — "I'm not sure about that..." (makes it more engaging)
- **Followup questions** — Host A asks clarifying questions
- **Jokes/banter** — Casual humor, not forced
- **Emotional shifts** — Excitement, skepticism, agreement
- **Natural transitions** — Move between topics like real people do
- **Outro** — Wrap-up with takeaways

**Script Format Example:**
```
[HOST_A]: Hey everyone, we're diving into the new .NET 9 features today. I'm curious what you think about the SIMD improvements?
[HOST_B]: Oh man, this is huge! The performance gains are... I mean, we're talking 3x speedup in some benchmarks.
[HOST_A]: 3x? That seems insane. Wait, is that in all workloads or just specific scenarios?
[HOST_B]: Right, good question. It's mainly when you're using vectorized operations, so...
```

**Recommended LLM Models:**
- Claude 3.5 Sonnet (strong dialogue generation)
- GPT-4 (excellent script quality)
- Local: Llama 3.1 70B (self-hosted, cost-effective)

### Phase 2: Multi-Voice TTS with Prosody Control

**Input:** Dialogue script (marked with [HOST_A], [HOST_B])

**TTS Task:** Render each host with:
- **Distinct voices** (e.g., male/female, different accents/styles)
- **Prosody control** (emotion, pacing, emphasis)
- **Filler word handling** (natural placement of "um", pauses)
- **Overlapping speech** (when appropriate in dialogue)
- **Turn-taking cues** (pitch variations, natural pauses)
- **Emotional range** (excitement, skepticism, agreement)

---

## TTS Model Comparison

| Model | Naturalness | Dialogue Quality | Open-Source | Cost | Best For | Notes |
|-------|-------------|------------------|-------------|------|----------|-------|
| **Fish Speech S2** | ★★★★★ | ★★★★★ | YES | Free | Production podcasts | LLM-integrated, real-time, rivals ElevenLabs |
| **ElevenLabs v3 Turbo** | ★★★★★ | ★★★★★ | NO | $$$$ | Premium quality | Industry leader, excellent emotion/dialogue |
| **VibeVoice (Microsoft)** | ★★★★★ | ★★★★★ | YES (research) | Free | Long-form podcasts (30+ min) | Up to 4 speakers, next-token diffusion |
| **MOSS-TTSD** | ★★★★ | ★★★★★ | YES | Free | Multi-speaker dialogue | Strong at turn-taking, overlapping speech |
| **PlayHT v3** | ★★★★ | ★★★★ | NO | $$ | Budget-friendly | 100+ languages, good emotion |
| **Azure HD Voices** | ★★★★ | ★★★★ | NO | $$ | Enterprise | 140+ languages, SSML control, reliable |
| **OpenAI TTS** | ★★★★ | ★★★★ | NO | $ | LLM integration | Limited voices, good for prototypes |
| **Bark/XTTS** | ★★★ | ★★★ | YES | Free | Local/private deployments | Voice cloning, privacy-focused |

**Recommendation for Your Stack:**
- **Self-hosted/cost-optimized:** Fish Speech S2 (free, open-source, LLM-integrated, production-ready)
- **Premium quality:** ElevenLabs (industry standard, best dialogue/emotion control)
- **Research/experimentation:** VibeVoice (cutting-edge, multi-speaker long-form)

---

## Key Conversational TTS Techniques

### 1. Overlapping Speech
Real conversations have natural overlaps where speakers talk simultaneously. Advanced models (MOSS-TTSD, VibeVoice, Fish Speech) can:
- Simulate multiple speakers talking at once
- Handle "collision" points realistically
- Use prosodic markers to clarify turn competition

### 2. Filler Words ("um", "uh", "you know", "exactly")
Placement is critical:
- Start of utterances (hesitation)
- Before difficult/uncommon words
- When switching topics/phrases
- When thinking aloud

This signals genuine conversation, not a script being read.

### 3. Emotional Range
Model continuous emotional dimensions:
- Pleasantness (bored → excited)
- Arousal (calm → energetic)
- Skepticism vs. agreement
- Surprise/discovery

Shift emotions mid-dialogue for natural transitions.

### 4. Turn-Taking Cues
Realistic dialogue requires:
- **Turn-yielding** (falling pitch, syntactic closure, pauses) = "Your turn to speak"
- **Turn-holding** (rising intonation, filler words) = "I'm still thinking"
- **Interruption markers** (abrupt entry, rising pitch) = "Wait, I have something"

Modern models (VibeVoice, MOSS-TTSD) excel at this.

---

## Implementation Roadmap

### **MVP (Week 1)**
- [ ] Add LLM script generation step (use Claude/GPT-4)
- [ ] Replace flat TTS with multi-voice TTS (try Fish Speech S2 or ElevenLabs)
- [ ] Test with 1-2 sample podcasts
- [ ] Gather feedback on "conversational feel"

### **Phase 2 (Week 2-3)**
- [ ] Add prosody/emotion control to TTS calls
- [ ] Implement strategic filler word insertion in scripts
- [ ] Add turn-taking markers to dialogue
- [ ] Test overlapping speech (if supported by TTS)

### **Phase 3 (Iteration)**
- [ ] Fine-tune LLM prompts for better banter
- [ ] A/B test different host personalities
- [ ] Optimize for specific topics (tech podcasts, tutorials, etc.)
- [ ] Compare to real podcasts (.NET Rocks, Syntax.fm, etc.)

---

## Stack Recommendations

### **For PowerShell/Python Integration**

**Option A: Fish Speech (Recommended for MVP)**
```powershell
# Phase 1: Generate script
$script = Invoke-LLM -Model "gpt-4" -Prompt "Generate a 2-host dialogue about $topic"

# Phase 2: Render with Fish Speech
# Install: pip install fishaudio
python -c "from fishaudio import TTS; tts = TTS('fish-speech-s2'); tts.synthesize($script)"
```

**Option B: ElevenLabs (Premium Quality)**
```powershell
# Use ElevenLabs API for multi-voice rendering
# Supports all prosody/emotion markers
$response = Invoke-RestMethod -Uri "https://api.elevenlabs.io/v1/text-to-speech" `
  -Method Post `
  -Headers @{"xi-api-key" = $apiKey} `
  -Body @{text = $scriptWithEmotionTags; voice_id = $voiceId} | ConvertTo-Json
```

**Option C: Azure (Enterprise)**
```powershell
# Azure Speech Services with SSML for emotion/prosody
$ssmlScript = Convert-ToSSML -Script $script -AddEmotionTags
Invoke-AzureSpeech -SSML $ssmlScript -OutputFile "podcast.mp3"
```

### **LLM Integration**

Use system prompt to generate dialogue:

```
You are a script writer for tech podcasts (like .NET Rocks, Syntax.fm).
Generate a two-host conversation script about: [TOPIC]

Host A: Curious, asks questions, interrupts with "wait...", uses filler words
Host B: Expert, explains concepts, sometimes disagrees, adds humor

Requirements:
- Natural banter, not a lecture
- Include filler words: "um", "you know", "exactly", "hmm interesting"
- Add disagreements/debate (makes it engaging)
- Host A interrupts 3-4 times with "so basically..."
- Natural transitions between topics
- Outro with takeaways
- ~5-7 minutes of podcast content

Format:
[HOST_A]: ...
[HOST_B]: ...
```

---

## Comparison with Current Approach

| Aspect | Current (Flat Script) | Recommended (Conversational) |
|--------|----------------------|------------------------------|
| **Script Quality** | Generic, linear | Natural dialogue, banter, disagreements |
| **Audio Rendering** | Single voice reading | Two distinct voices, prosody, emotion |
| **Listener Experience** | "Someone reading" | "Two people discussing" |
| **Engagement** | Lower (passive) | Higher (interactive feel) |
| **Production Time** | 5 min | 10 min (LLM script + TTS) |
| **TTS Model** | edge-tts/basic | Fish Speech S2, ElevenLabs, VibeVoice |
| **Customization** | Limited | Full control (emotion, pacing, personalities) |

---

## Academic & Industry References

- **FireRedTTS-2** (2025): Long-form conversational TTS for podcasts, handles speaker-turn reliability
- **CoVoMix** (NeurIPS 2024): Zero-shot multi-talker dialogue with overlapping speech
- **VibeVoice** (Microsoft Research): Multi-speaker long-form podcast synthesis with next-token diffusion
- **MOSS-TTSD** (OpenMOSS): Text-to-spoken-dialogue generation with realistic turn-taking
- **Fish Speech** (2024): LLM-integrated TTS rivaling ElevenLabs for naturalness

---

## Success Metrics

Measure improvement vs. current podcaster:

1. **MOS (Mean Opinion Score):** Listeners rate naturalness (1-5 scale)
2. **Engagement:** Podcast completion rate, time listened
3. **Comparability:** How similar is it to real tech podcasts (.NET Rocks)?
4. **Filler Words:** Frequency/naturalness of "um", "you know" placements
5. **Turn-Taking:** Smooth speaker transitions, no awkward overlaps

---

## Next Steps

1. **Implement LLM script generation** (use GPT-4 or Claude system prompt)
2. **Integrate Fish Speech S2 or ElevenLabs** (Phase 2 TTS rendering)
3. **Test with 2-3 sample topics** (compare to current output)
4. **Gather team feedback** (Does it sound more conversational?)
5. **Iterate on LLM prompts** (Tailor host personalities, adjust banter level)
6. **Deploy to production** (replace current podcaster)

---

## References

- Google NotebookLM Podcast: https://notebooklm.google.com
- Fish Speech GitHub: https://github.com/fishaudio/fish-speech
- VibeVoice: https://vibevoice.art/
- MOSS-TTSD: https://github.com/OpenMOSS/MOSS-TTSD
- FireRedTTS-2: https://arxiv.org/html/2509.02020v1
- CoVoMix (NeurIPS 2024): https://proceedings.neurips.cc/paper_files/paper/2024/file/b5fd95d6b16d3172e307103a97f19e1b-Paper-Conference.pdf
- ElevenLabs: https://elevenlabs.io
- PlayHT: https://www.playht.com
- Azure Speech Services: https://learn.microsoft.com/en-us/azure/ai-services/speech-service/

---

**Report Status:** Ready for implementation kickoff  
**Recommended Action:** Start MVP (Phase 1 + Phase 2) this week
