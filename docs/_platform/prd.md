# Idea Pilot — Platform PRD (Overview)
**Tagline:** Helping you land on the tarmac of execution

---

## 1. Product Summary

Idea Pilot is a multi-surface execution platform that converts ideas into structured, phased plans and small, executable “Next Actions.” It prevents idea sprawl by enforcing separation of thinking layers and by making the **next move** unmistakable at all times.

Idea Pilot is **not** a generic task manager or PM tool. It is a **personal execution OS** with opinionated structure:

- Layer 1 — Vision (why / destination)
- Layer 2 — System (how it works / operating rules)
- Layer 3 — Build (what must be created)
- Layer 4 — Execution (what you do next)

The first flagship use case is executing a Programming Studio concept **inside** the platform; however, the platform is designed to support *any* project type.

---

## 2. Problem Statement

Builders fail more often from **idea sprawl** than from lack of ideas. Common failure modes:

- planning paralysis
- oversized tasks that never start
- mixing strategy and execution in the same space
- losing ideas across scattered tools
- unclear “single next action”

Most tools store tasks but do not impose structure. Idea Pilot imposes structure and converts complexity into momentum.

---

## 3. Goals & Success Metrics

### Primary Goal
At any moment, the user knows the **single next executable action**.

### Secondary Goals
- Capture ideas immediately (reduce cognitive load)
- Enforce phased progression (sequence over chaos)
- Maintain weekly cadence (momentum)
- Support offline-first execution on mobile
- Enable independent evolution of backend, iOS, web, and Android

### Success Metrics (MVP)
- Median time-to-capture an idea: < 15 seconds
- Tasks in “Now” per week: 3–5
- Weekly completion rate: ≥ 70%
- % tasks compliant with 1–3 hour rule: ≥ 90%
- At least 1 project advances weekly for active users

---

## 4. Target Users

Primary:
- founders, solo builders, operators, creators

Traits:
- many ideas, low execution throughput
- wants clarity and momentum
- values simplicity over feature sprawl

---

## 5. Core Concepts

### 5.1 Playbook (Project Container)
A Playbook is a structured container that holds:
- vision
- system
- build artifacts
- (optional) business model
- execution engine (Now/Next/Later)

### 5.2 Immutable Sections (per Playbook)
1. Vision
2. System
3. Build
4. Business Model (optional)
5. Next Actions (Now / Next / Later)

### 5.3 Execution Engine (Now/Next/Later)
- **Now:** active tasks (daily focus)
- **Next:** upcoming tasks
- **Later:** backlog (idea parking lot)

Rules:
- tasks must be 1–3 hours (enforced)
- vague tasks forbidden (enforced by templates/validation)
- oversized tasks must be decomposed

### 5.4 Phase Framework
Projects progress through phases:
1. Proof (validate manually)
2. Structure (formalize what worked)
3. Repeatability (make teachable/delegable)
4. Growth (only after a working machine)

---

## 6. Product Scope

### In Scope (Platform)
- Playbook creation and management
- Structured sections + content
- Next Actions engine with guardrails
- Phase tracking and gating rules
- Idea capture to backlog
- Weekly planning ritual support

### Out of Scope (MVP)
- team collaboration
- advanced scheduling/calendar replacement
- complex workflow automation
- full knowledge management suite

---

## 7. Architecture & Separation of Concerns (SoC)

Idea Pilot is **not** monolithic. It is a platform with independent tiers:

- Backend API (system of record)
- iOS native app (first client)
- Web app (future client)
- Android native app (future client)

Each tier is independently buildable, deployable, and releasable.

### Canonical Rules
- Backend owns canonical schema and business rules
- Clients focus on UX + offline continuity
- API is versioned and backward compatible
- Feature flags allow safe incremental rollouts

---

## 8. MVP Delivery Plan

### Phase A (Start Here): Backend + iOS
Backend:
- Auth
- Playbook CRUD
- Section content storage
- Next Actions (Now/Next/Later)
- Phase tracking
- Validation rules (task size, required fields)
- Weekly cycle endpoints

iOS:
- Login
- Playbook list
- Default landing on “Next Actions”
- Capture flow to Later
- Manage Now/Next/Later
- Weekly planning flow
- Offline cache + sync

### Phase B: Web
- Deep editing (Vision/System/Build)
- Exports (Markdown/PDF)
- Retrospectives / dashboards

### Phase C: Android
- Execution + capture parity with iOS

---

## 9. Non-Functional Requirements

- **Security:** per-user isolation; token auth; secure storage on device
- **Performance:** sub-second “open app → see Now” for cached state
- **Offline tolerance:** local cache; conflict strategy defined
- **Observability:** structured logs, error reporting, basic metrics
- **Maintainability:** strict SoC boundaries; versioned contracts

---

## 10. Validation Strategy

Flagship validation is “Pilot Playbook #1”: execute the Programming Studio concept inside Idea Pilot.
Success means the system reliably drives the project from concept → proof → structure → repeatability without collapse into planning chaos.

---

## 11. Naming & Brand Notes

**Name:** Idea Pilot  
**Metaphor:** You’re flying the idea; the system helps you land it—safely, repeatedly, with a clear runway (execution).

**Tagline:** Helping you land on the tarmac of execution

---

## End of Document
