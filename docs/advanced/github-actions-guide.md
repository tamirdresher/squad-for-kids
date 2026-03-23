# ⚙️ GitHub Actions & Automation Guide

> **For parents:** Everything you need to know about the automated processes in Squad for Kids, including honest pricing information.

---

## 📋 Table of Contents

1. [What are GitHub Actions?](#what-are-github-actions)
2. [What's Free](#whats-free)
3. [What Costs Money](#what-costs-money)
4. [Workflows in This Project](#workflows-in-this-project)
5. [How to Set Up Scheduled Tasks](#how-to-set-up-scheduled-tasks)
6. [Cost Calculator](#cost-calculator)
7. [GitHub Copilot Costs](#github-copilot-costs-the-ai-that-powers-squad)
8. [Total Cost Breakdown for Parents](#total-cost-breakdown-for-parents)

---

## What are GitHub Actions?

**Simple explanation:** GitHub Actions are automated helpers that run on GitHub's servers. Think of them as little robots that do tasks for you automatically — no human intervention needed.

You don't need to install anything. You don't need to leave your computer running. GitHub handles everything in the cloud.

**Examples relevant to Squad for Kids:**
- 🕐 **Daily study reminders** — a workflow can check if your child has logged in today
- 📊 **Progress reports** — automatically generate weekly learning summaries
- 📋 **Issue triage** — when your child opens a new learning request, it gets categorized automatically
- 💓 **Health checks** — every 6 hours, a robot checks that nothing is stuck or broken

---

## What's Free

### Public Repositories (like Squad for Kids!)

| Resource | Free Tier | Notes |
|----------|-----------|-------|
| **GitHub Actions minutes** | **Unlimited** | Public repos get unlimited free minutes! |
| **Storage for artifacts** | 500 MB | Logs, reports, build outputs |
| **Concurrent jobs** | 20 | How many automations can run at the same time |

> ✅ **Squad for Kids is a public repository.** This means all GitHub Actions automations are **completely free with no limits on minutes**.

### Private Repositories (if you make your fork private)

| Resource | Free Tier (GitHub Free) | Notes |
|----------|------------------------|-------|
| **GitHub Actions minutes** | **2,000 minutes/month** | ~33 hours of automation |
| **Storage** | 500 MB | Same as public |

> 💡 Even if you make your fork private, 2,000 free minutes per month is more than enough for Squad for Kids. You'd need to run automations for 33+ continuous hours to exceed this.

---

## What Costs Money

We believe in **full transparency**. Here's what *could* cost money:

### GitHub Copilot (the AI brain)

| Plan | Price | What You Get |
|------|-------|-------------|
| **Copilot Free** | **$0/month** | 2,000 code completions + 50 chat messages/month |
| **Copilot Pro** | **$10/month** ($100/year) | Unlimited completions + unlimited chat |
| **Student/Teacher** | **$0/month** | Full Copilot Pro — free via [GitHub Education](https://education.github.com) |
| **Open-source maintainer** | **$0/month** | Free Copilot for qualifying maintainers |

### GitHub Actions (beyond free tier)

Only applies if your repo is **private** AND you exceed 2,000 minutes/month:

| Runner Type | Cost per Minute | Cost per Hour |
|-------------|----------------|---------------|
| Linux | $0.008 | $0.48 |
| Windows | $0.016 | $0.96 |
| macOS | $0.08 | $4.80 |

> 🎯 **Important:** Squad for Kids uses only Linux runners, and the repo is public. **Your cost: $0.**

### GitHub Codespaces (the cloud development environment)

| Resource | Free Tier | Notes |
|----------|-----------|-------|
| Core-hours | **120 core-hours/month** | ~60 hours on a 2-core machine |
| Storage | 15 GB/month | For your Codespace files |

> 💡 120 core-hours = roughly 60 hours of learning per month. That's about 2 hours per day — plenty for most kids!

---

## Workflows in This Project

Squad for Kids includes 4 automated workflows. **All are free on public repos.**

### 1. 💓 `squad-heartbeat.yml` — Health Check

| | |
|---|---|
| **What it does** | Checks for untriaged issues, labels them, and reminds about stale PRs |
| **When it runs** | Every 6 hours (automatic) + manual trigger |
| **Trigger** | `cron: '0 */6 * * *'` |
| **Cost** | **FREE** (public repo) |
| **Typical run time** | < 1 minute |

**In plain English:** Every 6 hours, Ralph (our friendly robot) checks if there are any new learning requests that haven't been categorized yet. If a Pull Request has been sitting for over a week, Ralph leaves a gentle reminder.

### 2. 📋 `squad-triage.yml` — Automatic Issue Categorization

| | |
|---|---|
| **What it does** | Reads new issues, categorizes them (bug, feature, homework, game, question), and posts a friendly comment |
| **When it runs** | When an issue gets the `squad` label |
| **Trigger** | `issues: [labeled]` |
| **Cost** | **FREE** (public repo) |
| **Typical run time** | < 30 seconds |

**In plain English:** When your child creates a new issue (like "I want to build a game!"), the system automatically figures out what type of request it is and adds the right labels. It also posts a friendly encouraging comment in Hebrew.

### 3. 📊 `squad-board-sync.yml` — Project Board Sync

| | |
|---|---|
| **What it does** | Keeps the project board in sync — adds new issues, moves completed items to "Done" |
| **When it runs** | When issues are opened/closed + weekly on Sundays at 5:00 UTC (8:00 AM Israel) |
| **Trigger** | `issues: [opened, closed, reopened, labeled]` + `cron: '0 5 * * 0'` |
| **Cost** | **FREE** (public repo) |
| **Typical run time** | < 30 seconds |

**In plain English:** The project board (where you can see what's being worked on) stays automatically updated. When your child finishes a project, it moves to "Done". Every Sunday morning, a full check runs to make sure nothing is out of sync.

### 4. 🏷️ `squad-issue-assign.yml` — Work Assignment

| | |
|---|---|
| **What it does** | Assigns work to squad members (including Copilot) when a `squad:` label is added |
| **When it runs** | When an issue gets a `squad:*` label |
| **Trigger** | `issues: [labeled]` |
| **Cost** | **FREE** (public repo) |
| **Typical run time** | < 30 seconds |

**In plain English:** When you label an issue with `squad:copilot`, the system automatically assigns it to GitHub Copilot (the AI coding agent), which will create a branch and start working on it. Your child can then review the code like a real developer!

---

## How to Set Up Scheduled Tasks

### Cron Syntax Explained Simply

GitHub Actions uses "cron expressions" to define schedules. Here's how to read them:

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23, UTC time)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0=Sunday, 6=Saturday)
│ │ │ │ │
* * * * *
```

### Common Schedules

| Schedule | Cron Expression | In Plain English |
|----------|----------------|-----------------|
| Every 6 hours | `0 */6 * * *` | At minute 0, every 6th hour |
| Daily at 7 AM Israel | `0 4 * * *` | 4:00 UTC = 7:00 AM Israel (IST = UTC+3) |
| Every weekday morning | `0 4 * * 1-5` | Monday through Friday at 7 AM Israel |
| Weekly on Sunday | `0 5 * * 0` | Every Sunday at 8:00 AM Israel |
| Monthly on the 1st | `0 5 1 * *` | First day of every month at 8:00 AM Israel |
| Every 15 minutes | `*/15 * * * *` | Four times per hour (not recommended — wastes minutes) |

> ⚠️ **Time zone note:** GitHub Actions uses UTC time. Israel is UTC+3 (winter) or UTC+2 (summer/DST). So "7 AM Israel" = "4 AM UTC" in winter, "5 AM UTC" in summer.

### How to Add Your Own Workflow

1. In your fork, navigate to `.github/workflows/`
2. Create a new file (e.g., `daily-check-in.yml`)
3. Use this template:

```yaml
name: Daily Check-In Reminder

on:
  schedule:
    # Every day at 7 AM Israel time (4 AM UTC)
    - cron: '0 4 * * *'
  workflow_dispatch:  # Allow manual trigger

jobs:
  remind:
    runs-on: ubuntu-latest
    steps:
      - name: Send reminder
        run: echo "⏰ Time to learn! Open your Codespace and say hi to the Squad!"
```

4. Commit the file to your `main` branch
5. The workflow will start running on the next scheduled time

### How to Disable a Workflow You Don't Want

1. Go to your fork on GitHub
2. Click the **"Actions"** tab
3. Click on the workflow name in the left sidebar
4. Click the **"..."** (three dots) button in the top-right
5. Select **"Disable workflow"**

> 💡 Disabling is better than deleting — you can re-enable it later if you change your mind.

---

## Cost Calculator

### Scenario 1: Public Fork (Recommended) ✅

| Usage | Minutes Used | Cost |
|-------|-------------|------|
| Heartbeat (4x/day × 30 days × ~1 min) | ~120 min | **$0** |
| Triage (on issue creation, ~10/month × 0.5 min) | ~5 min | **$0** |
| Board sync (weekly + events, ~20/month × 0.5 min) | ~10 min | **$0** |
| Issue assign (~10/month × 0.5 min) | ~5 min | **$0** |
| **Total** | **~140 min/month** | **$0** |

> 🎉 **If your child uses Squad daily with all automations enabled, your estimated monthly GitHub Actions cost is: $0 (public repo — unlimited free minutes)**

### Scenario 2: Private Fork

| Usage | Minutes Used | Cost |
|-------|-------------|------|
| Same automations as above | ~140 min/month | **$0** (within 2,000 free minutes) |
| Remaining free minutes | 1,860 min unused | — |

> 💡 **You'd need to run workflows for 33+ hours/month to exceed the free tier.** Squad for Kids uses about 2.3 hours/month — that's 7% of your free allowance.

### Scenario 3: Power User (Private Fork + Custom Workflows)

Even if you add custom daily reports, hourly reminders, and complex CI/CD:

| Usage | Minutes Used | Cost |
|-------|-------------|------|
| Squad workflows | ~140 min | $0 |
| Custom daily report (30 × 2 min) | ~60 min | $0 |
| Hourly checks (720 × 0.5 min) | ~360 min | $0 |
| **Total** | **~560 min/month** | **$0** (within 2,000 free) |

---

## GitHub Copilot Costs (the AI that Powers Squad)

GitHub Copilot is the AI engine that makes the Squad agents work. Here are the options:

### Copilot Free Tier — $0/month
- ✅ 2,000 code completions per month
- ✅ 50 chat messages per month
- ✅ Access to GPT-4o and Claude Sonnet models
- ⚠️ 50 chat messages = enough for about 2-3 learning sessions per week

### Copilot Pro — $10/month ($100/year)
- ✅ Unlimited code completions
- ✅ Unlimited chat messages
- ✅ Access to all AI models (GPT-4o, Claude Sonnet, and more)
- ✅ Recommended for daily learners

### Copilot for Students & Teachers — $0/month 🎓
- ✅ **Everything in Copilot Pro — completely free**
- ✅ Apply at [education.github.com](https://education.github.com)
- ✅ Requires a school email or proof of enrollment
- ✅ Valid for the duration of your studies

> 🏫 **If your child is a student (even elementary school), they may qualify for the free education program.** The application process is straightforward and usually approved within a few days.

### How to Check Your Copilot Status

1. Go to [github.com/settings/copilot](https://github.com/settings/copilot)
2. You'll see your current plan and usage
3. If you're on the Free tier, it shows remaining messages for the month

---

## Total Cost Breakdown for Parents

Here's the **complete, honest picture** of what Squad for Kids costs:

| What | Cost | Notes |
|------|------|-------|
| GitHub account | **Free** | Required — [github.com/signup](https://github.com/signup) |
| GitHub Copilot (Free tier) | **$0/month** | 50 chat messages/month — enough to get started |
| GitHub Copilot Pro | **$10/month** | Unlimited chat — recommended for daily use |
| GitHub Copilot (Student/Teacher) | **$0/month** | Apply at [education.github.com](https://education.github.com) |
| GitHub Actions (public repo) | **$0/month** | Unlimited — all automations are free |
| GitHub Actions (private repo) | **$0/month** | 2,000 free minutes — more than enough |
| GitHub Codespaces | **$0/month** | 120 core-hours free — ~60 hours of learning |
| **Total (student, Free Copilot)** | **$0/month** | ✅ Completely free |
| **Total (non-student, Free Copilot)** | **$0/month** | ⚠️ Limited to 50 chat messages |
| **Total (non-student, Copilot Pro)** | **$10/month** | ✅ Unlimited — best experience |

### The Bottom Line

- 🎓 **Students/Teachers:** Everything is **$0/month**. Apply for GitHub Education to unlock unlimited Copilot access for free.
- 👨‍👩‍👧 **Non-students using Free tier:** **$0/month** with 50 chat messages (about 2-3 sessions/week).
- 💎 **Non-students wanting unlimited:** **$10/month** for Copilot Pro — unlimited learning sessions.

> 💡 **Comparison:** A private tutor costs $40-100/hour. Copilot Pro at $10/month gives unlimited AI-powered tutoring — that's less than 15 minutes of a human tutor.

---

## Frequently Asked Questions

### "Will I get surprise charges?"
No. GitHub Free accounts have spending limits set to $0 by default. You cannot exceed your free tier unless you explicitly add a payment method and raise your spending limit.

### "What happens when I run out of free Copilot messages?"
The chat simply stops responding until the next month. No charges, no interruption to anything else.

### "Can I upgrade/downgrade Copilot anytime?"
Yes. You can switch between Free and Pro at any time from [github.com/settings/copilot](https://github.com/settings/copilot). There's no contract or commitment.

### "Is my child's data used to train AI?"
GitHub Copilot does not use your code or conversations to train AI models. See [GitHub's privacy statement](https://docs.github.com/en/copilot/overview-of-github-copilot/about-github-copilot-individual#about-privacy).

---

## Need Help?

- 📖 [Parent Guide](../parent-guide.md) — Full parent guide
- 📖 [README](../../README.md) — Project overview
- 🐛 [Open an issue](https://github.com/tamirdresher/squad-for-kids/issues) — Report problems
- 💬 [Discussions](https://github.com/tamirdresher/squad-for-kids/discussions) — Ask questions

---

*Last updated: 2025. Prices reflect GitHub's current published rates. Always check [github.com/pricing](https://github.com/pricing) for the latest information.*
