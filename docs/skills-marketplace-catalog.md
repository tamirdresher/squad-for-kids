# Squad Skills Marketplace Catalog

> Research report for publishing generalized skills to [tamirdresher/squad-skills](https://github.com/tamirdresher/squad-skills).
>
> Issue: #685 · Date: 2025-07-14

---

## Executive Summary

We cataloged **30 skills** in `.squad/skills/`. Of those, **14 are strong marketplace candidates**, **8 are partially generalizable** (need config extraction), and **8 are team-specific** (not suitable without major rework).

The marketplace repo already contains **10 plugins**: cross-machine-coordination, fact-checking, github-distributed-coordination, github-multi-account, github-project-board, news-broadcasting, outlook-automation, reflect, teams-monitor, teams-ui-automation.

This report identifies which local skills are **new** vs already published, proposes a `manifest.json` schema for universal skill packaging, and details the modifications needed for each candidate.

---

## Table of Contents

1. [Full Skills Inventory](#full-skills-inventory)
2. [Marketplace Candidates — Tier 1 (Publish As-Is)](#tier-1--publish-as-is)
3. [Marketplace Candidates — Tier 2 (Needs Generalization)](#tier-2--needs-generalization)
4. [Not Suitable for Marketplace](#not-suitable-for-marketplace)
5. [Already Published (Overlap Check)](#already-published-overlap-check)
6. [Manifest Schema Proposal](#manifest-schema-proposal)
7. [Modifications Required per Skill](#modifications-required-per-skill)
8. [Recommended Publishing Order](#recommended-publishing-order)

---

## Full Skills Inventory

| # | Skill | Category | Generalizable | Already in Marketplace | Recommendation |
|---|-------|----------|---------------|----------------------|----------------|
| 1 | api-gap-documentation | Methodology | ✅ High | ❌ No | **Publish** |
| 2 | azure | Cloud Ops | ✅ High | ❌ No | **Publish** |
| 3 | blog-publishing | Content | ⚠️ Partial | ❌ No | Templatize |
| 4 | cli-tunnel | Tooling | ✅ High | ❌ No | **Publish** |
| 5 | configgen-support-patterns | Internal SDK | ❌ Low | ❌ No | Skip |
| 6 | cross-machine-coordination | Coordination | ✅ High | ✅ Yes | Update existing |
| 7 | devbox-provisioning | Cloud Ops | ⚠️ Partial | ❌ No | Templatize |
| 8 | dk8s-support-patterns | Internal Platform | ❌ Low | ❌ No | Skip |
| 9 | dotnet-build-diagnosis | Build/CI | ✅ High | ❌ No | **Publish** |
| 10 | fact-checking | Methodology | ✅ High | ✅ Yes | Update existing |
| 11 | github-account-switching | Git Workflow | ❌ Low | ❌ No | Skip |
| 12 | github-distributed-coordination | Coordination | ✅ High | ✅ Yes | Update existing |
| 13 | github-project-board | Project Mgmt | ⚠️ Partial | ✅ Yes | Update existing |
| 14 | image-generation | Content | ✅ High | ❌ No | **Publish** |
| 15 | incident-response | Ops | ✅ High | ❌ No | **Publish** |
| 16 | kids-study-assistant | Education | ⚠️ Partial | ❌ No | Skip (niche) |
| 17 | news-broadcasting | Comms | ⚠️ Partial | ✅ Yes | Update existing |
| 18 | outlook-automation | Comms | ✅ High | ✅ Yes | Update existing |
| 19 | outlook-web-workflows | Comms | ✅ High | ❌ No | **Publish** |
| 20 | personal-email-access | Comms | ✅ High | ❌ No | **Publish** |
| 21 | reflect | Learning | ⚠️ Partial | ✅ Yes | Update existing |
| 22 | reskill | Meta | ✅ High | ❌ No | **Publish** |
| 23 | secrets-management | Security | — (missing) | ❌ No | Skip |
| 24 | session-recovery | Recovery | ✅ High | ❌ No | **Publish** |
| 25 | squad-conventions | Internal | ❌ Low | ❌ No | Skip |
| 26 | squad-email | Comms | ⚠️ Partial | ❌ No | Templatize |
| 27 | teams-monitor | Comms | ⚠️ Partial | ✅ Yes | Update existing |
| 28 | teams-ui-automation | Automation | ✅ High | ✅ Yes | Update existing |
| 29 | tts-conversion | Audio | ✅ High | ❌ No | **Publish** |
| 30 | voice-writing | Content | ❌ Low | ❌ No | Skip |

---

## Tier 1 — Publish As-Is

These skills are platform-agnostic, contain no team-specific secrets or config, and provide immediate value to any squad.

### 1. api-gap-documentation

**What it does:** Pattern for handling missing APIs — when expected programmatic access doesn't exist and manual UI workarounds are required. Provides a 5-step documentation process: confirm the gap, document manual steps, prepare integration artifacts, create programmatic access layers, establish maintenance protocols.

**Why publish:** Every team hits API gaps. This turns frustration into a systematic knowledge capture process.

**Modifications needed:** None. Already written as a generic methodology.

---

### 2. azure (6 sub-skills)

**What it does:** Azure operational skill pack covering production troubleshooting, RBAC management, compliance checks, cost optimization, resource discovery, and deployment orchestration. Based on Microsoft's official Azure Skills Plugin.

**Why publish:** Core Azure operations that every cloud-native team needs. Well-structured and battle-tested.

**Modifications needed:** Ensure `AZURE_SUBSCRIPTION_ID` is parameterized, not hardcoded. Package as a skill bundle with individual sub-skills.

---

### 3. cli-tunnel

**What it does:** Documentation for tunneling CLI apps to phones/browsers/remote displays using Microsoft Dev Tunnels. Covers terminal sharing, live recording, interactive remote sessions with QR codes, and hub mode for multi-session dashboards.

**Why publish:** Remote CLI access is a universal need. Dev Tunnels works across all platforms.

**Modifications needed:** None.

---

### 4. dotnet-build-diagnosis

**What it does:** Systematic .NET build failure diagnosis — clean builds, error categorization, package resolution, .csproj inspection, duplicate file detection. Includes real-world example of resolving 64 build errors.

**Why publish:** Every .NET team deals with build failures. This provides a repeatable triage process.

**Modifications needed:** None. Already generic.

---

### 5. image-generation

**What it does:** Comprehensive guide for AI image generation using Copilot CLI — text-based graphics (Mermaid, SVG, ASCII), Azure OpenAI DALL-E 3, and MCP servers. Covers Microsoft-approved sources and detailed workflows.

**Why publish:** Visual content generation is a growing need. This consolidates scattered approaches into one reference.

**Modifications needed:** Make Azure OpenAI endpoint configurable. Document alternative providers (OpenAI direct, Stability AI).

---

### 6. incident-response

**What it does:** First-check pattern — verify Azure Status page before assuming a local issue. Distinguishes platform outages from application bugs during incidents.

**Why publish:** Simple but high-value. Prevents wasted debugging time during Azure outages.

**Modifications needed:** Add configurable status URLs for AWS and GCP alternatives.

---

### 7. outlook-web-workflows

**What it does:** Playwright-based Outlook web automation for macOS/Linux/no-desktop scenarios. Covers meeting creation, email sending via web interface, with a decision tree for COM vs web approaches.

**Why publish:** Cross-platform Outlook automation. Fills the gap when COM automation isn't available.

**Modifications needed:** None. Already platform-aware.

---

### 8. personal-email-access

**What it does:** Multiple approaches for programmatic Gmail access — IMAP with App Passwords (recommended), Gmail API with OAuth2, Google Apps Script. Covers credential storage via Windows Credential Manager.

**Why publish:** Email integration is a common need. This provides a security-first approach.

**Modifications needed:** Add cross-platform credential storage (macOS Keychain, Linux secret-tool alongside Windows Credential Manager).

---

### 9. reskill

**What it does:** Meta-skill for extracting procedural knowledge from agent charters into shared skills. Identifies bloated charters (>1.5KB) and provides systematic extraction methodology.

**Why publish:** Essential for any team scaling their agent framework. Prevents charter sprawl.

**Modifications needed:** Generalize file paths from `.squad/` to configurable root.

---

### 10. session-recovery

**What it does:** Find and resume accidentally closed Copilot CLI sessions by querying the `session_store` SQLite database. Includes SQL queries, topic search, and context recovery from checkpoints.

**Why publish:** Session loss is a universal pain point. This turns it into a 30-second recovery.

**Modifications needed:** Remove Ralph-specific filtering. Make agent exclusion list configurable.

---

### 11. tts-conversion

**What it does:** Markdown-to-audio conversion using Edge TTS (free, no API key) with migration path to Azure AI Speech Service. Provides accessibility and audio summary capabilities.

**Why publish:** Document-to-audio conversion is broadly useful for accessibility and content consumption.

**Modifications needed:** Remove references to specific GitHub issues. Generalize script paths.

---

## Tier 2 — Needs Generalization

These skills have valuable patterns but contain team-specific configuration that needs to be extracted into parameters.

### 12. blog-publishing

**Core pattern:** Multi-account GitHub workflow for publishing content to a static site.

**What to generalize:** Replace hardcoded accounts (`tamirdresher`, `tamirdresher_microsoft`) with config variables. Make blog repo URL configurable. Extract the workflow pattern from the specific account setup.

**Marketplace value:** Medium — useful for teams with blog-from-repo workflows.

---

### 13. devbox-provisioning

**Core pattern:** Natural language → Azure DevBox provisioning via Bicep templates and PowerShell.

**What to generalize:** Replace specific Dev Center names and machine references with config parameters. Keep the NL interpretation layer and Bicep template structure.

**Marketplace value:** High — DevBox adoption is growing across Microsoft.

---

### 14. news-broadcasting

**Core pattern:** Structured squad activity reporting via messaging platforms (Teams/Slack/Discord).

**What to generalize:** Replace Teams webhook with configurable notification backend. Remove Star Trek references as default (make them optional themes). Extract format templates.

**Marketplace value:** High — every team wants activity digests.

---

### 15. squad-email

**Core pattern:** SMTP email automation with credential management for agent-initiated communications.

**What to generalize:** Replace hardcoded email address with config. Abstract credential storage beyond Windows Credential Manager. Keep the SMTP patterns and templates.

**Marketplace value:** Medium — useful for teams needing email automation without Outlook COM.

---

### 16. reflect

**Core pattern:** Learning capture system that extracts confidence-rated patterns from conversations to prevent repeated mistakes.

**What to generalize:** Replace squad-specific file paths with configurable output locations. Remove specific agent name references (Picard, Scribe).

**Marketplace value:** High — continuous learning is universally valuable.

---

### 17. teams-monitor

**Core pattern:** Teams channel → GitHub issue bridge with deduplication and actionable message filtering.

**What to generalize:** Replace team-specific keywords (DK8S, idk8s) with configurable topic list. Remove person-specific references. Make polling interval configurable.

**Marketplace value:** High — Teams-to-GitHub bridging is a common need.

---

### 18. github-project-board

**Core pattern:** GitHub Projects V2 lifecycle management — column transitions, label sync, status tracking.

**What to generalize:** Replace hardcoded project ID and field IDs with config. Keep the state machine and sync logic.

**Marketplace value:** High — every team using GitHub Projects can benefit.

---

## Not Suitable for Marketplace

| Skill | Reason |
|-------|--------|
| configgen-support-patterns | Microsoft-internal ConfigGen SDK specific |
| dk8s-support-patterns | Microsoft-internal DK8S platform specific |
| github-account-switching | Hardcoded to specific user accounts |
| kids-study-assistant | Niche personal use case |
| squad-conventions | Squad CLI codebase-specific coding standards |
| voice-writing | Single person's writing voice profile |
| secrets-management | Directory exists but contains no skill file |

---

## Already Published (Overlap Check)

These skills already exist in `tamirdresher/squad-skills/plugins/`. Action: sync local improvements back to the marketplace.

| Marketplace Plugin | Local Skill | Sync Action |
|--------------------|-------------|-------------|
| cross-machine-coordination | cross-machine-coordination | Diff and merge updates |
| fact-checking | fact-checking | Diff and merge updates |
| github-distributed-coordination | github-distributed-coordination | Diff and merge updates |
| github-multi-account | github-account-switching | Different approach — keep both |
| github-project-board | github-project-board | Diff and merge updates |
| news-broadcasting | news-broadcasting | Diff and merge updates |
| outlook-automation | outlook-automation | Diff and merge updates |
| reflect | reflect | Diff and merge updates |
| teams-monitor | teams-monitor | Diff and merge updates |
| teams-ui-automation | teams-ui-automation | Diff and merge updates |

---

## Manifest Schema Proposal

Every marketplace skill should include a `manifest.json` that makes it discoverable, configurable, and platform-agnostic.

```json
{
  "$schema": "https://squad-skills.github.io/schema/v1/manifest.json",
  "name": "tts-conversion",
  "version": "1.0.0",
  "description": "Convert markdown documents to audio using Text-to-Speech",
  "category": "audio",
  "tags": ["tts", "accessibility", "audio", "podcast", "edge-tts"],

  "author": {
    "name": "Tamir Dresher",
    "github": "tamirdresher"
  },

  "platforms": {
    "compatible": ["copilot-cli", "claude-code", "cursor", "aider", "custom"],
    "tested": ["copilot-cli"]
  },

  "requirements": {
    "os": ["windows", "macos", "linux"],
    "runtime": ["python3"],
    "tools": ["pip"],
    "packages": ["edge-tts"],
    "mcp_servers": []
  },

  "config": {
    "output_dir": {
      "type": "string",
      "description": "Directory for generated audio files",
      "default": "./output/audio"
    },
    "voice": {
      "type": "string",
      "description": "Edge TTS voice identifier",
      "default": "en-US-AriaNeural"
    },
    "azure_speech_key": {
      "type": "string",
      "description": "Azure AI Speech key (optional, for production quality)",
      "secret": true,
      "required": false
    }
  },

  "triggers": {
    "keywords": ["convert to audio", "generate podcast", "text to speech", "tts"],
    "file_patterns": ["*.md", "*.txt"],
    "commands": ["/tts", "/podcast"]
  },

  "entry_point": "SKILL.md",
  "files": ["SKILL.md", "scripts/tts-convert.py"],

  "license": "MIT"
}
```

### Schema Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Unique skill identifier (kebab-case) |
| `version` | string | ✅ | Semver version |
| `description` | string | ✅ | One-line description |
| `category` | string | ✅ | One of: `audio`, `automation`, `cloud-ops`, `comms`, `content`, `coordination`, `methodology`, `meta`, `security`, `build-ci` |
| `tags` | string[] | ✅ | Searchable tags |
| `author` | object | ✅ | Name and GitHub handle |
| `platforms.compatible` | string[] | ✅ | AI platforms this works with |
| `platforms.tested` | string[] | ✅ | Platforms verified by author |
| `requirements.os` | string[] | ❌ | Supported operating systems |
| `requirements.runtime` | string[] | ❌ | Required runtimes (python3, node, dotnet) |
| `requirements.tools` | string[] | ❌ | CLI tools needed |
| `requirements.packages` | string[] | ❌ | Packages to install |
| `requirements.mcp_servers` | string[] | ❌ | MCP servers used |
| `config` | object | ❌ | Configurable parameters with types, defaults, and secret flags |
| `triggers.keywords` | string[] | ❌ | Natural language phrases that activate the skill |
| `triggers.file_patterns` | string[] | ❌ | File patterns that suggest this skill |
| `triggers.commands` | string[] | ❌ | Slash commands |
| `entry_point` | string | ✅ | Main instruction file |
| `files` | string[] | ✅ | All files in the skill package |
| `license` | string | ✅ | SPDX license identifier |

---

## Modifications Required per Skill

### New skills to publish (Tier 1)

| Skill | Effort | Key Changes |
|-------|--------|-------------|
| api-gap-documentation | 🟢 Low | Add manifest.json only |
| azure | 🟡 Medium | Bundle 6 sub-skills, parameterize subscription ID |
| cli-tunnel | 🟢 Low | Add manifest.json only |
| dotnet-build-diagnosis | 🟢 Low | Add manifest.json only |
| image-generation | 🟡 Medium | Parameterize Azure OpenAI endpoint, add provider alternatives |
| incident-response | 🟢 Low | Add multi-cloud status URLs, add manifest.json |
| outlook-web-workflows | 🟢 Low | Add manifest.json only |
| personal-email-access | 🟡 Medium | Add cross-platform credential storage docs |
| reskill | 🟢 Low | Generalize `.squad/` to configurable root |
| session-recovery | 🟢 Low | Make agent exclusion list configurable |
| tts-conversion | 🟢 Low | Remove issue references, add manifest.json |

### Tier 2 skills (generalize first)

| Skill | Effort | Key Changes |
|-------|--------|-------------|
| blog-publishing | 🟡 Medium | Extract account names to config, templatize repo URLs |
| devbox-provisioning | 🔴 High | Replace all Dev Center specifics, keep NL layer |
| news-broadcasting | 🟡 Medium | Configurable notification backend, optional themes |
| squad-email | 🟡 Medium | Abstract email address and credential storage |
| reflect | 🟡 Medium | Configurable output paths, remove agent name references |
| teams-monitor | 🟡 Medium | Configurable topic keywords and polling |
| github-project-board | 🟡 Medium | Parameterize project/field IDs |

---

## Recommended Publishing Order

Prioritized by: marketplace value × low effort × not already published.

| Priority | Skill | Rationale |
|----------|-------|-----------|
| 1 | tts-conversion | High demand, low effort, unique in marketplace |
| 2 | session-recovery | Universal pain point, low effort |
| 3 | dotnet-build-diagnosis | Large .NET community, ready to publish |
| 4 | reskill | Meta-skill that improves all other skills |
| 5 | api-gap-documentation | Unique methodology, zero changes needed |
| 6 | incident-response | High value, trivial to publish |
| 7 | image-generation | Growing demand, medium effort |
| 8 | cli-tunnel | Useful tooling, ready as-is |
| 9 | outlook-web-workflows | Fills cross-platform gap |
| 10 | personal-email-access | Common need, medium effort |
| 11 | azure | High value but already partially available elsewhere |

---

## Next Steps

1. **Create `manifest.json`** for top 5 priority skills
2. **Fork-and-PR workflow**: For each skill, create a PR to `tamirdresher/squad-skills` with the skill directory + manifest
3. **Sync existing plugins**: Diff local skills against marketplace versions and merge improvements
4. **CI validation**: Add a GitHub Action to the marketplace repo that validates `manifest.json` schema on PRs
5. **Discovery**: Update marketplace README with searchable skill index
