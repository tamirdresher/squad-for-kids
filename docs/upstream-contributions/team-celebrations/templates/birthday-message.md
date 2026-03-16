# Birthday Message Template

> Template for generating birthday celebration messages. Use variable substitution or as a prompt for AI-generated messages.

## Template

```
**Happy Birthday, {{name}}!**

Today's your day, {{name}}! The whole squad wants you to know how glad we are to have you on this team. You make this crew better just by being you.

Take a moment today to do something that makes you smile — you've earned it.

Here's to another amazing trip around the sun!

— Your Squad
```

## Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{name}}` | Member's display name | Alex |
| `{{date}}` | The birthday date (Month Day) | March 15 |
| `{{team}}` | Team name (optional) | Squad Alpha |

## Alternate Variations

### Variation 1 — Short and Sweet
```
Happy Birthday, {{name}}!

You're awesome, and today the squad celebrates YOU. Have an incredible day!

— Your Squad
```

### Variation 2 — Playful
```
{{name}}, it's your birthday!

Quick squad announcement: {{name}} is officially one year more awesome today. 
This is not a drill. Celebrate accordingly.

Fun fact: the probability of being born on {{date}} is approximately 1/365. 
The probability of being as great as {{name}}? Much, much lower.

— Your Squad
```

### Variation 3 — Warm and Genuine
```
Happy Birthday, {{name}}

On your birthday, we just want to say: thank you. Thank you for showing up, for caring about the work, for being a teammate people can count on. This squad wouldn't be the same without you.

Wishing you a day as wonderful as you are.

— Your Squad
```

## AI Enhancement Prompt

If using AI to generate personalized messages, use this as a system prompt:

```
Generate a birthday message for a team member named {{name}}. 
The message should be:
- Warm and genuine (not corporate or stiff)
- 2-3 sentences max
- Fun but respectful
- Use emoji sparingly but effectively
- Never reference age or personal life details
- Sign off as "Your Squad"

Tone: Like a friend who genuinely cares, not an HR department.
```

## Rules

- **Never mention age** — Not even indirectly ("another year wiser")
- **Never assume personal details** — No "hope you celebrate with family" or similar
- **Keep it team-focused** — The celebration is about their value to the team
- **Rotate variations** — Don't use the same template every time
- **Respect the opt-in** — Only send to members who have `optedIn: true` and `celebrationPreferences.birthdayMessage: true`
