# Idea Pilot — iOS UX Specification

**Purpose:** Bridge the functional PRD and visual design. This document defines user flows, screen interactions, navigation, and state behavior so a UI team can produce wireframes and high-fidelity mockups without ambiguity.

**Audience:** UI/UX designers, iOS developers

**Reference docs:** iOS PRD, Platform PRD, Principles

---

## 1. Navigation Model

### 1.1 Tab Bar (Primary Navigation)

The app uses a bottom tab bar with 3 tabs:

| Tab | Label | Icon Concept | Destination |
|-----|-------|-------------|-------------|
| 1 | Now | Play / target | Playbook Home (Now lane) |
| 2 | Capture | Plus circle | Quick Add sheet |
| 3 | Playbooks | Stack / folder | Playbook List |

**Rules:**
- Tab 1 ("Now") opens the last-viewed playbook's Now lane. If no playbook exists, it shows the empty state with a "Create Playbook" prompt.
- Tab 2 ("Capture") does not navigate — it presents a bottom sheet overlay on top of the current screen.
- Tab 3 ("Playbooks") opens the full playbook list.
- The tab bar is always visible except during full-screen modals (auth, weekly plan flow).
- Active tab uses a filled icon + label; inactive tabs use outline icons, no label.

### 1.2 Navigation Stack

Each tab maintains its own navigation stack:

- **Now tab:** Playbook Home → (push) Section Editor
- **Playbooks tab:** Playbook List → (push) Playbook Home → (push) Section Editor

Back navigation uses the standard iOS swipe-from-left-edge gesture and a back chevron in the nav bar.

### 1.3 Modal Presentations

These screens present as modals (slide up from bottom):
- Quick Add (Capture) — half-sheet
- Weekly Plan flow — full-screen modal
- Settings — full-screen modal (from profile icon in Playbook List)
- Task Detail / Edit — half-sheet expanding to full

---

## 2. Screen Specifications

### 2.1 Auth (Full-Screen, No Tab Bar)

#### Sign In
- **Layout:** Centered logo/wordmark at top. Two text fields (email, password). "Sign In" primary button. "Create Account" text link below. "Continue with Auth0" secondary button at bottom (if Auth0 is configured).
- **Email field:** Keyboard type = email. Autocapitalize = none. Autocorrect = off.
- **Password field:** Secure text entry. Toggle visibility icon (eye).
- **Validation:** Inline error below each field on submit if invalid. Email must be valid format. Password minimum 8 characters.
- **States:**
  - Default: Fields empty, button enabled.
  - Loading: Button shows spinner, fields disabled.
  - Error: Red inline message below the relevant field ("Invalid email or password").
  - Network error: Banner at top — "No internet connection. Check your network and try again."

#### Sign Up
- **Layout:** Same as Sign In, but fields are email + password + confirm password. "Create Account" primary button. "Already have an account? Sign In" text link.
- **Validation:** Confirm password must match. Show inline error if mismatch on blur. Show password strength hint (e.g., "8+ characters").
- **On success:** Automatically sign in (tokens returned) and navigate to Playbook List.

#### Token Refresh
- Invisible to user. Handled by the networking layer.
- If refresh fails (expired/revoked), redirect to Sign In with a toast: "Session expired. Please sign in again."

---

### 2.2 Playbook List

#### Layout
- **Nav bar:** Title "Playbooks" (large title style). Right: profile/settings icon (gear).
- **List:** Vertical scroll. Each row shows:
  - Playbook title (primary text, single line, truncate with ellipsis)
  - Phase badge (PROOF / STRUCTURE / REPEATABILITY / GROWTH) — small colored pill
  - Task summary line: "{N} tasks in Now" (secondary text)
  - Chevron indicating push navigation
- **FAB or inline button:** "New Playbook" at the bottom of the list (not floating — inline after last item to avoid covering content).

#### Interactions
- **Tap row** → Push to Playbook Home (Now lane).
- **Long-press row** → Context menu: "Archive", "Delete" (destructive, red).
- **Swipe left on row** → Reveal "Archive" action (yellow/amber).
- **Tap "New Playbook"** → Present half-sheet: title field (required), description field (optional), "Create" button. On success, push to the new Playbook Home.
- **Tap gear icon** → Present Settings modal.
- **Pull to refresh** → Sync playbooks from server. Show pull-to-refresh indicator.

