# Cross-Machine Agent Coordination Research

**Date:** 2026-03-14  
**Researcher:** Seven (Research & Docs)  
**Status:** Complete  
**Scope:** Secure communication patterns for Copilot CLI squad agents on distributed machines  

---

## Executive Summary

Squad agents currently run on isolated machines (laptop CPC-tamir-WCBED, Microsoft Dev Box, Azure VMs) with **no direct inter-agent communication**. Tamir manually copy-pastes work between sessions.

This research evaluates **5 approaches** to enable secure, MS-compliant cross-machine coordination. **Recommendation: Hybrid Git + GitHub Issues pattern** — combines simplicity, security, zero new infrastructure, and immediate adoption.

---

## Problem Statement

| Factor | Current State |
|--------|---|
| **Machine A → Machine B Communication** | Manual copy-paste via Teams/chat |
| **Coordination Model** | Synchronous (blocking human) |
| **Discovery Latency** | Hours to days (depends on manual intervention) |
| **Auditability** | None (chat is ephemeral) |
| **Security** | Manual review, prone to credential leaks |

**Impact:**
- GPU workload scheduling loses context (laptop forgets what DevBox was working on)
- Voice cloning batches require manual handoff to Azure
- Ralph watch on each machine cannot coordinate

---

## Approach Comparison

### 1. Git-Based Coordination ✅ RECOMMENDED

**Mechanism:** Agents write task files to `.squad/cross-machine/` directory, commit & push. Other machines pull on next Ralph cycle.

| Aspect | Rating | Details |
|--------|--------|---------|
| **Setup Complexity** | 🟢 Trivial | Uses existing git repo + GitHub Actions |
| **Security** | 🟢 Excellent | Signed commits, PR review, branch protection |
| **MS Compliance** | 🟢 Full | GitHub native, no 3rd party, SOC2 aligned |
| **Real-Time?** | 🟡 Eventual | Depends on Ralph poll interval (5-10 min typical) |
| **Auditability** | 🟢 Excellent | Git log, blame, commit history |
| **Latency** | 🟡 Low (5-10 min) | Depends on polling interval & git push time |
| **Infrastructure Cost** | 💰 Zero | Uses existing repo |
| **Reliability** | 🟢 High | Git guarantees delivery; branch protection ensures validation |
| **Conflict Handling** | 🟡 Manual | File-level conflicts resolved via git |

**Strengths:**
- Already integrated with squad workflow
- No new infrastructure or credentials
- Signed commit trail for compliance audits
- Works offline (queued tasks)
- GitHub Actions can auto-validate task format

**Weaknesses:**
- Polling latency (not instantaneous)
- File naming + format convention needed
- Merge conflicts if both machines write simultaneously

**Implementation Pattern:**
```
Machine A creates: .squad/cross-machine/tasks/{timestamp}-{machine}-{task-id}.yaml
Commits & pushes to origin/main
Machine B Ralph watches: .squad/cross-machine/tasks/ on next pull
Ralph parses, executes, writes: .squad/cross-machine/results/{task-id}.yaml
Machine A Ralph watches: .squad/cross-machine/results/ on next pull
```

---

### 2. Dev Tunnels (Real-Time) 🔄 ALTERNATIVE

**Mechanism:** `devtunnel` CLI (Microsoft tool) exposes a local HTTP API endpoint from one machine to others. Agents POST tasks to the tunnel, GET results.

| Aspect | Rating | Details |
|--------|--------|---------|
| **Setup Complexity** | 🟡 Moderate | Tunnel setup, HTTP API skeleton, auth tokens |
| **Security** | 🟡 Good | MS-managed tunnel encryption, but requires token management |
| **MS Compliance** | 🟢 Full | Dev Tunnels are Microsoft-owned, first-party tool |
| **Real-Time?** | 🟢 Yes | Instant HTTP req/resp |
| **Auditability** | 🟡 Medium | Tunnel logs exist but less visible than git |
| **Latency** | 🟢 <100ms | Network only |
| **Infrastructure Cost** | 💰 Zero | Dev Tunnels are free for personal use |
| **Reliability** | 🟡 Medium | Tunnel must stay open; network outages break sync |
| **Conflict Handling** | 🟢 Simple | Stateless HTTP, no conflicts |

**Strengths:**
- Real-time response
- Microsoft first-party tool
- Stateless (easier to reason about)
- No polling overhead

**Weaknesses:**
- Tunnel daemon must stay running (DevBox RDP session fragile)
- Network interruption breaks coordination
- Limited audit trail
- Extra credential management (tunnel auth tokens)
- Requires HTTP API boilerplate

