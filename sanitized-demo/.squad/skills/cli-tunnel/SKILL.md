---
name: cli-tunnel
description: Tunnel any CLI application to your phone, browser, or remote display using secure Microsoft Dev Tunnels. Enables terminal sharing, live recording, and interactive remote CLI sessions with QR code scanning and hub mode for multi-session dashboards.
allowed-tools: 
---

# CLI Tunnel — Remote Terminal Access & Recording

**Confidence: Low (First Observation)**

CLI Tunnel is an innovative tool that lets you tunnel any command-line application (CLI) to your phone, browser, or remote display. It's perfect for live demos, terminal recording for presentations, multi-user terminal sharing, and working with CLI apps when away from your desk.

## What is CLI Tunnel?

CLI Tunnel runs a CLI process in a pseudo-terminal (PTY) and streams the full output—colors, interactive prompts, box drawings, and all—over a secure websocket to a browser-based terminal emulator (xterm.js). You control the remote CLI with full keyboard input support, all authenticated through your Microsoft or GitHub identity.

### Key Features

- **Tunnel Any CLI**: Copilot CLI, vim, Python REPL, htop, k9s, SSH, git, npm, and any other CLI tool
- **No Server Required**: Uses Microsoft Dev Tunnels for secure, authenticated HTTPS relay—no infrastructure to set up
- **Zero Installation Optional**: Use via `npx cli-tunnel <command>` (no install needed) or install globally with `npm install -g cli-tunnel`
- **Authentic Terminal**: Full TUI (text-based UI) support with colors, interactive prompts, and keyboard input
- **QR Code Sharing**: Generate a QR code to scan from your phone for instant access
- **Private & Secure**: Only accessible to your Microsoft/GitHub identity—even if someone else gets the URL
- **Hub Mode Dashboard**: Run `cli-tunnel` with no command to see all active sessions on a web-based dashboard
- **Grid View**: Monitor multiple live terminal previews in a card grid, like a browser-based tmux
- **Session Recording**: Capture terminal sessions for documentation, tutorials, and presentations

## Installation

### Global Install (Recommended)

```bash
npm install -g cli-tunnel
```

Verify installation:
```bash
cli-tunnel --version
```

### Per-Project or One-Off Usage (No Install)

```bash
npx cli-tunnel copilot --yolo
```

## Basic Usage

### Quick Start with Your First Session

```bash
# Tunnel your Copilot CLI
cli-tunnel copilot --yolo

# Tunnel Python REPL
cli-tunnel python -i

# Tunnel a shell session
cli-tunnel bash

# Tunnel any command
cli-tunnel your-command-here
```

A QR code will be displayed in your terminal. Scan it with your phone to access the session immediately.

### Named Sessions

```bash
# Name your session for the dashboard
cli-tunnel --name "My Demo" copilot --agent squad

# This session appears in the Hub with the name "My Demo"
```

## Hub Mode — Multi-Session Dashboard

Hub mode gives you a central dashboard to monitor and control all your active CLI sessions from one browser window.

### Start the Hub

```bash
# Run cli-tunnel with no command
cli-tunnel
```

This starts the Hub dashboard at `http://127.0.0.1:63726` (or similar local port).

**Hub Dashboard Features:**
- Live terminal previews of all active sessions
- Card-based grid layout (like tmux)
- Click to connect and control any session
- View session names, durations, and activity status
- Secure access via token in URL (do not share in screen recordings)

### Tunnel to the Hub from Anywhere

The Hub also exposes a public tunnel URL (over Microsoft Dev Tunnels):
```
https://jchkw9sp-63726.euw.devtunnels.ms?token=...&hub=1
```

**Warning:** Do not share this URL in public channels or screen recordings—the token grants access to all active sessions.

## Common Workflows

### Terminal Recording for Presentations

CLI Tunnel is ideal for recording terminal sessions for blog posts, tutorials, and demo videos:

1. Start a named session:
   ```bash
   cli-tunnel --name "git workflow demo" bash
   ```

2. Perform your commands in the terminal.

3. The terminal output (with colors and formatting) is preserved as clean, shareable text—unlike video screen captures.

4. Use the recorded session in:
   - Blog posts and documentation
   - Embedded terminal players (similar to Asciinema)
   - Synchronized with narration and slides for presentations

### Live Demos & Presentations

```bash
# Start a session you'll demo to an audience
cli-tunnel --name "Copilot Squad Demo" copilot --agent squad

# Share the session URL or QR code with audience members
# They see your terminal in real-time, with full interactivity
```

### Collaborative Terminal Sessions

```bash
# Start a shared session
cli-tunnel --name "pair-programming" vim myfile.js

# Share the tunnel URL with your pair
# Both of you control the same terminal
```

### Remote DevBox or SSH Session

```bash
# Tunnel into a DevBox or remote machine via SSH
cli-tunnel ssh user@devbox.example.com

# Access your DevBox terminal from your phone or any browser
```

### Monitoring Tools (htop, k9s, etc.)

