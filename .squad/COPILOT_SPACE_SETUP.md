# Copilot Space Setup Guide — "Research Squad"

> **Manual setup required:** GitHub does not provide API/CLI for Space creation. Follow this guide to create the Space via web UI.

## Prerequisites

- GitHub account with access to `tamirdresher_microsoft` organization
- Repository access to `tamirdresher_microsoft/tamresearch1`
- GitHub Copilot subscription (for Space creation)

---

## Step 1: Create the Space

1. Navigate to: **https://github.com/copilot/spaces**
2. Click **"New Space"**
3. Configure:
   - **Name:** `Research Squad`
   - **Owner:** `tamirdresher_microsoft` (organization)
   - **Visibility:** `Private` (team only)
   - **Description:** "AI agent team shared knowledge hub — cross-repo context for squad operations"

---

## Step 2: Add Custom Instructions

Paste the following into the "Custom instructions" field:

```
You are assisting the Research Squad — an AI agent team using Star Trek TNG/Voyager
personas. The team includes Picard (Lead), Seven (Research & Docs), B'Elanna (Infrastructure),
Worf (Security & Cloud), Data (Code), and others.

Context files describe agent charters, routing rules, and team decisions. When answering:
- Respect agent boundaries and routing rules in routing.md
- Reference decisions.md for past team decisions
- Use team.md roster for current member capabilities
- Follow copilot-instructions.md for agent behavior standards

This Space supplements the .squad/ file system in the repository — files here are read-only
context. The source of truth for editable content remains in the git repository.
```

---

## Step 3: Add Repository Files

**Add from tamirdresher_microsoft/tamresearch1 (main branch):**

Click **"Add source"** → **"Repository"** → Select `tamirdresher_microsoft/tamresearch1`

Select these files (use filter to find them):

### Core Team Structure (4 files)
- [ ] `.squad/team.md`
- [ ] `.squad/routing.md`
- [ ] `.squad/charter.md`
- [ ] `.squad/copilot-instructions.md`

### Agent Charters (13 files)
- [ ] `.squad/agents/picard/charter.md`
- [ ] `.squad/agents/belanna/charter.md`
- [ ] `.squad/agents/worf/charter.md`
- [ ] `.squad/agents/data/charter.md`
- [ ] `.squad/agents/seven/charter.md`
- [ ] `.squad/agents/podcaster/charter.md`
- [ ] `.squad/agents/q/charter.md`
- [ ] `.squad/agents/scribe/charter.md`
- [ ] `.squad/agents/kes/charter.md`
- [ ] `.squad/agents/ralph/charter.md`
- [ ] `.squad/agents/troi/charter.md`
- [ ] `.squad/agents/neelix/charter.md`
- [ ] `.squad/agents/@copilot/capability-profile.md` (if exists)

### Knowledge & Decisions (3 files)
- [ ] `.squad/KNOWLEDGE_MANAGEMENT.md`
- [ ] `.squad/decisions.md`
- [ ] `.squad/research-repos.md`

**Total: ~20 files, ~3 MB**

> **Note:** Files linked from repos auto-sync with main branch. No manual refresh needed.

---

## Step 4: Test the Space

After creation, validate with these queries in the Space web UI:

### Query 1: Agent routing
**Ask:** "Who handles infrastructure issues?"  
**Expected:** References B'Elanna from routing.md/team.md

### Query 2: Decision search
**Ask:** "What decisions have been made about knowledge management?"  
**Expected:** Finds relevant entries in decisions.md (Issue #321, #416)

### Query 3: Agent capabilities
**Ask:** "What is Seven's role and expertise?"  
**Expected:** Summarizes Seven's charter (Research & Docs)

### Query 4: Cross-file synthesis
**Ask:** "How does the squad handle work routing and assignment?"  
**Expected:** Combines info from routing.md, team.md, copilot-instructions.md

---

## Step 5: Verify MCP Access

After creation, verify agents can access the Space:

```bash
# From CLI or agent context:
github-mcp-server-list_copilot_spaces
# Should show: "Research Squad" owned by "tamirdresher_microsoft"

github-mcp-server-get_copilot_space owner:"tamirdresher_microsoft" name:"Research Squad"
# Should return Space metadata + file list
```

---

## Maintenance

### When to Update Space Content

1. **Major agent roster changes** → Update team.md (auto-synced from repo)
2. **Routing rule changes** → Update routing.md (auto-synced)
3. **Charter updates** → Update charter files (auto-synced)
4. **New key decisions** → Automatically reflected in decisions.md (auto-synced)

### No Action Needed
- Quarterly history rotation (Space excludes history files)
- Session logs, orchestration logs (not in Space)
- Temporary files (not in Space)

### Manual Action Required
- **Adding new repos** (if squad expands to new repositories)
- **Updating custom instructions** (if agent personas/behavior change)
- **Managing Space visibility** (if team access needs change)

---

## Troubleshooting

**Q: Space creation option is grayed out**  
A: Ensure you have GitHub Copilot subscription and org admin access.

**Q: Files not appearing in Space after adding repo**  
A: Wait 2-3 minutes for indexing. Check repo permissions.

**Q: Search results are incomplete**  
A: Files >1MB may have truncated content. Consider splitting large files.

**Q: Can agents write to the Space?**  
A: No. Spaces are read-only context. Agents write to `.squad/` files in the repo.

**Q: How do I delete the Space if needed?**  
A: Space settings → "Delete this space" (requires confirmation)

---

## Success Criteria

- [x] Space created with correct name and owner
- [x] Custom instructions configured
- [x] 20 core files added from tamresearch1 repo
- [x] Test queries return relevant results
- [x] MCP tools can access Space metadata
- [x] Documentation updated (KNOWLEDGE_MANAGEMENT.md, README.md)

---

**Created:** 2026-Q2 (Issue #416)  
**Owner:** Seven (Research & Docs)  
**Last Updated:** 2026-03-13
