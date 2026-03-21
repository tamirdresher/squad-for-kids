### 2026-03-18T07-52-51Z: User directive — Cross-company issue routing
**By:** Tamir Dresher (via Copilot)
**What:** Each sub-company has its own repo, its own squad, its own GitHub project board, and manages its own backlog/issues there — NOT in the HQ repo. Companies can create issues on EACH OTHER's backlogs (cross-company task routing via GitHub issues). 

Example flows:
- HQ needs content work → creates issue on TechAI Content repo with details
- TechAI Content needs infrastructure → creates issue on HQ repo tagged squad:belanna
- JellyBolt Games needs marketing → creates issue on TechAI Content repo
- Research Institute discovers something actionable → creates issue on the relevant company's repo

This means:
1. Each company's Ralph watches its OWN repo's issues
2. Cross-company work = GitHub issue on the target company's repo
3. No need for cross-machine task YAML files — GitHub issues ARE the coordination mechanism
4. The HQ repo's board tracks HQ-level work only, not sub-company operational work
5. Sub-companies are autonomous — they triage, prioritize, and execute their own backlog

**Why:** Clean separation of concerns. Each company owns its pipeline. GitHub issues are the universal coordination protocol between companies.