```bash
# Monitor a Kubernetes cluster from your phone
cli-tunnel k9s

# Monitor system performance
cli-tunnel htop
```

## Options & Flags

Place flags **before** the target application command:

```bash
cli-tunnel [flags] <command> [command-args]
```

### Common Flags

| Flag | Description |
|------|-------------|
| `--local` | Disable public tunneling; session accessible on localhost only (no public tunnel URL) |
| `--port <n>` | Set the bridge port (default: 63726) |
| `--name <name>` | Name the session for the Hub dashboard |
| `--yolo` | Accept all confirmations automatically (useful for automation) |
| `--help` | Display help and available options |
| `--version` | Display CLI Tunnel version |

### Examples

```bash
# Local-only session (no public tunnel)
cli-tunnel --local copilot --yolo

# Custom port for testing multiple sessions
cli-tunnel --port 63727 python -i

# Named session with custom port
cli-tunnel --name "debug-session" --port 63728 bash

# Localhost-only with custom port
cli-tunnel --local --port 63729 vim notes.txt
```

## DevBox & Remote Environment Integration

CLI Tunnel works seamlessly with DevBoxes and remote development environments:

1. **SSH to DevBox**, then start CLI Tunnel:
   ```bash
   ssh user@devbox.example.com
   cli-tunnel bash
   ```

2. **Or tunnel the SSH session itself**:
   ```bash
   cli-tunnel ssh user@devbox.example.com
   ```

3. **Hub mode across multiple machines**: Start a Hub on your main DevBox, then connect sessions from other machines to the same Hub for centralized monitoring.

## Security Considerations

- **Authenticated Access**: All tunnels require Microsoft or GitHub identity—the URL alone is not enough.
- **Do Not Share URLs in Recordings**: URLs contain tokens. If sharing session recordings, capture the terminal output directly rather than screen recordings.
- **Local-Only Mode**: Use `--local` for sensitive work that should not be exposed over the internet.
- **Session Timeouts**: Sessions are typically cleaned up automatically after inactivity.

## Troubleshooting

### "Command Not Found" After Global Install
Restart your terminal, or verify npm's global bin directory is in your PATH:
```bash
npm config get prefix
# Add this path to your PATH environment variable if not already there
```

### Session Not Accessible
- Verify you're using the correct Microsoft/GitHub identity
- Check the token in the URL hasn't been shared publicly
- If using `--local`, access only from `http://127.0.0.1:<port>`, not external IPs

### Terminal Output Not Rendering Correctly
This is rare—most CLI apps with ANSI colors and box drawings work perfectly. If an app isn't rendering correctly, it may use a terminal type that PTY doesn't support. Try a different environment variable: `TERM=xterm cli-tunnel your-app`.

### Performance Issues with Large Output
If you're working with apps that produce massive amounts of output (like large log streams), consider piping to `head`, `tail`, or using `grep` to reduce volume:
```bash
cli-tunnel bash -c "tail -f /var/log/app.log | grep ERROR"
```

## Comparison: CLI Tunnel vs. Alternatives

| Aspect | CLI Tunnel | SSH | Screen Share | Terminal Emulator |
|--------|-----------|-----|--------------|-------------------|
| **Setup** | 1 command | SSH key setup | External tool | SSH needed |
| **Security** | Microsoft identity | SSH key | Depends on tool | SSH key |
| **Mobile Access** | ✅ Yes (browser) | ❌ Limited | ✅ Yes | ❌ Limited |
| **Recording** | ✅ Clean text output | ❌ Video only | ❌ Video only | Manual capture |
| **Interactivity** | ✅ Full keyboard | ✅ Full keyboard | ✅ Full control | ✅ Full keyboard |
| **Multiple Sessions** | ✅ Hub mode | ✅ tmux/screen | ✅ Multiple windows | ✅ Multiple tabs |

## Resources

- **GitHub Repository**: https://github.com/tamirdresher/cli-tunnel
- **Tamir Dresher's Blog**: https://www.tamirdresher.com/blog/
- **Recent Blog Posts**:
  - "Your Copilot CLI on Your Phone — Building Squad Remote Control" – Hub mode and multi-session support
  - "I Let AI Produce My Entire Hackathon Demo Video — Here's How" – Using CLI Tunnel for recorded presentations

## Quick Command Reference

```bash
# Start Hub dashboard
cli-tunnel

# Tunnel with auto-confirm (good for automation)
cli-tunnel --yolo copilot --agent squad

# Local-only session
cli-tunnel --local bash

# Named session on custom port
cli-tunnel --name "demo" --port 63727 python -i

# Terminal recording session
cli-tunnel --name "git-demo" bash

# DevBox SSH tunnel
cli-tunnel ssh user@devbox.example.com

# Monitoring with Kubernetes
cli-tunnel k9s

# Interactive Python
cli-tunnel python -i

# VIM text editor
cli-tunnel vim myfile.txt
```

---

**Skill Maintainer**: Seven (Research & Docs)  
**Last Updated**: Issue #245 Research  
**Status**: Active & Tested
