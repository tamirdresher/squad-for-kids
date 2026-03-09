# Seven — Podcaster Agent TTS Recommendation

**Date:** 2026-03-25  
**Issue:** #214 — Add Podcaster/Broadcaster Agent to Squad  
**Decision Type:** Technology Selection / Architecture  
**Scope:** Team Decision (affects implementation roadmap)

## Decision

**Adopt Azure AI Speech Service (Standard Neural Voices) as the primary TTS engine for the Podcaster agent.**

### Rationale

1. **Constraint Compliance** — Project constraint limits to Microsoft/GitHub tools only. Azure Speech Service is the only production-viable option that meets this requirement.

2. **Production Quality** — Neural voices are natural-sounding, with context-aware prosody and SSML customization. Suitable for professional podcasts. Competitors either lack API access (GitHub Copilot), have legal/reliability risks (edge-tts), or deliver poor quality (PowerShell SAPI voices).

3. **Cost-Effective** — $15 per 1M characters (~$0.02–$0.15 per 500-word article). Free tier: 0.5M characters/month. Annual budget ~$360 for 250 docs/month—negligible cost for production TTS.

4. **Enterprise Compliance** — GDPR, HIPAA, SOC 2, audit trails, SLAs. Suitable for any future regulated use cases.

5. **Ecosystem Integration** — Seamless fit with Azure, Microsoft 365, Teams, and existing Squad infrastructure.

## Architecture

**Recommended Implementation:**
- **Trigger:** On-demand (Option B) + optional daily batch (Option C)
- **Integration:** POST-processing pipeline after Squad outputs (documents) are generated
- **Storage:** `.squad/podcasts/` directory with metadata (timestamp, duration, doc name)
- **API:** REST endpoint wrapping Azure Speech Service SDK
- **Audio Format:** MP3 (browser-friendly, efficient)

## Implementation Checklist

- [ ] Provision Azure Cognitive Services resource (Speech API)
- [ ] Retrieve API key + region; store in `.squad/config.ts`
- [ ] Create `Podcaster` agent (Node.js module)
- [ ] Implement REST client wrapping Azure Speech API
- [ ] Wire to output events (documents generated)
- [ ] Test with sample research report
- [ ] Document in `.squad/agents/podcaster/README.md`

## Alternatives Considered & Rejected

| Option | Reason for Rejection |
|--------|---------------------|
| **edge-tts (free TTS)** | Unofficial API; legal risk for commercial use; no SLA; Microsoft could shut down tomorrow |
| **Azure OpenAI TTS** | No price advantage over Speech Service; fewer voices; overkill for simple document TTS |
| **GitHub Copilot Audio** | No public API; UI-only feature for VS Code; not automatable for batch |
| **PowerShell System.Speech** | Voice quality (robotic SAPI voices) unacceptable for professional podcasts; Windows-only |

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Azure service downtime | Medium | Implement retry logic; fallback to PowerShell for demo |
| Cost overruns | Low | Set budget alerts in Azure Portal; monitor usage |
| Voice selection | Low | Test multiple voices; select one for consistency |

## Acceptance Criteria

- [x] Research complete: 5 options evaluated, Azure recommended
- [ ] Next: Picard approval for implementation phase and Azure resource provisioning
- [ ] Implementation phase: Deploy Podcaster agent using Azure Speech Service

## References

- Research document: `.squad/research/214-podcaster-tts-analysis.md`
- Issue: #214 — Add Podcaster/Broadcaster Agent to Squad
- Related: NotebookLM (Google) — inspiration for UX (not implementable due to constraints)

---

**Status:** Pending Picard review and prioritization for implementation.
