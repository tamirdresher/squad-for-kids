# ⚡ Build Your AI Squad in 30 Minutes

**Quick-Start Guide to Multi-Agent Teams with GitHub Copilot CLI**

> *By Tamir Dresher | tamirdresher.com*
> *Estimated time: 30 minutes to your first working squad*

---

## What You'll Build

In 30 minutes, you'll have a working 4-agent squad that can:
- ✅ Triage incoming GitHub issues automatically
- ✅ Write and review code changes
- ✅ Log decisions for institutional memory
- ✅ Monitor your repo continuously

**Prerequisites:**
- GitHub account with Copilot access
- GitHub Copilot CLI installed (`npm install -g @anthropic-ai/claude-cli` or equivalent)
- VS Code with Copilot extension
- Node.js 20+
- A GitHub repository to work with

---

## Step 1: Create Your Squad Config (5 minutes)

Create a `squad.config.ts` in your repository root:

```typescript
// squad.config.ts
export default {
  name: "my-squad",
  
  // Define your agents
  agents: {
    lead: {
      role: "Lead",
      description: "Breaks complex tasks into parallel work streams",
      model: "claude-sonnet-4-5",  // Good balance of speed and quality
    },
    
    coder: {
      role: "Code Expert", 
      description: "Writes, reviews, and refactors code",
      model: "claude-sonnet-4-5",
    },
    
    reviewer: {
      role: "Code Reviewer",
      description: "Reviews PRs for bugs, security issues, and best practices",
      model: "claude-sonnet-4-5",
    },
    
    scribe: {
      role: "Decision Logger",
      description: "Records all significant decisions with context and reasoning",
      model: "claude-haiku-4-5",  // Fast model for logging
    },
  },

  // How work gets routed
  routing: {
    simple: ["coder"],           // Bug fixes → straight to coder
    complex: ["lead", "coder"],  // Features → lead decomposes, coder implements
    review: ["reviewer"],        // All PRs → reviewer
    always: ["scribe"],          // Everything → scribe logs it
  },
};
```

---

## Step 2: Set Up Institutional Memory (5 minutes)

Create the `.squad` directory in your repo:

```bash
mkdir -p .squad
```

Create `.squad/decisions.md`:

```markdown
# Squad Decisions Log

This file records all significant decisions made by the team.
All agents read this file before starting work.

---

## Decision: Adopt Squad Pattern
- **Date:** [today's date]
- **Context:** Team wants to automate routine development tasks
- **Decision:** Implement 4-agent squad (Lead, Coder, Reviewer, Scribe)
- **Reasoning:** Specialization prevents agent paralysis, clear ownership
  enables parallel work, decisions.md preserves institutional knowledge
- **Outcome:** Initial setup complete
```

Create `.squad/team.md`:

```markdown
# Team Roster

## AI Agents
- **Lead** — Task decomposition, architecture decisions
- **Coder** — Code implementation, bug fixes, test writing
- **Reviewer** — PR review, quality checks, best practices
- **Scribe** — Decision logging, context preservation

## Humans
- **[Your Name]** — Final approval on architecture decisions, merge authority

## Routing
- Bug fixes (labeled `bug`) → Coder (auto)
- Features (labeled `enhancement`) → Lead → Coder (PR required)
- All PRs → Reviewer
- All decisions → Scribe logs to decisions.md
```

---

## Step 3: Create Your First Custom Agent (10 minutes)

Create a custom instruction file for your coder agent. This goes in your Copilot CLI configuration:

### Coder Agent Instructions

```markdown
# Coder Agent Instructions

You are the Coder agent for [project name].

## Before Starting Any Task:
1. Read `.squad/decisions.md` to understand past decisions
2. Check `.squad/team.md` for routing rules
3. Review existing code conventions in the codebase

## When Writing Code:
- Follow existing patterns in the codebase
- Write tests for all new functionality
- Keep PRs small and focused (one concern per PR)
- Include clear commit messages referencing the issue

## When Fixing Bugs:
- Write a failing test first
- Fix the bug
- Verify the test passes
- Check for similar bugs nearby

## Escalation Rules:
- Architecture changes → flag for human review
- Security-sensitive code → flag for human review
- Unclear requirements → comment on issue, ask for clarification
```

### Reviewer Agent Instructions

```markdown
# Reviewer Agent Instructions

You are the Reviewer agent for [project name].

## Review Checklist:
1. **Bugs:** Logic errors, off-by-one, null handling
2. **Security:** Input validation, auth checks, secret exposure
3. **Tests:** Coverage for new code, edge cases tested
4. **Performance:** Obvious N+1 queries, unnecessary allocations

## What NOT to Comment On:
- Style/formatting (leave to linters)
- Naming preferences (unless truly confusing)
- "I would have done it differently" suggestions

## Signal-to-Noise Rule:
Only comment if you've found a genuine issue. If the code is fine, approve it.
A review with zero comments and an approval is a GOOD review.
```

