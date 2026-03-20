# Parent Squad — Upstream Monitor for Yoav's Learning

This squad monitors a child's Squad for Kids learning environment via an upstream connection.

## What This Is

A minimal parent-facing squad that:
- Connects to the child's `squad-for-kids` repo via upstream sync
- Receives weekly progress reports automatically
- Shows parent-friendly dashboards on request
- Gets notified on grade transitions and achievements
- Never exposes raw learning sessions — only summaries

## Setup

This directory is pre-configured as a demo parent squad. In production, a parent would:

1. Create their own repo (or use a private directory)
2. Point `.squad/upstream.md` to the child's learning repo
3. Ask Copilot "How is [child] doing?" for on-demand reports

## Files

```
parent-squad/
├── .squad/
│   ├── team.md          — Parent squad team definition
│   ├── upstream.md      — Connection to child's learning repo
│   ├── routing.md       — How work flows in the parent squad
│   ├── reports/         — Synced weekly reports from child squad
│   └── templates/
│       └── parent-dashboard.md — Template for parent view
└── README.md            — This file
```
