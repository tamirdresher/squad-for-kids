# Skill: API Gap Documentation Pattern

## When to Use
When researching or implementing a feature where the expected API/CLI doesn't exist, and manual UI interaction is required instead.

## Pattern

### 1. Confirm the Gap
- Use MCP/API documentation to verify no programmatic option exists
- Check GitHub REST API, CLI tools, SDK documentation
- Test available tools (e.g., list operations work but create/update don't)

### 2. Document Manual Process
Create a step-by-step setup guide with:
- Prerequisites (account permissions, subscriptions, etc.)
- Exact web UI navigation steps
- Screenshots or clear descriptions of each UI action
- Configuration values (with examples)
- Validation steps to confirm success

### 3. Prepare Integration Artifacts
Even though manual setup is required, prepare:
- Configuration files ready to paste
- Custom instructions/settings text ready to copy
- Checklist of items to select/configure
- Test queries/commands to validate after creation

### 4. Create Programmatic Access Layer
Once manually created, document how to:
- Access the resource via API/CLI
- Verify it exists programmatically
- Query/read data from it
- Update it (if supported)

### 5. Maintenance Protocol
Document:
- When manual updates are needed
- What auto-syncs (if applicable)
- How to verify sync status
- Troubleshooting common issues

## Example: Copilot Space Integration (Issue #416)

**Gap Identified:**
- GitHub Copilot Spaces have list and get MCP tools (read-only)
- No create or update tools exist
- GitHub REST API doesn't expose Space creation endpoints

**Solution Implemented:**

1. Manual Setup Guide (COPILOT_SPACE_SETUP.md):
   - Navigation steps to github.com/copilot/spaces
   - Configuration values with examples
   - File selection checklist (20 specific files)
   - Custom instructions text (ready to paste)
   - Test validation queries

2. Integration Documentation (KNOWLEDGE_MANAGEMENT.md):
   - How Space supplements squad files
   - When to use Space vs local search
   - Maintenance protocol (auto-sync vs manual)

3. Programmatic Access (MCP tools):
   - After manual creation, use MCP get_copilot_space tool
   - Agents can query Space content
   - Files auto-sync from repos (no manual refresh)

4. Success Criteria Checklist with validation steps

## Anti-Patterns

Don't block implementation waiting for API that may never come - document manual path and enable future automation

Don't write vague create via web UI instructions - provide step-by-step guide with exact navigation and values

Don't ignore the resource after manual creation - document programmatic read and query access for agents

Don't leave manual process undocumented - create setup guide plus maintenance protocol

## Related Skills

- github-distributed-coordination
- squad-conventions
- Research methodology

---

Created: 2026-Q2 (Issue #416)
Owner: Seven (Research & Docs)
Pattern Type: Documentation & Integration
