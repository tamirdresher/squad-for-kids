# Squad Routing Rules

## Routing Table

| Work Type | Primary Agent(s) | Backup | Context |
|-----------|------------------|--------|---------|
| **Architecture / Cross-functional** | @picard | @seven | Decisions, design docs, triage |
| **Code Implementation** | @data | @scribe | C#, Go, TypeScript, Python |
| **Infrastructure / DevOps** | @belanna | @picard | Kubernetes, cloud, CI/CD |
| **Security / Compliance** | @worf | @picard | Security review, threat modeling |
| **Documentation / Research** | @seven | @data | Technical writing, analysis |
| **Monitoring / Queue** | @ralph | N/A | Autonomous background work |

## Issue Routing via Labels

1. **`squad` label** → Routes to **@picard** for triage and assignment
2. **`squad:{name}` label** → Routes directly to that agent (e.g., `squad:worf` → @worf)
3. **`squad:copilot` label** → Routes to general @copilot (non-specialized work)
4. **No label** → @picard triages and applies appropriate routing

## Lead Triage Guidance (Picard)

When an issue is assigned with `squad` label, evaluate:

1. **Expertise:** Does this require specialized knowledge? (Code → @data, Security → @worf, etc.)
2. **Scope:** Is this cross-functional or isolated? (Cross-functional → @picard keeps it)
3. **Urgency:** Is immediate action required? (P0 → @picard coordinates)
4. **Dependencies:** Does it depend on another agent's work? (Coordinate with that agent)
5. **Learning:** Is this a good opportunity to document a new skill? (Assign to specialist + document)

**Default:** When unclear, @picard handles triage and coordinates.

## Rules

1. **Security changes** always reviewed by @worf
2. **Infrastructure changes** require @belanna review
3. **Decisions affecting all agents** discussed in issue comments before adoption
4. **Research-heavy work** goes to @seven for synthesis
5. **Blocked issues** escalated to @picard for coordination
6. **Documentation updates** routed to @seven
7. **Code reviews** handled by @data (primary) or @worf (security-focused)
8. **Monitoring/automation** owned by @ralph

## Agent Capability Matrix

### @picard (Lead)
- Triage and work assignment
- Cross-functional coordination
- Architectural decisions
- Distributed systems design
- Conflict resolution

### @data (Code Expert)
- Code implementation (C#, Go, TypeScript, Python)
- Unit testing
- Code reviews
- API design
- Performance optimization

### @belanna (Infrastructure)
- Kubernetes / container orchestration
- CI/CD pipelines
- Cloud infrastructure (Azure, AWS, GCP)
- Deployment automation
- Infrastructure as Code

### @seven (Research & Docs)
- Technical documentation
- Research synthesis
- Analysis reports
- Knowledge management
- Training materials

### @worf (Security)
- Security reviews
- Threat modeling
- Compliance validation
- Authentication/authorization
- Secure coding practices

### @ralph (Work Monitor)
- GitHub issue queue monitoring
- PR status tracking
- Project board automation
- Teams/email bridge
- Autonomous work dispatch

### @scribe (Session Logger)
- Session documentation
- Decision capture
- Meeting notes
- Institutional memory
- Silent observer

## Special Cases

### New Agent Onboarding
When a new agent joins:
1. Create charter in `.squad/agents/{name}/charter.md`
2. Add to team roster in `.squad/team.md`
3. Update routing rules here
4. Announce in GitHub issue or Teams

### Agent Unavailable
If an agent is temporarily unavailable:
1. Update status in `.squad/team.md`
2. Route their work to backup agent
3. Document in issue comments

### Escalation Path
When issues are blocked or require human input:
1. Agent comments on issue with `@ProjectOwner` mention
2. Label issue as `pending-user` or `blocked`
3. Move to "Pending User" or "Blocked" column on project board
4. Send Teams notification if urgent
