# Milestone Message Template

> Template for celebrating team member achievements — PRs merged, issues closed, and custom milestones.

## Template

```
**Milestone Achieved — {{name}}!**

{{name}} just hit a major milestone: **{{milestone}}**! 

That's not just a number — it's a whole lot of effort, care, and dedication to making things better. The squad sees you, and we're impressed.

Keep being awesome.

— Your Squad
```

## Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{name}}` | Member's display name | Sam |
| `{{milestone}}` | Description of the milestone | 100th PR merged |
| `{{count}}` | The numeric milestone value | 100 |
| `{{type}}` | Milestone category | pr_count |
| `{{team}}` | Team name (optional) | Squad Alpha |

## Milestone-Specific Variations

### PR Milestones

#### 10th PR
```
**Double Digits — {{name}}!**

{{name}} just merged their **10th PR**! You're officially in the flow now. That's 10 contributions to the codebase, 10 reviews, 10 times you made things better.

Welcome to double digits. It only gets better from here.

— Your Squad
```

#### 50th PR
```
**50 PRs Strong — {{name}}!**

FIFTY pull requests merged. {{name}}, that is some serious consistency. 50 times you wrote the code, addressed the feedback, and shipped the improvement.

The codebase thanks you. We thank you.

— Your Squad
```

#### 100th PR
```
**THE CENTURY CLUB — {{name}}!**

ONE HUNDRED PULL REQUESTS. {{name}}, welcome to the century club. That's 100 improvements, 100 reviews, 100 times you moved the needle.

This is the kind of sustained effort that defines great engineers. Seriously impressive.

— Your Squad
```

#### 500th PR
```
**500 PRs — {{name}}, That's Legendary!**

Five. Hundred. Pull requests. {{name}}, we're running out of ways to express how incredible that is.

500 contributions means 500 times the codebase got better. 500 reviews. 500 chances to improve. And you showed up for every single one.

Legend status: confirmed.

— Your Squad
```

### Issue Milestones

#### 25th Issue Closed
```
**25 Issues Down — {{name}}!**

{{name}} just closed their **25th issue**! That's 25 problems identified, investigated, and resolved. You're the reason things work better.

Keep squashing those bugs and shipping those features.

— Your Squad
```

#### 100th Issue Closed
```
**Triple Digits — {{name}} Closed 100 Issues!**

ONE HUNDRED issues closed. {{name}}, that's a serious track record of Getting Things Done.

Behind every closed issue is a problem solved, a user helped, or a system improved. 100 of those? That's impact.

— Your Squad
```

### Custom Milestones

#### First Release
```
**First Release — {{name}}!**

{{name}} just shipped their **first release**! There's something special about that first time your code goes live. You're officially a shipper.

The first of many.

— Your Squad
```

#### First On-Call Rotation
```
**On-Call Champion — {{name}}!**

{{name}} just completed their **first on-call rotation**! Joining the on-call rotation is a milestone that says "I've got this team's back."

Thanks for stepping up. The squad sleeps better knowing you're watching.

— Your Squad
```

## AI Enhancement Prompt

If using AI to generate personalized milestone messages:

```
Generate a milestone celebration message for {{name}} who just achieved: {{milestone}}.
The message should be:
- Celebratory and specific to the achievement
- Explain why this milestone matters (not just "congrats!")
- 2-4 sentences
- Fun, energetic, use emoji
- Acknowledge the effort behind the number
- Sign off as "Your Squad"

Tone: Like a teammate who genuinely geeks out about your achievements.
Scale enthusiasm with milestone size: 10 = encouraging, 100+ = epic.
```

## Configurable Milestone Thresholds

Teams define their own thresholds in `.squad/skills/celebrations.json`:

```json
{
  "milestones": {
    "prCount": [10, 50, 100, 500, 1000],
    "issuesClosed": [25, 100, 500],
    "custom": [
      {
        "name": "First Release",
        "description": "Shipped their first release",
        "trigger": "manual"
      },
      {
        "name": "First On-Call",
        "description": "Completed first on-call rotation",
        "trigger": "manual"
      }
    ]
  }
}
```

## Rules

- **Celebrate the effort, not just the number** — "100 PRs" means "100 times you showed up"
- **Scale enthusiasm** — 10 is encouraging, 100 is exciting, 500 is legendary
- **Be specific** — Reference the actual milestone type (PRs, issues, etc.)
- **No comparisons** — Never rank members or compare milestone speeds
- **Respect the opt-in** — Only send to members who have `optedIn: true` and `celebrationPreferences.milestoneMessage: true`
