# Repository Etiquette Guide

This document outlines the standard practices for setting up and maintaining repositories. Use this as a reference when creating new projects or onboarding team members.

## Table of Contents

- [Branching Strategy](#branching-strategy)
- [Dev vs Main Commit Strategy](#dev-vs-main-commit-strategy)
- [CI/CD Pipeline Setup](#cicd-pipeline-setup)
- [Branch Protection Rules](#branch-protection-rules)
- [Production Readiness Checks](#production-readiness-checks)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [GitHub Issues Integration](#github-issues-integration)

> **Related:** For environment setup (Claude Code, GitHub CLI), see [ENV_SETUP.md](ENV_SETUP.md). For issue workflow details, see [github-flow.md](github-flow.md).

---

## Branching Strategy

### Branch Structure

| Branch | Purpose | Protected |
|--------|---------|-----------|
| `main` | Production-ready code | Yes |
| `dev` | Development integration branch | Yes |
| `feat/*` | Feature development | No |
| `fix/*` | Bug fixes | No |
| `hotfix/*` | Production hotfixes | No |

### Branch Naming Convention

```
<type>/<issue-number>-<short-description>
```

**Examples:**
- `feat/123-add-user-authentication`
- `fix/456-resolve-login-timeout`
- `hotfix/789-critical-security-patch`

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `hotfix` - Critical production fix
- `refactor` - Code refactoring
- `docs` - Documentation only
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

### Workflow

```
main <- dev <- feature branches
```

1. Create feature branches from `dev`
2. Merge feature branches back to `dev` via PR
3. Merge `dev` to `main` for releases
4. Hotfixes can go directly to `main` (then backport to `dev`)

---

## Dev vs Main Commit Strategy

### The Golden Rules

| Rule | Description |
|------|-------------|
| **Never commit directly to `main` or `dev`** | All changes go through PRs |
| **All feature work targets `dev`** | PRs from feature branches -> `dev` |
| **Only `dev` merges to `main`** | When ready for production release |
| **Hotfixes are the exception** | Can PR directly to `main`, then backport |

### Visual Flow

```
Feature Development:
+--------------+    PR     +--------------+    PR     +--------------+
|   feature    | ---------> |     dev      | ---------> |    main      |
|   branch     |            |  (staging)   |            | (production) |
+--------------+            +--------------+            +--------------+
     |                            |                           |
     | Daily work                 | Integration               | Releases
     | Multiple commits           | testing                   | only
     +----------------------------+---------------------------+

Hotfix (Emergency):
+--------------+    PR     +--------------+
|   hotfix     | ---------> |    main      |
|   branch     |            | (production) |
+--------------+            +--------------+
                                  |
                                  | Backport
                                  v
                            +--------------+
                            |     dev      |
                            +--------------+
```

### What Goes Where

#### Feature Branch -> `dev` (Daily Development)

**Target:** `dev` branch via PR

**Use for:**
- New features
- Bug fixes (non-critical)
- Refactoring
- Test additions
- Documentation updates
- Dependency updates

**Example workflow:**
```bash
# Start from dev
git checkout dev && git pull

# Create feature branch
git checkout -b feat/123-add-search-filters

# Work on feature (multiple commits OK)
git add . && git commit -m "feat: add date filter component"
git add . && git commit -m "feat: add keyword filter component"
git add . && git commit -m "test: add filter unit tests"

# Push and create PR targeting dev
git push -u origin feat/123-add-search-filters
gh pr create --base dev --title "#123 Add search filters"
```

#### `dev` -> `main` (Release)

**Target:** `main` branch via PR

**Use for:**
- Scheduled releases
- Accumulated features ready for production
- After QA validation on dev/staging

**Example workflow:**
```bash
# Ensure dev is up to date
git checkout dev && git pull

# Create release PR
gh pr create --base main --head dev --title "Release: v1.2.0"

# After approval and merge, tag the release
git checkout main && git pull
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

#### Hotfix Branch -> `main` (Emergency Only)

**Target:** `main` branch directly via PR

**Use for:**
- Critical production bugs
- Security vulnerabilities
- Data corruption issues

**Example workflow:**
```bash
# Start from main (production)
git checkout main && git pull

# Create hotfix branch
git checkout -b hotfix/999-fix-auth-bypass

# Make minimal fix
git add . && git commit -m "fix: patch authentication bypass vulnerability"

# Push and create PR targeting main
git push -u origin hotfix/999-fix-auth-bypass
gh pr create --base main --title "[HOTFIX] #999 Fix auth bypass"

# After merge to main, backport to dev
git checkout dev && git pull
git merge main
git push origin dev
```

### Commit Frequency Guidelines

| Branch Type | Commit Frequency | Commit Size |
|-------------|------------------|-------------|
| Feature branch | Frequent (multiple per day) | Small, focused |
| `dev` | Via PR merge only | Squash or merge commit |
| `main` | Via PR from `dev` only | Release batches |

### PR Requirements by Target

| Target Branch | Required Checks | Approvals | Notes |
|---------------|-----------------|-----------|-------|
| `dev` | CI must pass | 0-1 | Standard review |
| `main` | CI must pass | 1-2 | Release review |
| `main` (hotfix) | CI must pass | 1 | Expedited but reviewed |

### Common Mistakes to Avoid

| Mistake | Why It's Bad | Correct Approach |
|---------|--------------|------------------|
| Committing directly to `dev` | Bypasses code review | Always use feature branch + PR |
| Committing directly to `main` | Untested code in production | Use `dev` -> `main` PR |
| Feature PR to `main` | Skips integration testing | PR to `dev` first |
| Large PRs | Hard to review, risky | Break into smaller PRs |
| Merging without CI passing | Broken code in branch | Wait for green CI |

---

## CI/CD Pipeline Setup

### GitHub Actions Workflow

The CI workflow is defined in `.github/workflows/ci.yml` and runs on all pushes and PRs.

**Pipeline steps:**
1. Install dependencies
2. Build the project
3. Type check
4. Lint
5. Run tests with coverage
6. Production readiness check
7. Security audit

### Required package.json Scripts

```json
{
  "scripts": {
    "build": "...",
    "dev": "...",
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "check": "tsc",
    "check:prod": "tsx scripts/production-readiness-check.ts",
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

---

## Branch Protection Rules

### Protection Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `required_status_checks.strict` | `true` | Branch must be up-to-date before merging |
| `required_status_checks.contexts` | `["ci"]` | CI job must pass |
| `required_approving_review_count` | `0-1` | Number of approvals required |
| `dismiss_stale_reviews` | `true` | New commits invalidate old approvals |
| `allow_force_pushes` | `false` | Prevent history rewriting |
| `allow_deletions` | `false` | Prevent accidental branch deletion |

### Setting Up via GitHub UI

1. Go to **Settings** > **Branches**
2. Click **Add branch protection rule**
3. Enter branch name pattern: `main` or `dev`
4. Enable:
   - Require a pull request before merging
   - Require approvals (1 for main, 0 for dev)
   - Dismiss stale pull request approvals when new commits are pushed
   - Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Select status check: `ci`
5. Disable:
   - Allow force pushes
   - Allow deletions

---

## Production Readiness Checks

### Overview

Production readiness checks scan the codebase for issues that linters can't catch:

- Hardcoded IP addresses
- Hardcoded URLs (especially internal/dev URLs)
- AWS hostnames that should be environment variables
- Dev secrets in `.env.example` files
- Large files that need refactoring
- Duplicate constant definitions
- Console statements (should use proper logging)

### Setup

The check runs via: `npm run check:prod`

### Allowlisting Items

When you have legitimate exceptions, add them to `scripts/production-readiness-allowlist.json`:

```json
{
  "hardcodedUrls": [
    "http://localhost",
    "https://cdn.example.com"
  ],
  "largeFiles": [
    "src/pages/complex-page.tsx"
  ]
}
```

---

## Commit Guidelines

### Commit Message Format

```
<type>: <short description>

<optional body explaining the "why">

Co-Authored-By: <name> <email>
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style (formatting, semicolons, etc.) |
| `refactor` | Code refactoring |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |
| `perf` | Performance improvements |
| `ci` | CI/CD changes |

### Examples

```
feat: Add user authentication with OAuth

Implements OAuth2 flow with PKCE for secure browser-based auth.
Session tokens are stored in httpOnly cookies.

Co-Authored-By: Developer Name <dev@example.com>
```

### Rules

- Use imperative mood ("Add feature" not "Added feature")
- Keep first line under 72 characters
- Reference GitHub issues in PR descriptions, not commit messages
- Don't include file lists (git tracks that)

---

## Pull Request Process

### Creating a PR

1. **Title format:** `#123 Short description`
2. **Description template:**

```markdown
## Summary
- Brief bullet points of changes

## Test plan
- [ ] Unit tests pass
- [ ] Manual testing completed
- [ ] Edge cases covered

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

Closes #123
```

### PR Checklist

Before requesting review:

- [ ] CI passes (build, lint, tests, type check)
- [ ] **Unit tests written** for all new or modified logic
- [ ] Production readiness check passes
- [ ] Self-review completed
- [ ] **Documentation updated**:
  - [ ] Swagger/OpenAPI annotations for new or modified endpoints
  - [ ] JSDoc/TSDoc for public functions, services, and exported utilities
  - [ ] Inline comments for complex logic or business rules
- [ ] No console.log statements (use proper logging)
- [ ] No hardcoded values that should be config

### Post-Merge Workflow

1. **Merge the PR** to `dev`
2. **Issue auto-closes** if PR description includes `Closes #123`
3. **GitHub Projects board** auto-moves issue to "Done" (if automation is configured)
4. **Ask the developer** if they want to delete the feature branch

**Branch cleanup commands (when developer confirms):**

```bash
# Delete remote branch
git push origin --delete feat/123-description

# Delete local branch
git checkout dev && git pull
git branch -d feat/123-description
```

---

## GitHub Issues Integration

### Workflow States (via GitHub Projects)

| Column | Trigger |
|--------|---------|
| Todo | Issue created |
| In Progress | Developer starts work |
| In Review | PR opened |
| Done | PR merged / issue closed |

### Linking Issues to PRs

1. Include issue number in branch name: `feat/123-description`
2. Include issue number in PR title: `#123 Description`
3. Include `Closes #123` in PR description to auto-close on merge

> For the full GitHub Issues + Projects workflow, see [github-flow.md](github-flow.md).

---

## Quick Reference

### New Repository Checklist

- [ ] Initialize repo with README
- [ ] Add `.gitignore` appropriate for tech stack
- [ ] Create `main` and `dev` branches
- [ ] Set up branch protection rules
- [ ] Create `.github/workflows/ci.yml`
- [ ] Add production readiness check script
- [ ] Configure test coverage reporting
- [ ] Add `CLAUDE.md` with project-specific instructions
- [ ] Create GitHub Project board for the project

### Developer Daily Workflow

```bash
# 1. Start from dev
git checkout dev && git pull

# 2. Create feature branch
git checkout -b feat/123-description

# 3. Make changes, commit frequently
git add . && git commit -m "feat: description"

# 4. Write unit tests for new/modified logic
git add . && git commit -m "test: add tests for description"

# 5. Update documentation if behavior changes:
#    - Swagger/OpenAPI annotations for endpoint changes
#    - JSDoc/TSDoc for public functions
#    - Inline comments for complex logic or business rules

# 6. Push and create PR
git push -u origin feat/123-description
gh pr create --base dev --title "#123 Description"

# 7. After CI passes, merge via GitHub UI
# 8. Delete local branch
git checkout dev && git pull && git branch -d feat/123-description
```
