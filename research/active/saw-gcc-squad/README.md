# SAW/GCC-Compatible Squad with Azure OpenAI Backend

**Research Report for Issue #504**  
**Author:** Seven (Research & Docs)  
**Date:** March 2025  
**Status:** FEASIBLE with moderate complexity

---

## Executive Summary

Building a SAW/GCC-compatible Squad variant using Azure OpenAI as the LLM backend is **technically viable** with the following key findings:

✅ **Azure OpenAI is available in GCC/GCC-High** (FedRAMP High, DoD IL4/IL5/IL6)  
✅ **MCP stdio transport works in restricted environments** (local process communication)  
✅ **Managed Identity eliminates API key management** (Azure AD-based auth)  
⚠️ **AppLocker/WDAC whitelisting required** (moderate effort)  
⚠️ **Container/binary signing needed** (standard gov cloud practice)  
⚠️ **Testing requires air-gapped environment setup** (3-5 day initial setup)

**Estimated Effort:** 3-4 weeks (PoC: 1 week, production hardening: 2-3 weeks)

---

## 1. Azure OpenAI in GCC/SAW Environments

### Availability & Compliance

Azure OpenAI Service is **fully available** in U.S. Government cloud environments as of 2024:

| Environment | Status | Compliance | Models Available |
|-------------|--------|------------|------------------|
| **GCC** | ✅ GA | FedRAMP High | GPT-4o, GPT-4, GPT-3.5-turbo, embeddings |
| **GCC High** | ✅ GA | FedRAMP High, DoD IL4/IL5 | GPT-4o, GPT-4, GPT-3.5-turbo, embeddings |
| **DoD Cloud** | ✅ GA | DoD IL5/IL6, Top Secret | GPT-4o, GPT-4 (limited models) |

**Key Details:**
- **Regions:** `usgovarizona`, `usgovvirginia`
- **Data Residency:** All data stays within U.S. government cloud boundary
- **Personnel:** U.S. personnel screening for operations and support
- **Endpoints:** `https://<resource-name>.openai.azure.us` (not `.azure.com`)

### Authentication Methods

Three authentication methods are supported:

#### 1. **Managed Identity (RECOMMENDED)**
- **Best for:** SAW/GCC environments
- **Advantages:**
  - No API keys to manage or rotate
  - Azure AD-based access control
  - Automatic credential lifecycle management
  - Works with Azure VM, Container Instances, AKS, App Service
- **Setup:**
  ```python
  from azure.identity import DefaultAzureCredential
  credential = DefaultAzureCredential()
  token = credential.get_token("https://cognitiveservices.azure.com/.default")
  ```
- **RBAC Role:** Assign `Cognitive Services OpenAI User` to managed identity

#### 2. **API Keys**
- Standard key-based authentication (less secure, not recommended for SAW)

#### 3. **Azure AD User Authentication**
- For user-specific scenarios (OAuth 2.0 flows)
- Integrates with government Entra ID tenants

**Recommendation:** Use Managed Identity for Squad coordinator running on Azure VM or container.

### Network Requirements

**Minimum Endpoints Required:**
- `https://<resource-name>.openai.azure.us` — Azure OpenAI API
- `https://login.microsoftonline.us` — Azure AD authentication (Managed Identity token acquisition)
- No `api.github.com` or public internet required ✅

**Network Isolation:**
- Can deploy in private Azure VNet
- All traffic stays within Azure Government boundary
- No external dependencies beyond Azure infrastructure

---

## 2. MCP Transport Compatibility in SAW

### MCP stdio Transport Overview

The Model Context Protocol (MCP) uses **stdio (standard input/output)** for local process communication, which is ideal for SAW environments:

**Architecture:**
```
┌─────────────────┐
│  Squad          │
│  Coordinator    │  ← Main process (Azure OpenAI client)
│                 │
│  ┌───────────┐  │
│  │ MCP Host  │  │  Spawns ↓
│  └───────────┘  │
└────────┬────────┘
         │ stdio (stdin/stdout)
         │
    ┌────▼─────────────┐
    │  MCP Server      │  ← Subprocess (e.g., filesystem, git, tools)
    │  (Agent Tool)    │
    └──────────────────┘
```

