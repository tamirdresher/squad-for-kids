# Decision Proposal: DevBox Remote Access via SSH

**Date:** 2026-03-11  
**Author:** B'Elanna (Infrastructure Expert)  
**Status:** Proposed  
**Scope:** Infrastructure & Squad Automation

## Summary

Recommend SSH with key-based authentication as the standard for Squad's autonomous DevBox access, replacing manual dev tunnel workflows.

## Context

Issue #330 identified the need for Squad to reach DevBox autonomously without manual intervention. Current state requires Tamir to manually open dev tunnels and handle authentication, blocking Squad automation for checking Ralph status, installing tools, and running commands.

## Decision

**Use SSH with key-based authentication as the primary DevBox remote access method.**

## Rationale

Evaluated 5 solutions across 4 criteria (security, reliability, autonomy, simplicity):

### Comparison Matrix

| Solution | Security | Reliability | Autonomy | Simplicity | Score |
|----------|----------|-------------|----------|------------|-------|
| **SSH + Keys** | 🟢 Excellent | 🟢 Auto-starts | 🟢 Zero manual | 🟢 Native | **10/10** |
| Auto-start DevTunnel | 🟡 Auth required | 🟢 Persistent ID | 🟢 Zero manual | 🟡 Service setup | 7/10 |
| cli-tunnel auto-start | 🟡 Auth required | 🟢 Persistent | 🟢 Zero manual | 🟡 npm dependency | 7/10 |
| Self-hosted Runner | 🔴 Attack surface | 🟢 Auto-starts | 🟢 Zero manual | 🔴 Complex | 5/10 |
| Persistent Token | 🔴 Token leak risk | 🟢 Persistent | 🟢 Zero manual | 🟡 Token mgmt | 5/10 |

### Why SSH Wins

1. **Security**: Industry-standard key-based authentication, no secrets in URLs/tokens
2. **Reliability**: Native Windows OpenSSH service, starts on boot automatically
3. **Autonomy**: Zero manual intervention after initial setup
4. **Simplicity**: No external dependencies, built into Windows, PowerShell remoting works natively
5. **Auditability**: SSH logs all access attempts

### Alternatives Rejected

- **GitHub Actions Self-Hosted Runner**: High security risk (arbitrary code execution, secret access), not designed for interactive DevBox access
- **Persistent Tunnel Tokens**: Token leakage = full DevBox access until revoked
- **Dev Tunnels**: Good for web/browser access, but adds unnecessary complexity for command-line automation

## Implementation

1. Install OpenSSH Server on DevBox (one-time setup)
2. Generate SSH key pair on local machine
3. Configure authorized_keys on DevBox
4. Test with PowerShell remoting: `Enter-PSSession -HostName <devbox> -UserName <user> -SSHTransport`

## Consequences

**Positive:**
- Squad can autonomously check Ralph, install tools, run commands
- No manual tunnel opening required
- Strong security with key-based auth
- Works across reboots

**Negative:**
- Initial SSH key setup required (one-time)
- DevBox must be network-reachable (not an issue if on same network/VPN)

**Neutral:**
- cli-tunnel remains useful for web-based terminal monitoring (hub mode) but not primary access

## Related

- Issue #330: DevBox persistent access
- `.squad/skills/cli-tunnel/SKILL.md`: Documents cli-tunnel for monitoring use cases
- Microsoft Learn: OpenSSH on Windows documentation
