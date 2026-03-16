# Chrome DevTools MCP Skill

## Overview

Chrome DevTools MCP (Model Context Protocol) is a server integration that allows AI agents (and other MCP clients) to connect directly to Chrome DevTools for remote debugging, inspecting live browser sessions, and accessing DevTools capabilities programmatically.

**Repository:** [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)  
**Latest Feature:** Auto-connect to active Chrome sessions (Chrome 144+)

---

## Capability Summary

### What It Does

Chrome DevTools MCP enables:

1. **Live Browser Session Debugging**
   - Connect to active Chrome instances without needing separate browser profiles
   - Access DevTools data while browser is running (Elements, Network, Console, Performance)
   - Programmatic access to inspection results via MCP protocol

2. **Automated Web Debugging**
   - Inspect DOM elements by reference
   - Analyze network requests and responses
   - Capture performance metrics
   - Read console output and errors
   - Execute JavaScript in page context

3. **Hybrid Manual + AI Debugging**
   - Developer manually inspects a page in DevTools
   - Dev selects an Element or Network request
   - Dev asks AI agent (via MCP) to investigate that specific context
   - AI operates within the already-opened DevTools session

### Core Features (Chrome 144+)

- **Auto-connect:** MCP server uses `--autoConnect` flag to request debugging session from running Chrome
- **Permission-based:** Chrome shows user a dialog confirming each MCP connection request (security)
- **Multi-session support:** Can run multiple Chrome instances with separate debugging sessions
- **DevTools panel integration:** Elements and Network panels support "Investigate with AI" actions

---

## Squad Fit Assessment

### ✅ Strengths

1. **Complements Playwright Perfectly**
   - Playwright excels at **automation** (filling forms, clicking, navigation)
   - Chrome DevTools MCP excels at **debugging** (inspecting state, network analysis, performance)
   - Together: automate workflows + debug them in-session
   - Different from Playwright's capabilities — fills a gap

2. **Web Debugging Use Cases**
   - Debugging failed Playwright tests by inspecting live browser state
   - Performance analysis of web applications
   - Network debugging (inspecting requests/responses)
   - DOM inspection for complex UI issues
   - Authentication debugging (seeing actual requests)

3. **Low Setup Cost**
   - Lightweight npm package: `npx chrome-devtools-mcp@latest`
   - No additional browser plugins or extensions needed
   - Works with existing Chrome installations
   - Single MCP config entry

4. **Development Workflow Enhancement**
   - Reduces context-switching between manual DevTools and automation
   - Enables "I was debugging this, now let AI investigate" workflows
   - Useful for squad members writing and debugging test automation

5. **Minimal Overlap**
   - Does **not** duplicate Playwright CLI skill
   - Playwright CLI = browser automation & web testing
   - Chrome DevTools MCP = live debugging & inspection

### ⚠️ Limitations & Considerations

1. **Chrome 144+ Requirement**
   - Auto-connect feature requires Chrome beta/latest
   - Older Chrome versions still supported via manual profiling
   - Could be blocker for some environments

2. **Chrome-Only**
   - Does not work with Safari, Firefox, or Edge
   - Limits scope to web applications tested in Chrome

3. **DevTools Panel Integration Not Yet Complete**
   - Only Elements and Network panels currently exposed
   - Chrome blog mentions "we plan to show more panel data progressively"
   - May be limited initially for direct MCP access

4. **Security & User Consent**
   - Requires user to explicitly allow each debugging session
   - Shows "Chrome is being controlled by test software" banner
   - Not suitable for fully headless/unattended workflows

5. **Early Adoption**
   - Published December 2025 (very recent)
   - GitHub repo is relatively new
   - Community adoption TBD

---

## Technical Integration

### Installation & Configuration

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "chrome-devtools-mcp@latest",
        "--autoConnect"
      ]
    }
  }
}
```

### Requirements

- Node.js (for npx)
- Chrome browser (version 144+ for auto-connect)
- Chrome Remote Debugging enabled: Navigate to `chrome://inspect/#remote-debugging` and enable

### Prerequisites for Use

1. Enable Remote Debugging in Chrome: `chrome://inspect/#remote-debugging`
2. Start Chrome normally (not headless)
3. MCP server will request connection permission via dialog

---

## Recommendation for Squad

### ✅ **RECOMMENDED: Add to MCP Config**

**Verdict:** Chrome DevTools MCP is a **high-value, low-cost addition** that meaningfully extends the squad's capabilities for web debugging and test automation troubleshooting.

**Rationale:**
- Complements existing Playwright setup (no overlap)
- Solves real debugging workflows: "inspect live browser + ask AI to investigate"
- Lightweight integration (~1 line in MCP config)
- Early-stage tool with upside potential as Chrome DevTools panel integration expands
- No performance penalty (only activates when explicitly invoked)

### Implementation Approach

1. **Add to MCP Config**
   - File: `.copilot/mcp-config.json`
   - Add chrome-devtools server with `--autoConnect` flag
   - Enable in next squad session

2. **Create Skill Documentation** ← This document

3. **Document Use Cases in Squad Knowledge**
   - Add to `.squad/knowledge/` or decision tracker
   - When to use Chrome DevTools MCP vs. Playwright
   - Example workflows

4. **Soft Launch & Feedback**
   - Enable for Playwright-heavy work (Data, @copilot)
   - Gather feedback on utility
   - Document any gotchas

---

## Use Case Examples

### Scenario 1: Debugging Failed Test
```
Developer runs Playwright test → test fails on complex assertion
Developer opens Chrome DevTools MCP
→ "Inspect the DOM at selector #widget-container"
→ MCP returns actual DOM structure, classes, computed styles
→ AI suggests why selector failed
→ Developer fixes selector and reruns test
```

### Scenario 2: Network Request Debugging
```
Web app making unexpected API calls
Developer captures network trace in DevTools
Developer asks MCP: "What requests failed with 401?"
MCP returns failed requests, status codes, headers
Developer identifies auth token issue
```

### Scenario 3: Performance Analysis
```
Web app slow on production
Developer navigates to page in Chrome
Asks MCP: "Get performance metrics for this page"
MCP returns timing data (FCP, LCP, CLS, etc.)
Developer identifies bottleneck
```

---

## Related Skills

- **Playwright CLI** (`.squad/skills/playwright-cli/SKILL.md`) — Web automation & testing
- **Web Testing Patterns** — Integration of debugging + automation workflows

---

## References

- **Blog Post:** [Chrome DevTools MCP: Debug Your Browser Session](https://developer.chrome.com/blog/chrome-devtools-mcp-debug-your-browser-session) (Dec 2025)
- **GitHub Repo:** [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- **Chrome Remote Debugging:** [Docs](https://developer.chrome.com/docs/devtools/remote-debugging)

---

## Status

- **Evaluation Date:** March 2026
- **Recommended:** YES
- **Squad Member:** Seven (Research & Docs)
- **Decision:** Approved for MCP config integration
