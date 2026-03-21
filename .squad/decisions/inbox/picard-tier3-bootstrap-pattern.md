# Decision: Tier 3 Project Bootstrapping Pattern

**Date:** 2026-03-20  
**Decider:** Picard (Lead)  
**Status:** Accepted  
**Context:** Issue #1156 (KEDA GitHub Copilot Scaler)

## Problem

When creating new open-source projects (Tier 3 complexity), we need a consistent pattern to ensure:
1. Professional quality from day one
2. Open-source compliance (license, conduct, contribution guidelines)
3. Clear documentation for contributors
4. Working code that demonstrates the concept
5. Roadmap for next phases
6. Team handoff with no ambiguity

Without a pattern, Tier 3 projects risk:
- Incomplete documentation (code-only or docs-only)
- Missing open-source artifacts (legal issues)
- Unclear next steps (orphaned repos)
- Poor first impression for external contributors

## Decision

Establish **18-File Minimum Bootstrap Pattern** for all Tier 3 projects (new repositories, microservices, tools).

### Standalone Repository Strategy

- Create new repository outside main project (e.g., `/tmp/keda-github-copilot-scaler`)
- Commit planning doc to main project for tracking (`research/{project}-planning.md`)
- Clear separation: main repo tracks intent, standalone repo is deliverable
- Future: Publish standalone repo to public GitHub, reference from main

### 18-File Bootstrap Checklist

**1. Core Implementation (5 files minimum):**
- Working code with clear structure (e.g., `cmd/`, `pkg/`, `proto/`)
- Mock/stub dependencies where APIs not yet integrated
- Entry point with proper configuration (env vars, flags)
- Dependency management (`go.mod`, `package.json`, etc.)
- `.gitignore` (language-specific, build artifacts)

**2. Infrastructure (4 files minimum):**
- `Dockerfile` (multi-stage for optimization)
- `Makefile` or build script (build, test, lint, docker, clean targets)
- Kubernetes manifests or deployment config (if applicable)
- Example configurations

**3. Documentation — The Quad (4 files minimum):**
- `README.md`: Overview, quick start, configuration reference
- `ARCHITECTURE.md`: System design, components, decisions, diagrams
- `DEVELOPMENT.md`: Local setup, testing, debugging, release process
- `CONTRIBUTING.md`: PR workflow, standards, conventions

**4. Open-Source Artifacts (3 files minimum):**
- `LICENSE` (MIT for permissive, Apache 2.0 for patent protection)
- `CODE_OF_CONDUCT.md` (Contributor Covenant v2.0 standard)
- Initial tests (even 2-3 tests demonstrate testing culture)

**5. Planning Integration (2 files):**
- Planning doc in main repo: `research/{project}-planning.md`
  - Roadmap with phases
  - Risk assessment
  - Next steps and team assignments
  - Success criteria
- Initial commit with descriptive message

### Time Allocation (Tier 3 Bootstrap Session)

- Research: 20% (protocol, API, reference implementations)
- Core implementation: 30% (working code with mocks)
- Documentation: 25% (README, ARCHITECTURE, DEVELOPMENT, CONTRIBUTING)
- Open-source prep: 15% (LICENSE, CODE_OF_CONDUCT, manifests)
- Planning artifact: 10% (roadmap, risks, handoff)

### Success Indicators

- ✅ Repository can be cloned and built locally (even with mocks)
- ✅ Documentation answers "what", "why", "how" for new contributors
- ✅ Clear next steps for Phase 2 (no ambiguity on "what's next")
- ✅ Open-source compliant (license, conduct, contribution guide)
- ✅ Planning doc provides context for team/stakeholders
- ✅ Tests demonstrate testing culture (even if minimal)

## Consequences

### Positive

1. **Professional First Impression**: External contributors see complete, professional project
2. **Legal Compliance**: LICENSE and CODE_OF_CONDUCT from day one
3. **Clear Roadmap**: Planning doc eliminates "what's next" ambiguity
4. **Team Handoff**: Specialized agents (Data, Worf, B'Elanna) have clear Phase 2 tasks
5. **Reusable Pattern**: Scales to any Tier 3 work (microservices, tools, integrations)
6. **Documentation Culture**: Quad docs (README, ARCH, DEV, CONTRIB) become habit

### Negative

1. **Upfront Time**: 18-file bootstrap takes 2-4 hours vs. code-only (30 mins)
2. **Context Switching**: Multiple file types require different mindsets
3. **Maintenance**: Docs must be kept in sync with code evolution

### Mitigations

- Template repositories for common patterns (Go gRPC, Python API, etc.)
- Documentation generation tools where applicable
- Include docs review in PR checklist

## Alternatives Considered

### Alternative 1: Code-Only Bootstrap
Create working code, skip docs and open-source artifacts.

**Rejected because:**
- Poor external contributor experience
- Legal risks (no license)
- Unclear next steps
- Technical debt (docs always "coming later")

### Alternative 2: Docs-Only Bootstrap
Write comprehensive docs, defer code implementation.

**Rejected because:**
- Vaporware perception
- No proof of concept
- Cannot test/validate architecture
- Low contributor confidence

### Alternative 3: Main Repo Integration
Create new project as subdirectory in main repo.

**Rejected because:**
- Pollutes main repo history
- Harder to publish separately
- Less clear ownership
- Dependency conflicts

## Implementation

### Applied in Issue #1156 (KEDA GitHub Copilot Scaler)

**Repository:** `/tmp/keda-github-copilot-scaler`

**Files Created (18):**

1. Core Implementation (6):
   - `cmd/scaler/main.go` (entry point)
   - `pkg/scaler/scaler.go` (gRPC service)
   - `pkg/github/client.go` (API client)
   - `pkg/metrics/metrics.go` (Prometheus)
   - `go.mod` (dependencies)
   - `.gitignore`

2. Infrastructure (4):
   - `Dockerfile`
   - `Makefile`
   - `deploy/deployment.yaml`
   - `examples/scaled-object.yaml`

3. Documentation (4):
   - `README.md` (6.7KB)
   - `docs/ARCHITECTURE.md` (5.3KB)
   - `docs/DEVELOPMENT.md` (4.2KB)
   - `CONTRIBUTING.md` (2.4KB)

4. Open-Source (3):
   - `LICENSE` (MIT)
   - `CODE_OF_CONDUCT.md` (Contributor Covenant)
   - `pkg/scaler/scaler_test.go` (2 tests)

5. Planning (1):
   - `research/keda-copilot-scaler-planning.md` (10KB in main repo)

**Outcome:**
- 18 files, 458 LOC Go, 1,438 total lines
- Professional quality, open-source ready
- Clear Phase 2 roadmap (API integration, testing, security)
- Team handoff to Data, B'Elanna, Worf, Seven

## References

- Issue #1156: KEDA GitHub Copilot Scaler
- Commit: `7ca3947` (keda-github-copilot-scaler repo)
- Commit: `a6120c3` (tamresearch1 planning doc)
- KEDA External Scaler Protocol: https://keda.sh/docs/2.19/scalers/external/
- Contributor Covenant: https://www.contributor-covenant.org/

## Review Date

2026-09-20 (6 months): Assess pattern effectiveness after 3-5 Tier 3 projects
