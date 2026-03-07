# WorkIQ Query Template — General Channel

> Channel: General (Teams)
> Signal priority: LOW — High noise, occasional signal
> Scan order: 4 (last, most aggressive dedup)

## Query Templates

### Template 1: Announcements and Decisions

```
What team announcements, decisions, or important updates were shared in the General channel between {{DATE_FROM}} and {{DATE_TO}}? Exclude social messages, ignore casual conversation.
```

### Template 2: People and Org Changes

```
Were there any team changes, new hires, role changes, or organizational announcements in the General channel between {{DATE_FROM}} and {{DATE_TO}}?
```

### Template 3: Cross-Cutting Topics

```
What discussions about processes, tools, standards, or cross-team coordination happened in the General channel between {{DATE_FROM}} and {{DATE_TO}}? Only include items where a decision was made or action was agreed upon.
```

---

## Signal Patterns

| QMD Category | Likelihood | Typical Patterns |
|-------------|-----------|-----------------|
| Contacts & Relationships | **High** | New team members, org changes, introductions |
| Decisions | **Medium** | Process changes, tool adoption, standard updates |
| Commitments | **Low** | Team-wide deadlines, sprint goals |
| Pattern Changes | **Low** | Process shifts, workflow changes |
| Blockers & Resolutions | **Very Low** | Rarely discussed here |

## Noise Expectations

General channel has the **highest noise ratio** (~90% droppable). Apply aggressive filtering:

### Pre-Filter (Before QMD Classification)

Drop immediately:
- Social messages (greetings, celebrations, emoji reactions)
- Meeting logistics ("what room?", "link please")
- IT support requests ("my VPN is down")
- Forwarded articles without team-relevant commentary
- Poll responses without resulting decisions
- Out-of-office announcements

### Post-Filter Threshold

Only KEEP items that match QMD categories with **high confidence**. When uncertain, DROP — the cost of a false negative in General is low since high-signal channels capture the important items.

## Dedup Notes

- **Highest cross-channel overlap** — announcements often reposted from specific channels
- After dk8s-support, incidents, and configgen have been scanned, most General items will already be captured
- Apply cross-channel dedup aggressively

## Noise Filters

- All social/casual messages
- Meeting room bookings and logistics
- IT support requests unrelated to DK8S platform
- Generic company announcements without team impact
