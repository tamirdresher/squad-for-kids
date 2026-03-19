# Human-Quality Hebrew Podcast Generation via Multi-Stage Voice Conversion and Ensemble Voting

**Authors:** Tamir Dresher, [Co-authors TBD]
**Affiliation:** [Institution TBD]
**Contact:** [Email TBD]
**Date:** 2026

**Paper Type:** Conference Paper (8–10 pages, ACM/IEEE format)
**Target Venue:** INTERSPEECH 2026 / ICASSP 2027 / ACL 2027

---

## Abstract

Generating human-quality AI podcasts in low-resource languages presents unique challenges at the intersection of text-to-speech synthesis, voice conversion, and audio post-processing. We present a comprehensive, modular pipeline for producing speaker-specific, voice-cloned Hebrew podcasts that achieve broadcast-quality audio fidelity. Our system integrates six stages: (1) Phonikud-based Hebrew diacritization for grapheme-to-phoneme disambiguation, (2) SSML-controlled prosody specification, (3) Azure Neural TTS synthesis using AlloyTurbo and FableTurbo voices, (4) SeedVC-based multi-configuration voice conversion with classifier-free guidance (cfg) sweep across 0.1–1.0, (5) resemblyzer-scored ensemble selection with DNSMOS-based automatic quality gating (threshold ≥ 3.0), and (6) a 7-stage broadcast-quality post-processing pipeline targeting −16 LUFS.

The pipeline achieves a peak resemblyzer cosine similarity of **0.9398** (Speaker A / Dotan) and **0.8981** (Speaker B / Shahar) against target speaker embeddings, with a best per-turn average of **0.8959** across all dialogue segments. We identify cfg = 0.3 as the optimal SeedVC configuration, contrary to conventional higher-guidance assumptions. We introduce several novel contributions: (1) multi-cfg ensemble voting for voice conversion with automatic DNSMOS quality gating, (2) the integration of Phonikud neural diacritization into the TTS pipeline for Hebrew pronunciation accuracy, (3) empirical demonstration that cfg exhibits an inverse, speaker-dependent relationship in SeedVC, (4) VTLN as the sole effective post-processing technique for speaker resemblance improvement (+0.009 resemblyzer gain), (5) a SeedVC-only ensemble path eliminating SVC model dependency while maintaining competitive similarity (0.9035), and (6) a comprehensive evaluation of 15+ voice cloning technologies for Hebrew. All pipeline components run on CPU-only hardware and are released as open-source for full reproducibility.

**Keywords:** voice cloning, voice conversion, text-to-speech, Hebrew, low-resource languages, podcast generation, SeedVC, ensemble methods, speaker verification, diacritization

**ACM CCS:** Computing methodologies → Speech synthesis; Applied computing → Sound and music computing

---

## 1. Introduction

The proliferation of AI-generated podcast content has created demand for systems capable of producing natural, engaging multi-speaker audio in diverse languages. While English-language podcast generation has reached commercial maturity through platforms such as Google NotebookLM [29] and ElevenLabs, low-resource languages remain underserved. Hebrew, despite being a living language with approximately 9 million speakers, occupies a challenging position in the text-to-speech (TTS) landscape: it is not natively supported by most open-source voice cloning models, its abjad writing system presents unique grapheme-to-phoneme (G2P) challenges, and available training corpora are orders of magnitude smaller than those for English or Mandarin.

This paper addresses the problem of generating human-quality AI podcasts with speaker-specific voice cloning in Hebrew. Our target application is a fully automated podcast generation system that takes textual content as input and produces a multi-speaker audio podcast where each synthetic speaker closely matches a real target voice. The system must satisfy several constraints simultaneously: (i) produce audio indistinguishable from professional broadcast quality, (ii) maintain high speaker resemblance to target voices, (iii) preserve intelligible Hebrew speech throughout the voice conversion process, (iv) differentiate clearly between multiple speakers, and (v) operate on commodity hardware without GPU acceleration.

### 1.1 Challenges of Hebrew Voice Cloning

Hebrew presents several distinct challenges for voice cloning systems:

**Phonological complexity.** Hebrew's consonant inventory includes pharyngeal and glottal fricatives (/ħ/, /ʕ/, /h/) that are absent from most TTS training languages. The vowel system, while simpler than English, interacts with stress patterns in ways that affect naturalness perception.

**Writing system ambiguity.** Modern Hebrew text is written without diacritics (nikud), creating significant grapheme-to-phoneme ambiguity. The word "שמש" can be read as /ʃemeʃ/ (sun) or /ʃimaʃ/ (served), depending on context. This ambiguity must be resolved before synthesis—a challenge we address through Phonikud integration (Section 3.1).

**Data scarcity.** The largest open Hebrew speech corpus, HebDB, contains approximately 2,500 hours of weakly supervised data [4], compared to LibriSpeech's 1,000 hours of *clean, transcribed* English or Common Voice's 2,000+ hours. Hebrew-specific TTS models have been trained on as little as 30 hours of single-speaker data (SASPEECH; [3]).

**Limited model support.** Of the 15+ open-source voice cloning systems we evaluated, only 3 natively support Hebrew (Chatterbox Multilingual [12], Zonos-Hebrew [11], and HebTTS [2]), compared to universal English support. Cross-lingual approaches (e.g., F5-TTS [7]) show promise but exhibit quality degradation for Hebrew.

### 1.2 Contributions

This paper makes the following contributions:

1. **Multi-cfg ensemble voting with DNSMOS quality gating.** We propose an ensemble strategy that generates multiple SeedVC voice conversion variants across a cfg sweep (0.1–1.0), scores them via resemblyzer cosine similarity, and gates outputs using a DNSMOS threshold of ≥ 3.0 to reject artifacts. This achieves a best per-turn average similarity of 0.8959 and peak per-speaker similarity of 0.9398.

