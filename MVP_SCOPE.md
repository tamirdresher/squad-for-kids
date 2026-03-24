# Squad for Kids — MVP Scope & Timeline

**Goal:** Ship Dream Team template with full safety layer in 2 weeks  
**Success Metric:** Tamir's kids use it voluntarily and safely  
**Decision:** Build minimum viable product first, validate engagement before adding features

---

## Phase 1: Core MVP (2 weeks)

### Week 1: Safety Layer + Agent Framework

**Deliverables:**
- ✅ `skills/kids-safety/content-filter.ts` — Age-appropriate language & topic filtering
- ✅ `skills/kids-safety/session-limits.ts` — 30 min free tier enforcement, break reminders
- ✅ `skills/kids-safety/parental-gate.ts` — Parent approval for new topics
- ✅ `config/age-groups.json` — Language complexity rules (ages 6-12)
- ✅ `config/safety-rules.json` — Topic boundaries, interaction guardrails
- ✅ `config/content-policy.json` — Allowlist/blocklist for topics

**Owner:** Data (Code Expert)  
**Reviewer:** Worf (Security & Cloud) for safety layer audit

**Acceptance Criteria:**
- Content filter blocks inappropriate requests (tested with 20 edge cases)
- Session limits enforce 30 min for free tier (timer visible to child)
- Language adapts correctly (6yo gets 8 words/sentence, 12yo gets 15)
- Parent can approve/reject new topics via simple interface

### Week 2: Dream Team Template

**Deliverables:**
- ✅ `skills/kids-templates/dream-team/coach.md` — Motivational coach, growth mindset language
- ✅ `skills/kids-templates/dream-team/story.md` — Storyteller, reading comprehension, creative writing
- ✅ `skills/kids-templates/dream-team/explorer.md` — Science & nature, curiosity-driven learning
- ✅ `skills/kids-templates/dream-team/pixel.md` — Gamer, Minecraft/Roblox guidance, gamification
- ✅ `skills/kids-templates/dream-team/harmony.md` — Music & art, creative expression
- ✅ `skills/kids-templates/dream-team/buddy.md` — Homework help, emotional support, study skills
- ✅ Integration with Squad framework skill loader
- ✅ Basic documentation (README with setup instructions)

**Owner:** Data (Code Expert)  
**Reviewer:** Dr. Sarah (Meta-Squad) for pedagogical appropriateness

**Acceptance Criteria:**
- All 6 agents respond to child queries with age-appropriate language
- Each agent stays in their domain (Coach doesn't do math, Explorer doesn't do art)
- Agents redirect inappropriate topics politely ("Let's talk about that with your parent")
- Setup takes <10 min for tech-savvy parent

---

## Phase 2: Family Testing (2 weeks)

### Week 3: Hebrew Template + Dashboard

**Deliverables:**
- ✅ `skills/kids-templates/hebrew-friends/` — חברים ללמידה template (6 agents in Hebrew)
- ✅ Parental dashboard mockup (weekly progress report, conversation review)
- ✅ Engagement metrics collection (session length, return rate, favorite agents)
- ✅ Bug tracker for family testing feedback

**Owner:** Data (Hebrew template), Seven (Dashboard design)  
**Reviewer:** Tamir (Language quality)

**Acceptance Criteria:**
- Hebrew agents speak natural Hebrew (not translated English)
- Dashboard shows meaningful progress (subjects covered, time spent, learning milestones)
- Metrics collection works without storing sensitive child data

### Week 4: Testing & Iteration

**Deliverables:**
- ✅ Deploy to Tamir's family (2-3 kids, ages 6-12)
- ✅ Daily check-ins during first week (what worked, what broke, what was boring)
- ✅ Bug fixes and engagement improvements
- ✅ Safety audit (review all conversations for inappropriate content)

**Owner:** Entire Squad  
**Reviewer:** Dr. Sarah (Meta-Squad) for safety audit

**Go/No-Go Criteria:**
- ✅ Kids return to platform without parent prompting (>50% return within 3 days)
- ✅ Zero safety incidents (no inappropriate content generated)
- ✅ Parents feel confident with safety controls
- ✅ At least 1 parent reports learning improvement (even if anecdotal)

**If any criterion fails:** Re-scope, fix critical issues, extend testing phase

---

## Phase 3: Public Launch (4 weeks) — DEFERRED UNTIL PHASE 2 SUCCEEDS

