# Sanitization Plan for Squad Demo Repository

**Issue:** #225  
**Branch:** squad/225-sanitized-demo-repo  
**Status:** In Progress  
**Created:** 2026-03-25

## Executive Summary

This document provides a comprehensive plan for creating a clean, public-facing demo repository showcasing Squad capabilities without exposing sensitive data. The sanitization process identifies 150+ files containing sensitive information across 8 categories.

## Sensitive Data Categories

### 1. **Teams Webhook URLs** (HIGH PRIORITY)
**Risk:** Direct access to private Teams channels  
**Occurrences:** 15+ files

- `.github/workflows/squad-issue-notify.yml` - `secrets.TEAMS_WEBHOOK_URL`
- `.github/workflows/squad-daily-digest.yml` - `secrets.TEAMS_WEBHOOK_URL`
- `.squad/skills/teams-monitor/SKILL.md` - References `~\.squad\teams-webhook.url`
- `ralph-watch.ps1` - Line 57: `$teamsWebhookFile`
- `functions/integrations/TeamsClient.cs` - Webhook URL dictionary
- `.squad/scripts/teams-monitor-check.ps1` - Webhook references

**Sanitization Strategy:**
- Replace all webhook URLs with placeholder: `https://contoso.webhook.office.com/webhookb2/EXAMPLE-GUID`
- Update docs to instruct users to configure their own webhook
- Remove any stored webhook files from `.squad/` directory

### 2. **Azure Resource IDs and Subscription Data** (HIGH PRIORITY)
**Risk:** Exposure of Microsoft internal Azure resources  
**Occurrences:** 30+ files

Files containing Azure-specific data:
- `infrastructure/environments/*.parameters.json` (5 files)
  - Contains: CosmosDB names, KeyVault names, resource group names
  - Owner emails: `infrastructure-team@contoso.com`
- `infrastructure/*.bicep` - Azure resource configurations
- `api/FedRampDashboard.Api/appsettings.json` - CosmosDB connection strings
- `.azure-pipelines/*.yml` - Pipeline variable groups
- `.azuredevops/*.yml` - Azure DevOps specific config

**Sanitization Strategy:**
- Replace all Azure resource names with generic examples:
  - `fedramp-dashboard-dev` → `demo-dashboard-dev`
  - KeyVault: `fedramp-kv-dev` → `demo-kv-dev`
  - Storage: `fedrampstodev` → `demostoragedev`
- Remove subscription IDs entirely
- Replace owner emails with `team@example.com`
- Add comments indicating these are example values

### 3. **Personal Information** (HIGH PRIORITY)
**Risk:** Privacy violation, PII exposure  
**Occurrences:** 100+ files

Names found:
- "Tamir Dresher" - Repository owner
- "tamirdresher" - GitHub username
- "tamirdresher_microsoft" - Organization name
- Email references in agent histories

Files affected:
- `.squad/agents/*/history.md` (6 agent files)
- `.squad/decisions.md` - Attribution in decision headers
- `.squad/team.md` - Team roster
- `.squad/identity/now.md` - User context
- `.squad/skills/github-project-board/SKILL.md` - Project owner references
- `.squad/upstream.json` - Repository URLs
- Multiple docs with "Owner: Tamir" metadata

**Sanitization Strategy:**
- Replace "Tamir Dresher" → "Demo User"
- Replace "tamirdresher" → "demo-user"
- Replace "tamirdresher_microsoft" → "demo-org"
- Replace personal emails with `user@example.com`
- Generalize agent history learnings to remove personal references
- Update GitHub Project board references to generic format

### 4. **Internal Microsoft References** (MEDIUM PRIORITY)
**Risk:** Exposure of internal team structure and processes  
**Occurrences:** 50+ files

References found:
- "idk8s-infrastructure" - Internal Microsoft Kubernetes platform
- "DK8S" - Defender Kubernetes Service
- "Aurora" - Internal service name
- "msazure" Azure DevOps organization
- Internal service trees and team structures
- Microsoft-specific security controls (FedRAMP specific)

Files affected:
- `docs/dk8s-*.md` - Multiple DK8S documentation files
- `.squad/research-repos.md` - Internal repo references
- `FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md`
- Agent histories referencing internal services
- `.copilot/mcp-config.json` - Azure DevOps org "msazure"

**Sanitization Strategy:**
- Replace "DK8S" → "K8S-Platform" or "Demo-K8S"
- Replace "idk8s-infrastructure" → "platform-infrastructure"
- Replace "Aurora" → "Service-A"
- Replace "msazure" → "demo-org"
- Generalize FedRAMP references to "Compliance Dashboard"
- Remove specific Microsoft security control mappings

### 5. **API Keys and Tokens** (HIGH PRIORITY)
**Risk:** Direct security breach  
**Occurrences:** 8+ files

Found in:
- `.copilot/mcp-config.json` - Trello example with token placeholders
- GitHub workflow secrets references (not actual values, but usage patterns)
- `api/FedRampDashboard.Api/appsettings.json` - Connection string patterns