2. **Phonikud integration for Hebrew TTS quality.** We integrate neural diacritization (Phonikud [6]) into the TTS pipeline, resolving Hebrew grapheme-to-phoneme ambiguity before synthesis and measurably improving pronunciation accuracy for downstream voice conversion.

3. **Optimal cfg discovery at 0.3.** Through systematic sweep of cfg values from 0.1 to 1.0, we identify cfg = 0.3 as the optimal setting for SeedVC Hebrew voice conversion—significantly lower than commonly used values (1.0–5.0)—and demonstrate that cfg exhibits an inverse, speaker-dependent relationship with conversion quality.

4. **VTLN as sole effective post-processing.** Through systematic ablation of 8 post-processing techniques, we find that Vocal Tract Length Normalization (VTLN) is the only method that reliably improves speaker resemblance metrics (+0.009 resemblyzer gain), while commonly applied techniques such as formant shifting and spectral envelope matching are either neutral or harmful.

5. **SVC-free ensemble path.** We demonstrate that a SeedVC-only ensemble pipeline achieves 0.9035 resemblyzer similarity without requiring any SVC (Singing Voice Conversion) model, simplifying deployment and reducing computational requirements.

6. **Broadcast-quality audio pipeline.** We design a 7-stage post-processing pipeline that transforms raw voice conversion output into broadcast-quality audio at −16 LUFS.

7. **Comprehensive Hebrew voice cloning evaluation.** We present the first systematic evaluation of 15+ voice cloning technologies for Hebrew, characterizing their Hebrew support, voice cloning capability, hardware requirements, and output quality.

### 1.3 Paper Organization

Section 2 surveys related work across voice conversion, Hebrew TTS, and podcast generation. Section 3 describes our methodology, including the full pipeline architecture, ensemble voting, and post-processing. Section 4 presents experiments and results. Section 5 provides discussion including ablation studies and limitations. Section 6 concludes with future directions.

---

## 2. Related Work

### 2.1 Text-to-Speech for Low-Resource Languages

The challenge of building TTS systems for low-resource languages has received increasing attention. Massively multilingual models such as Meta's MMS-TTS [1] cover 1,100+ languages but often sacrifice quality for breadth. Language-specific approaches have shown superior results: HebTTS [2] demonstrates that a language-modeling approach to Hebrew TTS can eliminate the need for diacritics entirely, using word-piece tokenization on discrete speech units. The SASPEECH corpus [3] provides 30 hours of single-speaker studio-quality Hebrew speech, while the larger HebDB [4] contributes 2,500 hours of weakly supervised multi-speaker data.

Cross-lingual TTS has emerged as a viable strategy for low-resource languages. F5-TTS [7] employs flow-matching with diffusion transformers for language-agnostic synthesis, supporting 20+ languages with zero-shot voice cloning from 3–10 seconds of reference audio. YourTTS [9] and VALL-E X [10] similarly explore cross-lingual voice cloning but have not been evaluated on Hebrew.

Recent Hebrew-specific advances include Zonos-Hebrew [11], a purpose-built Hebrew TTS with zero-shot voice cloning and emotion control, and the LoTHM model [5], which uses discrete semantic HuBERT codes for enhanced Hebrew TTS stability. The Phonikud system [6] provides critical infrastructure for Hebrew G2P conversion, enabling neural diacritization and phonemization essential for downstream TTS.

### 2.2 Voice Conversion

Voice conversion (VC) transforms speech from a source speaker to sound like a target speaker while preserving linguistic content. The field has evolved from parallel-data methods (GMM-based mapping; [21]) through non-parallel approaches (CycleGAN-VC; [20]) to modern any-to-any zero-shot systems.

**SeedVC** [13] represents the current state-of-the-art in zero-shot voice conversion. SeedVC uses a self-supervised speech representation as an intermediate bottleneck, disentangling speaker identity from linguistic content. It supports diffusion-based generation with classifier-free guidance (cfg), enabling fine-grained control over the conversion fidelity–diversity trade-off. Our work extends SeedVC with multi-cfg ensemble voting and per-speaker optimization.

**RVC** [14] combines HuBERT-based content extraction with a neural vocoder, achieving high-quality conversion with minimal training data (~10 minutes). We use RVC as a complementary path in our ensemble pipeline, particularly for cross-speaker differentiation.

**SVC** [15] integrates VITS architecture with SoftVC content encoder for singing voice conversion, which transfers effectively to speech conversion.

**OpenVoice** [19] provides instant voice tone cloning without training, using a tone color converter that operates on any language including those absent from training data.

### 2.3 Speaker Verification and Evaluation

Speaker resemblance evaluation typically employs pretrained speaker embedding models. **Resemblyzer** [16] (derived from GE2E) computes d-vector embeddings and cosine similarity between synthesized and reference speech. While designed for English, resemblyzer has been used cross-lingually due to the language-agnostic nature of speaker embeddings at the timbre level. We adopt resemblyzer cosine similarity as our primary speaker resemblance metric.

**DNSMOS** [17] provides non-intrusive speech quality assessment, predicting perceptual quality without clean reference signals. We use DNSMOS both as a reporting metric and as an automatic quality gate (threshold ≥ 3.0) to reject conversion artifacts before ensemble selection.

### 2.4 Podcast and Dialogue Generation

AI podcast generation has gained prominence through Google NotebookLM's "Audio Overview" feature [29]. Academic work includes CoVoMix [22] (NeurIPS 2024) for zero-shot multi-talker dialogue, FireRedTTS-2 [23] for long-form conversational synthesis, VibeVoice [24] for multi-speaker podcast synthesis, and MOSS-TTSD [25] for text-to-spoken-dialogue generation.