**Use Case:** Real-time job scheduling (e.g., GPU availability check before submitting workload)

---

### 3. Azure Service Bus / Queue 📦 ENTERPRISE PATTERN

**Mechanism:** Both machines connect to a shared Azure Service Bus queue/topic. Agents publish tasks; consumers poll for work.

| Aspect | Rating | Details |
|--------|--------|---------|
| **Setup Complexity** | 🔴 High | Azure resource provisioning, identity/RBAC, SDK integration |
| **Security** | 🟢 Excellent | Azure RBAC, Managed Identity, encryption at rest/transit |
| **MS Compliance** | 🟢 Full | Azure native, enterprise-grade SLA |
| **Real-Time?** | 🟢 Yes | Push notifications via topics |
| **Auditability** | 🟢 Excellent | Azure Monitor, diagnostic logs, compliance reports |
| **Latency** | 🟢 <100ms | Event-driven |
| **Infrastructure Cost** | 💰 ~$50-200/month | Namespace + messages + storage |
| **Reliability** | 🟢 Excellent | Azure SLA 99.9%+, dead-letter queues, retries |
| **Conflict Handling** | 🟢 Simple | Message de-duplication IDs |

**Strengths:**
- Enterprise-ready
- Scales to many machines
- Built-in monitoring & alerts
- Reliable delivery guarantees
- Role-based access control (RBAC)
- Audit trail at Azure level

**Weaknesses:**
- Overkill for 2-3 machines
- Requires Azure subscription & billing setup
- Learning curve (Service Bus concepts)
- Additional dependency (Azure SDK)
- DevBox RDP session must authenticate to Azure

**Use Case:** Large-scale deployments (5+ machines, 100+ daily tasks)

---

### 4. GitHub Issues as Task Bus ⭐ ALREADY WORKS

**Mechanism:** Create an issue with `squad:machine-{name}` label (e.g., `squad:machine-devbox`). Ralph on each machine filters for its label + reads description. Updates issue with results via comment.

| Aspect | Rating | Details |
|--------|--------|---------|
| **Setup Complexity** | 🟢 Zero | Already supported by Ralph watch |
| **Security** | 🟢 Excellent | GitHub RBAC, signed commits, branch protection |
| **MS Compliance** | 🟢 Full | GitHub native |
| **Real-Time?** | 🟡 Eventual | Polling + GitHub API rate limits |
| **Auditability** | 🟢 Excellent | Issue history, comment timeline, labels |
| **Latency** | 🟡 Low (5-10 min) | Polling + API rate limits |
| **Infrastructure Cost** | 💰 Zero | GitHub API included in subscription |
| **Reliability** | 🟢 High | GitHub uptime SLA, retry-safe |
| **Conflict Handling** | 🟢 Simple | Issue is single source of truth |

**Strengths:**
- Zero additional infrastructure
- Ralph already watches issues
- Visibility in GitHub UI
- Comments = audit trail
- Already integrated in squad workflow

**Weaknesses:**
- Visible in public repo (unless private)
- GitHub API rate limits (60-5000 requests/hour)
- Not optimized for high-frequency messages
- Issue comment threading is verbose for logs

**Use Case:** Ad-hoc cross-machine tasks, sprint planning coordination

---

### 5. OneDrive/SharePoint Shared Folder 📁 CONVENIENCE PATTERN