### Week 5-6: Additional Templates
- `skills/kids-templates/creators/` — Ages 8-14 (Director, Coder, Artist, Writer, Builder, DJ)
- `skills/kids-templates/exam-prep/` — Ages 12-18 (Tutor, Quizzer, Motivator, Explainer)
- Free tier enforcement (1 template, 3 agents, 30 min/day)

### Week 7: Premium Infrastructure
- Payment integration (Stripe)
- Premium tier features (all templates, unlimited time, progress reports)
- License management (track subscriptions, enforce limits)

### Week 8: Documentation & Launch
- Setup guide for non-technical parents
- FAQ (safety, pricing, pedagogy)
- Landing page with demo video
- Announcement in Squad community, education forums

**Success Criteria for Launch:**
- 100 families using free tier within first month
- 10 premium subscribers within first month
- No safety incidents reported
- Net Promoter Score >50

---

## Out of Scope (Explicitly Not MVP)

### Deferred to Post-MVP
- Voice interactions (text-to-speech, speech-to-text)
- Mobile app (native iOS/Android)
- School license dashboard (teacher analytics, class-wide progress)
- Advanced gamification (team challenges, public leaderboards)
- Curriculum alignment (Common Core, Israeli Ministry of Education)
- Multi-child family accounts (sibling progress tracking)

### Why These Are Deferred
1. **Voice**: Adds complexity, requires audio processing infrastructure, not core to validation
2. **Mobile App**: Squad framework is CLI-based; mobile requires full rewrite of UX
3. **School License**: B2B sales cycle is long; validate B2C first
4. **Advanced Gamification**: Need engagement data before designing advanced reward systems
5. **Curriculum Alignment**: Time-intensive, not needed for initial parent appeal
6. **Multi-Child**: Edge case for MVP; can add after single-child validation

---

## Resource Allocation

### Data (Code Expert) — 80% Time for 4 Weeks
- Week 1: Safety layer (content filter, session limits, parental gate)
- Week 2: Dream Team template (6 agent charters, Squad integration)
- Week 3: Hebrew template (translation, cultural adaptation)
- Week 4: Bug fixes from family testing

### Picard (Lead) — 20% Time for 4 Weeks
- Week 1: Architecture decisions, age configuration files
- Week 2: Code review, scope management
- Week 3: Family testing coordination
- Week 4: Go/No-Go decision for Phase 3

### Seven (Research & Docs) — 30% Time for 4 Weeks
- Week 1: Research COPPA requirements, safety best practices
- Week 2: Setup documentation, README
- Week 3: Parental dashboard design, progress report templates
- Week 4: Parent FAQ, safety overview

### Worf (Security & Cloud) — 10% Time for 4 Weeks
- Week 1: Safety layer security audit
- Week 4: Final security review before family testing

### Dr. Sarah (Meta-Squad) — 20% Time for 4 Weeks
- Week 2: Agent charter pedagogical review
- Week 4: Conversation safety audit after family testing

### B'Elanna (Infrastructure) — Not Needed for MVP
- Defer until Phase 3 (premium infrastructure, cloud deployment)

---

## Critical Path

```
Week 1: Safety Layer (Data) → BLOCKS Week 2
Week 2: Dream Team Template (Data) → BLOCKS Week 3
Week 3: Hebrew Template (Data) + Dashboard (Seven) → BLOCKS Week 4
Week 4: Family Testing (Squad) → GO/NO-GO for Phase 3
```

**Bottleneck:** Data is critical path for Weeks 1-3. No parallelization possible without compromising quality.

**Risk Mitigation:** Picard can take over documentation or Hebrew translation if Data falls behind. Seven can write agent charters if Data provides framework.

---

## Testing Strategy

### Week 1: Unit Tests
- Content filter catches 20 edge cases (profanity, personal info, unsafe requests)
- Session limits enforce 30 min, warn at 25 min, hard stop at 30 min
- Language complexity rules (6yo: max 8 words/sentence, 12yo: max 15 words/sentence)

### Week 2: Integration Tests
- All 6 agents respond correctly to 10 sample queries per agent
- Agents redirect inappropriate topics to parent
- Squad skill loader loads Dream Team template successfully

### Week 3: System Tests
- End-to-end flow: child starts session → chats with agents → session limit enforced → parent reviews conversation
- Parental dashboard shows correct metrics (time spent, subjects covered)
- Hebrew template renders correctly (no encoding issues)

### Week 4: User Acceptance Testing
- Real kids use the platform with real homework
- Parents review conversations and provide feedback
- Squad reviews metrics and decides Go/No-Go for Phase 3

---

## Validation Criteria