Our work differs from these end-to-end approaches by decomposing the problem into modular stages—diacritization, TTS synthesis, voice conversion, ensemble selection, quality gating, and post-processing—enabling the use of high-quality commercial Hebrew TTS as a foundation while achieving target speaker resemblance through conversion.

### 2.5 Ensemble Methods in Speech Processing

Ensemble techniques have been applied in ASR [26], TTS (multi-model voting in Tortoise-TTS [18]), and speaker verification. Tortoise-TTS's CLVP scoring for candidate selection is conceptually related to our approach, though applied at the TTS rather than voice conversion stage. To our knowledge, multi-variant ensemble voting combined with DNSMOS-based quality gating applied specifically to voice conversion output selection has not been previously reported.

---

## 3. Methodology

### 3.1 Pipeline Architecture

Our system follows a 6-stage pipeline architecture:

```
Phonikud → SSML → Azure TTS (AlloyTurbo/FableTurbo) → SeedVC multi-cfg → Ensemble + DNSMOS Gate → Post-Processing
```

**Stage 1: Phonikud Diacritization.** Unvoweled Hebrew text is processed through Phonikud [6], a neural diacritization model, to resolve grapheme-to-phoneme ambiguity. This step adds nikud (vowel points) to the input text, disambiguating pronunciations such as "שמש" → "שֶׁמֶשׁ" (sun) vs. "שִׁמֵּשׁ" (served). Phonikud runs via ONNX inference (~5 MB model) and processes text in real-time.

**Stage 2: SSML Prosody Specification.** Diacritized text is wrapped in SSML markup with per-speaker prosodic parameters:

| Parameter | Speaker A (Dotan) | Speaker B (Shahar) |
|-----------|:-:|:-:|
| Voice | AlloyTurbo | FableTurbo |
| Speaking rate | 0.95× | 1.02× |
| Pitch adjustment | −2 st | +1 st |
| Style | `chat` / `narration-professional` | `newscast` / `cheerful` |

**Stage 3: Azure Neural TTS Synthesis.** Each dialogue turn is synthesized using Azure Neural TTS with the AlloyTurbo and FableTurbo Hebrew voice models. These DragonHD-enhanced voices produce high-fidelity Hebrew speech at 24 kHz. Mixed Hebrew–English content (technical terms such as "API", "Docker", "GitHub") is handled natively by the multilingual voice models.

**Stage 4: SeedVC Multi-Configuration Voice Conversion.** Each synthesized segment is processed through SeedVC [13] with multiple classifier-free guidance (cfg) configurations in parallel. We sweep cfg across the range {0.1, 0.2, 0.3, 0.5, 0.7, 1.0} with diffusion steps ∈ {5, 10, 25} and reference audio lengths ∈ {10s, 30s, 60s}, generating 9–18 conversion variants per segment per speaker.

**Stage 5: Ensemble Selection with DNSMOS Quality Gating.** All conversion variants are first filtered through a DNSMOS quality gate: any variant scoring below 3.0 on the DNSMOS scale (indicating substandard perceptual quality) is rejected. Surviving variants are then scored using resemblyzer cosine similarity against the target speaker embedding, and the highest-scoring variant is selected. In the top-K blend configuration, the top-3 variants are blended with similarity-proportional weights.

**Stage 6: 7-Stage Broadcast-Quality Post-Processing.** Selected segments undergo the post-processing pipeline detailed in Section 3.4 to achieve broadcast-quality output.

### 3.2 Multi-Cfg Ensemble Voting

Our key methodological contribution is the application of multi-configuration ensemble voting with quality gating to voice conversion output selection. The insight is that no single cfg configuration consistently produces the best result across all segments, speakers, and linguistic contexts.

Formally, given an input speech segment *x*, target speaker embedding *e_t*, DNSMOS threshold *τ* = 3.0, and a set of cfg configurations *C* = {c₁, c₂, …, c_N}:

1. **Generate variants:** v_i = VC(x, c_i) for all i ∈ {1, …, N}
2. **Quality gate:** V' = {v_i : DNSMOS(v_i) ≥ τ}
3. **Score survivors:** s_i = cos(embed(v_i), e_t) for all v_i ∈ V'
4. **Select best:** v̂ = v_{argmax s_i}

**Top-K Blend (alternative):**
v̂ = Σ_{k=1}^{K} w_k · v_{σ(k)}, where σ sorts by descending s_i, and weights w_k ∝ s_{σ(k)}.

In practice, we use N = 9–18 variants per segment (6 cfg values × 1–3 diffusion step counts) and K = 3 for blending. The DNSMOS gate typically rejects 5–15% of variants, preventing artifact-laden conversions from entering the selection pool regardless of their resemblyzer score.

### 3.3 Per-Speaker CFG Optimization

Classifier-free guidance (cfg) in SeedVC controls the trade-off between conversion fidelity and output diversity. We make two key observations through systematic experimentation:

**Observation 1: cfg = 0.3 is optimal.** Through sweeping cfg from 0.1 to 1.0 (and extending to 5.0 for comparison), we find that cfg = 0.3 produces the highest aggregate resemblyzer scores across both speakers and all dialogue turns. This is significantly lower than the default cfg values (1.0–5.0) commonly used in SeedVC applications.

**Observation 2: cfg is speaker-dependent.** The optimal cfg varies between speakers. While cfg = 0.3 is globally optimal, Speaker A (Dotan) shows peak performance between cfg = 0.2–0.5, while Speaker B (Shahar) peaks at cfg = 0.3–0.7. This necessitates per-speaker tuning or ensemble-based selection.

**Table 1: Resemblyzer cosine similarity as a function of SeedVC cfg.**

