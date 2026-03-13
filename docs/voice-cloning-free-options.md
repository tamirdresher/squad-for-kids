# Free Voice Cloning Options for Hebrew Podcasts

**Date:** 2026-03-14
**Author:** Seven (Research & Docs)
**Status:** 🔬 Research Complete
**Builds on:** `docs/voice-cloning-research.md`, `scripts/voice-clone-podcast.py`

---

## Executive Summary

We need voice cloning for Hebrew podcasts without paying ElevenLabs or similar services.
After extensive research, **three approaches stand out as immediately viable**:

| Rank | Approach | Hebrew? | Cost | Voice Cloning Quality | Setup Difficulty |
|------|----------|---------|------|-----------------------|------------------|
| 🥇 | **Chatterbox Multilingual** (Resemble AI) | ✅ Native | FREE | 9/10 | Medium (needs GPU) |
| 🥈 | **edge-tts → OpenVoice V2** pipeline | ✅ Via pipeline | FREE | 7/10 | Medium |
| 🥉 | **edge-tts → RVC** pipeline | ✅ Via pipeline | FREE | 8/10 | Medium-Hard |
| 🏅 | **Azure Personal Voice** | ✅ Native | Free tier* | 9/10 | Easy (needs approval) |

**Bottom line:** Chatterbox Multilingual is the clear winner — it natively supports Hebrew,
has zero-shot voice cloning from a 3–10 second sample, MIT licensed, and preferred over
ElevenLabs 63.75% of the time in blind tests.

> **RECOMMENDED IMMEDIATE ACTION:** Install `chatterbox-tts` and test Hebrew voice cloning
> with Avri/Hila reference samples. If no GPU is available on DevBox, use the
> edge-tts → OpenVoice V2 pipeline as fallback.

---

## Table of Contents

