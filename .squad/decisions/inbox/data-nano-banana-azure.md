# Decision: nano-banana-mcp — Use Gemini Free Tier, Defer Azure Fallback

**Date:** 2026-03-14
**Author:** Data (Code Expert)
**Issue:** #375
**Status:** Decided

## Context

Tamir asked whether nano-banana-mcp (AI image generation MCP server) can be used without billing or costs, and to set up Azure OpenAI as a fallback.

## Decision

**Use Gemini free tier directly.** Azure fallback is deferred — not needed.

## Rationale

1. **Gemini free tier has no cost** — API key created at aistudio.google.com, no billing info required
2. **Free tier limits are sufficient** — 15 RPM, 1500 RPD, 1M TPM — more than enough for dev/demo
3. **nano-banana-mcp is Gemini-only** — No provider abstraction; adding Azure would require forking (~50 LOC)
4. **Azure DALL-E 3 has costs** — Azure OpenAI image generation is not free; defeats the purpose
5. **MCP config updated** — nano-banana server added to `~/.copilot/mcp-config.json`, ready to use

## Trade-offs

- If Gemini free tier limits are hit, would need to either add billing or implement Azure fallback
- No redundancy — single provider dependency on Google
- If Google changes free tier terms, need a plan B

## Action Items

- [x] Retrieve Gemini API key (free tier, no billing)
- [x] Configure nano-banana-mcp in Copilot CLI MCP config
- [x] Post findings on issue #375
- [ ] If needed later: fork nano-banana-mcp to add Azure DALL-E 3 backend