**Key Characteristics:**
- **Local-only:** No network sockets, HTTP endpoints, or external connections
- **Process isolation:** Each MCP server runs as a separate subprocess
- **JSON-RPC over pipes:** Newline-delimited JSON on stdin/stdout
- **Security:** Process-level isolation, no shared state

### SAW Compatibility Assessment

✅ **Compatible:** MCP stdio transport does NOT require:
- Internet access
- Network listeners (no open ports)
- Remote connections
- Web server infrastructure

✅ **SAW-Friendly Properties:**
- Runs entirely in local process space
- Can be restricted by standard Windows process controls
- No browser/renderer dependencies (unlike Electron-based tools)
- Deterministic subprocess spawning (auditable)

⚠️ **Restrictions to Consider:**
- **AppLocker:** Must whitelist all MCP server executables (Node.js, Python interpreters, custom binaries)
- **WDAC:** Must allow spawning of approved subprocesses
- **Script Execution:** PowerShell/Node.js script execution must be permitted (or use compiled binaries)

**Mitigation Strategies:**
1. Package all MCP servers as signed executables (not scripts)
2. Use single consolidated binary with embedded interpreters (e.g., Node.js bundled with pkg)
3. Document all subprocesses for AppLocker rule creation
4. Test in audit mode before enforcement

---

## 3. Architecture Proposal: Squad with Azure OpenAI

### Current Squad Architecture (Copilot CLI-based)

```
┌──────────────────────────────────────────┐
│  Squad Coordinator (GitHub Copilot CLI)  │
│  - Reads .squad/ config                  │
│  - Routes work to agents                 │
│  - LLM: api.github.com ❌ (blocked)     │
└──────────────────┬───────────────────────┘
                   │
         ┌─────────┼─────────┐
         ▼         ▼         ▼
    ┌────────┐ ┌────────┐ ┌────────┐
    │ Picard │ │  Data  │ │ Seven  │
    │ (Lead) │ │ (Code) │ │ (Docs) │
    └────────┘ └────────┘ └────────┘
    Each spawned via Copilot CLI sub-agent
```

### Proposed Architecture (Azure OpenAI-based)

```
┌──────────────────────────────────────────┐
│  Squad Coordinator (Custom)              │
│  - Reads .squad/ config                  │
│  - Routes work to agents                 │
│  - LLM: Azure OpenAI (GCC) ✅           │
│  - Auth: Managed Identity ✅            │
└──────────────────┬───────────────────────┘
                   │ Spawns via MCP stdio
         ┌─────────┼─────────┐
         ▼         ▼         ▼
    ┌────────┐ ┌────────┐ ┌────────┐
    │ Picard │ │  Data  │ │ Seven  │
    │ Agent  │ │ Agent  │ │ Agent  │
    └────────┘ └────────┘ └────────┘
    Each is MCP server with tool access
```

### Key Changes Required

#### 1. **Replace LLM Provider**
```python
# BEFORE (Copilot CLI)
import subprocess
result = subprocess.run(["gh", "copilot", "suggest", prompt])

# AFTER (Azure OpenAI)
from azure.identity import DefaultAzureCredential
import openai

credential = DefaultAzureCredential()
token = credential.get_token("https://cognitiveservices.azure.com/.default").token

openai.api_base = "https://your-resource.openai.azure.us"
openai.api_version = "2024-02-01"
openai.api_type = "azure_ad"
openai.api_key = token

response = openai.ChatCompletion.create(
    engine="gpt-4o",
    messages=[{"role": "system", "content": system_prompt},
              {"role": "user", "content": user_prompt}]
)
```

#### 2. **Abstract LLM Layer**
Create a provider interface:
```python
class LLMProvider:
    def complete(self, messages: List[Dict]) -> str:
        raise NotImplementedError

class AzureOpenAIProvider(LLMProvider):
    def complete(self, messages: List[Dict]) -> str:
        # Managed Identity auth + Azure OpenAI call
        pass

class CopilotProvider(LLMProvider):
    def complete(self, messages: List[Dict]) -> str:
        # GitHub Copilot CLI fallback
        pass
```

