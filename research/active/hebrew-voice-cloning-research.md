# Hebrew Voice Cloning — Deep Research Report

**Researcher:** Seven (Research & Analytics)  
**Requested by:** Tamir Dresher  
**Date:** 2025-07-15  
**Status:** COMPLETE

---

## Executive Summary

Hebrew voice cloning is a genuinely hard problem. Hebrew is underrepresented in TTS/voice cloning training data, most open-source models don't natively support it, and the few that do are recent (2024–2025). After evaluating 15+ solutions, **the top three recommendations are:**

| Rank | Solution | Hebrew? | Voice Cloning? | Runs on RTX 500 Ada (4GB)? | Effort |
|------|----------|---------|----------------|---------------------------|--------|
| 🥇 | **Chatterbox Multilingual** (Resemble AI) | ✅ Native | ✅ Zero-shot (5s) | ⚠️ Tight but possible | Low |
| 🥈 | **OpenVoice V2 + Phonikud pipeline** | ⚠️ Cross-lingual | ✅ Tone cloning | ✅ Yes (~2–3GB) | Medium |
| 🥉 | **GPT-SoVITS V3** (with Hebrew fine-tuning) | ⚠️ Via fine-tune | ✅ Few-shot (1min) | ⚠️ Tight | High |

**Critical discovery: Chatterbox Multilingual by Resemble AI explicitly lists Hebrew (he) among 23 supported languages with zero-shot voice cloning.** This is the strongest candidate.

---

## Hardware Context

**NVIDIA RTX 500 Ada Generation:**
- **VRAM:** 4 GB GDDR6 (64-bit bus)
- **CUDA Cores:** 2048
- **Tensor Cores:** 64 (4th gen, FP8/INT8)
- **FP32:** ~9.2 TFLOPS
- **TDP:** 35–60W

**Impact:** 4GB VRAM is a significant constraint. Most large TTS models (>1B params) need 6–8GB+. We must target smaller models, quantized inference, or CPU fallback.

---

## What We Already Tried (and Why It Failed)

| Tool | Problem |
|------|---------|
| **edge-tts** | Generic Microsoft voices, no voice cloning at all |
| **F5-TTS** | Excellent voice cloning, but English/Chinese only. Hebrew text → English-sounding gibberish |
| **XTTS v2** (Arabic hack) | Hebrew ≠ Arabic. Phonetics are different. Voices don't match reference |

---

## Solution-by-Solution Analysis

### 1. 🥇 Chatterbox Multilingual (Resemble AI)

**Verdict: BEST OPTION — Native Hebrew + Zero-Shot Voice Cloning**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ✅ **Native** — Hebrew (he) is one of 23 explicitly listed languages |
| **Voice cloning** | ✅ Zero-shot from ~5 seconds of reference audio |
| **Cross-lingual** | ✅ Clone English voice → speak Hebrew (and vice versa) |
| **Emotion control** | ✅ Emotion exaggeration/intensity parameters |
| **License** | MIT (fully open source) |
| **Quality** | Preferred over ElevenLabs 63.75% of the time in blind A/B tests |
| **VRAM needs** | ~3–4GB (tight on RTX 500 Ada, may need CPU offload) |
| **Windows setup** | `pip install chatterbox-tts` — straightforward |

**GitHub:** https://github.com/resemble-ai/chatterbox  
**HuggingFace:** https://huggingface.co/ResembleAI/chatterbox  
**PyPI:** `pip install tts-webui.chatterbox-tts`

**Quick test code:**
```python
from chatterbox.tts import ChatterboxMultilingualTTS
model = ChatterboxMultilingualTTS.from_pretrained()
wav = model.generate(
    text="שלום, אני מפתח מחוץ לקופסא",
    audio_prompt_path="dotan_reference.wav",
    language="he"
)
```

**Why this is #1:**
- Only open-source model that **explicitly** supports Hebrew + voice cloning
- Zero-shot: no fine-tuning needed
- Includes neural watermarking (PerTh) for responsible use
- Active development (released ~Sep 2025)

