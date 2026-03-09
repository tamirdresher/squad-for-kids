# Podcaster Agent TTS Research — Issue #214

**Date:** 2026-03-25  
**Researcher:** Seven (Research & Docs)  
**Scope:** Text-to-Speech (TTS) viability for audio podcast generation from Squad outputs  
**Issue:** [#214 — Add Podcaster/Broadcaster Agent to Squad](https://github.com/tamirdresher/tamresearch1/issues/214)

---

## Executive Summary

Squad produces substantial text output—research reports, blog drafts, briefings, patent analysis—that takes significant time to read. A Podcaster agent would convert these into short audio briefings, similar to Google NotebookLM's podcast feature but constrained to Microsoft and GitHub tools only.

**Recommendation: Azure AI Speech Service** is the only production-viable path that meets all constraints. GitHub Copilot audio lacks a public TTS API, edge-tts has legal/reliability issues, and PowerShell TTS delivers poor voice quality unsuitable for professional podcasts.

**Viable Implementation:** Use **Azure AI Speech Service (Standard Neural Voices)** with **on-demand architecture**, triggered when new Squad outputs arrive. Estimated cost: **$0.02–$0.15 per 500-word article**.

---

## 5 TTS Options Evaluated

### 1. **Azure AI Speech Service (Cognitive Services)**

**Status:** ✅ **RECOMMENDED**

#### Availability
- **Global:** 100+ supported languages, 500+ neural voices
- **Access:** REST API, SDKs (Node.js, Python, C#, Java, Go), Azure Portal, Speech Studio
- **Deployment:** Cloud, Edge containers, embedded devices
- **Setup Complexity:** Medium—requires Azure subscription + resource creation + API key management

#### Pricing
| Tier | Rate | Notes |
|------|------|-------|
| **Free Tier** | 0.5M characters/month | Generous for testing/MVP |
| **Standard Neural** | $15 per 1M characters | ~$0.015 per 500-word article |
| **Custom Neural** | $24 per 1M characters + training | Not needed for MVP |
| **HD/Advanced** | ~$30 per 1M characters | Premium voices, higher quality |
| **Batch Processing** | Same rates | For large bulk jobs |

**Enterprise Discounts:** Commitment-based pricing available; large volumes can drop to ~$9.75/1M characters.

#### Voice Quality
- Neural voices are natural-sounding, human-like prosody
- SSML support for fine-grained control (pitch, rate, emotion, pronunciation)
- Context-aware intonation and realistic pauses

#### Constraints & Compliance
- ✅ Fully owned by Microsoft (satisfies "Microsoft tools only" constraint)
- ✅ Enterprise compliance: GDPR, HIPAA, SOC 2, audit trails, SLAs
- ✅ Integrates with Azure Cognitive Services ecosystem
- ⚠️ Cloud dependency (latency ~1–3 seconds per request)
- ⚠️ Cost accumulates with heavy usage

#### Implementation Complexity
**Low-to-Medium**
- REST API is straightforward; SDKs simplify integration
- Can integrate as post-processing step in Squad pipeline
- Error handling and retry logic standard

---

### 2. **edge-tts (npm package)**

**Status:** ⚠️ **NOT RECOMMENDED FOR PRODUCTION**

#### Availability
- **Source:** npm package (`@andresaya/edge-tts`, others)
- **Access:** Uses Microsoft Edge's internal Read Aloud TTS API (unofficial)
- **Languages:** 40+ languages, multiple regional accents
- **Setup Complexity:** Very easy—one npm install, minimal configuration

#### Pricing
- **Cost:** Free (no official billing)
- **Quota:** Unofficial; Microsoft doesn't publish rate limits
- **Risk:** Subject to throttling, IP blocking, or shutdown without notice

#### Voice Quality
- Good—same underlying neural models as Azure, but subset of voices available
- Audio formats: MP3, OGG, WAV, FLAC

#### Constraints & Compliance
- ❌ **Legal/Licensing Risk:** Not officially supported; commercial use may violate Microsoft terms
- ❌ **No SLA:** Service interruptions possible; no guaranteed uptime
- ❌ **Unofficial API:** Protocol changes or deprecation possible at any time
- ❌ **Rate Limiting:** No published quotas; risk of service blockage for high volume
- ✅ Lower latency (local-like performance)
- ⚠️ Browser user-agent spoofing required; Microsoft may block detection

#### Implementation Complexity
**Very Low** (but risk is high)
- Simple Node.js library
- Quick prototyping tool

#### Verdict
Perfect for **internal research/prototyping only**. Not suitable for production Podcaster agent—Microsoft could shut down access tomorrow, leaving Squad without TTS capability.

---

### 3. **Azure OpenAI TTS (via Azure OpenAI Service)**

**Status:** ⚠️ **VIABLE BUT EXPENSIVE**

#### Availability
- **Access:** Azure OpenAI Service (requires separate resource from standard Azure)
- **Models:** TTS-1, TTS-1 HD, gpt-4o-mini-tts
- **Setup Complexity:** Medium—requires Azure OpenAI resource provisioning

#### Pricing
| Model | Rate | Notes |
|-------|------|-------|
| **TTS-1 (Standard)** | $15 per 1M characters | Similar to Azure Speech Service |
| **TTS-1 HD** | $30 per 1M characters | Higher fidelity |
| **GPT-4o Mini TTS** | $0.60 in + $12 out per 1M tokens | Token-based; not character-efficient for simple TTS |

#### Voice Quality
- Good (same as OpenAI's public API, but via Azure)
- Fewer voices than Azure Speech Service (limited to OpenAI's voice set)

#### Constraints & Compliance
- ✅ Microsoft-hosted (Azure), satisfies constraint
- ✅ Official support, enterprise compliance
- ✅ Integrates with Azure ecosystem
- ⚠️ **Cost parity:** No price advantage over Azure Speech Service; often more expensive per character
- ⚠️ Limited voice selection vs. Azure Speech Service (only ~6 voices)
- ⚠️ Overkill for simple TTS (GPT-4o TTS targets multimodal interactions)

#### Implementation Complexity
**Medium**
- Similar to Azure Speech Service setup
- Uses standard Azure OpenAI SDK

#### Verdict
**Not recommended for Podcaster MVP.** Azure Speech Service is cheaper and offers more voice variety. Azure OpenAI TTS is better suited for conversational agents or multimodal workflows, not simple podcast generation.

---

### 4. **GitHub Copilot Audio Capabilities**

**Status:** ❌ **NOT VIABLE**

#### Availability
- **Platforms:** Visual Studio Code (via Speech extension + Copilot Chat)
- **Features:** Voice-to-text, text-to-speech (for reading Copilot responses back)
- **Languages:** 26+ languages
- **Setup:** Requires VS Code + Copilot Chat + Speech extension

#### Voice Quality
- Good—uses Windows Narrator or system TTS (quality varies)

#### Constraints & Compliance
- ✅ Microsoft-owned (GitHub subsidiary)
- ❌ **No Public API:** TTS capability is UI-only, embedded in VS Code
- ❌ **Not Automatable:** No programmatic way to invoke TTS from Squad agents
- ❌ **Not Designed for Batch:** Built for interactive coding, not document processing
- ❌ **UI-Only:** Cannot generate audio files programmatically

#### Implementation Complexity
**Impossible**
- No API exposed; only available as VS Code UI feature
- Would require UI automation (fragile, unsupported)

#### Verdict
**Not an option for Podcaster agent.** GitHub Copilot's audio is for developer productivity (dictation, response reading) in the IDE, not for batch audio generation. No public API exists.

---

### 5. **PowerShell System.Speech (Windows Native TTS)**

**Status:** ⚠️ **VIABLE FOR MVP/PROTOTYPE ONLY**

#### Availability
- **Platform:** Windows only (via System.Speech.Synthesis)
- **Voices:** Limited to SAPI voices installed on system (typically "David Desktop," "Zira Desktop")
- **Languages:** Dependent on installed voices (usually just US/UK English by default)
- **Setup Complexity:** Trivial—built into Windows

#### Pricing
- **Cost:** Free (local only, no cloud)
- **Quota:** Unlimited (system resource-bound)

#### Voice Quality
- **Poor:** SAPI desktop voices sound robotic, synthetic, dated
- Not suitable for professional podcasts or public consumption
- Acceptable for internal alerts or testing

#### Constraints & Compliance
- ✅ No Microsoft API dependency (fully local)
- ✅ No cost
- ✅ Works offline
- ✅ Windows-native, familiar to PowerShell users
- ❌ Voice quality unacceptable for professional podcasts
- ❌ Windows-only (not portable)
- ❌ No neural/modern voices accessible (OneCore voices not available to SAPI)
- ❌ Limited language support
- ❌ Minimal SSML/customization

#### Implementation Complexity
**Very Low**
- 3 lines of PowerShell code to generate audio
- Perfect for quick MVP/demo

#### Verdict
**Acceptable for internal MVP or demo only.** Voice quality is too poor for production. Users would immediately notice synthetic, robotic voices vs. Azure's neural voices. Good as fallback prototype while Azure setup is underway.

---

## NotebookLM Reference (Why We Can't Use It)

Google's NotebookLM generates conversational dual-host podcasts from documents—exactly the experience we want for Podcaster. However:
- ❌ Google service (violates "Microsoft/GitHub tools only" constraint)
- ❌ Requires API key + commercial licensing
- ❌ Not owned/controlled by Microsoft ecosystem

NotebookLM is the **inspiration** for architecture, but implementation must use Microsoft services.

---

## Architecture Options Comparison

### Option A: Post-Processing Pipeline
**Flow:** Squad output → Scribe logs → Podcaster daemon watches logs → triggers TTS → stores audio

**Pros:**
- Decoupled from agent execution
- Can batch multiple outputs
- Persistent history

**Cons:**
- Additional infrastructure (daemon/watcher)
- Latency (audio not ready immediately)

### Option B: On-Demand ("Podcast the Latest")
**Flow:** User requests "podcast research report #42" → Agent fetches document → TTS generates audio → returns link

**Pros:**
- Simple, synchronous
- No background infrastructure
- On-user-demand timing

**Cons:**
- User must explicitly request
- Real-time latency (~3–5 seconds per podcast)

### Option C: Automated Daily Podcast
**Flow:** Daily trigger (8:55 AM) → summarize yesterday's outputs → generate audio → send Teams notification with audio link

**Pros:**
- Proactive; Tamir gets morning briefing
- Predictable, scheduled
- Minimal user interaction

**Cons:**
- Requires scheduled task infrastructure
- Audio only generated once per day
- May miss important mid-day outputs

---

## Recommendation

### **Primary: Azure AI Speech Service**

**Implementation Path:**
1. **Service:** Azure AI Speech Service (Standard Neural Voices)
2. **Triggers:** On-demand (Option B) + optional daily batch (Option C)
3. **Cost:** ~$15 per 1M characters = **$0.02–$0.15 per 500-word document**
4. **Voice:** Multiple neural voices available; choose one for consistency
5. **Audio Format:** MP3 (browser-friendly, small file size)

**Setup Steps:**
1. Create Azure Cognitive Services resource (Speech API)
2. Add API key + region to Squad config
3. Create `Podcaster` agent Node.js module wrapping REST API
4. Add TTS endpoint to Squad API
5. Wire to output events (documents generated)
6. Store audio in `.squad/podcasts/` with metadata

**Fallback:** PowerShell System.Speech for MVP/demo (no cost, acceptable for internal testing)

### **Why Not the Others?**

| Option | Reason |
|--------|--------|
| edge-tts | Legal risk, no SLA, unofficial API—not suitable for production |
| Azure OpenAI TTS | More expensive, fewer voices, overkill for simple TTS |
| GitHub Copilot | No public API, UI-only feature |
| PowerShell | Poor voice quality, Windows-only, not professional-grade |

---

## Cost Analysis (Annual)

**Scenario:** 250 documents/month (~8,000 words avg) = 2M characters/month

| Service | Monthly Cost | Annual Cost |
|---------|--------------|-------------|
| **Azure Speech** | $30 (2M chars @ $15/1M) | $360 |
| **PowerShell** | $0 | $0 |
| **edge-tts** | $0 (but risky) | $0 (but risky) |

**Budget Impact:** Minimal. $360/year is negligible for production-grade TTS.

---

## Implementation Checklist (For Picard/Implementation Phase)

- [ ] Provision Azure Cognitive Services resource (Speech API)
- [ ] Retrieve API key and region
- [ ] Add to `.squad/config.ts` under `services.tts`
- [ ] Create `Podcaster` agent (Node.js module)
- [ ] Implement REST client wrapping Azure Speech API
- [ ] Add TTS endpoint to Squad API
- [ ] Wire to output events (when documents generated)
- [ ] Create `.squad/podcasts/` directory for audio files
- [ ] Store metadata (document name, duration, timestamp)
- [ ] Generate download links for audio files
- [ ] Test with sample research report
- [ ] Document usage in `.squad/agents/podcaster/README.md`
- [ ] Add Teams integration for audio notifications (optional)

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Azure service downtime | Medium | Implement retry logic; fallback to PowerShell for demo |
| API rate limiting | Low | Keep under free tier quota; monitor usage |
| Cost overruns | Low | Set budget alerts in Azure Portal |
| Voice selection | Low | Test multiple voices; select one for consistency |
| Audio quality issues | Low | Validate prosody with sample outputs; adjust SSML if needed |

---

## Conclusion

**Azure AI Speech Service** is the clear winner for Squad's Podcaster agent. It delivers production-grade quality, enterprise compliance, reasonable cost, and seamless integration with Microsoft's ecosystem. The "Microsoft/GitHub tools only" constraint eliminates Google and third-party services, leaving Azure as the only viable production option.

**Next Steps:** Coordinate with Picard for implementation prioritization and Azure resource provisioning.

---

## References & Links

- [Azure AI Speech Service Pricing](https://azure.microsoft.com/en-us/pricing/details/speech/)
- [Azure Speech Text-to-Speech Overview](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/text-to-speech)
- [Azure OpenAI Pricing](https://azure.microsoft.com/en-us/pricing/details/azure-openai/)
- [edge-tts npm Package](https://www.npmjs.com/package/@andresaya/edge-tts)
- [GitHub Copilot VS Code Speech Extension](https://github.com/microsoft/vscode/wiki/VS-Code-Speech)
- [PowerShell System.Speech Documentation](https://learn.microsoft.com/en-us/dotnet/api/system.speech.synthesis.speechsynthesizer)
- [NotebookLM Audio Overview (Reference Only)](https://blog.google/innovation-and-ai/products/notebooklm-audio-overviews/)
