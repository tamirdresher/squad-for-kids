# 👨‍👩‍👧 Parent Guide — Squad for Kids

> Everything you need to know about setting up, monitoring, and managing your child's AI learning environment.

---

## 📋 Table of Contents

1. [How the Fork System Works](#how-the-fork-system-works)
2. [Step-by-Step Setup](#step-by-step-setup)
3. [Monitoring Your Child's Progress](#monitoring-your-childs-progress)
4. [Syncing Updates from Upstream](#syncing-updates-from-upstream)
5. [Privacy & Safety](#privacy--safety)
6. [Multiple Children](#multiple-children)
7. [Costs & Pricing](#costs--pricing)
8. [GitHub Actions & Automation](#github-actions--automation)
9. [Troubleshooting](#troubleshooting)

---

## How the Fork System Works

```
┌──────────────────────────────┐
│  tdsquadAI/squad-for-kids │  ← Original repo (curriculum, features, templates)
│  (upstream)                  │
└──────────┬───────────────────┘
           │ Fork
           ▼
┌──────────────────────────────┐
│  YOUR-USERNAME/squad-for-kids│  ← Your child's personal copy
│  (your fork)                 │
│                              │
│  📄 student-profile.json     │  ← Child's identity & progress
│  📁 .squad/reports/          │  ← Weekly learning reports
│  📄 .squad/teaching-plan.md  │  ← Curriculum progress
│  📁 .squad/decisions.md      │  ← Squad decisions log
└──────────────────────────────┘
```

**Key concepts:**
- 🍴 **Fork** = Your own copy of the repo. Changes you make here don't affect the original.
- 🔄 **Upstream** = The original `tdsquadAI/squad-for-kids` repo. You can pull updates from it.
- 📝 **Commits** = Every learning session creates a record in your fork's git history.

---

## Step-by-Step Setup

### Prerequisites
- A **GitHub account** (free) — [Sign up here](https://github.com/signup)
- A **laptop or desktop computer** (not phone/tablet)
- A **web browser** (Chrome, Edge, or Firefox)

### 1. Fork the Repository

1. Go to [github.com/tdsquadAI/squad-for-kids](https://github.com/tdsquadAI/squad-for-kids)
2. Click the **"Fork"** button (top-right corner, next to ⭐ Star)
   > 📸 *The Fork button looks like a branching arrow. It's between Watch and Star.*
3. On the "Create a new fork" page:
   - **Owner:** Select your GitHub account
   - **Repository name:** Keep as `squad-for-kids`
   - ✅ Check "Copy the main branch only"
   - Click **"Create fork"**
4. Wait a few seconds — you'll be redirected to your new fork!

### 2. Verify You're on Your Fork

Look at the top-left of the page. It should say:

```
YOUR-USERNAME / squad-for-kids
forked from tdsquadAI/squad-for-kids
```

⚠️ **Common mistake:** Make sure you're NOT on `tdsquadAI/squad-for-kids`. If you create a Codespace on the original repo, your child's progress won't be saved to your account.

### 3. Create a Codespace

1. On **your fork's** page, click the green **"Code"** button
2. Switch to the **"Codespaces"** tab
3. Click **"Create codespace on main"**
4. ⏱️ Wait 1-2 minutes for the environment to load

> 💡 A Codespace is a cloud computer that runs VS Code in your browser. No installation needed!

### 4. Launch the Squad

1. Open Copilot Chat: click the 💬 icon in the sidebar, or press `Ctrl+Alt+I`
2. At the bottom of the chat window, select **"squad"** from the agent dropdown
3. Click **"Autopilot (Preview)"** to enable autonomous mode
4. Hand the keyboard to your child! 🎉

### 5. First Session

Your child types a greeting (e.g., `היי!` or `Hello!`) and the Squad takes it from there:
- Asks for their name
- Asks their age/grade
- Lets them pick a theme (Harry Potter, superheroes, Minecraft…)
- Creates their personalized learning team
- Suggests a first project

---

## Monitoring Your Child's Progress

### 📄 Student Profile (`student-profile.json`)

This file is created during the first session and contains:

```json
{
  "name": "Maya",
  "age": 10,
  "grade": "4th",
  "country": "Israel",
  "curriculum": "Israeli Ministry of Education",
  "language": "he",
  "interests": ["dinosaurs", "Minecraft", "math"],
  "universe": "Harry Potter",
  "xp": 450,
  "level": 3,
  "badges": ["Math Wizard", "First Project"],
  "streak": 7
}
```

### 📁 Weekly Reports (`.squad/reports/`)

After each learning week, a report is generated:

```
.squad/reports/
├── weekly-2025-01-06.md
├── weekly-2025-01-13.md
└── weekly-2025-01-20.md
```

Each report includes:
- 📚 Topics covered and time spent
- 💪 Areas of strength
- 🎯 Areas needing practice
- 🎮 XP and badges earned
- 💡 Suggested weekend activities
- 🤗 Emotional wellbeing notes

### 📄 Teaching Plan (`.squad/teaching-plan.md`)

Current curriculum progress — what's been covered, what's next, and mastery levels per subject.

### 📊 Git Commit History

Every learning session creates commits in your fork. You can see the full timeline:
1. Go to your fork on GitHub
2. Click on **"commits"** (or the clock icon)
3. Browse the history of what your child did in each session

### 🔍 Viewing Progress from Your Computer

You can check your child's progress without opening a Codespace:
1. Go to your fork on GitHub (`github.com/YOUR-USERNAME/squad-for-kids`)
2. Navigate to `student-profile.json` — see current stats
3. Navigate to `.squad/reports/` — read weekly reports
4. Check the commit history — see session-by-session activity

---

## Syncing Updates from Upstream

When we add new features, templates, or curriculum content to the original repo, your fork can pull those updates:

### Automatic (GitHub UI)

1. Go to your fork on GitHub
2. Look for the banner: **"This branch is X commits behind tdsquadAI:main"**
3. Click **"Sync fork"**
4. Click **"Update branch"**

> ✅ **Safe:** Your child's personal files (`student-profile.json`, `.squad/reports/`, etc.) won't be overwritten — they don't exist in the original repo.

### Manual (Command Line)

If you prefer the terminal (or if there are merge conflicts):

```bash
# Add the upstream remote (one-time setup)
git remote add upstream https://github.com/tdsquadAI/squad-for-kids.git

# Fetch and merge updates
git fetch upstream
git merge upstream/main

# Push to your fork
git push origin main
```

### Using the Setup Script

We provide a PowerShell script that automates the initial setup:

```powershell
pwsh setup-parent.ps1
```

This script:
- ✅ Checks if this repo is a fork
- 🔗 Sets up the `upstream` remote
- 📄 Creates a `student-profile.json` template (if not exists)
- 👋 Prints a welcome message

---

## Privacy & Safety

### What Stays Private in Your Fork

| Data | Location | Who Can See |
|------|----------|-------------|
| Child's name & age | `student-profile.json` | Only you (your fork is private by default) |
| Learning history | `.squad/reports/` | Only you |
| Chat conversations | Codespace (ephemeral) | Deleted when Codespace is deleted |
| Curriculum progress | `.squad/teaching-plan.md` | Only you |

### Fork Visibility

By default, forks of public repos are also public. To make your child's fork private:

1. Go to your fork → **Settings** → **General**
2. Scroll to **"Danger Zone"**
3. Click **"Change visibility"** → Select **"Private"**

> ⚠️ Note: Making a fork private may require a GitHub Pro account (free for education). Alternatively, you can create a new private repo and copy the files instead of forking.

### Data Minimization

The Squad only collects:
- First name (for personalization)
- Age/grade (for curriculum matching)
- City (optional, for curriculum detection)

**No last names, no addresses, no phone numbers, no emails collected from children.**

### Safety Guardrails

- Age-appropriate content filtering for every age group
- Agents redirect inappropriate topics gently
- Homework help = explaining concepts, NOT giving answers to copy
- Frustration detection with empathy response

---

## Multiple Children

### Option A: Separate Forks (Recommended)

Create a separate fork for each child:

1. **First child:** Fork normally to your account (`your-username/squad-for-kids`)
2. **Second child:** Fork again, but rename it:
   - Fork the repo
   - Go to Settings → Rename to `squad-for-kids-sarah` (or the child's name)
3. Each child gets their own Codespace, profile, and progress tracking

### Option B: Branches

Use one fork with different branches per child:

```bash
# Create a branch for each child
git checkout -b maya-learning
# ... Maya uses this branch ...

git checkout -b david-learning
# ... David uses this branch ...
```

> 💡 **Tip:** Option A (separate forks) is simpler and keeps things cleanly separated. Option B saves on Codespace resources but requires more technical knowledge.

---

## Costs & Pricing

### What's Free

| Resource | Free Tier | Notes |
|----------|-----------|-------|
| GitHub account | Free | Required |
| GitHub Copilot Free | $0/month | 50 chat messages/month |
| GitHub Actions (public repo) | Unlimited | All automations free |
| GitHub Actions (private repo) | 2,000 min/month | ~33 hours |
| GitHub Codespaces | 120 core-hours/month | ~60 hours of learning |

### What Costs Money

| Resource | Cost | Who Needs It |
|----------|------|-------------|
| GitHub Copilot Pro | $10/month | Parents wanting unlimited chat for daily learning |
| GitHub Copilot (Student/Teacher) | $0/month | Students — apply at [education.github.com](https://education.github.com) |

### Bottom Line

- 🎓 **Students:** $0/month — apply for GitHub Education
- 👨‍👩‍👧 **Free tier:** $0/month — 50 chat messages (2-3 sessions/week)
- 💎 **Pro:** $10/month — unlimited (less than 15 minutes of a human tutor)

> 📖 **Full pricing breakdown:** [GitHub Actions & Pricing Guide](advanced/github-actions-guide.md)

---

## GitHub Actions & Automation

Squad for Kids includes automated workflows that run on GitHub's servers — free for public repos.

### Active Workflows

| Workflow | Purpose | Schedule | Cost |
|----------|---------|----------|------|
| `squad-heartbeat.yml` | Checks for untriaged issues, reminds about stale PRs | Every 6 hours | Free |
| `squad-triage.yml` | Categorizes new issues (bug, feature, homework, game) | On issue label | Free |
| `squad-board-sync.yml` | Keeps project board in sync | On events + weekly | Free |
| `squad-issue-assign.yml` | Assigns work to squad members or Copilot | On `squad:` label | Free |

### Managing Workflows

- **Disable a workflow:** Go to Actions tab → click workflow → `...` → "Disable workflow"
- **Run manually:** Most workflows support `workflow_dispatch` — click "Run workflow" button
- **Add your own:** Create a `.yml` file in `.github/workflows/`

> 📖 **Detailed guide:** [GitHub Actions & Automation Guide](advanced/github-actions-guide.md)

---

## Troubleshooting

### "I can't find the Fork button"

Make sure you're logged in to GitHub. The Fork button appears in the top-right corner of the repo page, between "Watch" and "Star".

### "My child's progress disappeared"

Check which repo the Codespace is connected to. If they opened a Codespace on the **original** repo instead of the fork, progress was saved there (and may be lost when the Codespace is deleted). Always verify you're on YOUR fork.

### "Sync fork shows merge conflicts"

This is rare but can happen. The safest approach:
1. Click **"Discard changes"** on the conflicting files (only if they're template files)
2. If the conflict is in `student-profile.json` or reports, keep your version

### "Codespace is slow or not loading"

- Try refreshing the browser
- Delete the Codespace and create a new one (your data is in git, so it's safe)
- Check [githubstatus.com](https://www.githubstatus.com) for service issues

### "The Squad agent doesn't appear"

1. Make sure you're in a Codespace (not just viewing files on GitHub)
2. Check that Copilot Chat is open (💬 icon or `Ctrl+Alt+I`)
3. Look at the bottom of the chat window for the agent dropdown
4. If "squad" isn't listed, try refreshing the Codespace

---

## Need Help?

- 📖 [README](../README.md) — Project overview
- 🐛 [Open an issue](https://github.com/tdsquadAI/squad-for-kids/issues) — Report problems
- 💬 [Discussions](https://github.com/tdsquadAI/squad-for-kids/discussions) — Ask questions

---

*Built with ❤️ for every parent who wants the best education for their child.*