#### States
- **Empty (no playbooks):** Centered illustration + "Create your first playbook" message + prominent "Create Playbook" button.
- **Loading (first load, no cache):** Skeleton rows (3 placeholder rows with shimmer animation).
- **Offline with cache:** Show cached list. Subtle banner at top: "Offline — showing cached data."
- **Offline without cache:** Centered message: "No internet connection. Connect to get started."

#### Archived Playbooks
- Archived playbooks are hidden by default.
- A "Show Archived" toggle or filter chip appears at the top of the list if any archived playbooks exist.
- Archived rows appear dimmed with an "Archived" label.
- Long-press on archived → "Unarchive" option.

---

### 2.3 Playbook Home (Execution Surface)

This is the core screen. It must be the fastest path to "what do I do next."

#### Layout
- **Nav bar:** Back chevron (if pushed from Playbook List). Title = playbook name (inline, not large). Right: overflow menu (three dots).
- **Segmented control** below nav bar: **Now** | **Next** | **Later**
  - Selected segment is visually prominent (filled background).
  - Default selection: "Now" (always).
- **Task list** below segmented control: Vertical scrolling list of tasks for the selected lane.
- **Add task button:** Fixed at the bottom of the screen, above the tab bar. Full-width pill button: "+ Add Task to {Lane}".

#### Task Card (List Item)
Each task card displays:
- **Checkbox** (left) — tap to complete (Now/Next only; Later tasks show no checkbox)
- **Title** (primary text, up to 2 lines, then truncate)
- **Estimated time badge** (e.g., "90 min") — small pill, right-aligned
- **Drag handle** (right edge) — visible only when in reorder mode or always visible as subtle grip lines

#### Interactions

**Tap task card** → Present Task Detail half-sheet (see 2.4).

**Tap checkbox** → Complete the task:
1. Checkbox fills with checkmark + haptic (light impact).
2. Title gets strikethrough styling.
3. After 1.5s delay, the card animates out (slide left + fade).
4. If this was the last Now task, show a celebratory micro-animation (confetti or checkmark burst) and message: "All done for now!"
5. Task moves to DONE status with `completedAt` timestamp.
6. Mutation queued if offline.

**Swipe right on task card** → Complete (same as checkbox tap). Green background reveals during swipe.

**Swipe left on task card** → Reveal lane-move actions:
- If in Now: "Move to Next" (blue), "Move to Later" (gray)
- If in Next: "Move to Now" (green), "Move to Later" (gray)
- If in Later: "Move to Now" (green), "Move to Next" (blue)

**Long-press task card** → Enter reorder mode:
- Card lifts (shadow + scale 1.02).
- Other cards compress slightly to show drop zones.
- Drag to reorder within the current lane.
- Drop sends `POST /v1/tasks/reorder` with new order.

**Tap "+" button** → Present Quick Add sheet pre-set to current lane (see 2.5).

**Tap overflow menu (three dots)** → Options:
- "Weekly Plan" → Present Weekly Plan flow (see 2.7)
- "Sections" → Push to Sections list (see 2.6)
- "Playbook Settings" → Push to Playbook edit screen (title, description, phase)

#### Segmented Control Behavior
- Switching lanes is instant (no network call — data is locally cached).
- Each lane shows its task count as a badge on the segment label: "Now (3)", "Next (7)", "Later (12)".
- If a lane is empty, show inline empty state within the list area (no tasks card):
  - Now empty: "Plan your week to move tasks here" + "Start Weekly Plan" button
  - Next empty: "Tasks you'll tackle soon appear here"
  - Later empty: "Capture ideas to build your backlog" + "Capture" button

#### Guardrails
- When creating or editing a task, if `estimatedMinutes` > 180:
  - Show warning below the field: "Tasks over 3 hours should be broken down. Can you split this?"
  - Allow save anyway (soft guardrail), but show the warning persistently.
- If Now lane has > 5 tasks:
  - Show a soft warning banner above the task list: "Focus works best with 3-5 tasks. Consider moving some to Next."

---

### 2.4 Task Detail (Half-Sheet → Expandable)

Presented as a half-sheet that the user can drag up to full screen.

#### Layout
- **Drag indicator** at top (small gray pill).
- **Title** — editable inline. Tap to edit, keyboard appears.
- **Status pill** — "Open" (blue) or "Done" (green). If Done, show completedAt date.
- **Lane selector** — three horizontal chips: Now / Next / Later. Active chip is filled.
- **Estimated time** — stepper or preset chips: 30 / 60 / 90 / 120 / 180 min. Custom input if tapped again.
- **Detail / Notes** — multiline text field. Placeholder: "Add notes or details..." Supports basic text (no markdown rendering in MVP).
- **Actions at bottom:**
  - "Complete Task" button (green, only if status = OPEN)
  - "Delete Task" button (red text, no fill — destructive)

