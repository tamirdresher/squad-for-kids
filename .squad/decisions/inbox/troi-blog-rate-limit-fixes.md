# Decision: Rate Limiting Blog Post Corrections

**Date:** 2026-03-20  
**Agent:** Troi (Blogger & Voice Writer)  
**Issue:** #1281  
**Branch:** squad/blog-rate-limiting  
**Commit:** b4f7c53

## Context

The rate limiting blog post at `_posts/2026-03-20-rate-limiting-multi-agent.md` needed several fixes:
1. Missing section on multi-machine/multi-node rate limiting
2. Voice issues ("we/us" instead of "I/me")
3. Anthropic references (should be GitHub Copilot only)
4. Generic cloud references (should be Azure/AKS specifically)
5. Missing Reddit thread context
6. Overstated x-ratelimit-remaining availability

## Changes Made

### 1. Added Pattern 7: Multi-Node Rate Limiting

Added comprehensive section explaining:
- **Why file-based approach doesn't work multi-node:** POSIX locks don't propagate, heartbeats are local, no fencing tokens, eventual consistency on networked FS
- **Three practical alternatives:**
  - Redis/Valkey (atomic ops, TTL, pub/sub) — recommended choice
  - etcd (already in AKS, strong consistency)
  - Sidecar/DaemonSet pattern (local governor per node)
- **Honest about current state:** Squad runs single-node, file-based works fine, will migrate when needed
- **Philosophy:** "Start simple. Ship the file-based version. When you outgrow one machine, migrate to distributed state."

### 2. Fixed Voice: we/us → I/me

Replaced all instances of "we", "us", "our" with first-person singular throughout the post. Tamir's blog is personal, not corporate.

### 3. Removed Anthropic References

- Changed "Anthropic Claude API" to "GitHub REST/GraphQL" in mermaid diagram
- Changed "GitHub Copilot quota (80 completions/hour)" references to just "API quotas"
- Updated rate-pool.json examples to use "github" key instead of "copilot" or "anthropic"
- Generalized "Every response from Anthropic, OpenAI, and GitHub" to "GitHub REST API and Azure OpenAI"

### 4. Scoped to Azure/AKS

- Changed "Kubernetes, cloud VMs, or similar" to "AKS, Azure VMs, or similar"
- Changed "AWS API Gateway, Azure API Management" to just "Azure API Management"
- All cloud/K8s references now mention Azure specifically

### 5. Added Reddit Thread Context

Added reference to Reddit thread (https://www.reddit.com/r/GithubCopilot/s/N5DH2B8YA0) in the "Story" section: "I posted about this on r/GithubCopilot and realized other people are hitting the same wall."

### 6. Clarified x-ratelimit-remaining Applicability

Added clarification in Pattern 1 that x-ratelimit-remaining headers are available when making direct API calls (gh api, REST clients), not when using Copilot CLI with `-p` flag.

## Voice Patterns Applied

- First-person throughout ("I", "me", "my")
- Honest about limitations (single-node vs multi-node)
- Conversational tone ("Here's where I need to be honest")
- Technical depth with accessibility (Redis atomic ops explained with code sketches)
- "Start simple, migrate when needed" philosophy (pragmatic, not premature optimization)

## Outcome

Blog post now:
- Accurately represents single-node design
- Provides clear multi-node migration path
- Matches Tamir's authentic voice
- Uses correct provider names (GitHub Copilot, Azure)
- Includes community context (Reddit thread)
- Sets realistic expectations about header availability

Committed and pushed to `squad/blog-rate-limiting` branch: b4f7c53
