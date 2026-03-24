# YouTube Daily News Voice Pipeline
## TTS Architecture for 4-Language Video Production

> **Issue:** [#811](https://github.com/tamirdresher_microsoft/tamresearch1/issues/811)  
> **Author:** Seven (Squad Research Agent)  
> **Updated:** 2026-03-24  
> **Status:** ✅ Recommended — backed by 100+ Hebrew podcast experiments  

---

## Executive Summary

This document defines the recommended Azure TTS voice pipeline for producing daily YouTube news videos in **English (EN), Hebrew (HE), Spanish (ES), and French (FR)**. Hebrew recommendations are backed by empirical research from the repo's extensive TTS evaluation history (`podcast_quality_leaderboard.csv`, 100+ test files). All four languages use Azure Cognitive Services Speech SDK, already available on this machine.

**TL;DR:**

| Language | Primary Voice | Style | HD Option |
|----------|--------------|-------|-----------|
| EN 🇺🇸 | `en-US-AndrewMultilingualNeural` | newscast-casual | Dragon HD |
| HE 🇮🇱 | `he-IL-AvriNeural` | newscast | + SeedVC conversion |
| ES 🇪🇸 | `es-ES-AlvaroNeural` | newscast | `es-ES-XimenaNeural` |
| FR 🇫🇷 | `fr-FR-HenriNeural` | newscast | `fr-FR-VivienneMultilingualNeural` |

---

## 1. Voice Recommendations per Language

### 1.1 English (EN) 🇺🇸

**Primary:** `en-US-AndrewMultilingualNeural` (Dragon HD tier)  
**Alternate:** `en-US-AvaMultilingualNeural` (female, Dragon HD)  
**Fallback:** `en-US-GuyNeural` (standard neural, cost-optimized)

**Rationale:**
- Andrew Dragon HD produces the most natural, authoritative news delivery tone
- Tested in this repo against Hebrew conversion (`azure-he-dragonhd-andrew-newscast-casual.mp3`) — the voice translates well to structured content
- `newscast-casual` style is proven for YouTube delivery (conversational yet professional)
- Multilingual designation means a single voice model handles all 4 languages if needed

**Recommended Style Tags:**
```
newscast-casual (primary)
professional (fallback for formal topics)
```

---

### 1.2 Hebrew (HE) 🇮🇱

**Primary:** `he-IL-AvriNeural` (male) + `he-IL-HilaNeural` (female, for co-host format)  
**HD Upgrade:** `en-US-AndrewMultilingualNeural` with `he-IL` locale override  

**Rationale — backed by empirical research:**

The repo contains 100+ Hebrew TTS evaluation files. Key findings from `podcast_quality_leaderboard.csv`:

| Metric | Top Performer | Score |
|--------|--------------|-------|
| Resemblyzer similarity | `hebrew-podcast-phonikud-neural.wav` | **0.9397** |
| DNSMOS overall quality | `hebrew-podcast-fishspeech-v2-expressive.mp3` | **3.883** |
| Combined quality + similarity | `hebrew-podcast-f5tts-realvoice.mp3` | ≈ **0.939 / 3.576** |

The `phonikud-neural` pipeline uses `he-IL-AvriNeural` as its base TTS, confirming it as the top-performing natively Hebrew voice. The Dragon HD multilingual voices (`azure-he-dragonhd-andrew-*`, `azure-he-dragonhd-ava-*`, etc.) were tested with voice conversion — they produce richer audio texture but require the SeedVC post-processing step.

**For YouTube production (single-speaker news narration):**
- ✅ Use `he-IL-AvriNeural` with `newscast` style for clean, production-ready output
- ✅ Optional: apply SeedVC voice conversion with a reference sample for branded voice identity
- ⚠️ `he-IL-HilaNeural` works well for female presenter variant

**Pipeline for Hebrew (full quality):**
```
Hebrew news text
    │
    ▼ Azure TTS (he-IL-AvriNeural, newscast style)
Raw 24kHz audio
    │
    ▼ SeedVC voice conversion (optional, for branded persona)
    │  Reference: dotan-voice-sample.mp3 or shahar-voice-sample.mp3
    ▼
Branded voice audio
    │
    ▼ Post-processing (EQ, normalization, -14 LUFS loudness)
Final master audio
```

**Dragon HD for Hebrew:** `en-US-AndrewMultilingualNeural` can synthesize Hebrew text. Tested files: `azure-he-dragonhd-andrew-newscast-casual.mp3`, `azure-he-dragonhd-andrew-professional.mp3`. Quality is excellent but costs 8× more than Standard Neural. Recommended only if budget allows or for premium editions.

---

### 1.3 Spanish (ES) 🇪🇸

**Primary:** `es-ES-AlvaroNeural` (male, Spain Spanish, standard neural)  
**Female Alt:** `es-ES-ElviraNeural`  
**LATAM Alt:** `es-MX-JorgeNeural` (if targeting Latin American audience)  
**HD Option:** `es-ES-XimenaNeural` or `en-US-AndrewMultilingualNeural` with `es-ES` locale  

**Rationale:**
- Alvaro has the clearest, most neutral accent for international Spanish audience
- `es-ES-ElviraNeural` provides a professional female voice with warm delivery
- For daily news, Castilian Spanish (`es-ES`) is typically preferred for European distribution
- LATAM audiences prefer `es-MX` or `es-US` variants — consider two regional variants if the channel targets the Americas

**Recommended Style Tags:**
```
newscast
documentary (for feature segments)
```

---

### 1.4 French (FR) 🇫🇷

**Primary:** `fr-FR-HenriNeural` (male, standard neural)  
**Female Alt:** `fr-FR-DeniseNeural`  
**HD Option:** `fr-FR-VivienneMultilingualNeural` (Dragon HD tier)  

**Rationale:**
- Henri has authoritative, neutral Parisian French delivery suitable for news
- Denise is the default Azure French voice and well-tested for content production
- Vivienne Multilingual HD provides broadcast quality but at HD pricing
- For Quebec/Canadian French: `fr-CA-AntoineNeural` or `fr-CA-SylvieNeural`

**Recommended Style Tags:**
```
newscast
formal
```

---

## 2. Cost Estimates per Minute of Audio

### Azure TTS Pricing Tiers (per 1M characters)

| Tier | Price | Best For |
|------|-------|---------|
| Standard Neural | **$1.00** | Cost-efficient production, EN/ES/FR fallback |
| HD Neural (Dragon) | **$8.00** | Premium quality, EN primary, HE Dragon HD |
| Custom Neural Voice | **$24.00** | Not needed — use SSML styles instead |

### Per-Video Cost Estimate (10-minute video)

**Assumptions:**
- 10 min video ≈ 1,400 words ≈ **8,400 characters** (average speaking rate: 140 words/min)
- Daily production: 4 videos/day × 365 days = 1,460 videos/year

| Voice Tier | Cost per Video | Cost per Day (4 videos) | Cost per Year |
|-----------|---------------|------------------------|---------------|
| Standard Neural | **$0.008** | $0.034 | **$12.26** |
| HD Neural | **$0.067** | $0.269 | **$98.08** |
| Mixed (HE+EN HD, ES+FR Standard) | **$0.038** | $0.150 | **$54.67** |

**Recommendation:** Use **Standard Neural** for ES and FR. Use **HD Neural only for EN and HE** (highest visibility, highest brand impact). Estimated annual TTS cost: **~$55/year** — effectively negligible vs. video production overhead.

> ⚠️ These estimates are for TTS API calls only. Azure Speech subscription must be active. Confirm with `az cognitiveservices account list --resource-group squad-rg`.

---

## 3. Pipeline Architecture

### 3.1 Standard Pipeline (EN, ES, FR)

```
┌─────────────────────────────────────────────────────────────┐
│                    Content Ingestion                        │
│  News RSS / Script → Text normalization → SSML generation   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Azure TTS (per language)                   │
│  • Input: SSML with style tags + prosody markup             │
│  • Voice: language-appropriate neural voice                 │
│  • Output: 24kHz WAV (mono or stereo)                       │
│  • SDK: Azure Cognitive Services Speech SDK                 │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   Audio Post-Processing                     │
│  • Loudness normalization: -14 LUFS (YouTube standard)      │
│  • True peak limiting: -1.0 dBTP                            │
│  • Optional: slight room reverb for warmth                  │
│  • Format conversion: WAV → AAC 256kbps for YouTube         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Video Assembly                             │
│  • Combine audio with visual assets (B-roll, titles)        │
│  • Add intro/outro music bed at -20dB under voice           │
│  • Export: H.264 MP4, 1920×1080, 30fps                     │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Hebrew Pipeline (Extended — SeedVC Option)

```
Hebrew news text
    │
    ▼ ① SSML generation (he-IL locale, niqqud-aware)
SSML document
    │
    ▼ ② Azure TTS → he-IL-AvriNeural / he-IL-HilaNeural
Raw Azure voice (24kHz WAV)
    │
    ├─── [Optional: SeedVC Voice Conversion] ─────────────────┐
    │    Reference: dotan-voice-sample.mp3 (60s preferred)    │
    │    Steps: 10 diffusion steps, cfg=3.0                   │
    │    Output: Converted voice WAV                          │
    │                                                         │
    ◄────────────────────────────────────────────────────────-┘
    │
    ▼ ③ Post-processing
    •  EQ: +2dB warmth at 250Hz (Avri), -3dB at 6kHz (harshness)
    •  Compression: 4:1 ratio, -18dB threshold
    •  Loudness: -14 LUFS normalization
    │
    ▼ ④ Video assembly (same as standard)
Final YouTube-ready MP4
```

---

## 4. SSML Templates per Language

### 4.1 English Template

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="en-US">
  <voice name="en-US-AndrewMultilingualNeural">
    <mstts:express-as style="newscast-casual" styledegree="1.2">
      <prosody rate="-3%" pitch="-2st" volume="loud">
        Good morning. Here are today's top stories in AI and technology.
      </prosody>
      <break time="500ms"/>
      <!-- INSERT NEWS CONTENT HERE -->
    </mstts:express-as>
  </voice>
</speak>
```

### 4.2 Hebrew Template

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="he-IL">
  <voice name="he-IL-AvriNeural">
    <mstts:express-as style="newscast" styledegree="1.0">
      <prosody rate="-2%" pitch="-1.5st" volume="loud">
        בוקר טוב. אלו הידיעות המובילות של היום בתחום הבינה המלאכותית.
      </prosody>
      <break time="500ms"/>
      <!-- INSERT HEBREW NEWS CONTENT HERE -->
      <!-- Note: Keep technical terms (AI, API, GitHub) in English -->
    </mstts:express-as>
  </voice>
</speak>
```

> **Hebrew SSML Notes:**
> - Azure `he-IL-AvriNeural` handles diacritic-free Hebrew (no niqqud needed for production text)
> - Technical terms stay in English — Azure handles code-switching naturally
> - `newscast` style (not `newscast-casual`) is more appropriate for Israeli news delivery
> - `styledegree="1.0"` is baseline; increase to `1.5` for more expressive delivery

### 4.3 Spanish Template

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="es-ES">
  <voice name="es-ES-AlvaroNeural">
    <mstts:express-as style="newscast" styledegree="1.1">
      <prosody rate="-2%" pitch="-1st" volume="loud">
        Buenos días. Estas son las principales noticias de hoy en inteligencia artificial.
      </prosody>
      <break time="500ms"/>
      <!-- INSERT SPANISH NEWS CONTENT HERE -->
    </mstts:express-as>
  </voice>
</speak>
```

### 4.4 French Template

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="fr-FR">
  <voice name="fr-FR-HenriNeural">
    <mstts:express-as style="newscast" styledegree="1.1">
      <prosody rate="-3%" pitch="-1st" volume="loud">
        Bonjour. Voici les principales nouvelles d'aujourd'hui en intelligence artificielle.
      </prosody>
      <break time="500ms"/>
      <!-- INSERT FRENCH NEWS CONTENT HERE -->
    </mstts:express-as>
  </voice>
</speak>
```

---

## 5. Quick-Start: Generating Audio with Azure SDK

### Python snippet (all 4 languages)

```python
import azure.cognitiveservices.speech as speechsdk
import os

# Configure Azure Speech
speech_config = speechsdk.SpeechConfig(
    subscription=os.environ["AZURE_SPEECH_KEY"],
    region=os.environ["AZURE_SPEECH_REGION"]
)
speech_config.set_speech_synthesis_output_format(
    speechsdk.SpeechSynthesisOutputFormat.Riff24Khz16BitMonoPcm
)

VOICE_MAP = {
    "en": "en-US-AndrewMultilingualNeural",
    "he": "he-IL-AvriNeural",
    "es": "es-ES-AlvaroNeural",
    "fr": "fr-FR-HenriNeural",
}

def synthesize(ssml: str, lang: str, output_path: str) -> None:
    """Synthesize SSML to audio file."""
    audio_config = speechsdk.audio.AudioOutputConfig(filename=output_path)
    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config,
        audio_config=audio_config
    )
    result = synthesizer.speak_ssml_async(ssml).get()
    if result.reason == speechsdk.ResultReason.SynthesizingAudioCompleted:
        print(f"✅ [{lang}] Audio saved: {output_path}")
    else:
        print(f"❌ [{lang}] Synthesis failed: {result.cancellation_details.error_details}")

