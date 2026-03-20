---
layout: post
title: "Hailing Frequencies Open — Teaching Your AI Team to Talk to Humans"
date: 2026-03-20
tags: [ai-agents, squad, github-copilot, teams, communication, channel-routing, whatsapp, star-trek]
series: "Scaling AI-Native Software Engineering"
series_part: 5
---

> *"Hailing frequencies open, Captain."*
> — Lieutenant Uhura, Star Trek: The Original Series

The first time Squad sent a message to the wrong person, I told myself it was a one-off. Edge case. Noise. The second time it happened — to my boss's boss — I knew we needed a communication architecture. Not a config tweak. Not a quick hotfix. An actual, deliberate, thought-through system for how AI agents talk to humans.

This is that story.

---

## Why Communication Is the Hardest Problem

In [Part 4](/blog/2026/03/17/scaling-ai-part4-distributed-problems), I wrote about what happens when eight Ralphs fight over one login. Authentication chaos. Race conditions. Token thrashing. Those problems are humbling, but they're fundamentally *engineering* problems. You can reason through them. You can add locks, queues, and retry logic. The solution space is bounded.

Communication mistakes are different. They're not just wrong — they're *embarrassing*. An agent that floods a Teams channel with duplicate alerts doesn't just waste bandwidth. It trains your colleagues to mute the entire channel. An agent that CCs the wrong person on an email doesn't just make an awkward CC — it breaks trust. And once trust is broken with a VP-level "why is an AI emailing me?", you're having a very different conversation than the one you planned.

The root problem is that AI agents are promiscuous communicators by default. They want to be helpful. Being helpful means telling people things. And absent clear rules about *who* to tell, *what* to tell them, and *through which channel*, agents will just… tell everyone, everything, constantly.

I needed to build Lieutenant Uhura into my squad. Not just "open hailing frequencies." I needed an intelligent communications officer who knows *which* frequency to open, *when*, and *why*.

---

## The Boss's Boss Incident (Anonymized, But Not That Much)

Here's what happened. I was testing a new agent workflow — let's call it an automated status-update generator. The idea was that after significant PRs merged, the agent would send a short summary to the relevant stakeholders. Good idea in principle.

The problem: "relevant stakeholders" was resolved by scanning the PR participants list and walking up the org chart one level. Which, under normal circumstances, means "your immediate team." But one of the PRs had been reviewed by someone fairly senior in the org — normal, they were checking something out — and the org chart lookup climbed right past my manager, past their skip, and landed a cheerful AI-generated project update in the inbox of someone who had approximately zero context for why a robot was briefing them on my authentication refactor.

I found out the way you always find out about these things: a Teams message from my manager with a screenshot and a question mark.

The fix wasn't "make the org chart lookup smarter." The fix was rethinking the entire question of how agents decide where to send things.

---

## Channel Selection: Building the Decision Tree

After the incident, I sat down and mapped out the actual channels my agents use and the logic that should govern each one.

The channels break down into four categories, ordered by formality and blast radius:

**Teams channels** — Low friction, internal, recoverable. Mistakes are visible but containable. This is the primary channel for everything that doesn't need to leave my team's ecosystem.

**Email** — Higher stakes. Persistent. Archivable. Things sent to email feel official in a way that Teams messages don't. I decided agents should almost never auto-send email without human review. The exception: pre-approved templates sent to pre-approved recipients.

**WhatsApp** — Personal and urgent. This is the channel my family uses. If something shows up there from an agent, it had better be genuinely urgent and clearly relevant to my life outside work. The bar is high.

**SMS** — Nuclear option. I don't actually use this much, but the principle applies: if you're hitting SMS, you've concluded everything else has failed.

The rule I settled on: **channel selection must be a function of urgency, privacy context, and trust level — not just convenience**.

Here's the routing logic I encoded, in pseudocode because the actual implementation is a mess of conditionals I'm not proud of:

```
function selectChannel(message):
  if message.urgency == "emergency" and message.context == "personal":
    return WHATSAPP
  
  if message.context == "work" and message.requires_review:
    return EMAIL_DRAFT  # human reviews before it goes anywhere
  
  if message.context == "work":
    return teamsChannel(message.category)  # route to right Teams channel
  
  if message.urgency == "high" and message.context == "personal":
    return WHATSAPP
  
  return TEAMS_GENERAL  # catch-all
```

