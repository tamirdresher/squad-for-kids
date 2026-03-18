# Recurring Procedures — Squad for Kids

> Recurring procedures defined by parent. Kids' Ralph schedules these automatically.
> They run on the specified schedule and cannot be disabled by kids.

---

## Procedures

| ID | Name | Schedule | Description | Action |
|----|------|----------|-------------|--------|
| RP-001 | Morning Check-in | Daily 08:00 (Sun–Thu) | Report yesterday's progress | Ralph posts a summary of completed/pending tasks |
| RP-002 | Weekly Parent Report | Sunday 18:00 | Weekly progress summary | Ralph generates a summary and sends to Tamir via Teams |
| RP-003 | Homework Reminder | Weekdays 15:30 | Remind about homework | Ralph checks for open homework-related tasks and sends reminder |
| RP-004 | Parent Sync Check | Daily | Check for new parent directives | Ralph checks tamresearch1 for updated kids-directives |

---

## Procedure Details

### RP-001: Morning Check-in
- Time: 08:00 daily on school days (Sunday–Thursday, Israel calendar)
- Action: Ralph posts a brief summary of:
  - Tasks completed yesterday
  - Tasks due today
  - Any new parent-assigned tasks
- Output: Teams message or GitHub issue comment

### RP-002: Weekly Parent Report
- Time: Sunday evening 18:00
- Action: Ralph generates a weekly summary:
  - Tasks completed this week
  - Tasks still pending
  - Any notable activity or achievements
- Output: Teams message to Tamir

### RP-003: Homework Reminder  
- Time: 15:30 on weekdays
- Action: Ralph checks for any open issues tagged `homework` or `school`
  - If found: posts reminder to tackle them before evening
  - If none: celebrates with an encouraging message
- Output: Comment on GitHub or Teams

### RP-004: Parent Sync Check
- Time: Daily (can run multiple times)
- Action: Ralph checks `tamresearch1/.squad/kids-directives/` for changes
  - If changes found: syncs to `parent-directives.md`, notifies of updates
  - If no changes: silent pass
