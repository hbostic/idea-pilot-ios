# CI/CD Implementation Guide

This document describes the CI/CD pipeline and production readiness features implemented for the Analyst Search application.

## Overview

The CI pipeline uses GitHub Actions to automate code quality checks, testing, security scanning, and build verification on every push and pull request.

## GitHub Actions Workflow

**File:** `.github/workflows/ci.yml`

### Triggers

- **Push to any branch** - Runs CI on every commit
- **Pull requests to main** - Runs CI before merge

### Pipeline Steps

1. **Checkout** - Clone repository
2. **Setup Node.js 20** - Install Node with npm caching
3. **Install dependencies** - `npm ci`
4. **Type check** - `npm run check`
5. **Lint** - `npm run lint`
6. **Format check** - `npm run format:check`
7. **Tests with coverage** - `npm run test:coverage`
8. **Upload coverage** - Send to Codecov
9. **Security audit** - `npm audit --audit-level=high`
10. **Build** - `npm run build`

### Branch Protection (Manual Setup)

To require CI to pass before merging to main:

1. Go to repository Settings → Branches
2. Click "Add branch protection rule"
3. Branch name pattern: `main`
4. Enable "Require status checks to pass before merging"
5. Select "ci" as a required check
6. Enable "Require branches to be up to date before merging"

## Code Quality Tools

### ESLint

**File:** `eslint.config.js`

Configuration includes:

- TypeScript strict rules
- React and React Hooks rules
- `no-console` rule (errors on `console.log`, allows `console.error`/`console.warn`)
- Unused variable detection

**Commands:**

```bash
npm run lint        # Check for issues
npm run lint:fix    # Auto-fix issues
```

### Prettier

**Files:** `.prettierrc`, `.prettierignore`

Configuration:

- Semicolons enabled
- Single quotes
- Trailing commas (ES5)
- 2-space indentation
- 100 character line width

**Commands:**

```bash
npm run format        # Format all files
npm run format:check  # Check formatting
```

### Pre-commit Hooks (Husky + lint-staged)

**Files:** `.husky/pre-commit`, `package.json` (lint-staged config)

Automatically runs on every commit:

- ESLint with auto-fix on `.ts` and `.tsx` files
- Prettier on all supported files

## Security Features

### Helmet.js

Security headers configured in `server/index.ts`:

- Content Security Policy (CSP)
- X-Frame-Options
- X-Content-Type-Options
- Strict-Transport-Security
- And more...

### CORS

Configured with allowed origins from `ALLOWED_ORIGINS` environment variable.

### Rate Limiting

API endpoints limited to 100 requests per 15 minutes per IP.

### Health Check Endpoint

**Endpoint:** `GET /api/health`

Returns:

```json
{
  "status": "ok",
  "timestamp": "2024-01-08T12:00:00.000Z"
}
```

Use for load balancer health checks and monitoring.

## Environment Configuration

### Server (.env)

```bash
PORT=5000
NODE_ENV=development
SESSION_SECRET=change-this-to-a-secure-random-string
VOYAGER_BASE_URL=https://your-voyager-instance.com
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5000
```

### Client (client/.env)

```bash
VITE_VOYAGER_BASE_URL=https://your-voyager-instance.com
VITE_BASE_PATH=/analyst-search  # Optional
```

Template files (`.env.example`) are provided for reference.

## Error Handling

### React Error Boundary

**File:** `client/src/components/error-boundary.tsx`

Wraps the entire application to catch React rendering errors and display a user-friendly error page instead of a blank screen.

Features:

- "Try again" button to reset error state
- "Reload page" button for full refresh
- Error details shown in development mode

## NPM Scripts

| Script                  | Description               |
| ----------------------- | ------------------------- |
| `npm run lint`          | Run ESLint                |
| `npm run lint:fix`      | Run ESLint with auto-fix  |
| `npm run format`        | Format with Prettier      |
| `npm run format:check`  | Check Prettier formatting |
| `npm run check`         | TypeScript type checking  |
| `npm run test`          | Run tests in watch mode   |
| `npm run test:run`      | Run tests once            |
| `npm run test:coverage` | Run tests with coverage   |
| `npm run build`         | Build for production      |
| `npm run ci`            | Full CI pipeline locally  |

## Running CI Locally

Before pushing, run the full CI pipeline locally:

```bash
npm run ci
```

This runs: type check → lint → tests → build

## Console Logging Policy

- `console.log` - **Removed** (blocked by ESLint)
- `console.warn` - Allowed for warnings
- `console.error` - Allowed for error handling

Debug logging has been removed from production code. Use proper logging services (e.g., Sentry) for production error tracking.

## Files Created/Modified

### New Files

| File                                       | Purpose                     |
| ------------------------------------------ | --------------------------- |
| `eslint.config.js`                         | ESLint configuration        |
| `.prettierrc`                              | Prettier configuration      |
| `.prettierignore`                          | Prettier ignore patterns    |
| `.husky/pre-commit`                        | Pre-commit hook             |
| `.github/workflows/ci.yml`                 | GitHub Actions workflow     |
| `.env.example`                             | Server environment template |
| `client/.env.example`                      | Client environment template |
| `client/src/components/error-boundary.tsx` | React Error Boundary        |
| `docs/ci-implementation.md`                | This documentation          |

### Modified Files

| File                 | Changes                              |
| -------------------- | ------------------------------------ |
| `package.json`       | Added scripts and lint-staged config |
| `server/index.ts`    | Added security middleware            |
| `server/routes.ts`   | Added health endpoint                |
| Various source files | Removed console.log statements       |

## Troubleshooting

### ESLint errors on unused variables

Prefix unused variables with underscore: `_unusedVar`

### Pre-commit hook not running

Ensure Husky is installed:

```bash
npm run prepare
```

### CI fails on format check

Run `npm run format` locally and commit the changes.

### Rate limiting in development

The rate limiter is configured for 100 requests per 15 minutes. For development, you can temporarily increase this in `server/index.ts`.
