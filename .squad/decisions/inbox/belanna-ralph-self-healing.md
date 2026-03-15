# Decision: Ralph Self-Healing Architecture

**Date:** 2026-07-15
**Author:** B'Elanna (Infrastructure Expert)
**Issue:** #558
**PR:** #559
**Status:** PROPOSED

## Context

Ralph runs autonomously on DevBoxes and occasionally encounters gh CLI auth failures (missing scopes, expired tokens). Additionally, GitHub sends error notification emails that go unnoticed until a human checks. Both require manual intervention, breaking Ralph's autonomous loop.

## Decision

### 1. gh auth self-heal runs in PowerShell, not inside copilot session
The auth check (`gh api user`) runs as a PowerShell pre-round step (Step -1) in ralph-watch.ps1. This is faster, costs no tokens, and fixes auth before the copilot session even starts. Only the Playwright device flow delegates to agency copilot (which has Playwright MCP access).

### 2. Email monitoring runs inside the copilot session via prompt
GitHub error email monitoring is embedded in Ralph's agency prompt because it needs WorkIQ MCP tool access, which is only available inside the copilot session. The prompt instructs Ralph to check for specific GitHub notification patterns and create deduplicated issues.

### 3. Alert deduplication via GitHub labels
Issues created by email monitoring use label format `squad,github-alert,{type}` (e.g., `squad,github-alert,ci-failure`). Before creating a new issue, Ralph checks for existing open issues with matching labels to avoid duplicates.

### 4. Auto-remediation scoping
Only CI workflow failures are auto-remediated (re-run). Security alerts and dependency vulnerabilities require human review — Ralph flags these in Teams notifications.

## Alternatives Considered

- **Running self-heal inside copilot session**: Rejected — adds latency and token cost to every round, even when auth is healthy.
- **Separate email monitor daemon**: Rejected — would need its own scheduling; embedding in Ralph's existing round loop is simpler.
- **Full Playwright automation without agency**: Rejected — agency copilot provides adaptive handling of varying GitHub login page states.

## Impact

- All squad agents benefit from self-healing auth (Ralph runs on their behalf)
- GitHub error emails are now surfaced as issues automatically
- Reduces Tamir's need to manually check email for GitHub notifications
