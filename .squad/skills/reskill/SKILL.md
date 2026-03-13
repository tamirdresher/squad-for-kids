# Skill: Reskill — Charter Optimization
**Confidence:** low
**Domain:** team-management, knowledge-architecture
**Last validated:** 2026-03-13

## Context
Documents the process for extracting procedural knowledge from agent charters into shared skills, keeping charters slim (<1.5KB) and focused on identity + behavior.

## Pattern

### When to Reskill
- Any charter exceeding ~1.5KB
- Charter contains step-by-step procedures, code snippets, or detailed checklists
- Multiple agents share similar procedures (DRY principle)
- Charter has sections better served as reusable skills

### What Stays in a Charter
- **Identity:** Name, role, expertise, style (2-3 lines)
- **What I Own:** Bullet list of responsibilities
- **How I Work:** 3-5 behavioral rules max
- **Boundaries:** Concise scope definition
- **Model:** Preferred model + rationale
- **Collaboration:** Decision inbox conventions
- **Skill References:** Pointers to extracted skills

### What Gets Extracted to Skills
- Step-by-step procedures (workflows, pipelines)
- Code snippets and templates
- Checklists and output format templates
- Detailed style guides or humor guidelines
- Tool-specific instructions (Playwright, COM, webhook)

### Extraction Process
1. Measure all charter sizes: `Get-ChildItem .squad/agents/*/charter.md | ForEach-Object { "$($_.Directory.Name): $($_.Length) bytes" }`
2. Read each oversized charter, identify extractable sections
3. Check existing skills to avoid duplication
4. Create new skill files at `.squad/skills/{skill-name}/SKILL.md`
5. Edit charters: replace extracted content with `See .squad/skills/{name}/SKILL.md`
6. Re-measure to confirm <1.5KB
7. Report metrics: before/after sizes, skills created, bytes saved

### Skill File Format
```markdown
# Skill: {Name}
**Confidence:** low
**Domain:** {domain}
**Last validated:** {date}

## Context
{why this skill exists}

## Pattern
{the extracted procedure/checklist}
```

### Anti-Patterns
- Don't strip agent personality or identity — those stay in the charter
- Don't create skills only one agent will ever use (unless the charter is very large)
- Don't duplicate existing skills — extend them instead
- Don't make charters so thin they lose meaning