#### Interactions
- **Edit title:** Tap title text → inline edit mode. Save on keyboard dismiss or "Done" button.
- **Change lane:** Tap a lane chip → task moves immediately (optimistic). Card disappears from current lane list when sheet dismisses.
- **Change estimate:** Tap a time chip. If already selected, tap again to enter custom value (number input).
- **Complete:** Tap "Complete Task" → same completion animation as checkbox. Sheet dismisses.
- **Delete:** Tap "Delete Task" → Confirmation alert: "Delete this task? This can't be undone." Confirm = delete + dismiss. Cancel = stay.

---

### 2.5 Quick Add (Capture)

The fastest path from thought to task. Presented as a half-sheet.

#### Layout
- **Drag indicator** at top.
- **Title field** — large text, auto-focused, keyboard appears immediately. Placeholder: "What needs to happen?"
- **Lane selector** — three chips: Now / Next / **Later** (default selected).
- **Estimated time** — preset chips: 30 / 60 / 90 / 120 min. Default: 60.
- **"Add" button** — right side of title field or bottom. Enabled only when title is non-empty.

#### Interactions
- **Type + tap Add** → Task created, sheet stays open with fields cleared (allows rapid multi-capture). Subtle success feedback: title field briefly flashes green or shows a small checkmark.
- **Type + swipe down** → If title is non-empty, show confirmation: "Discard this task?" Yes/No. If empty, dismiss silently.
- **Keyboard shortcut (external keyboard):** Cmd+Enter = submit.

#### Offline Behavior
- Task saves locally immediately. Queued for sync.
- No visual difference — capture must feel identical online and offline.

---

### 2.6 Sections Editor

#### Sections List (Push from Playbook Home)
- **Nav bar:** Back chevron. Title: "Sections".
- **List of 4 sections:**
  - Vision
  - System
  - Build
  - Business Model
- Each row shows: section name, first line preview of content (gray, truncated), chevron.
- Rows are static (not reorderable — order is fixed by the platform).

#### Section Detail (Push from Sections List)
- **Nav bar:** Back chevron. Title: section name (e.g., "Vision").
- **Content area:** Full-screen multiline text editor. Plain text in MVP (rich text / markdown later).
- **Auto-save:** Content saves locally on every pause in typing (debounce 1s). Syncs to server when online.
- **Character/word count** at bottom (subtle, gray).
- **Offline:** Edits save locally. Sync on reconnect. If server has a newer version, show conflict notice: "This section was updated elsewhere. Keep yours / Keep server version / Keep both."

---

### 2.7 Weekly Plan Flow (Full-Screen Modal)

A guided ritual. Takes the user through planning their week in 3 steps.

#### Step 1: Review (What happened last week)
- **Header:** "Last Week" with week date range.
- **Summary card:** "{X} of {Y} tasks completed" with a simple progress ring.
- **List of completed tasks** (strikethrough, green checkmarks). Collapsed by default — "Show completed" toggle.
- **List of incomplete tasks** from Now (if any remain). Each has options: "Keep in Now", "Move to Next", "Move to Later".
- **"Continue" button** at bottom.

#### Step 2: Select (Choose this week's tasks)
- **Header:** "Plan This Week" with current week date range.
- **Source list:** Tasks from Next lane, ordered by existing orderIndex.
- Each task row shows: checkbox (multi-select), title, estimated time badge.
- **Running total** at top: "Selected: {N} tasks, ~{M} hours" — updates live as selections change.
- **Guidance text:** "Aim for 3-5 tasks that fit this week's capacity."
- **Soft warning** if > 5 selected: "That's ambitious! Consider focusing on fewer tasks."
- **"Plan Week" button** at bottom. Disabled if 0 tasks selected.

#### Step 3: Confirmation
- **Header:** "Week Planned"
- **Summary:** "{N} tasks moved to Now"
- **List of planned tasks** (brief).
- **"Let's Go" button** → Dismisses modal, returns to Playbook Home Now lane with the planned tasks visible.

