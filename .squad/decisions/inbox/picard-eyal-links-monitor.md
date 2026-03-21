# Decision: Eyal Links Continuous Monitor

**Date:** 2026-03-20  
**Author:** Picard (Lead)  
**Status:** ✅ ACTIVE  
**Issue:** #425

## Context

Eyal shares valuable technical content in the Cloud-Dev-and-Architecture Google Group. His curated links cover cloud architecture, distributed systems, Kubernetes, and other areas directly relevant to the Squad's work. To capture this knowledge systematically, we need automated monitoring.

## Decision

Implement continuous monitoring of Eyal's Google Group posts with these components:

### 1. Monitor Script (`scripts/eyal-links-monitor.js`)

**Capabilities:**
- Fetches Cloud-Dev-and-Architecture Google Group feed (Atom XML)
- Filters posts by author (Eyal identifiers: 'eyal', 'eyald', 'dresher.eyal')
- Extracts all URLs from post content
- Fetches each URL and extracts metadata (title, description, content preview)
- Scores relevance (HIGH/MEDIUM/LOW) based on keyword matching
- Deduplicates URLs across runs using state file

**Architecture:**
- **Single-responsibility**: One script handles full pipeline (fetch → parse → analyze → store → notify)
- **Stateless with persistence**: Uses JSON state file for deduplication, no external DB
- **Fail-safe**: Errors during URL fetch don't stop processing other links
- **Rate limiting**: 1-second delay between URL fetches to respect external servers

### 2. Knowledge Base (`.squad/knowledge/eyal-links/`)

**Structure:**
- One markdown file per Google Group post: `YYYY-MM-DD-{title-slug}.md`
- Each file contains:
  - Post metadata (author, date, source URL)
  - Original post content
  - All shared links with title, description, relevance, content preview
- Append-only: Never delete (knowledge accumulates)
- Searchable: Plain markdown enables `grep`, GitHub search, MCP tools

**Why Markdown?**
- Human-readable and diffable
- Git-friendly for version control
- No custom tooling needed for search/query
- Compatible with existing Squad knowledge patterns

### 3. State Tracking (`.squad/monitoring/eyal-links-state.json`)

Tracks:
- `lastCheck`: Timestamp of last monitoring run
- `processedPosts`: Array of post URLs already processed
- `processedUrls`: Array of link URLs already fetched (prevents refetching)

Prevents:
- Reprocessing the same Google Group post
- Refetching the same external URL across different posts
- Duplicate Teams notifications

### 4. Integration with Schedule

Added to `schedule.json`:
- **Interval:** Hourly (balance between freshness and API politeness)
- **Mode:** `once` (cron-style execution, not long-running daemon)
- **Notification Channel:** `squads > Tech News` (same as tech-news-scanner)
- **Knowledge Base Path:** Documented for future automation

### 5. Relevance Scoring

**HIGH** (immediate attention):
- Kubernetes, Azure, AKS, cloud architecture
- .NET, C#, microservices, DevOps, CI/CD
- AI, Copilot, GitHub, observability, security

**MEDIUM** (worth monitoring):
- Adjacent technologies not in our direct stack

**LOW** (filtered out):
- Everything else

Scoring drives notification behavior: HIGH/MEDIUM go to Teams, LOW stored but not notified.

## Alternatives Considered

### Alt 1: Manual Review
❌ **Rejected**: Doesn't scale; Tamir would need to check Google Group daily.

### Alt 2: Email Forwarding
❌ **Rejected**: No content extraction, no relevance scoring, no knowledge base.

### Alt 3: Full-Text Search Index (Elasticsearch, etc.)
❌ **Rejected**: Overengineered for ~10-50 links/month. Plain markdown + grep sufficient.

### Alt 4: Custom Google Group API Client
❌ **Rejected**: Atom feed is simpler and requires no OAuth setup.

### Alt 5: Store in Database
❌ **Rejected**: Markdown files are more maintainable and git-friendly for this use case.

## Implementation Details

**Language:** Node.js (matches existing monitors: tech-news-scanner.js, brady-squad-monitor.ps1 pattern)

**Dependencies:** Zero (uses only Node.js stdlib — https, fs, child_process)

**Error Handling:**
- Google Group feed fetch failure → Log error, exit non-zero (retry on next schedule)
- Individual URL fetch failure → Log warning, continue with other URLs
- Teams webhook missing → Log warning, skip notification (knowledge still saved)

**Modes:**
- `once`: Single run, exit (for scheduled execution)
- `continuous`: Infinite loop with configurable interval (for long-running daemon)

**Deployment:**
- Script added to repo: `scripts/eyal-links-monitor.js`
- Schedule entry added: `schedule.json`
- Ralph (Work Monitor) can execute on schedule
- Manual runs: `node scripts/eyal-links-monitor.js once`

## Success Criteria

✅ Captures all new posts from Eyal within 1 hour of posting  
✅ Extracts all URLs from each post  
✅ Scores relevance accurately (HIGH/MEDIUM/LOW)  
✅ Stores knowledge in searchable markdown format  
✅ Posts HIGH/MEDIUM links to Teams  
✅ No duplicate processing  
✅ Zero-dependency execution (Node.js stdlib only)

## Future Enhancements

**Phase 2** (if valuable after 1 month):
- AI-powered summarization of link content (via Copilot/GPT)
- Automatic tagging by topic (Kubernetes, Security, AI, etc.)
- Cross-reference with Squad decisions (e.g., "Eyal shared this about K8s before we chose AKS")

**Phase 3** (if scaling beyond Eyal):
- Generalize to monitor multiple people in Google Group
- Support multiple Google Groups
- Aggregate weekly digest instead of real-time notifications

## Integration Points

- **Tech News Scanner**: Same Teams channel, similar notification format
- **Ralph (Work Monitor)**: Executes on hourly schedule via `schedule.json`
- **Knowledge Management (Decision #16)**: Fits pattern of markdown-based knowledge capture
- **MCP Tools**: Knowledge base queryable via `grep`, `github-mcp-server-get_file_contents`

## Risks & Mitigations

**Risk:** Google Group blocks scraping  
**Mitigation:** Use Atom feed (public, intended for consumption); add User-Agent; rate limiting

**Risk:** Too many notifications (noise)  
**Mitigation:** Relevance scoring filters LOW; batch daily digest if volume increases

**Risk:** External URLs change/break over time  
**Mitigation:** Store content preview at capture time (not just URL); 404s logged but don't break pipeline

**Risk:** Eyal changes Google Group accounts  
**Mitigation:** Config has multiple identifier variants; manual config update if needed

## Rollout

1. ✅ Create script: `scripts/eyal-links-monitor.js`
2. ✅ Create knowledge base: `.squad/knowledge/eyal-links/README.md`
3. ✅ Add to schedule: `schedule.json`
4. ✅ Commit to branch: `squad/425-eyal-links-monitor`
5. ✅ Open PR with `Closes #425`
6. **Next:** Tamir approves → Merge → Ralph starts hourly execution

## Maintenance

- **Weekly:** Review Teams notifications for relevance tuning
- **Monthly:** Check knowledge base growth (expect ~10-50 files)
- **Quarterly:** Review relevance keywords; adjust based on Squad focus areas
- **Ad-hoc:** If Eyal changes accounts, update `CONFIG.eyalIdentifiers` in script

## References

- Issue #425: "Keep monitoring eyal shared links"
- Decision #16: Knowledge Management Phase 1 (quarterly history rotation)
- Tech News Scanner: `scripts/tech-news-scanner.js` (similar pattern)
- Brady Squad Monitor: Schedule pattern for periodic tasks
