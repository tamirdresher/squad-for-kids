## Evaluation Summary: Chrome DevTools MCP for Squad

### Research Findings

Evaluated Chrome DevTools MCP — a new Model Context Protocol server (published December 2025) that allows AI agents to connect directly to Chrome DevTools for remote debugging and browser session inspection.

### Key Capabilities

1. **Live Browser Debugging** — Connect to running Chrome instances, inspect DOM, analyze network, capture performance metrics
2. **Automated Web Debugging** — Programmatic access to DevTools data (Elements, Network, Console)
3. **Hybrid Manual + AI Workflow** — Developer manually inspects in DevTools, then asks AI to investigate specific context
4. **Auto-connect Feature (Chrome 144+)** — MCP server can request debugging session with user consent

### Fit with Squad

✅ **EXCELLENT FIT:**
- **Complements Playwright** — No overlap. Playwright = automation, Chrome DevTools MCP = debugging
- **Solves Real Workflows** — "I was debugging this in DevTools, now let AI investigate"
- **Low Setup Cost** — One npm package, single MCP config entry
- **Minimal Risk** — Only activates when explicitly invoked

### Limitations Identified

- Chrome-only (no Safari, Firefox, Edge support)
- Requires Chrome 144+ for auto-connect (beta/latest only)
- Requires user consent per debugging session (not headless-friendly)
- Early-stage tool (published Dec 2025, community adoption TBD)
- DevTools panel integration still expanding

### Recommendation

**✅ APPROVED** — Add to squad's MCP config

**Why:**
- Fills genuine debugging gap alongside Playwright automation
- Lightweight integration with no performance penalty
- High upside as Chrome DevTools panel support expands
- Perfect for Data, @copilot working on web tests

### Next Steps

1. Add `chrome-devtools` to `.copilot/mcp-config.json` with `--autoConnect` flag
2. Update squad knowledge with debugging workflow patterns
3. Soft launch with Playwright-heavy team members
4. Document gotchas (Chrome version, remote debugging setup)

### Documentation

Full evaluation and use cases documented in: `.squad/skills/chrome-devtools-mcp/SKILL.md`