**Risks:**
- 4GB VRAM may be tight — test with `device="cpu"` as fallback
- New model, limited community feedback on Hebrew quality specifically
- May need Phonikud for better Hebrew text preprocessing

---

### 2. 🥈 OpenVoice V2 (MyShell.ai + MIT)

**Verdict: STRONG RUNNER-UP — Cross-lingual voice cloning, Hebrew experimental**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ⚠️ Not native, but designed for "languages absent from training data" |
| **Voice cloning** | ✅ Instant tone-color cloning from short reference |
| **Architecture** | MeloTTS base → Tone Color Converter |
| **License** | MIT |
| **VRAM needs** | ~2–3GB (fits on RTX 500 Ada) |
| **Windows setup** | Well-documented, pip install |

**GitHub:** https://github.com/myshell-ai/OpenVoice  
**HuggingFace:** https://huggingface.co/myshell-ai/OpenVoiceV2  
**Paper:** https://arxiv.org/abs/2312.01479

**How it works:**
1. MeloTTS generates base speech (in a supported language)
2. Tone Color Converter transfers the reference speaker's voice characteristics
3. Cross-lingual: the voice "speaks" the target language with the reference timbre

**Challenge for Hebrew:**
- MeloTTS doesn't natively support Hebrew, so the base TTS output may be poor
- **Potential solution:** Use Phonikud to convert Hebrew text → IPA → feed to MeloTTS as phoneme input
- The tone color converter should work regardless of language

**VRAM advantage:** Lightweight enough to run on our hardware.

---

### 3. 🥉 GPT-SoVITS V3

**Verdict: POWERFUL BUT REQUIRES HEBREW FINE-TUNING**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ⚠️ Not native (EN/CN/JP/KR only). Cross-lingual inference possible |
| **Voice cloning** | ✅ Few-shot (1 min) or zero-shot (5–10s) |
| **Fine-tuning** | ✅ WebUI for training on custom data |
| **License** | MIT |
| **VRAM needs** | ~4–6GB (tight on 4GB) |
| **Windows setup** | Prepackaged Windows binaries available |

**GitHub:** https://github.com/RVC-Boss/GPT-SoVITS

**Approach for Hebrew:**
1. Use Phonikud to generate IPA phonemes from Hebrew text
2. Collect 1+ minutes of transcribed Hebrew speech from target speakers
3. Fine-tune on Hebrew data using WebUI
4. Generate with trained model

**Pros:** Very high quality voice cloning for supported languages  
**Cons:** Significant effort to add Hebrew; 4GB VRAM may not suffice for training

---

### 4. F5-TTS (Cross-Lingual Fork)

**Verdict: PROMISING ARCHITECTURE, BUT NEEDS RETRAINING FOR HEBREW**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not native (EN/CN only). Architecture is language-agnostic |
| **Voice cloning** | ✅ Zero-shot, high quality |
| **Cross-lingual paper** | "Cross-Lingual F5-TTS" (arXiv:2509.14579) shows language-agnostic approach |
| **VRAM needs** | ~4–6GB |

**GitHub:** https://github.com/SWivid/F5-TTS  
**Paper:** https://arxiv.org/abs/2509.14579

**Key insight:** The "Cross-Lingual F5-TTS" paper demonstrates that the architecture CAN support any language with sufficient training data. However, no pretrained Hebrew model exists.

**Not practical** for our immediate needs without significant training effort.

---

### 5. Bark (Suno AI)

**Verdict: NO — Neither Hebrew nor voice cloning**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not listed (13 languages supported, Hebrew not among them) |
| **Voice cloning** | ❌ No custom voice cloning — only 100+ preset speakers |
| **License** | MIT |

**GitHub:** https://github.com/suno-ai/bark

Bark excels at expressive speech with laughter/sighing, but lacks both Hebrew and true voice cloning. **Not suitable.**

---

### 6. XTTS v2 (Coqui TTS)

