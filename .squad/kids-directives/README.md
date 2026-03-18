# Kids Squad Directives — README

This folder contains **parent-controlled directives** that are automatically synced to `tamirdresher/squad-for-kids`.

## How This Works

1. Tamir (parent) edits files in this folder on the `main` branch
2. Kids' Ralph watches this folder on a daily schedule
3. On any change, Ralph syncs the content to `squad-for-kids/.squad/parent-directives.md`
4. The kids' squad agents treat these directives as inviolable — they cannot be overridden

## Files in This Folder

| File | Purpose |
|------|---------|
| `rules.md` | Behavioral rules agents must enforce |
| `tasks.md` | Tasks/chores Tamir assigns to the kids |
| `procedures.md` | Recurring procedures and routines |
| `schedule.json` | Machine-readable schedule for Ralph |

## How to Add a Rule

Edit `rules.md` and commit to `main`. Kids' Ralph will detect the change within 24 hours (or sooner if triggered manually).

## How to Assign a Task

Add a row to the `tasks.md` table. Use status `⏳ pending`. Once kids complete it, the status will update to `✅ done` automatically.

## Version Control

Every sync is committed by kids' Ralph with message: `chore: sync parent directives from tamresearch1 [skip ci]`. Full history is preserved in git.