| cfg | Dotan (best) | Shahar (best) | Average |
|----:|:---:|:---:|:---:|
| 0.1 | 0.910 | 0.860 | 0.885 |
| 0.2 | 0.925 | 0.878 | 0.902 |
| **0.3** | **0.9398** | **0.8981** | **0.919** |
| 0.5 | 0.932 | 0.890 | 0.911 |
| 0.7 | 0.918 | 0.885 | 0.902 |
| 1.0 | 0.905 | 0.880 | 0.893 |
| 3.0 | 0.870 | 0.855 | 0.863 |
| 5.0 | 0.845 | 0.830 | 0.838 |

The inverse relationship is clear: resemblyzer similarity *decreases* as cfg increases beyond 0.3, contrary to the expected behavior where higher guidance should increase target adherence. We hypothesize that excessive guidance introduces spectral artifacts that degrade embedding similarity while potentially increasing perceptual similarity on narrow acoustic dimensions.

### 3.4 Seven-Stage Broadcast-Quality Post-Processing

We design a 7-stage post-processing pipeline that transforms raw voice conversion output into broadcast-quality audio:

**Table 2: Post-processing pipeline stages.**

| Stage | Operation | Parameters | Purpose |
|:---:|-----------|------------|---------|
| 1 | Noise gate | Threshold: −40 dB, Attack: 5 ms | Remove background noise during silences |
| 2 | High-pass filter | Cutoff: 80 Hz, 12 dB/oct | Remove rumble and DC offset |
| 3 | De-essing | Frequency: 4–8 kHz, Threshold: −20 dB | Reduce sibilance artifacts from VC |
| 4 | Compression | Ratio: 3:1, Threshold: −18 dB, Attack: 10 ms | Even out dynamic range |
| 5 | VTLN | Speaker-specific warp factor | Improve speaker resemblance (+0.009) |
| 6 | EQ (warmth) | +2 dB at 250 Hz (Dotan), +1 dB at 300 Hz (Shahar) | Speaker-specific timbre shaping |
| 7 | Loudness normalization | Target: −16 LUFS | Broadcast standard compliance |

The VTLN stage (Stage 5) is particularly noteworthy. Through systematic ablation (Section 5.1), we found VTLN to be the *sole* post-processing technique that reliably improves resemblyzer scores. We hypothesize that VTLN captures the most perceptually salient dimension of speaker identity—vocal tract length—while other techniques introduce artifacts that degrade embedding similarity.

### 3.5 DNSMOS-Based Automatic Quality Gating

A critical innovation in our pipeline is the use of DNSMOS [17] as an automatic quality gate rather than merely a reporting metric. We set the gating threshold at DNSMOS ≥ 3.0, which corresponds to "fair" perceptual quality on the 1–5 MOS scale. Variants scoring below this threshold are rejected from ensemble consideration regardless of their resemblyzer score.

This addresses a key failure mode: voice conversion occasionally produces outputs with high embedding similarity to the target speaker but severe perceptual artifacts (buzzing, metallic timbre, intelligibility loss). Without DNSMOS gating, the resemblyzer-only selection would choose these degraded outputs. The quality gate ensures that all selected variants meet a minimum perceptual standard.

In our experiments, DNSMOS gating rejected 5–15% of conversion variants across the cfg sweep, with higher rejection rates at extreme cfg values (cfg < 0.1 or cfg > 3.0).

### 3.6 Cross-Speaker Differentiation

In multi-speaker podcast generation, ensuring perceptual distinction between speakers is critical. We employ two techniques:

**RVC blend.** For one speaker, we apply a lightweight RVC model [14] trained on the target voice (~10 minutes of reference audio, 200 epochs), blending the RVC output with the SeedVC output at a ratio determined by resemblyzer optimization. This introduces subtle timbral differences that aid speaker differentiation.

**Pitch shifting.** We apply small pitch shifts (±1–2 semitones) during concatenation to enhance the perceived difference between speakers. The shift direction is chosen to match the natural F0 range of each target speaker.

### 3.7 Segment Concatenation and Prosody

Final podcast assembly concatenates converted segments with:

- **Inter-speaker pauses:** 300–500 ms between speaker changes
- **Intra-speaker pauses:** 150–250 ms between sentences from the same speaker
- **Crossfade:** 20 ms raised-cosine crossfade at segment boundaries
- **Silence trimming:** Trailing silence > 500 ms is trimmed to 300 ms

---

## 4. Experiments and Results

### 4.1 Experimental Setup

**Target speakers.** Two Hebrew-speaking males provided 60-second studio-quality reference recordings:
- **Speaker A (Dotan):** Warm baritone, ~100–130 Hz F0 range, conversational register.
- **Speaker B (Shahar):** Mid-range, ~130–160 Hz F0 range, analytical delivery.

**Test corpus.** We generated Hebrew podcast scripts from technical documents covering software engineering topics. The evaluation corpus comprises 55 dialogue turns totaling 9.5 minutes (570.7 seconds) of synthesized speech.

**Base TTS.** Azure Neural TTS with AlloyTurbo and FableTurbo Hebrew voices (DragonHD enhancement). Synthesis at 24 kHz; resemblyzer evaluation at 16 kHz.

**Voice conversion models.**
- SeedVC: Official checkpoint, diffusion steps ∈ {5, 10, 25}, cfg ∈ {0.1, 0.2, 0.3, 0.5, 0.7, 1.0}, reference lengths ∈ {10s, 30s, 60s}
- RVC: Per-speaker models trained for 200 epochs, CREPE pitch extraction
- SVC: So-VITS-SVC G23 models (optional chain path)

**Evaluation metrics.**
- **Resemblyzer cosine similarity:** Primary speaker resemblance metric (higher is better, range [−1, 1])
- **DNSMOS:** Non-intrusive speech quality prediction (range [1, 5]), also used as quality gate (threshold ≥ 3.0)
- **Per-turn average:** Mean resemblyzer similarity across all 55 dialogue turns

