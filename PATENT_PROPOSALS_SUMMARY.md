# Patent Proposals — Quick Reference Summary
**Inventor:** Tamir Dresher | **Portal:** https://microsoft-patent.anaqua.com | **Contact:** Pon ArunKumar Ramalingam

---

## Patent 1: Governance-Based Agent Casting
A declarative system for assigning work to AI agents using explicit organizational governance policies (role, seniority, capacity) rather than load-balancing heuristics. Features typed "universes" of agents, overflow handling with upstream throttling signals, dynamic policy mutation with retroactive evaluation of pending assignments, and skill-based casting with learning-mode assignments for junior agents. No existing framework treats agent assignment as a governance/compliance problem. **Co-inventor: Brady Gaster (potential).**

## Patent 2: Character-Cast AI Educational Agent Teams (Squad for Kids)
An AI educational system that dynamically casts learning agents as characters from a child's favorite fictional universe (Harry Potter, Minecraft, Frozen), with framework-enforced age-adaptive communication (vocabulary, sentence length, interaction style per age group), curriculum auto-detection from location/grade, universe-themed gamification (diamond points for Minecraft, snowflakes for Frozen), and a three-layer safety architecture (input filtering, agent guardrails, output filtering). Built on GitHub Copilot infrastructure. No existing educational AI combines character casting with age-adaptive multi-agent teams. **Co-inventor: Brady Gaster (potential).**

## Patent 3: Autonomous Work Queue Monitor (Ralph Pattern)
A continuous monitoring agent that proactively scans work queues (issues, PRs, CI failures) without human prompting, categorizes and prioritizes items, spawns specialist agents, and runs until the queue is clear. Features a three-layer resilience architecture (in-session monitor → local watchdog → cloud heartbeat), behavioral anomaly detection via time-series deviation scoring, and autonomous failure recovery with Git checkpoint restoration. No existing system provides proactive monitoring of AI agent teams with autonomous recovery.

## Patent 4: Git-Native Agent Coordination with Drop-Box Pattern
Uses Git repositories as the coordination backbone for multi-agent teams—commits as state transitions, branches for isolation, PRs for consensus. Introduces a "drop-box" pattern where agents independently append decisions to a shared Git-tracked directory, with a union merge driver for conflict-free parallel writes, worktree-aware multi-agent access, and asynchronous consensus detection via quorum tracking. Provides inherent auditability, version control, and human-readable history without dedicated infrastructure. **Co-inventor: Brady Gaster (potential).**

## Patent 5: Fork-Based Educational Environment Personalization
Uses Git fork mechanics to create personalized learning environments—parents fork an upstream curriculum repo, children's progress is tracked as Git commits, new curriculum content is delivered via upstream sync, and parents monitor progress through Git history. Supports multiple children via separate forks/branches. Eliminates centralized infrastructure, gives learners data ownership, enables offline learning, and provides inherent version control. No existing educational system uses Git forks as personalization infrastructure.

## Patent 6: Autonomous Video Production from Live AI Interactions
An automated pipeline that records live AI multi-agent interactions via CDP + screen capture, auto-detects key moments (team reveals, correct answers, celebrations), generates localized narration via TTS in multiple languages with RTL text handling (Hebrew/Arabic), produces audience-specific variants (child/parent, boy/girl, student/teacher), and assembles final video with timed narration and background music—all without manual editing. No existing system automates the full pipeline from live AI interaction to finished, localized, audience-targeted video.

---

**Filing Priority:** 🔴 Patents 1+3 (strongest novelty) → 🟡 Patent 4 (pending gitclaw analysis) → 🟢 Patents 2+5 (education domain) → 🔵 Patent 6 (broadest applicability)

⚠️ **File before any public disclosure of Squad blog posts to preserve patent rights.**
