# Belanna — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

TBD - Q2 work incoming

## Learnings

### 2026-05-11: Azure DevOps MCP Multi-Org Limitations

**Context:** Issue #329 — Squad couldn't access PRs in different Azure DevOps orgs (microsoft vs msazure).

**Key Findings:**
1. **Single-Org Constraint**: The `@azure-devops/mcp` package requires org name as a startup argument and cannot switch orgs at runtime
2. **No Runtime Reconfiguration**: MCP servers must be restarted with a new org argument to switch orgs
3. **Config Hierarchy**: Repo-level `.copilot/mcp-config.json` doesn't override global MCP server instances. Global config takes precedence for server definitions.
4. **Auth Method**: Uses Entra ID interactive authentication (browser/device flow). PATs are explicitly NOT supported.

**Solution Implemented:**
- **Multi-instance pattern**: Run separate MCP server instances per org with unique names:
  ```json
  "ado-microsoft": { "args": ["@azure-devops/mcp", "microsoft"] }
  "ado-msazure": { "args": ["@azure-devops/mcp", "msazure"] }
  ```
- Tools become prefixed: `ado-microsoft-core_list_projects` vs `ado-msazure-core_list_projects`
- Both orgs accessible simultaneously without context switching

**Alternative Considered:**
- Az CLI fallback with `--org` flags (rejected: CLI is slower, less structured, and was failing in test environment)
- Dynamic config swapping (rejected: no runtime reload capability)

**Recommendation:** Always use multi-instance MCP setup for any cross-org ADO work. Document org routing in Squad skills.

**Decision Status:** ✅ Merged to `.squad/decisions.md` (Decision 14) on 2026-03-11. Multi-instance MCP pattern approved for team adoption.

### 2026-03-11: DevBox Remote Access Solution Selection

**Context:** Issue #330 — Squad needed autonomous DevBox access without manual tunnel/auth intervention.

**Key Findings:**
1. **Problem Analysis**: Playwright persistent sessions lose auth cookies on dev tunnels, manual tunnel opening blocks automation
2. **5 Solutions Evaluated**:
   - Auto-start dev tunnel (scored 7/10) — good but requires service wrapper
   - SSH + key auth (scored 10/10) — **recommended**
   - Self-hosted GitHub Actions runner (scored 5/10) — security risk, wrong tool
   - Persistent tunnel tokens (scored 5/10) — token leakage risk
   - cli-tunnel auto-start (scored 7/10) — good for monitoring, not primary access

**Solution Recommended: SSH with Key-Based Authentication**
- **Security**: Industry-standard key-based auth, no token leakage, auditable
- **Reliability**: Native Windows OpenSSH service, survives reboots
- **Autonomy**: Zero manual intervention after setup
- **Simplicity**: No external dependencies, built into Windows
- **Integration**: PowerShell remoting over SSH works seamlessly for Squad commands

**Implementation Path:**
1. Install OpenSSH Server on DevBox (Windows capability)
2. Generate SSH key pair (ed25519)
3. Configure authorized_keys on DevBox
4. Test PowerShell remoting: `Enter-PSSession -HostName <devbox> -UserName <user> -SSHTransport`

**Key Insight:** SSH is the right tool for remote command execution on Windows — dev tunnels and cli-tunnel are better suited for web/browser-based access and monitoring dashboards.

**Alternative Rejected — Self-Hosted Runner Risk:**
- GitHub Actions self-hosted runners pose significant security risks (arbitrary code execution, secret access, attack surface)
- Requires dedicated isolation, constant patching, and monitoring
- Not designed for interactive DevBox access — using it this way would be a security anti-pattern

**Decision Status:** Analysis posted to Issue #330. Awaiting Tamir's approval to implement.