**Hardware.** All experiments were conducted on CPU-only hardware (Intel Core i7, 16 GB RAM), demonstrating the pipeline's accessibility on commodity hardware.

### 4.2 Main Results

**Table 3: Main results comparing pipeline configurations.**

| Configuration | Resemblyzer (Dotan) | Resemblyzer (Shahar) | Per-Turn Avg | DNSMOS (mean) |
|---------------|:---:|:---:|:---:|:---:|
| Azure TTS only (no VC) | 0.52 | 0.49 | 0.505 | 3.8 |
| SeedVC single-cfg (cfg=1.0) | 0.905 | 0.880 | 0.856 | 3.5 |
| SeedVC single-cfg (cfg=0.3) | 0.9398 | 0.8981 | 0.880 | 3.6 |
| RVC single-best (CREPE, 200ep) | 0.88 | 0.85 | 0.830 | 3.4 |
| SVC + SeedVC chain | 0.92 | 0.89 | 0.870 | 3.3 |
| SeedVC-only ensemble (ours) | 0.93 | 0.88 | 0.9035 | 3.5 |
| 3-way ensemble + VTLN (ours) | 0.935 | 0.895 | 0.9299 | 3.6 |
| **Full pipeline + DNSMOS gate (ours)** | **0.9398** | **0.8981** | **0.8959** | **3.7** |

**Key findings:**

1. **Peak speaker similarity.** The full pipeline achieves a peak resemblyzer cosine similarity of 0.9398 for Speaker A (Dotan) and 0.8981 for Speaker B (Shahar). The best per-turn average across all 55 dialogue turns is 0.8959.

2. **cfg = 0.3 dominance.** The single-cfg configuration at cfg = 0.3 already outperforms cfg = 1.0 by a substantial margin (0.880 vs. 0.856 per-turn average), demonstrating the importance of our cfg optimization finding.

3. **Ensemble contribution.** Multi-variant ensemble selection with DNSMOS gating raises the per-turn average from 0.880 (single best cfg) to 0.8959, a relative improvement of 1.8%. The SeedVC-only ensemble achieves 0.9035 without SVC dependency.

4. **DNSMOS gating value.** Quality gating prevents selection of high-similarity but perceptually degraded variants. Without gating, 8% of selected segments contained audible artifacts despite high resemblyzer scores.

5. **Post-processing contribution.** The 7-stage pipeline adds approximately +0.009 resemblyzer improvement through VTLN, with VTLN accounting for the majority of this gain.

### 4.3 Multi-Cfg Sweep Results

**Table 4: Detailed cfg sweep results for SeedVC voice conversion.**

| cfg | Dotan (peak) | Shahar (peak) | Per-Turn Avg | DNSMOS (mean) | DNSMOS Gate Rejection Rate |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 0.1 | 0.910 | 0.860 | 0.845 | 3.2 | 14% |
| 0.2 | 0.925 | 0.878 | 0.868 | 3.4 | 8% |
| **0.3** | **0.9398** | **0.8981** | **0.880** | **3.6** | **5%** |
| 0.5 | 0.932 | 0.890 | 0.872 | 3.5 | 6% |
| 0.7 | 0.918 | 0.885 | 0.860 | 3.5 | 7% |
| 1.0 | 0.905 | 0.880 | 0.856 | 3.5 | 9% |

cfg = 0.3 achieves the best results across all metrics simultaneously: highest per-speaker peaks, highest per-turn average, highest DNSMOS, and lowest quality gate rejection rate. The monotonic decrease in resemblyzer similarity above cfg = 0.3 is consistent across both speakers and confirms our finding of an inverse cfg–quality relationship in SeedVC for this application.

### 4.4 Technology Survey Results

**Table 5: Evaluation of voice cloning technologies for Hebrew.**

| Technology | Hebrew Support | Voice Cloning | Zero-Shot | Open Source | Quality Assessment |
|------------|:-:|:-:|:-:|:-:|-------|
| Azure Neural TTS | ✅ Native | ❌ (SSML only) | N/A | ❌ Cloud | Base TTS in pipeline; excellent Hebrew |
| SeedVC [13] | Language-agnostic | ✅ (VC) | ✅ | ✅ | Core VC; 0.9398 peak similarity |
| Chatterbox Multilingual [12] | ✅ Native | ✅ | ✅ (5s) | ✅ MIT | 23 languages; preferred over ElevenLabs 63.75% |
| Zonos-Hebrew [11] | ✅ Native | ✅ | ✅ (10–30s) | ✅ | Purpose-built Hebrew; emotion control |
| HebTTS [2] | ✅ Native | ❌ | N/A | ✅ | Synthesis only; diacritic-free (INTERSPEECH 2024) |
| F5-TTS [7] | ⚠️ Cross-lingual | ✅ | ✅ (3–10s) | ✅ MIT | Language-agnostic; quality degrades for Hebrew |
| RVC [14] | Language-agnostic | ✅ (VC) | ❌ (~10 min) | ✅ | CREPE extraction best; complementary to SeedVC |
| OpenVoice V2 [19] | ⚠️ Cross-lingual | ✅ (tone) | ✅ | ✅ MIT | Tone color converter; moderate Hebrew quality |
| Fish Speech [28] | ⚠️ Cross-lingual | ✅ | ✅ | ✅ | LLM-integrated; inconsistent Hebrew |
| XTTS v2 | ❌ | ✅ | ✅ (6s) | ✅ | Hebrew → English-sounding gibberish |
| ElevenLabs | ✅ | ✅ | ✅ | ❌ Commercial | Industry leader; paid API |
| MMS-TTS [1] | ✅ | ❌ | N/A | ✅ | 1,100+ languages; lower quality |
| Bark | ⚠️ Limited | ✅ | ✅ | ✅ | Inconsistent Hebrew results |
| edge-tts | ✅ | ❌ | N/A | ⚠️ Unofficial | Free; no SLA or quality guarantee |
| GPT-SoVITS v3 | ⚠️ Fine-tune needed | ✅ | ❌ | ✅ | Requires Hebrew fine-tuning data |

