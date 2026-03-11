# MDE Copilot CLI Assets Repository — Research Findings

**Date:** 2026-03-12  
**Researcher:** Seven  
**Issue:** #340  
**Repo:** https://dev.azure.com/microsoft/DefenderCommon/_git/MDE.ServiceModernization.CopilotCliAssets

## Summary

Microsoft Defender team (Service Modernization) maintains a production plugin catalog for GitHub Copilot CLI and Claude Code. Repository contains 4 plugins with agents, skills, and orchestration patterns directly relevant to Squad's architecture.

## Key Architectural Patterns

### 1. Plugin Structure (`.claude-plugin/`)

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── agents/                  # Specialized agents (*.agent.md)
├── skills/                  # Agent Skills (SKILL.md)
├── commands/                # Slash commands
├── hooks/                   # Event handlers (e.g., pre-push)
├── .mcp.json                # MCP server config
└── README.md
```

**Similarity to Squad:**
- Uses `.github/agents/*.agent.md` (we use `.squad/agents/`)
- Uses `.github/skills/` (we use `.squad/skills/`)
- Has `marketplace.json` for multi-plugin discovery
- Supports MCP server integration (we use ADO/GitHub MCP)

### 2. Agent Orchestration — PR Review Orchestrator

**Most relevant plugin:** `pr-review-orchestrator`

**What it does:**
- Dispatches **6 specialized sub-agents in parallel**:
  - `code-review` — General code quality
  - `icm-pattern-analyzer` — Incident pattern detection
  - `kusto-validator` — Query validation
  - `cross-repo-breaking-change-analyser` — API breaking changes
  - `cross-repo-navigator` — Cross-repo impact
  - `security-posture-analyzer` — Security assessment
- Collects results and produces **unified review report**
- Includes **git pre-push hooks** for automatic reviews

**Alignment with Squad:**
- Same multi-agent dispatch pattern (we have Picard, Worf, LaForge, etc.)
- Parallel execution for efficiency
- Specialized agents for specific domains
- Orchestration layer produces unified output

### 3. Learning Capture — Reflect Skill

**Plugin:** `rimuri`  
**Skill:** `reflect`

**What it does:**
- Extracts **HIGH/MED/LOW confidence patterns** from agent conversations
- Prevents repeating mistakes by capturing learnings
- Stores patterns in structured format

**Relevance to Squad:**
- Ralph (Squad Lead) has "adaptive learning" in charter
- We use `history.md` files but don't formalize confidence levels
- Could inform Decision #16 Phase 2 (knowledge management evolution)

### 4. Report Generation Pipeline

**Plugin:** `news-letter-reporter`

**Pattern:**
1. `srs-member-deep-dive` skill — Collects ADO + M365 evidence per team member
2. `srs-report-manager` skill — Provides grouping rules, constants
3. `srs-newsletter-html` skill — Renders HTML from structured JSON
4. `monthly-service-report` agent — Orchestrates the pipeline

**Relevant to Squad:**
- Multi-skill pipeline pattern
- ADO/M365 data integration (we have these MCPs)
- Structured → presentation rendering

## Differences from Squad

| Aspect | MDE CopilotCliAssets | Squad |
|--------|----------------------|-------|
| **Scope** | Multi-plugin catalog for sharing | Single integrated team |
| **Distribution** | Copy plugins to `.github/` | In-repo `.squad/` structure |
| **Agent model** | Generic Copilot agents | Persona-based agents (Star Trek crew) |
| **History tracking** | Not visible | Quarterly rotation + archival |
| **Decisions** | Not formalized | `.squad/decisions.md` canonical record |
| **Installation** | Manual copy or marketplace | Git clone (monorepo) |

## Recommendations

### Immediate (Tamir Decision)

1. **Review pr-review-orchestrator** — Study parallel dispatch implementation
2. **Evaluate reflect skill** — Assess if confidence-level learning improves Ralph's adaptive behavior
3. **Consider git hooks** — Pre-push review automation could reduce issues

### Long-term (Team Discussion)

1. **Plugin marketplace** — If Squad expands to multiple repos, adopt `.claude-plugin/marketplace.json` pattern
2. **MCP standardization** — Their `.mcp.json` approach could inform our MCP server configs
3. **Learning formalization** — Reflect skill's HIGH/MED/LOW pattern could enhance Phase 2 knowledge management

## Files to Explore

- `/plugins/pr-review-orchestrator/README.md` — Agent orchestration docs
- `/plugins/pr-review-orchestrator/agents/*.agent.md` — Specialized agent prompts
- `/plugins/rimuri/skills/reflect/SKILL.md` — Learning capture system
- `/.claude-plugin/marketplace.json` — Plugin discovery config
- `/README.md` — Architecture overview

## Conclusion

**This repository is a production reference implementation** of multi-agent orchestration patterns that validate Squad's design. The PR review orchestrator is especially relevant — it demonstrates that parallel specialized-agent dispatch is a proven pattern at Microsoft scale.

**Proposal:** Tamir should evaluate if any plugins (particularly `pr-review-orchestrator` or `reflect`) warrant adoption or adaptation for Squad.
