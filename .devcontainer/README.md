# Codespaces Configuration Guide

> Developing in the cloud with GitHub Codespaces and Copilot CLI integration

## Overview

This repository is configured for **GitHub Codespaces** with:
- ✅ Copilot CLI (interactive agent in the terminal)
- ✅ Agency (Squad agent framework for automated tasks)
- ✅ All MCP (Model Context Protocol) servers configured
- ✅ Project dependencies pre-installed
- ✅ VS Code extensions ready to use

## Quick Start

### 1. Open Codespace

From the repository on GitHub:
1. Click **Code** button
2. Select **Codespaces** tab
3. Click **Create codespace on main**

GitHub provisions the environment automatically using `.devcontainer/devcontainer.json`.

### 2. Wait for Post-Create Setup

The first time you open a Codespace:
- Container is built from Microsoft's universal image
- `post-create.sh` runs automatically
- Copilot CLI, Squad CLI, and dependencies are installed
- MCP servers are configured
- **This takes ~2-3 minutes**

### 3. Configure Copilot CLI

Once setup completes, authenticate with GitHub:

```bash
copilot configure
```

Follow the browser prompt to authenticate with your GitHub account. This enables Copilot CLI to:
- Access MCP servers (Azure DevOps, etc.)
- Use the Squad agent framework
- Operate on your behalf in the terminal

### 4. Verify Setup

Check that everything is working:

```bash
# Verify Copilot CLI
copilot --version

# Verify Squad CLI
squad --version

# Verify MCP servers are discoverable
copilot list-mcp-servers
# Should show: azure-devops, devbox (if configured)

# Run project tests
npm run test
```

## What's Available

### Copilot CLI

Interactive assistant for common tasks. Examples:

```bash
# Ask for help with a task
copilot help

# Explain a file
copilot explain src/api/main.ts

# Generate code based on description
copilot generate "Create a simple HTTP server in Node.js"

# Refactor code
copilot refactor src/utils/transform.ts
```

For more: `copilot --help`

### Squad CLI

Multi-agent orchestration for complex tasks:

```bash
# List available agents
squad list-agents

# Run an agent task
squad run @scribe "Analyze test failures and suggest fixes"

# View agent history
squad show-history
```

For more: `squad --help`

### MCP Servers

Model Context Protocol servers are automatically configured and available:

**Azure DevOps MCP:**
```bash
copilot azure-devops list-projects
copilot azure-devops get-pr 42
```

**DevBox MCP:**
```bash
copilot devbox list
copilot devbox create --name "my-devbox"
```

For full MCP documentation, see `.squad/mcp-config.md`

### VS Code Extensions

Pre-configured extensions:
- **GitHub Copilot** — Code generation, inline chat
- **GitHub Copilot Chat** — Dedicated chat panel
- **GitLens** — Git history and blame
- **Docker** — Docker file support
- **REST Client** — Test HTTP endpoints
- **ESLint** — JavaScript/TypeScript linting
- **Prettier** — Code formatting

## File Locations

```
.devcontainer/
├── devcontainer.json      # Main Codespaces configuration
├── post-create.sh         # Setup script (runs after container creation)
├── init.sh                # Pre-container initialization
└── README.md              # This file

.copilot/
├── mcp-config.json        # MCP server configuration
└── [other Copilot config]

squad.config.ts            # Squad agent routing and configuration
package.json               # Node.js dependencies
```

## Troubleshooting

### Copilot CLI Not Working

**Symptom:** `copilot: command not found`

**Fix:**
```bash
# Reinstall Copilot CLI
npm install -g @github/copilot@latest

# Verify installation
copilot --version
```

### MCP Servers Not Discovered

**Symptom:** `copilot list-mcp-servers` returns empty

**Fix:**
1. Check MCP config exists:
   ```bash
   cat ~/.copilot/mcp-config.json
   ```

2. Verify config is valid JSON:
   ```bash
   jq . ~/.copilot/mcp-config.json
   ```

3. Reinitialize Copilot CLI:
   ```bash
   copilot configure --reset
   ```

### Authentication Issues

**Symptom:** "Not authenticated" or "Permission denied"

**Fix:**
```bash
# Re-authenticate
copilot configure

# Or manually set token
export GITHUB_TOKEN="your-token-here"
copilot configure
```

### Container Build Fails

**Symptom:** "Failed to build container"

**Fix:**
1. In VS Code, open Command Palette (Ctrl+Shift+P)
2. Search: "Codespaces: Rebuild Container"
3. Click to rebuild

Or via command line:
```bash
gh codespace rebuild
```

