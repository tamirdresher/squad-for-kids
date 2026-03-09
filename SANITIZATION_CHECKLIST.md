# Sanitization Checklist - Issue #225

**Branch:** squad/225-sanitized-demo-repo  
**Status:** In Progress  
**Last Updated:** 2026-03-25

## Phase 1: Planning & Analysis ✅

- [x] Analyze repository for sensitive data patterns
- [x] Identify 8 categories of sensitive data
- [x] Document 150+ files requiring sanitization
- [x] Create comprehensive sanitization plan (SANITIZATION_PLAN.md)
- [x] Design automated sanitization script
- [x] Draft public-facing README (DEMO_README.md)
- [x] Create this checklist

## Phase 2: Automated Sanitization 🔄

### Script Execution
- [ ] Run `scripts/sanitize-for-demo.ps1 -DryRun -Verbose`
- [ ] Review dry run output for correctness
- [ ] Execute actual sanitization: `scripts/sanitize-for-demo.ps1`
- [ ] Verify output directory created
- [ ] Validate file count matches expectations

### Pattern Coverage
- [ ] Personal names (Tamir Dresher → Demo User)
- [ ] Usernames (tamirdresher → demo-user)
- [ ] Org names (tamirdresher_microsoft → demo-org)
- [ ] Azure DevOps org (msazure → demo-org)
- [ ] Internal services (DK8S → K8S-Platform)
- [ ] URLs (*.contoso.com → *.example.com)
- [ ] Azure resources (fedramp-* → demo-*)
- [ ] Email addresses (@contoso.com → @example.com)
- [ ] GitHub project IDs (replace with placeholders)
- [ ] Repository names (tamresearch1 → squad-demo)

## Phase 3: Manual Review 🔄

### High Priority Files
- [ ] `.squad/agents/*/charter.md` - Remove personal context
- [ ] `.squad/decisions.md` - Sanitize attributions
- [ ] `.squad/team.md` - Generalize team info
- [ ] `.squad/skills/github-project-board/SKILL.md` - Generic IDs
- [ ] `.squad/skills/teams-monitor/SKILL.md` - Remove webhook refs
- [ ] `ralph-watch.ps1` - Validate sanitization
- [ ] `.github/workflows/squad-issue-notify.yml` - Webhook placeholders
- [ ] `.github/workflows/squad-daily-digest.yml` - Webhook placeholders

### Configuration Files
- [ ] `squad.config.ts` - Clean model config
- [ ] `.copilot/mcp-config.json` - Remove real credentials
- [ ] `.devcontainer/devcontainer.json` - Generic config
- [ ] `package.json` - Clean dependencies

### Documentation Files
- [ ] `README.md` - Replace with DEMO_README.md
- [ ] `docs/cross-squad-orchestration-design.md` - Review refs
- [ ] `docs/UPSTREAM_INHERITANCE.md` - Clean examples
- [ ] All skill README files

### Grep Validation Passes
Run these searches on sanitized output to find remaining sensitive data:

- [ ] `grep -ri "tamirdresher" .` (expect: 0 results)
- [ ] `grep -ri "tamir dresher" .` (expect: 0 results)
- [ ] `grep -ri "contoso" .` (expect: 0 results except examples)
- [ ] `grep -ri "webhook.*office365.com" .` (expect: 0 results)
- [ ] `grep -ri "msazure" .` (expect: 0 results)
- [ ] `grep -ri "dk8s" .` (expect: 0 results, or only K8S-Platform)
- [ ] `grep -ri "azure.com" .` (expect: only generic examples)
- [ ] `grep -ri "PVT_kw" .` (expect: 0 results, should be placeholder)
- [ ] `grep -ri "PVTSSF_" .` (expect: 0 results, should be placeholder)

## Phase 4: File Exclusions ✅

Verify these are NOT in sanitized output:

### Agent Histories (Privacy)
- [ ] `.squad/agents/*/history.md` - EXCLUDED
- [ ] `.squad/identity/now.md` - EXCLUDED
- [ ] `.squad/scripts/workiq-queries/*` - EXCLUDED

### Azure Infrastructure
- [ ] `infrastructure/**/*` - EXCLUDED
- [ ] `.azure-pipelines/**/*` - EXCLUDED
- [ ] `.azuredevops/**/*` - EXCLUDED

### Project-Specific Code
- [ ] `api/**/*` - EXCLUDED
- [ ] `functions/**/*` - EXCLUDED
- [ ] `dashboard-ui/**/*` - EXCLUDED
- [ ] `tests/fedramp-validation/**/*` - EXCLUDED

### Research/Internal Docs
- [ ] `FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md` - EXCLUDED
- [ ] `PATENT_*.md` - EXCLUDED
- [ ] `krishna-review-findings.md` - EXCLUDED
- [ ] `ISSUE_*_SUMMARY.md` - EXCLUDED

### Temporary/State Files
- [ ] `node_modules/` - EXCLUDED
- [ ] `.ralph-watch.lock` - EXCLUDED
- [ ] `.ralph-state.json` - EXCLUDED
- [ ] `.playwright-cli/**/*` - EXCLUDED
- [ ] `cli-tunnel-hub-output-latest.txt` - EXCLUDED
- [ ] `.squad/commit-*.txt` - EXCLUDED

### Training Materials
- [ ] `training/**/*` - EXCLUDED