The `teamsChannel()` function is where the real routing lives. And that brings me to the architecture I'm actually proud of.

---

## The Teams Channel Architecture

One of the best decisions I made early on was not treating Teams as "one big inbox." Different types of agent messages have radically different audiences, urgency levels, and appropriate response actions. Mixing them all into one channel is how you train everyone to ignore all of it.

Here's the actual channel structure I landed on:

```
squads (Teams Team)
│
├── #tamir-squads-notifications   ← catch-all, low-priority
│   "Ralph said something, probably fine"
│
├── #PR-and-Code                  ← PR opened, CI failures, reviews needed
│   "Something in the codebase needs a human eyeball"
│
├── #Ralph-Alerts                 ← Errors, stalls, restarts, health
│   "Ralph is on fire (literally or figuratively)"
│
├── #Wins-and-Celebrations        ← Issues closed, PRs merged, milestones
│   "Something good happened, take a moment"
│
├── #Tech-News                    ← Daily briefings, industry news
│   "Your morning reading, curated by Neelix"
│
└── #Research-Updates             ← Research outputs, paper summaries
    "Seven finished reading the internet again"
```

Each channel has a specific character. `#Ralph-Alerts` is the one you need to check when things go wrong. `#Wins-and-Celebrations` is the one that makes you feel good about the work. `#PR-and-Code` is the one you actually action in the morning. `#Tech-News` is the one you read with coffee. `#Research-Updates` is the one you read when you have forty-five minutes and want to go deep.

The config that drives this lives in `.squad/teams-channels.json`:

```json
{
  "teamId": "5f93abfe-b968-44ea-bd0a-6f155046ccc7",
  "teamName": "squads",
  "channels": {
    "general": {
      "name": "tamir-squads-notifications",
      "use": "catch-all, general notifications"
    },
    "tech-news": {
      "name": "Tech News",
      "use": "daily tech briefings, industry news"
    },
    "ralph-alerts": {
      "name": "Ralph Alerts",
      "use": "Ralph errors, stalls, restarts, health issues"
    },
    "wins": {
      "name": "Wins and Celebrations",
      "use": "issues closed, PRs merged, milestones, birthdays"
    },
    "pr-code": {
      "name": "PR and Code",
      "use": "PR opened, reviews needed, CI failures, merges"
    },
    "research": {
      "name": "Research Updates",
      "use": "research squad outputs, paper summaries"
    }
  },
  "_routing_notes": {
    "webhook_fallback": "Webhook URL always posts to 'general'. When agents have Teams MCP tools, they should post directly using channelId.",
    "neelix_channel_hint": "Neelix output must include 'CHANNEL: <key>' so routing middleware directs the message correctly.",
    "birthday_channel": "Birthday notifications → 'wins' (Wins and Celebrations)."
  }
}
```

The key insight here is the `CHANNEL:` hint convention. Because Neelix (my news and briefings agent) doesn't always have direct access to the Teams MCP tools, his output includes a machine-readable routing hint that the middleware can parse:

```
CHANNEL: tech-news

## Today's Tech Briefing — March 20, 2026

**AI Regulation:** EU AI Act enforcement begins...
```

Simple. Dumb. Works perfectly. The routing middleware reads the first line, looks it up in the channel map, and posts to the right place. If the hint is missing or invalid, it falls back to general. Nobody important gets an accidental briefing.

---

## WhatsApp: When Your AI Team Knows Your Personal Number

WhatsApp monitoring was a deliberate choice, and it made some people uncomfortable when I described it.

The Signal protocol (which WhatsApp uses) is genuinely excellent cryptography. The privacy and security story at the protocol level is solid. But I'm not passing anything sensitive through the channel — I'm using it for urgent, personal-context notifications: family situation updates, urgent reminders that escaped my work calendar, that kind of thing.

The architecture here is intentionally narrow. I didn't hook every agent up to WhatsApp. Only Ralph can initiate a WhatsApp message, and only under strict conditions:

