# WorkIQ Query Template — Incidents Channel

> Channel: Incidents (Teams)
> Signal priority: HIGH — Active incident tracking
> Scan order: 2 (after dk8s-support for dedup)

## Query Templates

### Template 1: Active Incidents

```
What incidents were reported or discussed in the Incidents channel between {{DATE_FROM}} and {{DATE_TO}}? Include severity, affected services, current status (active/mitigated/resolved), and any timeline information.
```

### Template 2: Incident Resolutions

```
What incidents were resolved or mitigated in the Incidents channel between {{DATE_FROM}} and {{DATE_TO}}? Include the resolution method, root cause if identified, and who resolved it.
```

### Template 3: Post-Incident Actions

```
What post-incident reviews, action items, or follow-ups were discussed in the Incidents channel between {{DATE_FROM}} and {{DATE_TO}}? Include any process changes or prevention measures agreed upon.
```

---

## Signal Patterns

| QMD Category | Likelihood | Typical Patterns |
|-------------|-----------|-----------------|
| Blockers & Resolutions | **Very High** | Active incidents → resolution threads |
| Pattern Changes | **High** | New failure modes, regression patterns, SLO breaches |
| Decisions | **Medium** | Incident response decisions, rollback choices |
| Commitments | **Medium** | Fix timelines, post-incident review dates |
| Contacts & Relationships | **Low** | Incident commanders, on-call rotations |

## Incident Status Tracking

When scanning this channel, track incident state transitions:

```
OPENED  → severity, service, reporter, timestamp
UPDATED → new information, status change
MITIGATED → partial fix, workaround applied
RESOLVED → root cause, fix applied, resolver
```

Mark resolved incidents in the digest with `[RESOLVED]` tag so downstream processing can close them out.

## Dedup Notes

- **Heavy overlap with dk8s-support** — same incident often discussed in both channels
- If dk8s-support already captured an incident (by fingerprint), mark as `[DUP:dk8s-support]`
- Incident updates across hours should be grouped into a single digest entry per incident ID

## Noise Filters

- Automated monitoring alerts (PagerDuty, Grafana) with no human context
- "Acknowledged" responses with no additional detail
- Status page update notifications
