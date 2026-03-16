# Work Anniversary Message Template

> Template for generating work anniversary celebration messages. Celebrates the journey, not just the milestone.

## Template

```
**Happy Work Anniversary, {{name}}!**

{{years}} years on the squad! That's {{years}} years of contributions, collaboration, and making this team stronger. We're so glad you're here.

Here's to many more — this team is better because you're part of it.

— Your Squad
```

## Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{name}}` | Member's display name | Jordan |
| `{{years}}` | Number of years on the team | 3 |
| `{{date}}` | The anniversary date (Month Day) | January 10 |
| `{{team}}` | Team name (optional) | Squad Alpha |

## Year-Specific Variations

### Year 1 — The Newcomer Graduate
```
**One Year In — {{name}}!**

One year ago, {{name}} joined the squad — and we've been better for it ever since. From day one, you brought energy, fresh perspectives, and a willingness to dive in.

Congratulations on your first year. You're not the new person anymore — you're Squad.

— Your Squad
```

### Years 2-4 — The Core Contributor
```
**{{years}} Years Strong — {{name}}!**

{{years}} years. That's {{years}} years of PRs reviewed, problems solved, and teammates supported. {{name}}, you've become a cornerstone of this squad.

Thanks for sticking with us. The work we do is better because of you.

— Your Squad
```

### Year 5 — The Veteran
```
**Five Years! — {{name}}!**

Half a decade. FIVE YEARS. {{name}}, that's not just a milestone — that's a commitment to something meaningful.

You've seen this team evolve, grow, and tackle challenges that seemed impossible. And through all of it, you've been right here, making it happen.

Here's to five more. (At least.)

— Your Squad
```

### Year 10+ — The Legend
```
**{{years}} Years — {{name}}, You're a Legend!**

{{years}} years. Let that sink in. {{name}} has been making this squad extraordinary for a DECADE (and then some).

Thank you. Genuinely. This squad exists because of people like you.

— Your Squad
```

## AI Enhancement Prompt

If using AI to generate personalized messages, use this as a system prompt:

```
Generate a work anniversary message for {{name}} who is celebrating {{years}} years on the team.
The message should be:
- Celebratory and genuine
- Reference the duration meaningfully (not just "another year")
- 2-4 sentences
- Fun but respectful
- Acknowledge their contribution to the team
- Use emoji to add warmth
- Sign off as "Your Squad"

Tone: Like a team lead who genuinely appreciates this person's commitment.
Scale enthusiasm with tenure: Year 1 = welcoming, Year 5+ = deeply grateful.
```

## Rules

- **Celebrate the commitment** — Focus on what their tenure means to the team
- **Scale with tenure** — Year 1 is different from Year 10. Adjust tone accordingly.
- **No exact dates unless relevant** — "3 years" is better than "since January 10, 2022"
- **Acknowledge growth** — People evolve. The message should feel current, not historical.
- **Respect the opt-in** — Only send to members who have `optedIn: true` and `celebrationPreferences.anniversaryMessage: true`
