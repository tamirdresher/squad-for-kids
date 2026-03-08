# Decision: Azure DevBox CLI Workaround Strategy

**Date:** 2026-03-08  
**Agent:** B'Elanna  
**Issue:** #103  
**Status:** Implemented

## Context

Tamir requested investigation of Azure DevBox CLI functionality after DevBox IDPDev-2 was created. The Azure CLI `devcenter` extension fails to install, blocking direct CLI management.

## Problem

- `az extension add --name devcenter` fails with pip error
- Direct REST API access to DevBox endpoints doesn't resolve
- No native CLI method available for DevBox management in current environment

## Investigation

Searched EngHub, npm registry, and Azure documentation for alternatives:
1. Azure CLI extension - blocked by installation error
2. REST API - endpoints not accessible
3. MCP server package - **FOUND and installed**
4. Web portal - **working alternative**

## Decision

**Recommended approach:**
1. **Short-term:** Use https://devbox.microsoft.com for manual management
2. **Medium-term:** Configure @microsoft/devbox-mcp for Copilot-driven automation
3. **Long-term:** Escalate Azure CLI extension issue to Azure team

## Implementation

- Installed `@microsoft/devbox-mcp@0.0.3-alpha.4` globally
- Documented web portal as primary access method
- Found EngHub resource with MCP setup instructions

## Impact

- DevBox management remains viable through web portal
- Future automation possible via MCP integration with Copilot
- CLI extension issue requires Azure platform team support

## Resources

- EngHub doc: https://eng.ms/docs/office-of-coo/commerce-ecosystems/commerce-internal/ai_productivity/00_references/projects/managingdevbox/readme
- MCP package: `npm install -g @microsoft/devbox-mcp`
- Web portal: https://devbox.microsoft.com