1. The message category is `personal` or `urgent-personal`
2. The recipient is in my pre-approved contacts list (currently: exactly one entry, myself)
3. The message has been through the rate limiter (max 3 per hour; if you're sending more than 3 urgent personal messages in an hour, something has gone deeply wrong)

The incident that shaped this: early in the experiment, I had a bug where the contact resolution was reading from a stale cache. The message I intended to send to my own number went to a contact whose number had been in a recent conversation — in this case, my father-in-law. He received a test notification that read: "URGENT: Ralph health check failed on machine DEVBOX-2, manual restart required."

He called me immediately, extremely concerned, believing "Ralph" was a person.

The fix: the pre-approved contacts list is now hardcoded, not resolved dynamically. Some things should not be configurable at runtime.

---

## The Email Bridge: When Agents Need a Human in the Loop

Email is where I drew the hardest line. My agents cannot send external emails autonomously. Full stop.

The reasons are obvious once you've thought about them for five minutes. Email is archived. Email is searchable. Email can be forwarded. A rogue agent CC'ing someone once is an embarrassment. A rogue agent sending external emails from my work address is a policy violation. These are not the same category of problem.

So I built what I call the email bridge: a review queue that sits between "an agent wants to send an email" and "an email actually gets sent."

```
Agent → generates email draft
      → posts to #PR-and-Code: "Draft ready for review: [subject]"
      → attaches draft to issue for human approval
      
Human → reviews, approves or edits
       → approved: agent sends via Graph API
       → rejected: agent archives, logs feedback
```

The actual sending still happens via agent — I didn't want to force myself back to copy-paste — but the trigger is a human action: a specific comment on the tracking issue, a thumbs-up emoji on the Teams message, something deliberate.

This pattern — **agent proposes, human approves** — turns out to be the right model for anything consequential. It's not slower, because the agent prepares everything: the draft, the context, the suggested recipients, the rationale. All I have to do is review and approve. My cognitive load is low. The error risk is low. The blast radius is managed.

---

## The Duplicate Message Flood

One more incident worth documenting. Not because it was dramatic, but because it illustrates a subtle failure mode.

I had deployed a new webhook configuration for `#PR-and-Code` and neglected to remove the old one. For about six hours, every PR event triggered *two* notifications — identical messages, two seconds apart, in the same channel.

Nobody said anything immediately. It took me noticing the channel myself, seeing the doubled messages, and checking the webhook config to figure out what happened. But by the time I fixed it, the pattern was established: people had learned to expect two messages per PR event. When I fixed the duplicate and went back to one, two different colleagues asked me if the notifications were broken.

The lesson: **duplicate messages don't just annoy — they recalibrate expectations**. The signal-to-noise ratio of a channel is surprisingly fragile. Once you've trained people to expect noise, the absence of noise itself becomes confusing.

---

## Communication Is the Hardest Problem

In distributed systems, the fallacies of distributed computing are famous: the network is reliable, latency is zero, bandwidth is infinite, the network is secure, topology doesn't change. Every one of these assumptions fails in production.

AI agent communication has its own set of fallacies:

- The right person will see the right message at the right time
- Channel selection is a technical problem with a technical solution
- If it's sent, it's received; if it's received, it's understood
- Agents can infer social context from org charts and conversation history
- Automation can't make things awkward

That last one is the killer. Human communication is deeply social. When a message lands in the wrong place, or at the wrong volume, or through the wrong channel — even if the content is technically correct — it creates friction that no amount of engineering can smooth away after the fact.

The answer isn't to make agents communicate less. The answer is to make agents communicate *deliberately*. To encode the social knowledge — urgency, privacy, trust, blast radius — into the routing logic. To build Uhura into your team, not just the transmitter.

Lieutenant Uhura didn't just push buttons. She understood diplomacy, protocol, and the difference between a message that should go to the entire bridge and one that should go to the captain's ear only. That's the model.

Hailing frequencies open. But only to the right people. At the right time. Through the right channel.

---

*This is Part 5 of my "Scaling AI-Native Software Engineering" series. [Part 4](/blog/2026/03/17/scaling-ai-part4-distributed-problems) covered what happens when eight Ralphs fight over one login. Up next: how I'm thinking about the line between what agents should decide autonomously and what always needs a human in the loop.*
