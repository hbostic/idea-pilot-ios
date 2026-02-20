# Idea Pilot — iOS PRD
**Role:** Primary execution surface (fast, offline-tolerant, low-friction)

---

## 1. Summary

The iOS app is the first client for Idea Pilot. It must provide the fastest path from “open app” to “know what to do next,” with a strong capture flow and offline continuity.

Default landing experience: **Next Actions**.

---

## 2. Goals

- Execution-first UX: Now is always visible within 1–2 taps
- Ultra-fast capture into Later backlog
- Smooth weekly planning ritual
- Offline-first: app remains usable without connectivity
- High-quality, minimal UI (avoid feature sprawl)

Success (MVP):
- Time from app open to seeing NOW tasks: < 1 second (cached)
- Capture idea → appears in LATER: < 10 seconds
- Weekly plan flow completed in < 2 minutes

---

## 3. Non-Goals (MVP)

- Multi-user collaboration
- Complex calendar scheduling
- Rich analytics dashboards
- Deep automation rules builder
- Fully custom themes/skins

---

## 4. UI Stack Options

### Option A (Recommended): SwiftUI
- Declarative, state-driven UI
- Excellent for execution-first surfaces
- Cleaner architecture for solo/small teams

### Option B: UIKit
- More control; more boilerplate
- Use if you need advanced custom interactions that SwiftUI struggles with

Recommendation: SwiftUI-first with selective UIKit bridging if needed.

---

## 5. Core Screens (MVP)

### 5.1 Auth
- Sign in / sign up
- Token refresh handling
- Error states + offline handling (read-only mode if cached)

### 5.2 Playbook List
- List of Playbooks
- Create new Playbook (from template)
- Search (optional later)
- Archive (optional)

### 5.3 Playbook Home (Default: Next Actions)
Tabs or segmented control:
- Now
- Next
- Later

Core interactions:
- add task
- move between lanes (drag/drop or context actions)
- reorder within lane
- mark done

Guardrails:
- estimated time required (30–180 minutes)
- prompt to split if user enters too large

### 5.4 Capture (Quick Add)
- single text field + optional voice (later)
- default routes to LATER (or user chooses lane)
- minimal friction; should work offline

### 5.5 Weekly Plan
- choose 3–5 tasks from Next
- promote to Now
- optional “clear Now” prompt if needed
- show weekly completion summary

### 5.6 Sections Editor (Lightweight in MVP)
- view/edit Vision/System/Build/Business Model
- simple markdown editor or rich text field
- deep editing can come later on web

### 5.7 Settings (Minimal)
- account
- data sync status
- export (later)

---

## 6. Offline-First Requirements

- Local persistence for:
  - playbooks
  - sections
  - tasks
- Queue mutations while offline:
  - create task
  - move lane
  - reorder
  - complete
- Background sync when online

Conflict strategy (MVP):
- last-write-wins using server `updated_at`
- if conflict on sections text: notify user and keep both versions (later)

---

## 7. Notifications (MVP)

- Local notifications:
  - daily reminder to review “Now” (user-configurable later)
- Push notifications deferred until backend eventing is mature

---

## 8. Performance Requirements

- Cold open → cached Now list: < 1s on modern devices
- Core list interactions must be 60fps
- Network calls must not block UI; optimistic updates preferred

---

## 9. Analytics (MVP, Privacy-Respecting)

Track locally and optionally send anonymized aggregates later:
- tasks completed per week
- streak count
- capture count

Avoid heavy tracking early.

---

## 10. Recommended iOS Architecture (Optional)

- SwiftUI + MVVM
- Networking: URLSession + typed API client
- Local persistence: SwiftData or SQLite
- Dependency injection for testability
- Feature flags controlled server-side

---

## End of Document
