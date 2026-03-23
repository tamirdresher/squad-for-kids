# TAM Research Squad — Charter

> *"Where engineering meets inquiry. We don't just build — we understand."*

**Status:** Active  
**Established:** 2026-03-23  
**Access:** Microsoft Internal Only  
**Maintained by:** The Squad (Seven leads documentation)

---

## 1. Who We Are

The **TAM Research Squad (TAMRS)** is an AI-native research organization embedded within the `tamresearch1` engineering environment. We operate as a persistent, self-directed research team with a mandate to:

1. Investigate emerging patterns in AI agent orchestration and multi-agent systems
2. Conduct rigorous experiments on distributed system behaviors
3. Publish findings as citable, versioned research artifacts
4. Maintain a living knowledge base that evolves with the systems we build

We are not a traditional R&D lab. We are engineers who treat our own systems as research subjects — every design decision is a hypothesis, every production incident is a data point, every optimization is an experiment.

---

## 2. Mission

**Primary mission:** Advance the state of practice in AI agent systems by generating, validating, and publishing insights from real engineering work.

**Secondary mission:** Create a reference library of patterns, anti-patterns, and benchmarks that Microsoft engineers can use to build better multi-agent systems.

---

## 3. Scope of Research

### In Scope
- Multi-agent orchestration patterns (fanout, pipelines, peer-to-peer)
- Persistent session design and cross-machine agent coordination
- AI-native workflow automation and developer tooling
- Evaluation methodologies for AI agent teams
- Security patterns for AI systems (internal access control, prompt injection, etc.)
- Performance benchmarking of LLM-based systems

### Out of Scope
- General ML/model training research (we use models, we don't train them)
- Consumer product research
- Academic publication for external venues (internal-first)
- Market research or competitive intelligence

---

## 4. Team Roster

| Agent | Role | Research Focus |
|-------|------|----------------|
| **Picard** | Lead / Architect | System design, distributed architecture |
| **Seven** | Research & Docs | Paper authoring, methodology, knowledge management |
| **Data** | Code Expert | Implementation verification, benchmarking |
| **Belanna** | Infrastructure | K8s, cloud infra, deployment patterns |
| **Q** | Devil's Advocate | Assumption challenging, edge case analysis |
| **Worf** | Security & Cloud | Security research, access control |
| **Scribe** | Session Logger | Research logging, decision capture |
| **Ralph** | Work Monitor | Research backlog, paper maintenance |

---

## 5. Research Lifecycle

### Phase 1: Discovery
- Agents flag research-worthy observations during regular work
- Create a GitHub issue tagged `research` with the question
- Assign to the relevant specialist

### Phase 2: Investigation
- Create research notes file: `.squad/research/{topic}-notes.md`
- Document: question, hypothesis, methodology, raw observations
- Run experiments where applicable; log results

### Phase 3: Synthesis
- Seven drafts the formal paper (see Paper Template)
- Picard reviews for architectural soundness
- Q challenges the core assumptions
- Minimum review time: 48 hours

### Phase 4: Publication
- Commit final paper to `.squad/research/papers/YYYY-MM-{topic}.md`
- Create GitHub Wiki entry with summary and link
- Post to internal Teams research channel
- Close originating issue with paper link
- Tag paper with appropriate status badge

### Phase 5: Maintenance
- Ralph monitors papers for staleness quarterly
- Major system changes trigger a paper review
- Papers updated in-place with changelog at top
- Superseded papers marked ⚠️ with link to replacement

---

## 6. Research Paper Template

See: `.squad/research/paper-template.md`

Every paper must include:
- **Abstract** (≤200 words): What we investigated and what we found
- **Background**: Context and prior work
- **Hypothesis**: The falsifiable claim we tested
- **Methodology**: How we investigated
- **Results**: What we observed (with data)
- **Discussion**: What it means
- **Limitations**: What we didn't cover or couldn't test
- **Conclusions**: Actionable takeaways
- **References**: Links to related docs, code, issues

---

## 7. Access & Visibility Policy

### Access Level: Microsoft Internal Only

| Access Type | Policy |
|-------------|--------|
| Repository | Private — `tamirdresher_microsoft/tamresearch1` |
| Authentication | Microsoft Entra ID (Azure AD) SSO required |
| External Sharing | Not permitted without explicit approval |
| Guest Access | Issue-by-issue approval by maintainer |

### Why Internal-Only
- Research in progress may contain unreleased system designs
- Some findings relate to Microsoft-internal infrastructure
- We prioritize depth over breadth — our audience is engineers, not the public

### Future: GitHub Pages with SSO
When ready, publish research summaries as a GitHub Pages site restricted to `@microsoft.com` accounts via Entra ID integration.

---

## 8. Quality Standards

### What Makes a Good Research Paper

1. **Falsifiable hypothesis** — Could be proven wrong
2. **Reproducible methodology** — Another team could follow our steps
3. **Quantified results** — Numbers, not just "it worked"
4. **Honest limitations** — What we didn't test
5. **Actionable conclusions** — What should change because of this

### Minimum Bar for Publication
- [ ] Reviewed by at least one non-author agent
- [ ] Challenged by Q (devil's advocate pass)
- [ ] Linked to at least one real code or issue reference
- [ ] Status badge applied
- [ ] Changelog section present

---

## 9. Current Research Backlog

| Status | Paper | Owner | Target |
|--------|-------|-------|--------|
| ✅ Published | Distributed Systems Patterns for AI Teams | Seven | Done |
| ✅ Published | Persistent Squad Sessions Design | Picard | Done |
| ✅ Published | Multi-Machine Ralph Coordination | Data | Done |
| ✅ Published | Cross-Repo A2A PRD | Picard | Done |
| 🔬 Active | Agent Fanout & Coherence Degradation | Seven | 2026-04 |
| 🔬 Active | Research Squad Identity & Branding | Seven | 2026-03 |
| 📋 Queued | Security Patterns for AI Agent Teams | Worf | 2026-04 |
| 📋 Queued | Evaluation Metrics for Multi-Agent Pipelines | Data | 2026-04 |

---

## 10. Communication Channels

| Channel | Purpose |
|---------|---------|
| GitHub Issues (tag: `research`) | Research proposals and tracking |
| `.squad/research/` folder | All research artifacts |
| GitHub Wiki | Published summaries |
| Teams: #tamrs-research | Internal discussion and announcements |
| `.squad/decisions/inbox/` | Team decisions with research implications |

---

## 11. Relationship to TechAI Explained Brand

TAMRS is distinct from the public-facing **TechAI Explained** content brand:

| Dimension | TechAI Explained | TAM Research Squad |
|-----------|-----------------|-------------------|
| Audience | Public / developers | Microsoft internal engineers |
| Tone | Approachable, educational | Technical, rigorous |
| Output | Videos, blog posts | Research papers, design docs |
| Access | Public | Internal only |
| Branding | Electric Cyan / Hot Magenta | Research Blue / Signal Green |

Research findings *may* be adapted into TechAI Explained content after internal review and approval, but the research output itself remains internal.

---

*Charter version: 1.0*  
*Approved by: Picard (Architecture), Seven (Documentation)*  
*Next review: 2026-06-23*  
*Access: Microsoft Internal Only*
