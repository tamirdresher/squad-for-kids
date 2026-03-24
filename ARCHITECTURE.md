# Squad for Kids — Architecture Decision Document

**Status:** Proposal  
**Date:** 2026-03-20  
**Author:** Picard (Lead)  
**Decision:** Architecture design for Squad for Kids MVP

---

## Executive Summary

Squad for Kids is a **squad-skills plugin** that provides AI learning teams for children ages 4-17. It's built on the Squad framework but designed specifically for safety, age-appropriateness, and educational outcomes.

**Core Decision:** Build as a **plugin**, not a fork. This keeps Squad for Kids in sync with Squad framework improvements while maintaining specialized safety and pedagogy features.

---

## Architecture Principles

### 1. Safety First
- **Content filtering** at every agent interaction
- **Conversation guardrails** prevent inappropriate topics
- **Parental controls** baked into the platform, not bolted on
- **No data collection** beyond essential progress tracking (COPPA compliant)

### 2. Pedagogy Over Technology
- Age-appropriate language and complexity **enforced by framework**, not agent prompts
- Learning progression based on **mastery**, not time
- Multi-modal learning (text, games, video, projects) as first-class citizens

### 3. Plugin Architecture
- Squad for Kids extends Squad framework via **skills** directory
- Core safety features in `skills/kids-safety/`
- Age-specific templates in `skills/kids-templates/`
- Integration with existing Squad agent charters in `.squad/agents/`

---

## System Design

### Component Architecture

```
squad-for-kids/
├── skills/
│   ├── kids-safety/           # Safety & content filtering layer
│   │   ├── content-filter.ts  # Age-appropriate language & topic filtering
│   │   ├── session-limits.ts  # Time limits, break reminders
│   │   └── parental-gate.ts   # Parent approval for new topics/agents
│   ├── kids-templates/        # Age-specific learning team templates
│   │   ├── dream-team/        # Ages 6-12, English
│   │   ├── creators/          # Ages 8-14, English
│   │   ├── hebrew-friends/    # Ages 6-12, Hebrew
│   │   └── exam-prep/         # Ages 12-18, English
│   ├── kids-study-assistant/  # Homework help, exam tracking
│   │   ├── homework-helper.ts # Socratic questioning, no direct answers
│   │   ├── exam-tracker.ts    # Progress tracking, weak area detection
│   │   └── study-timer.ts     # Pomodoro for kids, break reminders
│   └── kids-gamification/     # XP, badges, streaks
│       ├── xp-system.ts       # Tracks learning milestones
│       ├── badges.ts          # Achievement system
│       └── streak-tracker.ts  # Daily engagement rewards
├── .squad/
│   ├── agents/                # Kid-facing agent charters
│   │   ├── gamer/             # Pixel - game integration & gamification
│   │   ├── youtuber/          # Zephyr - video content & learning media
│   │   └── study-buddy/       # Buddy - homework help & encouragement
│   └── team.md                # Meta-squad (Maria, Ken, Sal, Dr. Sarah, etc.)
└── config/
    ├── age-groups.json        # Language complexity, content rules per age
    ├── content-policy.json    # Topic allowlist/blocklist
    └── safety-rules.json      # Interaction guardrails
```

### Data Flow

```
Child interaction
    ↓
Safety Layer (content filter, session limits, parental gate)
    ↓
Age Adapter (language complexity, interaction style)
    ↓
Learning Agent (Dream Team member, Gamer, Study Buddy, etc.)
    ↓
Skills (gamification, study tracking, homework help)
    ↓
Response (filtered, age-appropriate, pedagogically sound)
```

---

## Technology Stack

### Core Framework
- **Squad Framework** (bradygaster/squad or local variant)
  - Agent coordination, session management, skill loading
  - OTel metrics for usage tracking
  - PlatformAdapter for multi-platform support

### Safety Layer
- **Content Filtering**: OpenAI Moderation API + custom age-appropriate filters
- **Topic Gating**: Parent-approved topic list (configurable per child)
- **Session Management**: Time limits enforced at framework level (not agent discretion)

### Gamification
- **XP System**: Milestone-based (not time-based) rewards
- **Badges**: Achievement definitions in JSON, rendered as emoji/images
- **Streaks**: Daily engagement tracking (encourages consistency)

### Integration Points
- **Existing Games**: Minecraft Education, Roblox Studio, Scratch
  - API integration for Pixel (Gamer) agent
  - No direct game control — guidance and project suggestions only
- **Video Platforms**: YouTube (curated, COPPA-compliant)
  - Zephyr (YouTuber) provides links, scripts, thumbnail analysis
  - No auto-play — parent/child approval required
- **Study Tools**: Existing homework tracking systems
  - Buddy integrates with `kids-study-assistant` skill
  - Exam schedules, weak area tracking, progress reports

---

## Safety Architecture

### Three-Layer Defense

1. **Input Filtering** (before agent sees it)
   - Detect inappropriate language, personal info sharing, unsafe requests
   - Age-specific topic boundaries (e.g., no social media strategy for ages 4-7)

