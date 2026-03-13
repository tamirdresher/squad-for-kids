# Skill: Fact Checking
**Confidence:** low
**Domain:** quality, verification
**Last validated:** 2026-03-13

## Context
Extracted from Q's charter. Codifies the review output format and methodology so any agent performing fact-checking or review produces consistent, structured output.

## Pattern

### Review Methodology

For every claim or deliverable under review:
1. Ask: "What evidence supports this? What would disprove it?"
2. Generate counter-hypotheses and test them against available data
3. Verify URLs, package names, API endpoints, and external references actually exist
4. Flag confidence levels: ✅ Verified, ⚠️ Unverified, ❌ Contradicted

### Review Output Format

When reviewing another agent's work, use this template:

```
### Q's Fact Check — {deliverable name}
**Claims verified:** {count}
**Issues found:** {count}

| # | Claim | Status | Evidence/Notes |
|---|-------|--------|---------------|
| 1 | {claim} | ✅/⚠️/❌ | {supporting or contradicting evidence} |

**Counter-hypotheses tested:**
- {alternative explanation + result}

**Verdict:** {PASS / PASS WITH NOTES / NEEDS REVISION}
```

### Confidence Levels

- ✅ **Verified** — evidence confirms the claim
- ⚠️ **Unverified** — cannot confirm or deny; suggest verification method
- ❌ **Contradicted** — evidence disproves the claim