### Slow Performance

**Symptom:** Commands are slow or unresponsive

**Fix:**
1. Check available disk space:
   ```bash
   df -h
   ```

2. Clear npm cache:
   ```bash
   npm cache clean --force
   ```

3. Restart container:
   ```bash
   gh codespace stop
   gh codespace start
   ```

## Development Workflow

### Local Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Run tests
npm run test

# Run linter
npm run lint
```

### Using Copilot CLI for Code Tasks

```bash
# Get code review suggestions
copilot review-code

# Fix linting issues automatically
copilot fix-lint

# Generate tests
copilot generate-tests src/api/users.ts
```

### Using Squad for Multi-Agent Tasks

```bash
# Coordinate multiple agents for complex work
squad run @coordinator "Analyze architecture and suggest improvements"

# Review pull request with full team
squad run @reviewer "Review PR #167 comprehensively"
```

## Ports

The following ports are forwarded and accessible:

| Port  | Service              | Auto-Forward |
|-------|----------------------|--------------|
| 3000  | Dev Server           | Notify       |
| 5000  | Backend API          | Notify       |
| 8080  | HTTP                 | Notify       |
| 8888  | Jupyter/Aspire       | Notify       |
| 18888 | Aspire Dashboard     | Notify       |

When you access a forwarded port, GitHub automatically creates a secure URL.

## Environment Variables

The Codespaces environment includes:

| Variable      | Value          | Purpose                |
|---------------|----------------|------------------------|
| `NODE_ENV`    | `development`  | Sets Node.js env mode  |
| `HOME`        | `/home/codespace` | User home directory   |
| `GITHUB_TOKEN`| (if set)       | GitHub API auth token  |

To add custom environment variables:
1. In repository settings → Codespaces → Secrets
2. Add environment variable
3. Rebuild container for changes to take effect

## SSH Access to Git

SSH keys from your local machine are automatically mounted to the Codespace:
- Source: `~/.ssh` (read-only)
- Mount: `/home/codespace/.ssh`

This enables:
```bash
# Push/pull with SSH authentication
git push origin feature-branch

# No need to enter credentials
```

## Comparing with DevBox

| Feature           | Codespaces           | DevBox              |
|-------------------|----------------------|---------------------|
| **Environment**   | Cloud (container)    | Cloud (VM)          |
| **Setup Time**    | 2-3 minutes          | 5-10 minutes        |
| **Cost**          | GitHub quota         | Azure compute cost  |
| **Persistence**   | Stops after inactivity | Always-on          |
| **Performance**   | Lightweight          | Full VM resources   |
| **Collaboration** | Browser-based        | RDP required        |
| **CLI Tools**     | Copilot + Squad      | Copilot + Squad     |
| **MCPs**          | All configured       | All configured      |

## Advanced Configuration

### Adding More VS Code Extensions

Edit `.devcontainer/devcontainer.json`:

```json
"extensions": [
  "GitHub.copilot",
  "your-new-extension-id"
]
```

Rebuild container:
```bash
gh codespace rebuild
```

### Adding Services (Docker Compose)

Create `.devcontainer/docker-compose.yml` with additional services (database, cache, etc.).

Reference in `devcontainer.json`:
```json
"dockerComposeFile": "docker-compose.yml",
"service": "app"
```

### Customizing Post-Create Setup

Edit `.devcontainer/post-create.sh` to add additional setup steps.

Changes take effect on next container rebuild.

## Getting Help

### Documentation
- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Copilot CLI Docs](https://docs.github.com/en/copilot/cli-reference)
- [Squad Agent Framework](../.squad/README.md)
- [MCP Configuration](../.squad/mcp-config.md)

### Support
- File an issue: https://github.com/tamirdresher_microsoft/tamresearch1/issues
- Codespaces limits: https://docs.github.com/en/codespaces/overview

## Tips & Tricks

### Keep Codespace Active During Long Tasks

```bash
# Prevent timeout during long operations
sleep 55m &
your-long-running-command
kill %1
```

### Copy/Paste Between Local and Codespace

Use Codespaces browser UI or:
```bash
# Forward local port to Codespace
gh codespace ports forward 3000
```

### Use Multiple Codespaces

Create separate Codespaces for different branches:
```bash
gh codespace create --branch feature-xyz
```

### Debug Codespace Issues

```bash
# Check logs
gh codespace logs

# View detailed status
gh codespace list -q

# SSH into running Codespace
gh codespace ssh
```

---

**Maintained by:** B'Elanna (Infrastructure Expert)  
**Related Issue:** #167  
**Status:** ✅ Production Ready