2. **Agent Guardrails** (in agent charter)
   - Agents trained to redirect unsafe topics politely
   - Never provide answers to homework — guide to understanding
   - Positive reinforcement language only (no criticism, shame, or pressure)

3. **Output Filtering** (before child sees it)
   - Double-check age-appropriateness
   - Remove any accidental unsafe content
   - Enforce language complexity limits

### Parental Controls

- **Dashboard**: Weekly progress reports (topics covered, time spent, areas of growth)
- **Topic Approval**: New topics require parent OK (configurable per family)
- **Conversation Review**: Parents can read any conversation (privacy with oversight)
- **Time Limits**: Configurable per day/week, enforced by framework
- **Agent Selection**: Parents approve which agents child can interact with

---

## Age-Specific Adaptations

### Language Complexity

| Age Group | Max Words/Sentence | Vocabulary Level | Special Rules |
|-----------|-------------------|------------------|---------------|
| 4-7 | 8 | Picture book (K-2) | Emoji-heavy, read-aloud friendly, no idioms |
| 8-12 | 15 | Elementary (3-6) | Conversational, multi-step OK, explain idioms |
| 13-17 | 25 | Teen/adult | Peer-level, respects autonomy, no condescension |

### Interaction Style

- **Ages 4-7**: Oral-first, picture-based, games-as-learning, movement breaks every 15 min
- **Ages 8-12**: Project-based, collaborative, Socratic questioning, 20-30 min sessions
- **Ages 13-17**: Self-directed, mastery-based, career-linked motivation, autonomy with guardrails

### Content Rules

- **Ages 4-7**: Educational apps only, no competitive elements, no losing screens
- **Ages 8-12**: Minecraft Education, Scratch, Kahoot, Prodigy Math; XP systems, badges, friendly competition
- **Ages 13-17**: Roblox scripting, Unity basics, game jams, career exploration, standardized test prep

---

## MVP Scope

### Phase 1: Dream Team Template (2 weeks)
**Goal:** Ship one working template with full safety layer

**Deliverables:**
- `skills/kids-safety/` — Content filter, session limits, parental gate
- `skills/kids-templates/dream-team/` — Coach, Story, Explorer, Pixel, Harmony, Buddy agents
- `config/age-groups.json` — Language complexity rules for ages 6-12
- `config/safety-rules.json` — Topic boundaries, interaction guardrails
- Integration with Squad framework skill loader

**Success Criteria:**
- Child can chat with Dream Team agents
- Safety layer blocks inappropriate requests
- Language adapts to age (6 vs 12 year old)
- Session limits enforced (30 min free tier)

### Phase 2: Family Testing (2 weeks)
**Goal:** Real-world validation with Tamir's kids

**Deliverables:**
- Hebrew template (`skills/kids-templates/hebrew-friends/`)
- Parental dashboard (progress reports, conversation review)
- Bug fixes from family testing
- Engagement metrics (session length, return rate, favorite agents)

**Success Criteria:**
- Kids voluntarily return to the platform
- Parents feel safe with content and interactions
- No safety incidents (inappropriate content, harmful interactions)
- Positive feedback on learning outcomes

### Phase 3: Public Launch (4 weeks)
**Goal:** Publish as squad-skills plugin with free tier

**Deliverables:**
- Documentation (setup guide, parent FAQ, safety overview)
- Creators template (ages 8-14)
- Exam Prep template (ages 12-18)
- Free tier enforcement (1 template, 3 agents, 30 min/day)
- Premium tier infrastructure (payment, license management)

**Success Criteria:**
- 100 families using free tier
- 10 premium subscribers
- No safety incidents in first month
- Positive reviews from parents and educators

---

## Deferred Features (Post-MVP)

- **School License Dashboard**: Teacher analytics, curriculum alignment, class-wide progress
- **Voice Interactions**: Text-to-speech for younger kids, speech-to-text for hands-free
- **Mobile App**: Native iOS/Android with offline support
- **Advanced Gamification**: Team challenges, public leaderboards (with parent approval), seasonal events
- **Curriculum Alignment**: Map learning to national standards (Common Core, Israeli Ministry of Education)
- **AI Tutor Orchestration**: Multiple agents working together on complex learning goals
- **Multi-Child Families**: Sibling accounts, shared progress, family challenges

---

## Technical Risks & Mitigations

### Risk 1: Safety Layer Bypass
**Impact:** Child exposed to inappropriate content  
**Likelihood:** Medium (AI agents can be creative)  
**Mitigation:**
- Three-layer defense (input filter + agent guardrails + output filter)
- Regular safety audits by Dr. Sarah (meta-squad agent)
- Parent conversation review as fallback
- Incident reporting system for rapid response

### Risk 2: Engagement Failure
**Impact:** Kids don't return after first session  
**Likelihood:** High (competing with YouTube/TikTok)  
**Mitigation:**
- Family testing before public launch
- Gamification from day 1 (XP, badges, streaks)
- Agent personalities designed for likability (Pixel, Harmony, Buddy)
- Short feedback loops (2-week family testing sprint)

