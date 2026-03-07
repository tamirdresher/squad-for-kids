# Research Repository Catalog

Created: 2026-03-07  
Split from: tamresearch1

## Private Research Repositories

### 1. tamresearch1-dk8s-investigations
**Purpose:** Deep-dive research on DK8S platform  
**URL:** https://github.com/tamirdresher_microsoft/tamresearch1-dk8s-investigations  
**Visibility:** Private

**Content:**
- Architecture reports (idk8s-architecture-report.md, idk8s-infrastructure-complete-guide.md)
- Cross-repo analysis (cross-repo-analysis-idk8s-to-baseplatformrp.md)
- Infrastructure inventory (dk8s-infrastructure-inventory.md)
- Aurora adoption research (aurora-adoption-plan.md, aurora-cluster-provisioning-experiment.md, aurora-scenario-catalog.md)
- Fleet manager evaluation (fleet-manager-evaluation.md, fleet-manager-security-analysis.md)
- RP registration guides (rp-registration-guide.md, rp-registration-status.md)
- Platform knowledge (dk8s-platform-knowledge.md, dk8s-stability-analysis.md)
- Workload migration (workload-migration-deep-dive.md)
- Continuous learning design (continuous-learning-design.md)
- Analysis artifacts (aspire-kind-analysis.md, baseplatform-issues.md)
- Screenshots (gap-analysis-*.png)

### 2. tamresearch1-agent-analysis
**Purpose:** Cross-agent investigation reports from squad formation  
**URL:** https://github.com/tamirdresher_microsoft/tamresearch1-agent-analysis  
**Visibility:** Private

**Content:**
- analysis-belanna-infrastructure.md
- analysis-data-code.md
- analysis-picard-architecture.md
- analysis-seven-repohealth.md
- analysis-worf-security.md

### 3. tamresearch1-squadplaces-research
**Purpose:** SquadPlaces API exploration, screenshots, test data  
**URL:** https://github.com/tamirdresher_microsoft/tamresearch1-squadplaces-research  
**Visibility:** Private

**Content:**
- API documentation (api-docs.yaml, api-docs.png, api-artifacts.png, api-post-artifact.png)
- Artifact data (artifact1.json, artifact2.json, artifact3.json, artifact-detail.yaml, artifact-with-comments.md)
- Comment data (comment1.json, comment2.json, comments-after-reply.png, comments-section.png)
- Feed analysis (feed-*.md, feed-*.yaml, feed-*.png, squad-places-feed-*.md)
- Page snapshots (current-page.md, squads-page.yaml, squads-page.png)
- Squad data (squad-detail.png, squad-export.json)
- Screenshots (squadplaces-*.png, star-trek-squad-verify.png)

## Migration Notes

- All files migrated on 2026-03-07
- Markdown and YAML files contain header: `<!-- Moved from tamresearch1 on 2026-03-07 -->`
- Original files removed from tamresearch1
- All three repos are private under tamirdresher_microsoft organization

## Remaining in tamresearch1

- `.squad/` directory (agent configurations, history, decisions)
- `squad.config.ts` (squad configuration)
- `package.json`, `package-lock.json`, `node_modules/` (dependencies)
- `ralph-watch.ps1` (monitoring script)
- Summary files: `EXECUTIVE_SUMMARY.md`, `QUICK_REFERENCE.txt`, `RESEARCH_REPORT.md`