# Usage
for lang, voice in VOICE_MAP.items():
    with open(f"templates/ssml-{lang}.xml") as f:
        ssml = f.read()
    synthesize(ssml, lang, f"output/daily-news-{lang}.wav")
```

### PowerShell one-liner (Azure CLI test)

```powershell
# Test Azure Speech subscription is active
az cognitiveservices account list --resource-group squad-rg --query "[?kind=='SpeechServices'].{name:name, sku:sku.name, location:location}" -o table
```

---

## 6. Quality vs. Cost Decision Matrix

| Scenario | Recommended Configuration | Monthly Cost (est.) |
|----------|--------------------------|---------------------|
| **MVP / Proof of concept** | All 4 languages: Standard Neural | < $1/month |
| **Production: Cost-optimized** | EN+HE: Dragon HD, ES+FR: Standard | ~$5/month |
| **Production: Max quality** | All 4 languages: Dragon HD | ~$15/month |
| **Premium: Branded voice** | HE+EN: Dragon HD + SeedVC cloning | ~$5/month + GPU time |

**Recommended starting point:** Cost-optimized production configuration.  
**Escalate to @picard** if budget ceiling or long-term contract with Azure needs to be established.

---

## 7. Voice Persona Consistency Guidelines

To maintain consistent voice identity across daily episodes:

1. **Pin the voice version** — Azure voice models can be updated. Specify `version` in SSML if consistency across months matters
2. **Lock SSML parameters** — Keep `rate`, `pitch`, and `styledegree` identical across all episodes for a language
3. **Brand the intro** — Record a single human-voiced intro ("You're watching [Channel Name]") and prepend it — this anchors brand identity without TTS drift
4. **SeedVC for Hebrew** — If using SeedVC voice conversion, always use the same reference file (`dotan-voice-sample.mp3`) and same SeedVC parameters (steps=10, cfg=3.0) to avoid voice drift between episodes

---

## 8. Research Basis (Hebrew)

The Hebrew recommendations are directly backed by quantitative testing in this repository:

| Experiment Set | Files | Key Finding |
|---------------|-------|-------------|
| Dragon HD voices | `azure-he-dragonhd-*.mp3` (24 files) | Andrew Dragon HD best male voice; Ava best female; newscast-casual style optimal |
| Quality leaderboard | `podcast_quality_leaderboard.csv` | `phonikud-neural` pipeline (Avri-based) top resemblyzer score: **0.9397** |
| Pipeline comparison | `COSYVOICE2_HEBREW_EVAL.md` | Azure TTS + SeedVC confirmed best production pipeline; CosyVoice 2 not yet viable for Hebrew |
| Style testing | `azure-he-avri-style-*.mp3` | `newscast` > `chat` > `customerservice` for news delivery |
| Multilingual voices | `azure-he-multilingual-*.mp3` | Andrew/Ava multilingual work for Hebrew but require higher budget |

**Conclusion:** `he-IL-AvriNeural` with `newscast` style is the optimal production voice for Hebrew YouTube news. Dragon HD multilingual is the upgrade path when quality becomes the primary concern over cost.

---

## 9. Related Files

| File | Purpose |
|------|---------|
| `HEBREW_PODCAST_METHODS.md` | Method comparison for Hebrew podcast generation |
| `COSYVOICE2_HEBREW_EVAL.md` | Alternative TTS model evaluation for Hebrew |
| `podcast_quality_leaderboard.csv` | Quantitative quality scores for 80+ Hebrew TTS experiments |
| `docs/voice-cloning-research.md` | Voice cloning options survey (open-source + commercial) |
| `docs/content-pipeline-overview.md` | Content pipeline architecture (upstream of this document) |
| `dotan-voice-sample.mp3` | Male Hebrew voice reference for SeedVC |
| `shahar-voice-sample.mp3` | Alternative male Hebrew voice reference |
| `azure-he-dragonhd-andrew-newscast-casual.mp3` | Best Dragon HD Hebrew test sample |

---

*Document maintained by Seven (Squad Research Agent) | Issue #811*