**Verdict: NO HEBREW — Already tried, confirmed doesn't work**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not supported. 17 languages but no Hebrew |
| **Voice cloning** | ✅ Excellent for supported languages |
| **Arabic workaround** | ❌ Confirmed: sounds terrible for Hebrew |

Hebrew is not Arabic. Different phoneme inventory, different prosody, different script-to-sound mapping. The "language=ar" hack produces unintelligible output.

Fine-tuning XTTS v2 for Hebrew is theoretically possible but requires extensive Hebrew speech data and significant VRAM (8GB+).

---

### 7. CosyVoice (Alibaba)

**Verdict: NO HEBREW SUPPORT — 9 languages, not including Hebrew**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not in CosyVoice 2.0 or 3.0 |
| **Voice cloning** | ✅ Zero-shot, high quality |
| **Languages** | EN, CN, DE, ES, FR, IT, JP, KR, RU |
| **VRAM needs** | ~6–8GB (too large for RTX 500 Ada) |

**GitHub:** https://github.com/FunAudioLLM/CosyVoice  
**Paper:** https://arxiv.org/abs/2407.05407

Excellent model but both too large for our GPU and lacking Hebrew.

---

### 8. StyleTTS 2

**Verdict: POSSIBLE VIA FINE-TUNING, HIGH EFFORT**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ⚠️ Language-agnostic architecture. Requires Hebrew phonemizer + data |
| **Voice cloning** | ✅ Style transfer from reference audio |
| **Fine-tuning** | Needs 1+ hours of transcribed Hebrew speech |
| **VRAM needs** | ~4–6GB for inference, 8GB+ for training |

**GitHub:** https://github.com/yl4579/StyleTTS2

Would require: espeak-ng Hebrew phonemes OR Phonikud integration, Hebrew speech corpus, multi-hour training. High effort, uncertain outcome.

---

### 9. VALL-E X (Microsoft)

**Verdict: NO HEBREW, LIMITED OPEN IMPLEMENTATION**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ EN/CN/JP only in open-source version |
| **Voice cloning** | ✅ Zero-shot from 3–10s |
| **Open implementation** | Community fork by Plachtaa (not official Microsoft) |

**GitHub:** https://github.com/Plachtaa/VALL-E-X

Not practical for Hebrew without retraining.

---

### 10. VoiceCraft (Meta/FAIR)

**Verdict: NO HEBREW, ENGLISH-FOCUSED**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not supported |
| **VoiceCraft-X** | 11 languages planned (no Hebrew) |
| **Strength** | Speech *editing* (modifying existing audio) — unique capability |

**GitHub:** https://github.com/jasonppy/VoiceCraft  
**Paper:** https://arxiv.org/abs/2403.16973

---

### 11. MeloTTS

**Verdict: NO HEBREW, NO VOICE CLONING**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ EN/ES/FR/CN/JP/KR only |
| **Voice cloning** | ❌ No voice cloning capability |

**GitHub:** https://github.com/myshell-ai/MeloTTS

Used as a base in OpenVoice V2, but doesn't help alone for our use case.

---

### 12. Piper TTS

**Verdict: HEBREW TTS YES, VOICE CLONING VIA WORKAROUND**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ✅ Hebrew listed among 30+ languages |
| **Voice cloning** | ⚠️ Via qpclone pipeline (Qwen3-TTS → Piper fine-tune) |
| **VRAM needs** | Very low — runs on CPU, even Raspberry Pi |
| **Quality** | Lower than neural TTS models — more "robotic" |

**GitHub:** https://github.com/rhasspy/piper  
**qpclone:** https://github.com/whit3rabbit/qpclone

**Good for:** Lightweight Hebrew TTS. Not great for natural-sounding podcast voices.

---

### 13. WhisperSpeech

**Verdict: NO HEBREW YET — Still developing multilingual**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Currently EN/PL/FR only |
| **Voice cloning** | ✅ One-click cloning |
| **License** | Apache-2.0 |

**GitHub:** https://github.com/WhisperSpeech/WhisperSpeech

Promising architecture but too early for Hebrew.

