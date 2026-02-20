# GitHub Workflow

This document describes the GitHub Issues + Projects workflow for idea-pilot.

## Workflow States (GitHub Projects Board)

| Column | Description |
|--------|-------------|
| **Todo** | Issue created, not yet started |
| **In Progress** | Actively being worked on |
| **In Review** | PR open, code review in progress |
| **Done** | PR merged, issue closed |

## Transitions

```
┌──────────┐   Create branch    ┌─────────────┐
│   Todo   │ ─────────────────▶ │ In Progress │
└──────────┘                    └─────────────┘
                                       │
                                       ├── Open PR ────────▶ In Review
                                       │
                                       └── Close issue ────▶ Done
```

### From Todo
- **Create branch & start work** → In Progress

### From In Progress
- **Open PR** → In Review
- **Close issue** → Done (if no code change needed)

### From In Review
- **Merge PR** → Done (issue auto-closes via PR)
- **Request changes** → stays In Review (author pushes fixes)

## Standard Development Flow

1. **Create issue** in GitHub (or pick one from the backlog)
2. **Assign to yourself** and move to "In Progress" on the Projects board
3. **Create feature branch** from `dev`: `git checkout -b feat/123-description`
4. **Write code** on the feature branch
5. **Create PR** targeting `dev` — reference the issue with `Closes #123`
6. **Wait for CI to pass** — ensure all checks pass before merging
7. **Merge PR** — squash and merge into `dev`; issue auto-closes
8. **Delete feature branch** — ask for permission, then delete the remote branch

## GitHub Projects Automation (Optional)

You can set up built-in automations on your GitHub Projects board:

| Trigger | Action |
|---------|--------|
| Issue added to project | Move to **Todo** |
| PR opened that references issue | Move to **In Review** |
| PR merged / issue closed | Move to **Done** |

Set these up in **Projects > Workflows** on the project board.

## Issue Labels

| Label | Purpose |
|-------|---------|
| `bug` | Something isn't working |
| `feature` | New feature request |
| `enhancement` | Improvement to existing feature |
| `docs` | Documentation only |
| `chore` | Maintenance / housekeeping |
| `priority: high` | Needs immediate attention |
| `priority: low` | Nice to have |

## Team Members

| Name | Role | Notes |
|------|------|-------|
| TBD | Developer | - |
| TBD | Reviewer | - |

*Note: Names and team composition may change as other team members join. The workflow process remains the same.*

## Tips

- Always assign the issue to yourself before starting work
- Use `Closes #123` in PR descriptions to auto-close issues on merge
- Use meaningful branch names that include the issue number
- Reference the issue number in PR titles: `#123 Short description`
- Keep the Projects board up to date — it's the source of truth for what's in flight

---

*Last updated: February 2026*
