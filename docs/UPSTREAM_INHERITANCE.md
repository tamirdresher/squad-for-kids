# Upstream Inheritance from bradygaster/squad

## Overview

This repository (tamresearch1) is a fork/derivative of [bradygaster/squad](https://github.com/bradygaster/squad), a programmable multi-agent runtime for GitHub Copilot. This document defines our upstream inheritance strategy to leverage community improvements while maintaining our custom implementations.

## Upstream Configuration

### Git Remote Setup

The upstream remote has been configured to track bradygaster/squad:

```bash
git remote add upstream https://github.com/bradygaster/squad.git
git fetch upstream
```

Verify remotes:
```bash
git remote -v
# origin    https://github.com/tamirdresher_microsoft/tamresearch1.git (fetch)
# origin    https://github.com/tamirdresher_microsoft/tamresearch1.git (push)
# upstream  https://github.com/bradygaster/squad.git (fetch)
# upstream  https://github.com/bradygaster/squad.git (push)
```

### Current Upstream State

- **Upstream version**: v0.8.25 (as of analysis)
- **Main branches**: `main`, `dev`, `insider`, `insiders`
- **Active feature branches**: Multiple squad/* branches for ongoing work
- **Package structure**: Monorepo with `packages/squad-sdk` and `packages/squad-cli`

## Key Upstream Features & Assets

### 1. **Templates & Scaffolding** (`.squad-templates/`)

Upstream maintains comprehensive templates for squad initialization:

- **Agent templates**: `charter.md`, `history.md`, `squad.agent.md`
- **Workflow templates**: GitHub Actions for CI, docs, heartbeat, label enforcement, preview, release, triage
- **Skill templates**: `skill.md` with structured format for domain knowledge
- **Squad configuration**: `casting-policy.json`, `casting-registry.json`, `ceremonies.md`
- **Documentation templates**: `copilot-instructions.md`, `mcp-config.md`, `multi-agent-format.md`

**Inheritance Strategy**: 
- Compare our `.squad/` structure with upstream `.squad-templates/`
- Cherry-pick new templates as they're added
- Adapt templates to our naming conventions (e.g., we use Picard/Data/Geordi vs. upstream's Apollo 13 theme)

### 2. **Monorepo Package Structure**

Upstream uses a clean monorepo with:
- `packages/squad-sdk/` — Core SDK for multi-agent runtime
- `packages/squad-cli/` — CLI tools (`squad init`, `squad start`, `squad watch`, etc.)

**Our Current State**: 
- We consume `@bradygaster/squad-cli` as a devDependency (v0.8.18)
- We don't have a local packages/ directory

**Inheritance Strategy**:
- Track upstream SDK/CLI releases
- Periodically update our `@bradygaster/squad-cli` dependency
- Consider: Do we need to fork the SDK/CLI for custom modifications?

### 3. **Changesets for Release Management**

Upstream uses `.changeset/` for versioned releases:
- Structured changelog management
- Semantic versioning automation
- Release notes generation

**Inheritance Strategy**:
- Evaluate if we need changeset-based versioning
- If we publish our fork, adopt upstream's release workflow

### 4. **GitHub Workflows**

Upstream has mature CI/CD:
- `squad-ci.yml` — Test suite on PR/push
- `squad-docs.yml` — Documentation build
- `squad-heartbeat.yml` — Health checks
- `squad-insider-release.yml` — Insider builds
- `squad-label-enforce.yml` — Label consistency
- `squad-preview.yml` — Preview deployments
- `squad-publish.yml` — NPM publishing
- `squad-release.yml` — Release automation
- `squad-triage.yml` — Issue triage

**Our Current State**: 
- We have some overlapping workflows (e.g., squad-ci.yml, squad-docs.yml)
- We also have custom workflows (drift-detection, fedramp-validation, squad-daily-digest, squad-issue-notify, squad-main-guard)

**Inheritance Strategy**:
- Merge improvements from upstream workflows
- Retain our enterprise-specific workflows (FedRAMP, drift detection)
- Sync workflow patterns for consistency

### 5. **CLI Commands**

Upstream CLI has grown significantly:
- `squad aspire` — Aspire integration
- `squad build` — Squad build
- `squad consult` — Agent consultation
- `squad copilot-bridge` — Copilot integration
- `squad doctor` — Health diagnostics
- `squad export` / `import` — Squad portability
- `squad init-remote` — Remote initialization
- `squad link` — Linking squads
- `squad migrate` — Migration utilities
- `squad plugin` — Plugin management
- `squad rc` / `rc-tunnel` — Remote control
- `squad start` — Start squad
- `squad streams` — Streaming support
- `squad upstream` — **Upstream management command** (meta!)
- `squad watch` — Watch mode

**Inheritance Strategy**:
- Update our CLI dependency to get new commands
- Document which commands are relevant to our use case
- Create custom commands as needed (e.g., `squad fedramp-check`)

### 6. **SDK Features**

From upstream SDK structure:
- **Adapter system**: `adapter/client.ts`, `adapter/types.ts` (platform abstraction)
- **Casting engine**: Dynamic agent assignment based on skills
- **Charter compilation**: Agent identity system
- **History shadowing**: Agent memory management
- **Model selection**: Multi-model support
- **Onboarding**: New agent onboarding
- **Event bus**: Inter-agent communication
- **Session pooling**: Multi-agent coordination
- **CI/Build system**: `build/ci-pipeline.ts`, `build/release.ts`, `build/versioning.ts`

**Inheritance Strategy**:
- Study upstream SDK architecture
- Identify patterns we should adopt in our custom implementations
- Consider: Should we contribute our Azure DevOps/FedRAMP features back to upstream?

## Upstream Sync Workflow

### Automated Checks

**Recommendation**: Add a GitHub Action to check for upstream updates weekly.

```yaml
# .github/workflows/upstream-sync-check.yml
name: Upstream Sync Check
on:
  schedule:
    - cron: '0 9 * * MON'  # Weekly on Monday 9 AM
  workflow_dispatch:

jobs:
  check-upstream:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Add upstream remote
        run: git remote add upstream https://github.com/bradygaster/squad.git || true
      - name: Fetch upstream
        run: git fetch upstream
      - name: Check for new commits
        run: |
          NEW_COMMITS=$(git log HEAD..upstream/main --oneline | wc -l)
          echo "New upstream commits: $NEW_COMMITS"
          if [ $NEW_COMMITS -gt 0 ]; then
            echo "Upstream has new changes. Consider syncing."
            git log HEAD..upstream/main --oneline --format="%h %s"
          fi
      - name: Create issue if updates exist
        if: steps.check.outputs.has_updates == 'true'
        run: |
          gh issue create \
            --title "Upstream sync available" \
            --label "upstream,squad" \
            --body "New commits detected in bradygaster/squad. Review for inheritance."
```

### Manual Sync Process

When upstream has relevant changes:

1. **Review upstream changes**:
   ```bash
   git fetch upstream
   git log HEAD..upstream/main --oneline
   git log HEAD..upstream/main --stat
   ```

2. **Identify relevant changes**:
   - New templates in `.squad-templates/`
   - Workflow improvements in `.github/workflows/`
   - CLI/SDK version bumps
   - Documentation updates in `docs/`

3. **Cherry-pick or merge selectively**:
   ```bash
   # For specific commits
   git cherry-pick <commit-sha>
   
   # For file-level sync
   git checkout upstream/main -- .squad-templates/skill.md
   git add .squad-templates/skill.md
   git commit -m "sync: inherit skill template from upstream"
   ```

4. **Test locally**:
   ```bash
   npm install
   npm test
   npm run build
   ```

5. **Create PR with upstream sync**:
   ```bash
   git checkout -b squad/upstream-sync-YYYY-MM-DD
   git push origin squad/upstream-sync-YYYY-MM-DD
   gh pr create \
     --title "Sync with upstream bradygaster/squad" \
     --body "Cherry-picked commits: <list>"
   ```

### Merge Strategy

**Selective inheritance, not full merge**:
- We maintain custom implementations (Azure DevOps, FedRAMP, custom agents)
- Upstream is a source of patterns, templates, and feature inspiration
- We cherry-pick specific commits rather than merging branches wholesale

**Merge conflicts**: Resolve in favor of our implementation unless upstream has clear improvements.

## Files Worth Inheriting

Based on comparative analysis, these upstream files are high-value for inheritance:

### High Priority
1. **`.squad-templates/skill.md`** — Skill documentation template (more structured than ours)
2. **`.squad-templates/workflows/squad-ci.yml`** — Improved CI patterns
3. **`.squad-templates/charter.md`** — Agent charter template updates
4. **`.squad-templates/history.md`** — Agent history template updates
5. **`packages/squad-cli/src/cli/commands/doctor.ts`** — Health diagnostics
6. **`packages/squad-cli/src/cli/commands/upstream.ts`** — Upstream management (meta-useful!)
7. **`.github/workflows/squad-heartbeat.yml`** — System health monitoring
8. **`.changeset/config.json`** — Release automation if we publish

### Medium Priority
9. **`.squad-templates/casting-policy.json`** — Dynamic agent assignment rules
10. **`.squad-templates/ceremonies.md`** — Team rituals documentation
11. **`packages/squad-sdk/src/casting/casting-engine.ts`** — Dynamic casting patterns
12. **`.github/workflows/squad-label-enforce.yml`** — Label consistency automation

### Low Priority (Informational)
13. **`docs/` structure** — Documentation site patterns
14. **`samples/` directory** — Example implementations
15. **`test-fixtures/`** — Testing patterns

## Versioning & Compatibility

- **Our current CLI version**: `@bradygaster/squad-cli@^0.8.18`
- **Upstream latest**: v0.8.25
- **Version lag**: 7 patch versions behind

**Action**: Update to v0.8.25 to inherit latest features.

```bash
npm install --save-dev @bradygaster/squad-cli@^0.8.25
npm install
```

## Contributing Back to Upstream

As we develop features (FedRAMP, Azure DevOps, enterprise patterns), consider contributing back:

1. **Generic patterns** → PR to upstream
2. **Enterprise-specific code** → Keep in our fork
3. **Documentation improvements** → PR to upstream
4. **Bug fixes** → Always PR to upstream

See upstream's [CONTRIBUTING.md](https://github.com/bradygaster/squad/blob/main/CONTRIBUTING.md) for contribution guidelines.

## Decision Log

- **2025-01-XX**: Upstream remote configured, inheritance strategy documented
- **Next**: Evaluate adopting `.squad-templates/` structure
- **Future**: Consider full monorepo migration vs. continued consumption model

## Ownership

- **Owner**: Picard (Lead, Architecture)
- **Review cadence**: Monthly upstream review
- **Sync responsibility**: Team rotation (document in `.squad/roster.md`)

---

**Last updated**: 2025-01-06  
**Upstream commit**: c56b2af (v0.8.25)  
**Our branch**: squad/182-upstream-inheritance