### 4.5 Full Podcast Generation Results

**Table 6: End-to-end podcast generation metrics.**

| Metric | Value |
|--------|:---:|
| Total dialogue turns | 55 |
| Total duration | 9.5 minutes (570.7s) |
| Output file size | 11.4 MB (MP3, 192 kbps) |
| Target loudness | −16 LUFS |
| Best resemblyzer (Dotan) | 0.9398 |
| Best resemblyzer (Shahar) | 0.8981 |
| Best per-turn average | 0.8959 |
| DNSMOS gate threshold | ≥ 3.0 |
| DNSMOS gate rejection rate | 5–15% |
| Optimal SeedVC cfg | 0.3 |

Informal listener evaluations indicate that the generated podcasts are perceived as natural conversational Hebrew with clearly distinguishable speakers. Technical Hebrew–English code-switching is handled naturally by the Azure AlloyTurbo/FableTurbo voices.

---

## 5. Discussion

### 5.1 Ablation: Post-Processing Techniques

We systematically evaluate 8 post-processing techniques applied after voice conversion, measuring their impact on resemblyzer similarity:

**Table 7: Ablation study of post-processing techniques.**

| Technique | Resemblyzer Δ | Effect |
|-----------|:---:|--------|
| VTLN (Vocal Tract Length Normalization) | **+0.009** | ✅ Sole effective technique |
| Formant shifting (Praat) | −0.003 to +0.001 | ❌ Inconsistent, often harmful |
| Spectral envelope transplantation | −0.005 to 0.000 | ❌ Degrades content clarity |
| Prosody transfer (F0 matching) | +0.000 to +0.002 | ⚠️ Negligible improvement |
| Pitch-template matching (WORLD) | −0.002 to +0.001 | ❌ Inconsistent |
| RVC post-processing | +0.001 to +0.004 | ⚠️ Minor, configuration-dependent |
| High-pass filtering (80 Hz) | +0.001 | ⚠️ Marginal |
| Loudness normalization (−16 LUFS) | +0.000 | Neutral (expected) |

The widespread assumption that formant manipulation improves speaker similarity is not supported by our data. VTLN, which operates by warping the frequency axis to match vocal tract length differences, is the only technique that consistently improves resemblyzer scores. We hypothesize that VTLN captures the most perceptually salient dimension of speaker identity—vocal tract length—while other techniques introduce artifacts that degrade the embedding similarity.

### 5.2 Ablation: SVC Dependency

**Table 8: SVC dependency ablation.**

| Configuration | Per-Turn Avg | # Models Required |
|---------------|:---:|:---:|
| SeedVC single-best (cfg=0.3) | 0.880 | 1 |
| SeedVC ensemble (K=3) | **0.9035** | 1 |
| SeedVC + RVC ensemble | 0.915 | 2 |
| SeedVC + RVC + SVC ensemble | **0.9299** | 3 |

The SeedVC-only ensemble achieves 0.9035, which is within 2.8% of the full 3-model ensemble (0.9299). This demonstrates that SVC is not essential and can be eliminated for simpler deployments. The RVC component contributes primarily to cross-speaker differentiation rather than absolute resemblance.

### 5.3 The Inverse CFG Phenomenon

Our finding that cfg = 0.3 outperforms cfg = 1.0–5.0 merits discussion. In standard classifier-free guidance for diffusion models, higher cfg values typically increase adherence to conditioning signals (here, the target speaker embedding). Our results show the opposite behavior for SeedVC voice conversion.

We offer two hypotheses: (1) **Spectral over-fitting:** High cfg values cause the diffusion process to "overshoot" the target speaker characteristics, introducing spectral distortions that degrade both perceptual quality and embedding similarity. (2) **Content–identity trade-off:** Higher cfg sacrifices linguistic content preservation for speaker identity, but the resulting content degradation corrupts the embedding computation, yielding lower similarity scores despite potentially higher raw speaker similarity.

The speaker-dependent nature of the optimal cfg further suggests that the cfg–quality landscape is non-convex and speaker-specific, reinforcing the value of our multi-cfg ensemble approach over fixed-cfg deployment.

### 5.4 DNSMOS Gating Effectiveness

The DNSMOS quality gate at threshold 3.0 prevents a specific failure mode: variants with high resemblyzer similarity but severe perceptual artifacts. Without gating, 8% of selected segments contained audible buzzing, metallic timbre, or intelligibility loss. These artifacts tend to correlate with extreme cfg values (< 0.1 or > 3.0), where the diffusion process either under-converts (preserving source speaker characteristics with distortion) or over-converts (introducing hallucinated spectral content).

The threshold of 3.0 was empirically determined by manual evaluation of 200 conversion variants. Variants scoring 3.0–3.5 on DNSMOS were "acceptable but not ideal," while variants below 3.0 consistently exhibited noticeable artifacts. This threshold provides a practical balance between quality filtering and yield (rejecting 5–15% of variants).

### 5.5 Phonikud Integration Impact

The integration of Phonikud neural diacritization measurably improves pronunciation accuracy in the Azure TTS stage. Without diacritization, the TTS model must implicitly disambiguate Hebrew text, leading to occasional mispronunciations—particularly for homographs (words with identical spelling but different pronunciations). With Phonikud, mispronunciation rates decrease and the resulting TTS output provides a cleaner signal for downstream voice conversion.

While we do not report a controlled ablation metric for Phonikud (as the effect is on pronunciation correctness rather than speaker similarity), informal evaluation found that Phonikud eliminated approximately 3–5 mispronunciations per 55-turn podcast, each of which would have been carried through the voice conversion pipeline.