**Mechanism:** Both machines sync to a shared OneDrive/SharePoint folder. Task files written to `Shared Documents\squad-tasks\` auto-sync via OneDrive client.

| Aspect | Rating | Details |
|--------|--------|---------|
| **Setup Complexity** | 🟢 Trivial | Right-click → Share folder, select sync folder |
| **Security** | 🟡 Good | OneDrive encryption, M365 identity, but sync delay unpredictable |
| **MS Compliance** | 🟢 Full | OneDrive is M365-native, SOC2/FedRAMP available |
| **Real-Time?** | 🟡 Eventual | Sync latency 10-60 seconds, not guaranteed |
| **Auditability** | 🟡 Low | File versioning exists, but limited logs |
| **Latency** | 🟡 Medium (10-60s) | Dependent on OneDrive client behavior |
| **Infrastructure Cost** | 💰 Zero | Included in M365 subscription |
| **Reliability** | 🟡 Medium | Sync can stall, network loss breaks it |
| **Conflict Handling** | 🟡 Risky | OneDrive creates conflicted copies (.conflict) |

**Strengths:**
- Already available on all MS machines
- Easy to set up (drag-and-drop in Explorer)
- Faster than polling-based git
- All squad members can see shared folder

**Weaknesses:**
- **Sync is non-deterministic** — no guarantee file arrives in 5 seconds
- Conflict handling creates duplicate files (not merged)
- No audit trail integration
- Dependent on OneDrive client stability
- Not version-controlled (hard to debug failures)

**Use Case:** Sharing artifacts (logs, screenshots, data files) between machines

---

## Recommendation: Hybrid Approach

### Primary Pattern: Git-Based + GitHub Issues (Layered)

**Philosophy:** Use the tool that fits the task type.

| Task Type | Pattern | Why |
|-----------|---------|-----|
| **Scheduled workload** (GPU jobs, batch processing) | Git `.squad/cross-machine/tasks/` | Survives network outages; audit trail |
| **Ad-hoc request** (urgent debugging, immediate help) | GitHub Issue `squad:machine-{name}` | Already watched by Ralph; visible to team |
| **Result sharing** (logs, artifacts) | OneDrive Shared Folder | Instant sync; no git clutter |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Machine A (laptop CPC-tamir-WCBED)                         │
│  - Ralph watch loop                                          │
│  - Monitors: .squad/cross-machine/tasks/, GitHub issues     │
└────────────────────────┬────────────────────────────────────┘
                         │ Git push/pull
                         │ GitHub API watch
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Repository (source of truth)                        │
│  - .squad/cross-machine/tasks/{id}.yaml                     │
│  - .squad/cross-machine/results/{id}.yaml                   │
│  - Issues with squad:machine-* labels                       │
└────────────────────────┬────────────────────────────────────┘
                         │ Git push/pull
                         │ GitHub API watch
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Machine B (DevBox or Azure VM)                             │
│  - Ralph watch loop                                          │
│  - Monitors: .squad/cross-machine/tasks/, GitHub issues     │
└─────────────────────────────────────────────────────────────┘

Optional: OneDrive Shared Folder for large artifacts
  (doesn't block task coordination)
```

### Why This Hybrid?

1. **Git is primary** because:
   - Scheduled workloads (GPU jobs) need durability (survive RDP disconnect)
   - Audit trail is crucial for compliance
   - Scales to 5+ machines without infrastructure cost
   - Works offline (queued tasks)

2. **GitHub Issues supplement** for:
   - Human-initiated urgent tasks
   - Status updates (already in Ralph watch)
   - Emergency communication (visible to all squad members)

3. **OneDrive fills gaps** for:
   - Large log files, model weights (avoid git LFS)
   - Temporary scratch data (not committed to history)
   - Team-wide artifact sharing

---

## Implementation Sketch (Git-Based + GitHub Issues)

### Phase 1: File Format & Conventions

**Task File Format:** `.squad/cross-machine/tasks/{timestamp}-{source-machine}-{task-id}.yaml`

```yaml
# Example: .squad/cross-machine/tasks/2026-03-14T1530Z-laptop-gpu-voice-clone.yaml
id: gpu-voice-clone-001
source_machine: CPC-tamir-WCBED
target_machine: devbox
priority: high
created_at: 2026-03-14T15:30:00Z
task_type: gpu_workload
payload:
  command: "python scripts/voice-clone.py --input voice.wav --output cloned.wav"
  expected_duration_min: 15
  resources:
    gpu: true
    memory_gb: 8
status: pending
```

**Result File Format:** `.squad/cross-machine/results/{task-id}.yaml`

```yaml
id: gpu-voice-clone-001
target_machine: devbox
completed_at: 2026-03-14T15:45:00Z
status: completed  # completed | failed | timeout
exit_code: 0
stdout: "Voice cloning completed successfully. Output: s3://..."
stderr: ""
artifacts:
  - path: "s3://squad-artifacts/voice-clone-001/output.wav"
    type: audio
    size_mb: 2.5
```

### Phase 2: Ralph Integration

**Ralph Task Watcher (pseudo-code):**

```python
def watch_cross_machine_tasks():
    while True:
        # 1. Fetch all task files for this machine
        tasks = load_yaml_files(".squad/cross-machine/tasks/*-{this_machine}.yaml")
        
        for task in tasks:
            if task.status == "pending" and task.target_machine == HOSTNAME:
                try:
                    # 2. Execute task
                    result = execute_task(task)
                    
                    # 3. Write result
                    write_result(".squad/cross-machine/results/{task.id}.yaml", result)
                    
                    # 4. Git commit & push
                    git_commit(f"Ralph: completed cross-machine task {task.id}")
                    git_push()
                    
                except Exception as e:
                    # Write error result
                    write_result(task.id, error=str(e))
                    git_push()
        
        sleep(POLL_INTERVAL)  # 5-10 minutes
```

