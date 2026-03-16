# Contributing Notes — Team Celebrations

> Guidance on where files from this contribution should land in the upstream Squad repository (bradygaster/squad).

## Upstream Repository

- **Repo:** `bradygaster/squad`
- **Branch:** `dev`

## File Placement

### Skill Definition

| Source File | Upstream Destination | Notes |
|-------------|---------------------|-------|
| `SKILL.md` | `.squad/skills/celebrations/SKILL.md` | Main skill documentation |

### Ceremony

| Source File | Upstream Destination | Notes |
|-------------|---------------------|-------|
| `ceremony-definition.md` | `.squad/ceremonies/daily-celebrations-check.md` | Ceremony definition for Ralph's watch cycle |

### Templates

| Source File | Upstream Destination | Notes |
|-------------|---------------------|-------|
| `templates/members.json` | `.squad/team-data/members.example.json` | Example schema — **not** actual team data |
| `templates/birthday-message.md` | `.squad/skills/celebrations/templates/birthday-message.md` | Birthday template |
| `templates/anniversary-message.md` | `.squad/skills/celebrations/templates/anniversary-message.md` | Anniversary template |
| `templates/milestone-message.md` | `.squad/skills/celebrations/templates/milestone-message.md` | Milestone template |

### Configuration

| File | Upstream Destination | Notes |
|------|---------------------|-------|
| (generate from SKILL.md) | `.squad/skills/celebrations.json` | Skill configuration — create from the config section in SKILL.md |

### State Files

| File | Upstream Destination | Notes |
|------|---------------------|-------|
| (runtime generated) | `.squad/team-data/.celebrations-state.json` | Runtime state — add to `.gitignore` |
| (team populated) | `.squad/team-data/members.json` | Actual team data — add to `.gitignore` or keep private |

## Gitignore Additions

Add to the upstream `.gitignore`:

```
# Celebrations — runtime state (do not commit)
.squad/team-data/.celebrations-state.json

# Team member data — keep private or use example file
# Uncomment the next line if your team data should not be committed:
# .squad/team-data/members.json
```

## Integration Points

### Ralph Watch Script

The celebrations check should be integrated into Ralph's watch cycle. Add a call to the celebrations check near the **beginning** of each cycle:

```
# In Ralph's watch cycle:
1. [existing checks...]
2. Run Daily Celebrations Check (see ceremony-definition.md)
3. [continue with remaining checks...]
```

### Channel Configuration

Ensure the `wins` channel (or configured celebrations channel) exists in the team's channel routing setup.

## PR Guidelines for Upstream

When submitting this to upstream:

1. **Title:** `feat: Add team celebrations skill — birthdays, anniversaries, milestones`
2. **Description:** Reference this contribution package and explain the privacy model
3. **Labels:** `skill`, `ceremony`, `enhancement`
4. **Reviewers:** Repository maintainers
5. **Testing:** Verify the ceremony definition is parseable and templates render correctly

## Dependencies

This contribution has **no external dependencies**. It uses:
- JSON for data storage
- Markdown for templates and documentation
- Existing Squad infrastructure (Ralph, Neelix, Kes) for execution and delivery

## Privacy Checklist for Upstream Review

Before merging upstream, verify:

- [ ] `members.json` example contains only fake data
- [ ] No real names, dates, or identifiers in any file
- [ ] Birthday format is `MM-DD` only (no year)
- [ ] `optedIn` field defaults to `false` (or absent)
- [ ] No age calculation or display in any template
- [ ] State file (`.celebrations-state.json`) is in `.gitignore`
- [ ] Privacy notice is included in the schema
- [ ] All celebration types respect individual `celebrationPreferences`

---

*Contribute with care — this is about people, not just code.*