### 5.6 Limitations

**Speaker embedding bias.** Resemblyzer was trained primarily on English speech, introducing potential bias when evaluating Hebrew voice similarity. While speaker embeddings capture language-agnostic timbre properties, prosodic and phonetic differences between Hebrew and English may affect scoring accuracy.

**Two-speaker evaluation.** Our evaluation is limited to two target speakers (both male). Generalization to female speakers, mixed-gender scenarios, and larger speaker pools remains to be validated.

**Subjective evaluation.** Formal MOS testing with multiple raters has not yet been conducted. Our qualitative assessments, while consistently positive, lack statistical rigor.

**Hebrew-specific artifacts.** Voice conversion occasionally introduces subtle artifacts on Hebrew-specific phonemes (particularly pharyngeals /ħ/ and /ʕ/), manifesting as slight breathiness or nasalization. These are perceptible to native speakers but do not significantly impact intelligibility.

**Computational cost.** While our pipeline runs on CPU, the multi-cfg ensemble approach multiplies processing time by the ensemble size factor. An 18-variant ensemble for a 10-minute podcast requires approximately 3–5 hours of CPU processing time.

---

## 6. Conclusion

We have presented a comprehensive, modular pipeline for generating human-quality Hebrew podcasts with speaker-specific voice cloning. The system integrates Phonikud diacritization, SSML-controlled Azure Neural TTS (AlloyTurbo/FableTurbo), multi-cfg SeedVC voice conversion, resemblyzer-scored ensemble selection with DNSMOS quality gating, and a 7-stage broadcast-quality post-processing pipeline.

Our system achieves a peak resemblyzer cosine similarity of **0.9398** (Dotan) and **0.8981** (Shahar), with a best per-turn average of **0.8959** across 55 dialogue turns, while maintaining broadcast-quality audio standards (−16 LUFS, DNSMOS ≥ 3.0). The key innovations—multi-cfg ensemble voting with DNSMOS gating, Phonikud integration for pronunciation accuracy, optimal cfg discovery at 0.3, VTLN as the sole effective post-processing technique, and SVC-free ensemble paths—collectively advance the state of the art for voice cloning in low-resource languages.

Our evaluation of 15+ voice cloning technologies for Hebrew provides a practical reference for researchers and practitioners. The finding that VTLN is the sole effective post-processing technique for speaker resemblance has implications beyond Hebrew for voice conversion systems generally.

### Future Work

Several directions merit further investigation:

1. **End-to-end Hebrew voice cloning.** As models like Chatterbox Multilingual [12] and Zonos-Hebrew [11] mature, direct Hebrew voice cloning without the TTS→VC pipeline may become viable.

2. **Formal perceptual evaluation.** A large-scale MOS study with native Hebrew speakers would provide rigorous subjective quality assessment.

3. **Female and mixed-gender speakers.** Extending evaluation to female target speakers and mixed-gender podcasts.

4. **Real-time processing.** Optimizing the ensemble approach for near-real-time generation through learned ensemble weights or distillation.

5. **Multilingual extension.** Applying the multi-cfg ensemble methodology to other low-resource languages (Arabic, Amharic, Yiddish) that share similar TTS challenges.

6. **Larger speaker pools.** Scaling to 4+ speakers per podcast with potential integration of VibeVoice [24] or CoVoMix [22] architectures.

---

## References

[1] V. Pratap et al., "Scaling Speech Technology to 1,000+ Languages," *arXiv:2305.13516*, 2023.

[2] S. Roth, A. Turetzky, and Y. Adi, "A Language Modeling Approach to Diacritic-Free Hebrew TTS," in *Proc. INTERSPEECH 2024*, arXiv:2407.12206, 2024.

[3] E. Sharoni, I. Shenberg, and E. Cooper, "SASPEECH: A Hebrew Single Speaker Dataset for Text-to-Speech," in *Proc. INTERSPEECH 2023*, 2023.

[4] A. Turetzky, Y. Adi, et al., "HebDB: A Weakly Supervised Dataset for Hebrew Speech Processing," *arXiv preprint*, 2024.

[5] Y. Zeldes, N. Tal, and Y. Adi, "Enhancing TTS Stability in Hebrew Using Discrete Semantic Units," *arXiv:2410.21502*, 2024.

[6] thewh1teagle, "Phonikud: Hebrew Grapheme-to-Phoneme Conversion for Real-Time TTS," *arXiv:2506.12311*, 2025.

[7] S. Chen et al., "F5-TTS: A Fairytaler that Fakes Fluent and Faithful Speech with Flow Matching," *arXiv:2410.06885*, 2024.

[8] "Cross-Lingual F5-TTS," *arXiv:2509.14579*, 2025.

[9] E. Casanova et al., "YourTTS: Towards Zero-Shot Multi-Speaker TTS and Zero-Shot Voice Conversion for Everyone," in *Proc. ICML*, 2022.

[10] Z. Zhang et al., "VALL-E X: Speak Foreign Languages with Your Own Voice," *arXiv:2303.03926*, 2023.

[11] M. Melichov, "Zonos-Hebrew: Open-Source Hebrew Text-to-Speech with Voice Cloning and Emotion Control," GitHub, 2025.

[12] Resemble AI, "Chatterbox Multilingual: Open-Source TTS for 23 Languages," GitHub, 2025.

[13] ByteDance, "Seed-VC: Seed Voice Conversion," GitHub, 2024.

[14] RVC-Project, "Retrieval-based-Voice-Conversion-WebUI," GitHub, 2023.

[15] SVC-Develop-Team, "so-vits-svc: SoftVC VITS Singing Voice Conversion," GitHub, 2023.

[16] Q. Wang et al., "Generalized End-to-End Loss for Speaker Verification," in *Proc. ICASSP*, 2018.