1. [Microsoft / Azure Options](#1-microsoft--azure-options)
2. [Open Source Voice Cloning Models](#2-open-source-voice-cloning-models)
3. [Voice Conversion Approach](#3-voice-conversion-approach-recommended-for-cpu)
4. [Hebrew-Specific Projects & Considerations](#4-hebrew-specific-projects--considerations)
5. [DIY Fine-Tuning Approach](#5-diy-fine-tuning-approach)
6. [Comparison Matrix](#6-full-comparison-matrix)
7. [Recommended Implementation Plan](#7-recommended-implementation-plan)

---

## 1. Microsoft / Azure Options

### 1.1 Azure Personal Voice ⭐ BEST MICROSOFT OPTION

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ✅ Yes — among 100+ supported languages |
| **Voice Cloning** | ✅ Zero-shot from ~1 minute of speech |
| **Training Time** | < 5 seconds |
| **Model** | DragonV2.1Neural (upgraded 2025) |
| **Free Tier** | 0.5M characters/month free, 1 model hosted free |
| **Quality** | 9/10 — enterprise-grade, very expressive |
| **API Access** | ⚠️ Requires approval via intake form |
| **Multilingual** | Cloned voice can speak 90+ languages |

**How it works:**
1. Record a verbal consent statement + ~1 minute of speech
2. Upload to Azure Speech Studio
3. System creates a zero-shot voice clone in seconds
4. Synthesize Hebrew text using the cloned voice

**Catch:** API access beyond the Speech Studio demo requires Microsoft Responsible AI
approval. For internal/research use at Microsoft, this should be straightforward to obtain.

**Cost estimate:** Within free tier for podcast volumes (~50K chars/episode = 10 episodes/month free).

**Links:**
- [Personal Voice Overview](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/personal-voice-overview)
- [Azure Speech Pricing](https://azure.microsoft.com/en-us/pricing/details/speech/)

### 1.2 Azure Custom Neural Voice Lite

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ✅ Yes |
| **Voice Cloning** | Record 20–50 scripts (~5 minutes) |
| **Free Tier** | Training < 1 compute hour; 0.5M chars synthesis free/month |
| **Quality** | 7/10 — moderate (limited training data) |
| **Use Restriction** | Demo/evaluation only without further application |

**Verdict:** More effort than Personal Voice for worse results. Only useful if Personal
Voice approval is denied.

### 1.3 Azure Custom Neural Voice Professional

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ✅ Yes |
| **Requirements** | 300–2000 professionally recorded utterances |
| **Training** | 20–40 compute hours |
| **Quality** | 10/10 — production-grade |
| **Cost** | $$$ — not free, requires approval |

**Verdict:** Overkill. Reserve for production if podcast becomes a real product.

### 1.4 Microsoft VALL-E / VALL-E X

| Aspect | Details |
|--------|---------|
| **Official Release** | ❌ Not released by Microsoft |
| **Community Impl.** | ✅ Plachtaa/VALL-E-X on GitHub (MIT) |
| **Languages** | EN, ZH, JA only |
| **Hebrew Support** | ❌ Not supported |
| **GPU Required** | Yes (CUDA, PyTorch 2.0+) |

**Verdict:** Not viable for Hebrew. The community implementation only supports 3 languages,
and Microsoft hasn't released official code or weights.

---

## 2. Open Source Voice Cloning Models

### 2.1 Chatterbox Multilingual ⭐⭐⭐ TOP RECOMMENDATION

| Aspect | Details |
|--------|---------|
| **Developer** | Resemble AI |
| **Hebrew Support** | ✅ **Native — Hebrew is one of 23 supported languages** |
| **Voice Cloning** | ✅ Zero-shot from 3–10 seconds of audio |
| **Quality** | 9/10 — preferred over ElevenLabs 63.75% in blind tests |
| **License** | MIT — free for commercial use |
| **Emotion Control** | ✅ Controllable exaggeration parameter |
| **Cross-Language** | ✅ Clone voice in English → speak Hebrew |
| **Watermarking** | Built-in PerTh neural watermark |
| **GPU Required** | Yes — 8–16 GB VRAM recommended |
| **CPU Feasible** | Slow but possible for batch generation |
| **Install** | `pip install chatterbox-tts` |
| **Time to Demo** | ~30 minutes (with GPU) |

**Why this is the winner:**
- **Hebrew is natively supported** — no fine-tuning needed
- Quality rivals ElevenLabs (blind test data proves this)
- Zero-shot: just provide 3–10s of Avri/Hila's voice
- MIT license, fully open source
- Emotion control for podcast expressiveness
- Cross-lingual: clone a voice from any language, output Hebrew

**Quick start code:**
```python
from chatterbox.mtl_tts import ChatterboxMultilingualTTS
import torchaudio as ta

model = ChatterboxMultilingualTTS.from_pretrained(device="cuda")  # or "cpu"

wav = model.generate(
    "שלום לכולם! ברוכים הבאים לפודקאסט מפתחים מחוץ לקופסא",
    language_id="he",
    audio_prompt_path="avri_sample.wav",  # 3-10s reference
    exaggeration=0.5,
    cfg_weight=0.5,
)
ta.save("avri_hebrew.wav", wav, model.sr)
```

**Links:**
- [GitHub](https://github.com/resemble-ai/chatterbox)
- [Hugging Face](https://huggingface.co/ResembleAI/chatterbox)
- [PyPI](https://pypi.org/project/chatterbox-tts/)

### 2.2 F5-TTS

| Aspect | Details |
|--------|---------|
| **Developer** | Community (SWivid) |
| **Hebrew Support** | ⚠️ Not native — needs fine-tuning |
| **Voice Cloning** | ✅ Zero-shot from few seconds |
| **Quality** | 8/10 |
| **License** | MIT |
| **GPU Required** | Yes |
| **Cross-Lingual** | ✅ Via 2026 Cross-Lingual extension paper |
| **Time to Demo** | ~1 hour |

**Notes:** Recent paper (arXiv:2509.14579) extends F5-TTS for language-agnostic voice
cloning. Hebrew possible but requires data prep and fine-tuning. Good alternative if
Chatterbox doesn't meet needs.

**Links:**
- [GitHub](https://github.com/SWivid/F5-TTS)
- [Cross-Lingual Paper](https://arxiv.org/abs/2509.14579)

### 2.3 OpenVoice V2

| Aspect | Details |
|--------|---------|
| **Developer** | MyShell + MIT |
| **Hebrew Support** | ⚠️ Not native (EN, ES, FR, ZH, JA, KO) — but zero-shot cross-lingual works |
| **Voice Cloning** | ✅ Tone color transfer from short sample |
| **Quality** | 7/10 |
| **License** | MIT |
| **GPU Required** | Recommended, CPU possible (slower) |
| **Best Use** | Tone color converter on top of edge-tts Hebrew output |
| **Time to Demo** | ~1 hour |

**The pipeline approach:**
1. Generate Hebrew speech using edge-tts (high quality, native Hebrew)
2. Apply OpenVoice V2 tone color converter to match reference speaker
3. Output retains Hebrew pronunciation + target speaker's voice characteristics

**Links:**
- [GitHub](https://github.com/myshell-ai/OpenVoice)
- [Hugging Face](https://huggingface.co/myshell-ai/OpenVoiceV2)

### 2.4 GPT-SoVITS

| Aspect | Details |
|--------|---------|
| **Developer** | RVC-Boss |
| **Hebrew Support** | ⚠️ Not native (EN, ZH, JA, KO, Cantonese) — extensible with data |
| **Voice Cloning** | ✅ Zero-shot (5s) or few-shot (1 min) |
| **Quality** | 8/10 |
| **License** | MIT |
| **GPU Required** | Yes (6+ GB VRAM) |
| **WebUI** | ✅ Built-in web interface |
| **Time to Demo** | ~2 hours |

**Notes:** Very popular for voice cloning. Hebrew would require custom training data
and text normalization resources. The WebUI makes experimentation easier. v4 (2025)
improved cross-lingual capabilities.

**Links:**
- [GitHub](https://github.com/RVC-Boss/GPT-SoVITS)

### 2.5 CosyVoice 2.0

| Aspect | Details |
|--------|---------|
| **Developer** | FunAudioLLM (Alibaba) |
| **Hebrew Support** | ❌ Not listed (ZH, EN, JA, KO, DE, RU, FR, IT, ES) |
| **Voice Cloning** | ✅ Zero-shot cross-lingual |
| **Quality** | 8/10 |
| **License** | Apache 2.0 |
| **Streaming** | ✅ ~150ms latency |
| **GPU Required** | Yes |

**Verdict:** Excellent model but Hebrew not supported. Would require significant
fine-tuning effort.

### 2.6 Coqui TTS / XTTS v2

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ❌ Not in 17 supported languages |
| **Voice Cloning** | ✅ From 3–6s sample |
| **Quality** | 7/10 |
| **License** | MPL 2.0 |
| **Fine-tuning** | ✅ Documented process for new languages |
| **Time to Demo** | Hours–Days (Hebrew fine-tuning needed) |

**Verdict:** Was the previous go-to option. Surpassed by Chatterbox in every dimension
for Hebrew use cases.

### 2.7 Bark (Suno)

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ✅ Listed among 13+ languages |
| **Voice Cloning** | ❌ Not native — preset voices only; community hacks exist |
| **Quality** | 6/10 for Hebrew |
| **License** | MIT |
| **GPU Required** | Recommended |

**Verdict:** Supports Hebrew text but cannot clone voices out-of-box. Quality for Hebrew
lags behind English. Not suitable for our use case.

### 2.8 Tortoise TTS

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ⚠️ Mainly English; limited multilingual |
| **Voice Cloning** | ✅ Excellent quality from short samples |
| **Quality** | 9/10 for English, 5/10 for Hebrew |
| **CPU Performance** | ❌ Extremely slow (minutes–hours per sentence) |
| **License** | Apache 2.0 |

**Verdict:** Best quality for English but impractical for Hebrew. CPU inference is
brutally slow. Skip.

### 2.9 VITS / VITS2 / Bert-VITS2

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ⚠️ Via fine-tuning (facebook/mms-tts-heb exists for base VITS) |
| **Voice Cloning** | Via YourTTS extension — zero-shot with 1–3 min data |
| **Quality** | 7/10 |
| **Fine-tuning** | ✅ Well documented |

**Verdict:** The `facebook/mms-tts-heb` model provides a Hebrew VITS base, but voice
cloning requires additional fine-tuning work. Not as turnkey as Chatterbox.

### 2.10 Piper TTS

| Aspect | Details |
|--------|---------|
| **Hebrew Support** | ⚠️ Community models may exist |
| **Voice Cloning** | ❌ No cloning — pre-trained voices only |
| **Quality** | 6/10 |
| **CPU Optimized** | ✅ Very lightweight and fast |

**Verdict:** Great for lightweight TTS but has no voice cloning capability. Not relevant
for our voice cloning goal.

---

## 3. Voice Conversion Approach (Recommended for CPU)

**This is the best approach if we don't have GPU access on DevBox.**

The idea: generate high-quality Hebrew speech with edge-tts (which we already use
successfully), then convert the voice characteristics to match a target speaker.

### 3.1 edge-tts → RVC Pipeline ⭐ BEST FOR CPU-CONSTRAINED

```
Hebrew Text → edge-tts (Hebrew voices) → WAV → RVC Voice Conversion → Cloned Voice WAV
```

| Aspect | Details |
|--------|---------|
| **Hebrew TTS** | ✅ edge-tts handles Hebrew perfectly |
| **Voice Conversion** | RVC converts speaker identity |
| **Training Data** | 5–10 min of target speaker audio |
| **Quality** | 8/10 — up to 98% similarity per benchmarks |
| **CPU Training** | ⚠️ Hours–days (GPU recommended) |
| **CPU Inference** | ✅ Feasible but slow (~minutes per segment) |
| **Language Agnostic** | ✅ RVC doesn't care about language |

**Why this works for Hebrew:**
- edge-tts already handles Hebrew phonetics, prosody, and RTL text perfectly
- RVC only converts the "voice identity" (timbre, formants) — not the language content
- The Hebrew pronunciation stays correct while the voice changes to match our target

**Steps:**
1. Collect 5–10 minutes of Avri/Hila voice recordings
2. Train an RVC model for each speaker (requires GPU or cloud GPU session)
3. Generate Hebrew podcast segments with edge-tts
4. Run each segment through RVC inference to apply voice identity
5. Concatenate final podcast

**Tools:**
- [RVC WebUI](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI)
- [rvc-tts-pipeline](https://github.com/JarodMica/rvc-tts-pipeline) — pre-built TTS→RVC pipeline
- [RVC PyPI package](https://pypi.org/project/rvc/)

### 3.2 edge-tts → OpenVoice V2 Pipeline

```
Hebrew Text → edge-tts → WAV → OpenVoice Tone Color Converter → Styled Voice WAV
```

| Aspect | Details |
|--------|---------|
| **Training Needed** | None — zero-shot from reference audio |
| **Quality** | 7/10 |
| **CPU Feasible** | ✅ Yes (slower than GPU) |
| **Advantage** | No training step at all |

**This was already identified in our previous research** (`docs/voice-cloning-research.md`)
as the next step. The advantage over RVC is that no training is needed — just provide a
reference audio clip and OpenVoice transfers the tone color.

### 3.3 edge-tts → So-VITS-SVC

Similar to RVC but originally designed for singing voice conversion. Works for speech too.
Available via [so-vits-svc-fork](https://so-vits-svc-fork.readthedocs.io/).

**Verdict:** RVC is preferred — faster training (2.5–4x), better quality, more active community.

---

## 4. Hebrew-Specific Projects & Considerations

### 4.1 Hebrew TTS Projects

| Project | Type | Notes |
|---------|------|-------|
| **Phonikud** | G2P Converter | Hebrew grapheme-to-phoneme with IPA, stress handling, vocal shva. Integrates with Piper TTS. [GitHub](https://github.com/thewh1teagle/phonikud) |
| **HebTTS** | Full TTS | Diacritic-free Hebrew TTS from Hebrew University. Uses language models on discrete speech representations. [GitHub](https://github.com/slp-rl/HebTTS) |
| **facebook/mms-tts-heb** | VITS Model | Meta's Hebrew TTS model on Hugging Face. Direct inference available. [HF](https://huggingface.co/facebook/mms-tts-heb) |
| **israwave** | TTS Package | Independent Hebrew TTS, available on PyPI. [PyPI](https://pypi.org/project/israwave/) |
| **edge-tts (he-IL)** | Cloud TTS | Microsoft Edge Neural voices: AvriNeural (male), HilaNeural (female). **Currently our best Hebrew TTS.** |

### 4.2 Hebrew Phoneme Challenges

| Challenge | Impact | Mitigation |
|-----------|--------|------------|
| **Right-to-left text** | Most TTS pipelines assume LTR | edge-tts handles RTL natively; Chatterbox supports it via language_id="he" |
| **Niqqud (vowel marks)** | Most Hebrew text lacks diacritics | Phonikud and HebTTS handle undiacritized text; edge-tts also handles it |
| **Stress patterns** | Hebrew stress is penultimate by default with many exceptions | Phonikud specifically handles stress; edge-tts has this built-in |
| **Vocal Shva** | Hebrew has both silent and voiced shva | Phonikud handles this; most other systems approximate |
| **Phoneme inventory** | Pharyngeal consonants (ח, ע), emphatics | edge-tts and Chatterbox handle these correctly |

### 4.3 Which Models Actually Handle Hebrew?

| Model | Hebrew Text→Phoneme | Hebrew Synthesis | Quality |
|-------|---------------------|------------------|---------|
| edge-tts | ✅ Built-in | ✅ Excellent | 8/10 |
| Chatterbox | ✅ Built-in | ✅ Good–Excellent | 8–9/10 |
| Bark | ✅ Basic | ⚠️ Fair | 5–6/10 |
| facebook/mms-tts-heb | ✅ Built-in | ✅ Good | 7/10 |
| HebTTS | ✅ Built-in | ✅ Good | 7/10 |
| All others | ❌ Requires work | ❌ Requires fine-tuning | Varies |

---

## 5. DIY Fine-Tuning Approach

If none of the above meet quality needs, we can fine-tune a multilingual model.

### 5.1 Data Requirements

| Approach | Training Data | Quality Expected | Time to Train (GPU) | Time to Train (CPU) |
|----------|---------------|------------------|---------------------|---------------------|
| Zero-shot (Chatterbox) | 3–10 seconds | 8–9/10 | N/A (inference only) | N/A |
| Few-shot (GPT-SoVITS) | 1–5 minutes | 7–8/10 | 30–60 min | Not practical |
| RVC model | 5–10 minutes | 8/10 | 1–2 hours | 1–3 days |
| Full fine-tune (XTTS) | 30+ minutes | 9/10 | 4–8 hours | Not practical |
| Custom Neural Voice | 5+ minutes (Lite) | 7–9/10 | Minutes (Azure cloud) | N/A |

### 5.2 Can We Train on CPU?

| Task | CPU Feasible? | Expected Time |
|------|---------------|---------------|
| Chatterbox inference | ✅ Slow but works | ~1–5 min per sentence |
| RVC inference | ✅ Slow | ~minutes per segment |
| RVC training | ⚠️ Technically yes | Days for 10 min dataset |
| GPT-SoVITS training | ❌ Not practical | Would take weeks |
| XTTS fine-tuning | ❌ Not practical | Would take weeks |

### 5.3 Minimum Viable Demo

**Fastest path to a working demo (< 1 hour):**
1. `pip install chatterbox-tts` (on a GPU machine or Colab)
2. Record/extract 10 seconds of target voice (Avri/Hila)
3. Run the 6-line Python code from Section 2.1
4. Listen to Hebrew output with cloned voice

**Fastest path on CPU-only DevBox (< 2 hours):**
1. Generate Hebrew with edge-tts (already working — `scripts/render-hebrew-podcast.py`)
2. Install OpenVoice V2 (`pip install openvoice` + download models)
3. Apply tone color converter using reference audio
4. Evaluate quality

---

## 6. Full Comparison Matrix

| Model | Cost | Hebrew | Cloning Quality | CPU OK? | GPU VRAM | Setup Time | License |
|-------|------|--------|-----------------|---------|----------|------------|---------|
| **Chatterbox Multilingual** | FREE | ✅ Native | 9/10 | Slow | 8–16 GB | 30 min | MIT |
| **Azure Personal Voice** | Free tier* | ✅ Native | 9/10 | N/A (cloud) | N/A | 1 hour | Proprietary |
| **edge-tts → RVC** | FREE | ✅ Pipeline | 8/10 | Inference only | 4+ GB | 2–4 hours | MIT/GPL |
| **edge-tts → OpenVoice V2** | FREE | ✅ Pipeline | 7/10 | ✅ Yes | 4+ GB | 1 hour | MIT |
| **F5-TTS** | FREE | ⚠️ Fine-tune | 8/10 | No | 8+ GB | Days | MIT |
| **GPT-SoVITS** | FREE | ⚠️ Fine-tune | 8/10 | No | 6+ GB | Hours | MIT |
| **CosyVoice 2.0** | FREE | ❌ Not listed | 8/10 | No | 4+ GB | Hours | Apache 2.0 |
| **Coqui XTTS v2** | FREE | ❌ Fine-tune | 7/10 | No | 8+ GB | Days | MPL 2.0 |
| **Bark** | FREE | ✅ Basic | 4/10 (no clone) | No | 8+ GB | 1 hour | MIT |
| **VITS/mms-tts-heb** | FREE | ✅ Via Meta | 7/10 | Inference only | 4+ GB | 1 hour | MIT |
| **Tortoise TTS** | FREE | ⚠️ Limited | 5/10 Hebrew | ❌ Very slow | 8+ GB | Hours | Apache 2.0 |
| **Piper TTS** | FREE | ⚠️ Community | N/A (no clone) | ✅ Fast | None | 30 min | MIT |
| **Azure CNV Lite** | Free tier | ✅ Yes | 7/10 | N/A | N/A | 1 hour | Proprietary |
| **Azure CNV Pro** | $$$ | ✅ Yes | 10/10 | N/A | N/A | Days | Proprietary |

*Azure free tier: 0.5M characters/month, requires Responsible AI approval for API access.

---

## 7. Recommended Implementation Plan

### Phase 1: Immediate (This Week) — Chatterbox Test

**Goal:** Get a working Hebrew voice-cloned podcast demo.

```bash
# On a GPU machine (Colab, Azure VM, or any CUDA-capable box)
pip install chatterbox-tts torchaudio

# Test Hebrew synthesis
python -c "
from chatterbox.mtl_tts import ChatterboxMultilingualTTS
import torchaudio as ta
model = ChatterboxMultilingualTTS.from_pretrained(device='cuda')
wav = model.generate(
    'שלום! זהו מבחן של שכפול קולות בעברית',
    language_id='he',
    audio_prompt_path='avri_sample.wav',
    exaggeration=0.5,
)
ta.save('test_hebrew_clone.wav', wav, model.sr)
print('Done!')
"
```

**Requires:** 10-second voice sample from each host, GPU access (even a free Colab notebook).

### Phase 2: CPU Fallback (This Week) — OpenVoice Pipeline

If no GPU is available, upgrade our existing edge-tts pipeline:

1. Keep `scripts/voice-clone-podcast.py` as the main entry point
2. Add OpenVoice V2 tone color conversion as a post-processing step
3. Reference audio samples for Avri and Hila

### Phase 3: Best Quality (Next Sprint) — RVC Training

1. Collect 5–10 minutes of each host's voice
2. Train RVC models (use Colab or Azure GPU VM)
3. Integrate into `voice-clone-podcast.py` as a new backend
4. Pipeline: edge-tts Hebrew → RVC voice conversion → final audio

### Phase 4: Enterprise (Future) — Azure Personal Voice

1. Apply for Azure Personal Voice API access
2. Record consent statements from hosts
3. Create personal voice profiles
4. Integrate Azure Speech SDK into podcast pipeline

---

## Appendix A: What We Already Have

Our existing infrastructure (`scripts/voice-clone-podcast.py`) already supports:
- ✅ edge-tts Hebrew voices (AvriNeural + HilaNeural)
- ✅ Audio style transfer (pitch, formant, warmth, breathiness)
- ✅ Reference audio matching (F0 analysis + pitch alignment)
- ✅ ElevenLabs backend (ready, needs API key)
- ⬜ OpenVoice backend (placeholder exists)
- ⬜ Chatterbox backend (new — needs implementation)
- ⬜ RVC backend (new — needs implementation)

## Appendix B: GPU Access Options (Free/Cheap)

| Option | GPU | Free? | Duration |
|--------|-----|-------|----------|
| Google Colab (free) | T4 (16GB) | ✅ Yes | ~4 hours/session |
| Kaggle Notebooks | T4/P100 | ✅ Yes | 30 hours/week |
| Azure ML (with credits) | Various | With credits | Flexible |
| Lightning AI | T4 | ✅ Free tier | 22 hours/month |
| RunPod (spot) | Various | ~$0.20/hr | As needed |

## Appendix C: Key Links

| Resource | URL |
|----------|-----|
| Chatterbox GitHub | https://github.com/resemble-ai/chatterbox |
| OpenVoice V2 GitHub | https://github.com/myshell-ai/OpenVoice |
| RVC WebUI | https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI |
| F5-TTS | https://github.com/SWivid/F5-TTS |
| GPT-SoVITS | https://github.com/RVC-Boss/GPT-SoVITS |
| Phonikud (Hebrew G2P) | https://github.com/thewh1teagle/phonikud |
| HebTTS | https://github.com/slp-rl/HebTTS |
| facebook/mms-tts-heb | https://huggingface.co/facebook/mms-tts-heb |
| Azure Personal Voice | https://learn.microsoft.com/en-us/azure/ai-services/speech-service/personal-voice-overview |
| Azure Speech Pricing | https://azure.microsoft.com/en-us/pricing/details/speech/ |
| ClonEval Benchmark | https://arxiv.org/html/2504.20581v2 |
| rvc-tts-pipeline | https://github.com/JarodMica/rvc-tts-pipeline |

---

*Research conducted 2026-03-14. Voice AI is moving fast — re-evaluate quarterly.*
