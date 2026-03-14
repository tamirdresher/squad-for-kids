# .NET Rocks Voice Cloning — Research Report

> **Issue:** #537  
> **Author:** Seven (Research & Docs)  
> **Date:** 2026-03-14  
> **Status:** 🟢 Research Complete — Ready for Implementation  
> **Depends on:** #496 (Hebrew Voice Cloning Pipeline)

---

## Executive Summary

Voice cloning the .NET Rocks hosts (Carl Franklin and Richard Campbell) for synthetic podcast generation is **highly feasible** using the existing infrastructure in this repository. Unlike the Hebrew voice cloning effort (#496), which fought against limited language support across all TTS models, **English is the native strength of every model we've tested**. This means quality will be significantly better with less effort.

**Recommended approach:** Fish Speech S2-Pro via the Cloud API (`render_fishspeech_cloud.py`), with ElevenLabs as a premium fallback. The existing v4 pipeline (`render_fishspeech_v4.py`) can be adapted in ~2-3 days, with reference audio preparation being the main work.

---

## 1. Voice Profile Analysis

### 1.1 Carl Franklin

| Attribute | Detail |
|-----------|--------|
| **Role** | Co-host, drives technical depth, show producer |
| **Vocal register** | Warm baritone, ~100-130 Hz fundamental frequency (estimated) |
| **Speaking style** | Relaxed, broadcast-quality delivery; clear articulation |
| **Distinctive features** | Distinctive laugh (genuine, from-the-belly), smooth transitions between topics |
| **Emotional range** | Enthusiastic when discovering new tech, calm and deliberate during explanations |
| **Pacing** | Moderate, steady — rarely rushed, lets points land |
| **Background** | Professional musician and audio producer — his delivery has natural studio polish |
| **Catchphrases / Habits** | Warm intros ("Welcome back to .NET Rocks!"), grounding questions to keep discussions practical |

**Cloning challenge:** Carl's warmth and musicality are subtle. Reference audio should capture his conversational register, not just monologue. His laugh is iconic — but TTS models won't reproduce spontaneous laughter. Script-level `[laughs]` cues combined with short laugh audio clips (crossfaded) may be needed.

**Estimated pitch target:** ~120 Hz (to be verified from reference audio using `librosa.pyin`)

### 1.2 Richard Campbell

| Attribute | Detail |
|-----------|--------|
| **Role** | Co-host, brings breadth and industry context, storytelling |
| **Vocal register** | Mid-range, slightly higher energy than Carl, ~130-160 Hz (estimated) |
| **Speaking style** | Authoritative, mentor-like, often philosophical; great at analogies |
| **Distinctive features** | "Geek Out" segments, scotch recommendations, historical deep-dives |
| **Emotional range** | Animated when making a point, thoughtful pauses before big insights |
| **Pacing** | Slightly faster than Carl, builds momentum through segments |
| **Background** | Decades in enterprise tech — his delivery carries gravitas |
| **Catchphrases / Habits** | Rhetorical questions ("But here's the thing..."), segues into broader industry context |

**Cloning challenge:** Richard's voice carries more tonal variation than Carl's. His "Geek Out" delivery has a different energy from his interview segments. Reference audio should include both conversational and expository modes.

**Estimated pitch target:** ~145 Hz (to be verified from reference audio)

### 1.3 Host Dynamics

The magic of .NET Rocks isn't just two voices — it's the **interplay**:

- **Carl asks, Richard explains** (or vice versa, depending on the topic)
- **Natural overlaps** — "Right, right" / "Exactly" while the other speaks
- **Complementary energy** — Carl grounds, Richard expands
- **Humor** — dry wit, running jokes, callbacks to previous episodes
- **Guest triangulation** — both hosts ping-pong with guests, never just one interviewer

The script generator (`scripts/generate-podcast-script.py`) already models two-host dynamics with the Alex/Sam personas. Adapting it to Carl/Richard personas is straightforward.

---

## 2. Voice Cloning Technology Assessment

### 2.1 Model Comparison for English Voice Cloning

| Model | Cloning Quality (English) | Speed | Cost | Setup Effort | Already in Repo |
|-------|--------------------------|-------|------|-------------|-----------------|
| **Fish Speech S2-Pro (Cloud)** | ⭐⭐⭐⭐⭐ Excellent | ~1-2s/segment | $24/mo (Plus plan) | Minimal — `render_fishspeech_cloud.py` exists | ✅ Yes |
| **Fish Speech S2-Pro (Local)** | ⭐⭐⭐⭐⭐ Excellent | ~54 min/episode (CPU) | Free | Moderate — v4 pipeline exists | ✅ Yes |
| **ElevenLabs** | ⭐⭐⭐⭐⭐ Best-in-class | ~2-5s/segment | $22/mo (Creator) | Low — `render_elevenlabs_podcast.py` exists | ✅ Yes |
| **XTTS v2** | ⭐⭐⭐⭐ Very Good | Fast | Free | Low — tested in repo | ✅ Yes |
| **Chatterbox TTS** | ⭐⭐⭐⭐ Good | Fastest | Free | Moderate | ✅ Tested |
| **F5-TTS** | ⭐⭐⭐⭐⭐ Excellent (diffusion) | Slow | Free | Moderate | ✅ Tested |
| **OpenVoice v2** | ⭐⭐⭐ Good (tone conversion) | Fast | Free | Integrated as post-processor | ✅ Yes |

### 2.2 Recommended Primary: Fish Speech S2-Pro (Cloud API)

**Why Fish Speech wins for this project:**

1. **Existing infrastructure** — The entire v1→v4 pipeline evolution is already built. The Cloud API (`render_fishspeech_cloud.py`) reduces 54 minutes of CPU rendering to 1-2 seconds.
2. **Reference audio approach proven** — The v3/v4 pipeline already handles dual-speaker rendering with per-speaker reference audio, Whisper-aligned transcripts, and pitch correction.
3. **English is native** — Unlike Hebrew (which required phonetic niqqud guidance, Arabic proxy tricks, and extensive pitch correction), English "just works" with Fish Speech S2-Pro.
4. **Emotion control** — S2-Pro supports inline emotion tags (`[excited]`, `[thoughtful]`, `[laughing]`) that map perfectly to podcast dynamics.
5. **Cost-effective** — $24/month for the Fish Audio Plus plan covers ~500 minutes of generated audio.

### 2.3 Recommended Fallback: ElevenLabs

**When to use ElevenLabs instead:**

- If Fish Speech cloning quality for either host is unsatisfactory after tuning
- For a "gold standard" comparison during quality evaluation
- If commercial-grade fidelity is required for external-facing content

**ElevenLabs specifics:**
- Professional voice cloning requires Creator tier ($22/month, 100K credits ≈ ~100 min audio)
- Best-in-class emotional range and naturalness
- `render_elevenlabs_podcast.py` already exists in the repo
- Upload reference samples → get instant clone → API-driven generation

### 2.4 Why Not Others?

| Model | Why Not Primary |
|-------|----------------|
| **XTTS v2** | Great for English, but Fish Speech S2-Pro has surpassed it on TTS Arena ELO ratings. Use as a backup. |
| **F5-TTS** | Excellent diffusion-based quality but slower inference. Consider for a "premium render" variant. |
| **Chatterbox** | Speed champion but slightly lower cloning fidelity than Fish Speech for voice matching. |
| **OpenVoice v2** | Best as a post-processing tone converter (already integrated), not as primary TTS. |

---

## 3. Reference Audio Strategy

### 3.1 Source: .NET Rocks Episodes

**Primary source:** https://www.dotnetrocks.com/

**RSS Feed:** `https://www.dotnetrocks.com/feed`

The podcast has **2000+ episodes** going back to 2002, all available as MP3 downloads. This is an enormous corpus to draw from.

**Recommended episodes for reference extraction:**

| Purpose | Episode Type | Why |
|---------|-------------|-----|
| Carl solo voice | Episodes where Carl does extended intros/outros | Clean single-speaker audio, broadcast quality |
| Richard solo voice | "Geek Out" segments | Richard speaks uninterrupted for 5-10 minutes |
| Conversational dynamics | Any recent episode with a guest | Captures natural interplay |
| Carl's laugh | Episodes with humorous guests | Need isolated laugh samples |
| Richard storytelling | Historical/industry retrospective episodes | Captures his authoritative mode |

### 3.2 Reference Audio Preparation Pipeline

```
Step 1: Download 3-5 recent episodes (MP3, ~60 min each)
        └─ Script: parse RSS feed, download via requests

Step 2: Speaker diarization (separate Carl vs Richard vs Guest)
        └─ Tool: pyannote.audio or whisperx with diarization
        └─ Output: per-speaker segments with timestamps

Step 3: Select best 30-second clips per speaker
        └─ Criteria: clean audio, no overlap, representative tone
        └─ Tool: adapt scripts/extract_best_refs.py (already exists!)
        └─ Need: 2-3 clips per speaker for variety

Step 4: Transcribe reference clips (Whisper large-v3)
        └─ Output: exact word-for-word transcript per clip
        └─ Critical: transcript MUST match spoken words exactly
        └─ Lesson from Hebrew work: ref_text accuracy is the #1 quality driver

Step 5: Validate pitch targets
        └─ Tool: librosa.pyin (already used in v4 pipeline)
        └─ Output: fundamental frequency per speaker
        └─ Use for post-processing pitch correction

Step 6: Store in voice_samples/
        └─ carl_franklin_ref.wav (30s, best clip)
        └─ carl_franklin_ref_long.wav (if composite needed)
        └─ carl_franklin_ref_transcript.txt
        └─ richard_campbell_ref.wav
        └─ richard_campbell_ref_long.wav
        └─ richard_campbell_ref_transcript.txt
```

### 3.3 Reference Audio Quality Checklist

Based on Fish Speech S2-Pro best practices and lessons from the Hebrew pipeline:

- [ ] Duration: 10-30 seconds per clip (30s ideal for S2-Pro)
- [ ] Single speaker only — no crosstalk or guest overlap
- [ ] Clean audio — no background music, audience noise, or sound effects
- [ ] WAV format, 44.1 kHz sample rate, mono preferred
- [ ] Exact transcript matching spoken content word-for-word
- [ ] Representative of typical speaking style (not extreme emotion)
- [ ] Volume normalized (LUFS-based)
- [ ] Multiple clips per speaker for quality-scored selection (use `extract_best_refs.py`)

### 3.4 Legal and Ethical Considerations

> ⚠️ **Important:** Voice cloning of real public figures raises ethical and legal questions.

- .NET Rocks episodes are publicly distributed under their podcast license
- Using voice clones for **internal demos, research, or parody** is generally permissible
- Using voice clones to **impersonate** the hosts or create content that could be mistaken for official .NET Rocks episodes would be problematic
- **Recommendation:** Always watermark or label synthetic audio as AI-generated
- **Best practice:** Reach out to Carl and Richard for permission if content will be shared publicly — they're accessible community figures

---

## 4. Implementation Plan

### Phase 1: Reference Audio Preparation (1-2 days)

**Goal:** Clean, validated reference audio for both hosts.

| Step | Task | Tool / Script | Output |
|------|------|---------------|--------|
| 1.1 | Download 5 recent .NET Rocks episodes | Python script (feedparser + requests) | `voice_samples/dotnetrocks_raw/` |
| 1.2 | Run speaker diarization | pyannote.audio or whisperx | Per-speaker segment files |
| 1.3 | Extract best 30s clips per speaker | `scripts/extract_best_refs.py` (adapt) | `voice_samples/carl_franklin_ref.wav`, `richard_campbell_ref.wav` |
| 1.4 | Transcribe with Whisper large-v3 | whisper CLI or whisperx | `*_transcript_largev3.txt` per speaker |
| 1.5 | Validate pitch targets | librosa.pyin analysis | Pitch targets for post-processing |
| 1.6 | Quality-score reference clips | Agent analysis (as done for Dotan/Shahar) | `*_best_composite.wav` if needed |

### Phase 2: Pipeline Adaptation (1 day)

**Goal:** Adapt the existing v4 pipeline for English / .NET Rocks voices.

| Step | Task | Details |
|------|------|---------|
| 2.1 | Create `render_dotnetrocks.py` | Fork `render_fishspeech_v4.py`, replace Hebrew-specific config |
| 2.2 | Remove Hebrew-specific features | Drop niqqud phonetic guidance (not needed for English) |
| 2.3 | Update speaker config | Replace Dotan/Shahar with Carl/Richard: pitch targets, ref paths, parameter sets |
| 2.4 | Update parameter variants | English needs different temp/top_p tuning than Hebrew (typically lower temp is fine) |
| 2.5 | Adapt post-processing | Keep pitch correction + loudness normalization; tune for English speech characteristics |
| 2.6 | Test with Cloud API | Use `render_fishspeech_cloud.py` pattern for fast iteration |

**Key simplifications vs Hebrew pipeline:**
- No niqqud/phonetic guidance needed
- No Arabic language proxy tricks
- Post-processing pitch correction will be gentler (models handle English natively)
- No need for OpenVoice tone color conversion as a rescue layer

### Phase 3: Script Generator Adaptation (0.5 days)

**Goal:** Generate scripts that sound like .NET Rocks, not generic podcasts.

| Step | Task | Details |
|------|------|---------|
| 3.1 | Create Carl/Richard persona prompts | Adapt `generate-podcast-script.py` Alex/Sam → Carl/Richard |
| 3.2 | Add .NET Rocks segment structure | Intro → News → Main Discussion → Geek Out → Wrap-up |
| 3.3 | Add personality markers | Carl: grounding questions, tech depth. Richard: analogies, industry context, "Geek Out" tangents |
| 3.4 | Add show-specific elements | ".NET Rocks" intro/outro, "Better Know a Framework" segment prompts |
| 3.5 | Test script quality | Generate 3-5 sample scripts, evaluate for authenticity |

**Script persona mapping:**

```
Carl Franklin (Speaker 1):
- Drives the interview, asks probing technical questions
- Warm intros and smooth transitions
- "That's a great point, but how does that work in practice?"
- Music/audio production metaphors occasionally
- The "straight man" in humor — sets up jokes naturally

Richard Campbell (Speaker 2):
- Brings broader industry context and history
- "You know, this reminds me of when we first saw..."
- Great analogies to explain complex concepts
- "Geek Out" energy for tangential deep-dives
- Scotch segment references (can be a fun synthetic touch)
```

### Phase 4: Quality Evaluation (0.5 days)

| Step | Task | Criteria |
|------|------|---------|
| 4.1 | Generate test episode (5 min) | Full pipeline: script → voice clone → post-processing |
| 4.2 | A/B test against real episode | Compare naturalness, voice similarity, conversational flow |
| 4.3 | Evaluate speaker differentiation | Can listeners tell Carl from Richard? |
| 4.4 | Test emotion tags | Do `[excited]`, `[thoughtful]` annotations work? |
| 4.5 | Compare Fish Speech vs ElevenLabs | Run same script through both; pick winner |
| 4.6 | Iterate on reference audio if needed | Swap clips, adjust pitch targets, re-render |

### Phase 5: Production Pipeline (0.5 days)

| Step | Task | Details |
|------|------|---------|
| 5.1 | Create end-to-end script | `render_dotnetrocks_podcast.py` — markdown in → .NET Rocks MP3 out |
| 5.2 | Integrate with `parallel_podcast_render.py` | Parallel rendering for multi-segment episodes |
| 5.3 | Add OneDrive auto-upload | Mirror pattern from v4 pipeline |
| 5.4 | Document the pipeline | Update PODCASTER_README.md |

---

## 5. Dependencies on Hebrew Voice Cloning (#496)

### What We Reuse Directly

| Component | File | What It Does |
|-----------|------|-------------|
| Fish Speech S2-Pro model | `fish-speech-repo/` | Same model, same checkpoint — English is natively supported |
| Cloud API client | `render_fishspeech_cloud.py` | API pattern is language-agnostic |
| Post-processing pipeline | `scripts/postprocess_fishspeech.py` | Pitch correction, loudness normalization, compression |
| Reference extraction | `scripts/extract_best_refs.py` | Quality-scored clip selection |
| Script generator | `scripts/generate-podcast-script.py` | Two-host dialogue generation framework |
| Voice sample directory | `voice_samples/` | Storage convention for reference audio |
| Parallel renderer | `scripts/parallel_podcast_render.py` | Multi-segment rendering infrastructure |

### What We Don't Need

| Hebrew-Specific Component | Why Not Needed |
|---------------------------|---------------|
| Niqqud (phonetic guidance) | English pronunciation is handled natively |
| Arabic language proxy (XTTS) | English is the primary language for all models |
| Inverted pitch correction | The ±5.5 semitone corrections were Hebrew artifacts |
| OpenVoice tone rescue layer | Fish Speech handles English voice identity well on its own |
| Manual MMS-TTS fallback | Not needed — all models support English natively |

### What We Improve

| Area | Hebrew (v4) | English (.NET Rocks) |
|------|------------|---------------------|
| Reference audio quality | Real voice recordings (internal) | Professional podcast audio (broadcast quality) |
| Transcript accuracy | Whisper large-v3 (had Hebrew accuracy issues) | Whisper large-v3 (excellent for English) |
| Model performance | Required workarounds for Hebrew | Native English support — simpler, better |
| Post-processing effort | Heavy (pitch, tone, niqqud) | Light (mainly loudness normalization) |

---

## 6. Effort and Timeline Estimate

| Phase | Effort | Calendar Days | Blockers |
|-------|--------|---------------|----------|
| **Phase 1:** Reference audio prep | 8-12 hours | 1-2 days | Need to download and process .NET Rocks episodes |
| **Phase 2:** Pipeline adaptation | 4-6 hours | 1 day | Depends on Phase 1 |
| **Phase 3:** Script generator | 2-3 hours | 0.5 days | Can parallel with Phase 2 |
| **Phase 4:** Quality evaluation | 3-4 hours | 0.5 days | Depends on Phases 2+3 |
| **Phase 5:** Production pipeline | 3-4 hours | 0.5 days | Depends on Phase 4 |
| **Total** | **20-29 hours** | **3-5 days** | — |

### Cost Estimate

| Item | One-Time | Monthly |
|------|----------|---------|
| Fish Speech Cloud API (Plus) | — | $24/month (already budgeted for Hebrew) |
| ElevenLabs Creator (if needed) | — | $22/month |
| GPU compute (if local rendering) | — | Free (existing CPU pipeline) |
| .NET Rocks audio (public podcast) | Free | — |

**Key insight:** If the Fish Audio Plus plan is already active for Hebrew podcast work, .NET Rocks voice cloning adds **zero additional infrastructure cost** — it's the same API, same plan.

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Voice cloning doesn't capture host personality | Low | Medium | Multiple reference clips, A/B testing, ElevenLabs fallback |
| Legal/ethical concerns from hosts | Low | High | Label as AI-generated, seek permission for public use |
| Reference audio quality issues (background noise, overlap) | Medium | Medium | Speaker diarization + careful clip selection |
| Fish Speech API changes/downtime | Low | Medium | Local CPU fallback pipeline exists |
| Script generator produces generic-sounding dialogue | Medium | Medium | Detailed persona prompts, iterative prompt tuning |

---

## 8. File Structure (Proposed)

```
voice_samples/
├── carl_franklin_ref.wav              # 30s best reference clip
├── carl_franklin_ref_long.wav         # Extended reference (if needed)
├── carl_franklin_ref_transcript.txt   # Exact Whisper transcript
├── carl_franklin_best_composite.wav   # Quality-scored composite
├── richard_campbell_ref.wav           # 30s best reference clip
├── richard_campbell_ref_long.wav      # Extended reference
├── richard_campbell_ref_transcript.txt
├── richard_campbell_best_composite.wav
└── dotnetrocks_raw/                   # Downloaded episode clips (gitignored)

scripts/
├── render_dotnetrocks.py              # Main rendering pipeline
├── download_dotnetrocks_refs.py       # Episode download + diarization
└── generate-podcast-script.py         # Adapted with Carl/Richard personas

research/active/dotnet-rocks-voice-cloning/
├── RESEARCH.md                        # This document
└── SAMPLES.md                         # Evaluation notes after Phase 4
```

---

## 9. Quick Start (For the Implementing Engineer)

```bash
# Step 1: Download reference episodes
python scripts/download_dotnetrocks_refs.py --episodes 5 --output voice_samples/dotnetrocks_raw/

# Step 2: Diarize and extract speaker segments
python scripts/download_dotnetrocks_refs.py --diarize --extract-best --speaker carl
python scripts/download_dotnetrocks_refs.py --diarize --extract-best --speaker richard

# Step 3: Transcribe reference clips
whisper voice_samples/carl_franklin_ref.wav --model large-v3 --output_format txt
whisper voice_samples/richard_campbell_ref.wav --model large-v3 --output_format txt

# Step 4: Generate a test script
python scripts/generate-podcast-script.py article.md --persona dotnetrocks -o test-script.txt

# Step 5: Render with Fish Speech Cloud API
python scripts/render_dotnetrocks.py test-script.txt --engine cloud --output dotnetrocks-test.mp3

# Step 6: Compare with ElevenLabs
python scripts/render_dotnetrocks.py test-script.txt --engine elevenlabs --output dotnetrocks-test-el.mp3
```

---

## 10. Conclusion

The .NET Rocks voice cloning project benefits enormously from the Hebrew pipeline groundwork. Every hard problem — model selection, reference audio alignment, Whisper transcription, pitch correction, post-processing, parallel rendering — has been solved. English voice cloning is the **easy mode** of what we've already done.

The main work is operational: downloading episodes, extracting clean reference clips, and tuning the script generator for Carl/Richard's specific dynamic. The technology is ready. The pipeline exists. This is a 3-5 day effort with high confidence of quality results.

**Next action:** Approve this research and begin Phase 1 (reference audio preparation).

---

## References

- [.NET Rocks! Official Site](https://www.dotnetrocks.com/)
- [.NET Rocks! RSS Feed](https://www.dotnetrocks.com/feed)
- [.NET Rocks! About Page](https://www.dotnetrocks.com/about)
- [Fish Speech S2-Pro (GitHub)](https://github.com/fishaudio/fish-speech)
- [Fish Speech S2-Pro (Hugging Face)](https://huggingface.co/fishaudio/s2-pro)
- [Fish Audio Cloud API](https://fish.audio/)
- [ElevenLabs Pricing](https://elevenlabs.io/pricing)
- [TTS Arena ELO Rankings](https://huggingface.co/spaces/TTS-AGI/TTS-Arena)
- [Best Open Source Voice Cloning Models 2026](https://www.siliconflow.com/articles/en/best-open-source-models-for-voice-cloning)
- [Comparing TTS Models (Inferless)](https://www.inferless.com/learn/comparing-different-text-to-speech---tts--models-part-2)
- Internal: `FISH_SPEECH_INVENTORY.md` — Full v1-v4 progression
- Internal: `HEBREW_PODCAST_METHODS.md` — Hebrew pipeline lessons
- Internal: `PODCASTER_README.md` — Podcast generation framework