#### 3. **Squad Coordinator Changes**
- **Configuration:** Add `llm_provider: azure_openai` to `.squad/config.yaml`
- **Routing:** Keep existing routing logic (no changes needed)
- **Agent Spawning:** Keep MCP stdio transport (no changes needed)
- **Tool Access:** Keep existing MCP server integrations (filesystem, git, ADO, etc.)

#### 4. **Agent Process Flow**
```
1. Coordinator receives issue via webhook/polling
2. Reads agent capability profile from .squad/agents/*/
3. Routes to appropriate agent (same logic as current)
4. Spawns agent as MCP server subprocess
5. Agent uses Azure OpenAI for reasoning (via coordinator's provider)
6. Agent executes tools via MCP (filesystem, git, etc.)
7. Returns result to coordinator
8. Coordinator posts to GitHub/ADO
```

**What Stays the Same:**
- `.squad/` directory structure
- Agent capability profiles
- Routing logic
- MCP tool servers
- Issue tracking workflow

**What Changes:**
- LLM provider implementation (Copilot CLI → Azure OpenAI SDK)
- Authentication (API key → Managed Identity)
- Configuration (add Azure OpenAI endpoint/deployment)

---

## 4. AppLocker/WDAC Considerations

### Binaries Requiring Whitelisting

For a Node.js-based Squad implementation:

#### Core Executables
1. **Node.js Runtime:** `node.exe` (v18+ LTS)
2. **Git:** `git.exe` (for repository operations)
3. **Azure CLI (optional):** `az.exe` (for Managed Identity debugging)

#### MCP Servers (Tool Providers)
4. **Filesystem Server:** `mcp-server-filesystem.exe` (or bundled with Node)
5. **Git Server:** `mcp-server-git.exe`
6. **Azure DevOps Server:** `mcp-server-ado.exe`
7. **Custom Servers:** Any domain-specific tool servers

### Packaging Strategies

#### Option 1: Signed Executables (RECOMMENDED)
- **Tool:** Use `pkg` or `nexe` to bundle Node.js + app into single `.exe`
- **Signing:** Code-sign with organization certificate (required for WDAC)
- **Advantage:** Single binary, easy to whitelist
- **Example:**
  ```bash
  npm install -g pkg
  pkg squad-coordinator.js --targets node18-win-x64 --output squad.exe
  signtool sign /f cert.pfx /p password /tr http://timestamp.digicert.com squad.exe
  ```

#### Option 2: Container (SAW Container Support Required)
- **Tool:** Docker/containerd with Windows containers
- **Signing:** Sign container image
- **Advantage:** Isolated dependencies, easier updates
- **Challenge:** Requires container runtime in SAW (may not be approved)

#### Option 3: Approved Binary Directory
- **Strategy:** Install to `C:\Program Files\Squad\` (trusted path)
- **AppLocker Rule:** Allow all signed executables in this path
- **Signing:** Code-sign all binaries with organization certificate

### WDAC Policy Example

```xml
<!-- Allow Squad coordinator and MCP servers -->
<Allow>
  <FilePublisher 
    PublisherName="O=YOUR_ORG, CN=Code Signing" 
    ProductName="Squad Coordinator" 
    BinaryName="squad.exe" 
    MinVersion="1.0.0.0" />
  <FilePublisher 
    PublisherName="O=YOUR_ORG, CN=Code Signing" 
    ProductName="Squad MCP Server" 
    BinaryName="mcp-*.exe" 
    MinVersion="1.0.0.0" />
