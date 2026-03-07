# Issue #35: Devbox Creation Investigation - B'Elanna's Comprehensive Response

## Executive Summary

I've completed investigation into devbox provisioning tools and infrastructure automation. **The good news:** Microsoft has published an official Dev Box MCP Server specifically designed for this use case, along with mature Azure CLI tooling. I've identified a path forward that involves both a dedicated provisioning repo and a reusable Squad skill.

---

## What I Found: Devbox Provisioning Landscape

### 1. **Microsoft Dev Box MCP Server** ✅ (This is what Tamir mentioned!)

**Status:** Production-ready, officially supported by Microsoft  
**Package:** `@microsoft/devbox-mcp` (npm)  
**Repository:** `github.com/microsoft/devbox-mcp-server`  
**Documentation:** Microsoft Learn tutorial + npm docs  

**What it does:**
- Provides standardized MCP (Model Context Protocol) endpoints for AI agents to manage Dev Boxes
- Supports: List projects/pools/boxes, create new boxes, start/stop boxes, query configurations
- Works with VS Code, Copilot Studio, and any MCP-compatible client
- Authentication via Azure CLI login or Windows SSO

**Relevant Operations for Your Use Case:**
```
- List all Dev Box projects and pools you have access to
- Create new Dev Box in specified project/pool (with custom naming)
- Start/stop lifecycle management
- Query Dev Box status and configuration
```

### 2. **Azure CLI Dev Center Extension** ✅ (For automation)

**Status:** Production-ready  
**Installation:** `az extension add --name devcenter`  
**CLI Pattern:** `az devcenter dev dev-box <operation>`  

**Core Provisioning Command:**
```bash
az devcenter dev dev-box create \
  --dev-center-name <name> \
  --project-name <project> \
  --pool-name <pool> \
  --name <new-box-name>
```

**Limitation to note:** Dev Box creation via CLI requires authenticated user principal (not service principals). This means the skill I build needs user credentials at execution time, not a static service account.

### 3. **Infrastructure-as-Code Options for Full Environment Setup**

If you ever need to provision the *entire* infrastructure (Dev Center, projects, pools, network connections, custom images), the recommended tools are:

- **Bicep/ARM Templates:** Azure-native, pairs perfectly with `az devcenter` CLI for full automation
- **OpenTofu/Terraform:** Multi-cloud, modular, GitOps-friendly
- **Ansible:** Agentless, YAML-based, good for post-provisioning configuration
- **Pulumi:** Code-centric (TypeScript/Python), strong for complex automation logic

Microsoft also publishes reference implementations (e.g., DevExp-DevBox on GitHub) that combine Bicep + CLI automation for end-to-end provisioning.

---

## My Recommended Approach for Your Request

### Phase 1: Dedicated "devbox-provisioning" Repository
This repo should contain:

1. **Infrastructure Definition (if setting up new pools/projects)**
   - Bicep templates for Dev Center, projects, network configurations, custom images
   - `deployments/` folder with parameterized ARM templates
   - Environment-specific parameter files (dev, staging, prod)

2. **Provisioning Scripts & Configuration**
   - PowerShell or Bash scripts wrapping `az devcenter dev dev-box create`
   - Configuration file capturing your "golden" devbox template:
     - Project name
     - Pool name (compute specs, OS image)
     - Tagging/naming conventions
     - Any post-provisioning setup (software installs, dotfiles, tool configurations)
   - Example `devbox-config.json` with your current devbox specs

3. **Documentation**
   - README explaining your current devbox project/pool setup
   - Step-by-step guide to spin up identical boxes
   - Troubleshooting guide (e.g., CLI installation, authentication)

4. **CI/CD Integration (optional but recommended)**
   - GitHub Actions or Azure DevOps pipeline to validate provisioning scripts
   - Dry-run validation that the scripts can execute without errors

### Phase 2: Squad Skill for Future Automation
Create a Squad skill (e.g., "devbox-provisioner") that:

1. **Accepts natural language requests:**  
   - "Create a new devbox named 'dev-box-2' matching my current setup"
   - "Spin up 3 new devboxes for the team"

2. **Knows how to:**
   - Read the devbox-provisioning repo config (project/pool/naming conventions)
   - Call `az devcenter dev dev-box create` with proper parameters
   - Report success/failure and new devbox details

3. **Is reusable** because:
   - The config is stored in the repo (you update it once)
   - The skill just reads the repo and executes the automation
   - No hardcoding of project/pool names in the skill

---

## Information I Need From You (Tamir)

Before I build the repo and skill, please confirm:

1. **Current Devbox Details:**
   - What is your Dev Center name?
   - What is your project name?
   - What is your pool name?
   - What OS/image does your current box use? (Windows/Linux, VS, specific tools)
   - Any custom naming conventions you use?

2. **Scope of Automation:**
   - Do you want the dedicated repo to *only* handle devbox creation/cloning (Phase 2), or also to provision the entire Dev Center/projects/pools infrastructure from scratch (Phase 1)?
   - Recommendation: Start with Phase 2 (box cloning), add Phase 1 later if you need to provision entirely new projects/pools.

3. **Post-Provisioning Configuration:**
   - Are there specific tools, scripts, or dotfiles that should be installed on each new devbox?
   - Should those be part of the provisioning repo, or handled separately?

4. **Team Access:**
   - Will other team members need to provision boxes, or just you?
   - Should the skill be available to specific users only, or broadly in the Squad?

---

## Next Steps

1. **I'm ready to build:**
   - Dedicated `devbox-provisioning` repo with Bicep templates, CLI scripts, and documentation
   - Squad skill that reads the repo and automates box creation
   - All driven by the MCP Server (your original instinct was correct!)

2. **You can unblock me by providing:**
   - Your current devbox project/pool/image details (list above)
   - Confirmation on scope (Phase 2 now, or Phase 1+2)

3. **Timeline:**
   - Once I have your details: ~1-2 days to stand up the repo and skill
   - The infrastructure will be repeatable and versioned in Git

---

## Key Advantages of This Approach

✅ **Reproducible:** All configuration in Git, version-controlled, code-reviewable  
✅ **Future-proof:** Uses official Microsoft tooling (MCP Server + CLI extension)  
✅ **Hands-off:** Squad skill means you say "create 3 boxes" and it happens  
✅ **Team-friendly:** Other engineers can spin up identical boxes without manual steps  
✅ **IaC-ready:** Bicep templates mean you can provision new projects/pools later if needed  

---

## References

- [Microsoft Dev Box MCP Server Tutorial](https://learn.microsoft.com/en-us/azure/dev-box/tutorial-get-started-dev-box-mcp-server)
- [Dev Center CLI Reference](https://learn.microsoft.com/en-us/cli/azure/devcenter/dev/dev-box)
- [DevExp-DevBox Accelerator (Bicep reference)](https://github.com/Evilazaro/DevExp-DevBox)

---

**What's your move, Tamir?** Confirm the details above and I'll build the infrastructure! 🚀
