### Decision: DK8S Squad Usage Standard Published

- **Date:** 2025-07-22
- **Author:** Picard (Lead)
- **Status:** Active
- **Issue:** #773

#### Context

Adir requested a clear baseline for Squad adoption across the DK8S Platform team. Without a standard, each engineer's squad would fragment — different labels, different review gates, different decision formats — eliminating the "leverage" benefit of shared tooling.

#### Decision

Published `docs/dk8s-squad-usage-standard.md` as the canonical reference for DK8S Squad usage. Key elements:

1. **Three-level topology:** Org-level (`mtp-microsoft/dk8s-platform-squad`) → Swimlane → Personal squads
2. **Upstream inheritance:** All personal squads `squad upstream add` from org-level squad
3. **Non-overridable policies:** Security review gates, vulnerability scanning, test requirements, decision recording — marked `[ENFORCED]`
4. **Closest-wins for everything else:** Personal preferences (universe, casting, ceremonies) are autonomous
5. **Shared skills catalog:** 6 org-level skills identified for promotion to `dk8s-platform-squad`
6. **Cross-team ownership matrix:** Named owners for vuln management, CI/CD, cleanups, incident response, ConfigGen

#### Consequences

- Every DK8S engineer should create a personal squad and connect upstream
- The org-level squad repo (`mtp-microsoft/dk8s-platform-squad`) needs the shared skills populated
- Swimlane leads need to be identified for platform-core, security-compliance, infrastructure, tooling-dx
- This document should be copied/adapted into the org-level squad repo once reviewed