**Current Status:** ✅ Most are already using `${{ secrets.* }}` pattern  
**Action Required:** Validate no hardcoded tokens exist

**Sanitization Strategy:**
- Grep for patterns: `token`, `key`, `password`, `secret`, `api_key`
- Replace any found values with `<YOUR_TOKEN_HERE>`
- Ensure all workflows use GitHub secrets pattern
- Add security scanning recommendation to README

### 6. **Internal URLs and Endpoints** (MEDIUM PRIORITY)
**Risk:** Exposure of internal infrastructure topology  
**Occurrences:** 20+ files

Found:
- `functions/integrations/TeamsClient.cs` - `https://fedramp-dashboard.contoso.com`
- `dashboard-ui/src/services/api.service.ts` - API endpoints
- `.devcontainer/README.md` - Internal devbox URLs
- `cli-tunnel-hub-output-latest.txt` - Tunnel endpoints

**Sanitization Strategy:**
- Replace all `*.contoso.com` with `*.example.com`
- Replace internal service URLs with `https://api.example.com/v1`
- Remove tunnel output logs or sanitize endpoints
- Update DevBox references to generic cloud dev environment

### 7. **GitHub Organization/Project Specific Data** (MEDIUM PRIORITY)
**Risk:** Exposure of internal project structure  
**Occurrences:** 15+ files

Found:
- Project board IDs: `PVT_kwHOC0L5c84BRG-P`
- Field IDs: `PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc`
- Repository: `tamirdresher_microsoft/tamresearch1`
- Workflow references to self-hosted runners

Files affected:
- `.squad/skills/github-project-board/SKILL.md`
- `.github/workflows/*.yml` (19 workflow files)
- `.squad/upstream.json`

**Sanitization Strategy:**
- Replace project/field IDs with `<YOUR_PROJECT_ID>` placeholders
- Update skill documentation with instructions to obtain IDs
- Change `self-hosted` runners to `ubuntu-latest`
- Replace repo references with `demo-org/squad-demo`

### 8. **Work Artifacts and Debug Logs** (LOW PRIORITY)
**Risk:** Information leakage through logs and temporary files  
**Occurrences:** 20+ files

Found:
- `.ralph-watch.lock` - Runtime state
- `.ralph-state.json` - Session state
- `.playwright-cli/*.log` - Browser automation logs
- `cli-tunnel-hub-output-latest.txt` - Debug output
- `.squad/commit-*.txt` - Draft commit messages

**Sanitization Strategy:**
- Exclude from demo repo via `.gitignore` updates
- Delete all `.log`, `.lock`, `.state.json` files
- Remove `cli-tunnel-hub-output-latest.txt`
- Clean up temporary commit message files

## Files to Include in Demo Repo

### Core Squad Infrastructure ✅
- `.squad/` directory (sanitized)
  - `agents/*/charter.md` (remove history.md to protect privacy)
  - `decisions.md` (sanitized)
  - `team.md` (generalized)
  - `routing.md`
  - `schedule.json`
  - `upstream.json` (sanitized)
  - `skills/**/SKILL.md` (all skills, sanitized)

### Ralph Watch System ✅
- `ralph-watch.ps1` (sanitized)
- Documentation on Ralph's capabilities

### Podcaster Feature ✅
- `PODCASTER_README.md`
- `.squad/research/214-podcaster-tts-analysis.md` (sanitized)
- `.squad/skills/tts-conversion/SKILL.md`

### GitHub Workflows ✅ (Sanitized)
- `.github/workflows/squad-*.yml` (all Squad workflows)
- `.github/agents/squad.agent.md`

### Documentation ✅
- `README.md` (NEW: public-facing demo README)
- `docs/cross-squad-orchestration-design.md`
- `docs/UPSTREAM_INHERITANCE.md`
- Select docs showing Squad patterns

### Configuration Files ✅
- `squad.config.ts` (sanitized)
- `.devcontainer/devcontainer.json` (sanitized)
- `package.json` (cleaned)

### Screenshots ✅
- `devbox-*.png` (10 screenshots showing Squad in action)
- `github-app-creation-login.png`

## Files to Exclude from Demo Repo

### Excluded: Private/Internal Content ❌
- `.squad/agents/*/history.md` - Contains personal work history
- `.squad/identity/now.md` - User-specific context
- `.squad/scripts/workiq-queries/*.md` - Microsoft WorkIQ queries
- `.squad/.gitignore-rules.md` - Internal conventions

### Excluded: Azure/Infrastructure ❌
- `infrastructure/` - All Azure Bicep templates (too Microsoft-specific)
- `.azure-pipelines/` - Azure DevOps pipelines
- `.azuredevops/` - Azure DevOps config

### Excluded: Project-Specific Code ❌
- `api/` - FedRAMP Dashboard API (not Squad-related)
- `functions/` - Azure Functions (not Squad-related)
- `dashboard-ui/` - React dashboard (not Squad-related)
- `tests/fedramp-validation/` - Internal compliance tests

