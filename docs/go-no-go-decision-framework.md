# WAF/OPA False Positive Measurement — Go/No-Go Decision Framework

**Owner:** Worf (Security & Cloud)  
**Purpose:** Formal decision framework for sovereign deployment approval  
**Version:** 1.0  
**Last Updated:** 2026-03-08

---

## Executive Summary

This document defines the decision criteria, approval process, and escalation procedures for authorizing WAF/OPA policy deployment to sovereign environments based on false positive measurement results.

**Decision Authority:** Security Leadership / CISO  
**Decision Timeline:** Day 14 (after 10-day measurement + 3-day analysis)  
**Outcome:** GO / NO-GO / CONDITIONAL-GO

---

## Decision Criteria

### Primary Criteria (ALL must pass for GO)

| # | Criterion | Threshold | Measurement Method | Pass/Fail |
|---|-----------|-----------|-------------------|-----------|
| 1 | **WAF False Positive Rate** | < 1.0% | FP_waf / (FP_waf + TP_waf) × 100% | ✅ / ❌ |
| 2 | **OPA False Positive Rate** | < 1.0% | FP_opa / (FP_opa + TP_opa) × 100% | ✅ / ❌ |
| 3 | **Zero False Negatives** | 0 FN | Manual security bypass testing | ✅ / ❌ |
| 4 | **Measurement Completeness** | 100% | All blocked requests classified | ✅ / ❌ |
| 5 | **Tuning Validation** | < 1.0% FP post-tuning | Re-test after tuning (Day 9-10) | ✅ / ❌ |

### Secondary Criteria (Advisory, not blocking)

| # | Criterion | Threshold | Impact if Failed |
|---|-----------|-----------|------------------|
| 6 | **Performance Impact** | p95 latency < 5% increase | Re-evaluate architecture |
| 7 | **Security Confidence** | High (qualitative) | Extended testing period |
| 8 | **Operational Readiness** | Runbook validated | Training sessions required |

---

## Decision Matrix

### Scenario 1: GO (All Primary Criteria Pass)

**Conditions:**
- ✅ WAF FP Rate: 0.6% (< 1.0%)
- ✅ OPA FP Rate: 0.4% (< 1.0%)
- ✅ False Negatives: 0
- ✅ Classification: 100% complete
- ✅ Post-Tuning Validation: 0.5% FP rate
- ✅ Performance: +1.8% p95 latency (< 5%)

**Decision:** **GO for sovereign deployment**

**Deployment Plan:**
1. **Week 3:** Deploy to STG-GOV (5-day validation)
2. **Week 4:** Deploy to PPE-GOV (2-week bake)
3. **Week 6:** Deploy to PROD-GOV
4. **Week 7:** Enable enforcement mode (WAF: Prevention, OPA: Deny)

**Monitoring:**
- Daily FP rate tracking for first 30 days
- Weekly review meetings
- Alerting on FP rate > 2% (revert to dryrun if sustained)

---

### Scenario 2: NO-GO (Any Primary Criterion Fails)

#### 2a. High False Positive Rate (FP ≥ 1.0%)

**Conditions:**
- ❌ WAF FP Rate: 2.3% (≥ 1.0%)
- ✅ OPA FP Rate: 0.4%
- ✅ Other criteria pass

**Decision:** **NO-GO — Extended tuning required**

**Remediation Plan:**
1. **Week 2:** Deep-dive analysis on problematic rules
   - Identify top 5 rules causing FPs
   - Implement rule refinements (regex tightening, exclusions)
   - Document business justification for each exclusion
2. **Week 3-4:** Re-run measurement with tuned policies (10 days)
3. **Week 5:** Re-evaluate go/no-go criteria

**Escalation:** If FP rate > 5%, escalate to CISO for risk acceptance decision

#### 2b. False Negative Detected (Security Bypass)

**Conditions:**
- ❌ False Negatives: 1 security bypass confirmed
- ❌ CRITICAL BLOCKER

**Decision:** **NO-GO — Emergency fix required**

**Remediation Plan:**
1. **Immediate (Day 1):** Analyze bypass technique
2. **Day 2-3:** Implement policy fix
3. **Week 2:** Red team validation (extended adversarial testing)
4. **Week 3-4:** Re-run full measurement cycle
5. **Week 5:** Re-evaluate with external security audit

**Escalation:** Immediate escalation to Security Leadership and CISO

#### 2c. Incomplete Classification (< 100%)

**Conditions:**
- ❌ Classification Completeness: 85% (< 100%)
- ℹ️ 15% of requests unclassified (INCONCLUSIVE)

**Decision:** **NO-GO — Complete classification first**

