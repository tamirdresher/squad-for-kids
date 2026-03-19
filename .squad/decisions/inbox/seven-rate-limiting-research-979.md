# Decision Candidate: Rate Limiting Strategy for Squad

**From:** Seven (Research & Docs)  
**Date:** March 2026  
**Issue:** #979  
**Relates to:** All agents making API calls to Claude/GitHub/Azure

## Summary

Research complete on adaptive rate limiting for multi-agent AI systems. The following strategy is recommended for Squad adoption:

## Recommended Approach

1. **Shared pool + per-agent priority caps** (not per-agent isolated limits)
2. **Centralized Rate Governor** routing all agent API calls through a single throttle layer
3. **Three-tier priority queue:** P0 (Picard/Worf), P1 (Data/Seven/Belanna/Troi/Neelix), P2 (Ralph/Scribe)
4. **Full-jitter exponential backoff** on all 429 responses; always honor `Retry-After`
5. **Proactive slow mode** when rate limit remaining < 20%
6. **Anthropic prompt caching** enabled for all agents (system prompts are stable)
7. **Batch API** for Ralph and Scribe (background, non-interactive)
8. **Ralph webhook-first** instead of polling GitHub

## Full Report

`research/rate-limiting-multi-agent-2026-03.md`

## Needs Team Decision

Should the Rate Governor be:
- (A) An in-process shared module used by all agents
- (B) A standalone microservice with Redis backing for distributed/multi-machine squads
- (C) Start with (A), migrate to (B) when multi-machine becomes the norm

Recommendation: Option (A) now, with (B) as a clear upgrade path.
