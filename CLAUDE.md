# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Idea Pilot iOS client is an offline-first SwiftUI app that provides the primary execution surface for the Idea Pilot platform. It syncs with the backend API and prioritizes fast capture, distraction-free task execution, and a weekly planning ritual.

**Product Name**: Idea Pilot
**Tagline**: "Helping you land on the tarmac of execution"

## Multi-Tier Architecture

Idea Pilot is **not a monorepo**. Each tier lives in its own repository:

| Repo | Purpose |
|------|---------|
| `idea-pilot-api` | Backend API — system of record, validation, business rules |
| `idea-pilot-ios` | iOS client — offline-first SwiftUI app (this repo) |
| `idea-pilot-docs` | Central documentation hub (syncs docs to tier repos via CI) |

Each tier is independently deployable. All communication occurs through versioned APIs (`/v1/...`). The backend is the canonical source of truth — this client may cache and queue mutations but may not redefine business rules.

## Development Commands

### Running the Application

```bash
# Open in Xcode
open IdeaPilot.xcodeproj

# Build via command line
xcodebuild -scheme IdeaPilot -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Testing

```bash
# Run all tests
xcodebuild test -scheme IdeaPilot -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test target
xcodebuild test -scheme IdeaPilotTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Linting

```bash
swiftlint                    # Run SwiftLint
swiftlint --fix              # Auto-fix lint issues
```

## Architecture

### Project Structure

```
idea-pilot-ios/
├── IdeaPilot/
│   ├── App/
│   │   ├── IdeaPilotApp.swift        # App entry point
│   │   └── AppDelegate.swift         # Lifecycle hooks
│   ├── Features/                     # Feature modules
│   │   ├── Auth/
│   │   │   ├── Views/                # SignInView, SignUpView
│   │   │   ├── ViewModels/           # AuthViewModel
│   │   │   └── Services/             # AuthService, TokenManager
│   │   ├── Playbooks/
│   │   │   ├── Views/                # PlaybookListView, PlaybookHomeView
│   │   │   ├── ViewModels/           # PlaybookListViewModel, PlaybookHomeViewModel
│   │   │   └── Services/             # PlaybookService
│   │   ├── Tasks/
│   │   │   ├── Views/                # TaskCardView, TaskDetailView, QuickAddView
│   │   │   ├── ViewModels/           # TaskViewModel
│   │   │   └── Services/             # TaskService
│   │   ├── WeeklyPlan/
│   │   │   ├── Views/                # WeeklyPlanFlow (Review, Select, Confirm)
│   │   │   └── ViewModels/           # WeeklyPlanViewModel
│   │   ├── Sections/
│   │   │   ├── Views/                # SectionsListView, SectionEditorView
│   │   │   └── ViewModels/           # SectionsViewModel
│   │   └── Settings/
│   │       └── Views/                # SettingsView
│   ├── Core/
│   │   ├── Networking/               # APIClient, endpoint definitions, interceptors
│   │   ├── Persistence/              # SwiftData models, local store
│   │   ├── Sync/                     # SyncEngine, conflict resolution, mutation queue
│   │   └── Extensions/               # Swift/SwiftUI extensions
│   ├── Models/                       # Shared domain models
│   │   ├── Playbook.swift
│   │   ├── Task.swift
│   │   ├── Section.swift
│   │   ├── WeeklyCycle.swift
│   │   └── User.swift
│   ├── Navigation/                   # Tab bar, navigation routing
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings
├── IdeaPilotTests/                   # Unit tests
├── IdeaPilotUITests/                 # UI tests
├── docs/                             # Synced from idea-pilot-docs (do not edit directly)
│   ├── _shared/                      # Shared standards (ENV_SETUP, REPO_ETIQUETTE, etc.)
│   ├── _platform/                    # Platform-wide docs (PRD, architecture)
│   ├── prd.md                        # iOS-specific PRD
│   └── ux.md                         # iOS UX specification
└── IdeaPilot.xcodeproj
```

### Core Domain Models