</Allow>
```

### Implementation Steps

1. **Audit Phase (1-2 days):**
   - Run WDAC in audit mode
   - Identify all executables Squad needs to spawn
   - Document script files (.ps1, .js) that need allowlisting

2. **Bundling Phase (2-3 days):**
   - Bundle Node.js apps as signed executables
   - Test subprocess spawning in isolated VM
   - Verify Managed Identity auth works in bundled form

3. **Policy Creation (1 day):**
   - Create WDAC policy XML for all Squad binaries
   - Create AppLocker rules for script execution (if needed)
   - Test in pilot SAW environment

4. **Validation Phase (2-3 days):**
   - Deploy to test SAW with WDAC enforcement enabled
   - Verify all Squad operations work (issue routing, git ops, etc.)
   - Performance testing

---

## 5. Network Isolation Testing

### Test Environment Setup

#### Prerequisites
- Azure Government subscription (GCC or GCC-High tenant)
- Azure VM in isolated VNet
- Azure OpenAI resource in same region
- Managed Identity enabled on VM

#### Network Configuration

**Isolated VNet Setup:**
```
┌─────────────────────────────────────────────┐
│  Azure VNet (10.0.0.0/16)                   │
│  No internet gateway ❌                     │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ Private Subnet (10.0.1.0/24)          │ │
│  │                                       │ │
│  │  ┌──────────────┐                    │ │
│  │  │ Test VM      │                    │ │
│  │  │ - Ubuntu/Win │                    │ │
│  │  │ - Managed ID │                    │ │
│  │  │ - Squad      │                    │ │
│  │  └──────────────┘                    │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ Private Endpoints                     │ │
│  │ - Azure OpenAI                        │ │
│  │ - Azure AD (login.microsoftonline.us) │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**NSG (Network Security Group) Rules:**
```
DENY: All outbound to 0.0.0.0/0 (internet)
ALLOW: Outbound to Azure OpenAI private endpoint (10.0.2.5)
ALLOW: Outbound to Azure AD endpoint (login.microsoftonline.us via service tag)
```

### Testing Procedure

#### Phase 1: Azure OpenAI Connectivity (Day 1)
1. Deploy VM in isolated VNet
2. Enable Managed Identity (system-assigned)
3. Grant `Cognitive Services OpenAI User` role
4. Test token acquisition:
   ```bash
   curl -H "Metadata:true" \
     "http://169.254.169.254/metadata/identity/oauth2/token?resource=https://cognitiveservices.azure.com&api-version=2018-02-01"
   ```
5. Test Azure OpenAI API call with token:
   ```bash
   TOKEN=$(curl -H "Metadata:true" "..." | jq -r .access_token)
   curl -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"messages":[{"role":"user","content":"Hello"}]}' \
        "https://your-resource.openai.azure.us/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-01"
   ```

#### Phase 2: Squad Coordinator (Day 2-3)
1. Transfer Squad binaries to VM (encrypted USB or Azure Blob with private endpoint)
2. Install without internet access (all dependencies pre-bundled)
3. Configure `.squad/config.yaml`:
   ```yaml
   llm:
     provider: azure_openai
     endpoint: https://your-resource.openai.azure.us
     deployment: gpt-4o
     auth: managed_identity
   ```
4. Test basic operations:
   - Read issue from local file (simulate webhook)
   - Route to agent
   - Agent generates response
   - Write result to local file

#### Phase 3: Full Workflow (Day 4)
1. Set up local Git repository (no GitHub access)
2. Simulate issue creation (JSON file)
3. Run Squad coordinator
4. Verify:
   - Issue parsed correctly
   - Routed to correct agent
   - Agent executed tools (filesystem, git)
   - Response generated via Azure OpenAI
   - Changes committed to local repo

#### Phase 4: Monitoring (Day 5)
1. Monitor VM metrics (CPU, memory, disk)
2. Check Azure OpenAI usage (token consumption)
3. Review logs for any blocked network calls
4. Verify no telemetry/diagnostics sent externally

### Success Criteria

✅ VM has no internet access (verified via NSG logs)  
✅ Squad coordinator successfully authenticates to Azure OpenAI via Managed Identity  
✅ All LLM operations complete without errors  
✅ MCP tool servers (filesystem, git) work in isolated environment  
✅ No external network calls detected (except Azure Government endpoints)  
✅ Performance is acceptable (latency, throughput)

### Fallback Testing

If private endpoint setup is complex, use **service endpoints** as interim:
- Less secure than private endpoints (traffic uses public IP but over Azure backbone)
- Simpler configuration
- Still no internet browsing capability

---

## 6. Feasibility Assessment

### ✅ VIABLE: Technical Foundation