## Phase 5: Demo Enhancements 🔄

### Required Files
- [ ] Copy `DEMO_README.md` to `README.md` in sanitized output
- [ ] Add `.gitignore` entries for state files
- [ ] Update `LICENSE` file if needed
- [ ] Add `CONTRIBUTING.md` with Squad contribution guidelines
- [ ] Create `.env.example` with placeholder variables

### Documentation Updates
- [ ] Update all skill files with `<YOUR_*>` placeholders
- [ ] Add setup instructions to project board skill
- [ ] Document Teams webhook configuration
- [ ] Explain GitHub Project setup process
- [ ] Add troubleshooting section to README

### Code Comments
- [ ] Add comments to `ralph-watch.ps1` explaining configuration
- [ ] Document `squad.config.ts` options
- [ ] Explain workflow secrets in workflow files

## Phase 6: Testing & Validation 🔄

### Clone & Setup Test
- [ ] Clone sanitized repo to fresh directory
- [ ] Run `npm install` successfully
- [ ] Verify Squad CLI can read configuration
- [ ] Test agent charter loading
- [ ] Validate routing rules parse correctly
- [ ] Check skill files load without errors

### Search Validation
- [ ] No personal information found
- [ ] No webhook URLs found
- [ ] No Azure resource IDs found
- [ ] No internal Microsoft references found
- [ ] All URLs use example.com
- [ ] All IDs are placeholders

### Functional Validation
- [ ] Squad config loads without errors
- [ ] Agent charters are complete and coherent
- [ ] Skills are well-documented
- [ ] Workflows are valid YAML
- [ ] Scripts are executable

## Phase 7: Documentation Quality 🔄

### README.md Quality
- [ ] Clear value proposition ("What is Squad?")
- [ ] Feature showcase with examples
- [ ] Quick start instructions
- [ ] Prerequisites listed
- [ ] Configuration steps documented
- [ ] Repository structure explained
- [ ] Key concepts defined
- [ ] Customization guide included
- [ ] Integration points documented
- [ ] Links to upstream Squad repo

### Skill Documentation
- [ ] All 8 skills have complete SKILL.md files
- [ ] Context section explains when to use
- [ ] Procedure section has step-by-step instructions
- [ ] Examples section shows real usage
- [ ] Limitations documented
- [ ] Placeholders clearly marked

## Phase 8: PR Creation 🔄

### Git Operations
- [ ] Stage all changes: `git add .`
- [ ] Commit with message: `feat: #225 Create sanitization plan and scripts for demo repo`
- [ ] Push branch: `git push -u origin squad/225-sanitized-demo-repo`
- [ ] Open draft PR with `gh pr create`

### PR Content
- [ ] Title: "feat: #225 Create sanitized demo repo plan"
- [ ] Body references issue #225
- [ ] Body explains sanitization approach
- [ ] Body includes checklist summary
- [ ] Body requests review from team
- [ ] Mark as draft initially

## Phase 9: Team Review 🔄

### Review Requests
- [ ] Request review from repository owner
- [ ] Tag relevant team members
- [ ] Link to sanitization plan document
- [ ] Provide test instructions

### Feedback Incorporation
- [ ] Address review comments
- [ ] Update sanitization script based on feedback
- [ ] Re-run sanitization if patterns change
- [ ] Update documentation based on suggestions

## Phase 10: Demo Repository Creation 🔄

### Repository Setup
- [ ] Create new public repository: `demo-org/squad-demo`
- [ ] Copy sanitized files to new repo
- [ ] Initialize git: `git init`
- [ ] Add remote: `git remote add origin <url>`
- [ ] Initial commit: `git add . && git commit -m "Initial commit"`
- [ ] Push: `git push -u origin main`

### Repository Configuration
- [ ] Set repository description
- [ ] Add topics/tags: `ai`, `agents`, `squad`, `automation`
- [ ] Enable Issues
- [ ] Enable Projects
- [ ] Configure branch protection (optional)
- [ ] Add LICENSE file

### Project Board Setup
- [ ] Create Projects V2 board
- [ ] Add Status field
- [ ] Document board configuration in skill

## Phase 11: Upstream Contribution 🔄

### Contribution to bradygaster/squad
- [ ] Review Squad contributing guidelines
- [ ] Identify valuable patterns to contribute
- [ ] Create PR with sanitized examples
- [ ] Share skill documentation
- [ ] Contribute improved README sections
- [ ] Submit documentation improvements

### Community Engagement
- [ ] Share demo repo link in Squad discussions
- [ ] Write blog post about Squad usage patterns
- [ ] Present learnings to team
- [ ] Document advanced patterns discovered

## Success Metrics

### Zero Sensitive Data ✅
- ✅ No personal names, emails, or PII
- ✅ No webhook URLs or secrets
- ✅ No Azure resource IDs
- ✅ No Microsoft internal references

### Complete Documentation ✅
- ✅ Comprehensive README
- ✅ All skills documented
- ✅ Setup instructions clear
- ✅ Examples provided

### Working Demo ✅
- ✅ Can clone and configure independently
- ✅ All configs load successfully
- ✅ Clear path to customization
- ✅ Ready for community use

---

## Notes

**Current Phase:** Phase 1 Complete ✅, Phase 2 Ready to Start

**Next Action:** Execute sanitization script and begin manual review

**Estimated Completion:** 3-5 days

**Blocker Status:** None
