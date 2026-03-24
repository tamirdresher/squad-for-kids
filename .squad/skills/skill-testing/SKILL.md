# Skill: Skill Testing

## Purpose
Test Squad skills end-to-end before shipping them to the team. Catches trigger failures, typos in queries/scripts, missing dependencies, and broken flows — before anyone else hits them.

**Credit:** Based on a tip from Assaf Akiva.

## When to Use
- After creating or modifying any skill in `.squad/skills/`
- After updating an agent charter that references skills
- Before committing skill changes to the repo
- When debugging a skill that's reported as broken

## Testing Approaches

### 1. Quick Trigger Test
Verify the skill triggers correctly when described in a prompt:

```bash
# Copilot CLI — test that a skill triggers and produces output
copilot -p "generate OCE report" --allow-tool='shell(git)' --allow-tool='kusto-tools'

# Claude Code equivalent
claude -p "generate OCE report" --allowedTools "mcp__kusto-tools__execute_query,Read" --verbose
```

### 2. Safe End-to-End Test
Allow all tools but block destructive commands:

```bash
# Allow everything except dangerous operations
copilot -p "review and fix the auth module" \
  --allow-all-tools \
  --deny-tool='shell(rm)' \
  --deny-tool='shell(git push)' \
  --deny-tool='shell(git commit)'
```

### 3. Force-Inject a Skill
If the skill didn't auto-trigger, force-inject it:

```bash
# Inject the skill file directly into the system prompt
claude -p "show dashboard" \
  --append-system-prompt-file .squad/skills/my-skill/SKILL.md \
  --allowedTools "Read"
```

### 4. Skip All Permissions (Local Only)
For quick local iteration — never use in shared environments:

```bash
claude -p "check active incidents" --dangerously-skip-permissions
```

## Testing Checklist

When testing a skill, verify:

1. **Trigger** — Does the skill activate when expected keywords/scenarios are mentioned?
2. **Prerequisites** — Are all required tools/CLIs/APIs available?
3. **Happy path** — Does the main flow produce correct output?
4. **Error handling** — What happens when a dependency is missing or an API fails?
5. **Output format** — Is the output clean and useful, not raw debug noise?
6. **Idempotency** — Can the skill be run twice without breaking things?

## How to Test a Skill (Step by Step)

### For the Coordinator (Squad)

When you create or modify a skill, run this verification before committing:

```
1. Read the SKILL.md you just wrote
2. Identify the trigger phrases/scenarios
3. Compose a test prompt that should trigger the skill
4. Run it with copilot -p or claude -p with appropriate tool permissions
5. Verify:
   - Skill was triggered (check output for skill-specific behavior)
   - No errors or unhandled exceptions
   - Output matches expected format
   - Any external calls (APIs, CLIs) succeeded
6. If it fails, fix and re-test
7. Only then commit
```

### Test Prompt Template

```bash
# Replace {SKILL_NAME} and {TEST_PROMPT} with your skill details
copilot -p "{TEST_PROMPT}" \
  --allow-tool='shell(cat)' \
  --allow-tool='shell(ls)' \
  --allow-tool='shell(grep)' \
  --allow-all-tools
```

## Examples

### Testing the blog-publishing skill
```bash
copilot -p "publish my latest blog post about Kind Aspire" \
  --allow-all-tools \
  --deny-tool='shell(git push)'
```

### Testing the tts-conversion skill
```bash
copilot -p "convert EXECUTIVE_SUMMARY.md to audio" \
  --allow-tool='shell(edge-tts)' \
  --allow-tool='shell(ffmpeg)'
```

### Testing the teams-monitor skill
```bash
copilot -p "check my Teams messages from today" \
  --allow-all-tools
```

## Common Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Skill doesn't trigger | SKILL.md not in right path or trigger words too specific | Move to `.squad/skills/{name}/SKILL.md`, broaden trigger description |
| "Command not found" | CLI dependency not installed | Add prerequisite check to SKILL.md |
| Auth failure | Token expired or wrong account | Add auth verification step to skill |
| Empty output | API returned no data | Add error handling for empty responses |
| Wrong tool called | Skill description too vague | Be more specific in SKILL.md about which tools to use |