---

### 14. Fish Speech / OpenAudio

**Verdict: HEBREW POSSIBLY EXPERIMENTAL, NO EXPLICIT SUPPORT**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ⚠️ Not officially listed. Uses LLM-based approach (no G2P rules) |
| **Voice cloning** | ✅ Zero-shot from 10–30s |
| **Training data** | 1M+ hours multilingual |
| **VRAM needs** | ~4–6GB |

**GitHub:** https://github.com/fishaudio/fish-speech  
**HuggingFace:** https://huggingface.co/fishaudio/fish-speech-1.5

The LLM-based approach (no grapheme-to-phoneme rules) means it *might* handle Hebrew better than rule-based systems. Worth testing but no guarantees.

---

### 15. Kokoro TTS

**Verdict: NO HEBREW**

| Attribute | Details |
|-----------|---------|
| **Hebrew support** | ❌ Not natively supported |
| **Voice cloning** | ✅ Via KokoClone |
| **Model size** | 82M params — very lightweight |

**GitHub:** https://github.com/hexgrad/kokoro

---

## Hebrew-Specific Resources

### Robo-Shaul — Hebrew Voice Clone Project

A dedicated Hebrew voice cloning project using Tacotron2 + HiFiGAN, trained to mimic Israeli journalist Shaul Amsterdamski.

**GitHub:** https://github.com/gabykh1/Robo-Shaul  
**Relevance:** Proof that Hebrew voice cloning IS possible. Code/methodology could be adapted for our speakers.

---

### Phonikud — Hebrew Grapheme-to-Phoneme (G2P)

**Critical infrastructure for ANY Hebrew TTS solution.**

| Attribute | Details |
|-----------|---------|
| **What it does** | Converts Hebrew text → fully specified IPA phonemes |
| **Handles** | Stress, vowel shva, diacritics, mixed Hebrew-English |
| **Performance** | Real-time, lightweight (ONNX models available) |
| **License** | CC BY 4.0 |
| **Install** | `pip install phonikud phonikud-onnx` |

**GitHub:** https://github.com/thewh1teagle/phonikud  
**Paper:** https://arxiv.org/abs/2506.12311  
**Dataset:** ILSpeech — expert-annotated Hebrew speech-to-IPA benchmark

**Why this matters:** Many TTS models fail on Hebrew because they can't properly convert Hebrew text to phonemes. Phonikud solves this. It should be integrated into any pipeline we build.

---

### Academic Research (Hebrew University, 2024)

#### HebTTS — Diacritic-Free Hebrew TTS
- **Authors:** Amit Roth, Arnon Turetzky, Yossi Adi (Hebrew University)
- **Innovation:** Language model approach that works WITHOUT diacritics (nikud)
- **Paper:** https://arxiv.org/abs/2407.12206
- **Demo:** https://pages.cs.huji.ac.il/adiyoss-lab/HebTTS/

#### LoTHM — Discrete Semantic Units for Hebrew TTS
- **Authors:** Ella Zeldes, Or Tal, Yossi Adi
- **Innovation:** HuBERT-based discrete units for stable Hebrew synthesis with speaker embeddings
- **Paper:** https://arxiv.org/abs/2410.21502
- **Demo:** https://pages.cs.huji.ac.il/adiyoss-lab/LoTHM/

#### HEBDB — 2,500-Hour Hebrew Speech Database
- **Authors:** Arnon Turetzky et al. (Hebrew University)
- **Size:** ~2,500 hours of diverse Hebrew speech
- **Use:** Training data for Hebrew TTS models

**These academic projects are cutting-edge but may not have easily reusable code/models for voice cloning specifically.** They're more useful as building blocks for a custom pipeline.

---

## Recommended Strategy

### Option A: Quick Win (1–2 days)
**Use Chatterbox Multilingual**

1. `pip install chatterbox-tts`
2. Load model (may need CPU mode for 4GB VRAM)
3. Provide reference WAV files for Dotan & Shahar
4. Generate Hebrew podcast with voice cloning
5. Evaluate quality