| Model | Key Fields | Purpose |
|-------|-----------|---------|
| **User** | id, email, accessToken, refreshToken | Account identity and auth state |
| **Playbook** | id, title, phase, createdAt, updatedAt | Project container |
| **Section** | playbookId, sectionType, content | Vision/System/Build/BusinessModel |
| **Task** | id, playbookId, title, lane, estimatedMinutes, status, orderIndex | Executable work items |
| **WeeklyCycle** | playbookId, weekStartDate, completedCount, totalCount | Weekly planning ritual |

### State Management

**SwiftUI + MVVM + SwiftData:**

- **ViewModels** (ObservableObject) manage screen-level state and coordinate between UI and services
- **SwiftData** provides local persistence — models are the single source of truth for UI rendering
- **SyncEngine** handles background syncing between local SwiftData store and remote API
- All mutations are applied locally first (optimistic updates), then queued for server sync

### Authentication Flow

**JWT + Refresh Tokens (mirrors backend):**

1. **Sign In**: `POST /v1/auth/login` — returns access + refresh tokens
2. **Token Storage**: Stored in Keychain (never UserDefaults)
3. **Auto-Refresh**: APIClient interceptor detects 401, attempts token refresh transparently
4. **Sign Out**: Clears Keychain, purges local SwiftData store, returns to Auth screen

**Key files:**

- `Features/Auth/Services/AuthService.swift` — Login/signup/logout API calls
- `Features/Auth/Services/TokenManager.swift` — Keychain storage, token refresh logic
- `Core/Networking/APIClient.swift` — Auth interceptor (auto-refresh on 401)

### Configuration System

- **API Base URL**: Configured per build scheme (Debug → localhost, Release → production)
- **Build Configurations**: Debug and Release schemes in Xcode
- **Feature Flags**: Server-side controlled (fetched on app launch, cached locally)
- **Secrets**: Stored in Keychain, never in code or plists

### Feature Organization

Code is organized by feature domain under `Features/`:

- Each feature has its own `Views/`, `ViewModels/`, and optionally `Services/` directories
- Cross-cutting concerns live in `Core/` (networking, persistence, sync)
- Shared domain models live in `Models/`
- Navigation logic is centralized in `Navigation/`

## Key Technical Patterns

### API Requests

All API calls go through `APIClient`, a centralized networking layer:

```swift
// Typed API client with automatic auth handling
let playbooks = try await apiClient.request(
    .get("/v1/playbooks"),
    responseType: [Playbook].self
)
```

- Uses `URLSession` with typed request/response
- Auth interceptor automatically injects Bearer token
- On 401, transparently refreshes token and retries
- All responses decoded to typed Swift models

### Offline-First / Sync Engine

- **Local-first**: All reads come from SwiftData. Network is secondary.
- **Mutation queue**: Offline changes are queued in a persistent mutation log
- **Background sync triggers**: App foreground, pull-to-refresh, after mutation (debounced 2s), periodic background refresh
- **Conflict resolution**: Last-write-wins using server `updated_at`. Section content conflicts present a chooser to the user.
- **Sync status**: Exposed as observable state — green (synced), yellow (pending), red (error)

### Navigation

**Tab-based with NavigationStack per tab:**

| Tab | Label | Destination |
|-----|-------|-------------|
| 1 | Now | Playbook Home (Now lane) |
| 2 | Capture | Quick Add sheet (overlay) |
| 3 | Playbooks | Playbook List |

- Tab bar always visible except during full-screen modals (auth, weekly plan)
- Each tab maintains its own navigation stack
- Modals: Quick Add (half-sheet), Weekly Plan (full-screen), Settings (full-screen), Task Detail (half-sheet → expandable)

### Error Handling

- Network errors show inline banners (not alerts) — non-blocking
- Validation errors display inline below fields
- Offline errors are silent — mutations queue automatically
- Session expiry redirects to auth with toast message
- Sync failures show status indicator; tap for retry

### Type Safety

- Swift strict concurrency enabled
- All API responses decoded to typed models
- SwiftData models with relationships and constraints
- No force unwrapping (`!`) — use guard/let or nil coalescing

### Gestures & Interactions

| Gesture | Context | Action |
|---------|---------|--------|
| Tap | Task card | Open Task Detail sheet |
| Tap | Checkbox | Complete task (haptic + animation) |
| Swipe right | Task card | Complete task |
| Swipe left | Task card | Reveal lane-move actions |
| Long-press + drag | Task card | Reorder within lane |
| Pull down | Any list | Refresh / sync |

