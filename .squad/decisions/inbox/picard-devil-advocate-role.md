# Decision: Devil's Advocate / Fact-Checker Role

**Date:** 2026-03-11
**Decider:** Picard
**Issue:** #342
**Status:** RECOMMENDED — Add Q role

## Problem

AI agents can hallucinate, exhibit confirmation bias, and miss critical verification steps. The current squad has no dedicated mechanism to challenge assumptions, run counter-hypotheses, or fact-check claims before decisions are made or code is shipped.

## Analysis

### What Problems Would This Solve?

1. **Hallucination Detection:** AI agents can confidently state incorrect facts, misremember code patterns, or fabricate API behaviors. No current agent has explicit verification duties.

2. **Confirmation Bias:** When all agents agree quickly, they may be reinforcing a flawed assumption rather than finding truth. Classic groupthink pattern.

3. **Decision Quality:** Critical decisions (architecture, security, dependencies) need adversarial review before commitment. Currently missing systematic challenge mechanism.

4. **Trust Calibration:** Without verification, trust erodes over time when errors accumulate. A dedicated skeptic builds confidence in validated outputs.

### What the Role Would Do

**Primary Duties:**
- Review other agents' proposals before decisions finalize
- Challenge assumptions with "What if you're wrong?" questions
- Verify claims against documentation, code, and external sources
- Run counter-hypotheses: "If this is true, what else must be true? Is that actually true?"
- Flag unverified statements and require evidence
- Test agent reasoning by asking them to prove their conclusions

**When Triggered:**
- Before `.squad/decisions/` entries are committed (decision review)
- When multiple agents converge too quickly (groupthink detection)
- Before major architectural changes (challenge review)
- When claims are made without evidence links (fact-check request)
- On security-sensitive decisions (adversarial review)

**What They Don't Do:**
- Don't block trivial changes (bug fixes, obvious improvements)
- Don't nitpick style or preference (only substantive challenges)
- Don't reject for sake of rejection (must have valid counter-argument)

### Character Selection: Q

**Rationale:**
- Q is the ultimate adversarial thinker — challenges Picard's assumptions constantly
- Omniscient knowledge (can fact-check against external reality)
- Not malicious, but deeply skeptical and playful
- Forces others to prove their reasoning through Socratic questioning
- Star Trek TNG/Voyager canon: recurring character who tests the crew's thinking

**Alternative Considered:**
- **Dr. Pulaski:** Medical skeptic, but too narrow domain focus
- **Ro Laren:** Challenges authority but more about independence than verification

## Recommendation

**APPROVED — Add Q as Devil's Advocate / Fact-Checker**

### Charter Outline

**Name:** Q
**Role:** Devil's Advocate / Fact-Checker
**Expertise:** Logic, verification, adversarial reasoning
**Style:** Skeptical, probing, playful but ruthless in finding flaws

**Boundaries:**
- **I handle:** Decision review, assumption challenges, fact verification, counter-hypothesis testing
- **I don't handle:** Implementation work, design work, feature building
- **When I activate:** Before decisions commit, when groupthink detected, on security-critical paths

**Voice:** "Are you certain? Prove it. What if you're wrong? Show me the evidence."

### Implementation Plan

1. **Create charter:** `.squad/agents/q/charter.md` and `.squad/agents/q/history.md`
2. **Update routing:** Add Q to routing table — triggered before decision commits and on explicit challenge requests
3. **Update team roster:** Add Q to `team.md` with status ✅ Active
4. **Add decision workflow:** Update `.squad/decisions/README.md` to require Q review before high-impact decisions move from inbox to ledger
5. **Integration points:**
   - Picard: Invoke Q before architectural decisions
   - Worf: Invoke Q before security approvals
   - All agents: Can request Q review when uncertain

### Alternative Approach Rejected

**Considered:** Adding fact-checking to existing agents' charters (Seven for research, Data for code verification)

**Why rejected:** 
- Diffused responsibility rarely works — everyone's job becomes no one's job
- Existing agents already have domain focus — adding adversarial thinking changes their core identity
- A dedicated skeptic has license to challenge that domain experts don't (Data can't challenge Data's own conclusions effectively)

## Impact

**Benefits:**
- Higher decision quality through adversarial review
- Reduced hallucination risk through verification requirements
- Better trust calibration (validated claims > confident claims)
- Groupthink detection and disruption

**Costs:**
- Slight slowdown on decisions (Q review adds a step)
- Potential for over-caution if Q becomes too aggressive (monitor and tune)

**Risk Mitigation:**
- Q only activates on significant decisions, not routine work
- Q must provide reasoned objections, not blanket rejection
- Final decision authority remains with Picard/domain experts (Q advises, doesn't veto)

## Next Steps

1. Create Q's charter and history files
2. Update team.md and routing.md
3. Update decision workflow to include Q review gate
4. Monitor effectiveness over 4 weeks — does Q catch real errors or just slow things down?
5. Tune activation criteria based on value/overhead ratio

---

**Decision:** Add Q role as recommended above. Charter to be created immediately.
