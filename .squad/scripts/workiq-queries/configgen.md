# WorkIQ Query Template — ConfigGen Channel

> Channel: ConfigGen (Teams)
> Signal priority: MEDIUM — Domain-specific configuration generation
> Scan order: 3 (after incidents)

## Query Templates

### Template 1: ConfigGen Updates

```
What was discussed in the ConfigGen channel between {{DATE_FROM}} and {{DATE_TO}}? Include any package updates, breaking changes, version announcements, or migration guidance.
```

### Template 2: Breaking Changes and Issues

```
Were there any breaking changes, build failures, or version conflicts discussed in the ConfigGen channel between {{DATE_FROM}} and {{DATE_TO}}? Include the affected packages, versions, and any workarounds.
```

### Template 3: Decisions and Standards

```
What decisions about ConfigGen usage, version pinning, or migration strategies were discussed in the ConfigGen channel between {{DATE_FROM}} and {{DATE_TO}}?
```

---

## Signal Patterns

| QMD Category | Likelihood | Typical Patterns |
|-------------|-----------|-----------------|
| Decisions | **High** | Version pinning, migration strategy, deprecation choices |
| Pattern Changes | **High** | New package versions, API surface changes, behavior shifts |
| Blockers & Resolutions | **Medium** | Build failures from upgrades, version conflict resolution |
| Commitments | **Low** | Release dates, migration deadlines |
| Contacts & Relationships | **Low** | Package maintainers, ConfigGen team contacts |

## Domain Context

ConfigGen (ConfigurationGeneration.*) is a NuGet package ecosystem used across DK8S projects. Key signals:

- **Version announcements** — New releases, pre-release builds
- **Breaking changes** — API surface changes requiring consumer updates
- **Migration guidance** — Steps to upgrade between major versions
- **Build failures** — Consumer projects broken by updates

## Dedup Notes

- Minimal overlap with other channels (domain-specific)
- Same breaking change may be reported by multiple consumers — dedup by package+version
- Thread discussions about a single version bump should be collapsed into one entry

## Noise Filters

- NuGet feed update notifications
- Automated build status messages
- "Which version should I use?" without a resulting decision
