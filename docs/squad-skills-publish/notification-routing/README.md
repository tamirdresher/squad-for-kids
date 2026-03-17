# 🔀 Notification Routing

Route work items, issues, and notifications to the right handler based on domain expertise, labels, and configurable routing rules.

## What It Does

- **Domain matching** — Route work to experts using keyword and label matching
- **Issue triage** — Classify and assign issues by content and complexity
- **Agent fit evaluation** — Assess whether AI agents can handle tasks autonomously
- **Urgency-based delivery** — Route notifications to appropriate channels by priority
- **Fallback chains** — Primary → secondary → escalation routing

## Trigger Phrases

- `route work`, `assign task`
- `triage issue`, `who handles`
- `route notification`, `work routing`

## Quick Start

### Prerequisites

- Routing table configuration (`routing.json`)
- Issue tracking system (GitHub Issues, ADO, Jira, etc.)
- Notification channels (webhooks, email, messaging)

### Example Usage

```
User: "Who should handle this Kubernetes networking issue?"
Agent: [Matches keywords against routing table]
Agent: "Route to infra-team (score: 14). Keywords matched: kubernetes, networking"
```

## Routing Table

```json
{
  "routes": [
    {
      "domain": "infrastructure",
      "handler": "infra-team",
      "keywords": ["kubernetes", "docker", "networking"],
      "labels": ["infra"]
    }
  ],
  "fallback": { "handler": "team-lead" }
}
```

## Urgency Levels

| Level | Channel | Example |
|-------|---------|---------|
| 🔴 Critical | Immediate DM/page | Production outage |
| 🟡 Important | Team channel | Build failures |
| 🟢 Normal | Daily digest | PR reviews |
| ⚪ Low | Weekly summary | Dependency updates |

## See Also

- [News Broadcasting](../news-broadcasting/) — Deliver routed notifications
- [Upstream Monitor](../upstream-monitor/) — Source of change notifications