### Excluded: Research/Internal Docs ❌
- `FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md`
- `PATENT_*.md` - Patent research (personal/confidential)
- `krishna-review-findings.md` - Internal review
- `ISSUE_*_SUMMARY.md` - Issue-specific summaries
- Research reports not related to Squad itself

### Excluded: Temporary/State Files ❌
- `node_modules/`
- `.ralph-watch.lock`
- `.ralph-state.json`
- `.playwright-cli/` logs
- `cli-tunnel-hub-output-latest.txt`

### Excluded: Training Materials ❌
- `training/` - Internal training content

## Sanitization Implementation Plan

### Phase 1: Automated Sanitization Script ✅ (Current Task)
**Script:** `scripts/sanitize-for-demo.ps1`

```powershell
# Automated find-and-replace patterns
$replacements = @(
    @{ Pattern = 'tamirdresher_microsoft'; Replacement = 'demo-org' }
    @{ Pattern = 'tamirdresher'; Replacement = 'demo-user' }
    @{ Pattern = 'Tamir Dresher'; Replacement = 'Demo User' }
    @{ Pattern = 'tamir@.*'; Replacement = 'user@example.com' }
    @{ Pattern = 'https://.*\.contoso\.com'; Replacement = 'https://api.example.com' }
    @{ Pattern = 'msazure'; Replacement = 'demo-org' }
    @{ Pattern = 'DK8S'; Replacement = 'K8S-Platform' }
    @{ Pattern = 'idk8s'; Replacement = 'platform-k8s' }
    # ... more patterns
)
```

### Phase 2: Manual Review Checklist ✅
- [ ] Review all `.squad/agents/*/charter.md` for personal info
- [ ] Validate no webhook URLs in workflows
- [ ] Check all `.json` and `.yml` for Azure resource IDs
- [ ] Verify GitHub project IDs replaced with placeholders
- [ ] Review all markdown docs for internal references
- [ ] Check code files for hardcoded secrets
- [ ] Validate all URLs sanitized

### Phase 3: Create Public README ✅
**File:** `README.md` (public-facing)

Contents:
- What is Squad?
- Key features showcase
- Architecture overview
- Getting started guide
- How to configure (webhooks, GitHub projects, etc.)
- Link to bradygaster/squad upstream
- Contribution guidelines
- License

### Phase 4: Testing & Validation ✅
- [ ] Clone sanitized repo to fresh directory
- [ ] Search for: `tamirdresher`, `Tamir`, `contoso`, `msazure`, `webhook`, `azure`
- [ ] Verify no personal data remains
- [ ] Test that configs are genericized
- [ ] Validate README is comprehensive

### Phase 5: Upstream Contribution ✅
- [ ] Create PR to bradygaster/squad with sanitized examples
- [ ] Share learnings about Squad patterns
- [ ] Contribute improved documentation

## Risk Assessment

| Category | Risk Level | Mitigation |
|----------|-----------|------------|
| Teams Webhooks | 🔴 CRITICAL | Full removal + placeholder docs |
| Azure Resource IDs | 🟡 HIGH | Replace with generic examples |
| Personal Info (PII) | 🔴 CRITICAL | Comprehensive find-replace + manual review |
| Internal MS References | 🟡 MEDIUM | Genericize to "Demo" equivalents |
| API Keys/Tokens | 🟢 LOW | Already using secrets pattern |
| Internal URLs | 🟡 MEDIUM | Replace with example.com |
| GitHub Org Data | 🟡 MEDIUM | Placeholder IDs + documentation |
| Debug Logs | 🟢 LOW | Exclude via .gitignore |

## Success Criteria

✅ **Zero PII**: No personal names, emails, or identifiable information  
✅ **Zero Secrets**: No webhooks, tokens, keys, or credentials  
✅ **Zero Internal Refs**: No Microsoft-internal service names or infrastructure  
✅ **Comprehensive README**: Clear setup instructions for new users  
✅ **Working Example**: Demo repo can be cloned and configured independently  
✅ **Upstream Ready**: Can contribute back to bradygaster/squad  

## Timeline

- **Day 1** (Today): Sanitization plan + automated script ✅
- **Day 2**: Execute sanitization + manual review
- **Day 3**: Create public README + test validation
- **Day 4**: Create demo repository + open PR
- **Day 5**: Community review + upstream contribution

## Next Steps

1. ✅ Create `scripts/sanitize-for-demo.ps1` - Automated sanitization
2. ⏳ Execute script on branch `squad/225-sanitized-demo-repo`
3. ⏳ Manual review pass for edge cases
4. ⏳ Draft public-facing `README.md`
5. ⏳ Open draft PR for team review
6. ⏳ Create clean demo repository after approval

---

**Note:** This sanitization plan is tracked in Issue #225. All work happens on branch `squad/225-sanitized-demo-repo`.
