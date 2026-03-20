# Upstream Connection

## Child Learning Squad

```yaml
upstream:
  name: "Yoav's Learning Squad"
  type: parent-child
  source: "C:\\temp\\squad-for-kids"
  # In production, this would be a GitHub repo URL:
  # source: "https://github.com/parent/squad-for-kids-yoav"

sync:
  frequency: weekly
  trigger: on-report-generated
  items:
    - path: ".squad/reports/weekly-*.md"
      type: progress-report
      handler: Scout
    - path: ".squad/student-profile.json"
      type: profile-update
      handler: Herald
      watch_fields:
        - grade
        - gamification.level
        - gamification.badges

notifications:
  grade_transition:
    enabled: true
    handler: Herald
    urgency: high
  achievement:
    enabled: true
    handler: Herald
    urgency: low
  frustration_alert:
    enabled: true
    handler: Scout
    urgency: medium
  weekly_report:
    enabled: true
    handler: Scout
    urgency: low

privacy:
  # NEVER sync these from the child squad:
  excluded:
    - ".squad/teaching-plan.md"      # Contains session details
    - ".github/agents/*"              # Internal agent configs
    - "session-logs/*"                # Raw interaction logs
  # Only summaries and aggregated data flow upstream
  summary_only: true
```

## How It Works

1. **Weekly sync:** When Scribe generates a weekly report in the child squad, it appears in `.squad/reports/` here.
2. **Profile watches:** When the student profile changes (grade transition, new badge, level up), Herald gets notified.
3. **On-demand:** Parent asks "How is Yoav doing?" → Scout reads the latest synced reports and generates a dashboard.
4. **Privacy boundary:** Raw session transcripts, teaching plans, and agent configs NEVER cross the upstream boundary.
