# ADR-001: DK8S Squad Usage Standard

## Status
Proposed

## Date
2026-03-17

## Context
The DK8S Platform team is adopting Squad (AI agent teams) across multiple engineers and repos. Without a baseline standard, each engineer will implement differently — different task tracking, different prompt structures, different review gates. Adir Atias raised this risk explicitly.

## Decision
Adopt a three-level Squad topology with enforced org-level policies:

1. **Org-Level Squad** ([`mtp-microsoft/dk8s-platform-squad`](https://github.com/mtp-microsoft/dk8s-platform-squad)) — shared decisions, skills, routing rules
2. **Swimlane Squads** — per team area (platform-core, security, infra, tooling) via SubSquads or separate repos
3. **Personal Squads** — per engineer, customized universe, inherits from org via `squad upstream`

### Enforced Standards (non-overridable)
- Label taxonomy: `squad`, `squad:{member}`, `priority:*`, `type:*`
- Three-tier review: SAST → AI review → human (for architecture/security)
- Decision recording in `.squad/decisions.md`
- Security gates always escalate to human
- Cross-team activities have named owners

### Customizable (per engineer)
- Universe/casting (Star Trek, Star Wars, Marvel, etc.)
- Personal ceremonies and workflows
- Additional skills beyond org baseline

## Consequences
### Positive
- Consistent task tracking across all engineers
- Shared skills propagate automatically via upstream
- Cross-team work (vuln management, CI/CD) has clear ownership
- New engineers get baseline Squad setup in < 1 hour

### Negative
- Engineers must adopt standard labels (minor friction)
- Org-level changes require Lead approval (governance overhead)
- Initial setup of org-level squad repo needs investment

### Risks
- Fragmentation if engineers skip `upstream add`
- Org-level skill quality depends on promotion discipline
- Cross-team SubSquad boundaries may need adjustment as team evolves

## References
- [DK8S Squad Usage Standard](../dk8s-squad-usage-standard.md)
- [Blog: Upstream Inheritance (Part 2)](https://www.tamirdresher.com/blog/2026/03/12/scaling-ai-part2-collective)
- [Blog: SubSquads (Part 3)](https://www.tamirdresher.com/blog/2026/03/15/scaling-ai-part3-streams)
- [Distributed Systems Patterns Research](.squad/research/distributed-systems-patterns-for-ai-teams.md)