#### Interactions
- **Swipe or back to dismiss** at any step → Confirmation: "Abandon weekly planning?" Yes/No.
- **Step indicators** at top (3 dots) show progress. Tapping a previous dot navigates back.
- If there are incomplete tasks in Now from the previous week, Step 1 is shown. If Now is empty, skip directly to Step 2.

---

### 2.8 Settings (Full-Screen Modal)

#### Layout
- **Nav bar:** "Settings" title. "Done" button (right) to dismiss.
- **Sections:**
  1. **Account** — Email display (non-editable in MVP), "Sign Out" button (red text).
  2. **Sync** — Last sync timestamp: "Last synced: 2 min ago". Manual "Sync Now" button. Sync status indicator (green dot = synced, yellow = pending, red = error).
  3. **About** — App version, "Terms of Service", "Privacy Policy" links.

#### Interactions
- **Sign Out** → Confirmation: "Sign out? Unsynced changes will be lost." Confirm → Clear local data, return to Auth screen.
- **Sync Now** → Trigger immediate sync. Show spinner on button. On completion, update timestamp.

---

## 3. State Definitions

Every screen must handle these states. Designers must provide visual treatments for each.

### 3.1 Universal States

| State | Visual Treatment |
|-------|-----------------|
| **Loading (no cache)** | Skeleton / shimmer placeholder matching the content layout |
| **Loading (with cache)** | Show cached data immediately. Subtle refresh indicator (pull-to-refresh or top bar progress) |
| **Empty** | Centered illustration + contextual message + primary action button |
| **Error (network)** | Inline banner: "Couldn't load data. Pull to retry." Retry action available. |
| **Error (server)** | Inline banner: "Something went wrong. Try again later." |
| **Offline (with cache)** | Full functionality. Persistent subtle banner: "Offline" (small, top). Mutations queued silently. |
| **Offline (no cache)** | Limited message: "Connect to the internet to get started." (Auth screen only — all other screens should have cache.) |

### 3.2 Optimistic Updates

All mutations (create, update, complete, move, reorder) apply instantly to the local UI:
- The user sees the result immediately.
- A sync indicator (subtle, non-blocking) shows pending upload.
- If the sync fails, the item shows a small warning icon. Tap → "Retry" option.
- The UI never blocks on a network call for task operations.

---

## 4. Gestures Summary

| Gesture | Context | Action |
|---------|---------|--------|
| Tap | Task card | Open Task Detail sheet |
| Tap | Checkbox | Complete task |
| Swipe right | Task card | Complete task |
| Swipe left | Task card | Reveal lane-move actions |
| Long-press + drag | Task card | Reorder within lane |
| Long-press | Playbook row | Context menu (archive/delete) |
| Swipe left | Playbook row | Archive action |
| Pull down | Any list | Refresh / sync |
| Swipe down | Sheet / modal | Dismiss (with discard confirmation if unsaved changes) |
| Edge swipe left | Any pushed screen | Back navigation |

---

## 5. Transitions & Animation Guidelines

Idea Pilot's interface must feel **calm and fast** (per Principles 2.3). Animations serve function, not decoration.

| Transition | Type | Duration | Notes |
|-----------|------|----------|-------|
| Push navigation | Slide from right | 300ms | Standard iOS |
| Sheet present | Slide up from bottom | 250ms | Spring curve |
| Sheet dismiss | Slide down | 200ms | Ease-out |
| Task complete | Strikethrough + slide left + fade | 1500ms total | Strikethrough at 0ms, pause, slide at 1000ms |
| Lane switch (segment) | Crossfade list content | 150ms | No lateral slide — feels instant |
| Reorder drag | Card lifts (shadow + scale) | 100ms | Spring, subtle |
| Pull to refresh | Standard iOS spinner | System default | |
| Skeleton shimmer | Gradient pulse | 1500ms loop | Until content loads |
| Quick Add success | Brief green flash on title field | 300ms | Fade in/out |
| All Now tasks done | Checkmark burst / confetti | 800ms | Celebratory but brief |

**Rule:** No animation should delay the user from taking their next action. All animations must be interruptible.

---

## 6. Typography & Spacing Intent

*(The UI team will define exact values. These are structural guidelines.)*

- **Information hierarchy per card:** Title (body, semibold) > Time badge (caption, regular) > Detail preview (caption, secondary color)
- **Whitespace:** Generous padding between cards. The interface should feel breathable, not dense.
- **Touch targets:** Minimum 44pt height for all tappable elements (Apple HIG).
- **Section headers:** Uppercase caption, secondary color, generous top margin to separate groups.
- **Numbers / metrics:** Use tabular (monospaced) figures for counts and times so they don't shift during updates.