---

## Step 4: Test Your Squad (10 minutes)

### Test 1: Simple Bug Fix

Create a test issue in your repo:

```
Title: Fix off-by-one error in pagination
Body: The /api/items endpoint returns 11 items when limit=10. 
      File: src/api/items.ts, line ~45
Labels: bug, squad:copilot
```

Your squad flow:
1. Ralph (or manual trigger) picks up the issue
2. Routes to **Coder** (simple bug fix)
3. Coder reads decisions.md, fixes the bug, writes a test
4. Creates PR referencing the issue
5. **Reviewer** reviews the PR
6. **Scribe** logs: "Fixed pagination off-by-one. Root cause: `<=` instead of `<`"

### Test 2: Feature Request

Create a feature issue:

```
Title: Add rate limiting to API endpoints
Body: Implement rate limiting (100 req/min per API key) 
      for all public endpoints.
Labels: enhancement, squad:copilot
```

Your squad flow:
1. Routes to **Lead** (complex feature)
2. Lead decomposes: middleware setup, config, tests, docs
3. **Coder** implements each piece
4. **Reviewer** reviews the PR
5. **Scribe** logs the rate limiting decision with reasoning

### Test 3: Verify Institutional Memory

Ask any agent: "What decisions has the team made so far?"

It should reference decisions.md and list the logged decisions. This proves the memory layer is working.

---

## Adding the Ralph Loop (Bonus: +15 minutes)

The Ralph loop turns your squad from "on-demand" to "always-on":

```bash
# Simple Ralph loop (run in background)
while true; do
  echo "[$(date)] Ralph checking for work..."
  
  # Check for new issues labeled squad:copilot
  gh issue list --label "squad:copilot" --state open --json number,title | \
    jq -r '.[] | "\(.number): \(.title)"'
  
  # Check for PRs with passing checks
  gh pr list --state open --json number,title,statusCheckRollup | \
    jq -r '.[] | select(.statusCheckRollup | all(.conclusion == "SUCCESS")) | "\(.number): \(.title) ✅"'
  
  echo "[$(date)] Ralph sleeping 5 minutes..."
  sleep 300
done
```

Save this as `ralph-watch.sh` and run in the background:

```bash
nohup bash ralph-watch.sh > ralph.log 2>&1 &
```

---

## Squad Patterns That Work

### Pattern 1: Parallel Specialization
Don't make one agent do everything. Give each agent a clear, narrow role.

❌ **Bad:** "AI Assistant — helps with everything"
✅ **Good:** "Coder — writes code" + "Reviewer — reviews code" + "Scribe — logs decisions"

### Pattern 2: decisions.md as Source of Truth
Every significant decision gets logged. Period. This is the #1 thing that makes squads work long-term.

### Pattern 3: Human Approval Gates
AI agents should NOT have autonomous authority over:
- Architecture changes
- Security-sensitive code
- Production deployments
- Hiring/budget decisions

### Pattern 4: Model Tiering
Use cheap models for simple tasks, expensive models only when needed:
- 🚀 Haiku/GPT-5-mini: Exploration, logging, simple searches
- ⚡ Sonnet/GPT-5.2: Code writing, reviews, analysis
- 🏆 Opus: Architecture decisions, complex reasoning

---

## Next Steps

1. **Expand your squad** — Add domain-specific agents (Security, Infra, Docs)
2. **Connect MCP servers** — Give agents access to your internal tools
3. **Scale to your team** — Add human team members to the routing table
4. **Read the full guide** — Visit tamirdresher.com for the complete implementation

### Resources

- **Full Squad Blog Series:** tamirdresher.com (Parts 1 & 2)
- **MCP Server Starter Kit:** Available at tamirdresher.com/resources
- **AI Agent Architecture Cheatsheet:** Available at tamirdresher.com/resources
- **Workshop (2.5 hours):** "Build Your Own Squad" — contact for enterprise delivery

---

## About the Author

**Tamir Dresher** builds AI teams that ship real code. His Squad framework has been battle-tested on enterprise Kubernetes platform teams, delivering 14 merged PRs in 48 hours with zero manual prompts. He's the author of "Rx.NET in Action" (Manning) and speaks regularly on AI-assisted development.

📧 **Get more guides:** Subscribe at **tamirdresher.com**
🐦 **Follow:** @tamloaded

---

*© 2026 Tamir Dresher. Free to share with attribution.*