| Component | Status | Confidence |
|-----------|--------|------------|
| Azure OpenAI in GCC | ✅ Available | High |
| Managed Identity Auth | ✅ Supported | High |
| MCP stdio Transport | ✅ SAW-compatible | High |
| Network Isolation | ✅ Feasible | High |
| Model Quality (GPT-4o) | ✅ Production-ready | High |

### ⚠️ MODERATE COMPLEXITY: Operational Hurdles

| Challenge | Impact | Mitigation | Effort |
|-----------|--------|------------|--------|
| AppLocker/WDAC Setup | Medium | Signed executables, policy templates | 3-5 days |
| Binary Packaging | Low | Use `pkg` for Node.js bundling | 2 days |
| Air-gapped Testing | Medium | Dedicated test VNet, documented procedures | 1 week |
| Update Process | Medium | Manual transfer, version control | Ongoing |
| Telemetry Removal | Low | Disable SDK telemetry flags | 1 day |

### 🚫 BLOCKERS: None Identified

No technical blockers prevent this implementation. All challenges are operational and solvable with proper planning.

### Estimated Effort Breakdown

#### Phase 1: Proof of Concept (1 week)
- Abstract LLM provider interface
- Implement Azure OpenAI provider with Managed Identity
- Test in local development environment
- Verify MCP stdio still works with new provider

#### Phase 2: SAW Hardening (2 weeks)
- Bundle as signed executables
- Create WDAC/AppLocker policies
- Document all binaries for whitelisting
- Test in isolated VNet

#### Phase 3: Air-gapped Validation (1 week)
- Set up test SAW environment
- Deploy and test full workflow
- Document network requirements
- Performance benchmarking

#### Phase 4: Documentation & Handoff (2-3 days)
- Deployment guide
- AppLocker/WDAC policy templates
- Troubleshooting runbook
- Training for SAW admins

**Total: 3-4 weeks** (single developer, no dependencies)

---

## Recommendations

### Immediate Actions (Week 1)

1. **Create LLM abstraction layer** in Squad codebase
   - Define `LLMProvider` interface
   - Implement `AzureOpenAIProvider` alongside existing Copilot provider
   - Add provider selection to `.squad/config.yaml`

2. **Set up test Azure Government subscription**
   - Deploy Azure OpenAI in `usgovarizona` or `usgovvirginia`
   - Create test VM with Managed Identity
   - Validate end-to-end connectivity

3. **Document binary manifest**
   - List all executables Squad needs
   - Identify which can be bundled vs. must be separate
   - Plan signing strategy with security team

### Short-term (Weeks 2-3)

4. **Bundle Squad as executable**
   - Use `pkg` to create signed `squad.exe`
   - Test subprocess spawning from bundled binary
   - Verify Azure OpenAI SDK works in bundled form

5. **Create WDAC policies**
   - Generate base policy in audit mode
   - Refine based on actual execution patterns
   - Create deployment template for SAW admins

6. **Build air-gapped test environment**
   - Isolated VNet with no internet
   - Private endpoints for Azure OpenAI
   - Test VM with enforcement-level WDAC

### Long-term (Weeks 4+)

7. **Production deployment**
   - Deploy to pilot SAW users
   - Monitor for 2 weeks
   - Iterate on policy refinements

8. **Documentation**
   - Installation guide for SAW environments
   - Troubleshooting runbook
   - Network requirements diagram

9. **Maintenance plan**
   - Update procedures (manual transfer)
   - Security patch process
   - Model version upgrades

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WDAC policy too restrictive | Medium | High | Start in audit mode, iterate over 2 weeks |
| Managed Identity misconfiguration | Low | Medium | Extensive testing, clear documentation |
| Performance degradation | Low | Medium | Benchmark in test env, monitor token usage |
| Update process friction | High | Low | Document clearly, automate where possible |
| Model availability in gov cloud | Low | High | Verify model list before deployment |
| Network isolation breaks functionality | Low | High | Comprehensive testing in air-gapped env |

**Overall Risk Level:** **LOW-MEDIUM**  
All risks are manageable with proper planning and testing.

---

## Comparison: Current vs. Proposed

