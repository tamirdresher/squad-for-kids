---
name: notification-routing
description: "Route work items, issues, and notifications to the right agent or team member based on domain expertise, labels, and routing rules."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Multi-agent work routing patterns
---

# Notification Routing

**Route work to the right handler** using configurable routing tables, label-based triage, and domain expertise matching. Works for both human teams and AI agent squads.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `route work`, `assign task` | HIGH — Active routing |
| `triage issue`, `who handles` | HIGH — Lookup |
| `route notification` | MEDIUM — Notification delivery |
| `work routing`, `routing rules` | MEDIUM — Configuration |

---

## Routing Table

Define who handles what in a routing configuration:

### `routing.json`

```json
{
  "routes": [
    {
      "domain": "infrastructure",
      "handler": "infra-team",
      "keywords": ["kubernetes", "helm", "docker", "cloud", "networking"],
      "labels": ["infra", "devops"],
      "examples": ["K8s cluster issues", "Helm chart updates", "Network policies"]
    },
    {
      "domain": "security",
      "handler": "security-team",
      "keywords": ["auth", "encryption", "vulnerability", "CVE", "secrets"],
      "labels": ["security"],
      "examples": ["Auth token issues", "Secret rotation", "Vulnerability scanning"]
    },
    {
      "domain": "backend",
      "handler": "backend-team",
      "keywords": ["api", "database", "service", "endpoint", "migration"],
      "labels": ["backend", "api"],
      "examples": ["API endpoint bugs", "Database migrations", "Service integration"]
    },
    {
      "domain": "documentation",
      "handler": "docs-team",
      "keywords": ["docs", "readme", "guide", "tutorial", "runbook"],
      "labels": ["documentation"],
      "examples": ["README updates", "API docs", "Runbook creation"]
    },
    {
      "domain": "content",
      "handler": "content-team",
      "keywords": ["blog", "podcast", "newsletter", "announcement"],
      "labels": ["content"],
      "examples": ["Blog posts", "Team updates", "External communications"]
    }
  ],
  "fallback": {
    "handler": "team-lead",
    "action": "Manual triage required"
  }
}
```

---

## Label-Based Issue Routing

When issues receive labels, route them automatically:

### Routing Rules

| Label | Action | Handler |
|-------|--------|---------|
| `triage` | Analyze and assign domain label | Team Lead |
| `infra` | Route to infrastructure handler | Infra Team |
| `security` | Route to security handler (always human) | Security Team |
| `backend` | Route to backend handler | Backend Team |
| `docs` | Route to documentation handler | Docs Team |
| `autonomous` | Assign to AI agent for autonomous work | AI Agent |

### Triage Process

1. **New issue arrives** with generic label (e.g., `triage`)
2. **Triage handler** analyzes title, body, and metadata
3. **Domain classification** — match content against routing keywords
4. **Complexity assessment** — evaluate for autonomous agent fit:
   - 🟢 **Good fit**: Well-defined, follows patterns, has tests → route to agent
   - 🟡 **Needs review**: Medium complexity, has specs → route to agent with human review
   - 🔴 **Not suitable**: Design decisions, security-sensitive, ambiguous → route to human
5. **Apply domain label** and assign handler
6. **Comment with triage notes** explaining the routing decision

---

## Keyword Matching Algorithm

```python
def route_work_item(title, body, labels, routing_config):
    """Route a work item to the best handler based on content and labels."""

    content = f"{title} {body}".lower()
    scores = {}

    for route in routing_config["routes"]:
        score = 0

        # Label match (highest weight)
        for label in labels:
            if label.lower() in [l.lower() for l in route["labels"]]:
                score += 10

        # Keyword match
        for keyword in route["keywords"]:
            if keyword.lower() in content:
                score += 2

        if score > 0:
            scores[route["domain"]] = {
                "score": score,
                "handler": route["handler"]
            }

    if not scores:
        return routing_config["fallback"]

    best = max(scores.items(), key=lambda x: x[1]["score"])
    return {
        "domain": best[0],
        "handler": best[1]["handler"],
        "confidence": best[1]["score"]
    }
```

---

## Multi-Agent Routing

When routing across AI agents, use these patterns:

### Primary/Secondary Handlers

```json
{
  "domain": "infrastructure",
  "primary": "infra-agent",
  "secondary": "general-agent",
  "escalation": "human-reviewer"
}
```

### Routing Rules for Agents

1. **Eager by default** — spawn all agents who could usefully contribute
2. **Quick facts → direct answer** — don't route simple lookups
3. **When two handlers match** — pick the one whose domain is the primary concern
4. **Fan-out requests** — route to all relevant handlers in parallel
5. **Anticipate downstream work** — if building a feature, also route test writing

---

## Notification Delivery

Route notifications based on urgency:

| Urgency | Channel | Example |
|---------|---------|---------|
| 🔴 Critical | Immediate (Teams/Slack DM, page) | Production down, security breach |
| 🟡 Important | Team channel | Build failures, blocking issues |
| 🟢 Normal | Daily digest | PR reviews, status updates |
| ⚪ Low | Weekly summary | Dependency updates, minor issues |

### Delivery Configuration

```json
{
  "notification_channels": {
    "critical": {
      "type": "webhook",
      "url": "{WEBHOOK_URL}",
      "mention": "@oncall"
    },
    "important": {
      "type": "channel",
      "target": "team-alerts"
    },
    "normal": {
      "type": "digest",
      "frequency": "daily"
    },
    "low": {
      "type": "digest",
      "frequency": "weekly"
    }
  }
}
```

---

## See Also

- [News Broadcasting](../news-broadcasting/) — Format and deliver team updates
- [Upstream Monitor](../upstream-monitor/) — Surface changes that need routing
- [Birthday Celebration](../birthday-celebration/) — Route celebration notifications
