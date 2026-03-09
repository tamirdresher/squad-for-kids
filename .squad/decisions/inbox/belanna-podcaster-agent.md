# Decision: Podcaster Agent Integration

**Date:** 2026-03-09  
**Decider:** B'Elanna (Infrastructure Expert)  
**Context:** Issue #214 — Add Podcaster agent for audio summaries

## Decision

Integrated Podcaster agent into squad after successful prototype validation.

## Rationale

1. **Prototype Validation:**
   - Test document: Successfully generated 160.88 KB MP3 from 365B markdown in 2.25s
   - Real document: Successfully generated 3.91 MB MP3 from 14.52 KB markdown in 20.77s
   - Audio quality: Neural voice (en-US-JennyNeural) provides professional, production-grade output
   - No errors or issues during conversion

2. **Technical Readiness:**
   - edge-tts 7.2.7 already installed and working
   - Script handles markdown stripping correctly (removes formatting, preserves content)
   - Conversion time scales linearly (~1.4s per KB markdown)
   - MP3 output size is reasonable for audio content

3. **Squad Integration:**
   - Created comprehensive charter defining Podcaster role and boundaries
   - Seeded history with project context and validation results
   - Updated team roster and routing rules
   - Follows existing squad agent patterns

## Implementation

- **Branch:** squad/214-podcaster-agent
- **PR:** #227 (draft)
- **Files Added:**
  - `.squad/agents/podcaster/charter.md`
  - `.squad/agents/podcaster/history.md`
- **Files Updated:**
  - `.squad/team.md`
  - `.squad/routing.md`

## Consequences

**Positive:**
- Squad can now generate audio versions of research reports, briefings, and documentation
- Enables audio consumption for busy stakeholders
- Neural voice quality is professional enough for external delivery
- Zero setup overhead (edge-tts just works)

**Risks/Trade-offs:**
- Network dependency (requires internet for TTS service)
- Free tier rate limits (unspecified, but not hit during testing)
- Hardcoded voice selection (can be made configurable later)
- Single-file processing (batch processing not yet implemented)

## Next Steps

1. Wait for stakeholder review of audio quality
2. If approved, merge PR #227 to main
3. Plan integration with Scribe handoff workflow
4. Consider batch processing for multiple documents
5. Evaluate Azure AI Speech Service for production scale (if needed)

## Tags

`infrastructure` `audio` `tts` `squad-agent` `issue-214`