| Aspect | Copilot CLI (Current) | Azure OpenAI (Proposed) |
|--------|------------------------|--------------------------|
| **Internet Required** | ✅ Yes (api.github.com) | ❌ No (Azure internal only) |
| **SAW Compatible** | ❌ No | ✅ Yes |
| **GCC/GCC-High Compatible** | ❌ No | ✅ Yes |
| **Authentication** | GitHub PAT | Managed Identity (keyless) |
| **Model Quality** | GPT-4 class | GPT-4o (latest) |
| **Cost** | Included with Copilot | Pay-per-token (gov cloud rates) |
| **Setup Complexity** | Low | Medium (WDAC, signing) |
| **Update Process** | Automatic (via `gh` CLI) | Manual (air-gapped) |
| **MCP Transport** | ✅ stdio | ✅ stdio (unchanged) |
| **Agent Pattern** | ✅ Supported | ✅ Supported (unchanged) |

---

## Conclusion

Building a SAW/GCC-compatible Squad using Azure OpenAI is **technically feasible and operationally viable**. The key enablers are:

1. **Azure OpenAI availability in Government Cloud** with FedRAMP High compliance
2. **Managed Identity authentication** eliminating API key management
3. **MCP stdio transport** requiring no network listeners or internet
4. **Clear path to AppLocker/WDAC compliance** via signed executables

The implementation follows standard patterns for deploying AI tools in high-security environments and leverages existing Azure Government infrastructure. No fundamental architectural changes to Squad are required—only the LLM provider abstraction layer.

**Recommendation:** Proceed with Phase 1 PoC (1 week) to validate approach, then move to SAW hardening if successful.

---

## References

1. [Azure OpenAI Service in Azure Government](https://learn.microsoft.com/en-us/azure/foundry-classic/openai/azure-government)
2. [Azure OpenAI FedRAMP High Authorization](https://devblogs.microsoft.com/azuregov/azure-openai-authorization/)
3. [Managed Identity for Azure OpenAI](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/managed-identity)
4. [Model Context Protocol Architecture](https://modelcontextprotocol.io/docs/learn/architecture)
5. [WDAC for Secure Admin Workstations](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/windows-defender-application-control)
6. [AI Inferencing in Air-Gapped Environments](https://techcommunity.microsoft.com/blog/azurehighperformancecomputingblog/ai-inferencing-in-air-gapped-environments/4498594)
7. [AppLocker Policy Configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/applocker)

---

## Appendix A: Sample Configuration

### `.squad/config.yaml` (Azure OpenAI)
```yaml
version: 1.0
squad:
  name: "SAW Squad"
  coordinator: "squad-coordinator.exe"
  
llm:
  provider: "azure_openai"
  endpoint: "https://your-resource.openai.azure.us"
  deployment: "gpt-4o"
  api_version: "2024-02-01"
  auth:
    type: "managed_identity"
    # No credentials needed - Managed Identity is automatic
  
agents:
  - name: "picard"
    role: "lead"
    mcp_server: "mcp-agents/picard.exe"
  - name: "data"
    role: "code"
    mcp_server: "mcp-agents/data.exe"
  - name: "seven"
    role: "docs"
    mcp_server: "mcp-agents/seven.exe"

tools:
  - name: "filesystem"
    mcp_server: "mcp-servers/filesystem.exe"
  - name: "git"
    mcp_server: "mcp-servers/git.exe"

security:
  allow_network: false
  enforce_signing: true
```

### WDAC Policy Template
```xml
<?xml version="1.0" encoding="utf-8"?>
<SiPolicy xmlns="urn:schemas-microsoft-com:sipolicy">
  <PolicyID>{GUID}</PolicyID>
  <PolicyName>Squad SAW Policy</PolicyName>
  
  <!-- Allow Squad binaries signed by org -->
  <FilePublisher>
    <PublisherName>O=YOUR_ORG, CN=Code Signing Cert</PublisherName>
    <ProductName>Squad</ProductName>
    <BinaryName>squad-*.exe</BinaryName>
    <MinVersion>1.0.0.0</MinVersion>
  </FilePublisher>
  
  <!-- Allow Windows system binaries -->
  <FolderPath>C:\Windows\System32</FolderPath>
  
  <!-- Deny all others -->
  <DenyAll />
</SiPolicy>
```

---

**End of Report**
