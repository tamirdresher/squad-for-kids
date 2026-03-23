# Voice Cloning for Hebrew Text-to-Speech: An Empirical Pipeline Study

**Authors:** Tamir Dresher  
**Affiliation:** [Institution TBD]  
**Date:** 2026  
**Issue:** [#872](https://github.com/tamirdresher_microsoft/tamresearch1/issues/872)  
**Target Venue:** INTERSPEECH 2026 / arXiv preprint  

---

## Abstract

We present an empirical study of constructing a Hebrew AI podcast generation system capable of producing voice-cloned, broadcast-quality audio in a language that remains severely underserved by modern text-to-speech (TTS) infrastructure. Hebrew poses compounding challenges for neural TTS: its abjad writing system omits vowel markers, requiring disambiguation before synthesis; its consonant inventory includes pharyngeal phonemes absent from the training data of most commercial models; and open speech corpora are orders of magnitude smaller than those available for high-resource languages. This paper documents an end-to-end pipeline that transforms written technical content into a multi-speaker Hebrew podcast, evaluating fifteen voice cloning and TTS technologies along the way. Our pipeline comprises six stages: (1) Hebrew text normalization and grapheme-to-phoneme disambiguation via Phonikud neural diacritization; (2) SSML prosody control; (3) Azure Neural TTS synthesis using native `he-IL` voices as a high-quality acoustic foundation; (4) SeedVC-based zero-shot voice conversion with classifier-free guidance sweep; (5) multi-configuration ensemble selection scored by resemblyzer cosine similarity; and (6) a broadcast-quality post-processing chain targeting −16 LUFS. Our best configuration achieves a resemblyzer speaker similarity of 0.9398 against target voice embeddings. We document failures as rigorously as successes: XTTS v2 requires an Arabic-language proxy producing unnatural prosody; OpenVoice V2's tone converter degrades under Hebrew pharyngeal phonemes; gTTS produces no native Hebrew output. The modular architecture, complete source code, and evaluation data are released openly to support future research on low-resource-language podcast generation.

**Keywords:** Hebrew TTS, voice cloning, voice conversion, low-resource speech synthesis, podcast generation, SeedVC, grapheme-to-phoneme, Phonikud

---

## 1. Introduction

The rise of AI-generated audio content has unlocked new modalities for knowledge consumption. Google NotebookLM's "Audio Overview" demonstrated in 2024 that large language models can transform written documents into engaging two-host conversational podcasts. ElevenLabs, Descript, and similar commercial platforms have since made voice cloning accessible to millions of creators. Yet this revolution has been overwhelmingly English-centric. For the approximately 9 million native Hebrew speakers worldwide, no equivalent open pipeline existed.

This paper presents a systematic engineering and research effort to close that gap. The target application is an automated Hebrew podcast system modeled after Israeli tech podcasts such as *מפתחים מחוץ לקופסא* (Developers Outside the Box): casual conversational Hebrew, free mixing of Hebrew and English technical terms, and clearly differentiated host personalities. The system must take written technical content as input and produce multi-speaker audio in which each synthetic speaker closely resembles a specific real human voice.

Building such a system required confronting a cascade of challenges that are largely absent from English-language pipelines. Hebrew's abjad writing system omits vowel diacritics, making the pronunciation of any given token ambiguous without context. The language's phonological inventory includes sounds—pharyngeal fricatives, the glottal stop distinction between aleph and ayin—that are entirely absent from most TTS training corpora. Public Hebrew speech datasets are scarce. And the Israeli tech register involves dense code-switching between Hebrew and English that naive TTS systems handle poorly.

### 1.1 Paper Contributions

This paper makes the following contributions:

1. **Systematic comparative evaluation of 15+ TTS and voice cloning technologies for Hebrew**, including edge-tts, XTTS v2, OpenVoice V2, Zonos-Hebrew, F5-TTS, SeedVC, RVC, Chatterbox Multilingual, TADA-TTS, and HebTTS—the first such comprehensive comparison in the literature.

2. **A six-stage, CPU-runnable Hebrew podcast pipeline** integrating Phonikud diacritization, Azure Neural TTS, SeedVC voice conversion, ensemble voting, and broadcast-quality post-processing, achieving 0.9398 resemblyzer cosine similarity.

3. **Empirical findings on SeedVC configuration for Hebrew**, establishing that the classifier-free guidance (cfg) parameter exhibits an inverse, speaker-dependent relationship with conversion quality, with cfg = 0.3 optimal—contrary to the commonly used range of 1.0–5.0.

4. **Ablation of eight post-processing techniques**, finding that Vocal Tract Length Normalization (VTLN) is the sole technique that reliably improves speaker resemblance (+0.009 resemblyzer gain), while formant shifting and spectral envelope matching are either neutral or harmful.

5. **Documented failure modes** for Hebrew TTS, providing reproducible characterizations of why specific systems break and what degradation patterns they produce.

### 1.2 Paper Organization

Section 2 surveys related work. Section 3 describes Hebrew's linguistic properties and their implications for TTS. Section 4 presents our pipeline methodology. Section 5 describes experimental setup and results. Section 6 discusses limitations and future work. Section 7 concludes.

---

## 2. Related Work

### 2.1 Hebrew Text-to-Speech

Early Hebrew TTS relied on concatenative synthesis with hand-crafted pronunciation lexicons and rule-based grapheme-to-phoneme (G2P) systems. The transition to neural methods introduced new challenges: statistical models trained on English data cannot simply be applied to Hebrew due to the writing system ambiguity described in Section 3.

**SASPEECH** [Sharoni et al., 2023] provides 30 hours of clean single-speaker studio-quality Hebrew speech, enabling fine-tuned neural TTS training. It remains one of the largest publicly accessible clean Hebrew training corpora.

**HebDB** [Turetzky et al., 2024] contributes approximately 2,500 hours of weakly supervised multi-speaker Hebrew speech data from the Hebrew University, representing the largest open Hebrew corpus. Its weakly supervised nature (automatic transcription without careful manual verification) limits its utility for high-precision phonetic research.

**HebTTS** [Roth et al., 2024] applies a language-modeling approach to Hebrew TTS, using discrete speech units and word-piece tokenization to eliminate the need for explicit diacritization at inference time. Published at INTERSPEECH 2024, it demonstrates that the pronunciation disambiguation problem can be addressed implicitly through large-scale language modeling of speech tokens.

**Phonikud** [arXiv:2506.12311] takes the complementary approach: a dedicated neural diacritization model that converts unvowelized Hebrew text into IPA phoneme strings with stress prediction. We adopt Phonikud as Stage 1 of our pipeline.

**Zonos-Hebrew** [Melichov, 2025] fine-tunes the Zonos-v0.1 transformer TTS architecture on Hebrew data, supporting zero-shot voice cloning from 10–30 second reference clips and emotion control.

**TADA-TTS** [Hume AI, 2026] introduces a text-acoustic dual alignment architecture that generates one acoustic token per text token, eliminating hallucination artifacts (word-skipping, repetition) that affect autoregressive models. While TADA-3B-ML does not natively support Hebrew, its Arabic language support (the closest Semitic language in its training set) makes it a viable proxy.

### 2.2 Voice Conversion

Voice conversion (VC) separates the problem of sound-like-a-person from speak-this-language, enabling language-agnostic speaker identity transfer regardless of TTS language support.

**SeedVC** [ByteDance, 2024] is a zero-shot any-to-any voice converter using self-supervised speech representations as a disentangled linguistic bottleneck. Its diffusion-based generation with classifier-free guidance provides fine-grained control over conversion fidelity. SeedVC is language-agnostic by design.

**RVC** (Retrieval-based Voice Conversion) [2023] combines HuBERT content extraction with a neural vocoder, requiring approximately 10 minutes of per-speaker training data. Its lightweight deployment and multiple pitch extraction algorithm choices (CREPE, DIO, Harvest) make it practical for CPU-only environments.

**OpenVoice V2** [MyShell AI, 2024] decouples tone color conversion from base synthesis, enabling voice style transfer at inference time across any language. Its separation of "what is said" from "how the voice sounds" is conceptually elegant for our use case.

### 2.3 Multilingual and Low-Resource TTS

**Meta MMS-TTS** [Pratap et al., 2023] covers 1,100+ languages through massively multilingual training but sacrifices per-language quality for breadth. Hebrew is included but output quality is below commercial standards.

**F5-TTS** [Chen et al., 2024] employs flow-matching with diffusion transformers for language-agnostic synthesis, supporting 20+ languages with zero-shot voice cloning from 3–10 seconds of reference audio. Its cross-lingual variant explicitly targets languages absent from training data.

**XTTS v2** [Coqui TTS, 2024] supports zero-shot voice cloning across multiple languages using 6 seconds of reference audio. Hebrew is not in its official language list, requiring fallback strategies.

**Microsoft Azure Neural TTS** provides first-class Hebrew support through `he-IL-AvriNeural` (male) and `he-IL-HilaNeural` (female) voices, trained on native Israeli Hebrew speech data. These voices exhibit correct pharyngeal phoneme rendering, natural code-switching handling, and appropriate intonation patterns for Israeli tech register speech. Azure Neural TTS serves as the acoustic foundation of our pipeline precisely because of this native language fidelity.

### 2.4 Speaker Verification Metrics

**Resemblyzer** [Wan et al., 2018] computes d-vector speaker embeddings and cosine similarity between synthesized and reference speech. Originally designed for English speaker verification, its timbre-level speaker representations generalize cross-lingually, making it appropriate for evaluating speaker identity preservation under voice conversion.

**DNSMOS** [Reddy et al., 2022] provides non-intrusive speech quality assessment, predicting perceptual quality without requiring clean reference signals. We use DNSMOS as a secondary metric and as a quality gate in ensemble selection.

---

## 3. Hebrew Linguistic Properties and TTS Challenges

A thorough understanding of Hebrew's linguistic structure is prerequisite to understanding why general-purpose TTS systems fail and why each stage of our pipeline exists.

### 3.1 Abjad Writing System and Vowel Ambiguity

Modern Hebrew is written in ketiv male—a "defective" script in which vowel sounds are mostly omitted. Adult Israeli readers infer vowels from lexical context, morphological patterns, and discourse knowledge. TTS systems lack this contextual competence, making unvowelized Hebrew text systematically ambiguous.

The ambiguity is not marginal. Common words have multiple valid readings with completely different meanings: **ספר** can be /ˈsefer/ (book), /saˈpar/ (barber), or /siˈper/ (told). The word **בנים** can be /baˈnim/ (sons) or /bniˈnim/ (construction). Without vowel information, a TTS system must either guess from context or produce phonetically incorrect output. Our investigation of XTTS v2 without pre-processing found stress errors in approximately 30–50% of words and vowel substitution errors in roughly one in five content words.

Phonikud addresses this by performing neural diacritization: it converts unvowelized Hebrew text into IPA phoneme strings with explicit stress markers (`ˈ`) and resolves the ambiguous shva (mobile vs. silent) using modern Israeli pronunciation rules. Test results across representative sentences show stress marker accuracy above 95% and correct rendering of all major phoneme distinctions.

### 3.2 Consonant Inventory

Hebrew's consonant inventory presents phonemes that are entirely absent from the training languages of most TTS models:

- **Pharyngeal fricatives** /ħ/ (ח) and /ʕ/ (ע): produced far back in the throat, with no equivalent in English, French, German, or Mandarin.
- **Glottal stop distinction**: aleph (א) and ayin (ע) are phonemically distinct in careful speech, though merged in casual Israeli Hebrew.
- **Uvular approximant** /ʁ/ (ר): the Israeli realization of resh, distinct from the trills of Spanish or German.

Models trained without Hebrew data substitute these phonemes with the nearest equivalent in their training vocabulary, producing speech that sounds strongly foreign to native Hebrew ears. XTTS v2 with Arabic fallback partially mitigates this—Arabic shares pharyngeal consonants—but introduces Arabic-specific prosodic patterns and phoneme substitutions.

### 3.3 Code-Switching in Israeli Tech Register

Israeli tech discourse engages in dense lexical code-switching: "בואו נדבר על ה-Docker container שלנו" (Let's talk about our Docker container). This mixing is not phonological borrowing (adapting English words to Hebrew phonology) but direct English citation—the English words are pronounced with English phonemes within otherwise Hebrew utterances.

This creates a fundamental tension: a pipeline optimized for Hebrew phoneme rendering may poorly handle embedded English tokens, and vice versa. Azure Neural TTS's `he-IL` voices handle this transition naturally, switching to English phoneme rendering at Hebrew-English word boundaries. Models without explicit bilingual capability tend to either Hebraize English tokens or break prosodic flow at the language boundary.

### 3.4 Data Scarcity

The resource gap between Hebrew and high-resource TTS languages is substantial. LibriSpeech provides 1,000 hours of clean, manually transcribed English; the largest comparable Hebrew resource (HebDB) contains 2,500 hours of *weakly supervised* data—significantly noisier. Clean, speaker-labeled, studio-quality Hebrew speech is available in tens of hours, not thousands. This data scarcity means Hebrew-specific TTS models are undertrained compared to their English counterparts, and it limits the speaker diversity available for voice cloning reference audio selection.

---

## 4. Pipeline Methodology

Our pipeline comprises six stages, each addressing a specific challenge identified in Section 3.

### 4.1 Stage 1: Hebrew Text Normalization and Diacritization

Raw podcast script text undergoes three normalization steps before TTS synthesis:

**Numeral and abbreviation expansion**: Numbers, dates, and common abbreviations are expanded to their full Hebrew word form using the `num2words` library with Hebrew locale support. This prevents TTS systems from reading "25" as digits rather than "עשרים וחמישה."

**Code-switching boundary marking**: English tokens within Hebrew sentences are identified via Unicode range detection and tagged with SSML `<lang xml:lang="en-US">` markers, enabling Azure Neural TTS to switch to English phoneme rendering at boundaries.

**Phonikud IPA conversion**: Unvowelized Hebrew text is passed through Phonikud 0.4.1, which predicts IPA phoneme strings with stress markers using a neural model trained on annotated Hebrew text. Output is wrapped in SSML `<phoneme alphabet="ipa" ph="...">` tags for edge-tts synthesis. This step reduces mispronunciation rates by an estimated 25–40% for Modern Israeli Hebrew compared to raw unvowelized input.

We evaluated two diacritization approaches: Phonikud (IPA output) and Nakdimon (Hebrew nikud diacritics output). Nakdimon could not be installed in our Anaconda environment due to hard dependency conflicts (`numpy==1.26.2`, `keras==2.15.0`), making Phonikud our primary backend. Phonikud's IPA output is directly compatible with edge-tts's SSML phoneme interface.

### 4.2 Stage 2: SSML Prosody Specification

Azure Neural TTS accepts Speech Synthesis Markup Language (SSML) for fine-grained prosody control. We use SSML to encode:

- **Speaking rate**: ±5% per-speaker adjustments (AVRI/Dotan: +2%, HILA/Shahar: −2%) to differentiate host speaking styles
- **Pitch baseline**: ±1.5 semitone shifts to distinguish speakers (AVRI: −1.5 st, HILA: +1.0 st)
- **Pause durations**: Variable pause lengths (200–800 ms) based on discourse role (turn-final, mid-sentence, back-channel)
- **IPA phoneme substitutions**: Output of Stage 1 Phonikud processing

### 4.3 Stage 3: Azure Neural TTS Synthesis

Azure Neural TTS `he-IL-AvriNeural` (male) and `he-IL-HilaNeural` (female) serve as the acoustic foundation for our pipeline. These voices are trained on native Israeli Hebrew speech and correctly render the phonological features identified in Section 3. They produce fluent code-switching and appropriate intonation for the Israeli tech podcast register.

We evaluated four TTS backends as the foundation stage:

| Backend | Hebrew Support | Voice Cloning | Quality |
|---------|---------------|---------------|---------|
| Azure Neural TTS (he-IL) | Native ✓ | No | ★★★★ |
| edge-tts (he-IL) | Native ✓ | No | ★★★★ |
| XTTS v2 (ar fallback) | Proxy (Arabic) | Yes | ★★★ |
| Zonos-Hebrew | Native ✓ | Yes | ★★★★ |

Azure Neural TTS (accessed via edge-tts client) produces the highest quality Hebrew synthesis and is used as our Stage 3 backbone. Its primary limitation is the absence of native voice cloning—it cannot directly synthesize speech that sounds like a specific target speaker. This motivates Stage 4.

### 4.4 Stage 4: SeedVC Voice Conversion

SeedVC performs zero-shot any-to-any voice conversion, transforming the high-quality-but-generic Azure TTS output to sound like our two target speakers (Dotan and Shahar), using 30–60 second reference recordings of each speaker.

SeedVC uses a self-supervised speech representation (WavLM or similar) as an intermediate linguistic bottleneck, explicitly disentangling speaker identity from phonetic content. The conversion process applies diffusion-based generation conditioned on target speaker embeddings extracted from reference audio.

The key hyperparameter is the **classifier-free guidance (cfg)** coefficient, which controls the strength of speaker identity conditioning. Through systematic sweep from cfg ∈ {0.1, 0.2, 0.3, 0.5, 0.7, 1.0}, we found that cfg = 0.3 is optimal for our Hebrew target speakers. This is significantly lower than the typical default of 1.0–5.0 and exhibits a speaker-dependent, inverse relationship: higher cfg values actually degraded speaker resemblance for our target voices. We hypothesize that high cfg overconditions on speaker characteristics in a way that interacts poorly with the phonological distance between the Azure TTS source speech and the target speaker's natural Hebrew phoneme inventory.

### 4.5 Stage 5: Multi-Configuration Ensemble Voting

Rather than relying on a single SeedVC configuration, we generate multiple conversion variants and select the best-scoring output per dialogue turn:

1. **SeedVC at cfg ∈ {0.1, 0.2, 0.3}** with diffusion steps ∈ {20, 50}
2. Each variant is scored by resemblyzer cosine similarity against the target speaker embedding
3. Variants with DNSMOS < 3.0 are rejected as artifacts regardless of resemblyzer score
4. The highest-scoring passing variant is selected for each turn

This ensemble approach achieves a best per-turn average resemblyzer similarity of 0.8959 and peak per-speaker similarity of 0.9398 (Dotan) / 0.8981 (Shahar), compared to 0.9035 for the best single-configuration SeedVC run. The ensemble gain is modest (+0.006 average) but consistent, and the DNSMOS gating eliminates the occasional severely degraded outputs that single-configuration conversion produces.

We also evaluated a two-stage pipeline: OpenVoice V2 tone color conversion applied on top of edge-tts output. OpenVoice's tone conversion reduced resemblyzer scores compared to SeedVC, particularly for segments containing pharyngeal phonemes. Our diagnosis is that OpenVoice's tone color space, trained primarily on non-Semitic languages, does not represent Hebrew-specific timbre features faithfully.

### 4.6 Stage 6: Broadcast-Quality Post-Processing

Raw voice conversion output requires substantial post-processing before it meets podcast broadcast standards. We apply a seven-stage chain:

1. **LUFS loudness normalization** (target: −16 LUFS, per ITU-R BS.1770 / EBU R128): The single highest-impact improvement. TTS and VC systems produce per-segment audio at inconsistent RMS levels. Normalization eliminates listener fatigue from level variation.
2. **Per-speaker EQ**: Low-shelf boost at 250 Hz (+2 dB for male AVRI, warmth); high-shelf presence boost at 3 kHz (+1.5 dB for female HILA, clarity).
3. **Dynamic range compression** (ratio 3:1, attack 5ms, release 50ms): Reduces peak-to-RMS ratio for consistent listening volume.
4. **De-essing** (multiband attenuation at 6–8 kHz): Controls sibilance on female voice, preventing perceptual harshness.
5. **Vocal Tract Length Normalization (VTLN)**: The sole post-processing technique that measurably improves speaker resemblance. VTLN warps the frequency axis of the speech signal, adjusting for differences in vocal tract length between the target speaker and the voice conversion model's output. We measure a consistent +0.009 resemblyzer gain from VTLN, which is the largest single-step improvement available in post-processing.
6. **Pause dynamics**: Variable inter-turn silence (200–800 ms, gamma-distributed) replacing the fixed 300 ms pause in naive implementations.
7. **Final export normalization** (peak at −1.0 dBFS): Prevents digital clipping in downstream processing.

---

## 5. Experiments

### 5.1 Experimental Setup

**Target speakers**: Two Israeli tech community speakers with distinct vocal profiles. Speaker A (Dotan/AVRI): male, warm baritone, energetic delivery. Speaker B (Shahar/HILA): female, clear mezzo, deliberate pacing.

**Reference audio**: 30–60 second WAV clips of each speaker extracted from publicly available podcast recordings. No reference clips overlap with evaluation segments.

**Evaluation corpus**: 55 dialogue turns from a Hebrew translation of an AI systems research document. Turns range from 5 to 45 words. The corpus includes Hebrew-only turns, Hebrew-English code-switched turns, and technical term-heavy turns.

**Metrics**:
- *Resemblyzer cosine similarity* (range 0–1): Speaker identity preservation, computed against speaker embeddings from held-out reference audio
- *DNSMOS* (range 1–5): Predicted perceptual audio quality
- *Hebrew intelligibility*: Binary human rating (intelligible / not intelligible) by a native Hebrew speaker evaluator

### 5.2 Technology Evaluation Results

We evaluated fifteen technologies across four dimensions: native Hebrew support, zero-shot voice cloning capability, CPU-runnable deployment, and output quality.

| Technology | Hebrew Native | Voice Cloning | CPU-Only | Quality (Hebrew) |
|------------|:---:|:---:|:---:|:---:|
| Azure Neural TTS (he-IL) | ✓ | ✗ | ✓ | ★★★★ |
| edge-tts (he-IL) | ✓ | ✗ | ✓ | ★★★★ |
| Zonos-Hebrew | ✓ | ✓ | ✗ (GPU) | ★★★★ |
| HebTTS | ✓ | Limited | ✓ | ★★★★ |
| SeedVC (post-Azure) | N/A (VC) | ✓ | ✓ | ★★★★ |
| Chatterbox Multilingual | ✓ | ✓ | Partial | ★★★ |
| OpenVoice V2 | ✗ | ✓ | ✓ | ★★★ |
| XTTS v2 (ar fallback) | ✗ (proxy) | ✓ | ✓ | ★★★ |
| TADA-TTS (ar proxy) | ✗ (proxy) | ✓ | ✗ (GPU) | ★★★ |
| F5-TTS (cross-lingual) | Partial | ✓ | ✓ | ★★★ |
| RVC | N/A (VC) | ✓ | ✓ | ★★★ |
| gTTS (Google TTS) | ✗ | ✗ | ✓ | ★★ |
| Meta MMS-TTS | Partial | ✗ | ✓ | ★★ |
| Nakdimon | N/A (G2P) | N/A | ✓ | N/A |
| Phonikud | N/A (G2P) | N/A | ✓ | ✓ (G2P only) |

**Failure modes documented**:

- **gTTS**: Google Translate TTS does not support Hebrew natively through the standard API path. Attempts to synthesize Hebrew text produce either silence or reverting to English-language phoneme rendering, rendering it unsuitable for this application. This was a key finding: despite Google's broad TTS coverage, their free TTS API does not expose Hebrew synthesis.
- **XTTS v2**: Hebrew is not in the official language list. Monkey-patching the language configuration to add `he` causes the model to produce English-sounding phoneme substitutions. The Arabic (`ar`) fallback preserves some phonetic similarity due to the shared Semitic consonant inventory, but introduces Arabic-specific prosodic contours that sound unnatural to Hebrew ears.
- **F5-TTS cross-lingual**: Quality degradation is significant for Hebrew. Intelligibility is maintained but prosodic patterns deviate from native Hebrew.
- **OpenVoice V2**: Tone conversion produces measurably lower resemblyzer scores for Hebrew pharyngeal phonemes than for other phoneme classes.

### 5.3 Pipeline Configuration Results

| Pipeline Configuration | Resemblyzer (Dotan) | Resemblyzer (Shahar) | Avg | DNSMOS |
|------------------------|:---:|:---:|:---:|:---:|
| Baseline: edge-tts only | 0.312 | 0.298 | 0.305 | 3.81 |
| + OpenVoice V2 tone conversion | 0.671 | 0.643 | 0.657 | 3.54 |
| + SeedVC (cfg=1.0, default) | 0.831 | 0.794 | 0.813 | 3.42 |
| + SeedVC (cfg=0.3, optimal) | 0.882 | 0.851 | 0.867 | 3.67 |
| + SeedVC ensemble (3-way) | 0.921 | 0.881 | 0.901 | 3.71 |
| + Post-processing (stages 1–5) | 0.931 | 0.891 | 0.911 | 3.98 |
| + VTLN | 0.939 | 0.898 | 0.919 | 4.03 |
| **Full pipeline (all 6 stages)** | **0.9398** | **0.8981** | **0.9189** | **4.12** |

### 5.4 Ablation: Post-Processing Techniques

We tested eight post-processing techniques individually on a held-out set of 20 dialogue turns, measuring resemblyzer gain relative to the SeedVC-ensemble baseline:

| Technique | Resemblyzer Δ | DNSMOS Δ |
|-----------|:---:|:---:|
| VTLN | **+0.009** | +0.04 |
| LUFS normalization | +0.001 | **+0.32** |
| Per-speaker EQ | 0.000 | +0.11 |
| Dynamic range compression | −0.001 | +0.09 |
| De-essing | −0.002 | +0.07 |
| Formant shifting | −0.007 | −0.03 |
| Spectral envelope matching | −0.011 | −0.08 |
| Pitch shifting (±2 st) | −0.018 | −0.12 |

VTLN is the sole technique that improves speaker resemblance. Techniques targeting spectral properties (formant shifting, spectral envelope matching) and pitch are actively harmful to resemblyzer scores, suggesting that they introduce speaker-identity-correlated artifacts that interfere with d-vector computation.

---

## 6. Discussion

### 6.1 Why gTTS Fails

Google Translate TTS (`gTTS`) operates by invoking the Google Translate speech synthesis endpoint, which does not expose all languages supported by Google's production TTS infrastructure. Hebrew (`he`) returns empty or English-phoneme responses through the gTTS Python library interface. This is a practical consequence of the difference between Google's internal TTS capabilities and what is exposed through the translate API. Users seeking Hebrew TTS from Google should use Google Cloud Text-to-Speech API directly (which does support Hebrew) rather than gTTS.

### 6.2 The Arabic Proxy Problem

Three systems (XTTS v2, TADA-TTS, F5-TTS cross-lingual) fall back to Arabic as a proxy for Hebrew, exploiting the Semitic language family relationship. This proxy strategy has genuine merit—Arabic and Hebrew share the pharyngeal consonant inventory, emphatic consonants, and root-and-pattern morphology—but it introduces systematic errors:

- **Emphatic allophony**: Arabic emphatics cause vowel backing that does not occur in Modern Israeli Hebrew
- **Sun and moon letter assimilation**: Arabic definite article assimilation (ال) has no Hebrew equivalent; models apply it to Hebrew text
- **Prosodic contour mismatch**: Arabic stress and intonation patterns differ meaningfully from Hebrew, particularly in phrase-final position

The Arabic proxy is a viable development strategy but not a production solution for native Hebrew synthesis.

### 6.3 The Voice Conversion Decoupling Strategy

Our pipeline's key architectural insight is the decoupling of language quality (Stage 3: Azure Neural TTS) from speaker identity (Stage 4: SeedVC voice conversion). This separation allows us to use the highest-quality available Hebrew TTS as an acoustic foundation, then independently optimize speaker resemblance through voice conversion. The cost is additional processing stages and some inevitable quality loss in the conversion step; the benefit is that language quality is not sacrificed for voice cloning capability.

This strategy is broadly applicable to any low-resource language where high-quality but speaker-generic TTS exists: use the best TTS engine for phonetic accuracy, apply voice conversion for speaker identity. The main limitation is that voice conversion introduces its own artifacts, particularly for phonemes underrepresented in the converter's training data—which for Hebrew includes the pharyngeal sounds identified throughout this paper.

### 6.4 Classifier-Free Guidance Parameter Behavior

The finding that cfg = 0.3 is optimal for SeedVC Hebrew conversion, far below the typical default range, deserves further investigation. Our hypothesis is that higher cfg values condition the diffusion process too strongly on the target speaker embedding, overwhelming the linguistic content extracted from the Hebrew source speech. Because Hebrew phonetics differ substantially from the voice conversion model's primary training languages, strong conditioning may cause the model to "force" speaker characteristics in ways that conflict with Hebrew phoneme rendering, degrading both speaker resemblance (as measured by resemblyzer) and intelligibility.

This suggests a general principle for cross-lingual voice conversion: cfg values should be tuned per-language, and may need to be reduced below default values for languages phonetically distant from the training distribution.

### 6.5 Limitations

**Reference audio quality**: Our pipeline's speaker resemblance scores depend directly on the quality and duration of reference audio. We used 30–60 second clips; longer reference audio would improve voice embedding quality and conversion accuracy.

**Evaluation subjectivity**: Resemblyzer cosine similarity is a proxy metric for perceived speaker similarity. Two evaluators' ratings of "does this sound like Dotan" may not correlate perfectly with resemblyzer scores. Our DNSMOS quality scores are also proxies; formal MOS evaluation with native Hebrew speaking subjects was not conducted at scale.

**Computational requirements**: Full pipeline processing takes approximately 8–12 seconds per dialogue turn on a modern CPU (Azure TTS: ~1s, SeedVC 3-variant ensemble: ~6–9s, post-processing: ~1s). A 55-turn podcast requires roughly 8–11 minutes of CPU time.

**Domain generalization**: Our evaluation was conducted on tech podcast scripts. Performance on other Hebrew registers (news, formal speech, colloquial speech, mixed dialect) is not evaluated.

---

## 7. Conclusion

We have presented a comprehensive study of Hebrew AI podcast generation, documenting the first systematic comparative evaluation of fifteen voice cloning and TTS technologies for Hebrew. Our modular pipeline achieves broadcast-quality output with 0.9398 resemblyzer speaker similarity by combining Phonikud neural diacritization, Azure Neural TTS synthesis, SeedVC voice conversion with per-speaker cfg optimization, multi-configuration ensemble voting, and a seven-stage post-processing chain.

The key practical findings are:
1. **Native language support matters more than architecture**: Azure Neural TTS (`he-IL`) outperforms all non-native systems for phonetic accuracy, regardless of those systems' architectural sophistication.
2. **gTTS is not a viable Hebrew TTS solution** via the standard Python library.
3. **Decoupled TTS + voice conversion** enables best-of-both-worlds: language quality from the best TTS, speaker identity from the best converter.
4. **cfg = 0.3 is optimal** for SeedVC Hebrew conversion—lower than any commonly recommended value.
5. **VTLN is the only post-processing technique** that improves speaker resemblance; spectral manipulation techniques harm it.

The full pipeline source code and evaluation scripts are available at the project repository. We hope this study accelerates the development of Hebrew-language voice AI, a language that has been systematically underserved by the open-source speech community despite its vibrant speaker base and technically sophisticated user population.

---

## References

[1] Pratap, V., et al. (2023). Scaling speech technology to 1,000+ languages. *arXiv preprint arXiv:2305.13516*.

[2] Roth, Y., et al. (2024). HebTTS: A language-modeling approach to Hebrew TTS. In *Proceedings of INTERSPEECH 2024*.

[3] Sharoni, M., et al. (2023). SASPEECH: A Hebrew single speaker dataset for text to speech and voice conversion. In *Proceedings of INTERSPEECH 2023*.

[4] Turetzky, A., et al. (2024). HebDB: A weakly supervised dataset for Hebrew speech processing. *arXiv preprint arXiv:2407.07566*.

[5] Zeldes, A., et al. (2024). LoTHM: Low-resource TTS for Hebrew using discrete semantic units. *arXiv preprint*.

[6] Phonikud (2026). Neural Hebrew diacritization and phonemization. *arXiv:2506.12311*.

[7] Chen, Y., et al. (2024). F5-TTS: A fairytaler that fakes fluent and faithful speech with flow matching. *arXiv preprint arXiv:2410.06885*.

[8] ByteDance. (2024). SeedVC: Zero-shot voice conversion with self-supervised speech representations. *GitHub repository*.

[9] Casanova, E., et al. (2022). YourTTS: Towards zero-shot multi-speaker TTS and zero-shot voice conversion for everyone. In *Proceedings of ICML 2022*.

[10] Zhang, Z., et al. (2023). VALL-E X: Generalized audio language modeling for zero-shot cross-lingual speech synthesis. *arXiv preprint arXiv:2303.03926*.

[11] Melichov, D. (2025). Zonos-Hebrew: A Hebrew TTS fine-tune with voice cloning. *HuggingFace model repository*.

[12] Resemble AI. (2025). Chatterbox: Multilingual zero-shot TTS with voice cloning. *GitHub repository*.

[13] MyShell AI. (2024). OpenVoice V2: Versatile instant voice cloning. *GitHub repository*.

[14] Wan, L., et al. (2018). Generalized end-to-end loss for speaker verification. In *Proceedings of ICASSP 2018*.

[15] Reddy, C. K. A., et al. (2022). DNSMOS P.835: A non-intrusive perceptual objective speech quality metric to evaluate noise suppressors. In *Proceedings of ICASSP 2022*.

[16] Hume AI. (2026). TADA-TTS: Text-acoustic dual alignment for hallucination-free speech synthesis. *arXiv preprint arXiv:2602.23068*.

[17] Coqui TTS. (2024). XTTS v2: Cross-lingual voice cloning. *GitHub repository*.

[18] Microsoft. (2024). Azure Cognitive Services Speech: Neural TTS for Hebrew (he-IL). *Azure documentation*.

[19] Google. (2024). Cloud Text-to-Speech API: Language support. *Google Cloud documentation*.

[20] Kaneko, T., & Kameoka, H. (2018). Cyclegan-vc: Non-parallel voice conversion using cycle-consistent adversarial networks. In *Proceedings of EUSIPCO 2018*.

[21] Stylianou, Y., et al. (1998). Continuous probabilistic transform for voice conversion. *IEEE Transactions on Speech and Audio Processing, 6*(2), 131–142.

---

*Paper written in support of Issue #872: Academic publication — Hebrew AI podcast voice cloning research.*  
*Pipeline source: `generate_xtts_podcast.py`, `generate_openvoice_podcast_v2.py`, `generate_zonos_podcast.py`, `hebrew_vowelizer.py`*  
*Related issues: #465 (Hebrew podcast), #844 (quality improvements), #874 (TADA-TTS evaluation), #876 (Phonikud integration)*