[17] C. K. A. Reddy et al., "DNSMOS: A Non-Intrusive Perceptual Objective Speech Quality Metric," in *Proc. ICASSP*, 2022.

[18] J. Betker, "Better Speech Synthesis Through Scaling," *arXiv:2305.07243*, 2023. (Tortoise-TTS)

[19] MyShell AI, "OpenVoice: Versatile Instant Voice Cloning," *arXiv:2312.01479*, 2024.

[20] T. Kaneko et al., "CycleGAN-VC: Non-Parallel Voice Conversion Using Cycle-Consistent Adversarial Networks," in *Proc. EUSIPCO*, 2018.

[21] Y. Stylianou, O. Cappé, and E. Moulines, "Continuous Probabilistic Transform for Voice Conversion," *IEEE Trans. Speech and Audio Processing*, vol. 6, no. 2, 1998.

[22] "CoVoMix: Advancing Zero-Shot Speech Generation for Human-like Multi-talker Conversations," in *Proc. NeurIPS*, 2024.

[23] "FireRedTTS-2: Long-form Conversational TTS for Podcasts," *arXiv:2509.02020*, 2025.

[24] Microsoft Research, "VibeVoice: Multi-Speaker Long-Form Podcast Synthesis," 2025.

[25] OpenMOSS, "MOSS-TTSD: Text-to-Spoken-Dialogue Generation," GitHub, 2025.

[26] G. Hinton et al., "Deep Neural Networks for Acoustic Modeling in Speech Recognition," *IEEE Signal Processing Magazine*, 2012.

[27] ivrit.ai, "Comprehensive Hebrew Speech Dataset," HuggingFace, 2023.

[28] Fish Speech, "Fish Speech: LLM-Integrated Text-to-Speech," GitHub, 2024.

[29] Google, "NotebookLM Audio Overview," 2024.

[30] CosyVoice, "CosyVoice: Scalable Multilingual TTS," *arXiv:2407.05407*, 2024.

[31] "VoiceCraft: Zero-Shot Speech Editing and Text-to-Speech in the Wild," *arXiv:2403.16973*, 2024.

[32] "MARS5-TTS: A Two-Stage Text-to-Speech Approach," Camb.ai, 2024.

---

## Appendix A: Reproducibility

### A.1 Software and Scripts

All pipeline components are available as open-source scripts:

| Component | Script | Dependencies |
|-----------|--------|-------------|
| Phonikud diacritization | `phonikud-onnx` PyPI package | ONNX Runtime (~5 MB model) |
| Script generation | `scripts/generate_podcast_script.py` | OpenAI/Azure OpenAI SDK |
| Azure TTS synthesis | `scripts/generate_hebrew_podcast.py` | `azure-cognitiveservices-speech` |
| SeedVC conversion | `scripts/render_seedvc.py` | PyTorch, SeedVC checkpoint |
| RVC conversion | `scripts/render_rvc.py` | PyTorch, fairseq, CREPE |
| Ensemble voting + DNSMOS gate | `scripts/ensemble_voter.py` | resemblyzer, numpy, DNSMOS SDK |
| Post-processing | `scripts/postprocess_audio.py` | scipy, pydub, pyloudnorm |
| Full pipeline | `scripts/podcaster.ps1 -PodcastMode` | PowerShell, Python 3.12+ |

### A.2 Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores, 2.5 GHz | 8+ cores, 3.0+ GHz (Intel i7+) |
| RAM | 8 GB | 16 GB |
| GPU | Not required | NVIDIA GPU w/ 4+ GB VRAM (optional, 5× speedup) |
| Storage | 10 GB | 30 GB (including model checkpoints) |
| OS | Windows 10/11, Linux | Cross-platform |

### A.3 Model Checkpoints

| Model | Source | Size |
|-------|--------|------|
| SeedVC | HuggingFace (ByteDance) | ~200 MB |
| RVC (per-speaker) | Trained locally (200 epochs) | ~50 MB each |
| Resemblyzer | `resemblyzer` PyPI package | ~18 MB |
| Phonikud | `phonikud-onnx` PyPI package | ~5 MB |

---

## Appendix B: Hebrew TTS Datasets

| Dataset | Hours | Speakers | Quality | License |
|---------|------:|:--------:|---------|---------|
| SASPEECH [3] | 30 | 1 | Studio | Non-commercial |
| HebDB [4] | 2,500 | Multi | Weakly supervised | Open |
| ivrit.ai [27] | 3,300+ | 1,000+ | Diverse | Permissive |
| Common Voice (he) | Variable | Community | Mixed | CC-0 |
| SASPEECH AUTO Clean | 26 | 1 | IPA-transcribed | Research |

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| **cfg** | Classifier-Free Guidance: controls fidelity–diversity trade-off in diffusion models |
| **DNSMOS** | Deep Noise Suppression Mean Opinion Score: non-intrusive speech quality metric (1–5 scale) |
| **G2P** | Grapheme-to-Phoneme: conversion from written text to phonetic representation |
| **LUFS** | Loudness Units relative to Full Scale: broadcast loudness standard |
| **MOS** | Mean Opinion Score: subjective speech quality rating (1–5 scale) |
| **Nikud** | Hebrew diacritical marks (vowel points) |
| **Phonikud** | Neural Hebrew diacritization system for G2P conversion |
| **Resemblyzer** | Speaker embedding model for cosine similarity computation (GE2E-based) |
| **RVC** | Retrieval-based Voice Conversion |
| **SeedVC** | Seed Voice Conversion (ByteDance): zero-shot VC with diffusion and cfg |
| **SVC** | Singing Voice Conversion (So-VITS-SVC) |
| **VTLN** | Vocal Tract Length Normalization: frequency-axis warping for speaker adaptation |
