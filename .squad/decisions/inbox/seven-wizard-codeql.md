# Decision: DK8S Wizard CodeQL Compliance & Operational Issues

**Date:** 2026-03-11  
**Author:** Seven (Research & Docs)  
**Context:** Issue #339 follow-up — Ramaprakash's DK8S wizard statement  
**Status:** ⏳ Pending Review

## Summary

Research uncovered two distinct DK8S wizard issues: (1) CodeQL compliance requirement for security scanning, and (2) operational failures due to 1ES Permissions Service migration.

## Background

Tamir asked: "But Ramaprakash said there is something related to the dk8s wizard. What is it? What's the problem?"

This followed previous research on Microsoft.Security.CodeQL.10000 compliance requirement for product PRD-14079533.

## Findings

### 1. CodeQL Compliance Request (Direct Ask)

**Source:** Teams message from Ramaprakash to Tamir  
**Content:** Explicit request to review CodeQL compliance item for DK8S Provisioning Wizard  
**Link:** Same Liquid compliance URL from Issue #339 (PRD-14079533, Microsoft.Security.CodeQL.10000)  
**Action Required:** Enable CodeQL scanning on DK8S wizard repository

### 2. Wizard Operational Issues (Separate Problem)

**Source:** Runtime Platform (DK8S) Teams channel messages  
**Issues Identified:**

a) **1ES Permissions Migration Impact:**
   - Org onboarded to 1ES Permissions Service
   - Broke wizard-initiated PRs, branch creation, pipeline triggers
   - Non-human identities (MI/SP) require new 1ES processes

b) **Managed Identity Attribution:**
   - Wizard uses MI for ADO operations
   - ADO doesn't support On-Behalf-Of flow
   - Actions appear as MI, not initiating user → audit/compliance concerns

c) **Security Architecture Guidance:**
   - Clusters should be scoped to single service tree leaf nodes
   - Rationale: smaller blast radius, granular security boundaries, resilience to re-orgs
   - Current DK8S recommendation (mandatory)

### 3. ADO CodeQL Work Items (Not DK8S)

**Found:** Multiple CodeQL findings for **Microsoft.MDOS.Wizard.V2** (OEM/Fulfillment wizard)  
**Examples:** Work items 60154518, 60218652, 57449597, 60106755  
**Issues:** JsonWebTokenHandler validation disabled, obsolete crypto algorithms  
**Relevance:** Different wizard implementation, not applicable to DK8S wizard

**Note:** No specific CodeQL work items found for DK8S provisioning wizard in ADO search.

## Decision Points

### Action Owners

| Problem Domain | Owner | Reason |
|----------------|-------|--------|
| CodeQL scanning setup | Belanna (Infrastructure) | CI/CD pipeline configuration |
| Wizard 1ES fixes | Ramaprakash + Belanna | DK8S expertise + infra access |
| Service tree scoping | Ramaprakash | Already provided guidance |

### Recommended Actions

**Immediate (Issue #339):**
1. Enable CodeQL scanning on DK8S wizard repository
2. Integrate CodeQL tasks into build pipelines
3. Submit compliance evidence to Liquid portal

**Follow-up (Wizard Operations):**
1. Fix 1ES permission flows for wizard MI
2. Implement proper user attribution for audit trails
3. Validate wizard enforces service-tree-scoped cluster creation
4. Document 1ES migration impacts for future wizard users

## Implications

**For Squad:**
- Research methodology validated: WorkIQ + ADO search + Teams channel analysis
- Cross-tool correlation required to distinguish related but separate issues
- Naming similarity (wizard) doesn't imply same codebase/team

**For DK8S Team:**
- CodeQL compliance is blocking requirement (30-day SLA)
- 1ES migration creates cascading permission failures
- Service tree scoping is security posture, not optional convenience

## Related Decisions

- Decision 16: Knowledge Management Phase 1 (search patterns used here)
- Issue #339: CodeQL.10000 compliance research (foundation)

## Tags

`#research` `#compliance` `#security` `#dk8s` `#codeql` `#1es` `#wizard` `#infrastructure`