---

## 7. Accessibility Requirements

- All interactive elements must have accessibility labels.
- Checkbox: "Complete task: {title}".
- Lane chips: "Move to {lane} lane".
- Support Dynamic Type (text scaling) for all text elements.
- All color-coded elements (phase badges, status pills) must also use shape or text to convey meaning — never color alone.
- Minimum contrast ratio: 4.5:1 for body text, 3:1 for large text (WCAG AA).
- VoiceOver: Full task management flow must be operable with VoiceOver. Reorder via VoiceOver uses rotor actions.
- Reduce Motion: Replace all animations with instant state changes when "Reduce Motion" is enabled in iOS settings.

---

## 8. Offline & Sync UX

### 8.1 Sync Status Indicator
- A small dot or icon in the nav bar (Playbook Home) indicates sync state:
  - **Green dot:** All changes synced.
  - **Spinning:** Sync in progress.
  - **Yellow dot:** Pending changes (offline or queued).
  - **Red dot:** Sync error (tap for details).

### 8.2 Conflict Resolution (MVP)
- Last-write-wins for tasks and playbook metadata.
- For section content conflicts: Present a simple chooser: "This section was edited on another device. Keep this version / Keep other version / Keep both (appended)."
- Conflict UI is a non-blocking alert that appears after sync completes.

### 8.3 Background Sync
- Sync triggers on: app foreground, pull-to-refresh, after any mutation (debounced 2s), and periodic background refresh (if OS allows).
- Sync never interrupts the user. Failures are silent until the user checks Settings > Sync or notices the status indicator.

---

## 9. User Flows

### 9.1 First-Time User Flow
1. App opens → Auth screen (Sign Up).
2. User creates account → Auto signed in → Playbook List (empty state).
3. User taps "Create Playbook" → Enters title → Playbook created → Pushed to Playbook Home.
4. Now lane is empty → User sees "Plan your week to move tasks here."
5. User switches to Later tab → Empty → "Capture ideas to build your backlog" + Capture button.
6. User taps Capture → Quick Add sheet → Enters first task → Adds it → Repeats 2-3 times.
7. User switches to Next → Moves a task from Later to Next (swipe left → "Move to Next").
8. User taps overflow → "Weekly Plan" → Selects tasks from Next → Plans week → Tasks appear in Now.
9. User is now in the execution loop.

### 9.2 Daily Execution Flow (Returning User)
1. App opens → Now tab → Last-viewed playbook's Now lane (cached, < 1s).
2. User sees 3-5 tasks. Picks the top one.
3. Works on it. Returns to app.
4. Taps checkbox → Task completes with animation → Moves to next task.
5. Repeat until Now is clear or day ends.

### 9.3 Idea Capture Flow (Interrupt)
1. User is anywhere in the app.
2. Taps Capture tab (center) → Quick Add sheet slides up.
3. Types task title → Taps Add → Task saved to Later (default).
4. Sheet clears, ready for another capture. User swipes down to dismiss.
5. Total time: < 10 seconds.

### 9.4 Weekly Planning Flow
1. User opens playbook → Taps overflow → "Weekly Plan."
2. **Step 1 (Review):** Sees last week's results. Moves incomplete tasks to Next/Later or keeps in Now.
3. **Step 2 (Select):** Browses Next lane tasks. Selects 3-5 for this week. Sees running total of estimated hours.
4. **Step 3 (Confirm):** Sees summary. Taps "Let's Go."
5. Returns to Now lane with fresh tasks. Ready to execute.

### 9.5 Offline Workflow
1. User opens app with no connectivity.
2. App loads from local cache (playbooks, tasks, sections).
3. "Offline" banner visible but non-intrusive.
4. User completes a task, captures a new idea, reorders tasks — all work normally.
5. Connectivity returns → Background sync pushes queued mutations → Green dot appears → Banner disappears.

---

## 10. Design Deliverable Checklist

The UI team should produce the following for each screen:

- [ ] Default state
- [ ] Empty state
- [ ] Loading state (skeleton)
- [ ] Error state
- [ ] Offline state (with cache)
- [ ] Interaction states (pressed, swiped, dragging)
- [ ] Dark mode variant
- [ ] Dynamic Type at largest accessibility size
- [ ] Landscape orientation (iPad consideration, or explicitly excluded for MVP)

---

## End of Document
