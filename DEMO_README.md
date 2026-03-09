# Squad Demo Repository

> **AI-Powered Team of Specialized Agents for Software Development**

This repository showcases [Squad](https://github.com/bradygaster/squad) - an advanced AI agent orchestration framework that runs autonomous teams of specialized agents to handle software development tasks.

## 🎯 What is Squad?

Squad is a next-generation AI agent framework that goes beyond single-agent assistants. It creates a **persistent team of specialized agents** that:

- **Work autonomously** on assigned tasks via GitHub issues
- **Collaborate** through shared decisions, routing rules, and skills
- **Learn continuously** by documenting patterns and decisions
- **Execute in parallel** handling multiple issues simultaneously
- **Integrate deeply** with GitHub (issues, PRs, projects, workflows)

## ✨ Key Features Demonstrated

### 1. **Multi-Agent Collaboration**
- **Picard (Lead)** - Triage, planning, cross-functional coordination
- **Data (Analyst)** - Metrics, analysis, data-driven insights
- **B'Elanna (Infrastructure)** - DevOps, cloud architecture, deployment
- **Seven (Research & Docs)** - Documentation, research, analysis
- **Worf (Security)** - Security review, compliance, threat modeling
- **Scribe (Full-Stack)** - Implementation, testing, code changes

See agent charters in `.squad/agents/*/charter.md`

### 2. **Ralph Watch - Autonomous Operations**
The `ralph-watch.ps1` script runs Squad autonomously:
- Polls GitHub issues every 5 minutes
- Spawns specialized agents for new tasks
- Updates GitHub Project boards automatically
- Sends Teams notifications on important changes
- Handles multiple issues in parallel

### 3. **Shared Knowledge Base**
- **Decisions** (`.squad/decisions.md`) - Team-wide architectural decisions
- **Skills** (`.squad/skills/*/SKILL.md`) - Reusable patterns and procedures
- **Routing** (`.squad/routing.md`) - Work assignment rules
- **Team Context** (`.squad/team.md`) - Role definitions

### 4. **Intelligent Routing**
Issues are automatically routed to the right specialist based on:
- Work type (feature-dev, bug-fix, docs, security)
- Keywords and labels
- Agent expertise and current workload
- Dependencies and blocked status

### 5. **GitHub Project Integration**
Full integration with GitHub Projects V2:
- Auto-move issues between columns (Todo → In Progress → Done)
- Track agent assignments and status
- Visual workflow management
- See `.squad/skills/github-project-board/SKILL.md`

### 6. **Continuous Learning**
Agents extract and document reusable patterns as Skills:
- **TTS Conversion** - Text-to-speech for podcasting outputs
- **GitHub Project Board** - Project automation patterns
- **Devbox Provisioning** - Cloud development environment setup
- **Teams Monitor** - Bridge Teams messages to GitHub issues

### 7. **Upstream Inheritance**
Squad supports multi-repo hierarchies where subsquads inherit from parent squads:
- Share decisions across repositories
- Synchronize team structure
- Centralized skill libraries
- See `docs/UPSTREAM_INHERITANCE.md`

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and npm
- GitHub CLI (`gh`) authenticated
- PowerShell 7+ (for Ralph Watch)
- GitHub Copilot CLI access

### Setup

1. **Install Squad CLI**
   ```bash
   npm install -g @bradygaster/squad
   ```

2. **Configure Your Squad**
   ```bash
   # Initialize in your repo
   squad init
   
   # Create your team (edit .squad/team.md)
   squad cast
   ```

3. **Set Up GitHub Project Board**
   - Create a Projects V2 board
   - Add status field with columns: Todo, In Progress, Done, Blocked, Pending User
   - Get project ID and field IDs: `gh project list --owner <org>`
   - Update `.squad/skills/github-project-board/SKILL.md` with your IDs

4. **Configure Teams Integration (Optional)**
   - Create Teams Incoming Webhook
   - Save webhook URL to `~/.squad/teams-webhook.url`
   - Agents will send notifications to Teams

5. **Start Ralph Watch**
   ```powershell
   ./ralph-watch.ps1
   ```
   
   Ralph will:
   - Monitor GitHub issues
   - Spawn agents for new work
   - Update project board
   - Send Teams alerts

## 📁 Repository Structure

```
.squad/
  agents/              # Agent charters and configurations
    picard/
      charter.md       # Lead agent definition
    seven/
      charter.md       # Research agent definition
    ... (6 agents total)
  decisions.md         # Team-wide decisions (decision log)
  routing.md           # Work assignment rules
  team.md              # Team roster and roles
  schedule.json        # Scheduled tasks
  upstream.json        # Inheritance configuration
  skills/              # Reusable pattern library
    github-project-board/
    tts-conversion/
    teams-monitor/
    ... (8 skills total)

.github/
  workflows/           # Squad automation workflows
    squad-triage.yml   # Auto-triage new issues
    squad-heartbeat.yml # Daily health check
    squad-docs.yml     # Auto-update documentation
    ... (10+ workflows)

ralph-watch.ps1        # Autonomous operation script
squad.config.ts        # Squad configuration
```

## 🎓 Key Concepts

### Agents
Specialized AI personas with defined expertise, responsibilities, and work patterns. Each agent has:
- **Charter** - Identity, expertise, ownership areas
- **History** - Learning log (not in demo - privacy)
- **Routing rules** - When they're assigned work

### Decisions
Team-wide architectural decisions that all agents must follow:
```markdown
## Decision 1: Security Review Required for Auth Changes
**Status:** ✅ Adopted
**Scope:** Code Review

All PRs touching authentication code must be reviewed by Worf.
```

### Skills
Reusable procedures extracted from real work:
```markdown
# Skill: GitHub Project Board Management
**Confidence:** high
**Domain:** issue-lifecycle

## How to Move Items
```bash
gh project item-edit --project-id <ID> ...
```
```

### Routing
Rules that determine which agent handles which work:
```typescript
{
  workType: 'security-review',
  agents: ['@worf'],
  confidence: 'high'
}
```

## 🔧 Customization

### Create Your Own Agent
1. Define charter in `.squad/agents/<name>/charter.md`
2. Add to team roster in `.squad/team.md`
3. Configure routing rules in `.squad/routing.md`

### Extract a New Skill
When you discover a reusable pattern:
```bash
# Document it
.squad/skills/<skill-name>/SKILL.md

# Include:
- Context: When to use this skill
- Procedure: Step-by-step execution
- Examples: Real usage patterns
- Confidence: How proven is this pattern?
```

### Configure Ralph Watch
Edit `ralph-watch.ps1` variables:
```powershell
$intervalMinutes = 5              # Polling frequency
$maxLogEntries = 500              # Log rotation size
$prompt = 'Ralph, Go! ...'        # Agent instructions
```

## 📊 Observability

Ralph Watch includes built-in observability:
- **Structured logging** to `~/.squad/ralph-watch.log`
- **Heartbeat file** at `~/.squad/ralph-heartbeat.json`
- **Teams alerts** on consecutive failures (>3)
- **Lock file** prevents duplicate instances

View logs:
```powershell
Get-Content $env:USERPROFILE\.squad\ralph-watch.log -Tail 50
```

## 🤝 Integration Points

### GitHub
- Issues (task management)
- Pull Requests (code review)
- Projects V2 (visual workflow)
- Workflows (automation)
- GitHub CLI (`gh`)

### Microsoft Teams
- Incoming Webhooks (notifications)
- WorkIQ MCP server (read Teams messages)

### Development Tools
- GitHub Copilot CLI (agent execution)
- Node.js (Squad CLI)
- PowerShell (Ralph Watch)

## 📚 Learn More

- **Squad Framework**: https://github.com/bradygaster/squad
- **Cross-Squad Orchestration**: See `docs/cross-squad-orchestration-design.md`
- **Upstream Inheritance**: See `docs/UPSTREAM_INHERITANCE.md`
- **Skills Library**: Browse `.squad/skills/*/SKILL.md`

## 🔐 Security Notes

This is a **demo repository** with sanitized data. For production use:
- Store webhook URLs in environment variables or GitHub Secrets
- Use GitHub Actions secrets for sensitive data
- Configure proper RBAC for project board access
- Review agent permissions and scope
- Enable audit logging

## 📄 License

This demo repository is provided as an example of Squad capabilities. See the [Squad framework license](https://github.com/bradygaster/squad) for framework terms.

## 🙏 Acknowledgments

Built with [Squad](https://github.com/bradygaster/squad) by Brady Gaster.

Demonstrates:
- Multi-agent collaboration patterns
- Continuous learning through decisions and skills
- Autonomous operation with Ralph Watch
- Deep GitHub integration
- Real-world software development workflows

---

**Ready to build your own AI agent team?**
1. Install Squad: `npm install -g @bradygaster/squad`
2. Initialize: `squad init`
3. Configure agents in `.squad/`
4. Start Ralph Watch: `./ralph-watch.ps1`
5. Create issues and watch your agents work!
