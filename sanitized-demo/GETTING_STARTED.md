# Sanitized Demo - Quick Start Guide

This directory contains a **complete, ready-to-share** demo of the Squad system.

## What You Have

✅ **19 files** demonstrating Squad capabilities
✅ **Fully sanitized** - no personal data, webhooks, or internal references
✅ **Complete agent team** - 6 specialized agents with charters
✅ **Working automation** - Ralph Watch script for autonomous monitoring
✅ **Real examples** - Decisions, skills, routing rules, configuration

## How to Create Your Public Demo Repo

### Option 1: Create New Repo (Recommended)

```bash
cd sanitized-demo

# Initialize Git
git init
git add .
git commit -m "Initial commit: Squad AI agents demo"

# Create GitHub repo (replace demo-org/squad-demo with your org/repo)
gh repo create demo-org/squad-demo --public --source=. --push --description "AI Squad Demo - Multi-agent collaboration for software development"
```

### Option 2: Push to Existing Repo

```bash
cd sanitized-demo
git init
git add .
git commit -m "Initial commit: Squad AI agents demo"
git remote add origin https://github.com/YOUR-ORG/YOUR-REPO.git
git push -u origin main
```

## Configuration Required

After creating your repo, you'll need to configure:

### 1. GitHub Project Board
- Create a Projects V2 board
- Add "Status" field with columns: Todo, In Progress, Done, Blocked, Pending User
- Get project ID and field IDs: see `.squad/skills/github-project-board/SKILL.md`
- Update the skill file with your actual IDs

### 2. Teams Webhook (Optional)
- Create an Incoming Webhook in your Teams channel
- Save webhook URL to `~/.squad/teams-webhook.url`
- Ralph will send notifications to this webhook

### 3. Squad CLI
```bash
npm install -g @bradygaster/squad
squad init
```

### 4. Start Ralph Watch
```powershell
./ralph-watch.ps1
```

## What Makes This Different

**Not just documentation** - This is a complete, working Squad setup:
- Real agent charters showing how specialists collaborate
- Working ralph-watch.ps1 script for autonomous operation
- Actual skills extracted from real work (github-project-board)
- Example decisions showing how teams make choices
- Blog draft sharing personal experience with Squad

## File Structure

```
sanitized-demo/
├── README.md                    # Comprehensive guide
├── blog-draft.md                # Personal story about using Squad
├── ralph-watch.ps1              # Autonomous monitoring script
├── squad.config.ts              # Squad configuration
├── package.json                 # Dependencies
├── .gitignore                   # Proper exclusions
├── .squad/
│   ├── agents/                  # 6 agent charters
│   │   ├── picard/charter.md    # Lead
│   │   ├── data/charter.md      # Code Expert
│   │   ├── belanna/charter.md   # Infrastructure
│   │   ├── seven/charter.md     # Research & Docs
│   │   ├── worf/charter.md      # Security
│   │   ├── ralph/charter.md     # Work Monitor
│   │   └── scribe/charter.md    # Session Logger
│   ├── decisions.md             # Team-wide decisions
│   ├── routing.md               # Work assignment rules
│   ├── team.md                  # Team roster
│   ├── upstream.json            # Inheritance config
│   ├── schedule.json            # Scheduled tasks
│   └── skills/
│       └── github-project-board/
│           └── SKILL.md         # Complete skill example
└── .github/
    └── workflows/               # (Create your own workflows here)
```

## What Was Sanitized

✅ All personal names → Generic placeholders
✅ Organization names → `demo-org`
✅ Repository names → `squad-demo`
✅ Webhook URLs → Removed (setup instructions provided)
✅ GitHub project/field IDs → Placeholders with instructions
✅ Azure resources → Removed entirely
✅ Microsoft-internal references → Genericized

## Next Steps After Creating Repo

1. **Configure project board** - Get your IDs and update skill file
2. **Set up Teams webhook** - If you want notifications
3. **Customize agents** - Adjust charters for your team
4. **Update routing** - Match your work types
5. **Start Ralph** - Begin autonomous monitoring
6. **Create issues** - Watch your Squad work!

## Share Your Experience

Once you have your Squad running:
- Share what you learned
- Contribute improvements back to https://github.com/bradygaster/squad
- Help others get started

---

**Questions?** See the main README.md in this directory or visit https://github.com/bradygaster/squad
