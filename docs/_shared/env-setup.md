# Development Environment Setup

This document covers setting up the development environment, including tooling integrations for Claude Code and GitHub.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Claude Code Setup](#claude-code-setup)
- [GitHub CLI Setup](#github-cli-setup)
- [IDE Configuration](#ide-configuration)

---

## Prerequisites

Before starting, ensure you have:

- Node.js 20+ installed
- npm 10+
- Git configured with your credentials
- GitHub account with repo access

---

## Claude Code Setup

### Installation

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

### Project Configuration

Each project should have a `CLAUDE.md` file in the root directory. This file provides context to Claude about:

- Project structure and architecture
- Development commands
- Coding conventions
- Git workflow specific to the project

**Example CLAUDE.md structure:**

```markdown
# CLAUDE.md

## Project Overview
Brief description of what the project does.

## Development Commands
\`\`\`bash
npm install    # Install dependencies
npm run build  # Build the project
npm test       # Run tests
npm run dev    # Start dev server
\`\`\`

## Architecture
Key architectural decisions and patterns used.

## Git Workflow
Link to REPO_ETIQUETTE.md for standard practices.
```

---

## GitHub CLI Setup

The GitHub CLI (`gh`) is used for repository management, PRs, issues, and project tracking.

### Installation

```bash
# macOS
brew install gh

# Windows
winget install GitHub.cli

# Linux
sudo apt install gh
```

### Authentication

```bash
# Login to GitHub
gh auth login

# Follow the prompts:
# - Select GitHub.com
# - Select HTTPS
# - Authenticate via browser
```

### Verify Setup

```bash
# Check authentication
gh auth status

# Test repo access
gh repo view
```

### Common Commands

```bash
# Issues
gh issue create --title "Add user authentication"
gh issue list
gh issue view 123

# Create PR targeting dev
gh pr create --base dev --title "#123 Description"

# View PR status
gh pr status

# Check CI status
gh pr checks

# Merge PR (after approval)
gh pr merge --squash

# Create a new repo
gh repo create org/new-repo --private
```

---

## IDE Configuration

### VS Code Extensions

Recommended extensions:

```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "bradlc.vscode-tailwindcss",
    "formulahendry.auto-rename-tag",
    "christian-kohler.path-intellisense",
    "ms-vscode.vscode-typescript-next"
  ]
}
```

Save as `.vscode/extensions.json` in your project.

### VS Code Settings

Recommended workspace settings:

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "typescript.preferences.importModuleSpecifier": "relative",
  "files.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.turbo": true
  }
}
```

Save as `.vscode/settings.json` in your project.

---

## Environment Variables

### Local Development

This project uses `.env` files for local configuration:

```bash
# .env.example (committed as a template)
# See .env.example in project root for all available variables

# .env (local, gitignored)
# Copy from .env.example and fill in your values
```

Key environment variables:
- `DATABASE_URL` - Database connection string
- `PORT` - Server port (default: 5000)
- `JWT_SECRET` - Secret for signing auth tokens

### CI/CD Environment

GitHub Actions secrets are managed in repository settings:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add repository secrets for sensitive values
3. Reference in workflows: `${{ secrets.SECRET_NAME }}`

---

## Verification Checklist

After setup, verify everything works:

- [ ] `claude --version` shows installed version
- [ ] `gh auth status` shows authenticated
- [ ] `gh repo view` shows current repository
- [ ] IDE extensions installed and working
- [ ] Project builds successfully (`npm run build`)
- [ ] Tests pass (`npm run test:run`)

---

## References

- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub Projects Documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
