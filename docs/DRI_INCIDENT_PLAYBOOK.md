# DRI / Incident Manager Playbook

> **Source:** Joshua's playbook, shared by Ravid in the IDP LT Weekly Staff meeting chat.
> **Captured from:** [Teams meeting chat](https://teams.microsoft.com/l/message/19:meeting_ZDMxZmQyOTktNDI2NS00OGEyLWJmNGItMzVhZGEzY2JhN2I3@thread.v2/1773240260706?context=%7B%22contextType%22%3A%22chat%22%7D)
> **Related:** Issue #334, Issue #333 (Azure Status check during incidents)

---

## First Thing to Do (Always)

- **Confirm customer impact**
- **Declare an outage if there is any chance of impact**

**First question on the call:**

> "Is there customer impact?"

If **yes or unclear**:
- Declare an outage in **ICM immediately**
- It's better to notify early and be wrong than to delay while investigating

**Why early declaration matters:**
- Prevents duplicate investigations by app teams
- Avoids confusion when customers' own monitors fire
- The goal is **mitigating customer pain**, *not* root cause analysis

---

## The Only Four Mitigation Actions (Strict Order)

### 1. Rollback

- Identify what changed most recently
- Roll it back
- Safest and fastest option
- Should take **minutes**, not tens of minutes
- **Always do this first**

### 2. Add Capacity

- If constrained by scale or load
- No new code — just more resources
- Low risk, often effective

### 3. Fail Out / Fail Over

- When a region, cluster, or fault domain is unhealthy
- Move traffic away
- Be cautious: can stress other regions
- Still preferable to customer downtime

### 4. Fix Forward (Last Resort)

- Introduces new change
- Slowest and riskiest option
- Requires:
  - PR approval
  - Multiple sets of eyes
  - Senior / subject-matter experts if needed
- **Never do this first**

---

## Incident Manager — Core Responsibilities

- Keep the DRI focused on one of the four actions
- Track the clock (SLAs matter)
- Handle communications and escalation
- Pull in partner teams
- Escalate through management if stuck
- Declare / undeclare outages
- Explicitly mark resolved or false alarm
- Encourage breaks — if a DRI has been investigating for hours, tell them to step away

---

## What NOT to Do During an Incident

- Don't chase root cause
- Don't debug deeply
- Don't "fix forward" solo
- Don't wait for perfect information before declaring an outage

---

## Mental Model

> "There are only four things you can do in an incident.
> Your job is to get to one of them as fast as possible."
> — Joshua

---

## Related Squad Resources

- **Azure Status Check:** During any incident, check [Azure Status](https://azure.status.microsoft/en-us/status) first to distinguish "our problem" from "Azure-wide outage" (see Issue #333, `.squad/skills/incident-response/SKILL.md`)
