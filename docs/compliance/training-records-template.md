# Training Records Template

## 1. Purpose

This template provides a standardized format for tracking squad member capability assessments. It supports SOC 2 / ISO 27001 evidence requirements by documenting who can do what, when they were last assessed, and who performed the assessment.

## 2. Capability Assessment Register

Use the table below to record each squad member's capabilities. One row per agent-capability combination.

| Agent Name | Capability Area | Proficiency Level | Last Assessment Date | Next Assessment Due | Assessor | Notes |
|------------|----------------|-------------------|---------------------|---------------------|----------|-------|
| @picard | Code review | Expert | 2025-07-01 | 2025-10-01 | Repo owner | Squad lead; final approver for critical changes |
| @data | Code generation | Advanced | 2025-07-01 | 2025-10-01 | @picard | Strong in Python, TypeScript |
| @worf | Security review | Expert | 2025-07-01 | 2025-10-01 | @picard | Owns security-sensitive change approval |
| @belanna | Infrastructure | Advanced | 2025-07-01 | 2025-10-01 | @picard | Terraform, Helm, CI/CD pipelines |
| @copilot | Code generation | Intermediate | 2025-07-01 | 2025-10-01 | @picard | AI agent; bounded by change-control policy |
| | | | | | | |

### Proficiency Levels

| Level | Definition |
|-------|-----------|
| **Beginner** | Can perform tasks with guidance; requires review on all output |
| **Intermediate** | Can perform routine tasks independently; requires review on non-trivial output |
| **Advanced** | Can perform standard and complex tasks independently; peer review recommended |
| **Expert** | Can perform all tasks in the capability area; can review and approve others' work |

## 3. Assessment Criteria by Work Type

### 3.1 Code (Generation and Review)

| Criterion | Beginner | Intermediate | Advanced | Expert |
|-----------|----------|-------------|----------|--------|
| Produces syntactically correct code | ✓ | ✓ | ✓ | ✓ |
| Follows repo coding conventions | — | ✓ | ✓ | ✓ |
| Handles edge cases and error paths | — | — | ✓ | ✓ |
| Identifies security implications | — | — | ✓ | ✓ |
| Can design new modules/services | — | — | — | ✓ |

### 3.2 Documentation

| Criterion | Beginner | Intermediate | Advanced | Expert |
|-----------|----------|-------------|----------|--------|
| Produces clear, grammatically correct prose | ✓ | ✓ | ✓ | ✓ |
| Follows repo doc conventions and templates | — | ✓ | ✓ | ✓ |
| Can write user-facing documentation | — | — | ✓ | ✓ |
| Can author compliance/policy documents | — | — | — | ✓ |

### 3.3 Security

| Criterion | Beginner | Intermediate | Advanced | Expert |
|-----------|----------|-------------|----------|--------|
| Recognizes common vulnerability patterns | ✓ | ✓ | ✓ | ✓ |
| Can remediate OWASP Top 10 issues | — | ✓ | ✓ | ✓ |
| Can perform threat modelling | — | — | ✓ | ✓ |
| Can approve security-sensitive changes | — | — | — | ✓ |

### 3.4 Infrastructure

| Criterion | Beginner | Intermediate | Advanced | Expert |
|-----------|----------|-------------|----------|--------|
| Understands CI/CD pipeline structure | ✓ | ✓ | ✓ | ✓ |
| Can modify existing pipelines safely | — | ✓ | ✓ | ✓ |
| Can provision new cloud resources | — | — | ✓ | ✓ |
| Can design infrastructure architecture | — | — | — | ✓ |

## 4. Quarterly Review Schedule

Assessments are conducted quarterly. The squad lead is responsible for scheduling and completing reviews.

| Quarter | Review Period | Deadline | Reviewer |
|---------|-------------|----------|----------|
| Q1 | Jan 1 – Mar 31 | Apr 15 | Squad lead |
| Q2 | Apr 1 – Jun 30 | Jul 15 | Squad lead |
| Q3 | Jul 1 – Sep 30 | Oct 15 | Squad lead |
| Q4 | Oct 1 – Dec 31 | Jan 15 | Squad lead |

### Review Process

1. Squad lead opens a review issue at the start of each review period
2. Each agent's recent work is sampled (minimum 5 PRs or equivalent)
3. Proficiency levels are updated in the register above
4. The completed register is committed to `docs/compliance/training-records-template.md`
5. The review issue is closed with a link to the commit

## 5. Record Retention

- Current assessment records: Maintained in this file (version-controlled)
- Historical records: Preserved in git history
- Minimum retention period: 3 years (per ISO 27001 clause A.7.2)