### Animation Guidelines

- Animations serve function, not decoration — keep them calm and fast
- All animations must be interruptible
- Respect "Reduce Motion" accessibility setting — replace animations with instant state changes
- Task completion: strikethrough → pause → slide left + fade (1.5s total)
- Lane switching: crossfade (150ms, no lateral slide)

## Important Constraints

1. **Backend is canonical**: This client syncs with the API — never redefine business rules client-side. Task size (30-180 min), ownership isolation, and phase gating are enforced server-side.
2. **Offline-first**: App must remain fully functional without connectivity. All mutations queue locally.
3. **Versioned APIs**: All client-server communication uses `/v1/...` prefixed endpoints.
4. **Performance targets**: Cold open → cached Now list < 1s. Core list interactions at 60fps. Network calls never block UI.
5. **Accessibility**: All elements need accessibility labels. Support Dynamic Type. Color never the sole indicator. VoiceOver full support. WCAG AA contrast ratios.
6. **Feature isolation**: Keep feature-specific code in feature directories. Don't pollute global scope.
7. **No secrets in code**: Tokens in Keychain. API keys via build configuration. Never commit credentials.

## Standards & Processes

- **Environment setup** (Claude Code, GitHub CLI, IDE): See [docs/_shared/env-setup.md](docs/_shared/env-setup.md)
- **Git workflow & PR process** (branching, commits, CI/CD, branch protection): See [docs/_shared/repo-etiquette.md](docs/_shared/repo-etiquette.md)
- **GitHub Issues workflow** (issue tracking, Projects board): See [docs/_shared/github-flow.md](docs/_shared/github-flow.md)
- **Production readiness checks** (hardcoded URLs, secrets, large files): See [docs/_shared/repo-etiquette.md#production-readiness-checks](docs/_shared/repo-etiquette.md#production-readiness-checks)

### Git Workflow (Quick Reference)

1. Create feature branch from `dev`: `git checkout -b feat/123-description`
2. Make changes, commit with descriptive messages
3. **Write unit tests** for all new or modified logic — no PR without tests
4. **Update documentation** — if behavior changes, update:
   - **API docs** — API spec is owned by the backend repo (`idea-pilot-api`); coordinate if endpoint contracts change
   - **Function-level docs** — add Swift doc comments (`///`) for all public types, functions, and services (params, return types, thrown errors)
   - **Inline comments** — explain non-obvious logic, business rules, workarounds, and "why" decisions
5. Create PR targeting `dev`: `gh pr create --base dev --title "#123 Description"`
6. Wait for CI to pass (build, lint, tests, type check, production readiness)
7. Never merge directly to `main`

### Issue Tracking Integration

**Order of Operations (NON-NEGOTIABLE):**

1. **Issue exists?** If not, create one first
2. **Create feature branch** from `dev` — `git checkout dev && git pull && git checkout -b feat/123-description`
3. **Move issue to "In Progress"** on the GitHub Projects board
4. **NOW you may write code** on the feature branch
5. **Write unit tests** before or alongside your implementation
6. **Update documentation** if the change affects APIs, configs, or user-facing behavior:
   - Coordinate with backend repo if API endpoint contracts change
   - Swift doc comments (`///`) for new or modified public types and functions
   - Inline comments for complex logic or business rules

Do not:
- Fix code first, then create an issue (wrong order)
- Create an issue and immediately close it (skips the workflow)
- Make changes on `dev` or `main` (protected branches)

**Team Members:**

| Name | GitHub Handle | Role |
|------|---------------|------|
| Harold Bostic | @hbostic | Owner |

**Board Transitions (GitHub Projects):**

- **Todo** → **In Progress**: Assign yourself, start work
- **In Progress** → **In Review**: Open a PR
- **In Review** → **Done**: Merge PR (issue auto-closes via `Closes #123`)

### Merge Rules

**NEVER merge directly to `main`.** The ONLY way code gets to `main` is:

1. Feature branches merge to `dev` via PR
2. `dev` merges to `main` via release PR

**Before running `gh pr merge`:**

1. Run `gh pr view <number> --json baseRefName` to verify target is `dev`
2. If baseRefName is `main`, STOP and ask the user
3. Run `gh pr checks <number>` — ALL checks must show passed
4. If CI is still running or has failed, STOP and wait/report to user

### Close-Out Process

When the user confirms testing is complete and asks to "close out" or "finish" a ticket, execute **every** step below in order. Do not skip steps.

**Trigger phrases:** "close out", "finish the ticket", "put it through the close out process"

#### Step 1 — Verify PR target
```bash
gh pr view <PR_NUMBER> --json baseRefName --jq '.baseRefName'
```
Result MUST be `dev`. If it's `main`, STOP and alert the user.

#### Step 2 — Verify CI passed
```bash
gh pr checks <PR_NUMBER>
```
ALL checks must show `pass`. If any are `pending` or `fail`, STOP and wait/report.

#### Step 3 — Merge the PR
```bash
gh pr merge <PR_NUMBER> --merge
```
Only after steps 1-2 pass. Then pull `dev` locally:
```bash
git checkout dev && git pull
```

#### Step 4 — Document on the issue
Add a structured comment to the GitHub issue:
```bash
gh issue comment <ISSUE_NUMBER> --body "## Completed via PR #<PR_NUMBER>

### Summary of Changes
- <bullet list of what changed>

### Files Modified
- <list key files added/modified/deleted>

### CI
Build & Test passed ✓"
```

#### Step 5 — Move issue on project board
Move the issue to **"Done"** on the GitHub Projects board using GraphQL:

```bash
# 1. Find the item ID for the issue on the board
ITEM_ID=$(gh project item-list 2 --owner hbostic --format json \
  --jq '.items[] | select(.content.number == <ISSUE_NUMBER>) | .id')

# 2. Move to "Done" status
gh api graphql -f query='mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwHOABhefM4BPxmU"
    itemId: "'"$ITEM_ID"'"
    fieldId: "PVTSSF_lAHOABhefM4BPxmUzg-FlX8"
    value: { singleSelectOptionId: "4b89ce24" }
  }) { projectV2Item { id } }
}'
```

**Project Board Reference IDs:**

| Resource | ID |
|----------|-----|
| Project | `PVT_kwHOABhefM4BPxmU` |
| Status field | `PVTSSF_lAHOABhefM4BPxmUzg-FlX8` |
| Todo | `9ca83425` |
| In Progress | `d732bfa8` |
| In Review | `e0ab8755` |
| In QA | `a71b4e3e` |
| Done | `4b89ce24` |

#### Step 6 — Delete the feature branch
```bash
# Delete remote branch
git push origin --delete <BRANCH_NAME>

# Delete local branch
git branch -d <BRANCH_NAME>
```

#### Step 7 — Production readiness check
Review the merged changes against these concerns and report findings:

| Check | What to look for |
|-------|------------------|
| Environment config | Hardcoded URLs, ports, or credentials (localhost, API keys) |
| Sensitive logging | Tokens, passwords, PII in print/log statements |
| Input validation | Unvalidated user input at system boundaries |
| Security | Force unwraps on external data, insecure storage, missing auth checks |
| Dead code | Unused imports, commented-out blocks, unreachable paths |
| Placeholder content | TODO comments, Lorem ipsum, stub implementations shipped as real |

Report: "Production readiness check passed ✓" or list specific concerns found.

### Release Process

After testing is complete on `dev`, a separate PR from `dev` to `main` is created for release.

## Related Documentation

- iOS PRD: [docs/prd.md](docs/prd.md)
- iOS UX Specification: [docs/ux.md](docs/ux.md)
- Platform PRD: [docs/_platform/prd.md](docs/_platform/prd.md)
- Architecture PRD: [docs/_platform/architecture-prd.md](docs/_platform/architecture-prd.md)
- Environment setup: [docs/_shared/env-setup.md](docs/_shared/env-setup.md)
- Repository standards: [docs/_shared/repo-etiquette.md](docs/_shared/repo-etiquette.md)
- GitHub workflow: [docs/_shared/github-flow.md](docs/_shared/github-flow.md)