### Phase 3: GitHub Issues Pattern

**Ralph Issue Watcher (pseudo-code):**

```python
def watch_github_issues():
    while True:
        # Filter for issues with label squad:machine-{this_machine}
        issues = github_api.list_issues(labels=[f"squad:machine-{HOSTNAME}"])
        
        for issue in issues:
            if issue.state == "open" and not issue_already_processed(issue):
                try:
                    # Parse task from issue body
                    task = parse_task_from_issue(issue)
                    result = execute_task(task)
                    
                    # Comment with result
                    issue.create_comment(format_result(result))
                    issue.close()
                    
                except Exception as e:
                    issue.create_comment(f"❌ Error: {e}")
        
        sleep(POLL_INTERVAL)
```

### Phase 4: Security & Validation

**Pre-execution Validation:**
- Schema validation (YAML structure)
- Command whitelist (prevent arbitrary code execution)
- Resource limits (timeout, CPU, memory)
- Audit log (all executions → git commit)

**Signed Commits:**
- All task/result writes include GPG signature
- Ralph identity is verified
- Tamper detection via commit signature

---

## Migration Path

### Week 1: Setup
- Create `.squad/cross-machine/` structure
- Document file format in `.squad/skills/cross-machine-coordination/SKILL.md`
- Add schema validation to Ralph

### Week 2: Pilot
- Deploy to laptop ↔ DevBox
- Manually trigger 3-5 cross-machine tasks
- Validate round-trip latency, result accuracy

### Week 3: Hardening
- Add error handling (failed tasks, stalled execution)
- Implement timeout logic
- Create monitoring dashboard (task counts, latency)

### Week 4: Adoption
- Document in squad guides
- Train squad members on new pattern
- Retire manual copy-paste workflow

---

## Decision Points for Other Approaches

**When to use Dev Tunnels:**
- Real-time GPU availability checks (latency <100ms critical)
- Live debugging sessions between machines
- Already have on-premises network infrastructure

**When to use Azure Service Bus:**
- 5+ machines coordinating simultaneously
- 1000+ cross-machine tasks/day
- Formal SLA requirements (enterprise customers)

**When to use OneDrive only:**
- Sharing large artifacts (model weights, datasets)
- Non-blocking file distribution
- Team-wide scratch space (not task coordination)

---

## Security Analysis

### Threat Model

| Threat | Git-Based | GitHub Issues | OneDrive |
|--------|-----------|---------------|----------|
| **Unauthorized task injection** | ✅ PR review + branch protection | ✅ Issue creation perms + labels | ❌ Folder permissions only |
| **Credential leakage** | ✅ Pre-commit secret scan | ✅ GitHub secret scanning | ❌ OneDrive logs unencrypted at rest (depends on config) |
| **Man-in-the-middle** | ✅ SSH + signed commits | ✅ HTTPS + GitHub-managed | ✅ HTTPS + M365 encryption |
| **Result tampering** | ✅ Git history + signatures | ✅ Issue timeline immutable | ❌ File overwrite possible |
| **Lateral escalation** | ✅ Command whitelist validation | ✅ Command whitelist validation | ❌ No execution model |

### Compliance Considerations

- **SOC2 Type II:** Git commit audit trail + GitHub Actions logs satisfy compliance
- **FedRAMP (Azure):** If using Azure storage for artifacts, FedRAMP-compliant regions available
- **Data residency:** All data stays within GitHub / M365 (no 3rd party)

---

## Open Questions

1. **Polling Interval Trade-off:** 5 minutes balances latency vs. API rate limits. Should this be configurable?
2. **Task Timeout:** Default 60 minutes for GPU workloads. Should machines report "executing" status?
3. **Result Storage TTL:** How long to keep result files? Archive after 30 days?
4. **Multi-Machine Workflows:** If Machine A → B → C pipeline needed, should Ralph handle serial execution?

---

## Conclusion

**Git-based coordination + GitHub Issues supplement** provides:
- ✅ Zero new infrastructure
- ✅ Enterprise security (signed commits, audit trail)
- ✅ MS compliance (GitHub + M365)
- ✅ Immediate adoption (uses existing Ralph watch)
- ✅ Scalable to 5+ machines

**Recommendation:** Implement Phase 1 (file format + Ralph integration) within 1 sprint. Pilot with laptop ↔ DevBox. Evaluate latency/usability before scaling to Azure.

---

## References

- `.squad/routing.md` — Ralph task routing
- `.squad/agents/ralph/charter.md` — Ralph watch behavior
- GitHub Actions security best practices: https://docs.github.com/en/actions/security-guides
- Dev Tunnels documentation: https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/overview
