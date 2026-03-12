# Decision: DevBox SSH Implementation Scripts

**Agent:** Data  
**Date:** 2026-04-01  
**Status:** Implemented  
**Context:** Issue #330 — DevBox Persistent Access

## Background

Issue #330 research identified SSH + key-based auth as the optimal solution (10/10 score, unanimous team recommendation). However, no implementation artifacts were created — Tamir had to manually connect and run Ralph himself. This decision documents the implementation deliverables.

## Decision

Created three implementation artifacts for SSH-based DevBox access:

### 1. `scripts/devbox-ssh-setup.ps1`
PowerShell script to run **ON the DevBox** (as Administrator):
- Installs OpenSSH Server Windows capability
- Configures sshd for key-only authentication (disables password auth)
- Sets up authorized_keys with Squad's public key
- Configures Windows Firewall rules for port 22
- Restarts sshd service
- Tests setup and displays connection instructions

**Key Features:**
- Idempotent (safe to run multiple times)
- Interactive prompts for public key if not provided via parameter
- Backs up sshd_config before modifications
- Sets proper permissions on authorized_keys (owner-only)
- Colored output for clarity (Yellow=progress, Green=success, Red=error)

### 2. `scripts/devbox-ssh-keygen.ps1`
PowerShell script to run **on the LOCAL machine** where Squad runs:
- Generates ed25519 SSH key pair at `~/.ssh/squad-devbox-key`
- Won't overwrite existing keys without confirmation
- Displays public key to copy to DevBox
- Creates/updates `~/.ssh/config` with DevBox host entry (alias: `squad-devbox`)
- Provides connection examples (ssh, Enter-PSSession)

**Key Features:**
- Checks for ssh-keygen availability (instructs installation if missing)
- Interactive prompts for DevBox hostname and username if not provided
- Safe handling of existing keys and config entries
- Provides PowerShell remoting syntax for Squad automation

### 3. `.squad/config.json` Enhancement
Added `devbox` section with placeholders:
```json
"devbox": {
  "hostname": "PLACEHOLDER_DEVBOX_IP_OR_HOSTNAME",
  "username": "PLACEHOLDER_DEVBOX_USERNAME",
  "sshKeyPath": "~/.ssh/squad-devbox-key",
  "sshConfigAlias": "squad-devbox"
}
```

## Implementation Details

**SSH Configuration Approach:**
- Uses ed25519 keys (modern, secure, small)
- Key-only authentication (password auth disabled for security)
- SSH config alias (`squad-devbox`) for easy connection
- StrictHostKeyChecking=accept-new (auto-accept first connection)

**PowerShell Remoting Support:**
```powershell
Enter-PSSession -HostName squad-devbox -SSHTransport
```

**Error Handling:**
- All scripts use `$ErrorActionPreference = "Stop"` for fail-fast behavior
- Administrator privilege checks on devbox-ssh-setup.ps1
- Graceful fallbacks for missing config (prompts user for input)
- Backup of sshd_config before modifications

## Testing

Scripts are ready for testing. Recommended flow:
1. Run `devbox-ssh-keygen.ps1` on local machine → generates keys, displays public key
2. Copy public key
3. Run `devbox-ssh-setup.ps1` on DevBox with public key → installs/configures SSH server
4. Test connection: `ssh squad-devbox` from local machine
5. Test PowerShell remoting: `Enter-PSSession -HostName squad-devbox -SSHTransport`

## Rationale

- **Implementation over research:** Team consensus was already achieved. The blocker was lack of runnable artifacts.
- **PowerShell scripts:** Native Windows tooling, no dependencies, easy to read/modify
- **Idempotent design:** Safe to re-run if first attempt fails or config drifts
- **Clear separation:** Setup script (DevBox) vs keygen script (local) — prevents confusion about where to run what
- **Config integration:** Added devbox section to `.squad/config.json` for future automation use

## Next Steps

1. User tests scripts on actual DevBox
2. Update placeholders in `.squad/config.json` with real values
3. Validate SSH connection and PowerShell remoting
4. Integrate into Squad automation workflows (Ralph, monitoring, etc.)

## Alignment

Aligns with:
- B'Elanna's prior proposal (`.squad/decisions/inbox/belanna-devbox-access.md`)
- Issue #330 research findings (Data's recommendation, 10/10 score)
- Team consensus: SSH + key-based auth is the right solution
