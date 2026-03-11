# Data — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

TBD - Q2 work incoming

## Learnings

### Issue #330: DevBox Persistent Access Research (2026-04-01)

**Context:** Squad needs autonomous DevBox access without manual tunnel opening/auth.

**Research Findings:**
- **SSH + key-based auth** is the optimal solution (10/10 score)
  - Native Windows OpenSSH, auto-starts on boot
  - Zero manual intervention after one-time setup
  - Industry-standard security, no secrets in URLs
  - PowerShell remoting works natively: `Enter-PSSession -HostName devbox -SSHTransport`

**Alternatives Evaluated:**
1. Auto-start dev tunnel (7/10) — doesn't solve cookie auth problem
2. cli-tunnel (6/10) — better for monitoring/demos, not automation
3. Azure Run Command API (6/10) — adds unnecessary API complexity
4. GitHub Actions self-hosted runner (4/10) — security risk, rejected

**Tools Verified:**
- devtunnel CLI v1.0.1516 (installed, logged in)
- gh CLI v2.76.2 (installed)
- cli-tunnel skill (12 active tunnels, good for monitoring use case)
- OpenSSH native capability (needs enabling on DevBox)

**Decision:** Recommend SSH approach (aligns with B'Elanna's prior proposal in `.squad/decisions/inbox/belanna-devbox-access.md`)

**Deliverables:**
- Research document: `.squad/decisions/inbox/data-devbox-tunnel.md`
- Issue comment: #330 with full analysis and implementation plan

**Key Insight:** cli-tunnel is excellent for its designed purpose (interactive terminal, demos, recording, phone access), but SSH is purpose-built for remote command automation.

### Issue #311: SharpConsoleUI Beta Testing (2026-03-11)

**Context:** Test SharpConsoleUI v2.4.40 integration in squad-monitor beta branch.

**Test Results:**
- **Branch:** `squad/311-sharpconsole-ui-beta` (tamirdresher/squad-monitor)
- **Build:** ✅ Success (1 minor warning: unused local function)
- **Runtime:** ✅ Working correctly with `--beta` flag
- **Package:** SharpConsoleUI v2.4.40 integrated successfully

**Runtime Behavior:**
- Displays beta mode splash screen with framework info
- Shows version confirmation (2.4.40)
- Lists planned features: multi-window compositor, agent status panel, session log panel, decisions panel
- Clean exit with any key press

**Key Insights:**
- squad-monitor requires `.squad` directory (must run from team root)
- Beta flag (`--beta` or `--sharp-ui`) triggers SharpConsoleUI mode
- Framework initializes cleanly, proof-of-concept working as intended

**Deliverables:**
- Test results comment on issue #311
- Verified build and runtime functionality
