# 🎬 Squad for Kids — Demo Video Scripts

> Master index of all 20 planned demo videos with status tracking.
> Each video has a dedicated script file with storyboard, narration, and recording instructions.

---

## Status Legend

| Status | Meaning |
|--------|---------|
| 📝 Scripted | Script written, ready to record |
| 🎥 Recording | Currently being recorded |
| ✂️ Editing | Recorded, in post-production |
| ✅ Published | Final video published |
| ⏸️ Blocked | Waiting on dependency |

---

## Core Demos (Hebrew + English versions)

| # | Video | File | Duration | Hebrew | English | Status |
|---|-------|------|----------|--------|---------|--------|
| 1 | Fork & Setup | [01-fork-and-setup.md](01-fork-and-setup.md) | 4 min | 📝 | 📝 | 📝 Scripted |
| 2 | Ralph Watch | [02-ralph-watch.md](02-ralph-watch.md) | 3 min | 📝 | 📝 | 📝 Scripted |
| 3 | Child Creates Issues | [03-child-creates-issues.md](03-child-creates-issues.md) | 3 min | 📝 | 📝 | 📝 Scripted |
| 4 | Parent Creates Issues | [04-parent-creates-issues.md](04-parent-creates-issues.md) | 3 min | 📝 | 📝 | 📝 Scripted |
| 5 | Issue Auto-Resolution | [05-issue-auto-resolution.md](05-issue-auto-resolution.md) | 5 min | 📝 | 📝 | 📝 Scripted |
| 6 | Scheduled Tasks | [06-scheduled-tasks.md](06-scheduled-tasks.md) | 4 min | 📝 | 📝 | 📝 Scripted |
| 7 | Decisions & Directives | [07-decisions-and-directives.md](07-decisions-and-directives.md) | 4 min | 📝 | 📝 | 📝 Scripted |
| 8 | WhatsApp/Telegram Integration | [08-whatsapp-telegram-integration.md](08-whatsapp-telegram-integration.md) | 5 min | 📝 | 📝 | 📝 Scripted |

## Feature Demos

| # | Video | File | Duration | Language | Status |
|---|-------|------|----------|----------|--------|
| 9 | First-Time Onboarding | [09-first-time-onboarding.md](09-first-time-onboarding.md) | 5 min | EN | 📝 Scripted |
| 10 | Character Casting | [10-character-casting.md](10-character-casting.md) | 3 min | EN | 📝 Scripted |
| 11 | Homework Helper | [11-homework-helper.md](11-homework-helper.md) | 5 min | EN | 📝 Scripted |
| 12 | Grade Transition | [12-grade-transition.md](12-grade-transition.md) | 3 min | EN | 📝 Scripted |
| 13 | Gamification & Badges | [13-gamification-badges.md](13-gamification-badges.md) | 4 min | EN | 📝 Scripted |
| 14 | Study Scheduler | [14-study-scheduler.md](14-study-scheduler.md) | 4 min | EN | 📝 Scripted |
| 15 | Parent Weekly Report | [15-parent-weekly-report.md](15-parent-weekly-report.md) | 3 min | EN | 📝 Scripted |
| 16 | Multi-Language | [16-multi-language.md](16-multi-language.md) | 4 min | EN/HE/AR | 📝 Scripted |
| 17 | Read Aloud | [17-read-aloud.md](17-read-aloud.md) | 3 min | EN | 📝 Scripted |
| 18 | Squad Templates | [18-squad-templates.md](18-squad-templates.md) | 4 min | EN | 📝 Scripted |
| 19 | Starter Projects | [19-starter-projects.md](19-starter-projects.md) | 5 min | EN | 📝 Scripted |
| 20 | Safety & Content Filtering | [20-safety-content-filtering.md](20-safety-content-filtering.md) | 4 min | EN | 📝 Scripted |
| 21 | Teen Exam Prep — Bagrut | [21-teen-exam-prep.md](21-teen-exam-prep.md) | 6 min | HE/EN | 📝 Scripted |

---

## Total Runtime

| Category | Count | Combined Duration |
|----------|-------|-------------------|
| Core Demos | 8 | ~31 minutes |
| Feature Demos | 13 | ~53 minutes |
| **Total** | **21** | **~84 minutes** |

> Note: Core demos require Hebrew + English versions, effectively doubling to ~62 minutes for core content. Video 21 (Teen Exam Prep) includes both Hebrew and English narration.

---

## Recording Order (Recommended)

Record in dependency order — some videos reference profiles/state created in earlier ones:

### Phase 1: Foundation (record first)
1. `01-fork-and-setup` — sets up the repo
2. `09-first-time-onboarding` — creates the student profile
3. `10-character-casting` — establishes the universe

### Phase 2: Core Loop
4. `03-child-creates-issues` — kid interaction pattern
5. `04-parent-creates-issues` — parent interaction pattern
6. `02-ralph-watch` — background processing
7. `05-issue-auto-resolution` — end-to-end flow

### Phase 3: Features
8. `11-homework-helper`
9. `13-gamification-badges`
10. `14-study-scheduler`
11. `12-grade-transition`
12. `15-parent-weekly-report`

### Phase 4: Advanced
13. `06-scheduled-tasks`
14. `07-decisions-and-directives`
15. `16-multi-language`
16. `17-read-aloud`
17. `18-squad-templates`
18. `19-starter-projects`

### Phase 5: Integration & Safety
19. `08-whatsapp-telegram-integration`
20. `20-safety-content-filtering`

---

## Supporting Files

| File | Purpose |
|------|---------|
| [recording-checklist.md](recording-checklist.md) | Hardware, software, settings, post-processing |
| [../profiles/yoav-grade2.json](../profiles/yoav-grade2.json) | Default student profile for demos |
| [../reset-demo.ps1](../reset-demo.ps1) | Clean slate between recordings |
| [../RECORDING.md](../RECORDING.md) | Original recording guide (terminal setup) |

---

## How to Update Status

When recording a video, update the status columns in the table above:

```markdown
| 1 | Fork & Setup | ... | 4 min | 🎥 | 📝 | 🎥 Recording |
```

When published, link to the final video:

```markdown
| 1 | [Fork & Setup](https://youtu.be/xxx) | ... | 4 min | ✅ | ✅ | ✅ Published |
```