### Must-Have (Go/No-Go)
- ✅ Safety layer blocks inappropriate content (tested with adversarial prompts)
- ✅ Kids voluntarily return to platform (>50% return rate within 3 days)
- ✅ Parents feel safe with content and controls
- ✅ Zero safety incidents in family testing

### Should-Have (Fix Before Launch, Not Blocker)
- Agent responses feel natural and engaging (not robotic)
- Session limits are enforced gracefully (not abrupt cutoffs)
- Dashboard provides meaningful insights (not just raw numbers)
- Hebrew translation is culturally appropriate (not literal translation)

### Nice-to-Have (Post-MVP)
- Kids request new agents or templates
- Parents request premium features (justifies paid tier)
- Agents collaborate (e.g., Coach refers to Explorer for science help)
- Gamification drives return behavior (streaks, badges)

---

## Decision Points

### End of Week 2: Technical Feasibility
**Question:** Can we build the safety layer and Dream Team template in 2 weeks?  
**Decision Maker:** Data (Code Expert) with Picard (Lead) review  
**Options:**
- ✅ Yes → Proceed to Week 3
- ⚠️ Partial → Reduce Dream Team from 6 agents to 3 (Coach, Story, Buddy)
- ❌ No → Extend MVP to 3 weeks, push family testing to Week 4

### End of Week 4: Engagement Validation
**Question:** Do kids actually use this, or is it one-and-done?  
**Decision Maker:** Picard (Lead) with Squad input  
**Options:**
- ✅ Yes (>50% return rate) → Proceed to Phase 3 (public launch)
- ⚠️ Mixed (25-50% return) → Iterate on engagement (gamification, agent personalities) for 2 more weeks
- ❌ No (<25% return) → Pivot or shelve project (not worth public launch investment)

### End of Week 4: Safety Validation
**Question:** Did we expose any child to inappropriate content?  
**Decision Maker:** Worf (Security) with Dr. Sarah (Meta-Squad)  
**Options:**
- ✅ No incidents → Proceed to Phase 3
- ⚠️ Minor incident (caught by parents) → Fix vulnerability, extend testing by 1 week
- ❌ Major incident (child harmed) → Shelve project, full safety redesign required

---

## Success Metrics

### Phase 1 (Week 2)
- Safety layer catches 100% of test cases (20 edge cases)
- Dream Team agents respond correctly to 90%+ of sample queries
- Setup takes <10 min for technical user

### Phase 2 (Week 4)
- >50% return rate within 3 days (engagement)
- Zero safety incidents (safety)
- >70% parent confidence in safety controls (trust)
- ≥1 parent reports learning improvement (efficacy)

### Phase 3 (Week 8) — IF PHASES 1-2 SUCCEED
- 100 families using free tier
- 10 premium subscribers
- Net Promoter Score >50
- Zero safety incidents in first month

---

## Risks & Contingencies

### Risk 1: Safety Layer Failure
**Scenario:** Content filter misses inappropriate content in testing  
**Contingency:** Extend Week 1 by 3 days, add more edge cases, audit OpenAI Moderation API alternatives

### Risk 2: Engagement Failure
**Scenario:** Kids don't return after first session in family testing  
**Contingency:** Rapid iteration on agent personalities, add basic gamification (XP, badges), extend testing by 1 week

### Risk 3: Technical Complexity
**Scenario:** Squad skill plugin architecture doesn't support safety layer integration  
**Contingency:** Fork Squad framework (increases maintenance cost), or simplify safety layer to agent-level guardrails only

### Risk 4: Hebrew Translation Quality
**Scenario:** Hebrew agents feel unnatural or Google-translated  
**Contingency:** Tamir reviews and edits agent charters, or defer Hebrew template to Phase 3

---

## Open Questions for Tamir

1. **Family Testing Scope**: How many kids (2-3?) and for how long (1 week? 2 weeks?)
2. **Hebrew Priority**: Is Hebrew template required for MVP, or can we start with English only?
3. **Premium Tier Timing**: Launch with premium from day 1, or start free and add later?
4. **School License Interest**: Any schools already interested, or focus on B2C first?
5. **Safety Risk Tolerance**: What's acceptable incident rate during family testing? (Recommendation: zero tolerance)
6. **Investment Approval**: 8 weeks total (4 weeks MVP + 4 weeks launch) — approved?

---

**Prepared by:** Picard (Lead)  
**Date:** 2026-03-20  
**Status:** Awaiting Tamir Approval  
**Next Step:** Review with Tamir, answer open questions, get Go/No-Go for Phase 1