**Remediation Plan:**
1. **Day 14-15:** Security team completes outstanding classifications
2. **Day 16:** Re-calculate FP rates with complete data
3. **Day 17:** Re-evaluate go/no-go criteria

**Note:** This is a soft blocker — can be resolved quickly without re-measurement

---

### Scenario 3: CONDITIONAL-GO (Borderline Pass with Mitigations)

#### 3a. FP Rate: 1.0% - 1.5% (Slightly Above Target)

**Conditions:**
- ⚠️ WAF FP Rate: 1.2% (slightly above 1.0%)
- ✅ OPA FP Rate: 0.4%
- ✅ All other criteria pass

**Decision:** **CONDITIONAL-GO with enhanced monitoring**

**Mitigations:**
1. Deploy with **24/7 on-call rotation** for first 30 days
2. Enable **real-time FP alerting** (alert if FP rate > 2% in any 24h window)
3. **Weekly tuning reviews** to iteratively reduce FP rate
4. **Automatic revert to dryrun** if FP rate exceeds 3% for > 48 hours
5. **Executive approval** required (CISO or delegate)

**Success Criteria for Permanent Deployment:**
- FP rate reduced to < 1.0% within 60 days
- No P0/P1 incidents caused by policies

#### 3b. Single High-FP Rule (> 5% FP, others < 1%)

**Conditions:**
- ⚠️ WAF Rule "Custom-001" (nginx-injection): 7.2% FP rate
- ✅ All other WAF rules: < 0.5% FP rate
- ✅ OPA policies: < 1.0% FP rate

**Decision:** **CONDITIONAL-GO with rule exception**

**Mitigations:**
1. **Disable Custom-001 rule temporarily** (deploy without it)
2. **Extended tuning** for Custom-001 (Week 3-4)
3. **Phased re-enablement:** Enable in STG-GOV only, validate for 2 weeks, then expand
4. **Compensating control:** Enhanced manual review of related traffic patterns

**Note:** Document risk acceptance — deployment proceeds with reduced protection

#### 3c. Limited Gov Cloud Data (< 100 requests)

**Conditions:**
- ✅ DEV/STG environments: 10,000+ requests, FP rate < 1%
- ⚠️ STG-GOV environment: Only 50 requests (limited traffic)

**Decision:** **CONDITIONAL-GO with extended Gov validation**

