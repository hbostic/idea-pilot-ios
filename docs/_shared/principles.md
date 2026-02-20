# Idea Pilot — Principles

This document defines the non-negotiable principles that guide product decisions,
architecture decisions, and engineering behavior.

When tradeoffs occur, these principles override preferences, habits, and convenience.

If a proposal violates these principles, it must be redesigned or rejected.

Idea Pilot is not optimized for feature count.
It is optimized for execution clarity.

---

## 1. Product Philosophy

### 1.1 Execution over planning

The product exists to turn ideas into action.

Planning is only valuable if it leads to execution.
Features that encourage endless planning without action are rejected.

The system must always bias toward doing, not organizing.

---

### 1.2 One next action beats infinite options

At any moment, the user should know exactly what to do next.

Ambiguity is product failure.

Choice overload is friction.
Clarity is the feature.

---

### 1.3 Momentum over completeness

The goal is forward motion, not perfect structure.

Small tasks completed consistently beat large plans never started.

We optimize for progress, not theoretical elegance.

---

### 1.4 Constraints create progress

Idea Pilot is intentionally opinionated.

Limits are a feature:
- task size limits
- phased progression
- structured containers

We do not remove constraints to satisfy edge cases.
We design constraints to help the majority execute.

---

### 1.5 Reduce thinking, don’t add thinking

The product should lower cognitive load.

Every screen must answer:
> Does this help the user act faster?

If it adds analysis without action, it is suspect.

---

## 2. UX Principles

### 2.1 Execution is the default surface

The first thing users see is action.

Editing, configuration, and reflection are secondary surfaces.

The home of the app is execution.

---

### 2.2 Capture must be frictionless

Ideas must be captured faster than they can be forgotten.

Capture flows must be:
- immediate
- minimal
- interruption-resistant

If capture is slow, users abandon the system.

---

### 2.3 The interface must feel calm

The app should never feel busy or noisy.

We avoid:
- dashboard overload
- decorative complexity
- unnecessary animation
- dense information walls

Whitespace is a feature.

---

### 2.4 Editing is secondary to action

The product is not a writing tool.

Editing supports execution.
Execution is the primary goal.

---

## 3. Architecture Principles

### 3.1 Backend is canonical

The backend is the system of record.

Clients are caches and interfaces.
They do not own truth.

All business rules must be enforceable server-side.

---

### 3.2 Separation of concerns is mandatory

Tiers must remain independent:

- backend owns rules and data
- clients own presentation and offline continuity

No shortcuts.
No cross-tier leakage.

Convenience today becomes coupling tomorrow.

---

### 3.3 APIs are contracts

APIs are stable interfaces, not implementation details.

Once released, they must remain compatible or versioned.

Breaking changes are architectural events, not casual edits.

---

### 3.4 Offline is a first-class requirement

The system must tolerate imperfect connectivity.

Execution cannot depend on perfect network conditions.

Users should trust the system to behave consistently offline.

---

### 3.5 Independent deployability

Each tier must deploy independently.

Backend, iOS, web, and Android must evolve without lockstep releases.

Coupled releases signal architectural failure.

---

## 4. Engineering Principles

### 4.1 Prefer simple over clever

Readable code outlives clever code.

If it cannot be understood quickly, it is wrong.

---

### 4.2 Make illegal states unrepresentable

Data models should prevent invalid states by design.

Validation belongs in the system, not in developer memory.

---

### 4.3 Optimize for future maintainers

Code is written for the next engineer, not the current one.

Clarity beats brevity.
Explicit beats implicit.

---

### 4.4 Refactoring is first-class work

Cleaning architecture is not optional polish.

Technical debt compounds silently.
We pay it continuously, not in crises.

---

### 4.5 Tests describe behavior, not implementation

Tests should document what the system guarantees.

They are executable specifications.

---

## 5. Scope Discipline

Idea Pilot is intentionally narrow.

We reject features that dilute the core mission.

We are not:

- a team collaboration platform
- a calendar replacement
- a general note-taking app
- a project management suite
- a knowledge base
- a dashboard product

We are an execution engine.

If a feature pushes the product toward general productivity tooling,
it must justify its existence under the execution philosophy.

---

## 6. Decision Hierarchy

When tradeoffs occur, decisions follow this order:

1. User clarity beats feature richness
2. Execution speed beats customization
3. Simplicity beats extensibility
4. Consistency beats novelty
5. Reliability beats sophistication
6. Long-term maintainability beats short-term convenience

This hierarchy resolves disputes without debate.

---

## 7. Evolution Principle

The product must grow without losing identity.

We add power by deepening the execution engine,
not by adding unrelated surface area.

Growth is vertical (depth), not horizontal (feature sprawl).

---

## 8. Final Rule

If a proposal makes the system:

- harder to understand
- slower to act
- noisier to use
- more flexible but less decisive

…it violates the spirit of Idea Pilot.

Execution clarity is the north star.

Everything else is secondary.

---

## End of Principles
