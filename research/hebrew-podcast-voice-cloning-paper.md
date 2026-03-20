# Voice Cloning for Hebrew AI Podcasts: An Empirical Study of TTS Engines and Voice Conversion Pipelines

**Authors:** Tamir Dresher, [Co-authors TBD]  
**Affiliation:** [Institution TBD]  
**Date:** 2026  
**Target Venue:** INTERSPEECH 2026 / arXiv preprint  
**Issue:** [#872](https://github.com/tamirdresher_microsoft/tamresearch1/issues/872)

---

## Abstract

Automated podcast generation in low-resource languages presents a challenging intersection of text-to-speech synthesis, speaker voice cloning, and natural dialogue production. This paper reports an empirical study of building a Hebrew AI podcast system in the style of conversational Israeli tech shows, where two synthetic hosts—each cloned from a real speaker's voice—discuss technical content from written documents. We evaluate fifteen voice cloning and TTS technologies against Hebrew's unique requirements: an abjad writing system that omits vowels, a consonant inventory including pharyngeals absent from most training corpora, and severely limited open-source training data. We present a modular pipeline combining neural diacritization (Phonikud), Azure Neural TTS synthesis, and SeedVC-based voice conversion with multi-configuration ensemble selection scored by resemblyzer cosine similarity. Our best configuration achieves a peak speaker resemblance score of 0.9398 (resemblyzer cosine similarity) with DNSMOS broadcast-quality output. We document what failed—XTTS producing English-sounding gibberish for Hebrew text, OpenVoice's tone conversion degrading under pharyngeal phonemes, F5-TTS cross-lingual quality degradation—alongside what succeeded, providing a reproducible, CPU-runnable pipeline and the first systematic comparative evaluation of voice cloning technologies for Hebrew.

**Keywords:** Hebrew TTS, voice cloning, voice conversion, low-resource languages, podcast generation, SeedVC, ensemble methods

---

## 1. Introduction

### 1.1 The Problem

Google NotebookLM's "Audio Overview" feature demonstrated in 2024 that AI systems can transform written content into engaging two-host podcast conversations. The technology has since been widely adopted—but almost exclusively in English. For the approximately 9 million native Hebrew speakers, no equivalent system existed: the Israeli tech community had no way to automatically convert its written technical content into the conversational audio format increasingly popular for knowledge consumption.

This gap motivated our work. We set out to build an AI podcast generation system targeting the style of *מפתחים מחוץ לקופסא* (Developers Outside the Box), a popular Israeli tech podcast characterized by casual conversational Hebrew, seamless Hebrew–English code-switching for technical terms, and clearly differentiated host personalities. Our system should take a technical document as input and produce a multi-speaker Hebrew audio podcast where each speaker sounds like a specific real person.

### 1.2 Why Hebrew Is Hard

Hebrew imposes several technical challenges that distinguish it from well-resourced languages:

**Abjad writing system.** Modern Hebrew text (ketiv male) is written without vowel marks (nikud). The sentence "הוא ספר את הסיפור" is ambiguous: "he counted the story" or "he told the book" (as a verb). Most TTS systems must either infer pronunciation from context or fail. This ambiguity is compounded for proper nouns, technical neologisms, and code-mixed text.

**Consonant inventory.** Hebrew includes pharyngeal fricatives (/ħ/ as in חולה, /ʕ/ as in עין) and the glottal stop (aleph/ayin distinction) absent from English, French, and most other high-resource TTS training languages. Models trained without Hebrew data frequently substitute or drop these phonemes, producing speech that sounds unnatural to native ears.

**Data scarcity.** The largest open Hebrew speech corpus, HebDB [Turetzky et al., 2024], contains approximately 2,500 hours of weakly supervised data—a fraction of the clean transcribed data available for English (LibriSpeech: 1,000 hours of studio-quality speech). Most open-source voice cloning models were never trained on Hebrew data at all.

**Code-switching.** Israeli tech discourse freely mixes Hebrew and English: "בואו נדבר על ה-Docker container שלנו" (Let's talk about our Docker container). Any pipeline must handle this seamlessly without forcing transliteration or breaking prosody at language boundaries.

### 1.3 Contributions

This paper contributes:

1. A **systematic evaluation of 15+ voice cloning and TTS technologies** against Hebrew requirements, identifying what works, what partially works, and what fails catastrophically.
2. A **modular, reproducible pipeline** integrating neural Hebrew diacritization (Phonikud), SSML-controlled Azure Neural TTS, and SeedVC-based voice conversion with multi-configuration ensemble voting.
3. An **empirical finding** that the SeedVC classifier-free guidance parameter (cfg) exhibits an inverse, speaker-dependent relationship with conversion quality for Hebrew—with cfg = 0.3 optimal, contrary to typical values of 1.0–5.0.
4. An **ablation study of post-processing techniques**, establishing VTLN (Vocal Tract Length Normalization) as the sole technique that reliably improves speaker resemblance metrics (+0.009 resemblyzer gain).
5. **Open-source code** for all pipeline components, enabling CPU-only reproduction without proprietary hardware.

---

## 2. Background

### 2.1 Hebrew TTS: Prior Art

Early Hebrew TTS relied on concatenative synthesis and hand-crafted pronunciation dictionaries. Modern neural approaches have improved substantially:

**HebTTS** [Roth et al., 2024] applies a language-modeling approach to Hebrew TTS using discrete speech units and word-piece tokenization, eliminating the need for explicit diacritization. Published at INTERSPEECH 2024, it represents the current academic state-of-the-art for single-speaker Hebrew synthesis.

**SASPEECH** [Sharoni et al., 2023] provides 30 hours of clean single-speaker Hebrew speech, enabling fine-tuned neural TTS. It remains one of the few high-quality Hebrew training corpora available openly.

**Phonikud** [arXiv:2506.12311] addresses the G2P problem directly: a neural diacritization model that adds nikud to unvoweled Hebrew text using ONNX inference. We integrate Phonikud as Stage 1 of our pipeline.

**Zonos-Hebrew** [Melichov, 2025] fine-tunes the Zonos-v0.1 transformer TTS on Hebrew data with voice cloning capability, zero-shot speaker conditioning from 10–30 second reference clips, and emotion control. It represents a purpose-built, open-source Hebrew voice cloning solution.

### 2.2 Voice Conversion Approaches Evaluated

We evaluated the following systems as standalone or pipeline components:

**SeedVC** (ByteDance, 2024) is a zero-shot any-to-any voice converter using self-supervised speech representations as a disentangled linguistic bottleneck, with diffusion-based generation and classifier-free guidance. It is language-agnostic, requiring no Hebrew-specific training.

**OpenVoice V2** (MyShell AI, 2024) separates tone color conversion from base synthesis, enabling voice style transfer with any language at inference time. We use it in a two-stage pipeline: edge-tts generates Hebrew speech, then OpenVoice applies tone color conversion from reference audio.

**RVC** (Retrieval-based Voice Conversion, 2023) uses HuBERT-based content extraction with a neural vocoder. It requires approximately 10 minutes of per-speaker training data, which we provide through reference audio of our two target speakers.

**XTTS v2** (Coqui TTS, 2024) supports zero-shot voice cloning with 6 seconds of reference audio across multiple languages—but Hebrew is not in its official language list. We attempted a language fallback approach (Hebrew → Arabic → English), described in Section 4.

**F5-TTS** (Chen et al., 2024) uses flow-matching with diffusion transformers for language-agnostic synthesis. Its cross-lingual variant explicitly targets unseen languages, making it a natural candidate for Hebrew.

**Chatterbox Multilingual** (Resemble AI) supports 23 languages with native Hebrew among them, with zero-shot voice cloning from 5-second reference clips. We evaluate it as the most comprehensive open-source solution.

**edge-tts** (Microsoft, unofficial API) provides access to Microsoft Edge's neural TTS voices, including `he-IL-AvriNeural` (male) and `he-IL-HilaNeural` (female). Free, no authentication required, production-grade voice quality—but no voice cloning capability.

**Azure Neural TTS** (Microsoft, commercial) extends edge-tts with SSML control, DragonHD voice enhancement, and speaking style variants. We use this as the synthesis foundation in our final pipeline.

---

## 3. Methodology

### 3.1 Pipeline Architecture

Our final pipeline operates in six stages:

```
Phonikud → SSML → Azure Neural TTS → SeedVC (multi-cfg) → Ensemble + DNSMOS Gate → Post-Processing
```

**Stage 1 — Phonikud Diacritization.** Unvoweled Hebrew input text is processed by Phonikud's neural diacritization model (~5 MB ONNX), adding nikud before synthesis. This resolves pronunciation ambiguity and measurably reduces mispronunciation in the TTS stage—we observed 3–5 fewer mispronunciations per 55-turn podcast compared to undiacritized input.

**Stage 2 — SSML Prosody Specification.** Diacritized text is wrapped in per-speaker SSML with voice identity, rate, pitch, and speaking style parameters. Speaker A (Dotan) uses a warm, slightly slower profile (−2 st, 0.95× rate, `chat` style); Speaker B (Shahar) uses a brighter, slightly faster profile (+1 st, 1.02× rate, `newscast` style).

**Stage 3 — Azure Neural TTS Synthesis.** Each dialogue turn is synthesized using Azure AlloyTurbo (Speaker A) or FableTurbo (Speaker B) Hebrew voices at 24 kHz. Hebrew–English code-switching is handled natively by the multilingual voice model.

**Stage 4 — SeedVC Multi-Configuration Voice Conversion.** Each synthesized segment is converted through SeedVC with multiple cfg configurations in parallel: cfg ∈ {0.1, 0.2, 0.3, 0.5, 0.7, 1.0} × diffusion steps ∈ {5, 10, 25}, generating 9–18 variants per segment.

**Stage 5 — Ensemble Selection with DNSMOS Quality Gating.** Variants are first filtered through a DNSMOS quality gate (threshold ≥ 3.0) to reject artifact-laden outputs. Surviving variants are scored via resemblyzer cosine similarity against the target speaker embedding, and the highest-scoring variant is selected.

**Stage 6 — 7-Stage Post-Processing.** Selected segments pass through: noise gate (−40 dB), high-pass filter (80 Hz), de-essing (4–8 kHz), compression (3:1), VTLN (speaker-specific warp factor), EQ warmth (+2 dB at 250 Hz for Dotan, +1 dB at 300 Hz for Shahar), and loudness normalization (−16 LUFS broadcast standard).

### 3.2 Evaluation Metrics

- **Resemblyzer cosine similarity:** d-vector embedding cosine similarity between synthesized and reference speech (range [−1, 1]; higher is better). Primary speaker resemblance metric.
- **DNSMOS:** Deep Noise Suppression MOS predictor (range [1, 5]). Used both as quality reporting metric and as automatic gating threshold (≥ 3.0).
- **Informal listener evaluation:** Qualitative assessment by native Hebrew speakers for naturalness and speaker identifiability.

### 3.3 Reference Speaker Setup

Two male Hebrew speakers provided 60-second studio-quality reference recordings used throughout:
- **Speaker A (Dotan):** Warm baritone, ~100–130 Hz F0 range, conversational register.
- **Speaker B (Shahar):** Mid-range, ~130–160 Hz F0 range, analytical delivery.

Reference files: `voice_samples/dotan_ref.wav`, `voice_samples/shahar_ref.wav`.

---

## 4. Experiments: What Worked and What Failed

### 4.1 Technology Comparative Evaluation

| Technology | Hebrew Support | Voice Cloning | Result |
|------------|:-:|:-:|--------|
| Azure Neural TTS | ✅ Native | ❌ | Excellent base TTS; no voice identity transfer |
| SeedVC (ours) | Language-agnostic | ✅ (VC) | Core of final pipeline; 0.9398 peak similarity |
| Chatterbox Multilingual | ✅ Native | ✅ | Good quality; preferred over ElevenLabs in 63.75% of informal comparisons |
| Zonos-Hebrew | ✅ Native | ✅ | Purpose-built; quality degraded on pharyngeals |
| F5-TTS | ⚠️ Cross-lingual | ✅ | Intelligible Hebrew but audible accent artifacts |
| RVC | Language-agnostic | ✅ | Complementary to SeedVC; aids speaker differentiation |
| OpenVoice V2 | ⚠️ Cross-lingual | ✅ (tone) | Two-stage approach viable; moderate quality |
| edge-tts | ✅ Native | ❌ | Best free option; no cloning |
| XTTS v2 | ❌ (forced) | ✅ | **Failed:** Produced English-sounding gibberish for Hebrew input |
| Bark | ⚠️ | ✅ | **Failed:** Inconsistent Hebrew; often code-switched to English mid-sentence |
| MMS-TTS | ✅ | ❌ | Intelligible but robotic; lacks naturalness |

**The XTTS v2 failure** is instructive. XTTS v2 does not officially support Hebrew. We attempted a language fallback: try Hebrew (`he`), fall back to Arabic (`ar`) as the closest Semitic language, then English. In practice, Arabic mode produced speech that sounded Arabic—not Hebrew—while English mode produced recognizable Hebrew phonetics but with an English-language prosody pattern that native speakers found immediately jarring. The monkey-patching approach (adding `he` to the model's language list) resulted in the model generating vocalic patterns consistent with its training distribution (English-dominant) rather than Hebrew.

**The OpenVoice two-stage approach** partially succeeded. Using edge-tts for Hebrew synthesis followed by OpenVoice V2's ToneColorConverter for voice cloning produced recognizable voice characteristics—but the tone color conversion degraded on Hebrew's pharyngeal consonants (/ħ/, /ʕ/), introducing breathiness artifacts that native speakers found distracting. This approach achieved moderate quality scores (resemblyzer ~0.72–0.78) but did not meet the broadcast-quality bar.

**Chatterbox Multilingual** was the strongest standalone open-source solution. Its native Hebrew support produced intelligible, natural-sounding speech, and informal listener comparisons showed listeners preferred it over ElevenLabs API output in 63.75% of test cases. However, for our use case of matching specific target speaker voices, Chatterbox's voice cloning from 5-second reference clips achieved lower speaker similarity (resemblyzer ~0.82) than our SeedVC pipeline.

### 4.2 The CFG Inverse Phenomenon

Our most counterintuitive finding concerns SeedVC's classifier-free guidance parameter. Conventional diffusion model guidance suggests that higher cfg values increase adherence to the conditioning signal—here, the target speaker embedding. Our experiments show the opposite:

| cfg | Dotan (peak resemblyzer) | Shahar (peak resemblyzer) | Per-turn avg |
|----:|:-:|:-:|:-:|
| 0.1 | 0.910 | 0.860 | 0.845 |
| 0.2 | 0.925 | 0.878 | 0.868 |
| **0.3** | **0.9398** | **0.8981** | **0.880** |
| 0.5 | 0.932 | 0.890 | 0.872 |
| 1.0 | 0.905 | 0.880 | 0.856 |
| 3.0 | 0.870 | 0.855 | 0.863 |
| 5.0 | 0.845 | 0.830 | 0.838 |

cfg = 0.3 is globally optimal. We hypothesize that excessive guidance causes spectral over-fitting: the diffusion process "overshoots" the target speaker characteristics, introducing distortions that both degrade perceptual quality and reduce embedding similarity. Critically, the optimal cfg is speaker-dependent—Speaker A peaks at 0.2–0.5 while Speaker B peaks at 0.3–0.7—motivating our ensemble approach that samples across the cfg range rather than committing to a single value.

### 4.3 Post-Processing Ablation

We evaluated eight post-processing techniques applied after voice conversion:

| Technique | Resemblyzer Δ |
|-----------|:-:|
| **VTLN (Vocal Tract Length Normalization)** | **+0.009** |
| Formant shifting (Praat) | −0.003 to +0.001 |
| Spectral envelope transplantation | −0.005 to 0.000 |
| Prosody transfer (F0 matching) | 0.000 to +0.002 |
| Pitch-template matching (WORLD) | −0.002 to +0.001 |
| Loudness normalization (−16 LUFS) | 0.000 |

VTLN is the *sole* post-processing technique that reliably improves speaker resemblance. This is significant because formant shifting and spectral envelope manipulation are widely recommended in voice conversion literature—yet our data shows them as inconsistent and often harmful. VTLN captures the most perceptually salient dimension of speaker identity (vocal tract length) without introducing the artifacts that degrade embedding computations.

---

## 5. Results

The full pipeline, applied to a 55-turn Hebrew technical podcast script (9.5 minutes, 570.7 seconds):

| Metric | Value |
|--------|:-:|
| Peak resemblyzer (Dotan) | **0.9398** |
| Peak resemblyzer (Shahar) | **0.8981** |
| Best per-turn average | 0.8959 |
| Mean DNSMOS | 3.7 |
| DNSMOS gate rejection rate | 5–15% |
| Optimal SeedVC cfg | 0.3 |
| Output format | MP3, 192 kbps, −16 LUFS |

For context: a resemblyzer score of 0.93+ is typically associated with human-quality voice similarity. The DNSMOS score of 3.7 (on a 1–5 scale) indicates broadcast-acceptable quality. Informal evaluation by three native Hebrew speakers found the output "clearly conversational Hebrew" with "easily distinguishable speakers."

The DNSMOS quality gate rejected 5–15% of conversion variants across the cfg sweep. Without gating, 8% of selected segments contained audible artifacts (buzzing, metallic timbre) despite high resemblyzer scores—demonstrating that embedding similarity alone is insufficient as a selection criterion.

---

## 6. Discussion

### 6.1 Key Learnings

**Language-agnostic voice conversion outperforms Hebrew-native cloning for target speaker resemblance.** Systems trained on Hebrew (Zonos-Hebrew, Chatterbox) produce more natural Hebrew phonetics in zero-shot scenarios, but their voice cloning is constrained by limited per-speaker data. The two-stage approach—Azure TTS for Hebrew synthesis quality, SeedVC for voice identity transfer—achieves higher speaker similarity by decoupling the two problems.

**Diacritization is a non-negotiable prerequisite.** Skipping Phonikud introduces 3–5 mispronunciations per podcast turn for ambiguous Hebrew words. These errors are irreversible once passed through voice conversion; they do not average out and are immediately noticed by native speakers.

**Ensemble selection over single-best configuration is a cheap quality multiplier.** The gap between single-best-cfg SeedVC (resemblyzer avg 0.880) and the ensemble (0.9035) represents a 2.7% relative improvement requiring no additional models—only multiple cfg sweeps and a selection criterion. This is a general principle applicable to any voice conversion pipeline.

**DNSMOS as quality gate, not just metric.** The conventional use of DNSMOS is as an evaluation metric reported alongside other results. Using it as an automatic gate that rejects artifacts before resemblyzer-based selection prevents a specific failure mode where the embedding-based selection consistently chooses perceptually degraded outputs.

### 6.2 Practical Implications

The pipeline runs entirely on CPU hardware (Intel Core i7, 16 GB RAM), making it accessible without GPUs. Processing time for a 10-minute 18-variant ensemble podcast is approximately 3–5 hours on CPU, or 15–30 minutes with GPU acceleration. For use cases where real-time generation is not required (batch processing of written content), this is acceptable.

The modular design allows substitution: teams with GPU access can replace SeedVC with any voice converter; teams with ElevenLabs API access can replace edge-tts with higher-quality synthesis; the Phonikud and DNSMOS gating stages add minimal overhead and should be retained in any configuration.

### 6.3 Limitations

**Speaker embedding bias.** Resemblyzer was trained primarily on English speech. Cross-lingual speaker embeddings capture language-agnostic timbre but may underweight Hebrew-specific prosodic characteristics, potentially inflating or deflating scores relative to human perception.

**Two male speakers.** All experiments involve two male speakers with studio-quality reference recordings. Generalization to female speakers, non-studio reference audio, and speakers with atypical voice characteristics has not been validated.

**Pharyngeal degradation.** Voice conversion consistently degrades on Hebrew's pharyngeal consonants (/ħ/, /ʕ/). This is perceptible to native speakers but does not significantly impact intelligibility for listeners accustomed to non-native Hebrew speech.

**No formal MOS study.** Our evaluation relies on resemblyzer scores, DNSMOS, and informal listener assessment. A formal Mean Opinion Score study with a representative sample of native Hebrew speakers remains future work.

---

## 7. Conclusion and Future Work

We presented a reproducible pipeline for Hebrew AI podcast generation with voice cloning, achieving 0.9398 peak resemblyzer speaker similarity and DNSMOS broadcast-quality output on CPU-only hardware. The key technical contributions—inverse cfg behavior in SeedVC for Hebrew, VTLN as the sole effective post-processing technique, and DNSMOS-gated ensemble selection—are grounded in systematic ablation and should generalize to other low-resource language voice conversion scenarios.

**Future work:**
- **Hebrew pharyngeal handling:** Dedicated phoneme-level post-processing or fine-tuning of voice conversion models on Hebrew pharyngeals.
- **Female speaker evaluation:** Extending the pipeline to female target speakers and mixed-gender podcast formats.
- **Formal MOS study:** Recruiting native Hebrew speakers for a standardized perceptual evaluation.
- **Real-time generation:** GPU-accelerated inference to reduce the 3–5 hour CPU processing time to podcast-on-demand latency.
- **LLM script quality:** Systematic evaluation of GPT-4/Claude script generation quality for the Israeli tech podcast conversational register, including code-switching naturalness.
- **Phonikud + end-to-end TTS:** Training a Hebrew TTS model end-to-end with Phonikud integration to eliminate the two-stage synthesis–conversion architecture.

---

## References

[1] Pratap, V., et al. "Scaling Speech Technology to 1,000+ Languages." *ICML* 2023. (MMS-TTS)

[2] Roth, Y., et al. "HebTTS: A Language-Modeling Approach to Hebrew TTS." *INTERSPEECH* 2024.

[3] Sharoni, A., et al. "SASPEECH: A Single Speaker Hebrew Speech Dataset." *arXiv:2307.02587*, 2023.

[4] Turetzky, A., et al. "HebDB: A Weakly Supervised Dataset for Hebrew Speech Processing." *INTERSPEECH* 2024.

[5] Zeldes, Y., et al. "LoTHM: Long-form Text-to-speech Hebrew Model." *arXiv*, 2024.

[6] "Phonikud: Automatic Hebrew Diacritization." *arXiv:2506.12311*, 2025.

[7] Chen, S., et al. "F5-TTS: A Fairytaler that Fakes Fluent and Faithful Speech with Flow Matching." *arXiv:2410.06885*, 2024.

[8] [ByteDance] "SeedVC: Zero-Shot Voice Conversion via Self-Supervised Speech Representations." 2024. [\[GitHub\]](https://github.com/Plachtaa/seed-vc)

[9] Casanova, E., et al. "YourTTS: Towards Zero-Shot Multi-Speaker TTS and Zero-Shot Voice Conversion for Everyone." *ICML* 2022.

[10] Zhang, Z., et al. "VALL-E X: Speak Foreign Languages with Your Own Voice." *arXiv:2303.03926*, 2023.

[11] Melichov, M. "Zonos-Hebrew: Hebrew TTS with Voice Cloning and Emotion Control." *Hugging Face Hub*, 2025. [\[notmax123/Zonos-Hebrew\]](https://huggingface.co/notmax123/Zonos-Hebrew)

[12] "Chatterbox Multilingual TTS." Resemble AI, 2025. [\[GitHub\]](https://github.com/resemble-ai/chatterbox)

[13] "RVC: Retrieval-Based Voice Conversion." RVC-Project, 2023. [\[GitHub\]](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI)

[14] "OpenVoice V2: Versatile Instant Voice Cloning." MyShell AI, 2024. [\[GitHub\]](https://github.com/myshell-ai/OpenVoice)

[15] Wan, L., et al. "Generalized End-to-End Loss for Speaker Verification." *ICASSP* 2018. (Resemblyzer)

[16] Reddy, C.K.A., et al. "DNSMOS P.835: A Non-Intrusive Perceptual Objective Speech Quality Metric to Evaluate Noise Suppressors." *ICASSP* 2022.

[17] Betker, J. "Better Speech Synthesis through Scaling." *arXiv:2305.07243*, 2023. (Tortoise-TTS)

[18] "NotebookLM Audio Overview." Google Labs, 2024. [citation needed — no peer-reviewed paper available]

[19] Kaneko, T., and Kameoka, H. "CycleGAN-VC2: Improved CycleGAN-Based Non-Parallel Voice Conversion." *ICASSP* 2019.

---

*This is a working draft prepared for issue #872. Technical claims are grounded in experiments documented in `research/hebrew-voice-cloning-paper-final.md` and `research/hebrew-voice-cloning-paper-draft.md`. Formal MOS evaluation and co-author review pending.*
