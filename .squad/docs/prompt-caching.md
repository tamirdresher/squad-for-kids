# Anthropic Prompt Caching for Squad Agents

## What It Is

Anthropic's prompt caching lets you mark stable portions of a Claude API request
(system prompt, tool definitions, reference documents) with a `cache_control:
ephemeral` breakpoint. On subsequent requests that share the same prefix up to
that breakpoint, Anthropic serves the cached KV-state rather than re-processing
the tokens.

**Why it matters for Squad:**

| Metric | Without caching | With caching |
|---|---|---|
| TPM consumed | Full system-prompt tokens every call | Cache-hit tokens count at **~0.1×** against your TPM quota |
| Effective throughput | Baseline | **5–10× higher** for agents with large, stable prompts |
| Latency (TTFT) | Full prefill | Measurably lower on long prompts |

The practical effect: agents like `picard` and `belanna` whose system prompts
run to thousands of tokens stop being the first to hit Anthropic TPM limits
during busy Squad runs.

---

## How It Works

Claude's messages API accepts a `cache_control` field on any content block.
When you add `{ "type": "ephemeral" }` at a stable boundary, Anthropic caches
everything *up to and including* that block for **5 minutes** (TTL is reset on
each cache hit).

You can add up to **4** cache breakpoints per request.

---

## Example: Before / After

### Before (no caching)

```json
{
  "model": "claude-opus-4-5",
  "system": "You are Picard, lead architect…  [3 000 tokens of persona + policies]",
  "messages": [
    { "role": "user", "content": "Review this PR diff…" }
  ]
}
```

Every call charges the full 3 000 system-prompt tokens against your TPM limit.

### After (with cache breakpoint)

```json
{
  "model": "claude-opus-4-5",
  "system": [
    {
      "type": "text",
      "text": "You are Picard, lead architect…  [3 000 tokens of persona + policies]",
      "cache_control": { "type": "ephemeral" }
    }
  ],
  "messages": [
    { "role": "user", "content": "Review this PR diff…" }
  ]
}
```

The first request within a 5-minute window is a **cache write** (charged at
1.25× input tokens — slightly more expensive). Every subsequent hit within the
window is a **cache read** (charged at 0.1× input tokens — 10× cheaper).

### Multi-breakpoint example (system + large tool list)

```json
{
  "model": "claude-opus-4-5",
  "system": [
    {
      "type": "text",
      "text": "[stable persona block — 2 000 tokens]",
      "cache_control": { "type": "ephemeral" }
    },
    {
      "type": "text",
      "text": "[dynamic per-task context — 500 tokens, no cache_control]"
    }
  ],
  "tools": [
    {
      "name": "grep",
      "description": "…",
      "input_schema": { … },
      "cache_control": { "type": "ephemeral" }
    }
    // … more tools
  ],
  "messages": [ … ]
}
```

Stable persona + stable tool definitions each get their own breakpoint,
maximising the cacheable prefix while keeping the dynamic context uncached.

---

## Which Squad Agents Benefit Most

| Agent | Why |
|---|---|
| **picard** | Large architectural + decision-authority system prompt; called frequently as coordinator |
| **belanna** | Helm / K8s domain knowledge block is large and rarely changes |
| **data** | .NET + Go expert persona; stable across all coding tasks |
| **seven** | Documentation templates + research heuristics are stable |
| **scribe** | Session-log schema + formatting rules are constant |

Agents with short or highly variable system prompts (e.g., `ralph`, `troi`)
get less benefit because the cacheable prefix is small or changes every call.

---

## How to Verify Caching Is Working

Check the `usage` object in the Claude API response:

```json
{
  "usage": {
    "input_tokens": 120,
    "cache_creation_input_tokens": 2850,
    "cache_read_input_tokens": 0
  }
}
```

First call → `cache_creation_input_tokens > 0` (cache written).

```json
{
  "usage": {
    "input_tokens": 120,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 2850
  }
}
```

Subsequent calls within 5 min → `cache_read_input_tokens > 0` (cache hit).

If `cache_read_input_tokens` is always 0, check:
1. The system prompt text is **byte-for-byte identical** on each call.
2. The `cache_control` block is present in the exact same position.
3. Your Anthropic account has prompt caching enabled (available on all paid
   tiers as of early 2025; not available on free tier).

---

## Prerequisites

- **Messages API only** — prompt caching does not apply to the legacy
  `/v1/complete` (completions) endpoint.
- **Anthropic account with caching enabled** — enabled by default on Haiku,
  Sonnet, and Opus models on paid plans.
- **Minimum cacheable block size**: Anthropic requires at least **1 024 tokens**
  in a cached block for Claude 3.5 / Claude 3 models; smaller blocks are
  accepted but not cached.
- The breakpoint must appear at the **end** of a stable prefix — anything after
  it is still processed fresh each request.

---

## Integration with the Squad Rate-Limit System

Prompt caching directly reduces TPM consumption, which is the primary driver
of Anthropic 429 responses. The rate-limit manager (`scripts/rate-limit-manager.ps1`)
tracks 429 incidents and zone status; adding cache breakpoints is complementary:

```
Prompt caching → fewer tokens consumed → lower TPM → zone stays GREEN longer
                                                    → fewer incidents logged
```

Monitor effectiveness via:
```powershell
.\scripts\rate-limit-dashboard.ps1   # watch incident count drop over time
```

---

## Status: Agent Modifications Deferred

Actual modifications to individual agent system prompt files require a
**per-agent API call audit** to confirm:

1. The agent uses the messages API (not completions).
2. The system prompt is constructed in a way that allows stable prefix isolation.
3. The `cache_control` placement does not interfere with dynamic injections
   (e.g., per-task context, tool outputs).

This audit is tracked separately. This document captures the design intent and
implementation pattern so any team member can apply it once the audit clears.

---

## References

- [Anthropic prompt caching docs](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- `scripts/rate-limit-manager.ps1` — pool schema and quota tracking
- `scripts/rate-limit-dashboard.ps1` — live monitoring dashboard
- GitHub issue #1169 — parent feature tracking this work
