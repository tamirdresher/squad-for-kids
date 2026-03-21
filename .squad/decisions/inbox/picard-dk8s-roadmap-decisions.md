# Squad × DK8S Integration Roadmap — Architecture Decisions

**Date:** 2026-03-20
**Author:** Picard
**Issue:** #1039

## Decisions Made in Roadmap

### 1. Per-namespace deployment model (Phase 2 start)
Squad deploys one instance per namespace for strong tenant isolation. Revisit shared-Ralph model when tenant count exceeds 10.

### 2. Workload Identity as the auth model
No secrets in pods. All agent authentication goes through Azure Workload Identity + ExternalSecrets for GitHub App tokens. This aligns with DK8S's existing identity posture.

### 3. ADC is a secondary target, not primary
ADC (Agent Dev Compute) is evaluated in parallel via #752 but DK8S Kubernetes is the primary runtime. ADC is suitable for burst/ephemeral tasks; DK8S for persistent agents (Ralph).

### 4. ConfigGen generates Squad configuration
No manual YAML editing. `ConfigurationGeneration.Squad` (proposed package) generates Helm values, routing.md, and team.md from typed C# configuration. This is the right model for a DK8S-native service.

### 5. Ralph runs as a Deployment, all other agents as Jobs
Ralph is the persistent monitor (Deployment). Specialist agents (Picard, Belanna, Worf, Data) are spawned as Kubernetes Jobs on demand, scaled by KEDA based on GitHub issue queue depth.