### Risk 3: Age Adaptation Failure
**Impact:** Content too simple/complex for child's actual level  
**Likelihood:** Medium (age is proxy for ability)  
**Mitigation:**
- Language complexity rules per age group
- Mastery-based progression (not time-based)
- Parent override for age settings
- Monitor session transcripts for mismatch signals

### Risk 4: COPPA Compliance
**Impact:** Legal/regulatory issues with child data  
**Likelihood:** Low (architecture designed for compliance)  
**Mitigation:**
- No personal data collection beyond progress tracking
- Parental consent required for account creation
- Data retention policy (auto-delete after 1 year inactivity)
- Legal review before public launch

---

## Success Metrics

### Engagement
- **Return Rate**: >50% of kids return within 7 days
- **Session Length**: Average 20+ min (indicates engagement)
- **Streak Retention**: >30% maintain 7-day streak

### Safety
- **Incident Rate**: Zero inappropriate content exposures
- **Parent Confidence**: >90% feel safe with platform

### Learning Outcomes
- **Parent-Reported Progress**: >70% report learning improvement
- **Mastery Progression**: Kids advance through difficulty levels
- **Subject Coverage**: Average 3+ subjects explored per week

### Business
- **Free→Premium Conversion**: >10% upgrade to premium
- **School License Interest**: 3+ schools request pilot
- **Net Promoter Score**: >60 (indicates word-of-mouth growth)

---

## Alternatives Considered

### Alternative 1: Standalone App (Not Plugin)
**Pros:** Full control, custom UI, mobile-first  
**Cons:** Loses Squad framework updates, higher maintenance cost, slower MVP  
**Decision:** Rejected — Plugin keeps us in sync with Squad innovations

### Alternative 2: Single-Agent Tutor
**Pros:** Simpler architecture, faster MVP  
**Cons:** Less engaging, no personality diversity, harder to cover multiple subjects  
**Decision:** Rejected — Multi-agent team is core value proposition

### Alternative 3: Browser Extension
**Pros:** Easy distribution, works on any site  
**Cons:** Hard to enforce safety on arbitrary websites, limited to web browsing age groups  
**Decision:** Rejected — Need full control of environment for safety

### Alternative 4: Discord Bot
**Pros:** Existing distribution channel, teens already on Discord  
**Cons:** Discord not COPPA-compliant for <13, no parental controls  
**Decision:** Rejected — Can't guarantee safety in Discord environment

---

## Dependencies

### Internal
- Squad framework (local or bradygaster/squad)
- OTel metrics for usage tracking
- PlatformAdapter for GitHub/ADO integration (if used for teacher dashboard)

### External
- OpenAI Moderation API (content filtering)
- Payment processor (Stripe) for premium tier
- Email service (SendGrid) for parent reports

### Team
- **Picard**: Architecture decisions, MVP scoping, risk management
- **Data**: Safety layer implementation, skill plugin development
- **B'Elanna**: Infrastructure setup (if cloud deployment needed)
- **Worf**: Security review, COPPA compliance audit
- **Seven**: Documentation (parent FAQ, setup guide, safety overview)
- **Dr. Sarah (Meta-Squad)**: Safety audits, psychological appropriateness review

---

## Next Steps

### Immediate (This Week)
1. **Tamir Review**: Present this architecture document for approval/feedback
2. **Scope Validation**: Confirm MVP is achievable in 2-week sprint
3. **Risk Assessment**: Does Tamir accept safety risks with proposed mitigations?

### Phase 1 (Weeks 1-2)
1. **Data**: Implement `skills/kids-safety/` layer
2. **Data**: Build Dream Team template in `skills/kids-templates/dream-team/`
3. **Picard**: Create age configuration files (`age-groups.json`, `safety-rules.json`)
4. **Seven**: Write setup documentation and parent FAQ

### Phase 2 (Weeks 3-4)
1. **Data**: Hebrew template for Tamir's kids
2. **Seven**: Parental dashboard design
3. **Family Testing**: Real-world validation with 2-3 families
4. **Iteration**: Bug fixes and engagement improvements

### Phase 3 (Weeks 5-8)
1. **Data**: Additional templates (Creators, Exam Prep)
2. **B'Elanna**: Premium tier infrastructure
3. **Seven**: Public documentation (landing page, marketing copy)
4. **Launch**: Announce in Squad community, education forums

---

## Decision

**Approved:** Pending Tamir review  
**Risk Level:** Medium (safety risks mitigated, engagement risk requires validation)  
**Investment:** 8 weeks MVP + testing, ~40 hours Data + 20 hours other agents  
**Expected Outcome:** Working educational product used by 100+ families within 3 months

**Go/No-Go Criteria:**
- ✅ Safety layer implementation successful
- ✅ Family testing shows engagement (kids return voluntarily)
- ✅ Zero safety incidents in testing phase
- ✅ Parents report positive learning outcomes

If any criterion fails, re-scope or pivot before public launch.

---

**Signed:** Picard (Lead)  
**Date:** 2026-03-20  
**Status:** Awaiting Tamir Approval