### Option B: Hybrid Pipeline (3–5 days)
**OpenVoice V2 + Phonikud**

1. Install Phonikud for Hebrew text → IPA conversion
2. Use OpenVoice V2 for tone-color cloning
3. Feed IPA phonemes to MeloTTS base, then apply tone converter
4. Iterate on quality

### Option C: High-Quality Custom (1–2 weeks)
**Fine-tune GPT-SoVITS or F5-TTS on Hebrew**

1. Install Phonikud for text preprocessing
2. Prepare Hebrew speech dataset (using HEBDB or custom recordings)
3. Fine-tune model on Hebrew + reference speakers
4. Requires more VRAM (consider cloud GPU for training, local for inference)

### Option D: Academic Cutting-Edge (Research project)
**Build on HebTTS/LoTHM**

1. Contact Hebrew University SLP-RL lab
2. Adapt their Hebrew TTS pipeline
3. Add voice cloning on top (speaker embeddings)
4. Highest quality but highest effort

---

## VRAM Compatibility Matrix

| Model | Inference VRAM | Fits RTX 500 Ada (4GB)? | CPU Fallback? |
|-------|---------------|------------------------|---------------|
| Chatterbox Multi | ~3–4GB | ⚠️ Tight | ✅ Yes |
| OpenVoice V2 | ~2–3GB | ✅ Yes | ✅ Yes |
| GPT-SoVITS V3 | ~4–6GB | ⚠️ Inference maybe | ✅ Slow |
| F5-TTS | ~4–6GB | ❌ Too large | ✅ Very slow |
| Fish Speech 1.5 | ~4–6GB | ⚠️ Tight | ✅ Yes |
| Piper TTS | ~0.1–0.5GB | ✅ Easily | ✅ Fast |
| Bark | ~4–8GB | ❌ Too large | ✅ Slow |
| CosyVoice | ~6–8GB | ❌ Too large | ❌ Impractical |
| StyleTTS 2 | ~4–6GB | ⚠️ Inference maybe | ✅ Yes |

---

## Final Recommendation

**Start with Chatterbox Multilingual.** It's the only model that checks ALL boxes:
- ✅ Native Hebrew language support
- ✅ Zero-shot voice cloning from short reference audio
- ✅ Open source (MIT license)
- ✅ Emotion control
- ✅ Active development
- ⚠️ VRAM is tight but workable (try CPU mode or fp16)

**Fallback:** If Chatterbox quality is insufficient, try OpenVoice V2 with Phonikud for Hebrew G2P preprocessing. The tone-color converter doesn't depend on language, so voice matching should work even if pronunciation needs manual tuning.

**Essential companion tool:** Install **Phonikud** (`pip install phonikud`) regardless of which TTS model you use — it's the key to getting Hebrew phonemes right.

---

## Quick Reference Links

| Resource | URL |
|----------|-----|
| Chatterbox (Resemble AI) | https://github.com/resemble-ai/chatterbox |
| OpenVoice V2 | https://github.com/myshell-ai/OpenVoice |
| GPT-SoVITS | https://github.com/RVC-Boss/GPT-SoVITS |
| Phonikud (Hebrew G2P) | https://github.com/thewh1teagle/phonikud |
| Robo-Shaul (Hebrew clone) | https://github.com/gabykh1/Robo-Shaul |
| HebTTS (Hebrew University) | https://pages.cs.huji.ac.il/adiyoss-lab/HebTTS/ |
| LoTHM (Hebrew TTS) | https://pages.cs.huji.ac.il/adiyoss-lab/LoTHM/ |
| Fish Speech | https://github.com/fishaudio/fish-speech |
| Piper TTS | https://github.com/rhasspy/piper |
| F5-TTS | https://github.com/SWivid/F5-TTS |
| ILSpeech Dataset | https://arxiv.org/abs/2506.12311 |
| HEBDB Dataset | https://arnontu.github.io/ |

---

*Report generated by Seven, Research & Analytics — Squad AI Team*