**Mitigations:**
1. Deploy to STG-GOV with **extended measurement period** (Day 11-20, 10 additional days)
2. **Synthetic load testing** to generate more traffic volume
3. **Shadow mode deployment** to PROD-GOV (log only, don't block) for 30 days
4. **Weekly review** of Gov-specific patterns

---

## Decision Process

### Timeline

| Day | Milestone | Owner | Deliverable |
|-----|-----------|-------|-------------|
| Day 13 | **Prepare go/no-go brief** | Worf | Executive summary with recommendation |
| Day 14 | **Review with Security Leadership** | Security Team | 30-min decision meeting |
| Day 14 | **Final approval** | CISO / Delegate | Signed approval or rejection |
| Day 15 | **Execute deployment or remediation** | DevOps + SRE | Deployment runbook or tuning plan |

### Decision Meeting Agenda (Day 14)

**Duration:** 30 minutes  
**Attendees:** Security Leadership, CISO (or delegate), DevOps Lead, SRE Lead

**Agenda:**
1. **Measurement Summary (5 min)** — Present 10-day results
   - Total requests inspected: WAF + OPA
   - Classification breakdown: TP / FP / Inconclusive
   - Final FP rates: WAF and OPA
   
2. **Tuning Actions (5 min)** — Explain what was fixed
   - List of rules/policies tuned
   - Before/after FP rates
   - Validation results (Day 9-10)
   
3. **Go/No-Go Assessment (10 min)** — Evaluate criteria
   - Review decision matrix
   - Highlight any failures or conditional passes
   - Recommend GO / NO-GO / CONDITIONAL-GO
   
4. **Risk Discussion (5 min)** — Address concerns
   - Potential business impact of false positives
   - Security risk if policies not deployed
   - Operational readiness for monitoring
   
5. **Decision & Sign-off (5 min)** — Final approval
   - CISO approves or rejects
   - If conditional-go, approve mitigations
   - Document decision in meeting notes

### Approval Documentation

**GO Decision Approval Form:**
```
APPROVAL FOR WAF/OPA SOVEREIGN DEPLOYMENT

Measurement Period: [Start Date] to [End Date]
Measurement Environment: DEV-EUS2, STG-WUS2
Deployment Target: STG-GOV, PPE-GOV, PROD-GOV

Final Metrics:
- WAF False Positive Rate: [X.X%]
- OPA False Positive Rate: [X.X%]
- False Negatives Detected: [N]
- Classification Completeness: [XX%]
- Performance Impact: [+X.X% p95 latency]

Decision: ✅ GO / ❌ NO-GO / ⚠️ CONDITIONAL-GO

Approver: [Name], [Title]
Signature: ___________________
Date: [YYYY-MM-DD]

Conditions (if CONDITIONAL-GO):
- [ ] 24/7 on-call rotation
- [ ] Enhanced monitoring
- [ ] Weekly tuning reviews
- [ ] Other: ______________________
```

---

## Escalation Procedures

### Escalation Triggers

1. **FP Rate > 5%** — Escalate to CISO immediately
2. **False Negative Detected** — Escalate to CISO + Security Incident Response
3. **P0/P1 Incident Caused by Policy** — Escalate to Executive Leadership
4. **Multiple No-Go Cycles (> 2)** — Escalate to CTO for architecture review

### Escalation Path

1. **L1:** Security Engineer (Worf) → Security Team Lead
2. **L2:** Security Team Lead → CISO
3. **L3:** CISO → CTO / Executive Leadership

### Emergency Revert Procedure

**If deployed policy causes P0/P1 incident:**

```bash
# Immediate action (< 5 minutes)
# Revert WAF to Detection mode
az network front-door waf-policy update \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --set policySettings.mode=Detection

# Revert OPA to dryrun mode
kubectl patch config config -n gatekeeper-system \
  --type merge \
  -p '{"spec":{"enforcementAction":"dryrun"}}'

# Notify incident response team
# Document incident in post-mortem
```

---

## Risk Acceptance

### When to Consider Risk Acceptance

**Scenario:** FP rate 1.0% - 2.0% after extensive tuning (> 4 weeks)

**Conditions for Risk Acceptance:**
- Business impact of false positives is low (non-critical services)
- Security risk of not deploying is high (regulatory compliance requirement)
- Compensating controls in place (enhanced monitoring, manual review)
- Executive leadership understands and accepts residual risk

**Risk Acceptance Form:**
```
RISK ACCEPTANCE FOR ELEVATED FALSE POSITIVE RATE

Risk Description:
WAF/OPA policies have FP rate of [X.X%], above target of 1.0%.
This means approximately [N] legitimate requests per day may be blocked.

Business Impact:
- [Service A]: [Impact description]
- [Service B]: [Impact description]

Compensating Controls:
1. [Control 1]
2. [Control 2]
3. [Control 3]

Risk Owner: [Name], [Title]
Acceptance Period: [Start Date] to [Review Date]
Review Frequency: Weekly

Approver: [CISO Name]
Signature: ___________________
Date: [YYYY-MM-DD]
```

---

## Post-Deployment Validation

### 30-Day Monitoring Plan

**Week 1-2:**
- **Daily:** Review FP rate (target: < 1.0%)
- **Daily:** Check for P0/P1 incidents
- **Weekly:** Team review meeting

**Week 3-4:**
- **Every 2 days:** Review FP rate
- **Weekly:** Tuning session if FP rate > 1.5%

**Day 30:**
- **Final validation report:** Confirm sustained FP rate < 1.0%
- **Transition to steady-state monitoring:** Weekly reviews

### Success Criteria (Day 30)

- ✅ FP rate < 1.0% for 30 consecutive days
- ✅ Zero P0/P1 incidents caused by policies
- ✅ Performance impact < 5% p95 latency
- ✅ Operational team trained and confident

**If successful:** Policies remain in enforcement mode indefinitely  
**If failed:** Revert to dryrun mode, re-run measurement cycle

---

## Appendix

### A. Decision History Template

| Date | Measurement Period | WAF FP Rate | OPA FP Rate | Decision | Approver | Notes |
|------|-------------------|-------------|-------------|----------|----------|-------|
| 2026-03-14 | 2026-03-01 to 2026-03-10 | 0.6% | 0.4% | GO | CISO | Initial deployment approved |
| 2026-04-15 | 2026-04-01 to 2026-04-10 | 1.2% | 0.5% | CONDITIONAL-GO | CISO | Enhanced monitoring required |

### B. Contact Information

**Decision Authority:**
- CISO: [Name], [Email]
- Security Leadership: [Name], [Email]

**Operational Contacts:**
- Security Engineer (Worf): [Email]
- DevOps Lead: [Email]
- SRE On-Call: [Pager/Phone]

**Escalation Hotline:** [Phone Number]

---

**END OF DOCUMENT**
