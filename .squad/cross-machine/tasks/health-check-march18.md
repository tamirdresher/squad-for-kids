# Health Check + WhatsApp Monitor — All Machines
target: ALL
priority: high
created: 2026-03-18T07:24:21Z
created_by: CPC-tamir-3H7BI

## Instructions
1. Run full health check diagnostic (Ralphs, keep-alive, secrets, sleep settings, gh auth)
2. Auto-heal any issues found (restart dead processes, load secrets, re-disable sleep)
3. Verify WhatsApp monitoring is in ralph-watch.ps1 prompt — if missing, ensure it's there
4. Check schedule-state.json for any overdue scheduled tasks and run them
5. Send a health report to Tamir via Teams notification including:
   - Machine name
   - Ralph status (main + research) 
   - WhatsApp monitoring status
   - Any scheduled tasks that were missed
   - Any issues found and fixed
6. Comment on GitHub issue #894 with your machine's status

## Expected Response
Machine health report with all statuses.
