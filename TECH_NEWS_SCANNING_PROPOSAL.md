# Tech News Scanning Proposal — Issue #255

## TLDR
Implement a daily tech news scanning pipeline that monitors HackerNews (top/top-24h), Reddit (r/programming, r/devops, r/kubernetes), and X/Twitter trending for dev topics. Deliver via GitHub issues, Teams alerts, and optional Hebrew podcast. Runs nightly via GitHub Actions cron + ralph-watch fallback. Estimated MVP: 1-2 weeks.

---

## Background Research

**What Was Done Before:**
- ✅ Daily status briefing infrastructure exists: `scripts/daily-rp-briefing.ps1` (fetches GitHub PRs/issues via `gh CLI`, formats Teams Adaptive Cards, scheduling via ralph-watch)
- ✅ Podcaster agent ready: `scripts/podcaster.ps1` (Markdown → MP3 via edge-tts or Windows TTS; supports 45+ languages including Hebrew)
- ✅ ralph-watch.ps1 scheduler: Runs periodic tasks via 5-minute watch loop
- ❌ **No HackerNews/Reddit scanning code found** in `/scripts` or codebase
- ❌ **No scheduled news aggregation** currently running

**Relevant Infrastructure:**
- GitHub CLI integration (proven, working)
- Teams webhook delivery (proven, working)
- Podcaster TTS (proven, working; supports Hebrew via edge-tts `he-IL-HilaNeural` voice)
- Scheduling patterns (ralph-watch, GitHub Actions cron tested)

---

## Proposed Solution: Three-Phase Tech News Scanning

### **Phase 1: MVP (Week 1-2)**

**What It Does:**
- Daily 6:00 AM scan of:
  - **HackerNews**: Top 30 stories + top 24h stories (API: `hn.algolia.com/api/v1`)
  - **Reddit**: Hot/top posts from r/programming, r/devops, r/kubernetes, r/cloudnative
  - **X/Twitter**: Trending #dev, #devops, #kubernetes hashtags (via free tier or `posts` search)
- Filters: Min 50+ points/upvotes, relevant keywords (kubernetes, cloud, security, AI/ML, DevOps)
- Deliverables:
  - 📝 GitHub issue comment with curated daily digest (10-15 top stories)
  - 🔔 Teams alert with summary + links
  - Optional: Markdown file in repo for historical reference

**Scripts to Create:**
```
scripts/tech-news-scanner.ps1          # Main orchestrator
scripts/lib/hn-scraper.ps1             # HackerNews API client
scripts/lib/reddit-scraper.ps1         # Reddit API client  
scripts/lib/news-formatter.ps1         # Format results for Teams/GitHub
```

**Scheduling:**
- Primary: GitHub Actions cron (`0 6 * * *` UTC = varies by timezone)
- Fallback: ralph-watch.ps1 at 6:00 AM check
- Manual trigger: `./scripts/tech-news-scanner.ps1 -Manual`

**Output Example:**
```
## 🚀 Today's Top Tech Stories

### 🔴 MUST-READ (100+ points)
1. **"Kubernetes 1.32 Released with eBPF Networking"** (HN: 245 pts)
   - https://news.ycombinator.com/item?id=XXX

2. **"New CVE in glibc — patching guide"** (Reddit/devops: 186 pts)
   - https://reddit.com/r/devops/...

### 🟡 TRENDING (50-99 points)
3. **"Why we switched from Docker to Podman"** (HN: 87 pts)
   ...
```

---

### **Phase 2: Hebrew Podcast + Multi-Source Expansion (Week 3-4)**

**Add:**
- 🎙️ **Hebrew Audio Podcast**: Use `podcaster.ps1` to convert daily digest to MP3
  - Voice: `he-IL-HilaNeural` (edge-tts)
  - Duration: ~5-7 minutes (10-15 stories)
  - Storage: GitHub Releases or Azure Blob
  - Naming: `tech-news-hebew-YYYY-MM-DD.mp3`

- **Expand Sources:**
  - Dev.to trending posts
  - Product Hunt trending dev tools
  - InfoQ/DZone articles (RSS)
  - Lobsters (Hacker News alternative)

- **Enhanced Filtering:**
  - Category detection: Infrastructure/Cloud, Security, AI/ML, DevOps, Web Dev
  - Sentiment analysis (optional, Phase 3)
  - Duplicate detection (same story across sources)

