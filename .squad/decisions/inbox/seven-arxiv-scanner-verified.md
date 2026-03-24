# Decision: arXiv Daily Scanner Verified and Scheduled

**Date:** 2026-03-22
**Author:** Seven
**Issue:** #1308

## What was done

- Verified `scripts/arxiv-scanner.js` runs without errors (no external npm deps)
- Confirmed arXiv API connectivity: 50 papers fetched and parsed
- Zero results on Sunday is correct — arXiv doesn't publish weekends
- Added `arxiv-daily-scanner` to `schedule.json` (daily at 07:00)
- Closed issue #1308 as completed

## Schedule entry

```json
{
  "name": "arxiv-daily-scanner",
  "interval": "daily",
  "time": "07:00",
  "script": "scripts/arxiv-scanner.js",
  "runtime": "node",
  "tracking": ".squad/monitoring/arxiv-state.json"
}
```

## Notes for team

- First digest will appear on the next weekday (Monday 2026-03-23)
- State file `.squad/monitoring/arxiv-state.json` will be auto-created on first run
- Creates GitHub issues titled "Research Digest: YYYY-MM-DD" with ≥3 new papers
- Posts Teams notification to `squads > research` channel
