# Contributing Notes — Multi-Machine Coordination

> Notes for the upstream PR to [bradygaster/squad](https://github.com/bradygaster/squad)

## What This Contribution Adds

A reusable **git-based task queue** pattern that enables Squad agents on different
machines to coordinate work automatically — no external message broker required.

## Suggested File Placement in Upstream

```
bradygaster/squad/
├── docs/
│   └── skills/
│       └── cross-machine-coordination/
│           ├── README.md              ← from this package's README.md
│           └── SKILL.md               ← from this package's SKILL.md
├── templates/
│   └── cross-machine/
│       ├── config.json                ← from templates/config.json
│       ├── task-template.yaml         ← from templates/task-template.yaml
│       └── result-template.yaml       ← from templates/result-template.yaml
└── scripts/
    └── cross-machine-watcher.ps1      ← from scripts/cross-machine-watcher.ps1
```

Alternative: place everything under a single `skills/cross-machine-coordination/`
directory if the upstream repo prefers skill-scoped file organization.

## Compatibility Notes

- **PowerShell 7+** (pwsh) required for the watcher script
- **Git** required for task transport (push/pull)
- Works on Windows, macOS, and Linux
- No external dependencies beyond PowerShell and Git
- The YAML parser in the watcher is a minimal implementation — for production use,
  consider replacing with the `powershell-yaml` module (`Install-Module powershell-yaml`)

## What's NOT Included

- **Ralph integration code** — the watcher is standalone; Ralph can call it but the
  coupling is left to each deployment
- **GitHub Issues polling** — the SKILL.md describes using `squad:machine-*` labels
  as a supplement, but the watcher script focuses on the git-based file queue
- **Authentication/signing** — git commit signing and branch protection are deployment
  concerns, not part of the skill itself

## Testing

To verify the watcher works:

```bash
# 1. Set up the directory structure
mkdir -p .squad/cross-machine/{tasks,results}
cp templates/config.json .squad/cross-machine/config.json

# 2. Edit config — set your machine hostname
#    "this_machine_aliases": ["YOUR-HOSTNAME"]

# 3. Create a test task
cp templates/task-template.yaml .squad/cross-machine/tasks/test-001.yaml
# Edit test-001.yaml: set target_machine to your hostname, command to "echo hello"

# 4. Run the watcher in dry-run mode
pwsh scripts/cross-machine-watcher.ps1 -DryRun

# 5. Run for real
pwsh scripts/cross-machine-watcher.ps1

# 6. Check results
cat .squad/cross-machine/results/test-001.yaml
```

## Security Considerations

The command whitelist is the primary security boundary. Upstream adopters should:

1. **Start with a minimal whitelist** — only add commands you actually need
2. **Use branch protection** — require PR review before task files merge to main
3. **Enable pre-commit hooks** — scan for secrets in task/result files
4. **Review the threat model** in SKILL.md before deploying to production

## Origin

This pattern was developed and battle-tested in a multi-machine Squad deployment
running across laptop and cloud DevBox environments, handling GPU workloads, blog
rendering pipelines, and automated test execution.