**Output:**
```
📻 HEBREW PODCAST AVAILABLE:
- tech-news-hebrew-2026-03-25.mp3 (6:32)
- Listen: https://github.com/tamirdresher_microsoft/tamresearch1/releases/tag/news-2026-03-25
```

---

### **Phase 3: Advanced Features (Week 5-6)**

- ✨ **Personalized Digest**: Config file selects source priority (HN > Reddit > X)
- 📊 **Trend Analysis**: Weekly summary of top 5 emerging topics
- 🤖 **AI Summaries**: Use Claude/GPT to generate 2-sentence summaries per article
- 🔐 **Security Filter**: Highlight CVEs, breach news, incident reports
- 📈 **Metrics Dashboard**: Track most-discussed topics over time
- 🔗 **Reading List Export**: Generate weekly markdown file for easy sharing

---

## Implementation Details

### Tech Stack
- **PowerShell Core**: Primary scripting (consistent with squad tooling)
- **HackerNews API**: Official Algolia API (`hn.algolia.com/api/v1/search`)
- **Reddit API**: PRAW Python library OR direct REST API (`oauth.reddit.com/`)
- **GitHub API**: Existing `gh CLI`
- **TTS**: `podcaster.ps1` (edge-tts or Windows fallback)
- **Scheduling**: GitHub Actions + ralph-watch.ps1

### Data Pipeline
```
[HN/Reddit/X APIs] 
    → [Filter & Deduplicate]
    → [Rank by Relevance]
    → [Format Markdown]
    → [Generate Audio (Hebrew)]
    → [Post to GitHub Issue / Teams]
    → [Store in Releases]
```

### Storage & Archival
- Daily digest issues: Create in `/tech-news/` label
- Historical index: `docs/tech-news-archive.md` (rolling 30-day index)
- Audio files: GitHub Releases (tagged `tech-news-YYYY-MM-DD`)
- Execution logs: `.squad/logs/tech-news-scanner.log`

---

## Execution Plan

| Phase | Week | Tasks | Owner | Status |
|-------|------|-------|-------|--------|
| MVP | 1 | Build HN/Reddit/X scrapers, Teams formatter, GitHub issue poster | Seven | Pending |
| MVP | 2 | Integration testing, GitHub Actions workflow, ralph-watch integration | Seven | Pending |
| Podcast | 3 | Hebrew TTS integration, podcast metadata, Release publishing | Seven | Pending |
| Podcast | 4 | Multi-source expansion (Dev.to, PH, InfoQ, Lobsters) | Seven | Pending |
| Advanced | 5-6 | AI summaries, security filter, trend analysis, metrics | Seven | Pending |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| **API rate limits** | Cache results (1hr TTL), batch requests, monitor quota |
| **Noisy results** (low signal) | Keyword filters, duplicate detection, minimum score thresholds |
| **Scheduling misalignment** | Dual-trigger: GitHub Actions + ralph-watch fallback |
| **Hebrew audio quality** | Test edge-tts voices; fallback to Windows TTS if needed |
| **Spokespeople fatigue** (too many alerts) | Configurable digest frequency (daily/weekly), mute toggle |

---

## Decision Points for Tamir

1. **Sources**: Approve HN + Reddit + X, or prefer other sources? (Dev.to, Lobsters, etc.?)
2. **Frequency**: Daily 6:00 AM, or different schedule?
3. **Digest Size**: 10-15 stories, or more/fewer?
4. **Hebrew Podcast**: Start with MVP, or skip until Phase 2?
5. **Publishing**: GitHub issue + Teams, or add Slack/Discord?
6. **Archival**: 30-day rolling window, or longer?

---

## Concrete Next Steps

If approved:
1. ✅ Implement `tech-news-scanner.ps1` + scrapers (Friday EOD)
2. ✅ Create GitHub Actions workflow `.github/workflows/tech-news-scan.yml`
3. ✅ Test with dry-run for 3 days (Saturday-Monday)
4. ✅ Go live with MVP (Tuesday morning)
5. ✅ Phase 2 kickoff: Hebrew podcasting (Week 3)

**Estimated Effort**: 30-35 hours for full MVP + podcast integration.

---

## Questions?

Comment below with feedback, suggestions, or alternative sources you'd like scanned. Once approved, I'll implement immediately.

**Status**: ⏳ **PENDING-USER** — awaiting approval before implementation starts.
