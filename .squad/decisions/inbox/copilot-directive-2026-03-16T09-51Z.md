### 2026-03-16T09:51Z: Teams channel routing established
**By:** Tamir Dresher (via Copilot)
**What:** Squad notifications must be routed to dedicated channels under the "squads" team (5f93abfe-b968-44ea-bd0a-6f155046ccc7):
- Tech News → tech briefings
- Ralph Alerts → errors, stalls, health
- Wins and Celebrations → closed issues, merges, birthdays  
- PR and Code → PRs, reviews, CI
- Research Updates → research squad outputs
- tamir-squads-notifications → general/catch-all (webhook fallback)
Channel routing map: .squad/teams-channels.json
**Why:** User request — stop dumping everything into one channel
