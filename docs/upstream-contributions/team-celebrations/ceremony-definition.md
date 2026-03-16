# Ceremony: Daily Celebrations Check

> Check for team birthdays, work anniversaries, and milestones — deliver personalized messages to the celebrations channel.

## Ceremony Metadata

| Field | Value |
|-------|-------|
| **Name** | Daily Celebrations Check |
| **Trigger** | Every morning, at start of Ralph watch cycle |
| **Frequency** | Daily |
| **Channel** | `CHANNEL: wins` |
| **Owner** | Ralph (Work Monitor) |
| **Participants** | All opted-in team members |

## When

This ceremony runs **every morning at the start of Ralph's watch cycle**.

It should be one of the first checks Ralph performs — celebrations set a positive tone for the day.

### Schedule

```
Trigger: Ralph watch cycle start
Frequency: Daily (every watch cycle)
Time: Morning (first check in the cycle)
Skip: Never — even quiet days deserve a check
```

## What

### Step 1: Load Team Data

Read `.squad/team-data/members.json` and filter to members where `optedIn == true`.

If the file doesn't exist or has no opted-in members, log a note and exit gracefully:

```
No team members opted in for celebrations. Skipping celebrations check.
```

### Step 2: Check for Upcoming Celebrations

For each opted-in member, check if any celebrations fall within the **next 7 days** (configurable lookahead window):

#### Birthday Check
```
IF member.birthday is set
AND member.celebrationPreferences.birthdayMessage != false
AND MM-DD of member.birthday falls within [today .. today + 7 days]
AND no birthday celebration delivered for this member this year
THEN -> Queue birthday celebration
```

#### Anniversary Check
```
IF member.startDate is set
AND member.celebrationPreferences.anniversaryMessage != false
AND MM-DD of member.startDate falls within [today .. today + 7 days]
AND no anniversary celebration delivered for this member this year
THEN -> Queue anniversary celebration (calculate years from startDate)
```

#### Milestone Check
```
IF member.celebrationPreferences.milestoneMessage != false
AND member has reached a configured milestone threshold
AND this milestone has not been celebrated yet
THEN -> Queue milestone celebration
```

### Step 3: Generate Messages

For each queued celebration, generate a personalized message:

1. **Select template** — Choose from `birthday-message.md`, `anniversary-message.md`, or `milestone-message.md`
2. **Substitute variables** — Replace `{{name}}`, `{{years}}`, `{{milestone}}`, `{{date}}`, `{{team}}` with actual values
3. **Optional AI enhancement** — If WorkIQ or similar is available, enhance the message with contextual personalization (recent accomplishments, team contributions)
4. **Format for delivery** — Wrap in the celebration message format with appropriate emoji

### Step 4: Deliver

Post each celebration message to the configured channel:

```
CHANNEL: wins
```

#### Delivery Format

```markdown
**Happy Birthday, {{name}}!**

{{generated_message}}

— Your Squad
```

```markdown
**Happy Work Anniversary, {{name}}!**

{{generated_message}}

— Your Squad
```

```markdown
**Milestone Achieved — {{name}}!**

{{generated_message}}

— Your Squad
```

### Step 5: Record Delivery

Update `.squad/team-data/.celebrations-state.json` to prevent duplicate celebrations:

```json
{
  "memberId": "member-id",
  "type": "birthday",
  "date": "2025-03-15",
  "deliveredAt": "2025-03-14T09:00:00Z"
}
```

## Action Summary

```
Daily Celebrations Check:
  1. Load members.json -> filter opted-in members
  2. Check each member for celebrations in next 7 days
  3. Generate personalized message for each celebration
  4. Deliver to CHANNEL: wins
  5. Record delivery to prevent duplicates
  6. Log summary: "N celebrations today" or "No celebrations this week"
```

## Error Handling

| Scenario | Action |
|----------|--------|
| `members.json` missing | Log info, skip check, continue watch cycle |
| `members.json` malformed | Log warning, skip check, continue watch cycle |
| Delivery fails | Log error, retry once, then queue for next cycle |
| State file locked | Wait briefly, retry, continue if unavailable |

## Example Ralph Log Output

```
[Ralph] Celebrations Check — Start
[Ralph] Found 12 opted-in team members
[Ralph] Birthday upcoming: Alex (March 15)
[Ralph] Anniversary upcoming: Jordan (3 years — March 17)
[Ralph] 2 celebrations queued for delivery
[Ralph] Delivered 2 celebrations to #wins
[Ralph] Celebrations Check — Complete
```

## Customization

Teams can customize this ceremony:

| Setting | Default | Options |
|---------|---------|---------|
| Lookahead days | 7 | 1-30 |
| Delivery channel | `wins` | Any configured channel |
| Delivery method | Teams | Teams, email, webhook, custom |
| Message style | Template | Template, AI-generated, custom |
| Milestone thresholds | See SKILL.md | Any numeric thresholds |
| Include weekends | Yes | Yes/No |

---

*Starting the day with a celebration is the best way to remind your team that the humans matter more than the code.*
